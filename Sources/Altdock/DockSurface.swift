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
    func attach(to spaceID: UInt64) -> Bool
    func show()
    func hide()
    func close()
}

private final class DockPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class NativeDockSurface: DockSurface {
    private let panel: NSPanel
    private let presentation = DockPresentation()
    private let placement: SpacePanelPlacement
    private(set) var isOrdered = false

    var frame: CGRect { panel.frame }
    var isKeyWindow: Bool { panel.isKeyWindow }
    var windowNumber: Int { panel.windowNumber }

    init(spaceID: UInt64?, placement: SpacePanelPlacement, activate: @escaping (NSRunningApplication) -> Void) {
        self.placement = placement
        panel = DockPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
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
        let hostingView = NSHostingView(rootView: DockView(presentation: presentation, activate: activate))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
    }

    func update(applications: [DockApplication], isUpdating: Bool, layout: DockPanelLayout) {
        presentation.update(applications: applications, isUpdating: isUpdating, iconSize: layout.iconSize)
        if panel.frame != layout.frame {
            panel.setFrame(layout.frame, display: true)
            panel.contentView?.layoutSubtreeIfNeeded()
        }
    }

    func updateFocus(_ processID: Int32?) { presentation.updateFocus(processID) }
    func attach(to spaceID: UInt64) -> Bool { placement.attach(panel, to: spaceID) }

    func show() {
        guard !isOrdered else { return }
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        isOrdered = true
    }

    func hide() {
        guard isOrdered else { return }
        panel.orderOut(nil)
        isOrdered = false
    }

    func close() {
        panel.orderOut(nil)
        panel.close()
        isOrdered = false
    }
}
