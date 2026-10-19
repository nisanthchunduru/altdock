import AppKit
import ApplicationServices
import ServiceManagement

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let preferences: DockPreferences
    private let dock: DockPanelController
    private let model: DockModel
    private let statusItem: NSStatusItem

    init(preferences: DockPreferences, dock: DockPanelController, model: DockModel) {
        self.preferences = preferences
        self.dock = dock
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.bottomthird.inset.filled", accessibilityDescription: "Altdock")
        statusItem.button?.toolTip = "Altdock — your current Space"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let heading = NSMenuItem(title: "Altdock · Current Space", action: nil, keyEquivalent: "")
        menu.addItem(heading)
        menu.addItem(.separator())
        addItem(dock.isEnabled ? "Hide Altdock" : "Show Altdock", action: #selector(toggleDock), to: menu)
        addItem("Automatically Hide", action: #selector(toggleAutoHide), checked: preferences.autoHide, to: menu)

        let sizes = NSMenu()
        for (title, size) in [("Small", 40), ("Medium", 52), ("Large", 64)] {
            let item = addItem(title, action: #selector(setIconSize(_:)), checked: preferences.iconSize == Double(size), to: sizes)
            item.tag = size
        }
        let sizeItem = NSMenuItem(title: "Icon Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizes
        menu.addItem(sizeItem)

        let displays = NSMenu()
        for screen in NSScreen.screens {
            let item = addItem(screen.localizedName, action: #selector(setDisplay(_:)), checked: preferences.screen == screen, to: displays)
            item.representedObject = screen.displayID
        }
        let displayItem = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
        displayItem.submenu = displays
        menu.addItem(displayItem)

        menu.addItem(.separator())
        addItem("Launch at Login", action: #selector(toggleLaunchAtLogin), checked: SMAppService.mainApp.status == .enabled, to: menu)
        addItem(
            AXIsProcessTrusted() ? "Accessibility Enabled…" : "Enable Precise Window Switching…",
            action: #selector(openAccessibility), to: menu
        )
        addItem("About Altdock", action: #selector(showAbout), to: menu)
        menu.addItem(.separator())
        let quitItem = addItem("Quit Altdock", action: #selector(quit), to: menu)
        quitItem.keyEquivalent = "q"
    }

    @discardableResult
    private func addItem(_ title: String, action: Selector, checked: Bool = false, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = checked ? .on : .off
        menu.addItem(item)
        return item
    }

    @objc private func toggleDock() {
        if dock.isEnabled { dock.isEnabled = false } else { dock.reveal() }
    }

    @objc private func toggleAutoHide() {
        preferences.autoHide.toggle()
        dock.reveal()
    }

    @objc private func setIconSize(_ sender: NSMenuItem) {
        preferences.iconSize = Double(sender.tag)
    }

    @objc private func setDisplay(_ sender: NSMenuItem) {
        guard let displayID = sender.representedObject as? CGDirectDisplayID else { return }
        preferences.displayID = displayID
        model.refresh()
        dock.reveal()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            switch SMAppService.mainApp.status {
            case .enabled: try SMAppService.mainApp.unregister()
            case .requiresApproval: SMAppService.openSystemSettingsLoginItems()
            default: try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.informativeText += "\nRun the bundled Altdock.app from Applications to use Launch at Login."
            alert.runModal()
        }
    }

    @objc private func openAccessibility() {
        if !AXIsProcessTrusted() { ApplicationActivator.requestAccessibility() }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Altdock"
        alert.informativeText = "Your Space. Your apps. Less noise.\n\nAltdock shows apps with non-minimized windows in the active Space on the selected display. Click to switch; right-click for Open, Hide, and Quit.\n\nUse the menu-bar icon for size, display, auto-hide, and login settings. Optional Accessibility access helps focus the current-Space window when an app spans multiple Spaces.\n\nAltdock never changes Apple’s Dock settings. For more room, enable automatically hiding the system Dock in System Settings → Desktop & Dock."
        alert.addButton(withTitle: "Got It")
        alert.runModal()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
