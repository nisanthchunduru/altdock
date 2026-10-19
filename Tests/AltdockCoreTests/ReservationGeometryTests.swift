import AltdockCore
import CoreGraphics
import Testing

@Suite("Native-sized reservation on the original Dock edge")
struct ReservationGeometryTests {
    private let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let visible = CGRect(x: 0, y: 25, width: 1440, height: 875)
    private var geometry: ReservationGeometry { ReservationGeometry(display: display, visible: visible, preferredIconSize: 52) }

    @Test("Bottom reservation keeps top, left, and width while leaving a four-point gap")
    func maximizedWindow() {
        #expect(geometry.target(for: visible) == CGRect(x: 0, y: 25, width: 1440, height: 793))
    }

    @Test("Half and bottom-quarter tiles keep their horizontal alignment", arguments: [
        CGRect(x: 0, y: 25, width: 720, height: 875),
        CGRect(x: 720, y: 25, width: 720, height: 875),
        CGRect(x: 720, y: 462.5, width: 720, height: 437.5)
    ])
    func tiledWindow(_ frame: CGRect) throws {
        let target = try #require(geometry.target(for: frame))
        #expect(target.origin == frame.origin)
        #expect(target.width == frame.width)
        #expect(target.maxY == 818)
    }

    @Test("Floating windows, small corner windows, and top-only tiles are left alone", arguments: [
        CGRect(x: 100, y: 500, width: 800, height: 400),
        CGRect(x: 1140, y: 600, width: 300, height: 300),
        CGRect(x: 0, y: 25, width: 720, height: 400)
    ])
    func ignoresManuallyPlacedWindows(_ frame: CGRect) { #expect(geometry.target(for: frame) == nil) }

    @Test("Windows on other displays and invalid bounds are never resized", arguments: [
        CGRect(x: 1600, y: 25, width: 1440, height: 875), CGRect.zero, CGRect.null, CGRect.infinite
    ])
    func ignoresInvalidOrForeignWindows(_ frame: CGRect) { #expect(geometry.target(for: frame) == nil) }

    @Test("Negative display coordinates work in the same Quartz coordinate system")
    func negativeCoordinates() {
        let geometry = ReservationGeometry(display: CGRect(x: -1440, y: -900, width: 1440, height: 900), visible: CGRect(x: -1440, y: -875, width: 1440, height: 875), preferredIconSize: 52)
        #expect(geometry.target(for: geometry.visible) == CGRect(x: -1440, y: -875, width: 1440, height: 793))
    }

    @Test("Captured native thickness determines clearance, independent of app count")
    func capturedSize() {
        #expect(geometry.limit == 818)
        #expect(ReservationGeometry(display: display, visible: visible, style: DockStyle(iconSize: 64, footprint: 90)).limit == 806)
    }

    @Test("The old system Dock inset is not added to the new reservation")
    func ignoresOldSystemDockInset() throws {
        let inset = CGRect(x: 0, y: 25, width: 1440, height: 805)
        let target = try #require(ReservationGeometry(display: display, visible: inset, preferredIconSize: 52).target(for: inset))
        #expect(target.maxY == 818)
    }

    @Test("Windows reaching the physical edge qualify even when the reported work area is stale")
    func recognizesPhysicalBottomAlignment() throws {
        let inset = CGRect(x: 0, y: 25, width: 1440, height: 795)
        let target = try #require(ReservationGeometry(display: display, visible: inset, preferredIconSize: 52).target(for: visible))
        #expect(target.maxY == 818)
    }

    @Test("Windows already clear of the dock are not expanded")
    func doesNotExpandWindows() {
        let inset = CGRect(x: 0, y: 25, width: 1440, height: 700)
        #expect(ReservationGeometry(display: display, visible: inset, preferredIconSize: 52).target(for: inset) == nil)
    }

    @Test("The native 90-point footprint avoids the former eleven-point excess")
    func observedNativeDockSize() throws {
        let screen = CGRect(x: 0, y: 0, width: 3008, height: 1692)
        let window = CGRect(x: 0, y: 30, width: 3008, height: 1572)
        let style = DockStyle(iconSize: 64, footprint: 90)
        let panel = DockGeometry.frame(contentSize: DockGeometry.contentSize(applicationCount: 8, style: style), visibleFrame: CGRect(x: 0, y: 90, width: 3008, height: 1572), screenFrame: screen)
        let dockTop = screen.maxY - panel.maxY
        #expect(panel.height == 82)
        #expect(window.maxY == dockTop)
        let target = try #require(ReservationGeometry(display: screen, visible: window, style: style).target(for: window))
        #expect(window.height - target.height == 4)
        #expect(dockTop - target.maxY == 4)
    }

    @Test("Left-edge reservation preserves the right border and the window height")
    func leftReservation() throws {
        let geometry = ReservationGeometry(display: display, visible: visible, style: DockStyle(edge: .left))
        let target = try #require(geometry.target(for: visible))
        #expect(target == CGRect(x: 94, y: 25, width: 1346, height: 875))
    }

    @Test("Right-edge reservation preserves the left border and the window height")
    func rightReservation() throws {
        let geometry = ReservationGeometry(display: display, visible: visible, style: DockStyle(edge: .right))
        let target = try #require(geometry.target(for: visible))
        #expect(target == CGRect(x: 0, y: 25, width: 1346, height: 875))
    }

    @Test("Side reservations accept both stale work-area edges and full-display edges", arguments: [DockEdge.left, .right])
    func staleSideInsets(_ edge: DockEdge) throws {
        let inset = edge == .left ? CGRect(x: 90, y: 25, width: 1350, height: 875) : CGRect(x: 0, y: 25, width: 1350, height: 875)
        let geometry = ReservationGeometry(display: display, visible: inset, style: DockStyle(edge: edge))
        #expect(geometry.target(for: inset) != nil)
        #expect(geometry.target(for: visible) != nil)
    }

    @Test("Panels and reservation boundaries share the same native footprint", arguments: DockEdge.allCases)
    func panelAndReservationAgree(_ edge: DockEdge) {
        let style = DockStyle(edge: edge)
        let panel = DockGeometry.frame(contentSize: DockGeometry.contentSize(applicationCount: 5, style: style), visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875), screenFrame: display, edge: edge)
        let reservation = ReservationGeometry(display: display, visible: visible, style: style)
        switch edge {
        case .bottom: #expect(display.maxY - panel.maxY - reservation.limit == 4)
        case .left: #expect(reservation.limit - panel.maxX == 4)
        case .right: #expect(panel.minX - reservation.limit == 4)
        }
    }
}
