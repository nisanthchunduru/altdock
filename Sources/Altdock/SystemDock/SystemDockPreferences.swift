import AltdockCore
import Foundation

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
    private let domain: CFString
    private let restart: () throws -> Void

    init(domain: String = "com.apple.dock", restart: (() throws -> Void)? = nil) {
        self.domain = domain as CFString
        self.restart = restart ?? Self.restartSystemDock
    }

    func read() throws -> SystemDockSettings {
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            throw SystemDockError.preferenceWriteFailed
        }
        let orientation = CFPreferencesCopyValue("orientation" as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        let autoHide = CFPreferencesCopyValue("autohide" as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard orientation == nil || orientation is String, autoHide == nil || autoHide is NSNumber else {
            throw SystemDockError.backupInvalid
        }
        return SystemDockSettings(
            orientation: orientation as? String, autoHide: (autoHide as? NSNumber)?.boolValue,
            suppression: try SystemDockSuppression(tileSize: number(for: "tilesize"), autoHideDelay: number(for: "autohide-delay"))
        )
    }

    func apply(_ settings: SystemDockSettings) throws {
        let current = try read()
        let settings = settings.preservingUncapturedSuppression(from: current)
        guard current != settings else { return }
        var changes: [(String, CFPropertyList?)] = []
        if current.orientation != settings.orientation {
            changes.append(("orientation", settings.orientation.map { $0 as CFString }))
        }
        if current.autoHide != settings.autoHide {
            changes.append(("autohide", settings.autoHide.map { $0 ? kCFBooleanTrue : kCFBooleanFalse }))
        }
        if let suppression = settings.suppression {
            if current.suppression?.tileSize != suppression.tileSize {
                changes.append(("tilesize", suppression.tileSize.map { NSNumber(value: $0) }))
            }
            if current.suppression?.autoHideDelay != suppression.autoHideDelay {
                changes.append(("autohide-delay", suppression.autoHideDelay.map { NSNumber(value: $0) }))
            }
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
        try restart()
    }

    private func number(for key: String) throws -> Double? {
        guard let value = CFPreferencesCopyValue(key as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else { return nil }
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite else {
            throw SystemDockError.backupInvalid
        }
        return number.doubleValue
    }

    private static func restartSystemDock() throws {
        let restart = Process()
        restart.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        restart.arguments = ["-u", NSUserName(), "Dock"]
        restart.standardOutput = FileHandle.nullDevice
        restart.standardError = FileHandle.nullDevice
        try restart.run()
        restart.waitUntilExit()
    }
}
