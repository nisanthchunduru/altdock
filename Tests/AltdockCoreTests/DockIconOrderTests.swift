import AltdockCore
import Testing

@Suite("Dragging icons rearranges only their existing order")
struct DockIconOrderTests {
    @Test("Empty and partial snapshots retain ordering preferences without adding absent icons to visible lists")
    func remembersMissingIcons() {
        #expect(DockIconOrder.remembering([], previous: [3, 1, 2]) == [3, 1, 2])
        #expect(DockIconOrder.remembering([1, 2], previous: [3, 1, 2]) == [3, 1, 2])
        #expect(DockIconOrder.remembering([1, 2, 4], previous: [3, 1, 2]) == [3, 1, 2, 4])
    }

    @Test("Reordering visible apps preserves remembered slots for temporarily absent apps")
    func replacesVisibleRanks() {
        #expect(DockIconOrder.replacingVisibleOrder([2, 1], previous: [3, 1, 2]) == [3, 2, 1])
        #expect(DockIconOrder.replacingVisibleOrder([3, 2, 1], previous: [1, 2, 3]) == [3, 2, 1])
        #expect(DockIconOrder.replacingVisibleOrder([3, 2, 1], previous: []) == [3, 2, 1])
    }

    @Test("An icon can move in either direction without duplicating or losing apps")
    func movingIcons() {
        #expect(DockIconOrder.moving(1, to: 2, in: [1, 2, 3]) == [2, 3, 1])
        #expect(DockIconOrder.moving(3, to: 0, in: [1, 2, 3]) == [3, 1, 2])
        #expect(DockIconOrder.moving(2, to: 1, in: [1, 2, 3]) == [1, 2, 3])
    }

    @Test("Out-of-range destinations clamp safely and missing icons do nothing")
    func bounds() {
        #expect(DockIconOrder.moving(2, to: -100, in: [1, 2, 3]) == [2, 1, 3])
        #expect(DockIconOrder.moving(1, to: 100, in: [1, 2, 3]) == [2, 3, 1])
        #expect(DockIconOrder.moving(99, to: 0, in: [1, 2]) == [1, 2])
        #expect(DockIconOrder.moving(1, to: 0, in: []) == [])
    }

    @Test("Dragging crosses a slot at its midpoint, along either dock axis")
    func nearestSlot() {
        #expect(DockIconOrder.destination(processID: 2, order: [1, 2, 3], translation: 37, stride: 76) == 1)
        #expect(DockIconOrder.destination(processID: 2, order: [1, 2, 3], translation: 39, stride: 76) == 2)
        #expect(DockIconOrder.destination(processID: 2, order: [1, 2, 3], translation: -39, stride: 76) == 0)
    }

    @Test("Invalid translations cannot create invalid indexes")
    func invalidInput() {
        #expect(DockIconOrder.destination(processID: 1, order: [], translation: 0, stride: 76) == nil)
        #expect(DockIconOrder.destination(processID: 1, order: [1], translation: .infinity, stride: 76) == nil)
        #expect(DockIconOrder.destination(processID: 1, order: [1], translation: 10, stride: 0) == nil)
        #expect(DockIconOrder.destination(processID: 1, order: [1, 2], translation: 10000, stride: 76) == 1)
    }
}
