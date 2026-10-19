import CoreGraphics
import Foundation

public enum DockGeometry {
    public static func iconSize(preferred: Double, applicationCount: Int, availableWidth: Double) -> Double {
        guard applicationCount > 0 else { return preferred }
        let fittingSize = (availableWidth - 24) / Double(applicationCount) - 12
        return max(24, min(preferred, fittingSize))
    }

    public static func frame(contentSize: CGSize, visibleFrame: CGRect, screenFrame: CGRect) -> CGRect {
        let width = min(contentSize.width, max(0, visibleFrame.width - 24))
        return CGRect(
            x: visibleFrame.midX - width / 2,
            y: max(screenFrame.minY + 8, visibleFrame.minY + 8),
            width: width,
            height: contentSize.height
        )
    }
}
