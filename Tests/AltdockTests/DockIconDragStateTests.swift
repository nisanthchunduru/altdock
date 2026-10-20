import AppKit
import Testing
@testable import Altdock

@Suite("Icon drag previews commit only on a valid drop")
@MainActor
struct DockIconDragStateTests {
    @Test("Dragging previews the order and commits once on mouse release inside the dock")
    func successfulDrag() {
        let drag = DockIconDragState()
        drag.update(processID: 1, order: [1, 2, 3], translation: 160, stride: 76)
        #expect(drag.preview == [2, 3, 1])
        #expect(drag.displacement(stride: 76) == 8)
        var calls = 0
        drag.finish(order: [1, 2, 3], insidePanel: true) { id, index in
            #expect(id == 1 && index == 2)
            calls += 1
        }
        #expect(calls == 1)
        #expect(drag.processID == nil)
        #expect(drag.suppressesClick)
    }

    @Test("Dropping outside the dock restores the original order without committing")
    func outsideDrop() {
        let drag = DockIconDragState()
        drag.update(processID: 1, order: [1, 2], translation: 100, stride: 76)
        drag.finish(order: [1, 2], insidePanel: false) { _, _ in Issue.record("Outside drop must not commit") }
        #expect(drag.preview.isEmpty)
        #expect(drag.processID == nil)
    }

    @Test("Cancellation and membership changes cannot commit a stale order")
    func canceledDrag() {
        let drag = DockIconDragState()
        drag.update(processID: 1, order: [1, 2], translation: 100, stride: 76)
        drag.cancel()
        drag.finish(order: [1, 2], insidePanel: true) { _, _ in Issue.record("Canceled drag must not commit") }
        drag.update(processID: 1, order: [1, 2], translation: 100, stride: 76)
        drag.finish(order: [1, 3], insidePanel: true) { _, _ in Issue.record("Changed app list must not commit") }
    }

    @Test("A short drag that stays in the same slot does not change the order")
    func sameSlot() {
        let drag = DockIconDragState()
        drag.update(processID: 1, order: [1, 2], translation: 10, stride: 76)
        drag.finish(order: [1, 2], insidePanel: true) { _, _ in Issue.record("No reorder needed") }
        #expect(drag.suppressesClick)
    }
}
