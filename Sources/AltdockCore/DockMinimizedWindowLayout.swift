import CoreGraphics

public struct DockMinimizedWindowLayout: Equatable, Sendable {
    public let preview: CGRect
    public let separator: CGRect

    public init(style: DockStyle, precedingIconTrailingInset: CGFloat = 0) {
        let layout = DockIconLayout(style: style, isActive: false)
        preview = layout.icon.insetBy(dx: style.iconSize * 0.05, dy: style.iconSize * 0.15)
        let length = style.iconSize * 0.65
        let thickness: CGFloat = 1
        if style.edge.isVertical {
            let previousIconEnd = layout.icon.maxY - layout.size.height - DockIconLayout.spacing - precedingIconTrailingInset
            separator = CGRect(
                x: layout.icon.midX - length / 2,
                y: (previousIconEnd + preview.minY - thickness) / 2,
                width: length, height: thickness
            )
        } else {
            let previousIconEnd = layout.icon.maxX - layout.size.width - DockIconLayout.spacing - precedingIconTrailingInset
            separator = CGRect(
                x: (previousIconEnd + preview.minX - thickness) / 2,
                y: layout.icon.midY - length / 2,
                width: thickness, height: length
            )
        }
    }
}
