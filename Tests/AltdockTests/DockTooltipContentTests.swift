import AppKit
import Testing
@testable import Altdock

@Suite("Hover labels size to the complete application name")
@MainActor
struct DockTooltipContentTests {
    @Test("Short, long, and Unicode names have enough drawing space", arguments: [
        "Code", "Firefox Developer Edition", "Google Chrome", "Microsoft PowerPoint",
        "日本語のアプリケーション — Éditeur de texte", "An application name longer than the previous three-hundred-and-twenty-point limit"
    ])
    func fullName(_ name: String) {
        let view = DockTooltipContent()
        let size = view.preferredSize(name: name, availableWidth: 1400)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        #expect(view.label.stringValue == name)
        #expect(view.label.lineBreakMode == .byTruncatingTail)
        #expect(view.label.maximumNumberOfLines == 1)
        #expect(view.label.cell?.wraps == false)
        #expect(view.label.frame.width >= ceil((name as NSString).size(withAttributes: [.font: view.label.font!]).width))
        #expect(size.height <= 34, "Names that fit the screen should stay on one line")
        #expect(view.label.frame.height >= ceil(view.label.cell!.cellSize(forBounds: view.label.bounds).height))
    }

    @Test("Hover labels use a 13-point regular system font rather than the smaller default tooltip font")
    func dockLabelFont() {
        let view = DockTooltipContent()
        let expected = NSFont.systemFont(ofSize: 13, weight: .regular)
        #expect(view.label.font?.fontName == expected.fontName)
        #expect(view.label.font?.pointSize == expected.pointSize)
        #expect(view.label.font?.fontDescriptor.symbolicTraits == expected.fontDescriptor.symbolicTraits)
    }

    @Test("Label corners stay fully rounded as its size changes")
    func roundedCorners() {
        let view = DockTooltipContent()
        for name in ["Code", "Firefox Developer Edition"] {
            view.frame = CGRect(origin: .zero, size: view.preferredSize(name: name, availableWidth: 1400))
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
            #expect(view.layer?.cornerRadius == view.bounds.height / 2)
            #expect(view.layer?.masksToBounds == true)
            #expect(view.layer?.cornerCurve == .continuous)
        }
    }

    @Test("Moving from a short app name to a longer one remeasures rather than retaining the short width")
    func changingNames() {
        let view = DockTooltipContent()
        let short = view.preferredSize(name: "Code", availableWidth: 1400)
        view.frame = CGRect(origin: .zero, size: short)
        view.layoutSubtreeIfNeeded()
        let long = view.preferredSize(name: "Firefox Developer Edition", availableWidth: 1400)
        #expect(long.width > short.width)
        let shortAgain = view.preferredSize(name: "Code", availableWidth: 1400)
        #expect(shortAgain == short)
    }

    @Test("Only the screen width limits the label; even oversized names stay on one line")
    func singleLineOnSmallDisplay() {
        let view = DockTooltipContent()
        let name = "An exceptionally long application name that cannot fit on one line on this small display"
        let wide = view.preferredSize(name: name, availableWidth: 1400)
        let narrow = view.preferredSize(name: name, availableWidth: 180)
        view.frame = CGRect(origin: .zero, size: narrow)
        view.layoutSubtreeIfNeeded()
        #expect(narrow.width <= 180)
        #expect(narrow.height == wide.height)
        #expect(view.label.maximumNumberOfLines == 1)
        #expect(view.label.cell?.wraps == false)
        #expect(view.label.stringValue == name)
        #expect(view.label.frame.height >= ceil(view.label.cell!.cellSize(forBounds: view.label.bounds).height))
    }
}
