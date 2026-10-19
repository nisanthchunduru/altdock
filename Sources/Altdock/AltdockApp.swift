import AppKit

@main
@MainActor
enum AltdockApp {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)

        if CommandLine.arguments.contains("--list-current-space") {
            let preferences = DockPreferences()
            let model = DockModel(preferences: preferences)
            model.refresh()
            for app in model.applications {
                print("\(app.id)\t\(app.name)")
            }
            return
        }

        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: DockModel?
    private var dock: DockPanelController?
    private var statusMenu: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            NSApp.terminate(nil)
            return
        }

        let preferences = DockPreferences()
        let model = DockModel(preferences: preferences)
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
