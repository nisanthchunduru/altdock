import AltdockCore
import AppKit
import Testing
@testable import Altdock

@Suite("One persistent dock panel per Space")
@MainActor
struct DockPanelControllerTests {
    @Test("Every Space inherits the native Dock edge, thickness, and base icon size", arguments: DockEdge.allCases)
    func nativeDockStyle(_ edge: DockEdge) throws {
        let style = DockStyle(edge: edge, iconSize: 48, footprint: 74)
        let fixture = try PanelFixture(style: style)
        defer { fixture.stop() }
        _ = fixture.controller
        for panel in fixture.factory.created {
            switch edge {
            case .bottom: #expect(panel.frame.minY == 8 && panel.frame.height == 66)
            case .left: #expect(panel.frame.minX == 8 && panel.frame.width == 66)
            case .right: #expect(panel.frame.maxX == 1432 && panel.frame.width == 66)
            }
        }
        #expect(fixture.preferences.iconSize == 48)
    }

    @Test("Cached apps are preloaded while an empty Space's panel stays hidden")
    func preloadsEverySpace() throws {
        let fixture = try PanelFixture()
        defer { fixture.stop() }
        _ = fixture.controller
        let populated = try #require(fixture.factory.latest[100])
        let empty = try #require(fixture.factory.latest[200])
        #expect(populated.applications == [fixture.application.processIdentifier])
        #expect(empty.applications.isEmpty)
        #expect(populated.isOrdered && !empty.isOrdered)
        #expect(fixture.controller.isEnabled)
        #expect(fixture.preferences.reserveSpace)
        #expect(populated.windowNumber != empty.windowNumber)
        #expect(fixture.factory.shared == nil)
    }

    @Test("Switching Spaces reuses panels without swapping icons, resizing, or reattaching them")
    func switchingDoesNotRebuildPanels() throws {
        let fixture = try PanelFixture()
        defer { fixture.stop() }
        _ = fixture.controller
        let first = try #require(fixture.factory.latest[100])
        let second = try #require(fixture.factory.latest[200])
        let firstFrame = first.frame
        let secondFrame = second.frame
        let layoutCount = first.updateCount + second.updateCount
        for id in [UInt64(200), 100, 200] {
            fixture.tracker.activeID = id
            fixture.model.spaceDidChange()
            fixture.controller.updateCurrentSpace()
        }
        #expect(fixture.factory.created.count == 2)
        #expect(fixture.factory.latest[100] === first)
        #expect(fixture.factory.latest[200] === second)
        #expect(first.frame == firstFrame && second.frame == secondFrame)
        #expect(first.updateCount + second.updateCount == layoutCount)
        #expect(first.attachments == [100] && second.attachments == [200])
        #expect(first.applications.count == 1 && second.applications.isEmpty)
        #expect(first.isOrdered && !second.isOrdered)
    }

    @Test("Adding and deleting Spaces creates and closes only the corresponding panels")
    func reconcilesSpaceLifecycle() throws {
        let fixture = try PanelFixture()
        defer { fixture.stop() }
        _ = fixture.controller
        let retained = try #require(fixture.factory.latest[100])
        let removed = try #require(fixture.factory.latest[200])
        fixture.tracker.snapshots?[300] = []
        fixture.tracker.snapshots?.removeValue(forKey: 200)
        fixture.model.refresh()
        fixture.controller.synchronizePanels()
        #expect(fixture.factory.latest[100] === retained)
        #expect(retained.closeCount == 0)
        #expect(removed.closeCount == 1)
        #expect(fixture.factory.latest[300]?.attachments == [300])
        #expect(fixture.factory.created.count == 3)
    }

    @Test("Background app changes update the affected Space's existing presentation")
    func updatesInactiveSpaceContent() throws {
        let fixture = try PanelFixture()
        defer { fixture.stop() }
        _ = fixture.controller
        let background = try #require(fixture.factory.latest[200])
        let windows = fixture.tracker.snapshots?[100]
        fixture.tracker.snapshots?[200] = windows
        fixture.model.refresh()
        fixture.controller.synchronizePanels()
        #expect(fixture.factory.latest[200] === background)
        #expect(background.applications == [fixture.application.processIdentifier])
        #expect(background.attachments == [200])
    }

    @Test("A rejected placement is closed invisibly and uses a shared fallback only where needed")
    func failsSafe() throws {
        let fixture = try PanelFixture()
        defer { fixture.stop() }
        fixture.factory.rejected = [100]
        _ = fixture.controller
        #expect(fixture.factory.latest[100]?.closeCount == 1)
        #expect(fixture.factory.latest[100]?.isOrdered == false)
        #expect(fixture.factory.shared?.isOrdered == true)
        fixture.tracker.activeID = 200
        fixture.model.spaceDidChange()
        fixture.controller.updateCurrentSpace()
        #expect(fixture.factory.shared?.isOrdered == false)
        #expect(fixture.factory.latest[200]?.isOrdered == false)
        fixture.controller.synchronizePanels()
        #expect(fixture.factory.created.filter { $0.spaceID == 100 }.count == 1)
    }

    @Test("Changing displays disposes old panels and creates panels on the new display")
    func displayChanges() throws {
        let fixture = try PanelFixture()
        defer { fixture.stop() }
        _ = fixture.controller
        let old = fixture.factory.created
        fixture.display = DockDisplay(id: 2, frame: CGRect(x: -1440, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: -1440, y: 0, width: 1440, height: 875))
        fixture.controller.synchronizePanels()
        #expect(old.allSatisfy { $0.closeCount == 1 })
        #expect(fixture.factory.created.count == 4)
        #expect(fixture.factory.latest[100]?.frame.maxX ?? 1 < 0)
    }

    @Test("Work-area changes preserve panel identity and cannot lift the dock above an old bottom inset")
    func workAreaChanges() throws {
        let fixture = try PanelFixture()
        defer { fixture.stop() }
        _ = fixture.controller
        let first = try #require(fixture.factory.latest[100])
        let updates = first.updateCount
        fixture.controller.pollDisplayAndVisibility()
        #expect(first.updateCount == updates)
        fixture.display = DockDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 90, width: 1440, height: 785))
        fixture.controller.pollDisplayAndVisibility()
        #expect(fixture.factory.latest[100] === first)
        #expect(first.frame.minY == 8)
        #expect(first.attachments == [100])
        #expect(fixture.factory.created.count == 2)
    }

    @Test("Every Space's panel starts at the physical bottom despite a stale system Dock inset")
    func allPanelsIgnoreStaleBottomInset() throws {
        let fixture = try PanelFixture()
        defer { fixture.stop() }
        fixture.display = DockDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 90, width: 1440, height: 785))
        _ = fixture.controller
        #expect(fixture.factory.created.count == 2)
        #expect(fixture.factory.created.allSatisfy { $0.frame.minY == 8 })
        fixture.tracker.activeID = 200
        fixture.model.spaceDidChange()
        fixture.controller.updateCurrentSpace()
        #expect(fixture.factory.created.allSatisfy { $0.frame.minY == 8 })
    }

    @Test("The shared fallback also ignores the system Dock's old bottom inset")
    func sharedPanelIgnoresStaleBottomInset() throws {
        let fixture = try PanelFixture(usePerSpacePanels: false)
        defer { fixture.stop() }
        fixture.display = DockDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 90, width: 1440, height: 785))
        _ = fixture.controller
        #expect(fixture.factory.shared?.frame.minY == 8)
    }

    @Test("No available display closes every panel without leaving an orphan")
    func noDisplay() throws {
        let fixture = try PanelFixture()
        defer { fixture.stop() }
        _ = fixture.controller
        fixture.display = nil
        fixture.controller.synchronizePanels()
        #expect(fixture.factory.created.allSatisfy { $0.closeCount == 1 })
    }

    @Test("Compatibility mode uses one shared panel and never calls Space placement")
    func sharedCompatibilityMode() throws {
        let fixture = try PanelFixture(usePerSpacePanels: false)
        defer { fixture.stop() }
        _ = fixture.controller
        #expect(fixture.factory.created.count == 1)
        #expect(fixture.factory.shared?.isOrdered == true)
        #expect(fixture.factory.shared?.attachments.isEmpty == true)
    }

    @Test("A failed refresh retains per-Space cached apps instead of replacing them with a shared empty panel")
    func unavailableSnapshots() throws {
        let fixture = try PanelFixture()
        defer { fixture.stop() }
        fixture.tracker.snapshots = nil
        fixture.model.refresh()
        _ = fixture.controller
        #expect(fixture.factory.created.count == 2)
        #expect(fixture.factory.latest[100]?.isOrdered == true)
        #expect(fixture.factory.shared == nil)
    }

    @Test("First app reveals its cached panel and last app hides it without disabling reservation")
    func emptyPanelLifecycle() throws {
        let fixture = try PanelFixture()
        defer { fixture.stop() }
        _ = fixture.controller
        let empty = try #require(fixture.factory.latest[200])
        #expect(!empty.isOrdered)
        let windows = fixture.tracker.snapshots?[100]
        fixture.tracker.snapshots?[200] = windows
        fixture.model.refresh()
        fixture.controller.synchronizePanels()
        #expect(empty.isOrdered)
        fixture.tracker.snapshots?[200] = []
        fixture.model.refresh()
        fixture.controller.synchronizePanels()
        #expect(!empty.isOrdered)
        #expect(fixture.controller.isEnabled)
        #expect(fixture.preferences.reserveSpace)
        #expect(fixture.factory.latest[200] === empty)
    }

    @Test("Auto-hide reveal cannot show an empty panel")
    func cannotRevealEmptyPanel() throws {
        let fixture = try PanelFixture()
        defer { fixture.stop() }
        fixture.preferences.autoHide = true
        fixture.tracker.activeID = 200
        fixture.model.spaceDidChange()
        fixture.controller.reveal()
        #expect(fixture.factory.latest[200]?.isOrdered == false)
        #expect(fixture.controller.isEnabled)
    }

    @Test("An uncached startup displays no panel and does not disable reservation")
    func unknownStartup() throws {
        let fixture = try PanelFixture(hasInitialSnapshot: false)
        defer { fixture.stop() }
        _ = fixture.controller
        #expect(fixture.factory.created.isEmpty)
        #expect(fixture.controller.isEnabled)
        #expect(fixture.preferences.reserveSpace)
    }

    @Test("Global hide/show preserves all panels; quit disposes them and ignores late updates")
    func hideAndStop() throws {
        let fixture = try PanelFixture()
        defer { fixture.stop() }
        fixture.controller.isEnabled = false
        #expect(fixture.factory.created.allSatisfy { !$0.isOrdered && $0.closeCount == 0 })
        fixture.controller.reveal()
        #expect(fixture.factory.created.count == 2)
        #expect(fixture.factory.latest[100]?.isOrdered == true)
        #expect(fixture.factory.latest[200]?.isOrdered == false)
        fixture.controller.stop()
        fixture.controller.synchronizePanels()
        fixture.controller.updateCurrentSpace()
        #expect(fixture.factory.created.allSatisfy { $0.closeCount == 1 })
        #expect(fixture.factory.created.count == 2)
    }
}

@MainActor
private final class PanelFixture {
    let application = NSRunningApplication.current
    let tracker = PanelTracker()
    let factory = SurfaceFactory()
    let preferences: DockPreferences
    private let defaults: UserDefaults
    private let suite = "dev.altdock.panel-tests.\(UUID().uuidString)"
    private let usePerSpacePanels: Bool
    var display: DockDisplay? = DockDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875))
    lazy var model = DockModel(
        preferences: preferences, windowTracker: tracker, runningApplications: { [application] in [application] },
        displayBounds: { CGRect(x: 0, y: 0, width: 1440, height: 900) }
    )
    lazy var controller = DockPanelController(
        model: model, preferences: preferences, usePerSpacePanels: usePerSpacePanels,
        displayProvider: { [weak self] in self?.display },
        makeSurface: { [factory] in factory.make($0) }, report: { _ in }
    )

    init(usePerSpacePanels: Bool = true, style: DockStyle = DockStyle(), hasInitialSnapshot: Bool = true) throws {
        self.usePerSpacePanels = usePerSpacePanels
        defaults = try #require(UserDefaults(suiteName: suite))
        preferences = DockPreferences(defaults: defaults, style: style)
        if hasInitialSnapshot {
            tracker.snapshots = [100: [SpaceWindow(id: 1, processID: application.processIdentifier, bounds: CGRect(x: 0, y: 0, width: 800, height: 600))], 200: []]
        }
        model.refresh()
    }

    func stop() { controller.stop(); model.stop(); defaults.removePersistentDomain(forName: suite) }
}

@MainActor
private final class PanelTracker: SpaceWindowTracking {
    var activeID: UInt64 = 100
    var snapshots: [UInt64: [SpaceWindow]]?
    var usesSkyLight: Bool { snapshots != nil }
    var backendDescription: String { "Fixture" }
    func refresh(regularProcessIDs: Set<Int32>) {}
    func activeSpaceID(on displayBounds: CGRect) -> UInt64? { activeID }
    func selection(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> SpaceWindowSelection? {
        SpaceWindowSelection(spaceID: activeID, windows: snapshots?[activeID] ?? [])
    }
    func allSelections(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> [UInt64: [SpaceWindow]]? { snapshots }
}

@MainActor
private final class SurfaceFactory {
    var rejected: Set<UInt64> = []
    var created: [FakeSurface] = []
    var latest: [UInt64: FakeSurface] = [:]
    var shared: FakeSurface?
    func make(_ spaceID: UInt64?) -> FakeSurface {
        let surface = FakeSurface(spaceID: spaceID, windowNumber: created.count + 1, accepted: spaceID.map { !rejected.contains($0) } ?? true)
        created.append(surface)
        if let spaceID { latest[spaceID] = surface } else { shared = surface }
        return surface
    }
}

@MainActor
private final class FakeSurface: DockSurface {
    let spaceID: UInt64?
    let windowNumber: Int
    let accepted: Bool
    var frame = CGRect.zero
    var isOrdered = false
    var isKeyWindow = false
    var applications: [Int32] = []
    var attachments: [UInt64] = []
    var updateCount = 0
    var closeCount = 0
    init(spaceID: UInt64?, windowNumber: Int, accepted: Bool) { self.spaceID = spaceID; self.windowNumber = windowNumber; self.accepted = accepted }
    func update(applications: [DockApplication], isUpdating: Bool, layout: DockPanelLayout) {
        updateCount += 1
        self.applications = applications.map(\.id)
        frame = layout.frame
    }
    func updateFocus(_ processID: Int32?) {}
    func attach(to spaceID: UInt64) -> Bool { attachments.append(spaceID); return accepted }
    func show() { isOrdered = true }
    func hide() { isOrdered = false }
    func close() { closeCount += 1; isOrdered = false }
}
