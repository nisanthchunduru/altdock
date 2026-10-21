import AltdockCore
import CoreGraphics
import Testing
@testable import Altdock

@Suite("Move only the selected app's windows from this Desktop")
@MainActor
struct DesktopWindowMoverTests {
    @Test("Only source-Desktop windows of the selected process are moved; off-Desktop, ordered-out, and shared windows stay")
    func limitsWindowScope() async throws {
        let fixture = MoveFixture()
        let moved = try await fixture.mover.move(processID: 42, from: 100, to: 200, on: fixture.display)
        #expect(moved == 1)
        #expect(fixture.bridge.requests == [[1]])
        #expect(fixture.spaces.membership[2] == [200])
        #expect(fixture.spaces.membership[3] == [100])
        #expect(fixture.spaces.membership[4] == [100])
        #expect(fixture.spaces.membership[5] == [100, 200])
        #expect(fixture.spaces.active == 100)
    }

    @Test("Focused-only moves select that window even when another sibling appears first")
    func movesFocusedSiblingOnly() async throws {
        let fixture = MoveFixture()
        fixture.focused = 3
        fixture.spaces.ordering[3] = true
        let moved = try await fixture.mover.move(processID: 42, from: 100, to: 200, on: fixture.display, scope: .focused)
        #expect(moved == 1)
        #expect(fixture.bridge.requests == [[3]])
        #expect(fixture.spaces.membership[1] == [100])
        #expect(fixture.spaces.active == 100)
    }

    @Test("No local focused window never falls back to moving a sibling or the entire app")
    func refusesNonlocalFocus() async {
        for focused: UInt32? in [nil, 2, 3, 4, 5, 6, 999] {
            let fixture = MoveFixture()
            fixture.focused = focused
            do {
                _ = try await fixture.mover.move(processID: 42, from: 100, to: 200, on: fixture.display, scope: .focused)
                Issue.record("Expected rejection for unavailable, other-Desktop/display, hidden, other-PID or shared focus")
            } catch { #expect(fixture.bridge.requests.isEmpty) }
        }
    }

    @Test("Focus or active-Desktop changes before submission cancel a focused-only move")
    func rejectsChangedFocus() async {
        for changesDesktop in [false, true] {
            let fixture = MoveFixture()
            fixture.beforeSecondFocusRead = {
                if changesDesktop { fixture.spaces.active = 200 }
                else { fixture.focused = 2 }
            }
            do {
                _ = try await fixture.mover.move(processID: 42, from: 100, to: 200, on: fixture.display, scope: .focused)
                Issue.record("Expected stale-focus rejection")
            } catch { #expect(fixture.bridge.requests.isEmpty) }
        }
    }

    @Test("Stale source menus and deleted or full-screen destinations cause no writes")
    func rejectsStaleRequests() async {
        for (source, destination) in [(UInt64(200), UInt64(100)), (100, 999), (100, 300), (100, 100)] {
            let fixture = MoveFixture()
            do {
                _ = try await fixture.mover.move(processID: 42, from: source, to: destination, on: fixture.display)
                Issue.record("Expected request rejection")
            } catch { #expect(fixture.bridge.requests.isEmpty) }
        }
    }

    @Test("Failure to verify source membership prevents moving any windows")
    func refusesUnknownMembership() async {
        let fixture = MoveFixture()
        fixture.spaces.membership.removeValue(forKey: 1)
        do {
            _ = try await fixture.mover.move(processID: 42, from: 100, to: 200, on: fixture.display)
            Issue.record("Expected membership error")
        } catch { #expect(fixture.bridge.requests.isEmpty) }
    }

    @Test("The service verifies actual destination membership rather than treating submission as success")
    func verifiesResult() async {
        let fixture = MoveFixture()
        fixture.bridge.applyMove = false
        do {
            _ = try await fixture.mover.move(processID: 42, from: 100, to: 200, on: fixture.display)
            Issue.record("An unverified move must fail")
        } catch {
            #expect(error.localizedDescription.contains("0 of 1"))
            #expect(fixture.bridge.requests.count == 1)
            #expect(fixture.waits == 15)
        }
    }

    @Test("Partial moves report the moved count without retrying or rolling back unrelated windows")
    func partialMove() async {
        let fixture = MoveFixture()
        fixture.spaces.ordering[3] = true
        fixture.bridge.moveLimit = 1
        do {
            _ = try await fixture.mover.move(processID: 42, from: 100, to: 200, on: fixture.display)
            Issue.record("Expected partial result")
        } catch {
            #expect(error.localizedDescription.contains("1 of 2"))
            #expect(fixture.bridge.requests.count == 1)
        }
    }

    @Test("An unavailable backend does not attempt private operations")
    func unsupportedBackend() async {
        let fixture = MoveFixture()
        fixture.bridge.isAvailable = false
        #expect(!fixture.mover.isAvailable)
        do {
            _ = try await fixture.mover.move(processID: 42, from: 100, to: 200, on: fixture.display)
            Issue.record("Expected unsupported error")
        } catch { #expect(fixture.bridge.requests.isEmpty) }
    }

    @Test("An app without source windows is not launched or moved from elsewhere")
    func noSourceWindows() async {
        let fixture = MoveFixture()
        fixture.spaces.membership[1] = [200]
        do {
            _ = try await fixture.mover.move(processID: 42, from: 100, to: 200, on: fixture.display)
            Issue.record("Expected no movable windows")
        } catch { #expect(fixture.bridge.requests.isEmpty) }
    }
}

@MainActor
private final class MoveFixture {
    let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let spaces = MoveSpaces()
    lazy var bridge = MoveBridge(spaces: spaces)
    var waits = 0
    var focused: UInt32? = 1
    var focusReads = 0
    var beforeSecondFocusRead: (() -> Void)?
    lazy var mover = DesktopWindowMover(spaces: spaces, bridge: bridge, capture: {
        [
            SpaceWindow(id: 1, processID: 42, bounds: CGRect(x: 10, y: 10, width: 800, height: 600)),
            SpaceWindow(id: 2, processID: 42, bounds: CGRect(x: 10, y: 10, width: 800, height: 600), isOnScreen: false),
            SpaceWindow(id: 3, processID: 42, bounds: CGRect(x: 10, y: 10, width: 400, height: 84)),
            SpaceWindow(id: 4, processID: 43, bounds: CGRect(x: 10, y: 10, width: 800, height: 600)),
            SpaceWindow(id: 5, processID: 42, bounds: CGRect(x: 10, y: 10, width: 800, height: 600)),
            SpaceWindow(id: 6, processID: 42, bounds: CGRect(x: 2000, y: 10, width: 800, height: 600))
        ]
    }, wait: { [weak self] in self?.waits += 1 }, focusedWindowID: { [unowned self] _ in
        focusReads += 1
        if focusReads == 2 { beforeSecondFocusRead?() }
        return focused
    })
}

@MainActor
private final class MoveSpaces: SpaceQuerying {
    var active: UInt64 = 100
    var membership: [UInt32: Set<UInt64>] = [1: [100], 2: [200], 3: [100], 4: [100], 5: [100, 200], 6: [100]]
    var ordering: [UInt32: Bool] = [1: true, 2: true, 3: false, 4: true, 5: true, 6: true]
    func spaceIDs(for windowID: UInt32) -> Set<UInt64>? { membership[windowID] }
    func allSpaceIDs() -> Set<UInt64>? { [100, 200, 300] }
    func spaceIDs(on displayBounds: CGRect) -> Set<UInt64>? { allSpaceIDs() }
    func activeSpaceID(on displayBounds: CGRect) -> UInt64? { active }
    func isWindowOrderedIn(_ windowID: UInt32) -> Bool? { ordering[windowID] }
    func desktops(on displayBounds: CGRect) -> [DesktopDestination]? {
        [DesktopDestination(id: 100, number: 1), DesktopDestination(id: 200, number: 2)]
    }
}

@MainActor
private final class MoveBridge: DesktopMoveRequesting {
    let spaces: MoveSpaces
    var isAvailable = true
    var applyMove = true
    var moveLimit = Int.max
    var requests: [[UInt32]] = []
    init(spaces: MoveSpaces) { self.spaces = spaces }
    func request(windowIDs: [UInt32], destination: UInt64) -> Bool {
        requests.append(windowIDs)
        if applyMove { for id in windowIDs.prefix(moveLimit) { spaces.membership[id] = [destination] } }
        return true
    }
}
