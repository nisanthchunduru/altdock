import AltdockCore
import CoreGraphics
import Testing
@testable import Altdock

@Suite("Space discovery excludes ordered-out windows, not inactive Spaces")
@MainActor
struct SpaceWindowTrackerTests {
    private let display = CGRect(x: 0, y: 0, width: 3008, height: 1692)
    private let firstBrowser = SpaceWindow(id: 1, processID: 101, bounds: CGRect(x: 0, y: 30, width: 3008, height: 1557), isOnScreen: true)
    private let secondBrowser = SpaceWindow(id: 2, processID: 102, bounds: CGRect(x: 0, y: 30, width: 3008, height: 1557), isOnScreen: false)
    private let firstAuxiliary = SpaceWindow(id: 3, processID: 101, bounds: CGRect(x: 2243, y: 102, width: 415, height: 84), isOnScreen: false)
    private let secondAuxiliary = SpaceWindow(id: 4, processID: 102, bounds: CGRect(x: 2482, y: 102, width: 403, height: 84), isOnScreen: false)

    @Test("Two Chrome processes with only ordered-out helpers on Desktop 2 produce no icons there")
    func excludesPhantomChromeIcons() throws {
        let spaces = WindowOrderingFixture()
        let tracker = SpaceWindowTracker(spaces: spaces) { _ in [firstBrowser, secondBrowser, firstAuxiliary, secondAuxiliary] }
        tracker.refresh(regularProcessIDs: [101, 102])
        let selections = try #require(tracker.allSelections(on: display, regularProcessIDs: [101, 102]))
        #expect(selections[100] == [firstBrowser])
        #expect(selections[200] == [])
        #expect(selections[300] == [secondBrowser])
        #expect(tracker.usesSkyLight)
        #expect(spaces.membershipQueries == [1, 2])
        spaces.active = 200
        #expect(tracker.selection(on: display, regularProcessIDs: [101, 102])?.windows == [])
    }

    @Test("An ordered-in browser on an inactive Space stays cached before and after activation")
    func retainsInactiveSpaceWindows() {
        let spaces = WindowOrderingFixture()
        let tracker = SpaceWindowTracker(spaces: spaces) { _ in [secondBrowser] }
        tracker.refresh(regularProcessIDs: [102])
        #expect(tracker.index?.windows(in: 300) == [secondBrowser])
        spaces.active = 300
        #expect(tracker.selection(on: display, regularProcessIDs: [102])?.windows == [secondBrowser])
    }

    @Test("Small ordered-in windows remain eligible; window height is not a helper heuristic")
    func retainsSmallOrderedWindows() {
        let spaces = WindowOrderingFixture()
        spaces.ordering[3] = true
        let tracker = SpaceWindowTracker(spaces: spaces) { _ in [firstAuxiliary] }
        tracker.refresh(regularProcessIDs: [101])
        #expect(tracker.index?.windows(in: 200) == [firstAuxiliary])
    }

    @Test("Refreshing removes a formerly ordered-in helper from its cached Space")
    func refreshRemovesOrderedOutWindows() {
        let spaces = WindowOrderingFixture()
        spaces.ordering[3] = true
        let tracker = SpaceWindowTracker(spaces: spaces) { _ in [firstAuxiliary] }
        tracker.refresh(regularProcessIDs: [101])
        #expect(tracker.index?.windows(in: 200)?.count == 1)
        spaces.ordering[3] = false
        tracker.refresh(regularProcessIDs: [101])
        #expect(tracker.index?.windows(in: 200) == [])
    }

    @Test("An ordering query failure falls back to public on-screen windows instead of guessing")
    func failedOrderingQuery() {
        let spaces = WindowOrderingFixture()
        spaces.ordering.removeValue(forKey: 2)
        var snapshots: [CGWindowListOption] = []
        let tracker = SpaceWindowTracker(spaces: spaces) { options in
            snapshots.append(options)
            return options.contains(.optionOnScreenOnly) ? [firstBrowser] : [firstBrowser, secondBrowser]
        }
        tracker.refresh(regularProcessIDs: [101, 102])
        #expect(!tracker.usesSkyLight)
        #expect(snapshots.count == 2)
        #expect(tracker.selection(on: display, regularProcessIDs: [101, 102])?.windows == [firstBrowser])
        #expect(tracker.allSelections(on: display, regularProcessIDs: [101, 102]) == nil)
    }

    @Test("Unavailable private APIs preserve the existing public on-screen fallback")
    func unavailablePrivateAPI() {
        let tracker = SpaceWindowTracker(spaces: nil) { options in
            #expect(options.contains(.optionOnScreenOnly))
            return [firstBrowser]
        }
        tracker.refresh(regularProcessIDs: [101])
        #expect(tracker.selection(on: display, regularProcessIDs: [101])?.windows == [firstBrowser])
    }

    @Test("An ordered-in window assigned to multiple Spaces remains in each one")
    func retainsAllDesktopWindows() {
        let spaces = WindowOrderingFixture()
        spaces.membership[1] = [100, 200, 300]
        let tracker = SpaceWindowTracker(spaces: spaces) { _ in [firstBrowser] }
        tracker.refresh(regularProcessIDs: [101])
        for id: UInt64 in [100, 200, 300] { #expect(tracker.index?.windows(in: id) == [firstBrowser]) }
    }
}

@MainActor
private final class WindowOrderingFixture: SpaceQuerying {
    var active: UInt64 = 100
    var ordering: [UInt32: Bool] = [1: true, 2: true, 3: false, 4: false]
    var membership: [UInt32: Set<UInt64>] = [1: [100], 2: [300], 3: [200], 4: [200]]
    var membershipQueries: [UInt32] = []

    func allSpaceIDs() -> Set<UInt64>? { [100, 200, 300] }
    func spaceIDs(on displayBounds: CGRect) -> Set<UInt64>? { allSpaceIDs() }
    func activeSpaceID(on displayBounds: CGRect) -> UInt64? { active }
    func isWindowOrderedIn(_ windowID: UInt32) -> Bool? { ordering[windowID] }
    func spaceIDs(for windowID: UInt32) -> Set<UInt64>? {
        membershipQueries.append(windowID)
        return membership[windowID]
    }
}
