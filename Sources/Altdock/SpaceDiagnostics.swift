import AltdockCore
import AppKit

@MainActor
enum SpaceDiagnostics {
    static func printSpaces(using tracker: SpaceWindowTracker, preferences: DockPreferences) {
        let running = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && !$0.isTerminated }
        let names = Dictionary(uniqueKeysWithValues: running.map { ($0.processIdentifier, $0.localizedName ?? "Application") })
        let start = Date()
        tracker.refresh(regularProcessIDs: Set(names.keys))
        print("Backend: \(tracker.backendDescription)")
        print(String(format: "Snapshot: %.1f ms", Date().timeIntervalSince(start) * 1000))
        if let screen = preferences.screen,
           let selection = tracker.selection(on: CGDisplayBounds(screen.displayID), regularProcessIDs: Set(names.keys)) {
            print("Display: \(screen.localizedName); active Space: \(selection.spaceID.map(String.init) ?? "unknown")")
        }
        guard let index = tracker.index else {
            print("All-Spaces membership unavailable; using current on-screen windows.")
            return
        }
        for spaceID in index.spaceIDs.sorted() {
            let windows = index.windows(in: spaceID) ?? []
            print("Space \(spaceID): \(windows.count) windows")
            for processID in SpaceApplications.orderedProcessIDs(windows: windows, previousOrder: [], names: names) {
                print("  \(processID)\t\(names[processID] ?? "Application")")
            }
        }
    }
}
