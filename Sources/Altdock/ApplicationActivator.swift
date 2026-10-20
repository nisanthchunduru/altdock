import AltdockCore
import AppKit

@MainActor
enum ApplicationActivator {
    static func activate(_ application: NSRunningApplication, matching currentWindows: [SpaceWindow]) {
        activate(matching: currentWindows, access: NativeApplicationActivation(application: application))
    }

    static func activate<Access: ApplicationActivationAccess>(matching currentWindows: [SpaceWindow], access: Access) {
        let localWindows = currentWindows.filter { $0.processID == access.processID }
        guard !access.isTerminated, !localWindows.isEmpty else { return }
        var selected: Access.Window?
        if access.isTrusted {
            if let focused = access.focusedWindow(), localWindows.contains(where: { access.matches(focused, window: $0) }) {
                if access.isActive && !access.isHidden { return }
                selected = focused
            } else {
                let accessible = access.windows()
                for window in localWindows {
                    if let match = accessible.first(where: { access.matches($0, window: window) }) {
                        selected = match
                        break
                    }
                }
            }
        }
        access.unhide()
        if let selected { access.restoreAndRaise(selected) }
        access.activate()
    }

    static func requestAccessibility() {
        AccessibilityPermission.shared.requestIfNeeded()
    }
}
