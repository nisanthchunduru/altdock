import AppKit

@MainActor
final class DockPreferences: ObservableObject {
    @Published var iconSize: Double {
        didSet { defaults.set(iconSize, forKey: "iconSize") }
    }
    @Published var autoHide: Bool {
        didSet { defaults.set(autoHide, forKey: "autoHide") }
    }
    @Published var reserveSpace: Bool {
        didSet { defaults.set(reserveSpace, forKey: "reserveSpace") }
    }
    @Published var displayID: CGDirectDisplayID {
        didSet { defaults.set(Int(displayID), forKey: "displayID") }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedSize = defaults.double(forKey: "iconSize")
        iconSize = [40.0, 52.0, 64.0].contains(storedSize) ? storedSize : 52
        autoHide = defaults.bool(forKey: "autoHide")
        reserveSpace = defaults.object(forKey: "reserveSpace") as? Bool ?? true
        displayID = CGDirectDisplayID(clamping: defaults.integer(forKey: "displayID"))
    }

    var screen: NSScreen? {
        NSScreen.screens.first { $0.displayID == displayID } ?? NSScreen.screens.first
    }
}
