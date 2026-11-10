import CoreGraphics

public enum DockContextMenuGeometry {
    public static func frame(menuSize: CGSize, icon: CGRect, dock: CGRect, screen: CGRect, edge: DockEdge, rightToLeft: Bool = false) -> CGRect {
        let available = screen.insetBy(dx: 4, dy: 4)
        let width = min(max(0, menuSize.width), max(0, available.width))
        let height = min(max(0, menuSize.height), max(0, available.height))
        let gap: CGFloat = 6
        let origin: CGPoint
        switch edge {
        case .bottom:
            origin = CGPoint(x: rightToLeft ? icon.midX + 24 - width : icon.midX - 24, y: dock.maxY + gap)
        case .left:
            origin = CGPoint(x: dock.maxX + gap, y: icon.midY - height / 2)
        case .right:
            origin = CGPoint(x: dock.minX - gap - width, y: icon.midY - height / 2)
        }
        return CGRect(
            x: min(max(origin.x, available.minX), available.maxX - width),
            y: min(max(origin.y, available.minY), available.maxY - height),
            width: width, height: height
        )
    }
}
