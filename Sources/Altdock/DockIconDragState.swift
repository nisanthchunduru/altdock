import AltdockCore
import AppKit

@MainActor
final class DockIconDragState: ObservableObject {
    @Published private(set) var processID: Int32?
    @Published private(set) var preview: [Int32] = []
    @Published private(set) var translation: CGFloat = 0
    private var original: [Int32] = []
    private var target: Int?
    private var suppressClicksUntil = Date.distantPast

    var suppressesClick: Bool { processID != nil || Date() < suppressClicksUntil }

    func update(processID: Int32, order: [Int32], translation: CGFloat, stride: CGFloat) {
        guard order.contains(processID) else { cancel(); return }
        if self.processID == nil {
            self.processID = processID
            original = order
            preview = order
        }
        guard self.processID == processID, original == order,
              let destination = DockIconOrder.destination(processID: processID, order: original, translation: translation, stride: stride)
        else { cancel(); return }
        self.translation = translation
        target = destination
        let next = DockIconOrder.moving(processID, to: destination, in: original)
        if preview != next { preview = next }
    }

    func displacement(stride: CGFloat) -> CGFloat {
        guard let processID, let start = original.firstIndex(of: processID), let target else { return 0 }
        return translation - CGFloat(target - start) * stride
    }

    func finish(order: [Int32], insidePanel: Bool, commit: (Int32, Int) -> Void) {
        let pendingID = processID
        let destination = target
        let valid = insidePanel && order == original && preview != original
        cancel()
        if valid, let pendingID, let destination { commit(pendingID, destination) }
    }

    func cancel() {
        if processID != nil { suppressClicksUntil = Date().addingTimeInterval(0.25) }
        processID = nil
        preview = []
        original = []
        target = nil
        translation = 0
    }
}
