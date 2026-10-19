import AltdockCore
import AppKit

@MainActor
final class DockPresentation: ObservableObject {
    @Published private(set) var applications: [DockApplication] = []
    @Published private(set) var activeProcessID: Int32?
    @Published private(set) var isUpdating = false
    @Published private(set) var iconSize: CGFloat = 52

    func update(applications: [DockApplication], isUpdating: Bool, iconSize: CGFloat) {
        if self.applications.map(\.id) != applications.map(\.id) { self.applications = applications }
        if self.isUpdating != isUpdating { self.isUpdating = isUpdating }
        if self.iconSize != iconSize { self.iconSize = iconSize }
    }

    func updateFocus(_ processID: Int32?) {
        if activeProcessID != processID { activeProcessID = processID }
    }
}

struct DockDisplay: Equatable {
    let id: UInt32
    let frame: CGRect
    let visibleFrame: CGRect

    func layout(applicationCount: Int, preferredIconSize: CGFloat) -> DockPanelLayout {
        let size = DockGeometry.iconSize(
            preferred: preferredIconSize, applicationCount: applicationCount,
            availableWidth: visibleFrame.width - 24
        )
        let width = applicationCount == 0 ? 264 : CGFloat(applicationCount) * (size + 12) + 18
        return DockPanelLayout(
            frame: DockGeometry.frame(contentSize: CGSize(width: width, height: DockGeometry.panelHeight(iconSize: size)), visibleFrame: visibleFrame, screenFrame: frame),
            iconSize: size
        )
    }
}

struct DockPanelLayout: Equatable {
    let frame: CGRect
    let iconSize: CGFloat
}
