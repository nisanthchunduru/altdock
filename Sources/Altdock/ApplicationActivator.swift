import AltdockCore
import AppKit
@preconcurrency import ApplicationServices

@MainActor
enum ApplicationActivator {
    private typealias CopyWindowID = @convention(c) (AXUIElement, UnsafeMutablePointer<UInt32>) -> Int32
    private static let accessibilityLibrary = DynamicLibrary(
        path: "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
    )
    private static let copyWindowID = accessibilityLibrary?.symbol("_AXUIElementGetWindow", as: CopyWindowID.self)

    static func activate(_ application: NSRunningApplication, matching currentWindows: [SpaceWindow]) {
        guard !application.isTerminated, !currentWindows.isEmpty else { return }
        application.unhide()
        if AXIsProcessTrusted(), let window = accessibilityWindow(for: application, matching: currentWindows) {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
        application.activate(options: [])
    }

    static func requestAccessibility() {
        AccessibilityPermission.shared.requestIfNeeded()
    }

    private static func accessibilityWindow(
        for application: NSRunningApplication, matching windows: [SpaceWindow]
    ) -> AXUIElement? {
        let element = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.2)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
              let accessibleWindows = value as? [AXUIElement] else { return nil }

        for accessibleWindow in accessibleWindows { AXUIElementSetMessagingTimeout(accessibleWindow, 0.2) }
        for window in windows {
            if let match = accessibleWindows.first(where: { matches($0, window: window) }) {
                return match
            }
        }
        return nil
    }

    private static func matches(_ element: AXUIElement, window: SpaceWindow) -> Bool {
        if let copyWindowID {
            var identifier: UInt32 = 0
            return copyWindowID(element, &identifier) == 0 && identifier == window.id
        }
        return matchesGeometry(element, bounds: window.bounds)
    }

    private static func matchesGeometry(_ window: AXUIElement, bounds: CGRect) -> Bool {
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
