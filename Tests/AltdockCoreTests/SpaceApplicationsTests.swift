import AltdockCore
import CoreGraphics
import Testing

@Suite("Applications in the current Space")
struct SpaceApplicationsTests {
    private let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let windowBounds = CGRect(x: 100, y: 100, width: 800, height: 600)

    @Test("Includes regular applications with windows on the selected display")
    func includesRegularApplications() {
        let window = SpaceWindow(id: 1, processID: 10, bounds: windowBounds)
        #expect(filtered([window]) == [window])
    }

    @Test("Excludes off-screen windows, including other Spaces and minimized windows")
    func excludesOffScreenWindows() {
        let window = SpaceWindow(id: 1, processID: 10, bounds: windowBounds, isOnScreen: false)
        #expect(filtered([window]).isEmpty)
    }

    @Test("Excludes desktop overlays and floating panels")
    func excludesOtherWindowLayers() {
        let windows = [-1, 3, 20].map {
            SpaceWindow(id: UInt32($0 + 2), processID: 10, bounds: windowBounds, layer: $0)
        }
        #expect(filtered(windows).isEmpty)
    }

    @Test("Excludes transparent and empty windows")
    func excludesInvisibleWindows() {
        let windows = [
            SpaceWindow(id: 1, processID: 10, bounds: windowBounds, alpha: 0),
            SpaceWindow(id: 2, processID: 10, bounds: .zero),
            SpaceWindow(id: 3, processID: 10, bounds: CGRect(x: 0, y: 0, width: 1, height: 1))
        ]
        #expect(filtered(windows).isEmpty)
    }

    @Test("Excludes Altdock and non-regular applications")
    func excludesOwnProcessAndAgents() {
        let windows = [
            SpaceWindow(id: 1, processID: 99, bounds: windowBounds),
            SpaceWindow(id: 2, processID: 500, bounds: windowBounds)
        ]
        #expect(filtered(windows).isEmpty)
    }

    @Test("Excludes windows on another display")
    func excludesOtherDisplays() {
        let window = SpaceWindow(id: 1, processID: 10, bounds: CGRect(x: 1500, y: 0, width: 800, height: 600))
        #expect(filtered([window]).isEmpty)
    }

    @Test("Includes windows spanning the selected display")
    func includesSpanningWindows() {
        let window = SpaceWindow(id: 1, processID: 10, bounds: CGRect(x: 1400, y: 0, width: 800, height: 600))
        #expect(filtered([window]) == [window])
    }

    @Test("Supports displays with negative coordinates")
    func supportsOffsetDisplays() {
        let leftDisplay = CGRect(x: -1440, y: -200, width: 1440, height: 900)
        let window = SpaceWindow(id: 1, processID: 10, bounds: CGRect(x: -1000, y: -100, width: 800, height: 600))
        #expect(SpaceApplications.windows(
            from: [window], regularProcessIDs: [10], excluding: 99, on: leftDisplay
        ) == [window])
    }

    @Test("Shows one icon for an application with multiple windows")
    func deduplicatesApplications() {
        let windows = [
            SpaceWindow(id: 1, processID: 10, bounds: windowBounds),
            SpaceWindow(id: 2, processID: 10, bounds: windowBounds)
        ]
        #expect(SpaceApplications.orderedProcessIDs(windows: windows, previousOrder: [], names: [10: "Safari"]) == [10])
    }

    @Test("Retains existing icon order when window stacking order changes")
    func retainsIconOrder() {
        let windows = [
            SpaceWindow(id: 1, processID: 10, bounds: windowBounds),
            SpaceWindow(id: 2, processID: 20, bounds: windowBounds)
        ]
        #expect(SpaceApplications.orderedProcessIDs(
            windows: windows, previousOrder: [20, 10], names: [10: "Safari", 20: "Terminal"]
        ) == [20, 10])
    }

    @Test("Removes departed apps and appends new apps alphabetically")
    func updatesApplicationMembership() {
        let windows = [10, 20, 30].map { SpaceWindow(id: UInt32($0), processID: Int32($0), bounds: windowBounds) }
        #expect(SpaceApplications.orderedProcessIDs(
            windows: windows, previousOrder: [99, 20], names: [10: "Safari", 20: "Terminal", 30: "Finder"]
        ) == [20, 30, 10])
    }

    @Test("Uses process ID to break ties between identically named applications")
    func sortsDuplicateNamesDeterministically() {
        let windows = [30, 10].map { SpaceWindow(id: UInt32($0), processID: Int32($0), bounds: windowBounds) }
        #expect(SpaceApplications.orderedProcessIDs(
            windows: windows, previousOrder: [], names: [10: "Editor", 30: "Editor"]
        ) == [10, 30])
    }

    @Test("Clears all icons when the Space has no windows")
    func clearsEmptySpaces() {
        #expect(SpaceApplications.orderedProcessIDs(windows: [], previousOrder: [10, 20], names: [:]).isEmpty)
    }

    private func filtered(_ windows: [SpaceWindow]) -> [SpaceWindow] {
        SpaceApplications.windows(from: windows, regularProcessIDs: [10, 20, 99], excluding: 99, on: display)
    }
}
