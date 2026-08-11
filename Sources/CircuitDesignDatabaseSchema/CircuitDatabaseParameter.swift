public struct CircuitDatabaseParameter: Sendable, Hashable, Codable {
    public let name: String
    public let value: CircuitDatabaseParameterValue

    public init(name: String, value: CircuitDatabaseParameterValue) {
        self.name = name
        self.value = value
    }
}
