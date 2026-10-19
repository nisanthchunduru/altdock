import Foundation

struct SystemDockSettings: Codable, Equatable {
    let orientation: String?
    let autoHide: Bool?

    static let altdock = SystemDockSettings(orientation: "right", autoHide: true)
}

protocol SystemDockPreferenceAccess {
    func read() throws -> SystemDockSettings
    func apply(_ settings: SystemDockSettings) throws
}

enum SystemDockError: LocalizedError {
    case alreadyRunning, preferenceWriteFailed, backupInvalid, guardianUnavailable

    var errorDescription: String? {
        switch self {
        case .alreadyRunning: "Altdock is already running."
        case .preferenceWriteFailed: "Could not update the system Dock settings. Altdock will attempt to restore the saved settings."
        case .backupInvalid: "Altdock's system Dock recovery record could not be read. No new settings were applied."
        case .guardianUnavailable: "Could not start the system Dock restoration helper. No new settings were applied."
        }
    }
}

struct SystemDockPreferences: SystemDockPreferenceAccess {
    private let domain = "com.apple.dock" as CFString

    func read() throws -> SystemDockSettings {
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            throw SystemDockError.preferenceWriteFailed
        }
        let orientation = CFPreferencesCopyValue("orientation" as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        let autoHide = CFPreferencesCopyValue("autohide" as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard orientation == nil || orientation is String, autoHide == nil || autoHide is NSNumber else {
            throw SystemDockError.backupInvalid
        }
        return SystemDockSettings(orientation: orientation as? String, autoHide: (autoHide as? NSNumber)?.boolValue)
    }

    func apply(_ settings: SystemDockSettings) throws {
        let current = try read()
        guard current != settings else { return }
        var changes: [(String, CFPropertyList?)] = []
        if current.orientation != settings.orientation {
            changes.append(("orientation", settings.orientation.map { $0 as CFString }))
        }
        if current.autoHide != settings.autoHide {
            changes.append(("autohide", settings.autoHide.map { $0 ? kCFBooleanTrue : kCFBooleanFalse }))
        }
        for (key, _) in changes where CFPreferencesAppValueIsForced(key as CFString, domain) {
            throw SystemDockError.preferenceWriteFailed
        }
        for (key, value) in changes {
            CFPreferencesSetValue(key as CFString, value, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost), try read() == settings else {
            throw SystemDockError.preferenceWriteFailed
        }
        let restart = Process()
        restart.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        restart.arguments = ["-u", NSUserName(), "Dock"]
        restart.standardOutput = FileHandle.nullDevice
        restart.standardError = FileHandle.nullDevice
        try restart.run()
        restart.waitUntilExit()
    }
}
