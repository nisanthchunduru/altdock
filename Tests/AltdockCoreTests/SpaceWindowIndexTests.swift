import AltdockCore
import CoreGraphics
import Testing

@Suite("Cached window membership across Spaces")
struct SpaceWindowIndexTests {
    private let first = SpaceWindow(id: 1, processID: 10, bounds: CGRect(x: 10, y: 10, width: 800, height: 600))
    private let second = SpaceWindow(id: 2, processID: 20, bounds: CGRect(x: 10, y: 10, width: 800, height: 600), isOnScreen: false)

    @Test("Preloads off-screen windows on Spaces that have not been visited")
    func preloadsOtherSpaces() {
        let index = SpaceWindowIndex(windows: [first, second], membership: [1: [100], 2: [200]], knownSpaceIDs: [100, 200])
        #expect(index.windows(in: 100) == [first])
        #expect(index.windows(in: 200) == [second])
    }

    @Test("Distinguishes a known empty Space from an unknown Space")
    func distinguishesUnknownAndEmptySpaces() {
        let index = SpaceWindowIndex(windows: [], membership: [:], knownSpaceIDs: [100])
        #expect(index.windows(in: 100) == [])
        #expect(index.windows(in: 200) == nil)
    }

    @Test("A window assigned to multiple Spaces appears in each membership list")
    func indexesSharedWindows() {
        let index = SpaceWindowIndex(windows: [first], membership: [1: [100, 200]], knownSpaceIDs: [100, 200])
        #expect(index.windows(in: 100) == [first])
        #expect(index.windows(in: 200) == [first])
    }

    @Test("Windows without Space membership do not become phantom dock icons")
    func excludesUnassignedWindows() {
        let index = SpaceWindowIndex(windows: [first, second], membership: [1: []], knownSpaceIDs: [100])
        #expect(index.windows(in: 100) == [])
    }

    @Test("Reconciliation removes closed windows, moved windows, and deleted Spaces")
    func replacesStaleMembership() {
        var index = SpaceWindowIndex(windows: [first, second], membership: [1: [100], 2: [200]], knownSpaceIDs: [100, 200])
        index = SpaceWindowIndex(windows: [second], membership: [2: [100]], knownSpaceIDs: [100])
        #expect(index.windows(in: 100) == [second])
        #expect(index.windows(in: 200) == nil)
        #expect(index.spaceIDs == [100])
    }

    @Test("Space-aware filtering includes off-screen members but still excludes other displays")
    func filtersMappedWindowsByDisplay() {
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let anotherDisplay = SpaceWindow(id: 3, processID: 20, bounds: CGRect(x: 2000, y: 0, width: 800, height: 600), isOnScreen: false)
        #expect(SpaceApplications.windows(
            from: [second, anotherDisplay], regularProcessIDs: [20], excluding: 99,
            on: display, requiringOnScreen: false
        ) == [second])
        #expect(SpaceApplications.windows(
            from: [second], regularProcessIDs: [20], excluding: 99, on: display
        ).isEmpty)
    }

    @Test("All-Spaces scans still reject overlays, invisible helpers, and the dock itself")
    func preservesEligibilityRules() {
        let overlay = SpaceWindow(id: 3, processID: 20, bounds: first.bounds, layer: 3)
        let transparent = SpaceWindow(id: 4, processID: 20, bounds: first.bounds, alpha: 0)
        #expect(SpaceApplications.windows(
            from: [first, overlay, transparent], regularProcessIDs: [10, 20], excluding: 10,
            on: .infinite, requiringOnScreen: false
        ).isEmpty)
    }
}
