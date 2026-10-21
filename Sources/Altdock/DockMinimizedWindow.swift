import AltdockCore
import AppKit

struct DockWindowID: Hashable {
    let processID: Int32
    let windowID: UInt32
}

struct DockMinimizedWindow: Identifiable, Equatable {
    let application: NSRunningApplication
    let window: SpaceWindow
    var id: DockWindowID { DockWindowID(processID: window.processID, windowID: window.id) }
    var name: String {
        let title = window.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "\(application.localizedName ?? "Application") — Window \(window.id)" : title
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.window == rhs.window }

    static func ordered(windows: [SpaceWindow], applications: [Int32: NSRunningApplication], previous: [Self]) -> [Self] {
        let minimized = windows.filter(\.isMinimized).compactMap { window in
            applications[window.processID].map { Self(application: $0, window: window) }
        }
        let byID = Dictionary(minimized.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let retained = previous.compactMap { byID[$0.id] }
        let retainedIDs = Set(retained.map(\.id))
        return retained + byID.values.filter { !retainedIDs.contains($0.id) }.sorted { $0.window.id < $1.window.id }
    }
}
