import AltdockCore
import AppKit
import SwiftUI

private typealias MinimizedIconState<Value> = SwiftUI.State<Value>

struct DockMinimizedWindowIcon: View {
    let window: DockMinimizedWindow
    let style: DockStyle
    let startsSection: Bool
    var precedingIconTrailingInset: CGFloat = 0
    let restore: () -> Void
    @MinimizedIconState private var isHovered = false

    private var layout: DockIconLayout { DockIconLayout(style: style, isActive: false) }
    private var minimizedLayout: DockMinimizedWindowLayout { DockMinimizedWindowLayout(style: style, precedingIconTrailingInset: precedingIconTrailingInset) }

    var body: some View {
        Button(action: restore) {
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .bottomTrailing) {
                    VStack(spacing: 0) {
                        HStack(spacing: 2) {
                            ForEach(0..<3) { _ in Circle().fill(.secondary.opacity(0.5)).frame(width: 3, height: 3) }
                            Spacer(minLength: 0)
                        }
                        .padding(5)
                        .background(.primary.opacity(0.08))
                        Text(window.name)
                            .font(.system(size: max(7, style.iconSize * 0.14)))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(4)
                    }
                    .frame(width: minimizedLayout.preview.width, height: minimizedLayout.preview.height)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.secondary.opacity(0.4), lineWidth: 0.5))
                    .frame(width: style.iconSize, height: style.iconSize, alignment: .center)
                    Image(nsImage: window.application.icon ?? NSImage(named: NSImage.applicationIconName)!)
                        .resizable().interpolation(.high).scaledToFit()
                        .frame(width: style.iconSize * 0.38, height: style.iconSize * 0.38)
                }
                .shadow(color: .black.opacity(isHovered ? 0.3 : 0.15), radius: 3, y: 2)
                .position(x: layout.icon.midX, y: layout.icon.midY)
            }
            .frame(width: layout.size.width, height: layout.size.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .overlay(alignment: .topLeading) {
            if startsSection {
                Rectangle().fill(.primary.opacity(0.2))
                    .frame(width: minimizedLayout.separator.width, height: minimizedLayout.separator.height)
                    .offset(x: minimizedLayout.separator.minX, y: minimizedLayout.separator.minY)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel("Restore \(window.name)")
        .accessibilityValue("Minimized window of \(window.application.localizedName ?? "Application")")
        .accessibilityHint("Restore this specific window on this Desktop")
        .contextMenu {
            Text(window.name)
            Divider()
            Button("Restore", action: restore)
        }
    }
}
