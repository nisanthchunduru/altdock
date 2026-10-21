import AltdockCore
import AppKit
import SwiftUI

private typealias DockViewState<Value> = SwiftUI.State<Value>

struct DockView: View {
    @ObservedObject var presentation: DockPresentation
    let tooltip: DockTooltipController
    let activate: (NSRunningApplication) -> Void
    var moveWindows: ((NSRunningApplication, UInt64) -> Void)? = nil
    var reorderApplication: ((Int32, Int) -> Void)? = nil
    var restoreMinimizedWindow: ((DockMinimizedWindow) -> Void)? = nil
    @StateObject private var drag = DockIconDragState()
    @GestureState private var dragGestureActive = false

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
        GeometryReader { geometry in
            Group {
                if style.edge.isVertical {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: DockIconLayout.spacing) { icons(panelSize: geometry.size); minimizedIcons }
                            .padding(.vertical, 12)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: drag.preview)
                    }
                    .transition(reduceMotion ? .identity : .opacity)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DockIconLayout.spacing) { icons(panelSize: geometry.size); minimizedIcons }
                            .padding(.horizontal, 12)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: drag.preview)
                    }
                    .transition(reduceMotion ? .identity : .opacity)
                }
            }
        }
        .coordinateSpace(name: "altdock-panel")
        .onChange(of: presentation.applications.map(\.id)) { _ in drag.cancel() }
        .onChange(of: presentation.minimizedWindows.map(\.id)) { _ in drag.cancel() }
        .onChange(of: presentation.isUpdating) { updating in if updating { drag.cancel() } }
        .onChange(of: dragGestureActive) { active in if !active { drag.cancel() } }
        .onDisappear { drag.cancel() }
        .disabled(presentation.isUpdating)
        .background(DockMaterial())
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 0.5).allowsHitTesting(false)
        }
        .accessibilityLabel("Altdock, applications and minimized windows in this Space")
    }

    private var precedingIconTrailingInset: CGFloat {
        let lastID = drag.processID == nil ? presentation.applications.last?.id : drag.preview.last
        guard let application = presentation.applications.first(where: { $0.id == lastID }) else { return 0 }
        return DockIconArtwork.trailingInset(image: application.icon, style: style)
    }

    private var minimizedIcons: some View {
        ForEach(presentation.minimizedWindows) { window in
            DockMinimizedWindowIcon(window: window, style: style, startsSection: window.id == presentation.minimizedWindows.first?.id,
                                    precedingIconTrailingInset: window.id == presentation.minimizedWindows.first?.id ? precedingIconTrailingInset : 0) {
                guard !drag.suppressesClick else { return }
                tooltip.hide()
                restoreMinimizedWindow?(window)
            }
            .disabled(restoreMinimizedWindow == nil)
            .background(DockHoverAnchor(name: window.name, edge: style.edge, enabled: !presentation.isUpdating && drag.processID == nil, tooltip: tooltip))
            .transition(iconTransition)
        }
    }

    private func icons(panelSize: CGSize) -> some View {
        let byID = Dictionary(uniqueKeysWithValues: presentation.applications.map { ($0.id, $0) })
        let displayed = drag.processID == nil ? presentation.applications : drag.preview.compactMap { byID[$0] }
        return ForEach(displayed) { application in
            DockIcon(application: application, isActive: presentation.activeProcessID == application.id, style: style, destinations: presentation.destinations, moveWindows: moveWindows) {
                guard !drag.suppressesClick else { return }
                tooltip.hide()
                activate(application.application)
            }
            .background(DockHoverAnchor(name: application.name, edge: style.edge, enabled: !presentation.isUpdating && drag.processID == nil, tooltip: tooltip))
            .offset(
                x: drag.processID == application.id && !style.edge.isVertical ? drag.displacement(stride: style.iconSize + 12) : 0,
                y: drag.processID == application.id && style.edge.isVertical ? drag.displacement(stride: style.iconSize + 12) : 0
            )
            .zIndex(drag.processID == application.id ? 1 : 0)
            .transaction { transaction in
                if drag.processID == application.id { transaction.animation = nil }
            }
            .simultaneousGesture(DragGesture(minimumDistance: 6, coordinateSpace: .named("altdock-panel"))
                .updating($dragGestureActive) { _, active, _ in active = true }
                .onChanged { value in
                    guard reorderApplication != nil else { return }
                    tooltip.hide()
                    drag.update(processID: application.id, order: presentation.applications.map(\.id), translation: style.edge.isVertical ? value.translation.height : value.translation.width, stride: style.iconSize + 12)
                }
                .onEnded { value in
                    drag.finish(order: presentation.applications.map(\.id), insidePanel: CGRect(origin: .zero, size: panelSize).contains(value.location)) { id, index in
                        reorderApplication?(id, index)
                    }
                })
            .transition(iconTransition)
        }
    }

}

private struct DockIcon: View {
    let application: DockApplication
    let isActive: Bool
    let style: DockStyle
    let destinations: [DesktopDestination]
    let moveWindows: ((NSRunningApplication, UInt64) -> Void)?
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
        .accessibilityLabel(application.name)
        .accessibilityValue(isActive ? "Active application" : "Running")
        .accessibilityHint("Switch to this application")
        .contextMenu {
            Text(application.name)
            Divider()
            Button("Open", action: activate)
            Menu("Move to") {
                ForEach(destinations) { destination in
                    Button(destination.name) { moveWindows?(application.application, destination.id) }
                }
            }.disabled(moveWindows == nil || destinations.isEmpty)
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
