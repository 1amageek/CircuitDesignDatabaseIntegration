import CircuiteFoundation
import CircuiteFoundationCrypto
import DesignDatabaseCore

public struct CircuitDatabaseMutationPlanCompiler: Sendable {
    public init() {}

    public func compile(
        _ state: CircuitDatabaseState,
        segmentID: DesignMutationPlanSegmentID,
        databaseID: DesignDatabaseID,
        baseRevision: DesignRevisionReference,
        designSchemaBundleDigest: ContentDigest,
        dependencyRootDigest: ContentDigest,
        semanticDependencyGraphDigest: ContentDigest,
        sourceEvidenceDigest: ContentDigest
    ) throws -> DesignMutationPlan {
        let canonicalData = try CircuitDatabaseCanonicalCodec.encode(state)
        let payload = Array(canonicalData)
        let digester = SHA256ContentDigester()
        let payloadDigest = try DesignMutationPlanDigest.payload(
            payload,
            using: digester
        )
        let writeCount = try CircuitDatabaseCanonicalDocument.pageCount(
            forByteCount: canonicalData.count
        )
        let segment = try DesignMutationPlanSegment(
            id: segmentID,
            schemaID: try CircuitDesignDatabaseSchema.schemaID,
            schemaVersion: .v1,
            adapterVersion: CircuitDesignDatabaseSchema.adapterVersion,
            targetFacet: try CircuitDatabaseFacet.structural.designFacetID,
            payload: payload,
            payloadDigest: payloadDigest,
            expectedWriteCount: writeCount
        )
        let budget = try DesignMutationPlanBudget(
            maximumSegmentCount: 1,
            maximumPayloadByteCount: UInt64(canonicalData.count),
            maximumPreparedWriteCount: writeCount,
            maximumValidationReadCount: 1
        )
        let planDigest = try DesignMutationPlanDigest.plan(
            databaseID: databaseID,
            baseRevision: baseRevision,
            designSchemaBundleDigest: designSchemaBundleDigest,
            dependencyRootDigest: dependencyRootDigest,
            semanticDependencyGraphDigest: semanticDependencyGraphDigest,
            sourceEvidenceDigest: sourceEvidenceDigest,
            budget: budget,
            segments: [segment],
            using: digester
        )
        return DesignMutationPlan(
            databaseID: databaseID,
            baseRevision: baseRevision,
            designSchemaBundleDigest: designSchemaBundleDigest,
            dependencyRootDigest: dependencyRootDigest,
            semanticDependencyGraphDigest: semanticDependencyGraphDigest,
            sourceEvidenceDigest: sourceEvidenceDigest,
            budget: budget,
            segments: [segment],
            planDigest: planDigest
        )
    }
}
