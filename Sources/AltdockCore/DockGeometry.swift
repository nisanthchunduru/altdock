import CoreGraphics
import Foundation

public enum DockGeometry {
    public static let bottomMargin: CGFloat = 8
    public static let reservationClearance: CGFloat = 4

    public static func panelHeight(iconSize: CGFloat) -> CGFloat { iconSize + 29 }

    public static func iconSize(preferred: Double, applicationCount: Int, availableWidth: Double) -> Double {
        guard applicationCount > 0 else { return preferred }
        let fittingSize = (availableWidth - 24) / Double(applicationCount) - 12
        return max(24, min(preferred, fittingSize))
    }

    public static func frame(contentSize: CGSize, visibleFrame: CGRect, screenFrame: CGRect) -> CGRect {
        let width = min(contentSize.width, max(0, visibleFrame.width - 24))
        return CGRect(
            x: visibleFrame.midX - width / 2,
            y: screenFrame.minY + bottomMargin,
            width: width,
            height: contentSize.height
        )
    }
}
