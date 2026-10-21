import AltdockCore
import Foundation

struct SystemDockSuppression: Codable, Equatable {
    let tileSize: Double?
    let autoHideDelay: Double?
}

struct SystemDockSettings: Codable, Equatable {
    let orientation: String?
    let autoHide: Bool?
    let suppression: SystemDockSuppression?

    init(
        orientation: String?, autoHide: Bool?,
        suppression: SystemDockSuppression? = SystemDockSuppression(tileSize: nil, autoHideDelay: nil)
    ) {
        self.orientation = orientation
        self.autoHide = autoHide
        self.suppression = suppression
    }

    func preservingUncapturedSuppression(from current: SystemDockSettings) -> SystemDockSettings {
        SystemDockSettings(orientation: orientation, autoHide: autoHide, suppression: suppression ?? current.suppression)
    }

    static func parked(replacing original: SystemDockSettings) -> SystemDockSettings {
        let edge = DockEdge(rawValue: original.orientation ?? "bottom") ?? .bottom
        return SystemDockSettings(
            orientation: edge.parkedSystemEdge.rawValue, autoHide: true,
            suppression: SystemDockSuppression(tileSize: 1, autoHideDelay: 1000)
        )
    }
}
