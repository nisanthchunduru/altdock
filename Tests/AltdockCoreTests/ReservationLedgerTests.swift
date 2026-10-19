import AltdockCore
import CoreGraphics
import Testing

@Suite("Window adjustments do not fight user placement or tiling managers")
struct ReservationLedgerTests {
    private let id = ReservationWindowID(processID: 10, windowID: 20)
    private let original = CGRect(x: 0, y: 25, width: 1440, height: 875)
    private var geometry: ReservationGeometry {
        ReservationGeometry(display: CGRect(x: 0, y: 0, width: 1440, height: 900), visible: original, preferredIconSize: 52)
    }

    @Test("Self-generated resize notifications produce no additional writes")
    func suppressesOwnEvents() throws {
        var ledger = ReservationLedger()
        let proposed = ledger.target(for: id, frame: original, geometry: geometry, now: 0)
        let target = try #require(proposed)
        ledger.didApply(target, to: id, original: original, now: 0)
        #expect(ledger.target(for: id, frame: target, geometry: geometry, now: 10) == nil)
    }

    @Test("A competing window manager gets only one retry, not an endless resize loop")
    func boundsRetries() throws {
        var ledger = ReservationLedger()
        let target = try #require(geometry.target(for: original))
        ledger.didApply(target, to: id, original: original, now: 0)
        #expect(ledger.target(for: id, frame: original, geometry: geometry, now: 0.2) == nil)
        #expect(ledger.target(for: id, frame: original, geometry: geometry, now: 1) == target)
        ledger.didApply(target, to: id, original: original, now: 1)
        #expect(ledger.target(for: id, frame: original, geometry: geometry, now: 100) == nil)
    }

    @Test("Original geometry is restored only if the window still matches Altdock's adjustment")
    func guardedRestoration() throws {
        var ledger = ReservationLedger()
        let target = try #require(geometry.target(for: original))
        ledger.didApply(target, to: id, original: original, now: 0)
        #expect(ledger.restoration(for: id, current: target) == original)
        #expect(ledger.restoration(for: id, current: target.offsetBy(dx: 100, dy: 0)) == nil)
    }

    @Test("Manual changes cancel the stored restoration rather than snapping the window back")
    func yieldsToManualChanges() throws {
        var ledger = ReservationLedger()
        let target = try #require(geometry.target(for: original))
        ledger.didApply(target, to: id, original: original, now: 0)
        let manual = CGRect(x: 100, y: 100, width: 800, height: 600)
        #expect(ledger.target(for: id, frame: manual, geometry: geometry, now: 1) == nil)
        #expect(ledger.restoration(for: id, current: target) == nil)
    }

    @Test("Unsupported windows are not retried until they leave the managed layout")
    func suppressesRefusedWrites() {
        var ledger = ReservationLedger()
        ledger.suppress(id)
        #expect(ledger.target(for: id, frame: original, geometry: geometry, now: 1) == nil)
        #expect(ledger.target(for: id, frame: CGRect(x: 100, y: 100, width: 500, height: 400), geometry: geometry, now: 2) == nil)
        #expect(ledger.target(for: id, frame: original, geometry: geometry, now: 3) != nil)
    }

    @Test("A transient write failure is retried instead of suppressing the window forever")
    func retriesTransientFailures() {
        var ledger = ReservationLedger()
        ledger.didFail(id, now: 0)
        #expect(ledger.target(for: id, frame: original, geometry: geometry, now: 0.5) == nil)
        #expect(ledger.target(for: id, frame: original, geometry: geometry, now: 1.1) != nil)
        ledger.didFail(id, now: 1.1)
        ledger.didFail(id, now: 2.2)
        #expect(ledger.target(for: id, frame: original, geometry: geometry, now: 5) == nil)
    }

    @Test("Separate user maximizations are not counted as a lifetime two-adjustment limit")
    func repeatedUserMaximizations() throws {
        var ledger = ReservationLedger()
        for interaction in UInt64(1)...5 {
            let proposed = ledger.target(for: id, frame: original, geometry: geometry, now: Double(interaction) * 10, interaction: interaction)
            let target = try #require(proposed)
            ledger.didApply(target, to: id, original: original, now: Double(interaction) * 10)
        }
    }

    @Test("An unrelated click without a layout change does not restart a competing-manager loop")
    func ignoresClicksWithoutLayoutChanges() throws {
        var ledger = ReservationLedger()
        let proposed = ledger.target(for: id, frame: original, geometry: geometry, now: 0, interaction: 1)
        let target = try #require(proposed)
        ledger.didApply(target, to: id, original: original, now: 0)
        #expect(ledger.target(for: id, frame: original, geometry: geometry, now: 1, interaction: 1) != nil)
        ledger.didApply(target, to: id, original: original, now: 1)
        #expect(ledger.target(for: id, frame: original, geometry: geometry, now: 2, interaction: 1) == nil)
        #expect(ledger.target(for: id, frame: original, geometry: geometry, now: 3, interaction: 2) == nil)
    }

    @Test("Closed windows lose their restoration state")
    func removesClosedWindows() throws {
        var ledger = ReservationLedger()
        let target = try #require(geometry.target(for: original))
        ledger.didApply(target, to: id, original: original, now: 0)
        ledger.retain(liveIDs: [])
        #expect(ledger.adjustments.isEmpty)
    }
}
