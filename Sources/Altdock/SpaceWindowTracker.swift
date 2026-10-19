import AltdockCore
import CoreGraphics
import Foundation

struct SpaceWindowSelection {
    let spaceID: UInt64?
    let windows: [SpaceWindow]
}

@MainActor
protocol SpaceWindowTracking {
    var usesSkyLight: Bool { get }
    var backendDescription: String { get }
    func refresh(regularProcessIDs: Set<Int32>)
    func selection(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> SpaceWindowSelection?
}

@MainActor
final class SpaceWindowTracker: SpaceWindowTracking {
    private let spaces: SkyLightSpaces?
    private(set) var index: SpaceWindowIndex?
    private var onScreenWindows: [SpaceWindow]?

    var usesSkyLight: Bool { index != nil }
    var backendDescription: String { usesSkyLight ? "SkyLight · All Spaces" : "Public API · On-screen fallback" }

    init(usePrivateAPI: Bool = true) {
        spaces = usePrivateAPI ? SkyLightSpaces() : nil
    }

    func refresh(regularProcessIDs: Set<Int32>) {
        if let snapshot = allSpacesSnapshot(regularProcessIDs: regularProcessIDs) {
            index = snapshot
            onScreenWindows = nil
        } else {
            index = nil
            onScreenWindows = WindowSnapshot.capture(options: [.optionOnScreenOnly, .excludeDesktopElements])
        }
    }

    func selection(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> SpaceWindowSelection? {
        let spaceID: UInt64?
        let windows: [SpaceWindow]
        if let index {
            guard let activeID = spaces?.activeSpaceID(on: displayBounds),
                  let cachedWindows = index.windows(in: activeID) else { return nil }
            spaceID = activeID
            windows = cachedWindows
        } else {
            guard let onScreenWindows else { return nil }
            spaceID = nil
            windows = onScreenWindows
        }
        return SpaceWindowSelection(
            spaceID: spaceID,
            windows: SpaceApplications.windows(
                from: windows, regularProcessIDs: regularProcessIDs,
                excluding: ProcessInfo.processInfo.processIdentifier,
                on: displayBounds, requiringOnScreen: spaceID == nil
            )
        )
    }

    private func allSpacesSnapshot(regularProcessIDs: Set<Int32>) -> SpaceWindowIndex? {
        guard let spaces, let spaceIDs = spaces.allSpaceIDs(),
              let windows = WindowSnapshot.capture(options: [.optionAll, .excludeDesktopElements]) else { return nil }
        let candidates = SpaceApplications.windows(
            from: windows, regularProcessIDs: regularProcessIDs,
            excluding: ProcessInfo.processInfo.processIdentifier,
            on: .infinite, requiringOnScreen: false
        )
        var membership: [UInt32: Set<UInt64>] = [:]
        for window in candidates {
            guard let identifiers = spaces.spaceIDs(for: window.id) else { return nil }
            membership[window.id] = identifiers
        }
        return SpaceWindowIndex(windows: candidates, membership: membership, knownSpaceIDs: spaceIDs)
    }
}
