import AltdockCore
import AppKit

@MainActor
final class DockFrameAnimator {
    private let panel: NSPanel
    private var transition = DockFrameTransition()
    private var timer: Timer?

    init(panel: NSPanel) { self.panel = panel }

    func move(to frame: CGRect, animated: Bool) {
        timer?.invalidate()
        timer = nil
        transition.setTarget(
            frame, current: panel.frame, at: ProcessInfo.processInfo.systemUptime,
            duration: animated ? DockMembershipAnimation.duration : 0
        )
        if transition.isAnimating {
            let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        tick()
    }

    func reconcile() {
        guard !transition.isAnimating, let target = transition.target else { return }
        apply(target)
    }

    func finish() {
        timer?.invalidate()
        timer = nil
        if let target = transition.finish() { apply(target) }
    }

    private func tick() {
        if !panel.isOnActiveSpace || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            finish()
            return
        }
        guard let frame = transition.frame(at: ProcessInfo.processInfo.systemUptime) else { return }
        apply(frame)
        if !transition.isAnimating {
            timer?.invalidate()
            timer = nil
        }
    }

    private func apply(_ frame: CGRect) {
        guard panel.frame != frame else { return }
        panel.setFrame(frame, display: true)
        panel.contentView?.layoutSubtreeIfNeeded()
    }
}
