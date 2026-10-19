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
    func activeSpaceID(on displayBounds: CGRect) -> UInt64?
    func selection(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> SpaceWindowSelection?
    func allSelections(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> [UInt64: [SpaceWindow]]?
}

extension SpaceWindowTracking {
    func activeSpaceID(on displayBounds: CGRect) -> UInt64? { nil }
    func allSelections(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> [UInt64: [SpaceWindow]]? { nil }
}

@MainActor
final class SpaceWindowTracker: SpaceWindowTracking {
    private let spaces: (any SpaceQuerying)?
    private let captureWindows: (CGWindowListOption) -> [SpaceWindow]?
    private(set) var index: SpaceWindowIndex?
    private var onScreenWindows: [SpaceWindow]?
    private var lastSnapshotSucceeded = false

    var usesSkyLight: Bool { index != nil }
    var backendDescription: String {
        guard usesSkyLight else { return "Public API · On-screen fallback" }
        return lastSnapshotSucceeded ? "SkyLight · All Spaces" : "SkyLight · Cached Spaces (refresh pending)"
    }

    init(usePrivateAPI: Bool = true) {
        spaces = usePrivateAPI ? SkyLightSpaces() : nil
        captureWindows = WindowSnapshot.capture
    }

    init(spaces: (any SpaceQuerying)?, captureWindows: @escaping (CGWindowListOption) -> [SpaceWindow]?) {
        self.spaces = spaces
        self.captureWindows = captureWindows
    }

    func refresh(regularProcessIDs: Set<Int32>) {
        if let snapshot = allSpacesSnapshot(regularProcessIDs: regularProcessIDs) {
            index = snapshot
            onScreenWindows = nil
            lastSnapshotSucceeded = true
        } else {
            lastSnapshotSucceeded = false
            if index == nil { onScreenWindows = captureWindows([.optionOnScreenOnly, .excludeDesktopElements]) }
        }
    }

    func activeSpaceID(on displayBounds: CGRect) -> UInt64? {
        spaces?.activeSpaceID(on: displayBounds)
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

    func allSelections(on displayBounds: CGRect, regularProcessIDs: Set<Int32>) -> [UInt64: [SpaceWindow]]? {
        guard let index, let spaceIDs = spaces?.spaceIDs(on: displayBounds) else { return nil }
        var selections: [UInt64: [SpaceWindow]] = [:]
        for spaceID in spaceIDs {
            guard let windows = index.windows(in: spaceID) else { continue }
            selections[spaceID] = SpaceApplications.windows(
                from: windows, regularProcessIDs: regularProcessIDs,
                excluding: ProcessInfo.processInfo.processIdentifier,
                on: displayBounds, requiringOnScreen: false
            )
        }
        return selections
    }

    private func allSpacesSnapshot(regularProcessIDs: Set<Int32>) -> SpaceWindowIndex? {
        guard let spaces, let spaceIDs = spaces.allSpaceIDs(),
              let windows = captureWindows([.optionAll, .excludeDesktopElements]) else { return nil }
        let candidates = SpaceApplications.windows(
            from: windows, regularProcessIDs: regularProcessIDs,
            excluding: ProcessInfo.processInfo.processIdentifier,
            on: .infinite, requiringOnScreen: false
        )
        var membership: [UInt32: Set<UInt64>] = [:]
        for window in candidates {
            guard let isOrderedIn = spaces.isWindowOrderedIn(window.id) else { return nil }
            guard isOrderedIn else { continue }
            guard let identifiers = spaces.spaceIDs(for: window.id) else { return nil }
            membership[window.id] = identifiers
        }
        return SpaceWindowIndex(windows: candidates, membership: membership, knownSpaceIDs: spaceIDs)
    }
}
