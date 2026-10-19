public enum AccessibilityAttribute<Value: Sendable>: Sendable {
    case value(Value)
    case unsupported
    case unavailable(Int32)
}

public enum ReservationEligibility {
    public static func rejection(
        subrole: AccessibilityAttribute<String>, minimized: AccessibilityAttribute<Bool>,
        fullScreen: AccessibilityAttribute<Bool>, sizeSettable: AccessibilityAttribute<Bool>
    ) -> String? {
        guard case .value("AXStandardWindow") = subrole else { return "Not a standard window, or AXSubrole is unavailable" }
        guard case .value(false) = minimized else { return "Minimized window, or AXMinimized is unavailable" }
        switch fullScreen {
        case .value(true): return "Full-screen window"
        case .unavailable(let error): return "AXFullScreen read failed (\(error)); retrying later"
        case .value(false), .unsupported: break
        }
        switch sizeSettable {
        case .value(true): return nil
        case .value(false), .unsupported: return "AXSize is not writable"
        case .unavailable(let error): return "AXSize capability read failed (\(error)); retrying later"
        }
    }
}
