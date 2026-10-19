import CoreGraphics
import Foundation

public struct ReservationGeometry: Equatable, Sendable {
    public let display: CGRect
    public let visible: CGRect
    public let style: DockStyle
    public let limit: CGFloat

    public init(display: CGRect, visible: CGRect, style: DockStyle) {
        self.display = display
        self.visible = visible
        self.style = style
        let inset = style.footprint + DockGeometry.reservationClearance
        switch style.edge {
        case .bottom: limit = display.maxY - inset
        case .left: limit = display.minX + inset
        case .right: limit = display.maxX - inset
        }
    }

    public init(display: CGRect, visible: CGRect, preferredIconSize: CGFloat) {
        self.init(display: display, visible: visible, style: DockStyle(iconSize: preferredIconSize))
    }

    public func isClear(_ frame: CGRect) -> Bool {
        switch style.edge {
        case .bottom: frame.maxY <= limit + 2
        case .left: frame.minX >= limit - 2
        case .right: frame.maxX <= limit + 2
        }
    }

    public func target(for frame: CGRect) -> CGRect? {
        guard Self.isValid(frame), Self.isValid(visible), Self.isValid(display), !isClear(frame),
              frame.intersection(display).width * frame.intersection(display).height >= frame.width * frame.height * 0.5,
              frame.minX >= display.minX - 12, frame.maxX <= display.maxX + 12,
              frame.minY >= visible.minY - 12, frame.maxY <= display.maxY + 12,
              frame.width >= visible.width * 0.24, frame.height >= visible.height * 0.29 else { return nil }
        let top = abs(frame.minY - visible.minY) <= 12
        let bottom = abs(frame.maxY - visible.maxY) <= 12 || abs(frame.maxY - display.maxY) <= 12
        let left = abs(frame.minX - visible.minX) <= 12 || abs(frame.minX - display.minX) <= 12
        let right = abs(frame.maxX - visible.maxX) <= 12 || abs(frame.maxX - display.maxX) <= 12
        var target = frame
        switch style.edge {
        case .bottom:
            guard bottom && (top || left || right) else { return nil }
            target.size.height = limit - frame.minY
        case .left:
            guard left && (top || bottom || right) else { return nil }
            target.origin.x = limit
            target.size.width = frame.maxX - limit
        case .right:
            guard right && (top || bottom || left) else { return nil }
            target.size.width = limit - frame.minX
        }
        return target.width >= 160 && target.height >= 120 ? target : nil
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
