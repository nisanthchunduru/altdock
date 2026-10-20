import AltdockCore
import CoreGraphics
import Testing
@testable import Altdock

@Suite("Clicking an app icon preserves its eligible focused window")
@MainActor
struct ApplicationActivatorTests {
    private let windows = [
        SpaceWindow(id: 1, processID: 100, bounds: CGRect(x: 0, y: 0, width: 800, height: 600)),
        SpaceWindow(id: 2, processID: 100, bounds: CGRect(x: 100, y: 100, width: 800, height: 600))
    ]

    @Test("An active app's second window stays focused even if another window is listed first")
    func preservesFocusedSibling() {
        let access = FakeActivationAccess()
        access.focused = 2
        ApplicationActivator.activate(matching: windows, access: access)
        #expect(access.effects.isEmpty)
        #expect(access.windowQueries == 0)
    }

    @Test("Repeated clicks do not cycle windows, re-raise, unhide, or re-activate the app")
    func repeatedClicks() {
        let access = FakeActivationAccess()
        access.focused = 2
        for _ in 0..<5 { ApplicationActivator.activate(matching: windows, access: access) }
        #expect(access.effects.isEmpty)
    }

    @Test("A background app's remembered focused local window is preferred over its first sibling")
    func backgroundFocusedWindow() {
        let access = FakeActivationAccess()
        access.isActive = false
        access.focused = 2
        ApplicationActivator.activate(matching: windows, access: access)
        #expect(access.effects == ["unhide", "raise:2", "activate"])
        #expect(access.windowQueries == 0)
    }

    @Test("Focus outside this Space or display does not prevent selecting a local window")
    func focusOutsideLocalSelection() {
        let access = FakeActivationAccess()
        access.focused = 99
        access.accessible = [99, 2, 1]
        ApplicationActivator.activate(matching: windows, access: access)
        #expect(access.effects == ["unhide", "raise:1", "activate"])
    }

    @Test("Failed focused-window reads fall back to the first accessible eligible local window")
    func unknownFocus() {
        let access = FakeActivationAccess()
        access.focused = nil
        access.accessible = [99, 2]
        ApplicationActivator.activate(matching: windows, access: access)
        #expect(access.effects == ["unhide", "raise:2", "activate"])
    }

    @Test("A hidden app is restored rather than treated as already focused")
    func hiddenApplication() {
        let access = FakeActivationAccess()
        access.isHidden = true
        access.focused = 2
        ApplicationActivator.activate(matching: windows, access: access)
        #expect(access.effects == ["unhide", "raise:2", "activate"])
    }

    @Test("No Accessibility grant preserves normal macOS activation without prompting or querying AX")
    func noPermission() {
        let access = FakeActivationAccess()
        access.isTrusted = false
        ApplicationActivator.activate(matching: windows, access: access)
        #expect(access.effects == ["unhide", "activate"])
        #expect(access.focusQueries == 0 && access.windowQueries == 0)
    }

    @Test("No eligible windows or a terminated app causes no activation")
    func noEligibleTarget() {
        let access = FakeActivationAccess()
        ApplicationActivator.activate(matching: [], access: access)
        access.isTerminated = true
        ApplicationActivator.activate(matching: windows, access: access)
        #expect(access.effects.isEmpty)
        #expect(access.focusQueries == 0)
    }

    @Test("Windows from a different process cannot be used to preserve or change focus")
    func rejectsOtherProcesses() {
        let access = FakeActivationAccess()
        access.processID = 200
        ApplicationActivator.activate(matching: windows, access: access)
        #expect(access.effects.isEmpty)
    }

    @Test("If no accessible window matches, activation delegates to macOS without raising an unrelated window")
    func unmatchedAccessibilityWindows() {
        let access = FakeActivationAccess()
        access.focused = 99
        access.accessible = [99]
        ApplicationActivator.activate(matching: windows, access: access)
        #expect(access.effects == ["unhide", "activate"])
    }
}

@MainActor
private final class FakeActivationAccess: ApplicationActivationAccess {
    var processID: Int32 = 100
    var isTerminated = false
    var isActive = true
    var isHidden = false
    var isTrusted = true
    var focused: UInt32? = 1
    var accessible: [UInt32] = [1, 2]
    var effects: [String] = []
    var focusQueries = 0
    var windowQueries = 0

    func focusedWindow() -> UInt32? { focusQueries += 1; return focused }
    func windows() -> [UInt32] { windowQueries += 1; return accessible }
    func matches(_ element: UInt32, window: SpaceWindow) -> Bool { element == window.id }
    func restoreAndRaise(_ window: UInt32) { effects.append("raise:\(window)") }
    func unhide() { effects.append("unhide") }
    func activate() { effects.append("activate") }
}
