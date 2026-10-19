import AltdockCore
import AppKit

@main
@MainActor
enum AltdockApp {
    static func main() {
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--restore-dock-after-exit",
           let token = UUID(uuidString: CommandLine.arguments[2]) {
            do { try SystemDockSession().restoreAfterExit(token: token) }
            catch { NSLog("Altdock Dock recovery failed: %@", error.localizedDescription) }
            return
        }
        if CommandLine.arguments.contains("--panel-status") {
            do { print(try String(contentsOf: DockPanelDiagnostics.fileURL, encoding: .utf8)) }
            catch { print("No panel diagnostics yet. Launch Altdock first.") }
            return
        }
        if CommandLine.arguments.contains("--reservation-status") {
            do { print(try String(contentsOf: ReservationDiagnostics.fileURL, encoding: .utf8)) }
            catch { print("No reservation diagnostics yet. Launch Altdock first.") }
            return
        }
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let tracker = SpaceWindowTracker(usePrivateAPI: !CommandLine.arguments.contains("--public-windows"))

        if CommandLine.arguments.contains("--list-spaces") {
            SpaceDiagnostics.printSpaces(using: tracker, preferences: DockPreferences())
            return
        }

        if CommandLine.arguments.contains("--list-current-space") {
            let preferences = DockPreferences()
            let model = DockModel(preferences: preferences, windowTracker: tracker)
            model.refresh()
            for app in model.applications {
                print("\(app.id)\t\(app.name)")
            }
            return
        }

        let delegate = AppDelegate(windowTracker: tracker)
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowTracker: SpaceWindowTracker
    private var model: DockModel?
    private var dock: DockPanelController?
    private var statusMenu: StatusMenuController?
    private var reservation: WindowReservationController?
    private let systemDock = SystemDockSession()
    private var isQuitting = false

    init(windowTracker: SpaceWindowTracker) {
        self.windowTracker = windowTracker
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try systemDock.begin { [systemDock] token in try systemDock.launchGuardian(token: token) }
        } catch SystemDockError.alreadyRunning {
            NSApp.terminate(nil)
            return
        } catch {
            NSAlert(error: error).runModal()
            NSApp.terminate(nil)
            return
        }

        let preferences = DockPreferences(style: systemDock.dockStyle ?? DockStyle())
        let model = DockModel(preferences: preferences, windowTracker: windowTracker)
        self.model = model
        model.start()
        let dock = DockPanelController(
            model: model, preferences: preferences,
            usePerSpacePanels: !CommandLine.arguments.contains("--shared-panel")
        )
        self.dock = dock
        let reservation = WindowReservationController(preferences: preferences, model: model, dock: dock)
        self.reservation = reservation
        statusMenu = StatusMenuController(preferences: preferences, dock: dock, model: model, reservation: reservation)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isQuitting else { return .terminateLater }
        isQuitting = true
        model?.stop()
        dock?.stop()
        Task {
            await reservation?.stop()
            do { try systemDock.finish() }
            catch { NSLog("Altdock will retry Dock restoration via its recovery helper: %@", error.localizedDescription) }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        try? systemDock.finish()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
