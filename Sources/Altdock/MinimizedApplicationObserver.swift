import AppKit
import ApplicationServices

@MainActor
protocol MinimizedApplicationObserving: AnyObject {
    func start(processID: Int32, changed: @escaping @MainActor @Sendable () -> Void) -> Bool
    func stop()
}

@MainActor
final class MinimizedApplicationObserver: MinimizedApplicationObserving {
    nonisolated private static let notification = Notification.Name("dev.altdock.minimizationChanged")
    private static let names = [kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification]
    private var observer: AXObserver?
    private var application: AXUIElement?
    private var subscription: NSObjectProtocol?

    func start(processID: Int32, changed: @escaping @MainActor @Sendable () -> Void) -> Bool {
        stop()
        guard AXIsProcessTrusted() else { return false }
        let application = AXUIElementCreateApplication(processID)
        AXUIElementSetMessagingTimeout(application, 0.1)
        var observer: AXObserver?
        guard AXObserverCreate(processID, { _, element, _, _ in
            var pid: pid_t = 0
            guard AXUIElementGetPid(element, &pid) == .success else { return }
            NotificationCenter.default.post(name: MinimizedApplicationObserver.notification, object: nil, userInfo: ["pid": pid])
        }, &observer) == .success, let observer else { return false }
        self.observer = observer
        self.application = application
        for name in Self.names {
            let result = AXObserverAddNotification(observer, application, name as CFString, nil)
            guard result == .success || result == .notificationAlreadyRegistered else { stop(); return false }
        }
        subscription = NotificationCenter.default.addObserver(forName: Self.notification, object: nil, queue: .main) { notification in
            guard notification.userInfo?["pid"] as? Int32 == processID else { return }
            MainActor.assumeIsolated { changed() }
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        return true
    }

    func stop() {
        if let subscription { NotificationCenter.default.removeObserver(subscription) }
        subscription = nil
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            if let application {
                for name in Self.names { AXObserverRemoveNotification(observer, application, name as CFString) }
            }
            CFRunLoopSourceInvalidate(AXObserverGetRunLoopSource(observer))
        }
        observer = nil
        application = nil
    }
}
