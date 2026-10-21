import AltdockCore
import Darwin
import Foundation

final class SystemDockSession {
    private struct Record: Codable {
        let token: UUID
        let original: SystemDockSettings
        let appearance: DockStyle?
    }

    private let directory: URL
    private let preferences: any SystemDockPreferenceAccess
    private let appearanceProvider: (SystemDockSettings) -> DockStyle
    private(set) var dockStyle: DockStyle?
    private var lockDescriptor: Int32 = -1
    private var token: UUID?
    private var recordURL: URL { directory.appendingPathComponent("system-dock.json") }

    static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Altdock", isDirectory: true)
    }

    init(
        directory: URL = defaultDirectory,
        preferences: any SystemDockPreferenceAccess = SystemDockPreferences(),
        appearanceProvider: @escaping (SystemDockSettings) -> DockStyle = NativeDockAppearance.capture
    ) {
        self.directory = directory
        self.preferences = preferences
        self.appearanceProvider = appearanceProvider
    }

    deinit { unlock() }

    func begin(startGuardian: (UUID) throws -> Void) throws {
        try lock(wait: false)
        do {
            let existing = try readRecord()
            let original = try capturedOriginal(existing?.original)
            let appearance = existing?.appearance ?? appearanceProvider(original)
            let record = Record(token: UUID(), original: original, appearance: appearance)
            try JSONEncoder().encode(record).write(to: recordURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: recordURL.path)
            token = record.token
            dockStyle = appearance
            try startGuardian(record.token)
            try preferences.apply(.parked(replacing: original))
        } catch {
            try? restore()
            unlock()
            throw error
        }
    }

    func finish() throws {
        defer { unlock() }
        try restore()
    }

    func restoreAfterExit(token: UUID) throws {
        try lock(wait: true)
        defer { unlock() }
        guard let record = try readRecord(), record.token == token else { return }
        try preferences.apply(record.original)
        try FileManager.default.removeItem(at: recordURL)
    }

    func launchGuardian(token: UUID) throws {
        guard let executable = Bundle.main.executableURL else { throw SystemDockError.guardianUnavailable }
        let child = Process()
        child.executableURL = executable
        child.arguments = ["--restore-dock-after-exit", token.uuidString]
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = FileHandle.nullDevice
        child.standardError = FileHandle.nullDevice
        try child.run()
    }

    private func capturedOriginal(_ saved: SystemDockSettings?) throws -> SystemDockSettings {
        guard let saved else { return try preferences.read() }
        if saved.suppression != nil { return saved }
        return try saved.preservingUncapturedSuppression(from: preferences.read())
    }

    private func restore() throws {
        guard lockDescriptor >= 0, let token, let record = try readRecord(), record.token == token else { return }
        try preferences.apply(record.original)
        try FileManager.default.removeItem(at: recordURL)
        self.token = nil
    }

    private func readRecord() throws -> Record? {
        guard FileManager.default.fileExists(atPath: recordURL.path) else { return nil }
        do { return try JSONDecoder().decode(Record.self, from: Data(contentsOf: recordURL)) }
        catch { throw SystemDockError.backupInvalid }
    }

    private func lock(wait: Bool) throws {
        guard lockDescriptor < 0 else { throw SystemDockError.alreadyRunning }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let descriptor = open(directory.appendingPathComponent("system-dock.lock").path, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw POSIXError(.EACCES) }
        guard flock(descriptor, wait ? LOCK_EX : LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw SystemDockError.alreadyRunning
        }
        lockDescriptor = descriptor
    }

    private func unlock() {
        guard lockDescriptor >= 0 else { return }
        flock(lockDescriptor, LOCK_UN)
        close(lockDescriptor)
        lockDescriptor = -1
    }
}
