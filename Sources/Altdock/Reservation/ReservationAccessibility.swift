import AltdockCore
import AppKit
import ApplicationServices

final class ReservationAccessibility {
    private typealias WindowIDFunction = @convention(c) (AXUIElement, UnsafeMutablePointer<UInt32>) -> Int32
    private let library = DynamicLibrary(path: "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices")
    private lazy var windowIDFunction = library?.symbol("_AXUIElementGetWindow", as: WindowIDFunction.self)
    private(set) var enumerationError: Int32?
    private(set) var writeError: String?

    func windows(for processID: Int32) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(processID)
        AXUIElementSetMessagingTimeout(app, 0.25)
        var result: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &result)
        enumerationError = error == .success ? nil : error.rawValue
        let windows = result as? [AXUIElement] ?? []
        for window in windows { AXUIElementSetMessagingTimeout(window, 0.25) }
        return windows
    }

    func identifier(_ window: AXUIElement) -> UInt32? {
        guard let windowIDFunction else { return nil }
        var id: UInt32 = 0
        return windowIDFunction(window, &id) == 0 && id != 0 ? id : nil
    }

    func frame(_ window: AXUIElement) -> CGRect? {
        guard let position = value(window, kAXPositionAttribute), let size = value(window, kAXSizeAttribute),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }

    func rejection(_ window: AXUIElement) -> String? {
        ReservationEligibility.rejection(
            subrole: attribute(window, kAXSubroleAttribute, as: String.self),
            minimized: attribute(window, kAXMinimizedAttribute, as: Bool.self),
            fullScreen: attribute(window, "AXFullScreen", as: Bool.self),
            sizeSettable: settable(window, kAXSizeAttribute)
        )
    }

    func write(_ target: CGRect, to window: AXUIElement, expecting original: CGRect) -> Bool {
        writeError = rejection(window)
        guard writeError == nil else { return false }
        if abs(target.minX - original.minX) > 2 || abs(target.minY - original.minY) > 2 {
            guard case .value(true) = settable(window, kAXPositionAttribute) else {
                writeError = "This edge adjustment needs writable AXPosition"
                return false
            }
        }
        return ReservationFrameTransaction.apply(
            from: original, to: target, read: { self.frame(window) },
            write: { self.setFrame($0, on: window) },
            waitForNextRead: { Thread.sleep(forTimeInterval: 0.06) }
        )
    }

    private func setFrame(_ target: CGRect, on window: AXUIElement) -> Bool {
        guard !CGEventSource.buttonState(.combinedSessionState, button: .left) else { return false }
        var size = target.size
        var position = target.origin
        guard let sizeValue = AXValueCreate(.cgSize, &size), let positionValue = AXValueCreate(.cgPoint, &position) else { return false }
        let error = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        guard error == .success || error == .cannotComplete else {
            writeError = "AXSize write failed (\(error.rawValue))"
            return false
        }
        guard let afterSize = frame(window) else { return true }
        if abs(afterSize.minX - target.minX) > 2 || abs(afterSize.minY - target.minY) > 2 {
            guard case .value(true) = settable(window, kAXPositionAttribute) else {
                writeError = "Resize changed the anchor, but AXPosition is not writable"
                return false
            }
            let positionError = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
            guard positionError == .success || positionError == .cannotComplete else {
                writeError = "AXPosition write failed (\(positionError.rawValue))"
                return false
            }
        }
        return true
    }

    private func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }

    private func attribute<Value: Sendable>(_ element: AXUIElement, _ name: String, as type: Value.Type) -> AccessibilityAttribute<Value> {
        var result: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &result)
        if error == .attributeUnsupported { return .unsupported }
        guard error == .success, let value = result as? Value else { return .unavailable(error.rawValue) }
        return .value(value)
    }

    private func settable(_ element: AXUIElement, _ attribute: String) -> AccessibilityAttribute<Bool> {
        var settable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        if error == .attributeUnsupported { return .unsupported }
        return error == .success ? .value(settable.boolValue) : .unavailable(error.rawValue)
    }
}
