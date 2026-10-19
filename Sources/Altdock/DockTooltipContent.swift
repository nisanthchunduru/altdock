import AppKit

@MainActor
final class DockTooltipContent: NSVisualEffectView {
    let label = NSTextField(labelWithString: "")
    private let horizontalPadding: CGFloat = 10
    private let verticalPadding: CGFloat = 6

    init() {
        super.init(frame: .zero)
        material = .toolTip
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .labelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.cell?.wraps = false
        label.cell?.usesSingleLineMode = true
        addSubview(label)
    }

    required init?(coder: NSCoder) { nil }

    func preferredSize(name: String, availableWidth: CGFloat) -> CGSize {
        label.stringValue = name
        let maximumTextWidth = max(1, availableWidth - horizontalPadding * 2)
        let naturalWidth = ceil((name as NSString).size(withAttributes: [.font: label.font!]).width) + 8
        let textWidth = min(naturalWidth, maximumTextWidth)
        label.invalidateIntrinsicContentSize()
        let textHeight = ceil(NSLayoutManager().defaultLineHeight(for: label.font!)) + 2
        return CGSize(width: textWidth + horizontalPadding * 2, height: max(28, textHeight + verticalPadding * 2))
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = min(bounds.width, bounds.height) / 2
        label.frame = bounds.insetBy(dx: horizontalPadding, dy: verticalPadding)
    }
}
