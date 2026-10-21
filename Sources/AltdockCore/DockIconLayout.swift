import CoreGraphics

public struct DockIconLayout: Equatable, Sendable {
    public static let spacing: CGFloat = 6
    public let size: CGSize
    public let icon: CGRect
    public let indicator: CGRect

    public init(style: DockStyle, isActive: Bool) {
        size = style.edge.isVertical
            ? CGSize(width: style.panelThickness, height: style.iconSize + 6)
            : CGSize(width: style.iconSize + 6, height: style.panelThickness)
        icon = CGRect(
            x: (size.width - style.iconSize) / 2, y: (size.height - style.iconSize) / 2,
            width: style.iconSize, height: style.iconSize
        )
        let length: CGFloat = isActive ? 10 : 4
        let thickness: CGFloat = 4
        switch style.edge {
        case .bottom:
            indicator = CGRect(
                x: icon.midX - length / 2, y: (icon.maxY + size.height - thickness) / 2,
                width: length, height: thickness
            )
        case .left:
            indicator = CGRect(
                x: (icon.minX - thickness) / 2, y: icon.midY - length / 2,
                width: thickness, height: length
            )
        case .right:
            indicator = CGRect(
                x: (icon.maxX + size.width - thickness) / 2, y: icon.midY - length / 2,
                width: thickness, height: length
            )
        }
    }
}
