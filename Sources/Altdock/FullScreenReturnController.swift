import AltdockCore
import AppKit

@MainActor
final class FullScreenReturnController {
    struct Display {
        let id: UInt32
        let bounds: CGRect
    }

    private struct WindowIdentity: Hashable {
        let windowID: UInt32
        let processID: Int32
    }

    private struct Origin {
        let desktopID: UInt64
        let displayID: UInt32
    }

    private enum Phase {
        case ordinary
        case fullScreen
        case settling(source: UInt64, since: Date)
        case verifying(source: UInt64, destination: UInt64, deadline: Date)
    }

    private struct Record {
        var origin: Origin
        var phase: Phase = .ordinary
        var lastSeen: Date
    }

    private struct Topology {
        var desktops: [(displayID: UInt32, destinations: [DesktopDestination])] = []
        var fullScreenIDs: Set<UInt64> = []
        var ordinaryIDs: Set<UInt64> { Set(desktops.flatMap { $0.destinations.map(\.id) }) }

        func origin(for desktopID: UInt64) -> Origin? {
            guard let display = desktops.first(where: { $0.destinations.contains(where: { $0.id == desktopID }) }) else { return nil }
            return Origin(desktopID: desktopID, displayID: display.displayID)
        }

        func destination(for origin: Origin) -> UInt64? {
            if ordinaryIDs.contains(origin.desktopID) { return origin.desktopID }
            let display = desktops.first { $0.displayID == origin.displayID } ?? desktops.first
            return display?.destinations.first?.id
        }
    }

    private let spaces: (any SpaceQuerying)?
    private let bridge: any DesktopMoveRequesting
    private let displays: () -> [Display]
    private let capture: () -> [SpaceWindow]?
    private let now: () -> Date
    private let report: (String) -> Void
    private var records: [WindowIdentity: Record] = [:]

    init(
        spaces: (any SpaceQuerying)? = SkyLightSpaces(),
        bridge: any DesktopMoveRequesting = DesktopMoveBridge(),
        displays: @escaping () -> [Display] = { NSScreen.screens.map { Display(id: $0.displayID, bounds: CGDisplayBounds($0.displayID)) } },
        capture: @escaping () -> [SpaceWindow]? = { WindowSnapshot.capture(options: [.optionAll, .excludeDesktopElements]) },
        now: @escaping () -> Date = Date.init,
        report: @escaping (String) -> Void = { NSLog("Altdock full-screen return: %@", $0) }
    ) {
        self.spaces = spaces
        self.bridge = bridge
        self.displays = displays
        self.capture = capture
        self.now = now
        self.report = report
    }

    func observe(windows: [SpaceWindow], regularProcessIDs: Set<Int32>) {
        let time = now()
        let present = Set(windows.map { WindowIdentity(windowID: $0.id, processID: $0.processID) })
        defer { expireUnverifiedReturns(at: time) }
        records = records.filter { identity, record in
            guard regularProcessIDs.contains(identity.processID) else { return false }
            if case .ordinary = record.phase, !present.contains(identity) { return time.timeIntervalSince(record.lastSeen) < 60 }
            return true
        }
        guard bridge.isAvailable, let spaces, let topology = topology() else { return }
        for window in windows where regularProcessIDs.contains(window.processID) && window.processID != ProcessInfo.processInfo.processIdentifier {
            let identity = WindowIdentity(windowID: window.id, processID: window.processID)
            if records[identity] == nil {
                guard window.layer == 0, window.alpha > 0, window.bounds.width > 1, window.bounds.height > 1,
                      spaces.isWindowOrderedIn(window.id) == true else { continue }
            }
            guard let membership = spaces.spaceIDs(for: window.id), !membership.isEmpty,
                  membership.isSubset(of: topology.ordinaryIDs.union(topology.fullScreenIDs)) else { continue }
            guard membership.intersection(topology.ordinaryIDs).count <= 1 else {
                records.removeValue(forKey: identity)
                continue
            }
            if !membership.isDisjoint(with: topology.fullScreenIDs) {
                if records[identity] != nil {
                    records[identity]?.phase = .fullScreen
                    records[identity]?.lastSeen = time
                }
                continue
            }
            guard membership.count == 1, let source = membership.first, let currentOrigin = topology.origin(for: source) else {
                records.removeValue(forKey: identity)
                continue
            }
            if var record = records[identity] {
                record.lastSeen = time
                update(&record, identity: identity, source: source, currentOrigin: currentOrigin, topology: topology, time: time)
                records[identity] = record
            } else {
                records[identity] = Record(origin: currentOrigin, lastSeen: time)
            }
        }
    }

    private func update(
        _ record: inout Record, identity: WindowIdentity, source: UInt64,
        currentOrigin: Origin, topology: Topology, time: Date
    ) {
        switch record.phase {
        case .ordinary:
            record.origin = currentOrigin
        case .fullScreen:
            record.phase = .settling(source: source, since: time)
        case let .settling(previousSource, since):
            guard previousSource == source else {
                record.phase = .settling(source: source, since: time)
                return
            }
            guard time.timeIntervalSince(since) >= 0.5, let destination = topology.destination(for: record.origin) else { return }
            if source == destination {
                record.origin = currentOrigin
                record.phase = .ordinary
            } else {
                submitReturn(&record, identity: identity, source: source, destination: destination, time: time)
            }
        case let .verifying(previousSource, destination, deadline):
            if source == destination {
                report("Window \(identity.windowID) returned to Desktop \(destination).")
            } else if source == previousSource && time < deadline {
                return
            } else {
                report("Could not verify window \(identity.windowID) on Desktop \(destination); no retry attempted.")
            }
            record.origin = currentOrigin
            record.phase = .ordinary
        }
    }

    private func submitReturn(_ record: inout Record, identity: WindowIdentity, source: UInt64, destination: UInt64, time: Date) {
        guard let freshWindows = capture(), freshWindows.contains(where: { $0.id == identity.windowID && $0.processID == identity.processID }),
              let freshTopology = topology(), freshTopology.destination(for: record.origin) == destination,
              freshTopology.ordinaryIDs.contains(source), spaces?.spaceIDs(for: identity.windowID) == [source] else {
            record.phase = .fullScreen
            return
        }
        if bridge.request(windowIDs: [identity.windowID], destination: destination) {
            record.phase = .verifying(source: source, destination: destination, deadline: time.addingTimeInterval(2))
        } else {
            report("macOS rejected returning window \(identity.windowID) to Desktop \(destination); no retry attempted.")
            record.phase = .ordinary
            if let origin = freshTopology.origin(for: source) { record.origin = origin }
        }
    }

    private func expireUnverifiedReturns(at time: Date) {
        for (identity, record) in records {
            guard case let .verifying(_, destination, deadline) = record.phase, time >= deadline else { continue }
            report("Could not verify window \(identity.windowID) on Desktop \(destination); no retry attempted.")
            records.removeValue(forKey: identity)
        }
    }

    private func topology() -> Topology? {
        guard let spaces else { return nil }
        let connected = displays()
        guard !connected.isEmpty else { return nil }
        var result = Topology()
        for display in connected {
            guard let desktops = spaces.desktops(on: display.bounds), !desktops.isEmpty,
                  let fullScreenIDs = spaces.fullScreenSpaceIDs(on: display.bounds) else { return nil }
            result.desktops.append((display.id, desktops))
            result.fullScreenIDs.formUnion(fullScreenIDs)
        }
        guard result.ordinaryIDs.isDisjoint(with: result.fullScreenIDs),
              spaces.allSpaceIDs() == result.ordinaryIDs.union(result.fullScreenIDs) else { return nil }
        return result
    }
}
