import AltdockCore
import AppKit
import SwiftUI

@MainActor
protocol DockSurface: AnyObject {
    var frame: CGRect { get }
    var isOrdered: Bool { get }
    var isKeyWindow: Bool { get }
    var windowNumber: Int { get }
    func update(applications: [DockApplication], isUpdating: Bool, layout: DockPanelLayout)
    func updateFocus(_ processID: Int32?)
    func updateDestinations(_ destinations: [DesktopDestination])
    func attach(to spaceID: UInt64) -> Bool
    func show()
    func hide()
    func close()
}

extension DockSurface {
    func updateDestinations(_ destinations: [DesktopDestination]) {}
}

private final class DockPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class NativeDockSurface: DockSurface {
    private let panel: NSPanel
    private let frameAnimator: DockFrameAnimator
    private let presentation = DockPresentation()
    private let tooltip = DockTooltipController()
    private let placement: SpacePanelPlacement
    private let isSpaceBound: Bool
    private var lastLayout: DockPanelLayout?
    private(set) var isOrdered = false

    var frame: CGRect { panel.frame }
    var isKeyWindow: Bool { panel.isKeyWindow }
    var windowNumber: Int { panel.windowNumber }

    init(spaceID: UInt64?, placement: SpacePanelPlacement, moveWindows: ((NSRunningApplication, UInt64) -> Void)? = nil, activate: @escaping (NSRunningApplication) -> Void) {
        self.placement = placement
        isSpaceBound = spaceID != nil
        panel = DockPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        frameAnimator = DockFrameAnimator(panel: panel)
        panel.title = spaceID.map { "Altdock — Space \($0)" } ?? "Altdock"
        panel.level = .floating
        panel.collectionBehavior = spaceID == nil
            ? [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            : [.managed, .fullScreenAuxiliary, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = true
        panel.animationBehavior = .none
        panel.alphaValue = 0
        let hostingView = NSHostingView(rootView: DockView(presentation: presentation, tooltip: tooltip, activate: activate, moveWindows: moveWindows))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
    }

    func update(applications: [DockApplication], isUpdating: Bool, layout: DockPanelLayout) {
        if isUpdating || presentation.applications.map(\.id) != applications.map(\.id) || lastLayout != layout { tooltip.hide() }
        if applications.isEmpty { hide() }
        let animate = DockMembershipAnimation.shouldAnimate(
            previousIDs: presentation.applications.map(\.id), nextIDs: applications.map(\.id),
            previousLayout: lastLayout, nextLayout: layout,
            isSpaceBound: isSpaceBound, isOrdered: isOrdered, isOnActiveSpace: panel.isOnActiveSpace,
            wasUpdating: presentation.isUpdating, isUpdating: isUpdating,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        var transaction = Transaction(animation: animate ? DockMembershipAnimation.animation : nil)
        transaction.disablesAnimations = !animate
        withTransaction(transaction) {
            presentation.update(applications: applications, isUpdating: isUpdating, style: layout.style)
        }
        let frameChanged = lastLayout?.frame != layout.frame
        lastLayout = layout
        if frameChanged { frameAnimator.move(to: layout.frame, animated: animate) }
        else { frameAnimator.reconcile() }
    }

    func updateDestinations(_ destinations: [DesktopDestination]) { presentation.updateDestinations(destinations) }

    func updateFocus(_ processID: Int32?) {
        frameAnimator.reconcile()
        presentation.updateFocus(processID)
    }
    func attach(to spaceID: UInt64) -> Bool { placement.attach(panel, to: spaceID) }

    func show() {
        frameAnimator.reconcile()
        guard !presentation.applications.isEmpty else { hide(); return }
        guard !isOrdered else { return }
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        isOrdered = true
    }

    func hide() {
        tooltip.hide()
        frameAnimator.finish()
        guard isOrdered else { return }
        panel.orderOut(nil)
        isOrdered = false
    }

    func close() {
        tooltip.stop()
        frameAnimator.finish()
        panel.orderOut(nil)
        panel.close()
        isOrdered = false
    }
}
