import AltdockCore
import AppKit
import SwiftUI
import Testing
@testable import Altdock

@Suite("Each minimized window has its own stable, restorable dock tile")
@MainActor
struct DockMinimizedWindowTests {
    @Test("Two minimized windows of one app produce two tiles in addition to its app icon")
    func separateTiles() {
        let fixture = MinimizedDockFixture()
        fixture.model.refresh()
        #expect(fixture.model.applications.count == 1)
        #expect(fixture.model.minimizedWindows.map(\.window.id) == [2, 3])
        #expect(fixture.model.minimizedWindows.map(\.name) == ["Budget", "Meeting notes"])
        #expect(fixture.model.spaceMinimizedWindows?[200]?.map(\.window.id) == [4])
    }

    @Test("Restoring a tile targets that window, not whichever sibling was previously focused")
    func restoresExactWindow() {
        let fixture = MinimizedDockFixture()
        fixture.model.refresh()
        fixture.model.restoreMinimizedWindow(fixture.model.minimizedWindows[1], expectedSpaceID: 100)
        #expect(fixture.restored == [3])
    }

    @Test("Stale tiles cannot restore windows after a Desktop switch, close, restore, or failed refresh")
    func rejectsStaleTiles() {
        for change in 0..<4 {
            let fixture = MinimizedDockFixture()
            fixture.model.refresh()
            let target = fixture.model.minimizedWindows[0]
            if change == 0 { fixture.tracker.active = 200 }
            if change == 1 { fixture.tracker.snapshots[100]?.removeAll { $0.id == 2 } }
            if change == 2 { fixture.tracker.snapshots[100] = [fixture.window(2, minimized: false)] }
            if change == 3 { fixture.tracker.hasFreshSnapshot = false }
            fixture.model.restoreMinimizedWindow(target, expectedSpaceID: 100)
            #expect(fixture.restored.isEmpty)
        }
    }

    @Test("Minimized tiles retain their order when WindowServer enumeration order changes")
    func stableOrder() {
        let fixture = MinimizedDockFixture()
        fixture.model.refresh()
        fixture.tracker.snapshots[100]?.reverse()
        fixture.model.refresh()
        #expect(fixture.model.minimizedWindows.map(\.window.id) == [2, 3])
    }

    @Test("Space changes display the destination's minimized tiles immediately from its cache")
    func switchesMinimizedCache() {
        let fixture = MinimizedDockFixture()
        defer { fixture.model.stop() }
        fixture.model.refresh()
        fixture.tracker.active = 200
        fixture.tracker.selectionAvailable = false
        fixture.model.spaceDidChange()
        #expect(fixture.model.minimizedWindows.map(\.window.id) == [4])
        #expect(fixture.model.isSwitchingSpace)
    }

    @Test("Restoring one window removes only its tile while leaving its app and minimized sibling")
    func removesRestoredTile() {
        let fixture = MinimizedDockFixture()
        fixture.model.refresh()
        fixture.tracker.snapshots[100] = [fixture.window(1), fixture.window(2), fixture.window(3, minimized: true, title: "Meeting notes")]
        fixture.model.refresh()
        #expect(fixture.model.applications.count == 1)
        #expect(fixture.model.minimizedWindows.map(\.window.id) == [3])
    }

    @Test("Panel length includes minimized tiles even if the app list is unchanged")
    func panelIncludesWindowSlots() throws {
        let fixture = MinimizedDockFixture()
        fixture.model.refresh()
        var surfaces: [UInt64: MinimizedSurface] = [:]
        let display = DockDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875))
        let controller = DockPanelController(model: fixture.model, preferences: fixture.preferences, displayProvider: { display }, makeSurface: { id in
            let surface = MinimizedSurface()
            surfaces[id ?? 0] = surface
            return surface
        }, report: { _ in })
        defer { controller.stop() }
        let surface = try #require(surfaces[100])
        #expect(surface.minimized.map(\.window.id) == [2, 3])
        #expect(surface.frame.width == DockGeometry.contentSize(applicationCount: 3, style: fixture.preferences.style).width)
        fixture.tracker.snapshots[100] = [fixture.window(1)]
        fixture.model.refresh()
        controller.synchronizePanels()
        #expect(surface.minimized.isEmpty)
        #expect(surface.frame.width == DockGeometry.contentSize(applicationCount: 1, style: fixture.preferences.style).width)
    }

    @Test("A renamed minimized window updates its label without changing its identity")
    func updatesTitle() {
        let fixture = MinimizedDockFixture()
        fixture.model.refresh()
        let originalID = fixture.model.minimizedWindows[0].id
        fixture.tracker.snapshots[100] = [fixture.window(2, minimized: true, title: "Updated budget")]
        fixture.model.refresh()
        #expect(fixture.model.minimizedWindows.first?.id == originalID)
        #expect(fixture.model.minimizedWindows.first?.name == "Updated budget")
    }

    @Test("Window tiles fit the native icon cell at every Dock edge", arguments: DockEdge.allCases)
    func nativeCellSize(_ edge: DockEdge) throws {
        _ = NSApplication.shared
        let fixture = MinimizedDockFixture()
        let item = DockMinimizedWindow(application: .current, window: fixture.window(2, minimized: true, title: "Budget"))
        let style = DockStyle(edge: edge)
        let renderer = ImageRenderer(content: DockMinimizedWindowIcon(window: item, style: style, startsSection: true, restore: {}))
        let image = try #require(renderer.nsImage)
        #expect(image.size == DockIconLayout(style: style, isActive: false).size)
    }
}

@MainActor
private final class MinimizedDockFixture {
    let preferences = DockPreferences()
    let tracker = MinimizedModelTracker()
    var restored: [UInt32] = []
    lazy var model = DockModel(preferences: preferences, windowTracker: tracker,
        runningApplications: { [.current] }, displayBounds: { CGRect(x: 0, y: 0, width: 1440, height: 900) },
        restoreWindow: { [unowned self] _, window in restored.append(window.id) })

    init() {
        tracker.snapshots = [100: [window(1), window(2, minimized: true, title: "Budget"), window(3, minimized: true, title: "Meeting notes")],
                             200: [window(4, minimized: true, title: "Other Desktop")]]
    }
    func window(_ id: UInt32, minimized: Bool = false, title: String? = nil) -> SpaceWindow {
        SpaceWindow(id: id, processID: NSRunningApplication.current.processIdentifier,
                    bounds: CGRect(x: 10, y: 10, width: 800, height: 600), isOnScreen: !minimized, isMinimized: minimized, title: title)
    }
}

@MainActor
private final class MinimizedModelTracker: SpaceWindowTracking {
    var usesSkyLight = true
    var hasFreshSnapshot = true
    var backendDescription = "Fixture"
    var active: UInt64 = 100
    var selectionAvailable = true
    var snapshots: [UInt64: [SpaceWindow]] = [:]
    func refresh(regularProcessIDs: Set<Int32>) {}
    func activeSpaceID(on displayBounds: CGRect) -> UInt64? { active }
    func selection(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> SpaceWindowSelection? {
        selectionAvailable ? SpaceWindowSelection(spaceID: active, windows: snapshots[active] ?? []) : nil
    }
    func allSelections(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> [UInt64: [SpaceWindow]]? { snapshots }
}

@MainActor
private final class MinimizedSurface: DockSurface {
    var frame = CGRect.zero
    var isOrdered = false
    var isKeyWindow = false
    var windowNumber = 1
    var minimized: [DockMinimizedWindow] = []
    func update(applications: [DockApplication], isUpdating: Bool, layout: DockPanelLayout) { frame = layout.frame }
    func update(applications: [DockApplication], minimizedWindows: [DockMinimizedWindow], isUpdating: Bool, layout: DockPanelLayout) {
        minimized = minimizedWindows
        frame = layout.frame
    }
    func updateFocus(_ processID: Int32?) {}
    func attach(to spaceID: UInt64) -> Bool { true }
    func show() { isOrdered = true }
    func hide() { isOrdered = false }
    func close() { isOrdered = false }
}
