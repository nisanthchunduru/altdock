import AltdockCore
import AppKit
import Testing
@testable import Altdock

@Suite("Each Desktop keeps its own rearranged icons across refreshes")
@MainActor
struct DockReorderModelTests {
    @Test("Reordering one Desktop leaves another Desktop unchanged and survives discovery")
    func preservesPerDesktopOrder() {
        let tracker = ReorderTracker()
        let apps = [101, 102, 103].map { ReorderApplication(pid: Int32($0)) }
        let model = DockModel(preferences: DockPreferences(), windowTracker: tracker, runningApplications: { apps }, displayBounds: { tracker.display })
        defer { model.stop() }
        model.refresh()
        let other = model.spaceApplications?[200]?.map(\.id)
        model.reorderApplication(101, to: 2, on: 100)
        #expect(model.applications.map(\.id) == [102, 103, 101])
        #expect(model.spaceApplications?[200]?.map(\.id) == other)
        model.refresh()
        #expect(model.applications.map(\.id) == [102, 103, 101])
        tracker.active = 200
        model.spaceDidChange()
        #expect(model.applications.map(\.id) == other)
        tracker.active = 100
        model.spaceDidChange()
        #expect(model.applications.map(\.id) == [102, 103, 101])
    }

    @Test("A temporarily empty inactive Space does not erase the user's order")
    func temporaryEmptySnapshot() {
        let tracker = ReorderTracker()
        let apps = [101, 102, 103].map { ReorderApplication(pid: Int32($0)) }
        let model = DockModel(preferences: DockPreferences(), windowTracker: tracker, runningApplications: { apps }, displayBounds: { tracker.display })
        defer { model.stop() }
        model.refresh()
        model.reorderApplication(101, to: 2, on: 100)
        tracker.active = 200
        model.spaceDidChange()
        tracker.overrides = [100: [], 200: tracker.windows]
        model.refresh()
        #expect(model.spaceApplications?[100]?.isEmpty == true)
        tracker.overrides = nil
        model.refresh()
        tracker.active = 100
        model.spaceDidChange()
        #expect(model.applications.map(\.id) == [102, 103, 101])
    }

    @Test("A temporarily missing Space does not discard its ordering preference")
    func temporaryMissingSpace() {
        let tracker = ReorderTracker()
        let apps = [101, 102, 103].map { ReorderApplication(pid: Int32($0)) }
        let model = DockModel(preferences: DockPreferences(), windowTracker: tracker, runningApplications: { apps }, displayBounds: { tracker.display })
        defer { model.stop() }
        model.refresh()
        model.reorderApplication(101, to: 2, on: 100)
        tracker.active = 200
        tracker.overrides = [200: tracker.windows]
        model.refresh()
        tracker.overrides = nil
        tracker.active = 100
        model.refresh()
        #expect(model.applications.map(\.id) == [102, 103, 101])
    }

    @Test("An app that disappears and returns keeps its slot without showing a phantom icon while absent")
    func temporarilyMissingApplication() {
        let tracker = ReorderTracker()
        let apps = [101, 102, 103].map { ReorderApplication(pid: Int32($0)) }
        let model = DockModel(preferences: DockPreferences(), windowTracker: tracker, runningApplications: { apps }, displayBounds: { tracker.display })
        defer { model.stop() }
        model.refresh()
        model.reorderApplication(103, to: 0, on: 100)
        tracker.overrides = [100: tracker.windows.filter { $0.processID != 103 }, 200: tracker.windows]
        model.refresh()
        #expect(model.applications.map(\.id) == [101, 102])
        tracker.overrides = nil
        model.refresh()
        #expect(model.applications.map(\.id) == [103, 101, 102])
    }

    @Test("A drop from an outgoing Desktop cannot change the new Desktop's order")
    func rejectsStaleDrop() {
        let tracker = ReorderTracker()
        let apps = [101, 102, 103].map { ReorderApplication(pid: Int32($0)) }
        let model = DockModel(preferences: DockPreferences(), windowTracker: tracker, runningApplications: { apps }, displayBounds: { tracker.display })
        defer { model.stop() }
        model.refresh()
        tracker.active = 200
        model.reorderApplication(101, to: 2, on: 100)
        #expect(model.spaceApplications?[100]?.map(\.id) == [101, 102, 103])
        #expect(model.spaceApplications?[200]?.map(\.id) == [101, 102, 103])
    }
}

private final class ReorderApplication: NSRunningApplication, @unchecked Sendable {
    let pid: Int32
    init(pid: Int32) { self.pid = pid; super.init() }
    override var processIdentifier: pid_t { pid }
    override var localizedName: String? { "App \(pid)" }
}

@MainActor
private final class ReorderTracker: SpaceWindowTracking {
    let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
    var active: UInt64 = 100
    var overrides: [UInt64: [SpaceWindow]]?
    var usesSkyLight: Bool { true }
    var backendDescription: String { "Fixture" }
    var windows: [SpaceWindow] { [101, 102, 103].map { SpaceWindow(id: UInt32($0), processID: Int32($0), bounds: display) } }
    func refresh(regularProcessIDs: Set<Int32>) {}
    func activeSpaceID(on displayBounds: CGRect) -> UInt64? { active }
    func selection(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> SpaceWindowSelection? { SpaceWindowSelection(spaceID: active, windows: overrides?[active] ?? windows) }
    func allSelections(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> [UInt64: [SpaceWindow]]? { overrides ?? [100: windows, 200: windows] }
}
