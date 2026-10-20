import AltdockCore
import AppKit
@preconcurrency import ApplicationServices

@MainActor
protocol ApplicationActivationAccess {
    associatedtype Window
    var processID: Int32 { get }
    var isTerminated: Bool { get }
    var isActive: Bool { get }
    var isHidden: Bool { get }
    var isTrusted: Bool { get }
    func focusedWindow() -> Window?
    func windows() -> [Window]
    func matches(_ element: Window, window: SpaceWindow) -> Bool
    func restoreAndRaise(_ window: Window)
    func unhide()
    func activate()
}

@MainActor
final class NativeApplicationActivation: ApplicationActivationAccess {
    private typealias CopyWindowID = @convention(c) (AXUIElement, UnsafeMutablePointer<UInt32>) -> Int32
    private static let library = DynamicLibrary(path: "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices")
    private static let copyWindowID = library?.symbol("_AXUIElementGetWindow", as: CopyWindowID.self)
    private let application: NSRunningApplication
    private let element: AXUIElement

    var processID: Int32 { application.processIdentifier }
    var isTerminated: Bool { application.isTerminated }
    var isActive: Bool { application.isActive }
    var isHidden: Bool { application.isHidden }
    var isTrusted: Bool { AXIsProcessTrusted() }

    init(application: NSRunningApplication) {
        self.application = application
        element = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.2)
    }

    func focusedWindow() -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let focused = value as! AXUIElement
        AXUIElementSetMessagingTimeout(focused, 0.2)
        return focused
    }

    func windows() -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return [] }
        for window in windows { AXUIElementSetMessagingTimeout(window, 0.2) }
        return windows
    }

    func matches(_ element: AXUIElement, window: SpaceWindow) -> Bool {
        var owner: pid_t = 0
        guard window.processID == processID, AXUIElementGetPid(element, &owner) == .success, owner == processID else { return false }
        if let copyWindowID = Self.copyWindowID {
            var identifier: UInt32 = 0
            return copyWindowID(element, &identifier) == 0 && identifier == window.id
        }
        return matchesGeometry(element, bounds: window.bounds)
    }

    func restoreAndRaise(_ window: AXUIElement) {
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    func unhide() { application.unhide() }
    func activate() { application.activate(options: []) }

    private func matchesGeometry(_ window: AXUIElement, bounds: CGRect) -> Bool {
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
