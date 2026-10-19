import CoreGraphics

public enum ReservationFrameTransaction {
    public static func apply(
        from original: CGRect, to target: CGRect,
        read: () -> CGRect?, write: (CGRect) -> Bool,
        waitForNextRead: () -> Void = {}
    ) -> Bool {
        guard let before = read(), ReservationGeometry.matches(before, original) else { return false }
        let accepted = write(target)
        var lastObserved: CGRect?
        for attempt in 0..<8 {
            if attempt > 0 { waitForNextRead() }
            guard let actual = read() else { continue }
            lastObserved = actual
            if accepted && ReservationGeometry.matches(actual, target) { return true }
            guard accepted, isFrameTransition(actual, from: original, to: target) else { break }
        }
        guard let actual = lastObserved,
              !ReservationGeometry.matches(actual, original),
              isFrameTransition(actual, from: original, to: target),
              let confirmed = read(), ReservationGeometry.matches(confirmed, actual) else { return false }
        _ = write(original)
        return false
    }

    private static func isFrameTransition(_ frame: CGRect, from original: CGRect, to target: CGRect) -> Bool {
        let observed = [frame.minX, frame.minY, frame.width, frame.height]
        let start = [original.minX, original.minY, original.width, original.height]
        let end = [target.minX, target.minY, target.width, target.height]
        return observed.indices.allSatisfy { observed[$0] >= min(start[$0], end[$0]) - 2 && observed[$0] <= max(start[$0], end[$0]) + 2 }
    }
}
