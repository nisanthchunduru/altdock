import AltdockCore
import AppKit

@MainActor
final class ApplicationWindowCreator {
    private let commands: any NewWindowCommandRequesting
    private let spaces: (any SpaceQuerying)?
    private let capture: () -> [SpaceWindow]?
    private let wait: @MainActor () async throws -> Void
    private let activate: (NSRunningApplication, SpaceWindow) -> Void
    private let isTerminated: (NSRunningApplication) -> Bool

    init(
        commands: any NewWindowCommandRequesting = NewWindowCommand(),
        spaces: (any SpaceQuerying)? = SkyLightSpaces(),
        capture: @escaping () -> [SpaceWindow]? = { WindowSnapshot.capture(options: [.optionAll, .excludeDesktopElements]) },
        wait: @escaping @MainActor () async throws -> Void = { try await Task.sleep(for: .milliseconds(100)) },
        activate: @escaping (NSRunningApplication, SpaceWindow) -> Void = { ApplicationActivator.activate($0, matching: [$1]) },
        isTerminated: @escaping (NSRunningApplication) -> Bool = { $0.isTerminated }
    ) {
        self.commands = commands
        self.spaces = spaces
        self.capture = capture
        self.wait = wait
        self.activate = activate
        self.isTerminated = isTerminated
    }

    func createWindow(for application: NSRunningApplication) async throws {
        guard !isTerminated(application), let before = capture() else {
            throw NewWindowError(message: "The app or its window information is unavailable. No window was requested.")
        }
        let processID = application.processIdentifier
        let existing = Set(before.filter { $0.processID == processID }.map(\.id))
        try Task.checkCancellation()
        try commands.request(processID: processID)
        for _ in 0..<20 {
            try Task.checkCancellation()
            guard !isTerminated(application) else { break }
            if let snapshot = capture() {
                let candidates = SpaceApplications.windows(from: snapshot, regularProcessIDs: [processID], excluding: -1,
                                                           on: .infinite, requiringOnScreen: false)
                if let created = candidates.first(where: { !existing.contains($0.id) && isOrdered($0) }) {
                    activate(application, created)
                    return
                }
            }
            try await wait()
        }
        throw NewWindowError(message: "The New Window command was sent, but a new window could not be confirmed. The app may use a tab or dialog, reuse its existing window, or still be opening. No duplicate request was sent.")
    }

    private func isOrdered(_ window: SpaceWindow) -> Bool {
        if let spaces { return spaces.isWindowOrderedIn(window.id) == true }
        return window.isOnScreen
    }
}
