import Foundation

public struct SpaceWindowIndex {
    private let windowsBySpace: [UInt64: [SpaceWindow]]

    public var spaceIDs: Set<UInt64> { Set(windowsBySpace.keys) }

    public init(windows: [SpaceWindow], membership: [UInt32: Set<UInt64>], knownSpaceIDs: Set<UInt64>) {
        var grouped = Dictionary(uniqueKeysWithValues: knownSpaceIDs.map { ($0, [SpaceWindow]()) })
        for window in windows {
            for spaceID in membership[window.id, default: []] where knownSpaceIDs.contains(spaceID) {
                grouped[spaceID, default: []].append(window)
            }
        }
        windowsBySpace = grouped
    }

    public func windows(in spaceID: UInt64) -> [SpaceWindow]? {
        windowsBySpace[spaceID]
    }
}
