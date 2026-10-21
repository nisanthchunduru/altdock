import AltdockCore
import AppKit
import Testing
@testable import Altdock

@Suite("New Window uses an app command and never blindly launches another instance")
@MainActor
struct ApplicationWindowCreatorTests {
    @Test("A verified new window is activated without substituting an existing sibling")
    func createsWindow() async throws {
        let fixture = CreationFixture()
        fixture.command.onRequest = { fixture.windows.append(fixture.window(2)) }
        try await fixture.creator.createWindow(for: .current)
        #expect(fixture.command.requests == 1)
        #expect(fixture.activated == [2])
    }

    @Test("Unsupported or disabled commands produce a clear error without retrying or activating the app")
    func unsupportedApplication() async {
        let fixture = CreationFixture()
        fixture.command.failure = NewWindowError(message: "New Window is not supported by this app")
        do {
            try await fixture.creator.createWindow(for: .current)
            Issue.record("Expected unsupported command")
        } catch {
            #expect(error.localizedDescription.contains("not supported"))
            #expect(fixture.command.requests == 1)
            #expect(fixture.waits == 0)
            #expect(fixture.activated.isEmpty)
        }
    }

    @Test("Reusing existing WindowServer IDs does not count as creating another window")
    func singleWindowApplication() async {
        let fixture = CreationFixture()
        do {
            try await fixture.creator.createWindow(for: .current)
            Issue.record("Expected unverified creation")
        } catch {
            #expect(error.localizedDescription.contains("could not be confirmed"))
            #expect(fixture.command.requests == 1)
            #expect(fixture.waits == 20)
            #expect(fixture.activated.isEmpty)
        }
    }

    @Test("Another process's new window cannot satisfy the request")
    func rejectsOtherProcess() async {
        let fixture = CreationFixture()
        fixture.command.onRequest = {
            fixture.windows.append(SpaceWindow(id: 2, processID: -42, bounds: CGRect(x: 0, y: 0, width: 600, height: 400)))
        }
        do {
            try await fixture.creator.createWindow(for: .current)
            Issue.record("Expected rejection")
        } catch { #expect(fixture.activated.isEmpty) }
    }

    @Test("Unavailable baseline window information prevents sending a creation command")
    func missingSnapshot() async {
        let fixture = CreationFixture()
        fixture.captureAvailable = false
        do {
            try await fixture.creator.createWindow(for: .current)
            Issue.record("Expected snapshot error")
        } catch { #expect(fixture.command.requests == 0) }
    }

    @Test("Delayed creation is checked without submitting duplicate New Window commands")
    func waitsForCreation() async throws {
        let fixture = CreationFixture()
        fixture.afterWait = { if fixture.waits == 2 { fixture.windows.append(fixture.window(2)) } }
        try await fixture.creator.createWindow(for: .current)
        #expect(fixture.command.requests == 1)
        #expect(fixture.waits == 2)
        #expect(fixture.activated == [2])
    }

    @Test("Cancellation before execution sends no New Window command")
    func cancelsBeforeRequest() async {
        let fixture = CreationFixture()
        let task = Task { try await fixture.creator.createWindow(for: .current) }
        task.cancel()
        do {
            try await task.value
            Issue.record("Expected cancellation")
        } catch {
            #expect(error is CancellationError)
            #expect(fixture.command.requests == 0)
        }
    }

    @Test("Terminated applications receive no creation request")
    func terminatedApplication() async {
        let fixture = CreationFixture()
        fixture.terminated = true
        do {
            try await fixture.creator.createWindow(for: .current)
            Issue.record("Expected terminated-app rejection")
        } catch { #expect(fixture.command.requests == 0) }
    }

    @Test("Command discovery accepts explicit normal-window commands, not arbitrary New actions")
    func commandPolicy() {
        for title in ["New Window", "New Finder Window", "New Window…", "New Window ...", "New Window with Default Profile"] {
            #expect(NewWindowCommandPolicy.matches(title))
        }
        for title in ["New", "New Tab", "New Document", "New Private Window", "New Incognito Window", "New Playlist"] {
            #expect(!NewWindowCommandPolicy.matches(title))
        }
    }
}

@MainActor
private final class CreationFixture {
    init() { _ = NSApplication.shared }
    let command = CreationCommand()
    lazy var windows = [window(1)]
    var waits = 0
    var activated: [UInt32] = []
    var captureAvailable = true
    var terminated = false
    var afterWait: (() -> Void)?
    lazy var creator = ApplicationWindowCreator(commands: command, spaces: nil,
        capture: { [unowned self] in captureAvailable ? windows : nil },
        wait: { [unowned self] in waits += 1; afterWait?() },
        activate: { [unowned self] _, window in activated.append(window.id) },
        isTerminated: { [unowned self] _ in terminated })
    func window(_ id: UInt32) -> SpaceWindow {
        SpaceWindow(id: id, processID: NSRunningApplication.current.processIdentifier, bounds: CGRect(x: 10, y: 10, width: 600, height: 400))
    }
}

@MainActor
private final class CreationCommand: NewWindowCommandRequesting {
    var requests = 0
    var onRequest: (() -> Void)?
    var failure: NewWindowError?
    func request(processID: Int32) throws {
        requests += 1
        if let failure { throw failure }
        onRequest?()
    }
}
