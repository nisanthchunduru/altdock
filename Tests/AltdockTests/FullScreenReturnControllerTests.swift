import AltdockCore
import AppKit
import Testing
@testable import Altdock

@Suite("Windows return to their original Desktop after leaving native full screen")
@MainActor
struct FullScreenReturnControllerTests {
    @Test("Only the returning window moves, not another window of the same app or the active Desktop")
    func returnsOnlyTheOriginalWindow() {
        let fixture = ReturnFixture()
        fixture.enterFullScreen()
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests == [.init(windowIDs: [1], destination: 200)])
        #expect(fixture.spaces.membership[1] == [200])
        #expect(fixture.spaces.membership[2] == [300])
        #expect(fixture.spaces.active == 300)
        #expect(fixture.reports.isEmpty)
        fixture.observe()
        #expect(fixture.reports.count == 1)
        #expect(fixture.reports[0].contains("returned"))
    }

    @Test("A deleted origin falls back to Desktop 1 in Mission Control order, not the lowest Space ID")
    func deletedDesktopUsesFirstDesktop() {
        let fixture = ReturnFixture()
        fixture.enterFullScreen()
        fixture.spaces.desktopIDs = [500, 100, 300]
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests.first?.destination == 500)
    }

    @Test("Desktop renumbering does not change the remembered origin's stable Space ID")
    func desktopReorderingKeepsOrigin() {
        let fixture = ReturnFixture()
        fixture.enterFullScreen()
        fixture.spaces.desktopIDs = [300, 100, 200]
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests.first?.destination == 200)
    }

    @Test("An ordered-out minimized or hidden window returns without being restored or activated")
    func returnsMinimizedWindow() {
        let fixture = ReturnFixture()
        fixture.enterFullScreen()
        fixture.spaces.ordered[1] = false
        fixture.windows[0] = SpaceWindow(id: 1, processID: 42, bounds: fixture.bounds, isOnScreen: false)
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests == [.init(windowIDs: [1], destination: 200)])
        #expect(fixture.spaces.ordered[1] == false)
    }

    @Test("If macOS returns the window correctly, no move is submitted")
    func alreadyReturned() {
        let fixture = ReturnFixture()
        fixture.enterFullScreen()
        fixture.exitFullScreen(to: 200)
        #expect(fixture.bridge.requests.isEmpty)
    }

    @Test("Ordinary maximize, minimize, and manual Desktop moves do not trigger a return")
    func ordinaryChangesStayUntouched() {
        let fixture = ReturnFixture()
        fixture.observe()
        fixture.spaces.membership[1] = [300]
        fixture.spaces.ordered[1] = false
        fixture.windows[0] = SpaceWindow(id: 1, processID: 42, bounds: CGRect(x: 0, y: 0, width: 1440, height: 900))
        fixture.observe()
        fixture.advance()
        fixture.observe()
        #expect(fixture.bridge.requests.isEmpty)
    }

    @Test("A manual move before entering full screen becomes the new return Desktop")
    func remembersLatestOrdinaryDesktop() {
        let fixture = ReturnFixture()
        fixture.observe()
        fixture.spaces.membership[1] = [100]
        fixture.enterFullScreen()
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests.first?.destination == 100)
    }

    @Test("A deliberate move after return is not undone, and the next full-screen cycle remembers it")
    func doesNotFightLaterMoves() {
        let fixture = ReturnFixture()
        fixture.enterFullScreen()
        fixture.exitFullScreen()
        fixture.observe()
        fixture.spaces.membership[1] = [100]
        fixture.observe()
        fixture.advance()
        fixture.observe()
        #expect(fixture.bridge.requests.count == 1)
        fixture.enterFullScreen()
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests.map(\.destination) == [200, 100])
    }

    @Test("Unknown origins and newly recreated window IDs are not guessed from sibling windows")
    func unknownOriginIsNotGuessed() {
        let fixture = ReturnFixture()
        fixture.spaces.fullScreenIDs = [900]
        fixture.spaces.membership[1] = [900]
        fixture.observe()
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests.isEmpty)
        fixture.enterFullScreen()
        fixture.windows[0] = SpaceWindow(id: 9, processID: 42, bounds: fixture.bounds)
        fixture.spaces.membership[9] = [300]
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests.isEmpty)
    }

    @Test("All-Desktops windows lose exclusive origins and are never reassigned")
    func sharedWindowsAreNotMoved() {
        let fixture = ReturnFixture()
        fixture.observe()
        fixture.spaces.membership[1] = [100, 200, 300]
        fixture.observe()
        fixture.enterFullScreen()
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests.isEmpty)
    }

    @Test("Overlapping normal/full-screen transition memberships retain the original Desktop")
    func overlappingTransitionMembership() {
        let fixture = ReturnFixture()
        fixture.observe()
        fixture.spaces.fullScreenIDs = [900]
        fixture.spaces.membership[1] = [200, 900]
        fixture.observe()
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests.first?.destination == 200)
    }

    @Test("No move is made until ordinary membership stays stable for at least half a second")
    func waitsForStableExit() {
        let fixture = ReturnFixture()
        fixture.enterFullScreen()
        fixture.spaces.fullScreenIDs = []
        fixture.spaces.membership[1] = [100]
        fixture.observe()
        fixture.time += 0.2
        fixture.observe()
        #expect(fixture.bridge.requests.isEmpty)
        fixture.spaces.membership[1] = [300]
        fixture.observe()
        fixture.time += 0.4
        fixture.observe()
        #expect(fixture.bridge.requests.isEmpty)
        fixture.time += 0.2
        fixture.observe()
        #expect(fixture.bridge.requests.count == 1)
    }

    @Test("Unknown membership, incomplete topology, and transient missing windows preserve a known full-screen origin")
    func toleratesTransitionGaps() {
        let fixture = ReturnFixture()
        fixture.enterFullScreen()
        fixture.spaces.membership[1] = nil
        fixture.observe()
        fixture.spaces.membership[1] = []
        fixture.observe()
        fixture.spaces.topologyAvailable = false
        fixture.observe()
        fixture.spaces.topologyAvailable = true
        let windows = fixture.windows
        fixture.windows = []
        fixture.observe()
        fixture.time += 120
        fixture.windows = windows
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests.first?.destination == 200)
    }

    @Test("A terminated process or another process reusing a window ID cannot inherit a return")
    func processIdentityIsRequired() {
        let fixture = ReturnFixture()
        fixture.enterFullScreen()
        fixture.regularProcessIDs = []
        fixture.observe()
        fixture.regularProcessIDs = [43]
        fixture.windows[0] = SpaceWindow(id: 1, processID: 43, bounds: fixture.bounds)
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests.isEmpty)
    }

    @Test("Failed submissions and unverified submissions are not retried on every refresh")
    func boundsFailedMoves() {
        for accepted in [false, true] {
            let fixture = ReturnFixture()
            fixture.bridge.accept = accepted
            fixture.bridge.apply = false
            fixture.enterFullScreen()
            fixture.exitFullScreen()
            for _ in 0..<10 { fixture.advance(); fixture.observe() }
            #expect(fixture.bridge.requests.count == 1)
            #expect(fixture.reports.count == 1)
            #expect(fixture.reports[0].contains("no retry"))
        }
    }

    @Test("Fresh ownership and membership checks prevent moving a disappeared or changed window")
    func revalidatesWindowBeforeSubmission() {
        for change in 0..<3 {
            let fixture = ReturnFixture()
            fixture.enterFullScreen()
            fixture.beforeCapture = {
                if change == 0 { fixture.windows = [] }
                if change == 1 { fixture.windows[0] = SpaceWindow(id: 1, processID: 43, bounds: fixture.bounds) }
                if change == 2 { fixture.spaces.membership[1] = [900]; fixture.spaces.fullScreenIDs = [900] }
            }
            fixture.exitFullScreen()
            #expect(fixture.bridge.requests.isEmpty)
        }
    }

    @Test("A destination deleted immediately before submission is reconsidered before using Desktop 1")
    func revalidatesDestination() {
        let fixture = ReturnFixture()
        fixture.enterFullScreen()
        fixture.beforeCapture = { fixture.spaces.desktopIDs = [100, 300] }
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests.isEmpty)
        fixture.beforeCapture = nil
        fixture.observe()
        fixture.advance()
        fixture.observe()
        #expect(fixture.bridge.requests.first?.destination == 100)
    }

    @Test("Returning one half of Split View does not require the other half's full-screen Space to disappear")
    func splitViewSurvives() {
        let fixture = ReturnFixture()
        fixture.enterFullScreen()
        fixture.spaces.membership[2] = [900]
        fixture.spaces.membership[1] = [300]
        fixture.observe()
        fixture.advance()
        fixture.observe()
        #expect(fixture.bridge.requests == [.init(windowIDs: [1], destination: 200)])
        #expect(fixture.spaces.membership[2] == [900])
    }

    @Test("A window still present after a long sleep keeps its last ordinary Desktop")
    func originSurvivesLongRefreshGap() {
        let fixture = ReturnFixture()
        fixture.observe()
        fixture.time += 120
        fixture.spaces.fullScreenIDs = [900]
        fixture.spaces.membership[1] = [900]
        fixture.observe()
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests.first?.destination == 200)
    }

    @Test("Re-entering full screen while the exit is settling cancels that pending return")
    func reentryCancelsSettling() {
        let fixture = ReturnFixture()
        fixture.enterFullScreen()
        fixture.spaces.fullScreenIDs = []
        fixture.spaces.membership[1] = [300]
        fixture.observe()
        fixture.spaces.fullScreenIDs = [901]
        fixture.spaces.membership[1] = [901]
        fixture.advance()
        fixture.observe()
        #expect(fixture.bridge.requests.isEmpty)
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests.first?.destination == 200)
    }

    @Test("Disappearing windows and unreadable membership cannot leave verification pending forever")
    func expiresMissingVerification() {
        for absent in [false, true] {
            let fixture = ReturnFixture()
            fixture.enterFullScreen()
            fixture.exitFullScreen()
            if absent { fixture.windows = [] } else { fixture.spaces.membership[1] = nil }
            fixture.time += 3
            fixture.observe()
            #expect(fixture.reports.count == 1)
            #expect(fixture.reports[0].contains("Could not verify"))
            fixture.observe()
            #expect(fixture.reports.count == 1)
            #expect(fixture.bridge.requests.count == 1)
        }
    }

    @Test("Ordered-out auxiliary windows cannot establish return origins")
    func excludesUnobservedAuxiliaryWindows() {
        let fixture = ReturnFixture()
        fixture.spaces.ordered[1] = false
        fixture.enterFullScreen()
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests.isEmpty)
    }

    @Test("A stale normal-window record is discarded after the missing window's grace period")
    func prunesClosedOrdinaryWindows() {
        let fixture = ReturnFixture()
        fixture.observe()
        let originalWindows = fixture.windows
        fixture.windows = []
        fixture.time += 61
        fixture.observe()
        fixture.windows = originalWindows
        fixture.spaces.fullScreenIDs = [900]
        fixture.spaces.membership[1] = [900]
        fixture.observe()
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests.isEmpty)
    }

    @Test("An unsupported bridge or incomplete topology causes no move")
    func unavailableBackend() {
        let fixture = ReturnFixture()
        fixture.enterFullScreen()
        fixture.bridge.isAvailable = false
        fixture.exitFullScreen()
        #expect(fixture.bridge.requests.isEmpty)
        fixture.bridge.isAvailable = true
        fixture.spaces.topologyAvailable = false
        fixture.observe()
        #expect(fixture.bridge.requests.isEmpty)
    }

    @Test("Desktop 1 fallback stays on the origin display, or uses the primary display if unplugged")
    func multiDisplayFallback() {
        for disconnected in [false, true] {
            let fixture = ReturnFixture()
            fixture.spaces.secondaryDesktopIDs = [600, 700]
            fixture.connectedDisplays.append(.init(id: 20, bounds: CGRect(x: 1440, y: 0, width: 1440, height: 900)))
            fixture.spaces.membership[1] = [700]
            fixture.enterFullScreen()
            if disconnected {
                fixture.connectedDisplays.removeLast()
                fixture.spaces.secondaryDesktopIDs = []
            } else {
                fixture.spaces.secondaryDesktopIDs = [600]
            }
            fixture.exitFullScreen()
            #expect(fixture.bridge.requests.first?.destination == (disconnected ? 100 : 600))
        }
    }

    @Test("Discovery delivers ordered-out windows to return tracking while keeping them out of dock icons")
    func trackerIncludesMinimizedWindowsWithoutPhantomIcons() {
        let fixture = ReturnFixture()
        let tracker = SpaceWindowTracker(spaces: fixture.spaces, captureWindows: { _ in fixture.windows })
        tracker.didCaptureWindows = { windows, processIDs in fixture.controller.observe(windows: windows, regularProcessIDs: processIDs) }
        tracker.refresh(regularProcessIDs: [42])
        fixture.spaces.fullScreenIDs = [900]
        fixture.spaces.membership[1] = [900]
        tracker.refresh(regularProcessIDs: [42])
        fixture.spaces.fullScreenIDs = []
        fixture.spaces.membership[1] = [300]
        fixture.spaces.ordered[1] = false
        tracker.refresh(regularProcessIDs: [42])
        fixture.advance()
        tracker.refresh(regularProcessIDs: [42])
        #expect(fixture.bridge.requests.first?.destination == 200)
        #expect(tracker.index?.windows(in: 200)?.isEmpty == true)
    }
}

@MainActor
private final class ReturnFixture {
    let bounds = CGRect(x: 20, y: 20, width: 800, height: 600)
    let spaces = ReturnSpaces()
    lazy var bridge = ReturnBridge(spaces: spaces)
    var connectedDisplays = [FullScreenReturnController.Display(id: 10, bounds: CGRect(x: 0, y: 0, width: 1440, height: 900))]
    var regularProcessIDs: Set<Int32> = [42]
    lazy var windows = [SpaceWindow(id: 1, processID: 42, bounds: bounds), SpaceWindow(id: 2, processID: 42, bounds: bounds)]
    var time: TimeInterval = 0
    var reports: [String] = []
    var beforeCapture: (() -> Void)?
    lazy var controller = FullScreenReturnController(
        spaces: spaces, bridge: bridge, displays: { [unowned self] in connectedDisplays },
        capture: { [unowned self] in beforeCapture?(); return windows },
        now: { [unowned self] in Date(timeIntervalSince1970: time) }, report: { [unowned self] in reports.append($0) }
    )

    func observe() { controller.observe(windows: windows, regularProcessIDs: regularProcessIDs) }
    func advance() { time += 0.75 }
    func enterFullScreen() {
        observe()
        spaces.fullScreenIDs = [900]
        spaces.membership[1] = [900]
        observe()
    }
    func exitFullScreen(to desktop: UInt64 = 300) {
        spaces.fullScreenIDs = []
        spaces.membership[1] = [desktop]
        observe()
        advance()
        observe()
    }
}

@MainActor
private final class ReturnSpaces: SpaceQuerying {
    var membership: [UInt32: Set<UInt64>] = [1: [200], 2: [300]]
    var ordered: [UInt32: Bool] = [1: true, 2: true]
    var desktopIDs: [UInt64] = [100, 200, 300]
    var secondaryDesktopIDs: [UInt64] = []
    var fullScreenIDs: Set<UInt64> = []
    var active: UInt64 = 300
    var topologyAvailable = true
    func spaceIDs(for windowID: UInt32) -> Set<UInt64>? { membership[windowID] }
    func allSpaceIDs() -> Set<UInt64>? { Set(desktopIDs + secondaryDesktopIDs).union(fullScreenIDs) }
    func spaceIDs(on displayBounds: CGRect) -> Set<UInt64>? { allSpaceIDs() }
    func activeSpaceID(on displayBounds: CGRect) -> UInt64? { active }
    func isWindowOrderedIn(_ windowID: UInt32) -> Bool? { ordered[windowID] }
    func fullScreenSpaceIDs(on displayBounds: CGRect) -> Set<UInt64>? { topologyAvailable ? fullScreenIDs : nil }
    func desktops(on displayBounds: CGRect) -> [DesktopDestination]? {
        guard topologyAvailable else { return nil }
        return (displayBounds.minX == 0 ? desktopIDs : secondaryDesktopIDs).enumerated().map { DesktopDestination(id: $0.element, number: $0.offset + 1) }
    }
}

@MainActor
private final class ReturnBridge: DesktopMoveRequesting {
    struct Request: Equatable {
        let windowIDs: [UInt32]
        let destination: UInt64
    }
    let spaces: ReturnSpaces
    var isAvailable = true
    var accept = true
    var apply = true
    var requests: [Request] = []
    init(spaces: ReturnSpaces) { self.spaces = spaces }
    func request(windowIDs: [UInt32], destination: UInt64) -> Bool {
        requests.append(Request(windowIDs: windowIDs, destination: destination))
        if accept && apply { for id in windowIDs { spaces.membership[id] = [destination] } }
        return accept
    }
}
