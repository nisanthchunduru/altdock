import Foundation
import Testing
@testable import Altdock

@Suite("Native Dock suppression preserves exactly the preferences it borrows")
struct SystemDockPreferencesTests {
    @Test("Applying and restoring changes four keys without touching Dock items or minimize behavior")
    func roundTrip() throws {
        let fixture = PreferencesFixture()
        defer { fixture.clean() }
        fixture.set("orientation", "left" as CFString)
        fixture.set("autohide", kCFBooleanFalse)
        fixture.set("tilesize", NSNumber(value: 72))
        fixture.set("autohide-delay", NSNumber(value: 0.35))
        fixture.set("mineffect", "genie" as CFString)
        fixture.set("persistent-apps", ["untouched"] as CFArray)
        let original = try fixture.preferences.read()
        try fixture.preferences.apply(.parked(replacing: original))
        #expect(try fixture.preferences.read().suppression == .init(tileSize: 1, autoHideDelay: 1000))
        try fixture.preferences.apply(original)
        #expect(try fixture.preferences.read() == original)
        #expect(fixture.value("mineffect") as? String == "genie")
        #expect(fixture.value("persistent-apps") as? [String] == ["untouched"])
        #expect(fixture.restarts == 2)
    }

    @Test("Missing size and delay preferences are removed on restoration, not set to guessed defaults")
    func restoresAbsence() throws {
        let fixture = PreferencesFixture()
        defer { fixture.clean() }
        let original = try fixture.preferences.read()
        try fixture.preferences.apply(.parked(replacing: original))
        try fixture.preferences.apply(original)
        for key in ["orientation", "autohide", "tilesize", "autohide-delay"] {
            #expect(fixture.value(key) == nil)
        }
    }

    @Test("Restoring a legacy record leaves size and delay alone because older versions never captured them")
    func legacyRestore() throws {
        let fixture = PreferencesFixture()
        defer { fixture.clean() }
        fixture.set("tilesize", NSNumber(value: 88))
        fixture.set("autohide-delay", NSNumber(value: 3))
        let legacy = try JSONDecoder().decode(SystemDockSettings.self, from: Data("{\"orientation\":\"bottom\",\"autoHide\":false}".utf8))
        #expect(legacy.suppression == nil)
        try fixture.preferences.apply(legacy)
        #expect(fixture.value("tilesize") as? Double == 88)
        #expect(fixture.value("autohide-delay") as? Double == 3)
    }

    @Test("New records distinguish captured missing preferences from uncaptured legacy preferences")
    func preservesCapturedAbsence() throws {
        let original = SystemDockSettings(orientation: nil, autoHide: nil)
        let decoded = try JSONDecoder().decode(SystemDockSettings.self, from: JSONEncoder().encode(original))
        #expect(decoded.suppression != nil)
        #expect(decoded.suppression?.tileSize == nil)
        #expect(decoded.suppression?.autoHideDelay == nil)
    }

    @Test("Unchanged parked preferences do not restart the system Dock again")
    func skipsRedundantRestart() throws {
        let fixture = PreferencesFixture()
        defer { fixture.clean() }
        let target = SystemDockSettings.parked(replacing: try fixture.preferences.read())
        try fixture.preferences.apply(target)
        try fixture.preferences.apply(target)
        #expect(fixture.restarts == 1)
    }

    @Test("Invalid suppression values fail before overwriting any preference")
    func rejectsInvalidOriginal() throws {
        let fixture = PreferencesFixture()
        defer { fixture.clean() }
        fixture.set("tilesize", "invalid" as CFString)
        #expect(throws: SystemDockError.self) { try fixture.preferences.read() }
        #expect(throws: SystemDockError.self) {
            try fixture.preferences.apply(.parked(replacing: SystemDockSettings(orientation: nil, autoHide: nil)))
        }
        #expect(fixture.value("tilesize") as? String == "invalid")
        #expect(fixture.value("orientation") == nil)
        #expect(fixture.restarts == 0)
    }
}

private final class PreferencesFixture {
    let domain = "dev.altdock.preference-tests.\(UUID().uuidString)"
    var restarts = 0
    lazy var preferences = SystemDockPreferences(domain: domain, restart: { [unowned self] in restarts += 1 })

    func set(_ key: String, _ value: CFPropertyList?) {
        CFPreferencesSetValue(key as CFString, value, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
    func value(_ key: String) -> CFPropertyList? {
        CFPreferencesCopyValue(key as CFString, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
    func clean() {
        for key in ["orientation", "autohide", "tilesize", "autohide-delay", "mineffect", "persistent-apps"] { set(key, nil) }
    }
}
