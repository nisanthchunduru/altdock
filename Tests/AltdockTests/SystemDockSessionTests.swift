import Foundation
import Testing
@testable import Altdock

@Suite("System Dock settings are borrowed, never lost")
struct SystemDockSessionTests {
    @Test("Launch applies right/auto-hide and normal exit restores the original settings")
    func normalLifecycle() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        let session = fixture.session()
        try session.begin { _ in }
        #expect(fixture.preferences.current == .altdock)
        try session.finish()
        #expect(fixture.preferences.current == fixture.original)
        #expect(!FileManager.default.fileExists(atPath: fixture.record.path))
    }

    @Test("Settings that already match need no preference changes or Dock restart")
    func alreadyConfigured() throws {
        let fixture = try Fixture(original: .altdock)
        defer { fixture.clean() }
        let session = fixture.session()
        try session.begin { _ in }
        try session.finish()
        #expect(fixture.preferences.writes.isEmpty)
    }

    @Test("Previously absent keys are restored as absent, not guessed defaults")
    func missingKeys() throws {
        let fixture = try Fixture(original: SystemDockSettings(orientation: nil, autoHide: nil))
        defer { fixture.clean() }
        let session = fixture.session()
        try session.begin { _ in }
        try session.finish()
        #expect(fixture.preferences.current == fixture.original)
    }

    @Test("A second instance cannot overwrite the first instance's original snapshot")
    func duplicateInstance() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        let owner = fixture.session()
        try owner.begin { _ in }
        let second = fixture.session()
        #expect(throws: SystemDockError.self) { try second.begin { _ in } }
        try owner.finish()
        #expect(fixture.preferences.current == fixture.original)
    }

    @Test("The guardian restores settings after the owner's lock is released without normal cleanup")
    func crashRecovery() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        var owner: SystemDockSession? = fixture.session()
        var token: UUID?
        try owner?.begin { token = $0 }
        owner = nil
        try fixture.session().restoreAfterExit(token: #require(token))
        #expect(fixture.preferences.current == fixture.original)
    }

    @Test("Restart after a crash preserves the original settings rather than snapshotting Altdock's values")
    func relaunchRecovery() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        var first: SystemDockSession? = fixture.session()
        try first?.begin { _ in }
        first = nil
        let second = fixture.session()
        try second.begin { _ in }
        try second.finish()
        #expect(fixture.preferences.current == fixture.original)
    }

    @Test("A stale guardian cannot restore a newer session's settings")
    func staleGuardian() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        var first: SystemDockSession? = fixture.session()
        var oldToken: UUID?
        try first?.begin { oldToken = $0 }
        first = nil
        var second: SystemDockSession? = fixture.session()
        var newToken: UUID?
        try second?.begin { newToken = $0 }
        second = nil
        try fixture.session().restoreAfterExit(token: #require(oldToken))
        #expect(fixture.preferences.current == .altdock)
        try fixture.session().restoreAfterExit(token: #require(newToken))
        #expect(fixture.preferences.current == fixture.original)
    }

    @Test("If the guardian cannot start, launch does not leave the system Dock modified")
    func guardianFailure() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        #expect(throws: SystemDockError.self) {
            try fixture.session().begin { _ in throw SystemDockError.guardianUnavailable }
        }
        #expect(fixture.preferences.current == fixture.original)
        #expect(fixture.preferences.writes.isEmpty)
    }

    @Test("A failed restoration retains the recovery record for another attempt")
    func failedRestoreRetainsBackup() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        let session = fixture.session()
        var token: UUID?
        try session.begin { token = $0 }
        fixture.preferences.rejectWrites = true
        #expect(throws: SystemDockError.self) { try session.finish() }
        #expect(FileManager.default.fileExists(atPath: fixture.record.path))
        fixture.preferences.rejectWrites = false
        try fixture.session().restoreAfterExit(token: #require(token))
        #expect(fixture.preferences.current == fixture.original)
    }

    @Test("Corrupt recovery records fail closed instead of replacing the user's originals")
    func corruptRecord() throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        try Data("invalid".utf8).write(to: fixture.record)
        #expect(throws: SystemDockError.self) { try fixture.session().begin { _ in } }
        #expect(fixture.preferences.writes.isEmpty)
        #expect(try String(contentsOf: fixture.record, encoding: .utf8) == "invalid")
    }
}

private final class Fixture {
    let directory: URL
    let original: SystemDockSettings
    let preferences: FakeDockPreferences
    var record: URL { directory.appendingPathComponent("system-dock.json") }

    init(original: SystemDockSettings = SystemDockSettings(orientation: "bottom", autoHide: false)) throws {
        self.original = original
        preferences = FakeDockPreferences(current: original)
        directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("tmp-workspaces/\(UUID().uuidString)/tmp")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func session() -> SystemDockSession { SystemDockSession(directory: directory, preferences: preferences) }
    func clean() { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
}

private final class FakeDockPreferences: SystemDockPreferenceAccess {
    var current: SystemDockSettings
    var writes: [SystemDockSettings] = []
    var rejectWrites = false

    init(current: SystemDockSettings) { self.current = current }
    func read() throws -> SystemDockSettings { current }
    func apply(_ settings: SystemDockSettings) throws {
        guard settings != current else { return }
        if rejectWrites { throw SystemDockError.preferenceWriteFailed }
        writes.append(settings)
        current = settings
    }
}
