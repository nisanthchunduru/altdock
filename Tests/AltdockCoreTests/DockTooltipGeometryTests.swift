import AltdockCore
import CoreGraphics
import Testing

@Suite("App-name labels appear outside the dock without covering their icons")
struct DockTooltipGeometryTests {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let label = CGSize(width: 180, height: 28)

    @Test("Bottom labels sit above the panel centered on the hovered icon")
    func bottom() {
        let dock = CGRect(x: 500, y: 8, width: 400, height: 82)
        let icon = CGRect(x: 600, y: 8, width: 70, height: 82)
        let frame = DockTooltipGeometry.frame(labelSize: label, icon: icon, dock: dock, screen: screen, edge: .bottom)
        #expect(frame.minY == dock.maxY + 8)
        #expect(frame.midX == icon.midX)
    }

    @Test("Left and right labels appear toward the desktop, not beyond the screen", arguments: [DockEdge.left, .right])
    func sides(_ edge: DockEdge) {
        let dock = CGRect(x: edge == .left ? 8 : 1350, y: 200, width: 82, height: 400)
        let icon = CGRect(x: dock.minX, y: 300, width: 82, height: 70)
        let frame = DockTooltipGeometry.frame(labelSize: label, icon: icon, dock: dock, screen: screen, edge: edge)
        #expect(frame.midY == icon.midY)
        if edge == .left { #expect(frame.minX == dock.maxX + 8) }
        else { #expect(frame.maxX == dock.minX - 8) }
    }

    @Test("Labels for icons near either corner stay within the screen", arguments: [CGFloat(0), 1380])
    func screenBounds(_ x: CGFloat) {
        let frame = DockTooltipGeometry.frame(labelSize: label, icon: CGRect(x: x, y: 8, width: 64, height: 82), dock: CGRect(x: 0, y: 8, width: 1440, height: 82), screen: screen, edge: .bottom)
        #expect(screen.insetBy(dx: 6, dy: 6).contains(frame))
    }

    @Test("Negative display coordinates and oversized labels are handled")
    func offsetDisplay() {
        let screen = CGRect(x: -800, y: -600, width: 800, height: 600)
        let dock = CGRect(x: -600, y: -592, width: 400, height: 82)
        let frame = DockTooltipGeometry.frame(labelSize: CGSize(width: 2000, height: 28), icon: dock, dock: dock, screen: screen, edge: .bottom)
        #expect(frame.width == 788)
        #expect(screen.insetBy(dx: 6, dy: 6).contains(frame))
        #expect(frame.minY == dock.maxY + 8)
    }
}
