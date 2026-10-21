import AltdockCore
import CoreGraphics
import Foundation

struct SpaceWindowSelection {
    let spaceID: UInt64?
    let windows: [SpaceWindow]
}

@MainActor
protocol SpaceWindowTracking {
    var usesSkyLight: Bool { get }
    var hasFreshSnapshot: Bool { get }
    var backendDescription: String { get }
    func refresh(regularProcessIDs: Set<Int32>)
    func activeSpaceID(on displayBounds: CGRect) -> UInt64?
    func fullScreenSpaceIDs(on displayBounds: CGRect) -> Set<UInt64>?
    func selection(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> SpaceWindowSelection?
    func allSelections(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> [UInt64: [SpaceWindow]]?
}

extension SpaceWindowTracking {
    var hasFreshSnapshot: Bool { true }
    func activeSpaceID(on displayBounds: CGRect) -> UInt64? { nil }
    func fullScreenSpaceIDs(on displayBounds: CGRect) -> Set<UInt64>? { nil }
    func allSelections(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> [UInt64: [SpaceWindow]]? { nil }
}

@MainActor
final class SpaceWindowTracker: SpaceWindowTracking {
    private let spaces: (any SpaceQuerying)?
    private let captureWindows: (CGWindowListOption) -> [SpaceWindow]?
    private let minimizedWindows: (any MinimizedWindowReading)?
    private var knownMinimized: [Int32: [MinimizedWindowInfo]] = [:]
    private(set) var index: SpaceWindowIndex?
    var didCaptureWindows: (([SpaceWindow], Set<Int32>) -> Void)?
    private var onScreenWindows: [SpaceWindow]?
    private var lastSnapshotSucceeded = false

    var usesSkyLight: Bool { index != nil }
    var hasFreshSnapshot: Bool { lastSnapshotSucceeded }
    var backendDescription: String {
        guard usesSkyLight else { return "Public API · On-screen fallback" }
        return lastSnapshotSucceeded ? "SkyLight · All Spaces" : "SkyLight · Cached Spaces (refresh pending)"
    }

    init(usePrivateAPI: Bool = true) {
        spaces = usePrivateAPI ? SkyLightSpaces() : nil
        captureWindows = WindowSnapshot.capture
        minimizedWindows = usePrivateAPI ? MinimizedWindowReader() : nil
    }

    init(spaces: (any SpaceQuerying)?, minimizedWindows: (any MinimizedWindowReading)? = nil, captureWindows: @escaping (CGWindowListOption) -> [SpaceWindow]?) {
        self.spaces = spaces
        self.minimizedWindows = minimizedWindows
        self.captureWindows = captureWindows
    }

    func refresh(regularProcessIDs: Set<Int32>) {
        if let snapshot = allSpacesSnapshot(regularProcessIDs: regularProcessIDs) {
            index = snapshot
            onScreenWindows = nil
            lastSnapshotSucceeded = true
        } else {
            lastSnapshotSucceeded = false
            if index == nil { onScreenWindows = captureWindows([.optionOnScreenOnly, .excludeDesktopElements]) }
        }
    }

    func activeSpaceID(on displayBounds: CGRect) -> UInt64? {
        spaces?.activeSpaceID(on: displayBounds)
    }

    func fullScreenSpaceIDs(on displayBounds: CGRect) -> Set<UInt64>? {
        spaces?.fullScreenSpaceIDs(on: displayBounds)
    }

    func selection(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> SpaceWindowSelection? {
        let spaceID: UInt64?
        let windows: [SpaceWindow]
        if let index {
            guard let activeID = spaces?.activeSpaceID(on: displayBounds),
                  let cachedWindows = index.windows(in: activeID) else { return nil }
            spaceID = activeID
            windows = cachedWindows
        } else {
            guard let onScreenWindows else { return nil }
            spaceID = nil
            windows = onScreenWindows
        }
        return SpaceWindowSelection(
            spaceID: spaceID,
            windows: SpaceApplications.windows(
                from: windows, regularProcessIDs: regularProcessIDs,
                excluding: ProcessInfo.processInfo.processIdentifier,
                on: displayBounds, requiringOnScreen: spaceID == nil
            )
        )
    }

    func allSelections(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> [UInt64: [SpaceWindow]]? {
        guard let index, let spaceIDs = spaces?.spaceIDs(on: displayBounds) else { return nil }
        var selections: [UInt64: [SpaceWindow]] = [:]
        for spaceID in spaceIDs {
            guard let windows = index.windows(in: spaceID) else { continue }
            selections[spaceID] = SpaceApplications.windows(
                from: windows, regularProcessIDs: regularProcessIDs,
                excluding: ProcessInfo.processInfo.processIdentifier,
                on: displayBounds, requiringOnScreen: false
            )
        }
        return selections
    }

    private func allSpacesSnapshot(regularProcessIDs: Set<Int32>) -> SpaceWindowIndex? {
        guard let spaces, let spaceIDs = spaces.allSpaceIDs(),
              let windows = captureWindows([.optionAll, .excludeDesktopElements]) else { return nil }
        didCaptureWindows?(windows, regularProcessIDs)
        let candidates = SpaceApplications.windows(
            from: windows, regularProcessIDs: regularProcessIDs,
            excluding: ProcessInfo.processInfo.processIdentifier,
            on: .infinite, requiringOnScreen: false
        )
        var orderedIDs: Set<UInt32> = []
        var orderedOut: [SpaceWindow] = []
        for window in candidates {
            guard let isOrderedIn = spaces.isWindowOrderedIn(window.id) else { return nil }
            if isOrderedIn { orderedIDs.insert(window.id) }
            else { orderedOut.append(window) }
        }
        let minimized = confirmedMinimizedWindows(in: orderedOut)
        var membership: [UInt32: Set<UInt64>] = [:]
        var eligible: [SpaceWindow] = []
        for window in candidates where orderedIDs.contains(window.id) || minimized[window.id] != nil {
            guard let identifiers = spaces.spaceIDs(for: window.id) else { return nil }
            membership[window.id] = identifiers
            eligible.append(SpaceWindow(
                id: window.id, processID: window.processID, bounds: window.bounds,
                layer: window.layer, alpha: window.alpha, isOnScreen: window.isOnScreen,
                isMinimized: minimized[window.id] != nil, title: minimized[window.id]?.title
            ))
        }
        return SpaceWindowIndex(windows: eligible, membership: membership, knownSpaceIDs: spaceIDs)
    }

    private func confirmedMinimizedWindows(in windows: [SpaceWindow]) -> [UInt32: MinimizedWindowInfo] {
        let byProcess = Dictionary(grouping: windows, by: \.processID)
        knownMinimized = knownMinimized.filter { byProcess[$0.key] != nil }
        for (processID, windows) in byProcess {
            let candidates = Set(windows.map(\.id))
            let confirmed = minimizedWindows?.minimizedWindows(processID: processID, candidates: candidates)
            knownMinimized[processID] = (confirmed ?? knownMinimized[processID, default: []]).filter { candidates.contains($0.id) }
        }
        return Dictionary(knownMinimized.values.flatMap { $0 }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
