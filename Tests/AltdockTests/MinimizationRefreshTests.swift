import AltdockCore
import AppKit
import Testing
@testable import Altdock

@Suite("Minimized tiles refresh promptly without waiting for the periodic scan", .serialized)
@MainActor
struct MinimizationRefreshTests {
    @Test("A burst of minimization notifications causes one prompt discovery refresh")
    func refreshesAfterEvent() async throws {
        let fixture = RefreshFixture()
        fixture.model.start()
        defer { fixture.model.stop() }
        let initial = fixture.tracker.refreshes
        fixture.tracker.minimized = true
        for _ in 0..<5 { fixture.events.changed?() }
        #expect(fixture.tracker.refreshes == initial)
        try await Task.sleep(for: .milliseconds(50))
        #expect(fixture.tracker.refreshes == initial + 1)
        #expect(fixture.model.minimizedWindows.map(\.window.id) == [1])
    }

    @Test("A refresh already triggered by another event consumes the pending minimization refresh")
    func avoidsDuplicateRefresh() async throws {
        let fixture = RefreshFixture()
        fixture.model.start()
        defer { fixture.model.stop() }
        let initial = fixture.tracker.refreshes
        fixture.events.changed?()
        fixture.model.refresh()
        try await Task.sleep(for: .milliseconds(50))
        #expect(fixture.tracker.refreshes == initial + 1)
    }

    @Test("Quitting cancels a queued minimization refresh and ignores late events")
    func cancelsOnStop() async throws {
        let fixture = RefreshFixture()
        fixture.model.start()
        let initial = fixture.tracker.refreshes
        let callback = fixture.events.changed
        callback?()
        fixture.model.stop()
        callback?()
        try await Task.sleep(for: .milliseconds(50))
        #expect(fixture.tracker.refreshes == initial)
        #expect(fixture.events.stopped)
    }
}

@MainActor
private final class RefreshFixture {
    let tracker = RefreshTracker()
    let events = RefreshEvents()
    lazy var model = DockModel(preferences: DockPreferences(), windowTracker: tracker,
        runningApplications: { [.current] }, displayBounds: { CGRect(x: 0, y: 0, width: 1440, height: 900) },
        minimizedWindowEvents: events)
}

@MainActor
private final class RefreshEvents: MinimizedWindowObserving {
    var changed: (() -> Void)?
    var stopped = false
    func start(changed: @escaping () -> Void) { self.changed = changed }
    func update(processIDs: Set<Int32>) {}
    func stop() { changed = nil; stopped = true }
}

@MainActor
private final class RefreshTracker: SpaceWindowTracking {
    let usesSkyLight = true
    let backendDescription = "Fixture"
    var refreshes = 0
    var minimized = false
    func refresh(regularProcessIDs: Set<Int32>) { refreshes += 1 }
    func activeSpaceID(on displayBounds: CGRect) -> UInt64? { 100 }
    func selection(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> SpaceWindowSelection? {
        SpaceWindowSelection(spaceID: 100, windows: [SpaceWindow(id: 1, processID: NSRunningApplication.current.processIdentifier,
            bounds: CGRect(x: 10, y: 10, width: 800, height: 600), isMinimized: minimized, title: "Fixture")])
    }
    func allSelections(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> [UInt64: [SpaceWindow]]? {
        [100: selection(on: displayBounds, regularProcessIDs: regularProcessIDs)!.windows]
    }
}
