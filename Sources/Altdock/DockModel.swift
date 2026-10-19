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

    private let preferences: DockPreferences
    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var spaceRefresh: DispatchWorkItem?
    private var isChangingSpace = false

    init(preferences: DockPreferences) {
        self.preferences = preferences
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
        guard !isChangingSpace else { return }
        guard let screen = preferences.screen else {
            applications = []
            return
        }
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated && !$0.isHidden
        }
        let applicationsByID = Dictionary(uniqueKeysWithValues: running.map { ($0.processIdentifier, $0) })
        let windows = SpaceApplications.windows(
            from: WindowSnapshot.current(), regularProcessIDs: Set(applicationsByID.keys),
            excluding: ProcessInfo.processInfo.processIdentifier,
            on: CGDisplayBounds(screen.displayID)
        )
        let orderedIDs = SpaceApplications.orderedProcessIDs(
            windows: windows, previousOrder: applications.map(\.id),
            names: applicationsByID.mapValues { $0.localizedName ?? "" }
        )
        if orderedIDs != applications.map(\.id) {
            applications = orderedIDs.compactMap { applicationsByID[$0].map(DockApplication.init) }
        }
        let frontmostID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if activeProcessID != frontmostID { activeProcessID = frontmostID }
    }

    private func spaceDidChange() {
        spaceRefresh?.cancel()
        isChangingSpace = true
        applications = []
        let refresh = DispatchWorkItem { [weak self] in
            self?.isChangingSpace = false
            self?.refresh()
        }
        spaceRefresh = refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: refresh)
    }
}
