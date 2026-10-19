import AltdockCore
import CoreGraphics
import Testing

@Suite("Stable space above the dock for maximized and tiled windows")
struct ReservationGeometryTests {
    private let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let visible = CGRect(x: 0, y: 25, width: 1440, height: 875)
    private var geometry: ReservationGeometry { ReservationGeometry(display: display, visible: visible, preferredIconSize: 52) }

    @Test("Maximized windows keep their top, left, and width while their bottom clears the dock")
    func maximizedWindow() {
        #expect(geometry.target(for: visible) == CGRect(x: 0, y: 25, width: 1440, height: 782))
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
        #expect(target.maxY == 807)
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
        let geometry = ReservationGeometry(
            display: CGRect(x: -1440, y: -900, width: 1440, height: 900),
            visible: CGRect(x: -1440, y: -875, width: 1440, height: 875), preferredIconSize: 52
        )
        #expect(geometry.target(for: geometry.visible) == CGRect(x: -1440, y: -875, width: 1440, height: 782))
    }

    @Test("The configured size determines clearance, not app count or current icon shrinkage")
    func configuredSize() {
        #expect(geometry.bottomLimit == 807)
        #expect(ReservationGeometry(display: display, visible: visible, preferredIconSize: 64).bottomLimit == 795)
    }

    @Test("Existing bottom reservations are respected and not overwritten")
    func systemDockInset() throws {
        let inset = CGRect(x: 0, y: 25, width: 1440, height: 795)
        let target = try #require(ReservationGeometry(display: display, visible: inset, preferredIconSize: 52).target(for: inset))
        #expect(target.maxY == 727)
    }
}
