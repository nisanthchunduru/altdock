import CoreGraphics

public enum DockTooltipGeometry {
    public static func frame(labelSize: CGSize, icon: CGRect, dock: CGRect, screen: CGRect, edge: DockEdge) -> CGRect {
        let bounds = screen.insetBy(dx: 6, dy: 6)
        let width = min(labelSize.width, max(0, bounds.width))
        let height = min(labelSize.height, max(0, bounds.height))
        let origin: CGPoint
        switch edge {
        case .bottom: origin = CGPoint(x: icon.midX - width / 2, y: dock.maxY + 8)
        case .left: origin = CGPoint(x: dock.maxX + 8, y: icon.midY - height / 2)
        case .right: origin = CGPoint(x: dock.minX - width - 8, y: icon.midY - height / 2)
        }
        return CGRect(
            x: max(bounds.minX, min(origin.x, bounds.maxX - width)),
            y: max(bounds.minY, min(origin.y, bounds.maxY - height)),
            width: width, height: height
        )
    }
}
