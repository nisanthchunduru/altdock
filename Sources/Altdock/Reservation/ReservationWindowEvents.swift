import AppKit
import ApplicationServices

final class ReservationWindowEvents {
    static let changed = Notification.Name("dev.altdock.reservationWindowChanged")

    private struct Observation {
        let observer: AXObserver
        var windows: [UInt32: AXUIElement] = [:]
    }

    private var observations: [Int32: Observation] = [:]

    func update(processID: Int32, windows: [UInt32: AXUIElement]) {
        if observations[processID] == nil {
            var observer: AXObserver?
            guard AXObserverCreate(processID, { _, _, _, _ in
                NotificationCenter.default.post(name: ReservationWindowEvents.changed, object: nil)
            }, &observer) == .success, let observer else { return }
            let app = AXUIElementCreateApplication(processID)
            AXUIElementSetMessagingTimeout(app, 0.05)
            for name in [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification] {
                AXObserverAddNotification(observer, app, name as CFString, nil)
            }
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            observations[processID] = Observation(observer: observer)
        }
        guard var observation = observations[processID] else { return }
        let notifications = [kAXWindowMovedNotification, kAXWindowResizedNotification, kAXWindowDeminiaturizedNotification, kAXUIElementDestroyedNotification]
        for (id, element) in observation.windows where windows[id] == nil {
            for name in notifications { AXObserverRemoveNotification(observation.observer, element, name as CFString) }
            observation.windows.removeValue(forKey: id)
        }
        for (id, element) in windows where observation.windows[id].map({ !CFEqual($0, element) }) ?? true {
            if let old = observation.windows[id] {
                for name in notifications { AXObserverRemoveNotification(observation.observer, old, name as CFString) }
            }
            for name in notifications { AXObserverAddNotification(observation.observer, element, name as CFString, nil) }
            observation.windows[id] = element
        }
        observations[processID] = observation
    }

    func retain(processIDs: Set<Int32>) {
        for (pid, observation) in observations where !processIDs.contains(pid) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observation.observer), .commonModes)
            observations.removeValue(forKey: pid)
        }
    }

    func stop() { retain(processIDs: []) }
}
