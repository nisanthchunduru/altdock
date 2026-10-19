import AppKit

@main
@MainActor
enum AltdockApp {
    static func main() {
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

    init(windowTracker: SpaceWindowTracker) {
        self.windowTracker = windowTracker
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            NSApp.terminate(nil)
            return
        }

        let preferences = DockPreferences()
        let model = DockModel(preferences: preferences, windowTracker: windowTracker)
        let dock = DockPanelController(model: model, preferences: preferences)
        self.model = model
        self.dock = dock
        statusMenu = StatusMenuController(preferences: preferences, dock: dock, model: model)
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
        dock?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
