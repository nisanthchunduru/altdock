import CoreGraphics
import Foundation

public enum DockGeometry {
    public static let bottomMargin: CGFloat = 8
    public static let reservationClearance: CGFloat = 4

    public static func panelHeight(iconSize: CGFloat) -> CGFloat { iconSize + 18 }

    public static func contentSize(applicationCount: Int, style: DockStyle) -> CGSize {
        let cell = DockIconLayout(style: style, isActive: false).size
        let cellLength = style.edge.isVertical ? cell.height : cell.width
        let length = applicationCount == 0 ? 24
            : CGFloat(applicationCount) * cellLength + CGFloat(applicationCount - 1) * DockIconLayout.spacing + 24
        return style.edge.isVertical
            ? CGSize(width: style.panelThickness, height: length)
            : CGSize(width: length, height: style.panelThickness)
    }

    public static func frame(contentSize: CGSize, visibleFrame: CGRect, screenFrame: CGRect, edge: DockEdge = .bottom) -> CGRect {
        if edge.isVertical {
            let height = min(contentSize.height, max(0, visibleFrame.height - 24))
            return CGRect(
                x: edge == .left ? screenFrame.minX + bottomMargin : screenFrame.maxX - bottomMargin - contentSize.width,
                y: visibleFrame.midY - height / 2, width: contentSize.width, height: height
            )
        }
        let width = min(contentSize.width, max(0, visibleFrame.width - 24))
        return CGRect(x: visibleFrame.midX - width / 2, y: screenFrame.minY + bottomMargin, width: width, height: contentSize.height)
    }

    public static func revealZone(panel: CGRect, screen: CGRect, edge: DockEdge) -> CGRect {
        switch edge {
        case .bottom: CGRect(x: panel.minX, y: screen.minY, width: panel.width, height: 4)
        case .left: CGRect(x: screen.minX, y: panel.minY, width: 4, height: panel.height)
        case .right: CGRect(x: screen.maxX - 4, y: panel.minY, width: 4, height: panel.height)
        }
    }

    public static func travelZone(panel: CGRect, screen: CGRect, edge: DockEdge) -> CGRect {
        switch edge {
        case .bottom: CGRect(x: panel.minX - 10, y: screen.minY, width: panel.width + 20, height: panel.maxY - screen.minY + 10)
        case .left: CGRect(x: screen.minX, y: panel.minY - 10, width: panel.maxX - screen.minX + 10, height: panel.height + 20)
        case .right: CGRect(x: panel.minX - 10, y: panel.minY - 10, width: screen.maxX - panel.minX + 10, height: panel.height + 20)
        }
    }
}
