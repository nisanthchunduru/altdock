import CoreGraphics
import Foundation

public struct ReservationWindowID: Hashable, Sendable {
    public let processID: Int32
    public let windowID: UInt32

    public init(processID: Int32, windowID: UInt32) {
        self.processID = processID
        self.windowID = windowID
    }
}

public struct ReservationLedger: Sendable {
    public struct Adjustment: Sendable {
        public let original: CGRect
        public let applied: CGRect
        public var attempts: Int
        public var lastWrite: TimeInterval
    }

    public private(set) var adjustments: [ReservationWindowID: Adjustment] = [:]
    private var suppressed: Set<ReservationWindowID> = []
    private var failedWrites: [ReservationWindowID: (count: Int, retryAt: TimeInterval)] = [:]
    private var observedFrames: [ReservationWindowID: CGRect] = [:]
    private var inputGenerations: [ReservationWindowID: UInt64] = [:]

    public init() {}

    public mutating func target(
        for id: ReservationWindowID, frame: CGRect, geometry: ReservationGeometry,
        now: TimeInterval, interaction: UInt64? = nil
    ) -> CGRect? {
        let previousFrame = observedFrames.updateValue(frame, forKey: id)
        if let interaction {
            if let previousFrame, let previousInput = inputGenerations[id], previousInput != interaction,
               !ReservationGeometry.matches(previousFrame, frame), geometry.target(for: frame) != nil {
                adjustments.removeValue(forKey: id)
                suppressed.remove(id)
                failedWrites.removeValue(forKey: id)
                inputGenerations[id] = interaction
            }
            if inputGenerations[id] == nil { inputGenerations[id] = interaction }
        }
        if let failure = failedWrites[id], now < failure.retryAt { return nil }
        if let adjustment = adjustments[id] {
            if ReservationGeometry.matches(frame, adjustment.applied) { return nil }
            if !ReservationGeometry.matches(frame, adjustment.original) {
                adjustments.removeValue(forKey: id)
                suppressed.insert(id)
                return nil
            }
            guard adjustment.attempts < 2, now - adjustment.lastWrite >= 0.5 else { return nil }
        }
        guard let target = geometry.target(for: frame) else {
            adjustments.removeValue(forKey: id)
            suppressed.remove(id)
            failedWrites.removeValue(forKey: id)
            return nil
        }
        guard !suppressed.contains(id) else { return nil }
        return target
    }

    public mutating func didApply(_ target: CGRect, to id: ReservationWindowID, original: CGRect, now: TimeInterval) {
        let previous = adjustments[id]
        observedFrames[id] = target
        failedWrites.removeValue(forKey: id)
        adjustments[id] = Adjustment(
            original: previous?.original ?? original, applied: target,
            attempts: (previous?.attempts ?? 0) + 1, lastWrite: now
        )
    }

    public mutating func didFail(_ id: ReservationWindowID, now: TimeInterval) {
        let count = (failedWrites[id]?.count ?? 0) + 1
        failedWrites[id] = (count, now + 1)
        if count >= 3 { suppressed.insert(id) }
    }

    public func blockReason(for id: ReservationWindowID, now: TimeInterval) -> String? {
        if suppressed.contains(id) { return "Yielding after an external change or repeated write failures; waiting for a new layout" }
        if let failure = failedWrites[id], now < failure.retryAt { return "Retrying a transient resize failure after cooldown" }
        if let adjustment = adjustments[id], adjustment.attempts >= 2 { return "Yielding to a competing layout; waiting for a new user resize" }
        return nil
    }

    public mutating func suppress(_ id: ReservationWindowID) {
        suppressed.insert(id)
    }

    public func restoration(for id: ReservationWindowID, current: CGRect) -> CGRect? {
        guard let adjustment = adjustments[id], ReservationGeometry.matches(current, adjustment.applied) else { return nil }
        return adjustment.original
    }

    public mutating func retain(liveIDs: Set<ReservationWindowID>) {
        adjustments = adjustments.filter { liveIDs.contains($0.key) }
        suppressed.formIntersection(liveIDs)
        failedWrites = failedWrites.filter { liveIDs.contains($0.key) }
        observedFrames = observedFrames.filter { liveIDs.contains($0.key) }
        inputGenerations = inputGenerations.filter { liveIDs.contains($0.key) }
    }
}
