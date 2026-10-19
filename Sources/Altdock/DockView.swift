import AltdockCore
import AppKit
import SwiftUI

private typealias DockViewState<Value> = SwiftUI.State<Value>

struct DockView: View {
    @ObservedObject var presentation: DockPresentation
    let activate: (NSRunningApplication) -> Void

    private var style: DockStyle { presentation.style }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var insertionAnchor: UnitPoint {
        switch style.edge {
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }

    private var iconTransition: AnyTransition {
        reduceMotion ? .identity : .scale(scale: 0.01, anchor: insertionAnchor).combined(with: .opacity)
    }

    var body: some View {
        Group {
            if presentation.applications.isEmpty && presentation.isUpdating {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Updating applications")
            } else if presentation.applications.isEmpty {
                emptyState.transition(reduceMotion ? .identity : .opacity)
            } else if style.edge.isVertical {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) { icons }
                        .padding(.vertical, 12)
                }
                .transition(reduceMotion ? .identity : .opacity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) { icons }
                        .padding(.horizontal, 12)
                }
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .disabled(presentation.isUpdating)
        .background(DockMaterial())
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 0.5).allowsHitTesting(false)
        }
        .accessibilityLabel("Altdock, applications in this Space")
    }

    private var icons: some View {
        ForEach(presentation.applications) { application in
            DockIcon(application: application, isActive: presentation.activeProcessID == application.id, style: style) {
                activate(application.application)
            }
            .transition(iconTransition)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.bottomthird.inset.filled").font(.title2).foregroundStyle(.secondary)
            if !style.edge.isVertical {
                VStack(alignment: .leading, spacing: 3) {
                    Text("A little room to focus.").font(.system(size: 12, weight: .medium))
                    Text("Open a window in this Space.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .help("No apps with windows in this Space")
    }
}

private struct DockIcon: View {
    let application: DockApplication
    let isActive: Bool
    let style: DockStyle
    let activate: () -> Void
    @DockViewState private var isHovered = false

    var body: some View {
        Button(action: activate) {
            DockIconContent(
                image: application.icon, layout: DockIconLayout(style: style, isActive: isActive),
                isActive: isActive, isHovered: isHovered
            ).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(application.name)
        .accessibilityLabel(application.name)
        .accessibilityValue(isActive ? "Active application" : "Running")
        .accessibilityHint("Switch to this application")
        .contextMenu {
            Text(application.name)
            Divider()
            Button("Open", action: activate)
            Button("Hide") { application.application.hide() }
            Divider()
            Button("Quit") { application.application.terminate() }
        }
    }
}

private struct DockMaterial: NSViewRepresentable {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = reduceTransparency ? .windowBackground : .hudWindow
    }
}
