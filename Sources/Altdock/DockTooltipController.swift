import AltdockCore
import AppKit

@MainActor
final class DockTooltipController {
    private let panel: NSPanel
    private let content = DockTooltipContent()
    private var name = ""
    private weak var anchor: NSView?
    private var edge = DockEdge.bottom
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var spaceObserver: NSObjectProtocol?
    private var menuIsTracking = false

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isExcludedFromWindowsMenu = true
        panel.collectionBehavior = [.fullScreenAuxiliary, .ignoresCycle]
        panel.animationBehavior = .none
        panel.title = "Altdock app name"
        panel.contentView = content
        observers.append(NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.menuIsTracking = true; self?.hide() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.menuIsTracking = false }
        })
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    func show(name: String, edge: DockEdge, anchor: NSView) {
        guard !menuIsTracking, let owner = anchor.window, owner.isVisible, owner.isOnActiveSpace else { return }
        if self.anchor !== anchor { hide() }
        self.anchor = anchor
        self.edge = edge
        self.name = name
        panel.appearance = owner.effectiveAppearance
        panel.level = NSWindow.Level(rawValue: owner.level.rawValue + 1)
        refresh()
        guard self.anchor != nil else { return }
        if panel.parent !== owner { owner.addChildWindow(panel, ordered: .above) }
        if !panel.isVisible { panel.orderFrontRegardless() }
        if timer == nil {
            let timer = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func hide(for view: NSView) {
        if anchor === view { hide() }
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        anchor = nil
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
    }

    func stop() {
        hide()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        spaceObserver = nil
        panel.close()
    }

    private func refresh() {
        guard let anchor, let owner = anchor.window, owner.isVisible, owner.isOnActiveSpace,
              !anchor.isHiddenOrHasHiddenAncestor, let screen = owner.screen else { hide(); return }
        let visible = anchor.visibleRect
        guard !visible.isEmpty else { hide(); return }
        let iconFrame = owner.convertToScreen(anchor.convert(visible, to: nil))
        guard iconFrame.contains(NSEvent.mouseLocation) else { hide(); return }
        let size = content.preferredSize(name: name, availableWidth: max(1, screen.visibleFrame.width - 12))
        let frame = DockTooltipGeometry.frame(labelSize: size, icon: iconFrame, dock: owner.frame, screen: screen.visibleFrame, edge: edge)
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        content.needsLayout = true
        content.layoutSubtreeIfNeeded()
    }
}
