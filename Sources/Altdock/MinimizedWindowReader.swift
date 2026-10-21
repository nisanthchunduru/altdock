import AppKit
import ApplicationServices

struct MinimizedWindowInfo {
    let id: UInt32
    let title: String?
}

@MainActor
protocol MinimizedWindowReading {
    func minimizedWindows(processID: Int32, candidates: Set<UInt32>) -> [MinimizedWindowInfo]?
}

@MainActor
final class MinimizedWindowReader: MinimizedWindowReading {
    private typealias CopyWindowID = @convention(c) (AXUIElement, UnsafeMutablePointer<UInt32>) -> Int32
    private let library = DynamicLibrary(path: "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices")
    private lazy var copyWindowID = library?.symbol("_AXUIElementGetWindow", as: CopyWindowID.self)

    func minimizedWindows(processID: Int32, candidates: Set<UInt32>) -> [MinimizedWindowInfo]? {
        guard !candidates.isEmpty, AXIsProcessTrusted(), let copyWindowID else { return [] }
        let application = AXUIElementCreateApplication(processID)
        AXUIElementSetMessagingTimeout(application, 0.1)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return nil }
        var minimized: [MinimizedWindowInfo] = []
        for window in windows {
            var identifier: UInt32 = 0
            var owner: pid_t = 0
            guard copyWindowID(window, &identifier) == 0, candidates.contains(identifier),
                  AXUIElementGetPid(window, &owner) == .success, owner == processID else { continue }
            AXUIElementSetMessagingTimeout(window, 0.1)
            var role: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &role) == .success else { return nil }
            guard role as? String == kAXWindowRole else { continue }
            var state: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &state)
            if result == .attributeUnsupported || result == .invalidUIElement { continue }
            guard result == .success, let state, CFGetTypeID(state) == CFBooleanGetTypeID() else { return nil }
            if state as? Bool == true {
                var title: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
                minimized.append(MinimizedWindowInfo(id: identifier, title: title as? String))
            }
        }
        return minimized
    }
}
