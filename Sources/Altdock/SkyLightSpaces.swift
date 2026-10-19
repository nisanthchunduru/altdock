import CoreGraphics
import Foundation

@MainActor
protocol SpaceQuerying {
    func spaceIDs(for windowID: UInt32) -> Set<UInt64>?
    func allSpaceIDs() -> Set<UInt64>?
    func spaceIDs(on displayBounds: CGRect) -> Set<UInt64>?
    func activeSpaceID(on displayBounds: CGRect) -> UInt64?
    func isWindowOrderedIn(_ windowID: UInt32) -> Bool?
}

@MainActor
final class SkyLightSpaces: SpaceQuerying {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias CopyWindowSpaces = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias CopyDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias CopyDisplayIdentifier = @convention(c) (Int32, CGRect) -> Unmanaged<CFString>?
    private typealias CurrentSpace = @convention(c) (Int32, CFString) -> UInt64
    private typealias WindowIsOrderedIn = @convention(c) (Int32, UInt32, UnsafeMutablePointer<UInt8>) -> Int32

    private let library: DynamicLibrary
    private let connection: Int32
    private let copyWindowSpaces: CopyWindowSpaces
    private let copyDisplaySpaces: CopyDisplaySpaces
    private let copyDisplayIdentifier: CopyDisplayIdentifier
    private let currentSpace: CurrentSpace
    private let windowIsOrderedIn: WindowIsOrderedIn

    init?() {
        guard let library = DynamicLibrary(path: "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"),
              let mainConnection = library.symbol("SLSMainConnectionID", as: MainConnection.self),
              let copyWindowSpaces = library.symbol("SLSCopySpacesForWindows", as: CopyWindowSpaces.self),
              let copyDisplaySpaces = library.symbol("SLSCopyManagedDisplaySpaces", as: CopyDisplaySpaces.self),
              let copyDisplayIdentifier = library.symbol("SLSCopyBestManagedDisplayForRect", as: CopyDisplayIdentifier.self),
              let currentSpace = library.symbol("SLSManagedDisplayGetCurrentSpace", as: CurrentSpace.self),
              let windowIsOrderedIn = library.symbol("SLSWindowIsOrderedIn", as: WindowIsOrderedIn.self)
        else { return nil }
        self.library = library
        connection = mainConnection()
        self.copyWindowSpaces = copyWindowSpaces
        self.copyDisplaySpaces = copyDisplaySpaces
        self.copyDisplayIdentifier = copyDisplayIdentifier
        self.currentSpace = currentSpace
        self.windowIsOrderedIn = windowIsOrderedIn
    }

    func isWindowOrderedIn(_ windowID: UInt32) -> Bool? {
        var ordered: UInt8 = 0
        guard windowIsOrderedIn(connection, windowID, &ordered) == CGError.success.rawValue else { return nil }
        return ordered != 0
    }

    func spaceIDs(for windowID: UInt32) -> Set<UInt64>? {
        guard let result = copyWindowSpaces(connection, 0x7, [NSNumber(value: windowID)] as CFArray),
              let identifiers = result.takeRetainedValue() as? [NSNumber] else { return nil }
        return Set(identifiers.map(\.uint64Value).filter { $0 != 0 })
    }

    func allSpaceIDs() -> Set<UInt64>? {
        guard let result = copyDisplaySpaces(connection),
              let displays = result.takeRetainedValue() as? [[String: Any]] else { return nil }
        var identifiers: Set<UInt64> = []
        for display in displays {
            guard let spaces = display["Spaces"] as? [[String: Any]] else { return nil }
            for space in spaces {
                guard let identifier = space["ManagedSpaceID"] as? NSNumber else { return nil }
                identifiers.insert(identifier.uint64Value)
            }
        }
        identifiers.remove(0)
        return identifiers.isEmpty ? nil : identifiers
    }

    func spaceIDs(on displayBounds: CGRect) -> Set<UInt64>? {
        guard let identifier = copyDisplayIdentifier(connection, displayBounds)?.takeRetainedValue(),
              let result = copyDisplaySpaces(connection),
              let displays = result.takeRetainedValue() as? [[String: Any]] else { return nil }
        let display = displays.first { $0["Display Identifier"] as? String == identifier as String }
            ?? (displays.count == 1 ? displays.first : nil)
        guard let entries = display?["Spaces"] as? [[String: Any]] else { return nil }
        let identifiers = entries.compactMap { ($0["ManagedSpaceID"] as? NSNumber)?.uint64Value }
        guard identifiers.count == entries.count else { return nil }
        return Set(identifiers.filter { $0 != 0 })
    }

    func activeSpaceID(on displayBounds: CGRect) -> UInt64? {
        guard let identifier = copyDisplayIdentifier(connection, displayBounds)?.takeRetainedValue() else { return nil }
        let spaceID = currentSpace(connection, identifier)
        return spaceID == 0 ? nil : spaceID
    }
}
