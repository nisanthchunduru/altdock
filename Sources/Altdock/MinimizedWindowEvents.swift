import AppKit
import ApplicationServices

@MainActor
protocol MinimizedWindowObserving: AnyObject {
    func start(changed: @escaping () -> Void)
    func update(processIDs: Set<Int32>)
    func stop()
}

@MainActor
final class MinimizedWindowEvents: MinimizedWindowObserving {
    private struct Observation {
        let token: UUID
        let observer: any MinimizedApplicationObserving
    }

    private struct Retry {
        let at: TimeInterval
        let delay: TimeInterval
    }

    private let makeObserver: () -> any MinimizedApplicationObserving
    private let trusted: () -> Bool
    private let now: () -> TimeInterval
    private var observations: [Int32: Observation] = [:]
    private var retries: [Int32: Retry] = [:]
    private var changed: (() -> Void)?

    init(
        makeObserver: @escaping () -> any MinimizedApplicationObserving = { MinimizedApplicationObserver() },
        trusted: @escaping () -> Bool = { AXIsProcessTrusted() },
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.makeObserver = makeObserver
        self.trusted = trusted
        self.now = now
    }

    func start(changed: @escaping () -> Void) {
        stop()
        self.changed = changed
    }

    func update(processIDs: Set<Int32>) {
        guard changed != nil else { return }
        let available = trusted() ? processIDs : []
        for (pid, observation) in observations where !available.contains(pid) {
            observation.observer.stop()
            observations.removeValue(forKey: pid)
        }
        retries = retries.filter { available.contains($0.key) }
        let time = now()
        for pid in available.sorted() where observations[pid] == nil && time >= (retries[pid]?.at ?? -.infinity) {
            let token = UUID()
            let observer = makeObserver()
            if observer.start(processID: pid, changed: { [weak self] in
                guard let self, self.observations[pid]?.token == token else { return }
                self.changed?()
            }) {
                observations[pid] = Observation(token: token, observer: observer)
                retries.removeValue(forKey: pid)
            } else {
                observer.stop()
                let delay = min(5, (retries[pid]?.delay ?? 0.125) * 2)
                retries[pid] = Retry(at: time + delay, delay: delay)
            }
        }
    }

    func stop() {
        observations.values.forEach { $0.observer.stop() }
        observations.removeAll()
        retries.removeAll()
        changed = nil
    }
}
