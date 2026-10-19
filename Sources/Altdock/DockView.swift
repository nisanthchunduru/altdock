import AppKit
import SwiftUI

private typealias DockViewState<Value> = SwiftUI.State<Value>

struct DockView: View {
    @ObservedObject var model: DockModel
    @ObservedObject var preferences: DockPreferences
    let iconSize: CGFloat

    var body: some View {
        Group {
            if model.applications.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.bottomthird.inset.filled")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("A little room to focus.").font(.system(size: 12, weight: .medium))
                        Text("Open a window in this Space.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(model.applications) { application in
                            DockIcon(
                                application: application,
                                isActive: model.activeProcessID == application.id,
                                size: iconSize,
                                activate: {
                                    ApplicationActivator.activate(application.application, on: preferences.screen)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 14)
                    .padding(.bottom, 6)
                }
            }
        }
        .background(DockMaterial())
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .accessibilityLabel("Altdock, applications in the current Space")
    }
}

private struct DockIcon: View {
    let application: DockApplication
    let isActive: Bool
    let size: CGFloat
    let activate: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @DockViewState private var isHovered = false

    var body: some View {
        Button(action: activate) {
            VStack(spacing: 5) {
                Image(nsImage: application.icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .scaleEffect(isHovered && !reduceMotion ? 1.16 : 1)
                    .offset(y: isHovered && !reduceMotion ? -3 : 0)
                    .shadow(color: .black.opacity(isHovered ? 0.25 : 0.12), radius: 3, y: 2)
                Capsule()
                    .fill(isActive ? Color.primary.opacity(0.85) : Color.primary.opacity(0.35))
                    .frame(width: isActive ? 10 : 4, height: 4)
            }
            .frame(width: size + 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isHovered)
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
