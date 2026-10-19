import AppKit
import Testing
@testable import Altdock

@Suite("Native panel frames are reconciled with the current layout")
@MainActor
struct DockFrameAnimatorTests {
    @Test("An unchanged four-icon target repairs a native window stuck at the empty-state width")
    func repairsNativeDrift() {
        _ = NSApplication.shared
        let target = CGRect(x: 703, y: 8, width: 322, height: 82)
        let panel = NSPanel(contentRect: target, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        defer { panel.close() }
        let animator = DockFrameAnimator(panel: panel)
        animator.move(to: target, animated: false)
        panel.setFrame(CGRect(x: 732, y: 8, width: 264, height: 82), display: false)
        animator.reconcile()
        #expect(panel.frame == target)
        animator.finish()
        #expect(panel.frame == target)
    }
}
