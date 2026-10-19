import CoreGraphics
import Foundation

public struct ReservationGeometry: Equatable, Sendable {
    public let display: CGRect
    public let visible: CGRect
    public let bottomLimit: CGFloat

    public init(display: CGRect, visible: CGRect, preferredIconSize: CGFloat) {
        self.display = display
        self.visible = visible
        bottomLimit = display.maxY - DockGeometry.panelHeight(iconSize: preferredIconSize)
            - DockGeometry.bottomMargin - DockGeometry.reservationClearance
    }

    public func target(for frame: CGRect) -> CGRect? {
        guard Self.isValid(frame), Self.isValid(visible),
              frame.intersection(display).width * frame.intersection(display).height >= frame.width * frame.height * 0.5,
              frame.minX >= visible.minX - 12, frame.maxX <= visible.maxX + 12,
              frame.minY >= visible.minY - 12,
              abs(frame.maxY - visible.maxY) <= 12 || abs(frame.maxY - display.maxY) <= 12,
              frame.width >= visible.width * 0.24, frame.height >= visible.height * 0.29,
              abs(frame.minY - visible.minY) <= 12 || abs(frame.minX - visible.minX) <= 12 || abs(frame.maxX - visible.maxX) <= 12,
              frame.maxY > bottomLimit + 2, bottomLimit - frame.minY >= 120 else { return nil }
        return CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: bottomLimit - frame.minY)
    }

    public static func matches(_ left: CGRect, _ right: CGRect) -> Bool {
        abs(left.minX - right.minX) <= 2 && abs(left.minY - right.minY) <= 2
            && abs(left.width - right.width) <= 2 && abs(left.height - right.height) <= 2
    }

    private static func isValid(_ frame: CGRect) -> Bool {
        frame.minX.isFinite && frame.minY.isFinite && frame.width.isFinite && frame.height.isFinite
            && frame.width > 0 && frame.height > 0
    }
}
