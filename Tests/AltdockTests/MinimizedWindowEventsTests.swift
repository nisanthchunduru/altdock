import Foundation
import Testing
@testable import Altdock

@Suite("Minimization events are observed once per app with safe fallback and cleanup")
@MainActor
struct MinimizedWindowEventsTests {
    @Test("Stable processes reuse observers, while minimize/restore notifications deliver changes")
    func reusesObservers() {
        let fixture = EventFixture()
        defer { fixture.events.stop() }
        fixture.start()
        fixture.events.update(processIDs: [1, 2])
        fixture.events.update(processIDs: [1, 2])
        #expect(fixture.observers.count == 2)
        fixture.observers[0].changed?()
        fixture.observers[1].changed?()
        #expect(fixture.changes == 2)
    }

    @Test("Missing Accessibility never creates observers or prompts and can recover when permission is granted")
    func missingPermission() {
        let fixture = EventFixture()
        defer { fixture.events.stop() }
        fixture.trusted = false
        fixture.start()
        fixture.events.update(processIDs: [1])
        #expect(fixture.observers.isEmpty)
        fixture.trusted = true
        fixture.events.update(processIDs: [1])
        #expect(fixture.observers.count == 1)
        fixture.trusted = false
        fixture.events.update(processIDs: [1])
        #expect(fixture.observers[0].stopped)
    }

    @Test("A newly launched app gets an early retry instead of waiting five seconds for AX to become ready")
    func retriesWithBackoff() {
        let fixture = EventFixture()
        defer { fixture.events.stop() }
        fixture.supported = false
        fixture.start()
        fixture.events.update(processIDs: [1])
        fixture.time = 0.1
        fixture.events.update(processIDs: [1])
        #expect(fixture.observers.count == 1)
        #expect(fixture.observers[0].stopped)
        fixture.time = 0.25
        fixture.supported = true
        fixture.events.update(processIDs: [1])
        #expect(fixture.observers.count == 2)
        fixture.observers[1].changed?()
        #expect(fixture.changes == 1)
    }

    @Test("Repeated subscription failures back off to a five-second retry interval")
    func capsRetries() {
        let fixture = EventFixture()
        defer { fixture.events.stop() }
        fixture.supported = false
        fixture.start()
        for time in [0.0, 0.25, 0.75, 1.75, 3.75, 7.75] {
            fixture.time = time
            fixture.events.update(processIDs: [1])
        }
        #expect(fixture.observers.count == 6)
        fixture.time = 12
        fixture.events.update(processIDs: [1])
        #expect(fixture.observers.count == 6)
        fixture.time = 12.75
        fixture.events.update(processIDs: [1])
        #expect(fixture.observers.count == 7)
    }

    @Test("Removing and reusing a PID does not admit stale callbacks from the old observer")
    func processLifecycle() {
        let fixture = EventFixture()
        defer { fixture.events.stop() }
        fixture.start()
        fixture.events.update(processIDs: [1])
        let old = fixture.observers[0].changed
        fixture.events.update(processIDs: [])
        fixture.events.update(processIDs: [1])
        old?()
        #expect(fixture.changes == 0)
        fixture.observers[1].changed?()
        #expect(fixture.changes == 1)
    }

    @Test("Stop removes all observers and ignores updates and late callbacks until restarted")
    func stopsCleanly() {
        let fixture = EventFixture()
        fixture.start()
        fixture.events.update(processIDs: [1])
        let old = fixture.observers[0].changed
        fixture.events.stop()
        old?()
        fixture.events.update(processIDs: [2])
        #expect(fixture.changes == 0)
        #expect(fixture.observers.count == 1)
        #expect(fixture.observers[0].stopped)
    }
}

@MainActor
private final class EventFixture {
    var trusted = true
    var supported = true
    var time = 0.0
    var changes = 0
    var observers: [FakeMinimizedObserver] = []
    lazy var events = MinimizedWindowEvents(makeObserver: { [unowned self] in
        let observer = FakeMinimizedObserver(supported: supported)
        observers.append(observer)
        return observer
    }, trusted: { [unowned self] in trusted }, now: { [unowned self] in time })
    func start() { events.start { [unowned self] in changes += 1 } }
}

@MainActor
private final class FakeMinimizedObserver: MinimizedApplicationObserving {
    let supported: Bool
    var stopped = false
    var changed: (@MainActor @Sendable () -> Void)?
    init(supported: Bool) { self.supported = supported }
    func start(processID: Int32, changed: @escaping @MainActor @Sendable () -> Void) -> Bool {
        self.changed = changed
        return supported
    }
    func stop() { stopped = true; changed = nil }
}
