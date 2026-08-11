enum CircuitDatabasePreparedMutationError: Error, Sendable, Hashable {
    case contentAddressCollision(
        facetID: String,
        documentDigest: String,
        ordinal: UInt64
    )
}
