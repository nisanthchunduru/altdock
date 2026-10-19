import AltdockCore
import CoreGraphics
import Testing

@Suite("Icons are centered independently of running indicators")
struct DockIconLayoutTests {
    @Test("Icon centers coincide with their cells at every edge and supported size", arguments: DockEdge.allCases, [CGFloat(16), 32, 48, 64, 96, 128])
    func centeredIcons(_ edge: DockEdge, _ iconSize: CGFloat) {
        let style = DockStyle(edge: edge, iconSize: iconSize)
        let layout = DockIconLayout(style: style, isActive: false)
        #expect(layout.icon.midX == layout.size.width / 2)
        #expect(layout.icon.midY == layout.size.height / 2)
        #expect(layout.icon.size == CGSize(width: iconSize, height: iconSize))
        #expect(edge.isVertical ? layout.size.width == style.panelThickness : layout.size.height == style.panelThickness)
    }

    @Test("The native 64-point icon has equal nine-point cross-axis margins", arguments: DockEdge.allCases)
    func symmetricNativeMargins(_ edge: DockEdge) {
        let layout = DockIconLayout(style: DockStyle(edge: edge), isActive: true)
        if edge.isVertical {
            #expect(layout.icon.minX == 9)
            #expect(layout.size.width - layout.icon.maxX == 9)
        } else {
            #expect(layout.icon.minY == 9)
            #expect(layout.size.height - layout.icon.maxY == 9)
        }
    }

    @Test("A four-point indicator in the native nine-point gap leaves 2.5 points on either side", arguments: DockEdge.allCases)
    func nativeIndicatorClearance(_ edge: DockEdge) {
        for active in [false, true] {
            let layout = DockIconLayout(style: DockStyle(edge: edge), isActive: active)
            switch edge {
            case .bottom:
                #expect(layout.indicator.minY - layout.icon.maxY == 2.5)
                #expect(layout.size.height - layout.indicator.maxY == 2.5)
            case .left:
                #expect(layout.indicator.minX == 2.5)
                #expect(layout.icon.minX - layout.indicator.maxX == 2.5)
            case .right:
                #expect(layout.indicator.minX - layout.icon.maxX == 2.5)
                #expect(layout.size.width - layout.indicator.maxX == 2.5)
            }
        }
    }

    @Test("Changing active indicator length cannot shift the icon or resize its cell", arguments: DockEdge.allCases)
    func activeIndicatorDoesNotAffectLayout(_ edge: DockEdge) {
        let style = DockStyle(edge: edge)
        let running = DockIconLayout(style: style, isActive: false)
        let active = DockIconLayout(style: style, isActive: true)
        #expect(running.icon == active.icon)
        #expect(running.size == active.size)
        #expect(running.indicator != active.indicator)
    }

    @Test("Indicators have equal clearance from the icon and dock borders", arguments: DockEdge.allCases, [CGFloat(23), 26, 48])
    func separateIndicators(_ edge: DockEdge, _ extraFootprint: CGFloat) {
        let style = DockStyle(edge: edge, iconSize: 64, footprint: 64 + extraFootprint)
        let layout = DockIconLayout(style: style, isActive: true)
        #expect(!layout.icon.intersects(layout.indicator))
        #expect(CGRect(origin: .zero, size: layout.size).contains(layout.indicator))
        switch edge {
        case .bottom:
            #expect(layout.indicator.minY - layout.icon.maxY == layout.size.height - layout.indicator.maxY)
            #expect(layout.indicator.midX == layout.icon.midX)
        case .left:
            #expect(layout.indicator.minX == layout.icon.minX - layout.indicator.maxX)
            #expect(layout.indicator.midY == layout.icon.midY)
        case .right:
            #expect(layout.indicator.minX - layout.icon.maxX == layout.size.width - layout.indicator.maxX)
            #expect(layout.indicator.midY == layout.icon.midY)
        }
    }
}
