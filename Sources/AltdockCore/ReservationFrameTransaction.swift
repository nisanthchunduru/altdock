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
            guard accepted, isHeightTransition(actual, from: original, to: target) else { break }
        }
        guard let actual = lastObserved,
              !ReservationGeometry.matches(actual, original),
              abs(actual.minX - original.minX) <= 2, abs(actual.minY - original.minY) <= 2,
              abs(actual.width - original.width) <= 2,
              let confirmed = read(), ReservationGeometry.matches(confirmed, actual) else { return false }
        _ = write(original)
        return false
    }

    private static func isHeightTransition(_ frame: CGRect, from original: CGRect, to target: CGRect) -> Bool {
        abs(frame.minX - original.minX) <= 2 && abs(frame.minY - original.minY) <= 2
            && abs(frame.width - original.width) <= 2
            && frame.height >= min(original.height, target.height) - 2
            && frame.height <= max(original.height, target.height) + 2
    }
}
