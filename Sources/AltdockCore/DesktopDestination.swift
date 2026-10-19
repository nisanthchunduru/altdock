import Foundation

public struct DesktopDestination: Identifiable, Equatable, Sendable {
    public let id: UInt64
    public let number: Int
    public var name: String { "Desktop \(number)" }

    public init(id: UInt64, number: Int) {
        self.id = id
        self.number = number
    }
}
