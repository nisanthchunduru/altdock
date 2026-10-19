import AppKit
import ApplicationServices
import ServiceManagement

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let preferences: DockPreferences
    private let dock: DockPanelController
    private let model: DockModel
    private let reservation: WindowReservationController
    private let statusItem: NSStatusItem

    init(preferences: DockPreferences, dock: DockPanelController, model: DockModel, reservation: WindowReservationController) {
        self.preferences = preferences
        self.dock = dock
        self.model = model
        self.reservation = reservation
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
        menu.addItem(NSMenuItem(title: model.trackingDescription, action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        addItem(dock.isEnabled ? "Hide Altdock" : "Show Altdock", action: #selector(toggleDock), to: menu)
        addItem("Automatically Hide", action: #selector(toggleAutoHide), checked: preferences.autoHide, to: menu)
        addItem("Reserve Space", action: #selector(toggleReservation), checked: preferences.reserveSpace, to: menu)
        if preferences.reserveSpace && !reservation.hasAccessibility {
            addItem(reservation.status, action: #selector(openAccessibility), to: menu)
        } else {
            menu.addItem(NSMenuItem(title: reservation.status, action: nil, keyEquivalent: ""))
        }

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
            AXIsProcessTrusted() ? "Accessibility Enabled…" : "Grant Accessibility Access…",
            action: #selector(openAccessibility), to: menu
        )
        addItem("Reservation Diagnostics…", action: #selector(showReservationDiagnostics), to: menu)
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

    @objc private func toggleReservation() {
        preferences.reserveSpace.toggle()
        if preferences.reserveSpace && !AXIsProcessTrusted() { openAccessibility() }
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

    @objc private func showReservationDiagnostics() {
        NSWorkspace.shared.activateFileViewerSelecting([ReservationDiagnostics.fileURL])
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Altdock"
        alert.informativeText = "Your Space. Your apps. Less noise.\n\nAltdock caches window membership across Spaces using private SkyLight APIs, with an on-screen fallback. Click to switch; right-click for Open, Hide, and Quit.\n\nReserve Space is on by default. Grant Accessibility to let Altdock shorten maximized/tiled windows above the dock. Floating and full-screen windows are left alone. Reservation pauses when Altdock is hidden or auto-hide is on.\n\nWhile Altdock runs, the system Dock is moved to the right with auto-hide enabled. Its original position and auto-hide setting are restored on exit; a recovery helper also handles crashes."
        alert.addButton(withTitle: "Got It")
        alert.runModal()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
