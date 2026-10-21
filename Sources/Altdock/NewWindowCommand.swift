import AppKit
import ApplicationServices

struct NewWindowError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
protocol NewWindowCommandRequesting {
    func request(processID: Int32) throws
}

enum NewWindowCommandPolicy {
    static func matches(_ title: String) -> Bool {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "…", with: "").replacingOccurrences(of: "...", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["new window", "new finder window", "new window with default profile", "new window (default profile)"].contains(normalized)
    }
}

@MainActor
final class NewWindowCommand: NewWindowCommandRequesting {
    func request(processID: Int32) throws {
        guard AXIsProcessTrusted() else {
            throw NewWindowError(message: "Creating a window requires Accessibility access. Enable it through Altdock's menu and try again.")
        }
        let application = AXUIElementCreateApplication(processID)
        let deadline = ProcessInfo.processInfo.systemUptime + 0.6
        guard let menuBar = try value(application, kAXMenuBarAttribute, before: deadline),
              CFGetTypeID(menuBar) == AXUIElementGetTypeID() else {
            throw NewWindowError(message: "This app's menu bar is unavailable. No new window was requested.")
        }
        for menu in try children(menuBar as! AXUIElement, before: deadline).prefix(20) {
            for container in try children(menu, before: deadline).prefix(2) {
                for item in try children(container, before: deadline).prefix(100) {
                    guard let title = try value(item, kAXTitleAttribute, before: deadline) as? String,
                          NewWindowCommandPolicy.matches(title) else { continue }
                    let nested = try children(item, before: deadline)
                    if nested.isEmpty { try press(item, processID: processID, before: deadline); return }
                    for submenu in nested.prefix(2) {
                        for choice in try children(submenu, before: deadline).prefix(100) {
                            if (try value(choice, kAXMenuItemCmdCharAttribute, before: deadline) as? String)?.lowercased() == "n",
                               try value(choice, kAXMenuItemCmdModifiersAttribute, before: deadline) as? Int == 0 {
                                try press(choice, processID: processID, before: deadline)
                                return
                            }
                        }
                    }
                }
            }
        }
        throw NewWindowError(message: "This app does not expose a supported New Window command. It may be single-window or require an app-specific action. No additional instance was launched.")
    }

    private func press(_ item: AXUIElement, processID: Int32, before deadline: TimeInterval) throws {
        var owner: pid_t = 0
        guard AXUIElementGetPid(item, &owner) == .success, owner == processID,
              try value(item, kAXRoleAttribute, before: deadline) as? String == kAXMenuItemRole else {
            throw NewWindowError(message: "The app's New Window command changed. Reopen the menu and try again.")
        }
        guard let enabled = try value(item, kAXEnabledAttribute, before: deadline) as? Bool else {
            throw NewWindowError(message: "The app's New Window command could not be validated. No window was requested.")
        }
        guard enabled else {
            throw NewWindowError(message: "The app's New Window command is currently disabled. It may not allow another window in its current state.")
        }
        try Task.checkCancellation()
        AXUIElementSetMessagingTimeout(item, 0.2)
        let result = AXUIElementPerformAction(item, kAXPressAction as CFString)
        guard result == .success || result == .cannotComplete else {
            throw NewWindowError(message: "macOS could not invoke this app's New Window command. No alternative command or additional instance was launched.")
        }
    }

    private func children(_ element: AXUIElement, before deadline: TimeInterval) throws -> [AXUIElement] {
        try value(element, kAXChildrenAttribute, before: deadline) as? [AXUIElement] ?? []
    }

    private func value(_ element: AXUIElement, _ attribute: String, before deadline: TimeInterval) throws -> CFTypeRef? {
        guard ProcessInfo.processInfo.systemUptime < deadline else {
            throw NewWindowError(message: "The app took too long to expose its New Window command. No window was requested.")
        }
        AXUIElementSetMessagingTimeout(element, 0.1)
        var result: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &result)
        if error == .attributeUnsupported || error == .noValue { return nil }
        guard error == .success else {
            throw NewWindowError(message: "The app's window command could not be read (Accessibility error \(error.rawValue)). No window was requested.")
        }
        return result
    }
}
