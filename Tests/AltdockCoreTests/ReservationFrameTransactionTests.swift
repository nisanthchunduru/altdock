import AltdockCore
import CoreGraphics
import Testing

@Suite("Accessibility writes are checked and partial resizes are rolled back")
struct ReservationFrameTransactionTests {
    private let original = CGRect(x: 0, y: 25, width: 1000, height: 875)
    private let target = CGRect(x: 0, y: 25, width: 1000, height: 782)

    @Test("An intervening frame change prevents the write")
    func staleRead() {
        var writes = 0
        let result = ReservationFrameTransaction.apply(from: original, to: target, read: { target }) { _ in writes += 1; return true }
        #expect(!result)
        #expect(writes == 0)
    }

    @Test("Successful setters still require read-back verification")
    func verifiesActualFrame() {
        var current = original
        let result = ReservationFrameTransaction.apply(from: original, to: target, read: { current }) { current = $0; return true }
        #expect(result)
        #expect(current == target)
    }

    @Test("An animated resize may first report the old frame before reaching the target")
    func waitsForAnimatedResize() {
        var current = original
        var waits = 0
        var writes: [CGRect] = []
        let result = ReservationFrameTransaction.apply(
            from: original, to: target, read: { current },
            write: { writes.append($0); return true },
            waitForNextRead: {
                waits += 1
                current = waits < 3 ? CGRect(x: 0, y: 25, width: 1000, height: 840) : target
            }
        )
        #expect(result)
        #expect(writes == [target])
        #expect(waits == 3)
    }

    @Test("Transient missing verification frames are retried, not treated as permanent refusal")
    func retriesMissingVerificationRead() {
        var reads = 0
        let result = ReservationFrameTransaction.apply(
            from: original, to: target,
            read: {
                reads += 1
                if reads == 1 { return original }
                return reads < 4 ? nil : target
            }, write: { _ in true }
        )
        #expect(result)
        #expect(reads == 4)
    }

    @Test("A window that never settles has a bounded verification budget")
    func boundedVerification() {
        var waits = 0
        let result = ReservationFrameTransaction.apply(
            from: original, to: target, read: { original }, write: { _ in true },
            waitForNextRead: { waits += 1 }
        )
        #expect(!result)
        #expect(waits == 7)
    }

    @Test("An app's minimum-size clamp is rolled back instead of accepted as success")
    func minimumSizeRollback() {
        var current = original
        var writes: [CGRect] = []
        let result = ReservationFrameTransaction.apply(from: original, to: target, read: { current }) {
            writes.append($0)
            current = $0 == target ? CGRect(x: 0, y: 25, width: 1000, height: 820) : $0
            return true
        }
        #expect(!result)
        #expect(writes == [target, original])
        #expect(current == original)
    }

    @Test("Unexpected movement is preserved rather than blindly rolled back")
    func preservesExternalMove() {
        var current = original
        var count = 0
        let manual = original.offsetBy(dx: 50, dy: 50)
        let result = ReservationFrameTransaction.apply(from: original, to: target, read: { current }) { _ in
            count += 1
            current = manual
            return true
        }
        #expect(!result)
        #expect(current == manual)
        #expect(count == 1)
    }
}
