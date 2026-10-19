import AppKit
@preconcurrency import ApplicationServices

@MainActor
final class AccessibilityPermission {
    static let shared = AccessibilityPermission()

    private let check: () -> Bool
    private let prompt: () -> Void

    var isGranted: Bool { check() }

    init(check: @escaping () -> Bool = { AXIsProcessTrusted() }, prompt: @escaping () -> Void = {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }) {
        self.check = check
        self.prompt = prompt
    }

    @discardableResult
    func requestIfNeeded() -> Bool {
        guard !check() else { return false }
        prompt()
        return true
    }
}
