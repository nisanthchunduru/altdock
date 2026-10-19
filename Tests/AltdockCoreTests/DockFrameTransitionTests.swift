import AltdockCore
import CoreGraphics
import Testing

@Suite("Panel resizing always finishes at the latest app-list width")
struct DockFrameTransitionTests {
    private let fourIcons = CGRect(x: 703, y: 8, width: 322, height: 82)
    private let empty = CGRect(x: 732, y: 8, width: 264, height: 82)

    @Test("An empty-state shrink cannot overwrite a newer four-icon layout")
    func supersededShrink() {
        var transition = DockFrameTransition()
        transition.setTarget(empty, current: fourIcons, at: 0, duration: 0.24)
        let intermediate = transition.frame(at: 0.1)!
        transition.setTarget(fourIcons, current: intermediate, at: 0.1, duration: 0)
        #expect(transition.frame(at: 0.24) == fourIcons)
        #expect(transition.frame(at: 1) == fourIcons)
        #expect(!transition.isAnimating)
    }

    @Test("A new animated target starts at the currently displayed frame")
    func retargetsWithoutJump() {
        var transition = DockFrameTransition()
        transition.setTarget(empty, current: fourIcons, at: 0, duration: 0.24)
        let intermediate = transition.frame(at: 0.12)!
        transition.setTarget(fourIcons, current: intermediate, at: 0.12, duration: 0.24)
        #expect(transition.frame(at: 0.12) == intermediate)
        #expect(transition.frame(at: 0.5) == fourIcons)
    }

    @Test("Repeated snapshots do not restart the same in-flight target")
    func repeatedTarget() {
        var transition = DockFrameTransition()
        transition.setTarget(empty, current: fourIcons, at: 0, duration: 0.24)
        let intermediate = transition.frame(at: 0.12)!
        transition.setTarget(empty, current: intermediate, at: 0.12, duration: 0.24)
        #expect(transition.frame(at: 0.25) == empty)
        #expect(!transition.isAnimating)
    }

    @Test("An idle transition retains its authoritative target even if the native frame drifts")
    func repairsNativeFrameMismatch() {
        var transition = DockFrameTransition()
        transition.setTarget(fourIcons, current: empty, at: 0, duration: 0)
        #expect(transition.target == fourIcons)
        #expect(transition.frame(at: 5) == fourIcons)
    }

    @Test("Hiding or changing Spaces finishes at the latest target and stops animation")
    func finish() {
        var transition = DockFrameTransition()
        transition.setTarget(fourIcons, current: empty, at: 0, duration: 0.24)
        #expect(transition.finish() == fourIcons)
        #expect(!transition.isAnimating)
        #expect(transition.frame(at: 0.1) == fourIcons)
    }

    @Test("Panel interpolation keeps its center and thickness while opening a slot")
    func centeredInterpolation() {
        var transition = DockFrameTransition()
        transition.setTarget(fourIcons, current: empty, at: 0, duration: 0.24)
        let halfway = transition.frame(at: 0.12)!
        #expect(halfway.width == 293)
        #expect(halfway.midX == fourIcons.midX)
        #expect(halfway.minY == 8 && halfway.height == 82)
        #expect(transition.frame(at: 1) == fourIcons)
    }

    @Test("Side dock interpolation keeps width and vertical center")
    func verticalInterpolation() {
        var transition = DockFrameTransition()
        let start = CGRect(x: 8, y: 350, width: 82, height: 100)
        let end = CGRect(x: 8, y: 300, width: 82, height: 200)
        transition.setTarget(end, current: start, at: 0, duration: 0.24)
        let halfway = transition.frame(at: 0.12)!
        #expect(halfway == CGRect(x: 8, y: 325, width: 82, height: 150))
    }

    @Test("Disabling animation settles even when the requested target is unchanged")
    func disableDuringAnimation() {
        var transition = DockFrameTransition()
        transition.setTarget(empty, current: fourIcons, at: 0, duration: 0.24)
        let halfway = transition.frame(at: 0.12)!
        transition.setTarget(empty, current: halfway, at: 0.12, duration: 0)
        #expect(transition.frame(at: 0.12) == empty)
        #expect(!transition.isAnimating)
    }
}
