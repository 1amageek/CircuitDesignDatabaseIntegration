public enum CircuitDatabaseSchemaError: Error, Sendable, Hashable {
    case invalidSourceArtifactDescriptor
    case unsupportedPhotonicState
    case unsupportedSchemaVersion(Int)
    case invalidCircuitIdentity
    case emptyCircuit
    case invalidGroundNode(Int)
    case duplicateNodeID(Int)
    case duplicateNodeName(String)
    case invalidNodeID(Int)
    case duplicateBranchID(Int)
    case duplicateBranchName(String)
    case invalidBranchID(Int)
    case duplicateInstanceName(String)
    case invalidInstanceIdentity(String)
    case emptyInstanceNodes(String)
    case unknownNodeReference(instance: String, nodeID: Int)
    case unknownBranchReference(instance: String, branchID: Int)
    case duplicateBranchOwner(branchID: Int)
    case duplicateParameterName(instance: String, parameter: String)
    case invalidParameterName(instance: String)
    case nonFiniteNumericValue
    case integerOverflow
    case emptyExpression
    case unsupportedBehavioralExpressionDepth(limit: Int)
    case invalidBehavioralBranchReference(Int)
    case invalidCircuit([CircuitDatabaseValidationFinding])
    case nonCanonicalOrdering
    case encodingFailed(reason: String)
    case decodingFailed(reason: String)
    case nonCanonicalPayload
    case invalidPageByteCount(Int)
    case pageCountOverflow
}
