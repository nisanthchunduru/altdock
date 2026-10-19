import CoreGraphics
import Foundation

@MainActor
final class SkyLightSpaces {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias CopyWindowSpaces = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias CopyDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias CopyDisplayIdentifier = @convention(c) (Int32, CGRect) -> Unmanaged<CFString>?
    private typealias CurrentSpace = @convention(c) (Int32, CFString) -> UInt64

    private let library: DynamicLibrary
    private let connection: Int32
    private let copyWindowSpaces: CopyWindowSpaces
    private let copyDisplaySpaces: CopyDisplaySpaces
    private let copyDisplayIdentifier: CopyDisplayIdentifier
    private let currentSpace: CurrentSpace

    init?() {
        guard let library = DynamicLibrary(path: "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"),
              let mainConnection = library.symbol("SLSMainConnectionID", as: MainConnection.self),
              let copyWindowSpaces = library.symbol("SLSCopySpacesForWindows", as: CopyWindowSpaces.self),
              let copyDisplaySpaces = library.symbol("SLSCopyManagedDisplaySpaces", as: CopyDisplaySpaces.self),
              let copyDisplayIdentifier = library.symbol("SLSCopyBestManagedDisplayForRect", as: CopyDisplayIdentifier.self),
              let currentSpace = library.symbol("SLSManagedDisplayGetCurrentSpace", as: CurrentSpace.self)
        else { return nil }
        self.library = library
        connection = mainConnection()
        self.copyWindowSpaces = copyWindowSpaces
        self.copyDisplaySpaces = copyDisplaySpaces
        self.copyDisplayIdentifier = copyDisplayIdentifier
        self.currentSpace = currentSpace
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

    func activeSpaceID(on displayBounds: CGRect) -> UInt64? {
        guard let identifier = copyDisplayIdentifier(connection, displayBounds)?.takeRetainedValue() else { return nil }
        let spaceID = currentSpace(connection, identifier)
        return spaceID == 0 ? nil : spaceID
    }
}
