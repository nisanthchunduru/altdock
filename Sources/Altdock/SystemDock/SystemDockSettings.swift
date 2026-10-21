import AltdockCore
import Foundation

struct SystemDockSuppression: Codable, Equatable {
    let tileSize: Double?
    let autoHideDelay: Double?
}

struct SystemDockMinimization: Codable, Equatable {
    let effect: String?
}

struct SystemDockSettings: Codable, Equatable {
    let orientation: String?
    let autoHide: Bool?
    let suppression: SystemDockSuppression?
    let minimization: SystemDockMinimization?

    init(
        orientation: String?, autoHide: Bool?,
        suppression: SystemDockSuppression? = SystemDockSuppression(tileSize: nil, autoHideDelay: nil),
        minimization: SystemDockMinimization? = SystemDockMinimization(effect: nil)
    ) {
        self.orientation = orientation
        self.autoHide = autoHide
        self.suppression = suppression
        self.minimization = minimization
    }

    func preservingUncapturedPreferences(from current: SystemDockSettings) -> SystemDockSettings {
        SystemDockSettings(
            orientation: orientation, autoHide: autoHide,
            suppression: suppression ?? current.suppression, minimization: minimization ?? current.minimization
        )
    }

    static func parked(replacing original: SystemDockSettings) -> SystemDockSettings {
        let edge = DockEdge(rawValue: original.orientation ?? "bottom") ?? .bottom
        return SystemDockSettings(
            orientation: edge.rawValue, autoHide: true,
            suppression: SystemDockSuppression(tileSize: 1, autoHideDelay: 1000),
            minimization: SystemDockMinimization(effect: "scale")
        )
    }
}
