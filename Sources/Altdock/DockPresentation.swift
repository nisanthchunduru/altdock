import AltdockCore
import AppKit

@MainActor
final class DockPresentation: ObservableObject {
    @Published private(set) var applications: [DockApplication] = []
    @Published private(set) var activeProcessID: Int32?
    @Published private(set) var isUpdating = false
    @Published private(set) var style = DockStyle()
    @Published private(set) var destinations: [DesktopDestination] = []
    var iconSize: CGFloat { style.iconSize }

    func update(applications: [DockApplication], isUpdating: Bool, style: DockStyle) {
        if self.applications.map(\.id) != applications.map(\.id) { self.applications = applications }
        if self.isUpdating != isUpdating { self.isUpdating = isUpdating }
        if self.style != style { self.style = style }
    }

    func updateDestinations(_ destinations: [DesktopDestination]) {
        if self.destinations != destinations { self.destinations = destinations }
    }

    func updateFocus(_ processID: Int32?) {
        if activeProcessID != processID { activeProcessID = processID }
    }
}

struct DockDisplay: Equatable {
    let id: UInt32
    let frame: CGRect
    let visibleFrame: CGRect

    func layout(applicationCount: Int, style: DockStyle) -> DockPanelLayout {
        DockPanelLayout(
            frame: DockGeometry.frame(
                contentSize: DockGeometry.contentSize(applicationCount: applicationCount, style: style),
                visibleFrame: visibleFrame, screenFrame: frame, edge: style.edge
            ), style: style
        )
    }
}

struct DockPanelLayout: Equatable {
    let frame: CGRect
    let style: DockStyle
}
