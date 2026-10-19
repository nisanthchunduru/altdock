import AltdockCore
import Foundation

struct DockPanelReport: Codable, Equatable {
    struct Panel: Codable, Equatable {
        let spaceID: UInt64?
        let windowNumber: Int
        let applicationProcessIDs: [Int32]
        let frame: String
        let ordered: Bool
    }
    let displayID: UInt32?
    let activeSpaceID: UInt64?
    let fullScreenSpaceIDs: [UInt64]
    let mode: String
    let style: DockStyle
    let panels: [Panel]
}

@MainActor
final class DockPanelDiagnostics {
    static let shared = DockPanelDiagnostics()
    static var fileURL: URL { SystemDockSession.defaultDirectory.appendingPathComponent("panel-status.json") }
    private var previous: DockPanelReport?

    func publish(_ report: DockPanelReport) {
        guard previous != report else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try FileManager.default.createDirectory(at: Self.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(report).write(to: Self.fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Self.fileURL.path)
            previous = report
        } catch {
            NSLog("Altdock could not write panel diagnostics: %@", error.localizedDescription)
        }
    }
}
