import AltdockCore
import CoreGraphics
import Testing
@testable import Altdock

@Suite("Minimized windows keep their app on the correct Desktop without admitting auxiliary windows")
@MainActor
struct MinimizedWindowTrackingTests {
    @Test("An app whose only real window is minimized is included, but its ordered-out helper is excluded")
    func includesMinimizedWindow() {
        let fixture = MinimizedFixture()
        fixture.refresh()
        #expect(fixture.tracker.index?.windows(in: 100)?.map(\.id) == [1, 2])
        #expect(fixture.reader.calls == [42: [1, 3]])
        #expect(fixture.spaces.membershipQueries == [1, 2])
    }

    @Test("A window already minimized at startup is discovered on its own Desktop, not whichever Desktop is active")
    func preservesDesktopScope() {
        let fixture = MinimizedFixture()
        fixture.spaces.membership[1] = [200]
        fixture.refresh()
        #expect(fixture.tracker.selection(on: fixture.display, regularProcessIDs: [42, 43])?.windows.map(\.id) == [2])
        #expect(fixture.tracker.allSelections(on: fixture.display, regularProcessIDs: [42, 43])?[200]?.map(\.id) == [1])
        fixture.spaces.active = 200
        #expect(fixture.tracker.selection(on: fixture.display, regularProcessIDs: [42, 43])?.windows.map(\.id) == [1])
    }

    @Test("Minimized windows on a different display do not create local icons")
    func preservesDisplayScope() {
        let fixture = MinimizedFixture()
        fixture.windows[0] = SpaceWindow(id: 1, processID: 42, bounds: CGRect(x: 1800, y: 0, width: 800, height: 600), isOnScreen: false)
        fixture.refresh()
        #expect(fixture.tracker.selection(on: fixture.display, regularProcessIDs: [42, 43])?.windows.map(\.id) == [2])
    }

    @Test("Missing Accessibility or an unknown first read never promotes ordered-out helpers into icons")
    func unknownMinimization() {
        for ids: Set<UInt32>? in [nil, []] {
            let fixture = MinimizedFixture()
            fixture.reader.minimized = ids
            fixture.refresh()
            #expect(fixture.tracker.index?.windows(in: 100)?.map(\.id) == [2])
        }
    }

    @Test("A transient AX failure retains previously confirmed minimized windows without blocking other apps' discovery")
    func preservesConfirmationDuringReadFailure() {
        let fixture = MinimizedFixture()
        fixture.refresh()
        fixture.reader.minimized = nil
        fixture.spaces.membership[2] = [200]
        fixture.refresh()
        #expect(fixture.tracker.index?.windows(in: 100)?.map(\.id) == [1])
        #expect(fixture.tracker.index?.windows(in: 200)?.map(\.id) == [2])
    }

    @Test("Restoring a minimized window keeps the same icon without querying minimization for ordered-in windows")
    func restoresOrderedWindow() {
        let fixture = MinimizedFixture()
        fixture.refresh()
        fixture.spaces.ordering[1] = true
        fixture.reader.minimized = []
        fixture.reader.calls = [:]
        fixture.refresh()
        #expect(fixture.tracker.index?.windows(in: 100)?.map(\.id) == [1, 2])
        #expect(fixture.reader.calls == [42: [3]])
    }

    @Test("Successful non-minimized results remove old confirmation; merely hidden windows are not included")
    func clearsOldConfirmation() {
        let fixture = MinimizedFixture()
        fixture.refresh()
        fixture.reader.minimized = []
        fixture.refresh()
        #expect(fixture.tracker.index?.windows(in: 100)?.map(\.id) == [2])
    }

    @Test("A closed window loses its remembered minimized status even if the app still has an ordered-out helper")
    func discardsClosedWindows() {
        let fixture = MinimizedFixture()
        fixture.refresh()
        fixture.windows.removeFirst()
        fixture.reader.minimized = nil
        fixture.refresh()
        #expect(fixture.tracker.index?.windows(in: 100)?.map(\.id) == [2])
    }

    @Test("A different process cannot inherit another window's remembered minimized status")
    func requiresProcessIdentity() {
        let fixture = MinimizedFixture()
        fixture.refresh()
        fixture.windows[0] = SpaceWindow(id: 1, processID: 44, bounds: fixture.display, isOnScreen: false)
        fixture.reader.minimized = nil
        fixture.refresh(processIDs: [43, 44])
        #expect(fixture.tracker.index?.windows(in: 100)?.map(\.id) == [2])
    }

    @Test("Reader results are intersected with requested candidates instead of trusting unrelated window IDs")
    func rejectsUnrequestedWindows() {
        let fixture = MinimizedFixture()
        fixture.reader.minimized = [99]
        fixture.refresh()
        #expect(fixture.tracker.index?.windows(in: 100)?.map(\.id) == [2])
    }
}

@MainActor
private final class MinimizedFixture {
    let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let spaces = MinimizedSpaces()
    let reader = FakeMinimizedReader()
    lazy var windows = [
        SpaceWindow(id: 1, processID: 42, bounds: CGRect(x: 10, y: 10, width: 800, height: 600), isOnScreen: false),
        SpaceWindow(id: 2, processID: 43, bounds: CGRect(x: 10, y: 10, width: 800, height: 600)),
        SpaceWindow(id: 3, processID: 42, bounds: CGRect(x: 10, y: 10, width: 400, height: 84), isOnScreen: false)
    ]
    lazy var tracker = SpaceWindowTracker(spaces: spaces, minimizedWindows: reader, captureWindows: { [unowned self] _ in windows })
    func refresh(processIDs: Set<Int32> = [42, 43]) { tracker.refresh(regularProcessIDs: processIDs) }
}

@MainActor
private final class FakeMinimizedReader: MinimizedWindowReading {
    var minimized: Set<UInt32>? = [1]
    var calls: [Int32: Set<UInt32>] = [:]
    func minimizedWindows(processID: Int32, candidates: Set<UInt32>) -> [MinimizedWindowInfo]? {
        calls[processID] = candidates
        return minimized?.map { MinimizedWindowInfo(id: $0, title: "Window \($0)") }
    }
}

@MainActor
private final class MinimizedSpaces: SpaceQuerying {
    var active: UInt64 = 100
    var membership: [UInt32: Set<UInt64>] = [1: [100], 2: [100], 3: [100]]
    var ordering: [UInt32: Bool] = [1: false, 2: true, 3: false]
    var membershipQueries: [UInt32] = []
    func allSpaceIDs() -> Set<UInt64>? { [100, 200] }
    func spaceIDs(on displayBounds: CGRect) -> Set<UInt64>? { [100, 200] }
    func activeSpaceID(on displayBounds: CGRect) -> UInt64? { active }
    func isWindowOrderedIn(_ windowID: UInt32) -> Bool? { ordering[windowID] }
    func spaceIDs(for windowID: UInt32) -> Set<UInt64>? {
        membershipQueries.append(windowID)
        return membership[windowID]
    }
}
