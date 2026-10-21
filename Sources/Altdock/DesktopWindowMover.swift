import AltdockCore
import AppKit

struct DesktopMoveError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum DesktopWindowMoveScope: Equatable {
    case all
    case focused
}

@MainActor
final class DesktopWindowMover {
    private let spaces: (any SpaceQuerying)?
    private let bridge: any DesktopMoveRequesting
    private let capture: () -> [SpaceWindow]?
    private let wait: () async throws -> Void
    private let focusedWindowID: (Int32) -> UInt32?
    var isAvailable: Bool { spaces != nil && bridge.isAvailable }

    init(
        spaces: (any SpaceQuerying)? = SkyLightSpaces(),
        bridge: any DesktopMoveRequesting = DesktopMoveBridge(),
        capture: @escaping () -> [SpaceWindow]? = { WindowSnapshot.capture(options: [.optionAll, .excludeDesktopElements]) },
        wait: @escaping () async throws -> Void = { try await Task.sleep(for: .milliseconds(100)) },
        focusedWindowID: @escaping (Int32) -> UInt32? = { NativeApplicationActivation.focusedWindowID(processID: $0) }
    ) {
        self.spaces = spaces
        self.bridge = bridge
        self.capture = capture
        self.wait = wait
        self.focusedWindowID = focusedWindowID
    }

    func desktops(on display: CGRect) -> [DesktopDestination] { spaces?.desktops(on: display) ?? [] }

    func move(processID: Int32, from source: UInt64, to destination: UInt64, on display: CGRect, scope: DesktopWindowMoveScope = .all) async throws -> Int {
        guard let spaces, isAvailable else { throw DesktopMoveError(message: "Moving windows between Desktops is unavailable on this macOS version.") }
        guard source != destination, let desktops = spaces.desktops(on: display),
              desktops.contains(where: { $0.id == source }), desktops.contains(where: { $0.id == destination }) else {
            throw DesktopMoveError(message: "The source or destination Desktop changed. Reopen the menu and try again.")
        }
        guard spaces.activeSpaceID(on: display) == source else { throw DesktopMoveError(message: "The active Desktop changed. No windows were moved.") }
        let focusedID = scope == .focused ? focusedWindowID(processID) : nil
        if scope == .focused && focusedID == nil {
            throw DesktopMoveError(message: "This app's focused window could not be identified. Focus its window and try again. Accessibility access is required.")
        }
        guard let snapshot = capture() else { throw DesktopMoveError(message: "Window information is unavailable. No windows were moved.") }
        let candidates = SpaceApplications.windows(
            from: snapshot, regularProcessIDs: [processID], excluding: ProcessInfo.processInfo.processIdentifier,
            on: display, requiringOnScreen: false
        )
        var selected: [UInt32] = []
        for window in candidates where focusedID == nil || window.id == focusedID {
            guard let ordered = spaces.isWindowOrderedIn(window.id), let membership = spaces.spaceIDs(for: window.id) else {
                throw DesktopMoveError(message: "Window membership could not be verified. No windows were moved.")
            }
            if ordered && membership == [source] { selected.append(window.id) }
        }
        guard !selected.isEmpty else {
            let message = scope == .focused
                ? "The focused window is not movable on this Desktop/display. No sibling windows were moved."
                : "This app has no movable windows on this Desktop. Windows assigned to all Desktops, minimized/hidden windows, and other-Desktop windows are not moved."
            throw DesktopMoveError(message: message)
        }
        try Task.checkCancellation()
        guard spaces.activeSpaceID(on: display) == source,
              spaces.desktops(on: display)?.contains(where: { $0.id == destination }) == true else {
            throw DesktopMoveError(message: "The Desktop changed before the move. No windows were moved.")
        }
        if let focusedID {
            guard focusedWindowID(processID) == focusedID,
                  capture()?.contains(where: {
                      $0.id == focusedID && $0.processID == processID && $0.layer == 0 && $0.alpha > 0
                          && $0.bounds.width > 1 && $0.bounds.height > 1 && !$0.bounds.intersection(display).isEmpty
                  }) == true,
                  spaces.isWindowOrderedIn(focusedID) == true, spaces.spaceIDs(for: focusedID) == [source],
                  spaces.activeSpaceID(on: display) == source,
                  spaces.desktops(on: display)?.contains(where: { $0.id == destination }) == true else {
                throw DesktopMoveError(message: "The focused window changed before the move. No windows were moved.")
            }
        }
        guard bridge.request(windowIDs: selected, destination: destination) else {
            throw DesktopMoveError(message: "macOS could not start the Desktop move.")
        }
        var moved = 0
        for _ in 0..<15 {
            try Task.checkCancellation()
            moved = selected.filter { spaces.spaceIDs(for: $0) == [destination] }.count
            if moved == selected.count { return moved }
            try await wait()
        }
        throw DesktopMoveError(message: "macOS moved \(moved) of \(selected.count) windows. The remaining windows could not be verified on the destination Desktop. No automatic retry or rollback was attempted.")
    }
}
