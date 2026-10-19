import AppKit

@MainActor
final class SpacePanelPlacement {
    private typealias MoveWindows = @convention(c) (Int32, CFArray, UInt64) -> Void
    private typealias MainConnection = @convention(c) () -> Int32
    private let library = DynamicLibrary(path: "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight")
    private let spaces = SkyLightSpaces()

    func attach(_ panel: NSPanel, to spaceID: UInt64) -> Bool {
        guard spaceID != 0, NSApp.windows.contains(where: { $0 === panel }),
              let move = library?.symbol("SLSMoveWindowsToManagedSpace", as: MoveWindows.self),
              let main = library?.symbol("SLSMainConnectionID", as: MainConnection.self) else { return false }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        defer { panel.orderOut(nil) }
        guard panel.windowNumber > 0 else { return false }
        let windowID = UInt32(panel.windowNumber)
        move(main(), [NSNumber(value: windowID)] as CFArray, spaceID)
        return spaces?.spaceIDs(for: windowID) == [spaceID]
    }
}
