import AltdockCore
import AppKit
import Combine

@MainActor
final class WindowReservationController: ObservableObject {
    @Published private(set) var hasAccessibility = false

    private let preferences: DockPreferences
    private let model: DockModel
    private let dock: DockPanelController
    private let engine = ReservationEngine()
    private let diagnostics = ReservationDiagnostics()
    private let permission = AccessibilityPermission.shared
    private var subscriptions: Set<AnyCancellable> = []
    private var timer: Timer?
    private var pending: DispatchWorkItem?
    private var task: Task<Void, Never>?
    private var isRunning = true
    private var inFlight = false
    private var needsAnotherPass = false

    var status: String {
        if !preferences.reserveSpace { return "Space reservation off" }
        if !hasAccessibility { return "Reserve Space needs Accessibility…" }
        return preferences.autoHide || !dock.isEnabled ? "Reservation paused while hidden" : "Reserve Space active (maximized/tiled)"
    }

    init(preferences: DockPreferences, model: DockModel, dock: DockPanelController) {
        self.preferences = preferences
        self.model = model
        self.dock = dock
        Publishers.MergeMany([
            preferences.objectWillChange.eraseToAnyPublisher(),
            model.objectWillChange.eraseToAnyPublisher(),
            dock.objectWillChange.eraseToAnyPublisher()
        ]).receive(on: RunLoop.main).sink { [weak self] in self?.schedule() }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: ReservationWindowEvents.changed)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.schedule() }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.schedule() }.store(in: &subscriptions)
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.schedule() }
        }
        timer?.tolerance = 0.5
        hasAccessibility = permission.isGranted
        schedule()
    }

    func stop() async {
        isRunning = false
        timer?.invalidate()
        pending?.cancel()
        subscriptions.removeAll()
        task?.cancel()
        await task?.value
        await engine.restore()
        await diagnostics.publish(ReservationScanReport(state: "Altdock stopped"))
    }

    private func schedule() {
        guard isRunning, pending == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.pending = nil
            self?.refresh()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func refresh() {
        guard isRunning else { return }
        guard !inFlight else { needsAnotherPass = true; return }
        let trusted = permission.isGranted
        if trusted != hasAccessibility { hasAccessibility = trusted }
        let request = makeRequest()
        if request != nil && CGEventSource.buttonState(.combinedSessionState, button: .left) {
            schedule()
            return
        }
        inFlight = true
        task = Task {
            guard !Task.isCancelled else { inFlight = false; return }
            let report: ReservationScanReport
            if let request { report = await engine.reconcile(request) }
            else {
                if !model.isSwitchingSpace { await engine.restore() }
                report = ReservationScanReport(state: model.isSwitchingSpace ? "Changing Space" : status)
            }
            await diagnostics.publish(report)
            inFlight = false
            if needsAnotherPass { needsAnotherPass = false; schedule() }
        }
    }

    private func makeRequest() -> ReservationRequest? {
        guard preferences.reserveSpace, !preferences.autoHide, dock.isEnabled, hasAccessibility,
              let screen = preferences.screen,
              let primary = NSScreen.screens.first else { return nil }
        let visible = screen.visibleFrame
        let quartzVisible = CGRect(x: visible.minX, y: primary.frame.maxY - visible.maxY, width: visible.width, height: visible.height)
        return ReservationRequest(
            geometry: ReservationGeometry(display: CGDisplayBounds(screen.displayID), visible: quartzVisible, style: preferences.style),
            windows: model.currentSpaceWindows,
            frontmostProcessID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
            interactionGeneration: UInt64(CGEventSource.counterForEventType(.combinedSessionState, eventType: .leftMouseDown)) << 32
                | UInt64(CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown))
        )
    }
}
