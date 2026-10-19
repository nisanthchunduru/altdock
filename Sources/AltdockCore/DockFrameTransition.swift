import CoreGraphics
import Foundation

public struct DockFrameTransition: Sendable {
    public private(set) var target: CGRect?
    public private(set) var isAnimating = false
    private var start = CGRect.zero
    private var startedAt: TimeInterval = 0
    private var duration: TimeInterval = 0

    public init() {}

    public mutating func setTarget(_ frame: CGRect, current: CGRect, at time: TimeInterval, duration: TimeInterval) {
        if target == frame && isAnimating && duration > 0 { return }
        target = frame
        start = current
        startedAt = time
        self.duration = max(0, duration)
        isAnimating = duration > 0 && current != frame
    }

    public mutating func frame(at time: TimeInterval) -> CGRect? {
        guard let target else { return nil }
        guard isAnimating else { return target }
        let progress = min(1, max(0, (time - startedAt) / duration))
        if progress >= 1 { isAnimating = false; return target }
        let eased = progress * progress * (3 - 2 * progress)
        return CGRect(
            x: start.minX + (target.minX - start.minX) * eased,
            y: start.minY + (target.minY - start.minY) * eased,
            width: start.width + (target.width - start.width) * eased,
            height: start.height + (target.height - start.height) * eased
        )
    }

    public mutating func finish() -> CGRect? {
        isAnimating = false
        return target
    }
}
