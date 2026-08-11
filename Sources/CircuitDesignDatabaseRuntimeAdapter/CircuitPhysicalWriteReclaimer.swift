import CircuitDesignDatabaseSchema
import Database
import DesignDatabaseRuntime

extension CircuitDesignDatabaseRuntimeAdapter:
    DesignDatabaseRuntimePhysicalWriteReclaimer
{
    static let physicalStorageType =
        "CircuitDesignDatabaseSchema.CircuitDatabaseFacetPage.v1"

    public var storageType: String { Self.physicalStorageType }

    public func deleteImmutableWrite(
        _ identity: DesignDatabaseRuntimeImmutableWriteIdentity,
        from transaction: any DatabaseTransactionWriting
    ) async throws(DesignDatabaseRuntimePhysicalWriteReclaimerError) {
        let components = try DesignDatabaseRuntimePhysicalWriteDeletion
            .requirePartitionComponents(
                identity,
                storageType: storageType,
                count: 2
            )
        var partition = DirectoryPath<CircuitDatabaseFacetPage>()
        partition.set(CircuitDatabaseFacetPage.fields.facetID, to: components[0])
        partition.set(
            CircuitDatabaseFacetPage.fields.documentDigest,
            to: components[1]
        )
        try await DesignDatabaseRuntimePhysicalWriteDeletion.delete(
            identity,
            model: CircuitDatabaseFacetPage.self,
            identifiedBy: identity.modelID,
            in: partition,
            expectedIdentity: Self.physicalWriteIdentity,
            from: transaction
        )
    }

    static func physicalWriteIdentity(
        _ page: CircuitDatabaseFacetPage
    ) throws(DesignDatabaseRuntimePreparedMutationError)
        -> DesignDatabaseRuntimeImmutableWriteIdentity {
        try DesignDatabaseRuntimeImmutableWriteIdentity(
            storageType: physicalStorageType,
            partitionComponents: [page.facetID, page.documentDigest],
            modelID: page.id
        )
    }
}
