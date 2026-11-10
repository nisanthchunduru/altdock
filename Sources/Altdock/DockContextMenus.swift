import AltdockCore
import AppKit

@MainActor
enum DockContextMenus {
    static func application(
        _ application: DockApplication, destinations: [DesktopDestination], isBusy: Bool,
        activate: @escaping () -> Void, createWindow: ((NSRunningApplication) -> Void)?,
        moveFocusedWindow: ((NSRunningApplication, UInt64) -> Void)?, moveWindows: ((NSRunningApplication, UInt64) -> Void)?
    ) -> NSMenu {
        let menu = makeMenu(title: application.name)
        menu.addItem(ActionMenuItem("Open", action: activate))
        menu.addItem(ActionMenuItem("New Window", enabled: createWindow != nil && !isBusy) { createWindow?(application.application) })
        menu.addItem(moveMenu(title: "Move Focused Window", application: application.application,
                              destinations: destinations, enabled: !isBusy, action: moveFocusedWindow))
        menu.addItem(moveMenu(title: "Move", application: application.application,
                              destinations: destinations, enabled: !isBusy, action: moveWindows))
        menu.addItem(ActionMenuItem("Hide") { application.application.hide() })
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Quit") { application.application.terminate() })
        return menu
    }

    static func minimizedWindow(_ window: DockMinimizedWindow, restore: @escaping () -> Void) -> NSMenu {
        let menu = makeMenu(title: window.name)
        menu.addItem(ActionMenuItem("Restore", action: restore))
        return menu
    }

    private static func makeMenu(title: String) -> NSMenu {
        let menu = NSMenu(title: title)
        menu.autoenablesItems = false
        menu.allowsContextMenuPlugIns = false
        let heading = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        menu.addItem(.separator())
        return menu
    }

    private static func moveMenu(
        title: String, application: NSRunningApplication, destinations: [DesktopDestination],
        enabled: Bool, action: ((NSRunningApplication, UInt64) -> Void)?
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = enabled && action != nil && !destinations.isEmpty
        let submenu = NSMenu(title: title)
        submenu.autoenablesItems = false
        for destination in destinations {
            submenu.addItem(ActionMenuItem(destination.name) { action?(application, destination.id) })
        }
        item.submenu = submenu
        return item
    }
}

@MainActor
private final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, enabled: Bool = true, action: @escaping () -> Void) {
        handler = action
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        target = self
        isEnabled = enabled
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func invoke() {
        let action = handler
        DispatchQueue.main.async { action() }
    }
}
