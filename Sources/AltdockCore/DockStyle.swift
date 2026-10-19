import CoreGraphics
import Foundation

public enum DockEdge: String, Codable, CaseIterable, Sendable {
    case bottom, left, right

    public var isVertical: Bool { self != .bottom }
    public var parkedSystemEdge: DockEdge { self == .right ? .bottom : .right }
}

public struct DockStyle: Codable, Equatable, Sendable {
    public let edge: DockEdge
    public let iconSize: CGFloat
    public let footprint: CGFloat

    public init(edge: DockEdge = .bottom, iconSize: CGFloat = 64, footprint: CGFloat? = nil) {
        self.edge = edge
        self.iconSize = iconSize.isFinite ? min(128, max(16, iconSize)) : 64
        let proposed = footprint ?? self.iconSize + 26
        self.footprint = proposed.isFinite && proposed >= self.iconSize + 23 && proposed <= self.iconSize + 48
            ? proposed : self.iconSize + 26
    }

    public var panelThickness: CGFloat { footprint - DockGeometry.bottomMargin }
}
