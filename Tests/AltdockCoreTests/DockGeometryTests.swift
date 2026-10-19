import AltdockCore
import CoreGraphics
import Testing

@Suite("Dock layout")
struct DockGeometryTests {
    @Test("Uses the preferred icon size when applications fit")
    func usesPreferredIconSize() {
        #expect(DockGeometry.iconSize(preferred: 52, applicationCount: 5, availableWidth: 1400) == 52)
    }

    @Test("Shrinks icons when the dock would overflow")
    func shrinksIconsToFit() {
        let size = DockGeometry.iconSize(preferred: 64, applicationCount: 20, availableWidth: 1000)
        #expect(abs(size - 36.8) < 0.01)
    }

    @Test("Keeps icons usable for scrolling when there are many applications")
    func preservesMinimumIconSize() {
        #expect(DockGeometry.iconSize(preferred: 52, applicationCount: 100, availableWidth: 1000) == 24)
    }

    @Test("An empty Space uses the preferred height")
    func sizesEmptyDock() {
        #expect(DockGeometry.iconSize(preferred: 52, applicationCount: 0, availableWidth: 1000) == 52)
    }

    @Test("Centers Altdock above the system Dock without covering it")
    func avoidsSystemDock() {
        let frame = DockGeometry.frame(
            contentSize: CGSize(width: 400, height: 81),
            visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 795),
            screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )
        #expect(frame == CGRect(x: 520, y: 88, width: 400, height: 81))
    }

    @Test("Clamps dock width and positions it on an offset display")
    func fitsOffsetDisplay() {
        let frame = DockGeometry.frame(
            contentSize: CGSize(width: 2000, height: 81),
            visibleFrame: CGRect(x: -1440, y: -200, width: 1440, height: 875),
            screenFrame: CGRect(x: -1440, y: -200, width: 1440, height: 900)
        )
        #expect(frame == CGRect(x: -1428, y: -192, width: 1416, height: 81))
    }
}
