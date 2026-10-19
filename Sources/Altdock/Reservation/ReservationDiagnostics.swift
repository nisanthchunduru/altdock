import Foundation

struct ReservationScanReport: Codable, Equatable, Sendable {
    struct Window: Codable, Equatable, Sendable {
        let processID: Int32
        let windowID: UInt32?
        let frame: String?
        let target: String?
        let result: String
    }

    var state: String
    var windows: [Window] = []
}

actor ReservationDiagnostics {
    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Altdock/reservation-status.json")
    }

    private struct Status: Codable {
        let updatedAt: Date
        let processID: Int32
        let executable: String
        let report: ReservationScanReport
    }

    private var previous: ReservationScanReport?

    func publish(_ report: ReservationScanReport) {
        guard previous != report else { return }
        let status = Status(
            updatedAt: Date(), processID: ProcessInfo.processInfo.processIdentifier,
            executable: Bundle.main.executableURL?.path ?? CommandLine.arguments[0], report: report
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try FileManager.default.createDirectory(at: Self.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(status).write(to: Self.fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Self.fileURL.path)
            previous = report
        } catch {
            NSLog("Altdock could not write reservation diagnostics: %@", error.localizedDescription)
        }
    }
}
