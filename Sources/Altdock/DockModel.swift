import AltdockCore
import AppKit

struct DockApplication: Identifiable {
    let application: NSRunningApplication
    var id: Int32 { application.processIdentifier }
    var name: String { application.localizedName ?? "Application" }
    var icon: NSImage { application.icon ?? NSImage(named: NSImage.applicationIconName)! }
}

@MainActor
final class DockModel: ObservableObject {
    @Published private(set) var applications: [DockApplication] = []
    @Published private(set) var activeProcessID: Int32?
    @Published private(set) var isSwitchingSpace = true
    @Published private(set) var activeSpaceID: UInt64?
    @Published private(set) var spaceApplications: [UInt64: [DockApplication]]?
    @Published private(set) var fullScreenSpaceIDs: Set<UInt64> = []
    @Published private(set) var desktopDestinations: [DesktopDestination] = []
    @Published private(set) var isMovingWindows = false

    var isFullScreenSpaceActive: Bool { activeSpaceID.map { fullScreenSpaceIDs.contains($0) } ?? false }
    var trackingDescription: String { windowTracker.backendDescription }
    var currentSpaceWindows: [SpaceWindow] {
        guard !isFullScreenSpaceActive, let bounds = displayBounds() else { return [] }
        let processIDs = Set(runningApplications().map(\.processIdentifier))
        if let selection = windowTracker.selection(on: bounds, regularProcessIDs: processIDs),
           !isSwitchingSpace || selection.spaceID != nil { return selection.windows }
        return SpaceApplications.windows(
            from: WindowSnapshot.capture(options: [.optionOnScreenOnly, .excludeDesktopElements]) ?? [],
            regularProcessIDs: processIDs, excluding: ProcessInfo.processInfo.processIdentifier, on: bounds
        )
    }

    private let windowMover: DesktopWindowMover
    private var moveTask: Task<Void, Never>?
    private let displayBounds: () -> CGRect?
    private let windowTracker: any SpaceWindowTracking
    private let runningApplications: () -> [NSRunningApplication]
    private let now: () -> Date
    private let activateApplication: (NSRunningApplication, [SpaceWindow]) -> Void
    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var spaceRefresh: DispatchWorkItem?
    private var fallbackReadyAt = Date.distantPast
    private var iconOrders: [UInt64: [Int32]] = [:]
    private var cachedDisplayBounds: CGRect?

    init(
        preferences: DockPreferences,
        windowMover: DesktopWindowMover = DesktopWindowMover(),
        windowTracker: any SpaceWindowTracking = SpaceWindowTracker(),
        runningApplications: @escaping () -> [NSRunningApplication] = {
            NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && !$0.isTerminated }
        },
        now: @escaping () -> Date = Date.init,
        displayBounds: (() -> CGRect?)? = nil,
        activateApplication: @escaping (NSRunningApplication, [SpaceWindow]) -> Void = {
            ApplicationActivator.activate($0, matching: $1)
        }
    ) {
        self.windowMover = windowMover
        self.displayBounds = displayBounds ?? { preferences.screen.map { CGDisplayBounds($0.displayID) } }
        self.windowTracker = windowTracker
        self.runningApplications = runningApplications
        self.now = now
        self.activateApplication = activateApplication
    }

    func start() {
        let notifications: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.didWakeNotification
        ]
        for name in notifications {
            workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
        workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.spaceDidChange() }
        })
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer?.tolerance = 0.2
        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        spaceRefresh?.cancel()
        moveTask?.cancel()
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        workspaceObservers.removeAll()
    }

    func refresh() {
        let running = runningApplications()
        refreshFullScreenSpaces()
        let destinations = displayBounds().map { windowMover.isAvailable ? windowMover.desktops(on: $0) : [] } ?? []
        if destinations != desktopDestinations { desktopDestinations = destinations }
        windowTracker.refresh(regularProcessIDs: Set(running.map(\.processIdentifier)))
        publishAllSpaces(running: running)
        if !publishSelection(running: running), isSwitchingSpace, now() < fallbackReadyAt {
            scheduleRefresh(after: 0.08)
        }
    }

    func activate(_ application: NSRunningApplication, expectedSpaceID: UInt64? = nil) {
        guard !isSwitchingSpace, !isFullScreenSpaceActive, let bounds = displayBounds() else { return }
        let runningIDs = Set(runningApplications().map(\.processIdentifier))
        windowTracker.refresh(regularProcessIDs: runningIDs)
        guard let selection = windowTracker.selection(on: bounds, regularProcessIDs: runningIDs)
        else { return }
        guard expectedSpaceID == nil || selection.spaceID == expectedSpaceID else { return }
        activateApplication(application, selection.windows.filter { $0.processID == application.processIdentifier })
    }

    func moveWindows(of application: NSRunningApplication, from source: UInt64, to destination: UInt64) {
        guard !isMovingWindows, !isSwitchingSpace, !isFullScreenSpaceActive,
              !application.isTerminated, let bounds = displayBounds() else { return }
        isMovingWindows = true
        moveTask = Task {
            defer { isMovingWindows = false; if !Task.isCancelled { refresh() } }
            do {
                _ = try await windowMover.move(processID: application.processIdentifier, from: source, to: destination, on: bounds)
            } catch is CancellationError {
                return
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    func reorderApplication(_ processID: Int32, to index: Int, on source: UInt64) {
        guard !isSwitchingSpace, !isFullScreenSpaceActive, activeSpaceID == source,
              let bounds = displayBounds(), windowTracker.activeSpaceID(on: bounds) == source,
              let cached = spaceApplications?[source], cached.contains(where: { $0.id == processID }) else { return }
        let orderedIDs = DockIconOrder.moving(processID, to: index, in: cached.map(\.id))
        guard orderedIDs != cached.map(\.id) else { return }
        let byID = Dictionary(uniqueKeysWithValues: cached.map { ($0.id, $0) })
        let ordered = orderedIDs.compactMap { byID[$0] }
        iconOrders[source] = DockIconOrder.replacingVisibleOrder(orderedIDs, previous: iconOrders[source, default: []])
        spaceApplications?[source] = ordered
        applications = ordered
    }

    func spaceDidChange() {
        spaceRefresh?.cancel()
        fallbackReadyAt = now().addingTimeInterval(0.4)
        isSwitchingSpace = true
        refreshFullScreenSpaces()
        _ = publishSelection(running: runningApplications())
        scheduleRefresh(after: windowTracker.usesSkyLight ? 0 : 0.08)
    }

    private var fullScreenDisplayBounds: CGRect?

    private func refreshFullScreenSpaces() {
        let bounds = displayBounds()
        if fullScreenDisplayBounds != bounds {
            fullScreenSpaceIDs = []
            fullScreenDisplayBounds = bounds
        }
        guard let bounds, let ids = windowTracker.fullScreenSpaceIDs(on: bounds) else { return }
        if fullScreenSpaceIDs != ids { fullScreenSpaceIDs = ids }
    }

    private func publishAllSpaces(running: [NSRunningApplication]) {
        let bounds = displayBounds()
        if bounds != cachedDisplayBounds {
            spaceApplications = nil
            cachedDisplayBounds = bounds
        }
        guard let bounds, let selections = windowTracker.allSelections(
            on: bounds, regularProcessIDs: Set(running.map(\.processIdentifier))
        ) else { return }
        let byID = Dictionary(uniqueKeysWithValues: running.map { ($0.processIdentifier, $0) })
        var snapshots: [UInt64: [DockApplication]] = [:]
        for (spaceID, windows) in selections {
            let ordered = SpaceApplications.orderedProcessIDs(
                windows: windows, previousOrder: iconOrders[spaceID, default: []],
                names: byID.mapValues { $0.localizedName ?? "" }
            )
            iconOrders[spaceID] = DockIconOrder.remembering(ordered, previous: iconOrders[spaceID, default: []])
            snapshots[spaceID] = ordered.compactMap { byID[$0].map(DockApplication.init) }
        }
        if spaceApplications?.mapValues({ $0.map(\.id) }) != snapshots.mapValues({ $0.map(\.id) }) {
            spaceApplications = snapshots
        }
    }

    @discardableResult
    private func publishSelection(running: [NSRunningApplication]) -> Bool {
        guard let bounds = displayBounds() else { return false }
        let applicationsByID = Dictionary(uniqueKeysWithValues: running.map { ($0.processIdentifier, $0) })
        guard let selection = windowTracker.selection(
            on: bounds, regularProcessIDs: Set(applicationsByID.keys)
        ), selection.spaceID != nil || !isSwitchingSpace || now() >= fallbackReadyAt else {
            let destination = windowTracker.activeSpaceID(on: bounds)
            let cached = destination.flatMap { spaceApplications?[$0] } ?? []
            let available = cached.filter { applicationsByID[$0.id] != nil }
            if applications.map(\.id) != available.map(\.id) { applications = available }
            if activeSpaceID != destination { activeSpaceID = destination }
            if !isSwitchingSpace { isSwitchingSpace = true }
            return false
        }
        let orderKey = selection.spaceID ?? 0
        let orderedIDs = SpaceApplications.orderedProcessIDs(
            windows: selection.windows, previousOrder: iconOrders[orderKey, default: []],
            names: applicationsByID.mapValues { $0.localizedName ?? "" }
        )
        iconOrders[orderKey] = DockIconOrder.remembering(orderedIDs, previous: iconOrders[orderKey, default: []])
        if orderedIDs != applications.map(\.id) {
            applications = orderedIDs.compactMap { applicationsByID[$0].map(DockApplication.init) }
        }
        let selectedSpaceID = selection.spaceID ?? windowTracker.activeSpaceID(on: bounds)
        if activeSpaceID != selectedSpaceID { activeSpaceID = selectedSpaceID }
        let frontmostID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if activeProcessID != frontmostID { activeProcessID = frontmostID }
        if isSwitchingSpace { isSwitchingSpace = false }
        return true
    }

    private func scheduleRefresh(after delay: TimeInterval) {
        spaceRefresh?.cancel()
        let refresh = DispatchWorkItem { [weak self] in self?.refresh() }
        spaceRefresh = refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: refresh)
    }
}
