import CircuiteFoundation
import CircuiteFoundationCrypto
import CircuitDesignDatabaseSchema
import Database
import DesignDatabaseCore
import DesignDatabaseRuntime
import Foundation

public struct CircuitDesignDatabaseRuntimeAdapter:
    DesignDatabaseRuntimeMutationAdapter,
    Sendable
{
    public let schemaID: DesignSchemaID
    public let schemaVersion = SchemaVersion.v1
    public let adapterVersion = CircuitDesignDatabaseSchema.adapterVersion
    public let supportedFacets: Set<DesignFacetID>

    public init() throws {
        schemaID = try CircuitDesignDatabaseSchema.schemaID
        supportedFacets = [try CircuitDatabaseFacet.structural.designFacetID]
    }

    public func contribution() throws -> DesignDatabaseRuntimeContribution {
        let bindingDigest = try CircuitDatabaseDigesting.sha256(
            Array(CircuitDesignDatabaseSchema.bindingManifest.utf8)
        )
        return try DesignDatabaseRuntimeContribution(
            id: DesignDatabaseRuntimeContributionID("lsi.circuit-design-database"),
            designSchemaMember: DesignSchemaBundleMember(
                schemaID: schemaID,
                version: schemaVersion,
                canonicalDigest: bindingDigest
            ),
            bindingDigest: bindingDigest,
            entities: [try CircuitDatabaseFacetPage.schemaEntity],
            entityRuntimes: [
                try DatabaseFrameworkRuntime.entity(CircuitDatabaseFacetPage.self),
            ],
            mutationAdapter: self,
            physicalWriteReclaimers: [self]
        )
    }

    public func validate(
        _ segment: DesignMutationPlanSegment,
        in context: DesignDatabaseRuntimeMutationValidation
    ) async throws(DesignDatabaseRuntimeMutationAdapterError)
        -> DesignDatabaseRuntimeValidatedMutation {
        _ = context
        let structuralFacetID: DesignFacetID
        do {
            structuralFacetID = try CircuitDatabaseFacet.structural.designFacetID
        } catch {
            throw .invalidPayload(reason: String(describing: error))
        }
        guard segment.schemaID == schemaID,
              segment.schemaVersion == schemaVersion,
              segment.adapterVersion == adapterVersion,
              segment.targetFacet == structuralFacetID else {
            throw .invalidPayload(
                reason: "The circuit segment binding is not registered."
            )
        }
        let state: CircuitDatabaseState
        do {
            state = try CircuitDatabaseCanonicalCodec.decode(
                Data(segment.payload)
            )
        } catch let error {
            throw .validationFailed(
                diagnostics: [Self.diagnostic(error)],
                diagnosticsDigest: segment.payloadDigest
            )
        }
        let document: CircuitDatabaseCanonicalDocument
        do {
            document = try CircuitDatabaseCanonicalDocument(state: state)
        } catch let error {
            throw .validationFailed(
                diagnostics: [Self.diagnostic(error)],
                diagnosticsDigest: segment.payloadDigest
            )
        }
        guard document.pages.count == segment.expectedWriteCount else {
            throw .invalidPayload(
                reason: "The declared write count does not match the canonical page count."
            )
        }
        let observedPayloadDigest: ContentDigest
        do {
            observedPayloadDigest = try DesignMutationPlanDigest.payload(
                segment.payload,
                using: SHA256ContentDigester()
            )
        } catch {
            throw .invalidPayload(reason: String(describing: error))
        }
        guard observedPayloadDigest == segment.payloadDigest,
              document.facetRootDigest == segment.payloadDigest else {
            throw .invalidPayload(
                reason: "The canonical circuit payload digest does not match the segment."
            )
        }
        return DesignDatabaseRuntimeValidatedMutation(
            segmentID: segment.id,
            materializationPayload: segment.payload
        )
    }

    public func materializeValidatedMutation(
        _ validation: DesignDatabaseRuntimeValidatedMutationRecord,
        for segment: DesignMutationPlanSegment,
        in context: DesignDatabaseRuntimeMutationRestoration
    ) throws(DesignDatabaseRuntimeMutationAdapterError)
        -> any DesignDatabaseRuntimePreparedMutation {
        _ = context
        do {
            guard validation.materializationPayloadDigest
                    == validation.segmentPayloadDigest else {
                throw DesignDatabaseRuntimeMutationAdapterError.invalidPayload(
                    reason: "The validated circuit capsule is not the canonical segment payload."
                )
            }
            let materialization = try CircuitDatabaseCanonicalDocument
                .materializeValidated(
                    canonicalData: Data(validation.materializationPayload)
                )
            guard UInt64(materialization.pages.count) == segment.expectedWriteCount,
                  materialization.facetRootDigest == segment.payloadDigest else {
                throw DesignDatabaseRuntimeMutationAdapterError.invalidPayload(
                    reason: "The materialized circuit pages do not match the validated segment."
                )
            }
            return CircuitDatabasePreparedMutation(
                segmentID: validation.segmentID,
                pages: materialization.pages,
                facetRootDigest: materialization.facetRootDigest,
                changeContributionDigest: materialization.facetRootDigest
            )
        } catch let error as DesignDatabaseRuntimeMutationAdapterError {
            throw error
        } catch {
            throw .invalidPayload(
                reason: "The validated circuit input could not be materialized: \(error)"
            )
        }
    }

    private static func diagnostic(
        _ error: CircuitDatabaseSchemaError
    ) -> DesignDiagnostic {
        let code: String
        switch error {
        case .invalidSourceArtifactDescriptor:
            code = "CIRCUIT_SOURCE_ARTIFACT_INVALID"
        case .unsupportedPhotonicState:
            code = "CIRCUIT_PHOTONIC_STATE_UNSUPPORTED"
        case .unsupportedSchemaVersion:
            code = "CIRCUIT_SCHEMA_VERSION_UNSUPPORTED"
        case .invalidCircuitIdentity:
            code = "CIRCUIT_IDENTITY_INVALID"
        case .emptyCircuit:
            code = "CIRCUIT_EMPTY"
        case .invalidGroundNode:
            code = "CIRCUIT_GROUND_INVALID"
        case .duplicateNodeID, .duplicateNodeName, .invalidNodeID:
            code = "CIRCUIT_NODE_INVALID"
        case .duplicateBranchID, .duplicateBranchName, .invalidBranchID,
             .duplicateBranchOwner:
            code = "CIRCUIT_BRANCH_INVALID"
        case .duplicateInstanceName, .invalidInstanceIdentity,
             .emptyInstanceNodes:
            code = "CIRCUIT_INSTANCE_INVALID"
        case .unknownNodeReference:
            code = "CIRCUIT_NODE_REFERENCE_INVALID"
        case .unknownBranchReference:
            code = "CIRCUIT_BRANCH_REFERENCE_INVALID"
        case .duplicateParameterName, .invalidParameterName,
             .nonFiniteNumericValue, .integerOverflow, .emptyExpression,
             .invalidBehavioralBranchReference:
            code = "CIRCUIT_PARAMETER_INVALID"
        case .unsupportedBehavioralExpressionDepth:
            code = "CIRCUIT_EXPRESSION_DEPTH_UNSUPPORTED"
        case .invalidCircuit(let findings):
            code = findings.first?.code ?? "CIRCUIT_DOMAIN_VALIDATION_FAILED"
        case .nonCanonicalOrdering, .nonCanonicalPayload:
            code = "CIRCUIT_PAYLOAD_NONCANONICAL"
        case .encodingFailed, .decodingFailed:
            code = "CIRCUIT_PAYLOAD_INVALID"
        case .invalidPageByteCount, .pageCountOverflow:
            code = "CIRCUIT_PAGE_BUDGET_INVALID"
        }
        return DesignDiagnostic(
            code: .trusted(code),
            severity: .error,
            summary: String(describing: error),
            suggestedActions: [
                SuggestedAction(
                    code: "update_circuit_candidate",
                    summary: "Update the structural circuit candidate and retry."
                ),
            ]
        )
    }
}
