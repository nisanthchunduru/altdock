import AltdockCore
import AppKit
import Testing
@testable import Altdock

@Suite("Dock membership animation is limited to visible app-list changes")
@MainActor
struct DockMembershipAnimationTests {
    private let display = DockDisplay(
        id: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875)
    )

    @Test("Adding and removing apps animates on each native Dock edge", arguments: DockEdge.allCases)
    func membershipChanges(_ edge: DockEdge) {
        #expect(decision(previous: [1, 2], next: [1, 2, 3], edge: edge))
        #expect(decision(previous: [1, 2, 3], next: [1, 3], edge: edge))
    }

    @Test("Focus updates and repeated snapshots do not restart a resize animation")
    func unchangedMembership() { #expect(!decision(previous: [1, 2], next: [1, 2])) }

    @Test("First and last app changes animate the transition to or from the empty placeholder", arguments: DockEdge.allCases)
    func emptySpaces(_ edge: DockEdge) {
        #expect(decision(previous: [], next: [1], edge: edge))
        #expect(decision(previous: [1], next: [], edge: edge))
    }

    @Test("Background or auto-hidden panels update immediately instead of replaying animations on reveal")
    func hiddenPanels() {
        #expect(!decision(isOrdered: false))
        #expect(!decision(isOnActiveSpace: false))
    }

    @Test("Shared compatibility panels never animate one Space's icons into another Space's icons")
    func sharedPanel() { #expect(!decision(isSpaceBound: false)) }

    @Test("Reduce Motion disables membership movement")
    func reducedMotion() { #expect(!decision(reduceMotion: true)) }

    @Test("Initial layout and unresolved Space transitions never animate")
    func firstLayoutAndLoading() {
        #expect(!decision(hasPreviousLayout: false))
        #expect(!decision(isUpdating: true))
        #expect(!decision(wasUpdating: true))
    }

    @Test("Display repositioning and changes to native Dock style do not animate")
    func displayAndStyleChanges() {
        let style = DockStyle()
        let old = display.layout(applicationCount: 2, style: style)
        let resized = display.layout(applicationCount: 3, style: style)
        for next in [
            DockPanelLayout(frame: resized.frame.offsetBy(dx: 1, dy: 0), style: style),
            DockPanelLayout(frame: resized.frame.offsetBy(dx: 0, dy: 1), style: style),
            DockPanelLayout(frame: resized.frame, style: DockStyle(iconSize: 48))
        ] {
            #expect(!DockMembershipAnimation.shouldAnimate(
                previousIDs: [1, 2], nextIDs: [1, 2, 3], previousLayout: old, nextLayout: next,
                isSpaceBound: true, isOrdered: true, isOnActiveSpace: true,
                wasUpdating: false, isUpdating: false, reduceMotion: false
            ))
        }
    }

    @Test("Icons can still animate when a scrolling dock is already at maximum length")
    func overflow() {
        #expect(decision(previous: Array(1...80), next: Array(1...81)))
    }

    @Test("A rapid second app change uses the previous target layout, not an intermediate frame")
    func rapidUpdates() {
        #expect(decision(previous: [1, 2], next: [1, 2, 3]))
        #expect(decision(previous: [1, 2, 3], next: [1, 3, 4]))
        #expect(decision(previous: [1, 3, 4], next: [1]))
    }

    private func decision(
        previous: [Int32] = [1, 2], next: [Int32] = [1, 2, 3], edge: DockEdge = .bottom,
        hasPreviousLayout: Bool = true, isSpaceBound: Bool = true, isOrdered: Bool = true,
        isOnActiveSpace: Bool = true, wasUpdating: Bool = false, isUpdating: Bool = false, reduceMotion: Bool = false
    ) -> Bool {
        let style = DockStyle(edge: edge)
        return DockMembershipAnimation.shouldAnimate(
            previousIDs: previous, nextIDs: next,
            previousLayout: hasPreviousLayout ? display.layout(applicationCount: previous.count, style: style) : nil,
            nextLayout: display.layout(applicationCount: next.count, style: style),
            isSpaceBound: isSpaceBound, isOrdered: isOrdered, isOnActiveSpace: isOnActiveSpace,
            wasUpdating: wasUpdating, isUpdating: isUpdating, reduceMotion: reduceMotion
        )
    }
}
