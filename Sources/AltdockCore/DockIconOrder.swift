import Foundation

public enum DockIconOrder {
    public static func remembering(_ visibleOrder: [Int32], previous: [Int32]) -> [Int32] {
        let remembered = Set(previous)
        return previous + visibleOrder.filter { !remembered.contains($0) }
    }

    public static func replacingVisibleOrder(_ visibleOrder: [Int32], previous: [Int32]) -> [Int32] {
        let remembered = Set(previous)
        var updated = visibleOrder.filter { remembered.contains($0) }.makeIterator()
        let visible = Set(visibleOrder)
        let retained = previous.map { visible.contains($0) ? updated.next()! : $0 }
        return retained + visibleOrder.filter { !remembered.contains($0) }
    }

    public static func moving(_ processID: Int32, to destination: Int, in order: [Int32]) -> [Int32] {
        guard let source = order.firstIndex(of: processID), !order.isEmpty else { return order }
        var result = order
        result.remove(at: source)
        result.insert(processID, at: max(0, min(destination, result.count)))
        return result
    }

    public static func destination(processID: Int32, order: [Int32], translation: Double, stride: Double) -> Int? {
        guard let source = order.firstIndex(of: processID), translation.isFinite, stride.isFinite, stride > 0 else { return nil }
        let target = Double(source) + (translation / stride).rounded()
        return Int(max(0, min(target, Double(order.count - 1))))
    }
}
