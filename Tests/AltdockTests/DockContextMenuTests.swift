import AltdockCore
import AppKit
import Testing
@testable import Altdock

@Suite("Native Dock context menus preserve actions and normal icon interaction")
@MainActor
struct DockContextMenuTests {
    @Test("Only right-click and Control-click are intercepted; ordinary clicks and drags pass through")
    func routesOnlyContextClicks() throws {
        _ = NSApplication.shared
        for (type, modifiers, expected): (NSEvent.EventType, NSEvent.ModifierFlags, Bool) in [
            (.rightMouseDown, [], true), (.leftMouseDown, .control, true),
            (.leftMouseDown, [], false), (.leftMouseDragged, [], false), (.mouseMoved, [], false)
        ] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: .zero, modifierFlags: modifiers, timestamp: 0,
                                                       windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            #expect(DockContextMenuView.handles(event) == expected)
        }
        #expect(!DockContextMenuView.handles(nil))
    }

    @Test("All app actions and both Desktop submenus retain their labels and availability")
    func appMenu() {
        _ = NSApplication.shared
        let application = DockApplication(application: .current)
        let menu = DockContextMenus.application(application, destinations: [.init(id: 100, number: 2)], isBusy: false,
            activate: {}, createWindow: { _ in }, moveFocusedWindow: { _, _ in }, moveWindows: { _, _ in })
        #expect(menu.items.map(\.title) == [application.name, "", "Open", "New Window", "Move Focused Window", "Move", "Hide", "", "Quit"])
        #expect(menu.item(withTitle: "Move")?.submenu?.items.map(\.title) == ["Desktop 2"])
        #expect(menu.item(withTitle: "Move Focused Window")?.isEnabled == true)
        #expect(menu.item(withTitle: "New Window")?.isEnabled == true)
    }

    @Test("Busy or unsupported actions stay disabled instead of being re-enabled by AppKit validation")
    func disabledActions() {
        _ = NSApplication.shared
        for busy in [false, true] {
            let menu = DockContextMenus.application(DockApplication(application: .current), destinations: [], isBusy: busy,
                activate: {}, createWindow: busy ? { _ in } : nil, moveFocusedWindow: nil, moveWindows: nil)
            #expect(!menu.autoenablesItems)
            #expect(menu.item(withTitle: "New Window")?.isEnabled == false)
            #expect(menu.item(withTitle: "Move")?.isEnabled == false)
            #expect(menu.item(withTitle: "Move Focused Window")?.isEnabled == false)
            #expect(menu.item(withTitle: "Open")?.isEnabled == true)
        }
    }

    @Test("A native submenu invokes the selected focused-window destination, not the all-window action")
    func dispatchesFocusedMove() async {
        _ = NSApplication.shared
        await withCheckedContinuation { continuation in
            let menu = DockContextMenus.application(DockApplication(application: .current), destinations: [.init(id: 200, number: 2)], isBusy: false,
                activate: {}, createWindow: nil, moveFocusedWindow: { _, destination in
                    #expect(destination == 200)
                    continuation.resume()
                }, moveWindows: { _, _ in Issue.record("Wrong move scope") })
            menu.item(withTitle: "Move Focused Window")!.submenu!.performActionForItem(at: 0)
        }
    }

    @Test("The minimized-window menu restores the selected tile")
    func dispatchesRestore() async {
        _ = NSApplication.shared
        let window = DockMinimizedWindow(application: .current, window: SpaceWindow(id: 7, processID: NSRunningApplication.current.processIdentifier,
            bounds: CGRect(x: 0, y: 0, width: 500, height: 400), isMinimized: true, title: "Budget"))
        await withCheckedContinuation { continuation in
            let menu = DockContextMenus.minimizedWindow(window) { continuation.resume() }
            #expect(menu.items.map(\.title) == ["Budget", "", "Restore"])
            menu.performActionForItem(at: 2)
        }
    }

    @Test("An absent or disabled anchor never opens a menu")
    func missingAnchor() {
        let controller = DockContextMenuController()
        var built = false
        controller.makeMenu = { built = true; return NSMenu() }
        controller.show()
        #expect(!built)
        controller.enabled = false
        controller.show()
        #expect(!built)
    }
}
