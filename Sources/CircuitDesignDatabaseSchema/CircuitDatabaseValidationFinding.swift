public struct CircuitDatabaseValidationFinding: Sendable, Hashable, Codable {
    public enum Severity: String, Sendable, Hashable, Codable {
        case warning
        case error
    }

    public let severity: Severity
    public let code: String
    public let summary: String
    public let entity: String?

    public init(
        severity: Severity,
        code: String,
        summary: String,
        entity: String? = nil
    ) {
        self.severity = severity
        self.code = code
        self.summary = summary
        self.entity = entity
    }
}
