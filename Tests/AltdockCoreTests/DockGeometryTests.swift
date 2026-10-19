import AltdockCore
import CoreGraphics
import Testing

@Suite("Dock layout")
struct DockGeometryTests {
    @Test("Reveal and travel regions follow the selected physical screen edge", arguments: DockEdge.allCases)
    func edgeRevealZones(_ edge: DockEdge) {
        let screen = CGRect(x: -1440, y: -900, width: 1440, height: 900)
        let style = DockStyle(edge: edge)
        let panel = DockGeometry.frame(contentSize: DockGeometry.contentSize(applicationCount: 3, style: style), visibleFrame: screen, screenFrame: screen, edge: edge)
        let point: CGPoint
        switch edge {
        case .bottom: point = CGPoint(x: panel.midX, y: screen.minY + 1)
        case .left: point = CGPoint(x: screen.minX + 1, y: panel.midY)
        case .right: point = CGPoint(x: screen.maxX - 1, y: panel.midY)
        }
        #expect(DockGeometry.revealZone(panel: panel, screen: screen, edge: edge).contains(point))
        #expect(DockGeometry.travelZone(panel: panel, screen: screen, edge: edge).contains(point))
        #expect(DockGeometry.travelZone(panel: panel, screen: screen, edge: edge).contains(CGPoint(x: panel.midX, y: panel.midY)))
    }

    @Test("The native 64-point icon baseline occupies a 90-point edge footprint")
    func nativeBaseline() {
        let style = DockStyle()
        #expect(style.iconSize == 64)
        #expect(style.footprint == 90)
        #expect(style.panelThickness == 82)
    }

    @Test("Native icons do not shrink when the dock overflows; the viewport scrolls")
    func preservesNativeIcons() {
        let style = DockStyle(iconSize: 64)
        let content = DockGeometry.contentSize(applicationCount: 100, style: style)
        let frame = DockGeometry.frame(contentSize: content, visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875), screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900))
        #expect(style.iconSize == 64)
        #expect(content.width > frame.width)
        #expect(frame.width == 1416)
    }

    @Test("Vertical docks keep native thickness and clamp only their scrollable length", arguments: [DockEdge.left, .right])
    func verticalDock(_ edge: DockEdge) {
        let style = DockStyle(edge: edge)
        let content = DockGeometry.contentSize(applicationCount: 100, style: style)
        let frame = DockGeometry.frame(contentSize: content, visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875), screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900), edge: edge)
        #expect(frame.width == 82)
        #expect(frame.height == 851)
        #expect(frame.minX == (edge == .left ? 8 : 1350))
    }

    @Test("Empty side docks use a compact icon-sized placeholder")
    func emptySideDock() {
        #expect(DockGeometry.contentSize(applicationCount: 0, style: DockStyle(edge: .left)) == CGSize(width: 82, height: 88))
    }

    @Test("Uses the display bottom instead of the hidden system Dock's old reserved area")
    func ignoresOldSystemDockBottomInset() {
        let frame = DockGeometry.frame(
            contentSize: CGSize(width: 400, height: 81),
            visibleFrame: CGRect(x: 0, y: 80, width: 1440, height: 795),
            screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )
        #expect(frame == CGRect(x: 520, y: 8, width: 400, height: 81))
    }

    @Test("A stale bottom inset on a negatively positioned display does not lift the dock")
    func ignoresInsetOnOffsetDisplay() {
        let frame = DockGeometry.frame(
            contentSize: CGSize(width: 400, height: 81),
            visibleFrame: CGRect(x: -1440, y: -110, width: 1440, height: 785),
            screenFrame: CGRect(x: -1440, y: -200, width: 1440, height: 900)
        )
        #expect(frame.minY == -192)
    }

    @Test("Horizontal work-area insets still constrain the dock while bottom insets do not")
    func preservesHorizontalInsets() {
        let frame = DockGeometry.frame(
            contentSize: CGSize(width: 400, height: 81),
            visibleFrame: CGRect(x: 100, y: 90, width: 1340, height: 785),
            screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900)
        )
        #expect(frame == CGRect(x: 570, y: 8, width: 400, height: 81))
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
