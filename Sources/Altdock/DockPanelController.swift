import AltdockCore
import AppKit
import Combine
import SwiftUI

private final class DockPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class DockPanelController: ObservableObject {
    @Published var isEnabled = true {
        didSet { updateVisibility() }
    }

    private let model: DockModel
    private let preferences: DockPreferences
    private let panel: NSPanel
    private var subscriptions: Set<AnyCancellable> = []
    private var screenObserver: NSObjectProtocol?
    private var visibilityTimer: Timer?
    private var lastInteraction = Date.distantPast

    init(model: DockModel, preferences: DockPreferences) {
        self.model = model
        self.preferences = preferences
        panel = DockPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.title = "Altdock"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none

        model.objectWillChange.merge(with: preferences.objectWillChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.updateLayout() }
            .store(in: &subscriptions)
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.model.refresh()
                self?.updateLayout()
            }
        }
        visibilityTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateVisibility() }
        }
        visibilityTimer?.tolerance = 0.05
        updateLayout()
    }

    func stop() {
        visibilityTimer?.invalidate()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        subscriptions.removeAll()
        panel.orderOut(nil)
    }

    func reveal() {
        isEnabled = true
        lastInteraction = Date()
        updateLayout()
    }

    private func updateLayout() {
        guard let screen = preferences.screen else {
            panel.orderOut(nil)
            return
        }
        let iconSize = DockGeometry.iconSize(
            preferred: preferences.iconSize, applicationCount: model.applications.count,
            availableWidth: screen.visibleFrame.width - 24
        )
        let width = model.applications.isEmpty ? 264 : CGFloat(model.applications.count) * (iconSize + 12) + 18
        let size = CGSize(width: width, height: iconSize + 29)
        let frame = DockGeometry.frame(contentSize: size, visibleFrame: screen.visibleFrame, screenFrame: screen.frame)
        if let hostingView = panel.contentView as? NSHostingView<DockView> {
            hostingView.rootView = DockView(model: model, preferences: preferences, iconSize: iconSize)
        } else {
            panel.contentView = NSHostingView(rootView: DockView(model: model, preferences: preferences, iconSize: iconSize))
        }
        panel.setFrame(frame, display: true)
        updateVisibility()
    }

    private func updateVisibility() {
        guard isEnabled, let screen = preferences.screen else {
            panel.orderOut(nil)
            return
        }
        guard preferences.autoHide else {
            if !panel.isVisible { panel.orderFrontRegardless() }
            return
        }
        let mouse = NSEvent.mouseLocation
        let revealZone = CGRect(x: panel.frame.minX, y: screen.frame.minY, width: panel.frame.width, height: 4)
        let travelZone = CGRect(
            x: panel.frame.minX - 10, y: screen.frame.minY,
            width: panel.frame.width + 20, height: panel.frame.maxY - screen.frame.minY + 10
        )
        if revealZone.contains(mouse) || (panel.isVisible && travelZone.contains(mouse)) || panel.isKeyWindow {
            lastInteraction = Date()
        }
        if Date().timeIntervalSince(lastInteraction) < 0.65 {
            if !panel.isVisible { panel.orderFrontRegardless() }
        } else if panel.isVisible {
            panel.orderOut(nil)
        }
    }
}
