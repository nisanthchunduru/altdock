import AltdockCore
import AppKit
import Combine
import SwiftUI

@MainActor
final class DockContextMenuController: ObservableObject {
    private static var trackingWindows: Set<Int> = []
    weak var anchor: NSView?
    var edge = DockEdge.bottom
    var enabled = true
    var makeMenu: (() -> NSMenu)?
    private var activeMenu: NSMenu?

    static func isTracking(in window: NSWindow) -> Bool { trackingWindows.contains(window.windowNumber) }

    func show() {
        guard activeMenu == nil, enabled, let anchor, let owner = anchor.window,
              owner.isVisible, owner.isOnActiveSpace, !anchor.isHiddenOrHasHiddenAncestor,
              let screen = owner.screen, !anchor.visibleRect.isEmpty, let menu = makeMenu?(), !menu.items.isEmpty else { return }
        activeMenu = menu
        let number = owner.windowNumber
        Self.trackingWindows.insert(number)
        let center = NSWorkspace.shared.notificationCenter
        let observer = center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.cancel() }
        }
        defer {
            center.removeObserver(observer)
            Self.trackingWindows.remove(number)
            activeMenu = nil
        }
        menu.update()
        let rightToLeft = anchor.userInterfaceLayoutDirection == .rightToLeft
        menu.userInterfaceLayoutDirection = anchor.userInterfaceLayoutDirection
        let icon = owner.convertToScreen(anchor.convert(anchor.visibleRect, to: nil))
        let frame = DockContextMenuGeometry.frame(menuSize: menu.size, icon: icon, dock: owner.frame,
                                                  screen: screen.visibleFrame, edge: edge, rightToLeft: rightToLeft)
        let point = CGPoint(x: rightToLeft ? frame.maxX : frame.minX, y: frame.maxY)
        let local = anchor.convert(owner.convertPoint(fromScreen: point), from: nil)
        menu.popUp(positioning: nil, at: local, in: anchor)
    }

    func cancel() { activeMenu?.cancelTrackingWithoutAnimation() }
}

struct DockContextMenuAnchor: NSViewRepresentable {
    let controller: DockContextMenuController
    let edge: DockEdge
    var enabled = true
    let makeMenu: () -> NSMenu
    @Environment(\.isEnabled) private var isEnabled

    func makeNSView(context: Context) -> DockContextMenuView {
        let view = DockContextMenuView()
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: DockContextMenuView, context: Context) {
        if controller.edge != edge || !enabled || !isEnabled { controller.cancel() }
        controller.anchor = view
        controller.edge = edge
        controller.enabled = enabled && isEnabled
        controller.makeMenu = makeMenu
        view.controller = controller
    }

    static func dismantleNSView(_ view: DockContextMenuView, coordinator: ()) {
        view.controller?.cancel()
        view.controller?.anchor = nil
        view.controller?.makeMenu = nil
    }
}

final class DockContextMenuView: NSView {
    weak var controller: DockContextMenuController?

    static func handles(_ event: NSEvent?) -> Bool {
        guard let event else { return false }
        return event.type == .rightMouseDown || event.type == .leftMouseDown && event.modifierFlags.contains(.control)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard controller?.enabled == true, Self.handles(NSApp.currentEvent), super.hitTest(point) != nil else { return nil }
        return self
    }

    override func rightMouseDown(with event: NSEvent) { controller?.show() }
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { controller?.show() }
        else { super.mouseDown(with: event) }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow !== window { controller?.cancel() }
        super.viewWillMove(toWindow: newWindow)
    }
}
