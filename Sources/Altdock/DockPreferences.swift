import AltdockCore
import AppKit

@MainActor
final class DockPreferences: ObservableObject {
    let style: DockStyle
    var iconSize: CGFloat { style.iconSize }
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

    init(defaults: UserDefaults = .standard, style: DockStyle = DockStyle()) {
        self.defaults = defaults
        self.style = style
        autoHide = defaults.bool(forKey: "autoHide")
        reserveSpace = defaults.object(forKey: "reserveSpace") as? Bool ?? true
        displayID = CGDirectDisplayID(clamping: defaults.integer(forKey: "displayID"))
    }

    var screen: NSScreen? {
        NSScreen.screens.first { $0.displayID == displayID } ?? NSScreen.screens.first
    }
}
