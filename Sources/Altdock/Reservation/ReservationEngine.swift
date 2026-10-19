import AltdockCore
import AppKit

struct ReservationRequest: Sendable {
    let geometry: ReservationGeometry
    let windows: [SpaceWindow]
    var frontmostProcessID: Int32? = nil
    var interactionGeneration: UInt64 = 0
}

actor ReservationEngine {
    private let accessibility = ReservationAccessibility()
    private let events = ReservationWindowEvents()
    private var ledger = ReservationLedger()
    private var geometry: ReservationGeometry?
    private var processCursor = 0

    func reconcile(_ request: ReservationRequest) -> ReservationScanReport {
        guard AXIsProcessTrusted() else {
            events.stop()
            return ReservationScanReport(state: "Accessibility is not granted to this running executable")
        }
        guard !CGEventSource.buttonState(.combinedSessionState, button: .left) else {
            return ReservationScanReport(state: "Waiting for the mouse drag to finish")
        }
        if geometry != request.geometry {
            restore()
            geometry = request.geometry
        }
        guard let liveWindows = WindowSnapshot.capture(options: [.optionAll, .excludeDesktopElements]) else {
            return ReservationScanReport(state: "WindowServer snapshot unavailable")
        }
        ledger.retain(liveIDs: Set(liveWindows.map { ReservationWindowID(processID: $0.processID, windowID: $0.id) }))
        let onScreenIDs = Set(liveWindows.filter(\.isOnScreen).map(\.id))
        let wantedIDs = Set(request.windows.map(\.id)).intersection(onScreenIDs)
        let grouped = Dictionary(grouping: request.windows, by: \.processID)
        let processIDs = grouped.keys.sorted()
        events.retain(processIDs: Set(processIDs))
        var report = ReservationScanReport(state: "Accessibility granted; reservation active")
        guard !processIDs.isEmpty else { return report }
        let deadline = ProcessInfo.processInfo.systemUptime + 0.5
        for offset in 0..<processIDs.count {
            guard !Task.isCancelled else { return report }
            let pid = processIDs[(processCursor + offset) % processIDs.count]
            let elements = accessibility.windows(for: pid)
            if let error = accessibility.enumerationError {
                report.windows.append(.init(processID: pid, windowID: nil, frame: nil, target: nil, result: "AXWindows read failed (\(error)); retrying later"))
            }
            var byID: [UInt32: AXUIElement] = [:]
            for element in elements {
                if let id = accessibility.identifier(element) { byID[id] = element }
            }
            events.update(processID: pid, windows: byID)
            for window in grouped[pid, default: []] where wantedIDs.contains(window.id) {
                guard !Task.isCancelled else { return report }
                let id = ReservationWindowID(processID: pid, windowID: window.id)
                if let element = byID[window.id] {
                    report.windows.append(adjust(element, id: id, request: request))
                } else {
                    report.windows.append(.init(processID: pid, windowID: window.id, frame: NSStringFromRect(window.bounds), target: nil, result: "No accessible window with this WindowServer ID"))
                }
                if ProcessInfo.processInfo.systemUptime > deadline { break }
            }
            if ProcessInfo.processInfo.systemUptime > deadline {
                processCursor = (processCursor + offset + 1) % processIDs.count
                return report
            }
        }
        return report
    }

    func restore() {
        events.stop()
        if AXIsProcessTrusted() {
            let grouped = Dictionary(grouping: ledger.adjustments.keys, by: \.processID)
            for (pid, _) in grouped {
                for element in accessibility.windows(for: pid) {
                    guard let windowID = accessibility.identifier(element), let frame = accessibility.frame(element),
                          let original = ledger.restoration(for: ReservationWindowID(processID: pid, windowID: windowID), current: frame)
                    else { continue }
                    _ = accessibility.write(original, to: element, expecting: frame)
                }
            }
        }
        ledger = ReservationLedger()
        geometry = nil
    }

    private func adjust(_ element: AXUIElement, id: ReservationWindowID, request: ReservationRequest) -> ReservationScanReport.Window {
        let frame = accessibility.frame(element)
        let target = frame.flatMap { request.geometry.target(for: $0) }
        func result(_ message: String) -> ReservationScanReport.Window {
            .init(processID: id.processID, windowID: id.windowID, frame: frame.map(NSStringFromRect), target: target.map(NSStringFromRect), result: message)
        }
        guard !CGEventSource.buttonState(.combinedSessionState, button: .left) else { return result("Waiting for drag to finish") }
        if let rejection = accessibility.rejection(element) { return result(rejection) }
        guard let frame else { return result("AX frame unavailable; retrying later") }
        let now = ProcessInfo.processInfo.systemUptime
        guard let proposed = ledger.target(
            for: id, frame: frame, geometry: request.geometry, now: now,
            interaction: request.frontmostProcessID == id.processID ? request.interactionGeneration : nil
        ) else {
            if request.geometry.isClear(frame) { return result("Already clear of the reserved strip") }
            return result(ledger.blockReason(for: id, now: now) ?? "Not an edge-tiled/maximized window, or adjustment is settling")
        }
        if accessibility.write(proposed, to: element, expecting: frame) {
            ledger.didApply(proposed, to: id, original: frame, now: ProcessInfo.processInfo.systemUptime)
            return result("Adjusted and verified")
        }
        ledger.didFail(id, now: ProcessInfo.processInfo.systemUptime)
        return result(accessibility.writeError ?? "Resize did not settle at the requested frame; retrying with bounded backoff")
    }
}
