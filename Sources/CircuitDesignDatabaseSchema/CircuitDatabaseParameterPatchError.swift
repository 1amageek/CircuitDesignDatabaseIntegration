public enum CircuitDatabaseParameterPatchError: Error, Sendable, Hashable {
    case emptyPatchSet
    case emptyInstanceName(index: Int)
    case emptyParameterName(index: Int)
    case nonFiniteValue(instance: String, parameter: String)
    case duplicateTarget(instance: String, parameter: String)
    case sourceArtifactUnchanged
    case noEffectiveChange
    case instanceNotFound(String)
    case parameterNotFound(instance: String, parameter: String)
    case nonNumericParameter(instance: String, parameter: String)
    case integerValueNotExact(instance: String, parameter: String, value: Double)
    case stateInvalid(CircuitDatabaseSchemaError)
}
