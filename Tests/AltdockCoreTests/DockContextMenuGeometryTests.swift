import CoreGraphics
import Testing
@testable import AltdockCore

@Suite("Context menus are anchored outside the Dock rather than at the pointer")
struct DockContextMenuGeometryTests {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let menu = CGSize(width: 220, height: 240)

    @Test("Bottom menus open above the Dock near the clicked icon")
    func bottomAnchor() {
        let dock = CGRect(x: 500, y: 8, width: 400, height: 82)
        let icon = CGRect(x: 600, y: 8, width: 70, height: 82)
        let frame = DockContextMenuGeometry.frame(menuSize: menu, icon: icon, dock: dock, screen: screen, edge: .bottom)
        #expect(frame.minY == dock.maxY + 6)
        #expect(frame.minX == icon.midX - 24)
        #expect(!frame.intersects(dock))
    }

    @Test("Side-dock menus open inward and align vertically with the icon", arguments: [DockEdge.left, .right])
    func sideAnchors(_ edge: DockEdge) {
        let dock = CGRect(x: edge == .left ? 8 : 1350, y: 200, width: 82, height: 400)
        let icon = CGRect(x: dock.minX, y: 350, width: 82, height: 70)
        let frame = DockContextMenuGeometry.frame(menuSize: menu, icon: icon, dock: dock, screen: screen, edge: edge)
        #expect(frame.midY == icon.midY)
        #expect(edge == .left ? frame.minX == dock.maxX + 6 : frame.maxX == dock.minX - 6)
        #expect(!frame.intersects(dock))
    }

    @Test("Menus near screen corners remain on screen", arguments: DockEdge.allCases)
    func clampsToScreen(_ edge: DockEdge) {
        for point in [CGPoint(x: 0, y: 0), CGPoint(x: 1430, y: 890)] {
            let frame = DockContextMenuGeometry.frame(menuSize: menu, icon: CGRect(origin: point, size: CGSize(width: 64, height: 64)),
                dock: CGRect(x: 0, y: 0, width: 82, height: 82), screen: screen, edge: edge)
            #expect(screen.insetBy(dx: 4, dy: 4).contains(frame))
        }
    }

    @Test("Negative display coordinates use that display's bounds")
    func negativeDisplay() {
        let display = CGRect(x: -1440, y: -200, width: 1440, height: 900)
        let dock = CGRect(x: -1000, y: -192, width: 400, height: 82)
        let icon = CGRect(x: -900, y: -192, width: 70, height: 82)
        let frame = DockContextMenuGeometry.frame(menuSize: menu, icon: icon, dock: dock, screen: display, edge: .bottom)
        #expect(frame.minX == icon.midX - 24)
        #expect(frame.minY == dock.maxY + 6)
        #expect(display.contains(frame))
    }

    @Test("Right-to-left bottom menus mirror their horizontal attachment")
    func rightToLeft() {
        let dock = CGRect(x: 500, y: 8, width: 400, height: 82)
        let icon = CGRect(x: 700, y: 8, width: 70, height: 82)
        let frame = DockContextMenuGeometry.frame(menuSize: menu, icon: icon, dock: dock, screen: screen, edge: .bottom, rightToLeft: true)
        #expect(frame.maxX == icon.midX + 24)
    }

    @Test("Oversized menus produce an on-screen target for AppKit's final clipping and scrolling")
    func oversizedMenu() {
        let frame = DockContextMenuGeometry.frame(menuSize: CGSize(width: 2000, height: 1600),
            icon: CGRect(x: 600, y: 8, width: 70, height: 82), dock: CGRect(x: 500, y: 8, width: 400, height: 82), screen: screen, edge: .bottom)
        #expect(frame == screen.insetBy(dx: 4, dy: 4))
    }
}
