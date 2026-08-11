import CircuiteFoundation

public protocol CircuitDatabaseParameterPatchApplying: Sendable {
    func apply(
        _ patches: [CircuitDatabaseNumericParameterPatch],
        to state: CircuitDatabaseState,
        sourceArtifact: ArtifactReference
    ) throws(CircuitDatabaseParameterPatchError) -> CircuitDatabaseState
}
