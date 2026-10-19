import AltdockCore
import AppKit
@preconcurrency import ApplicationServices

@MainActor
enum ApplicationActivator {
    static func activate(_ application: NSRunningApplication, on screen: NSScreen?) {
        guard !application.isTerminated, let screen else { return }
        let currentWindows = SpaceApplications.windows(
            from: WindowSnapshot.current(), regularProcessIDs: [application.processIdentifier],
            excluding: ProcessInfo.processInfo.processIdentifier,
            on: CGDisplayBounds(screen.displayID)
        )
        guard !currentWindows.isEmpty else { return }

        if AXIsProcessTrusted(), let window = accessibilityWindow(for: application, matching: currentWindows) {
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
        application.activate(options: [])
    }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    private static func accessibilityWindow(
        for application: NSRunningApplication, matching windows: [SpaceWindow]
    ) -> AXUIElement? {
        let element = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.2)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
              let accessibleWindows = value as? [AXUIElement] else { return nil }

        for window in windows {
            if let match = accessibleWindows.first(where: { matches($0, bounds: window.bounds) }) {
                return match
            }
        }
        return nil
    }

    private static func matches(_ window: AXUIElement, bounds: CGRect) -> Bool {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return false }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return false }
        return abs(position.x - bounds.minX) < 2 && abs(position.y - bounds.minY) < 2
            && abs(size.width - bounds.width) < 2 && abs(size.height - bounds.height) < 2
    }
}
