import Testing
@testable import AltdockCore

@Suite("The minimized-window separator has equal spacing to its neighboring artwork")
struct DockMinimizedWindowLayoutTests {
    @Test("Both sides of the separator have the same gap at every edge and icon size", arguments: DockEdge.allCases, [16.0, 32, 48, 64, 96, 128])
    func equalGaps(edge: DockEdge, iconSize: Double) {
        let style = DockStyle(edge: edge, iconSize: iconSize)
        let icon = DockIconLayout(style: style, isActive: false)
        let minimized = DockMinimizedWindowLayout(style: style)
        let previousEnd = edge.isVertical
            ? icon.icon.maxY - icon.size.height - DockIconLayout.spacing
            : icon.icon.maxX - icon.size.width - DockIconLayout.spacing
        let before = (edge.isVertical ? minimized.separator.minY : minimized.separator.minX) - previousEnd
        let after = edge.isVertical
            ? minimized.preview.minY - minimized.separator.maxY
            : minimized.preview.minX - minimized.separator.maxX
        #expect(abs(before - after) < 0.0001)
        #expect(before > 0)
    }

    @Test("The preview retains its original size and remains centered in the native icon bounds", arguments: DockEdge.allCases)
    func preservesTileGeometry(_ edge: DockEdge) {
        let style = DockStyle(edge: edge, iconSize: 64)
        let icon = DockIconLayout(style: style, isActive: false)
        let minimized = DockMinimizedWindowLayout(style: style)
        #expect(abs(minimized.preview.width - 57.6) < 0.0001)
        #expect(abs(minimized.preview.height - 44.8) < 0.0001)
        #expect(minimized.preview.midX == icon.icon.midX)
        #expect(minimized.preview.midY == icon.icon.midY)
    }
}
