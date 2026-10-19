import AltdockCore
import AppKit
import Testing
@testable import Altdock

@Suite("Empty or unresolved dock surfaces never become visible")
@MainActor
struct DockSurfaceVisibilityTests {
    @Test("Show cannot order an empty native panel, whether discovery is pending or complete", arguments: [false, true])
    func emptyNativePanel(_ isUpdating: Bool) {
        _ = NSApplication.shared
        let surface = NativeDockSurface(spaceID: nil, placement: SpacePanelPlacement(), activate: { _ in })
        defer { surface.close() }
        surface.update(
            applications: [], isUpdating: isUpdating,
            layout: DockPanelLayout(frame: CGRect(x: 100, y: 8, width: 24, height: 82), style: DockStyle())
        )
        surface.show()
        #expect(!surface.isOrdered)
    }
}
