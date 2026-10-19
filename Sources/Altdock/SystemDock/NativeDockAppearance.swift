import AltdockCore
import AppKit

enum NativeDockAppearance {
    private typealias GetFloat = @convention(c) () -> Float
    private typealias GetBoolean = @convention(c) () -> UInt8
    private typealias GetRect = @convention(c) (UnsafeMutablePointer<CGRect>) -> Void
    private typealias GetOrientation = @convention(c) (UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Void

    static func capture(original: SystemDockSettings) -> DockStyle {
        let edge = DockEdge(rawValue: original.orientation ?? "bottom") ?? .bottom
        let library = DynamicLibrary(path: "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices")
        let storedSize = CFPreferencesCopyAppValue("tilesize" as CFString, "com.apple.dock" as CFString) as? NSNumber
        let normalized = library?.symbol("CoreDockGetTileSize", as: GetFloat.self)?()
        let iconSize: CGFloat
        if let normalized, normalized.isFinite, (0...1).contains(normalized) {
            iconSize = (CGFloat(normalized) * 112 + 16).rounded()
        } else { iconSize = CGFloat(storedSize?.doubleValue ?? 64) }
        var rect = CGRect.zero
        library?.symbol("CoreDockGetRect", as: GetRect.self)?(&rect)
        var orientation: Int32 = 0
        var pinning: Int32 = 0
        library?.symbol("CoreDockGetOrientationAndPinning", as: GetOrientation.self)?(&orientation, &pinning)
        let magnification = library?.symbol("CoreDockIsMagnificationEnabled", as: GetBoolean.self)?() != 0
        let matchesEdge = (edge == .bottom && orientation == 2) || (edge == .left && orientation == 3) || (edge == .right && orientation == 4)
        let measured = edge.isVertical ? rect.width : rect.height
        let footprint = matchesEdge && !magnification && measured > 0 ? measured : nil
        return DockStyle(edge: edge, iconSize: iconSize, footprint: footprint)
    }
}
