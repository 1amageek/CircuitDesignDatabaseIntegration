public struct CircuitDatabaseNumericParameterPatch:
    Sendable,
    Hashable,
    Codable
{
    public let instanceName: String
    public let parameterName: String
    public let value: Double

    public init(
        instanceName: String,
        parameterName: String,
        value: Double
    ) {
        self.instanceName = instanceName
        self.parameterName = parameterName
        self.value = value
    }
}
