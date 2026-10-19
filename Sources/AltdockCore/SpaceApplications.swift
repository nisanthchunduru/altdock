import CoreGraphics
import Foundation

public struct SpaceWindow: Equatable {
    public let id: UInt32
    public let processID: Int32
    public let bounds: CGRect
    public let layer: Int
    public let alpha: Double
    public let isOnScreen: Bool

    public init(
        id: UInt32, processID: Int32, bounds: CGRect,
        layer: Int = 0, alpha: Double = 1, isOnScreen: Bool = true
    ) {
        self.id = id
        self.processID = processID
        self.bounds = bounds
        self.layer = layer
        self.alpha = alpha
        self.isOnScreen = isOnScreen
    }
}

public enum SpaceApplications {
    public static func windows(
        from windows: [SpaceWindow],
        regularProcessIDs: Set<Int32>,
        excluding ownProcessID: Int32,
        on displayBounds: CGRect,
        requiringOnScreen: Bool = true
    ) -> [SpaceWindow] {
        windows.filter { window in
            (!requiringOnScreen || window.isOnScreen) && window.layer == 0 && window.alpha > 0
                && window.processID != ownProcessID
                && regularProcessIDs.contains(window.processID)
                && window.bounds.width > 1 && window.bounds.height > 1
                && !window.bounds.intersection(displayBounds).isEmpty
        }
    }

    public static func orderedProcessIDs(
        windows: [SpaceWindow], previousOrder: [Int32], names: [Int32: String]
    ) -> [Int32] {
        let currentIDs = Set(windows.map(\.processID))
        let retainedIDs = previousOrder.filter { currentIDs.contains($0) }
        let addedIDs = currentIDs.subtracting(retainedIDs).sorted { left, right in
            let comparison = (names[left] ?? "").localizedStandardCompare(names[right] ?? "")
            return comparison == .orderedSame ? left < right : comparison == .orderedAscending
        }
        return retainedIDs + addedIDs
    }
}
