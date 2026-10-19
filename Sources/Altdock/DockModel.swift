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

    var trackingDescription: String { windowTracker.backendDescription }

    private let displayBounds: () -> CGRect?
    private let windowTracker: any SpaceWindowTracking
    private let runningApplications: () -> [NSRunningApplication]
    private let now: () -> Date
    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var spaceRefresh: DispatchWorkItem?
    private var fallbackReadyAt = Date.distantPast
    private var iconOrders: [UInt64: [Int32]] = [:]

    init(
        preferences: DockPreferences,
        windowTracker: any SpaceWindowTracking = SpaceWindowTracker(),
        runningApplications: @escaping () -> [NSRunningApplication] = {
            NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && !$0.isTerminated }
        },
        now: @escaping () -> Date = Date.init,
        displayBounds: (() -> CGRect?)? = nil
    ) {
        self.displayBounds = displayBounds ?? { preferences.screen.map { CGDisplayBounds($0.displayID) } }
        self.windowTracker = windowTracker
        self.runningApplications = runningApplications
        self.now = now
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
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        workspaceObservers.removeAll()
    }

    func refresh() {
        let running = runningApplications()
        windowTracker.refresh(regularProcessIDs: Set(running.map(\.processIdentifier)))
        if !publishSelection(running: running), isSwitchingSpace, now() < fallbackReadyAt {
            scheduleRefresh(after: 0.08)
        }
    }

    func activate(_ application: NSRunningApplication) {
        guard !isSwitchingSpace, let bounds = displayBounds() else { return }
        let runningIDs = Set(runningApplications().map(\.processIdentifier))
        windowTracker.refresh(regularProcessIDs: runningIDs)
        guard let selection = windowTracker.selection(on: bounds, regularProcessIDs: runningIDs)
        else { return }
        ApplicationActivator.activate(application, matching: selection.windows.filter { $0.processID == application.processIdentifier })
    }

    func spaceDidChange() {
        spaceRefresh?.cancel()
        fallbackReadyAt = now().addingTimeInterval(0.4)
        isSwitchingSpace = true
        if windowTracker.usesSkyLight {
            _ = publishSelection(running: runningApplications())
            scheduleRefresh(after: 0)
        } else {
            scheduleRefresh(after: 0.08)
        }
    }

    @discardableResult
    private func publishSelection(running: [NSRunningApplication]) -> Bool {
        guard let bounds = displayBounds() else { return false }
        let applicationsByID = Dictionary(uniqueKeysWithValues: running.map { ($0.processIdentifier, $0) })
        guard let selection = windowTracker.selection(
            on: bounds, regularProcessIDs: Set(applicationsByID.keys)
        ) else { return false }
        guard selection.spaceID != nil || !isSwitchingSpace || now() >= fallbackReadyAt else { return false }
        let orderKey = selection.spaceID ?? 0
        let orderedIDs = SpaceApplications.orderedProcessIDs(
            windows: selection.windows, previousOrder: iconOrders[orderKey, default: []],
            names: applicationsByID.mapValues { $0.localizedName ?? "" }
        )
        iconOrders[orderKey] = orderedIDs
        if orderedIDs != applications.map(\.id) {
            applications = orderedIDs.compactMap { applicationsByID[$0].map(DockApplication.init) }
        }
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
