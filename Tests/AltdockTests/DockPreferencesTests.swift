import Foundation
import Testing
@testable import Altdock

@Suite("Reservation defaults on without overwriting an explicit user choice")
@MainActor
struct DockPreferencesTests {
    @Test("New and existing installations without a reservation preference enable it")
    func defaultsOn() throws {
        let name = "dev.altdock.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(DockPreferences(defaults: defaults).reserveSpace)
    }

    @Test("An explicit opt-out persists across launches")
    func persistsOptOut() throws {
        let name = "dev.altdock.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = DockPreferences(defaults: defaults)
        preferences.reserveSpace = false
        #expect(!DockPreferences(defaults: defaults).reserveSpace)
    }
}
