import Foundation

public struct ActivityEntry: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case sunrise, test, info, failure
    }

    public let id: UUID
    public let date: Date
    public let kind: Kind
    public let message: String

    public init(date: Date, kind: Kind, message: String) {
        id = UUID()
        self.date = date
        self.kind = kind
        self.message = message
    }
}
