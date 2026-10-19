import AltdockCore
import AppKit
import Combine
import Testing
@testable import Altdock

@Suite("Space transitions never publish an artificial empty dock")
@MainActor
struct DockModelTests {
    @Test("A cached destination is displayed synchronously without another window scan or empty list")
    func switchesFromCache() {
        let fixture = Fixture()
        defer { fixture.model.stop() }
        fixture.model.refresh()
        var publishedCounts: [Int] = []
        let subscription = fixture.model.$applications.sink { publishedCounts.append($0.count) }
        defer { subscription.cancel() }
        fixture.tracker.current = fixture.selection(spaceID: 200)

        fixture.model.spaceDidChange()

        #expect(fixture.tracker.refreshCount == 1)
        #expect(fixture.model.applications.map(\.id) == [fixture.application.processIdentifier])
        #expect(!publishedCounts.contains(0))
        #expect(!fixture.model.isSwitchingSpace)
    }

    @Test("A confirmed empty destination is shown immediately without a synthetic settling delay")
    func displaysKnownEmptySpace() {
        let fixture = Fixture()
        defer { fixture.model.stop() }
        fixture.model.refresh()
        fixture.tracker.current = SpaceWindowSelection(spaceID: 200, windows: [])

        fixture.model.spaceDidChange()

        #expect(fixture.model.applications.isEmpty)
        #expect(!fixture.model.isSwitchingSpace)
        #expect(fixture.tracker.refreshCount == 1)
    }

    @Test("An uncached destination clears the outgoing Space's icons and waits for discovery")
    func waitsForUnknownSpace() {
        let fixture = Fixture()
        defer { fixture.model.stop() }
        fixture.model.refresh()
        fixture.tracker.current = nil

        fixture.model.spaceDidChange()

        #expect(fixture.model.applications.isEmpty)
        #expect(fixture.model.isSwitchingSpace)
        fixture.model.activate(fixture.application)
        #expect(fixture.tracker.refreshCount == 1)
        fixture.tracker.current = fixture.selection(spaceID: 300)
        fixture.model.refresh()
        #expect(!fixture.model.isSwitchingSpace)
    }

    @Test("A destination's cached apps are displayed when its fresh window list is unavailable")
    func cachedDestinationWhileLoading() {
        let fixture = Fixture()
        defer { fixture.model.stop() }
        fixture.tracker.snapshots = [100: fixture.selection(spaceID: 100).windows, 200: fixture.selection(spaceID: 200).windows]
        fixture.model.refresh()
        fixture.tracker.current = nil
        fixture.tracker.destination = 200
        fixture.model.spaceDidChange()
        #expect(fixture.model.activeSpaceID == 200)
        #expect(fixture.model.applications.map(\.id) == [fixture.application.processIdentifier])
        #expect(fixture.model.isSwitchingSpace)
        #expect(fixture.tracker.refreshCount == 1)
    }

    @Test("An empty destination cache does not borrow icons from the previous Space")
    func emptyDestinationCache() {
        let fixture = Fixture()
        defer { fixture.model.stop() }
        fixture.tracker.snapshots = [100: fixture.selection(spaceID: 100).windows, 200: []]
        fixture.model.refresh()
        fixture.tracker.current = nil
        fixture.tracker.destination = 200
        fixture.model.spaceDidChange()
        #expect(fixture.model.activeSpaceID == 200)
        #expect(fixture.model.applications.isEmpty)
    }

    @Test("A failed all-Spaces refresh preserves previously cached app lists")
    func preservesCacheOnReadFailure() {
        let fixture = Fixture()
        defer { fixture.model.stop() }
        fixture.tracker.snapshots = [100: fixture.selection(spaceID: 100).windows]
        fixture.model.refresh()
        fixture.tracker.snapshots = nil
        fixture.tracker.current = nil
        fixture.tracker.destination = 100
        fixture.model.refresh()
        #expect(fixture.model.spaceApplications?[100]?.count == 1)
        #expect(fixture.model.applications.count == 1)
    }

    @Test("An outgoing Space's panel cannot activate an app after the active Space changes")
    func rejectsClicksFromAnotherSpace() {
        let fixture = Fixture()
        defer { fixture.model.stop() }
        fixture.model.refresh()
        fixture.tracker.current = fixture.selection(spaceID: 200)
        fixture.model.activate(fixture.application, expectedSpaceID: 100)
        #expect(fixture.activatedWindowIDs.isEmpty)
        fixture.model.activate(fixture.application, expectedSpaceID: 200)
        #expect(fixture.activatedWindowIDs == [1])
    }

    @Test("Public-API fallback does not mistake a transition's empty snapshot for an empty Space")
    func suppressesTransientEmptyFallback() {
        let fixture = Fixture()
        defer { fixture.model.stop() }
        fixture.model.refresh()
        fixture.tracker.usesSkyLight = false
        fixture.tracker.current = SpaceWindowSelection(spaceID: nil, windows: [])
        fixture.model.spaceDidChange()
        fixture.model.refresh()

        #expect(fixture.model.applications.isEmpty)
        #expect(fixture.model.isSwitchingSpace)
        fixture.clock.date = fixture.clock.date.addingTimeInterval(0.5)
        fixture.model.refresh()
        #expect(fixture.model.applications.isEmpty)
        #expect(!fixture.model.isSwitchingSpace)
    }

    @Test("Rapid Space changes select the latest cache entry rather than a delayed previous result")
    func coalescesRapidSwitches() {
        let fixture = Fixture()
        defer { fixture.model.stop() }
        fixture.model.refresh()
        fixture.tracker.current = fixture.selection(spaceID: 200)
        fixture.model.spaceDidChange()
        fixture.tracker.current = nil
        fixture.model.spaceDidChange()
        fixture.tracker.current = fixture.selection(spaceID: 100)
        fixture.model.spaceDidChange()

        #expect(fixture.model.applications.count == 1)
        #expect(!fixture.model.isSwitchingSpace)
        #expect(fixture.tracker.refreshCount == 1)
    }
}

@MainActor
private final class Fixture {
    let application = NSRunningApplication.current
    let tracker = FakeWindowTracker()
    let clock = TestClock()
    var activatedWindowIDs: [UInt32] = []
    lazy var model = DockModel(
        preferences: DockPreferences(), windowTracker: tracker,
        runningApplications: { [application] in [application] }, now: { [clock] in clock.date },
        displayBounds: { CGRect(x: 0, y: 0, width: 1440, height: 900) },
        activateApplication: { [weak self] _, windows in self?.activatedWindowIDs = windows.map(\.id) }
    )

    init() { tracker.current = selection(spaceID: 100) }

    func selection(spaceID: UInt64) -> SpaceWindowSelection {
        SpaceWindowSelection(spaceID: spaceID, windows: [
            SpaceWindow(id: 1, processID: application.processIdentifier, bounds: CGRect(x: 0, y: 0, width: 800, height: 600))
        ])
    }
}

@MainActor
private final class TestClock {
    var date = Date(timeIntervalSince1970: 1000)
}

@MainActor
private final class FakeWindowTracker: SpaceWindowTracking {
    var usesSkyLight = true
    var backendDescription: String { "Test cache" }
    var current: SpaceWindowSelection?
    var destination: UInt64?
    var snapshots: [UInt64: [SpaceWindow]]?
    var refreshCount = 0

    func refresh(regularProcessIDs: Set<Int32>) { refreshCount += 1 }
    func activeSpaceID(on displayBounds: CGRect) -> UInt64? { destination ?? current?.spaceID }
    func allSelections(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> [UInt64: [SpaceWindow]]? { snapshots }
    func selection(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> SpaceWindowSelection? { current }
}
