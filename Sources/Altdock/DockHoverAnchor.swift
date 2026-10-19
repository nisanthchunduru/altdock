import AltdockCore
import AppKit
import SwiftUI

struct DockHoverAnchor: NSViewRepresentable {
    let name: String
    let edge: DockEdge
    let enabled: Bool
    let tooltip: DockTooltipController

    func makeNSView(context: Context) -> DockHoverTrackingView { DockHoverTrackingView() }

    func updateNSView(_ view: DockHoverTrackingView, context: Context) {
        view.name = name
        view.edge = edge
        view.tooltip = tooltip
        view.enabled = enabled
        if !enabled { tooltip.hide(for: view) }
    }

    static func dismantleNSView(_ view: DockHoverTrackingView, coordinator: ()) {
        view.tooltip?.hide(for: view)
    }
}

final class DockHoverTrackingView: NSView {
    var name = ""
    var edge = DockEdge.bottom
    var enabled = true
    weak var tooltip: DockTooltipController?
    private var area: NSTrackingArea?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved], owner: self)
        addTrackingArea(area)
        self.area = area
    }

    override func mouseEntered(with event: NSEvent) { showTooltip() }
    override func mouseMoved(with event: NSEvent) { showTooltip() }
    override func mouseExited(with event: NSEvent) { tooltip?.hide(for: self) }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow !== window { tooltip?.hide(for: self) }
        super.viewWillMove(toWindow: newWindow)
    }

    private func showTooltip() {
        guard enabled else { return }
        tooltip?.show(name: name, edge: edge, anchor: self)
    }
}
