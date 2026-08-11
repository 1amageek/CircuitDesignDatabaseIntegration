import CircuiteFoundation
import CircuiteFoundationCrypto
import CircuitDesignDatabaseRuntimeAdapter
import CircuitDesignDatabaseSchema
import Database
import DesignDatabaseCore
import DesignDatabaseRuntime
import Foundation
import Testing

@Suite("Circuit DesignDatabase runtime")
struct CircuitDatabaseRuntimeTests {
    @Test("candidate circuit commits and reads from its exact revision")
    func candidateRoundTrip() async throws {
        let registration = try DesignDatabaseRuntimeRegistrationBuilder().build(
            schemaVersion: Schema.Version(1, 0, 0),
            contributions: [
                try CircuitDesignDatabaseRuntimeAdapter().contribution(),
            ]
        )
        let locator = try DesignDatabaseLocator(
            namespace: "tests",
            segments: ["circuit-integration"]
        )
        let databaseID = try DesignDatabaseID(high: 21, low: 22)
        let genesisRevisionID = DesignRevisionID(high: 0, low: 1)
        let subjectScopeID = try DesignAuthorizationSubjectScopeID(
            high: 23,
            low: 24
        )
        let createOperationID = try DesignDatabaseOperationID(
            rawValue: "create-circuit"
        )
        let capabilities = try DesignCapabilitySet([])
        let canonicalCreate = try DesignDatabaseRuntimeGenesisRequest(
            locator: locator,
            databaseID: databaseID,
            genesisRevisionID: genesisRevisionID,
            authorizationSubjectScopeID: subjectScopeID,
            operationID: createOperationID,
            declaredFeatureCapabilities: capabilities,
            initialSchemaBundle: registration.designSchemaBundle,
            registrationDigest: registration.registrationDigest
        )
        let provider = DesignDatabaseRuntimeProvider(
            registration: registration,
            containerProvider: CircuitDatabaseTestContainerProvider(),
            authorizationSubjectScopeID: subjectScopeID,
            creationRequestedAuthorization: DesignDatabaseAuthorizationGrantSet([
                .read,
                .proposeCandidate,
                .inspectOwnOperationOutcome,
            ]),
            authorizer: CircuitDatabaseTestAuthorizer()
        )
        let handle = try await provider.create(
            DesignDatabaseCreateRequest(
                locator: locator,
                databaseID: databaseID,
                genesisRevisionID: genesisRevisionID,
                operationID: createOperationID,
                initialSchemaBundle: registration.designSchemaBundle,
                declaredFeatureCapabilities: capabilities,
                requestDigest: canonicalCreate.requestDigest
            )
        )
        let genesis = handle.genesisRevision
        let snapshot = try await handle.openSnapshot(at: genesis)
        let state = try makeCircuitState()
        let plan: DesignMutationPlan
        do {
            plan = try CircuitDatabaseMutationPlanCompiler().compile(
                state,
                segmentID: DesignMutationPlanSegmentID(
                    rawValue: "structural-circuit"
                ),
                databaseID: databaseID,
                baseRevision: genesis,
                designSchemaBundleDigest: snapshot.designSchemaBundleDigest,
                dependencyRootDigest: snapshot.dependencyRootDigest,
                semanticDependencyGraphDigest: snapshot.semanticDependencyGraphDigest,
                sourceEvidenceDigest: try digest("circuit-source-evidence")
            )
            _ = await snapshot.close()
        } catch {
            _ = await snapshot.close()
            throw error
        }
        let operationID = try DesignDatabaseOperationID(
            rawValue: "import-structural-circuit"
        )
        let submission = DesignCommitSubmission(
            operationID: operationID,
            plan: plan,
            requestDigest: try DesignMutationPlanDigest.request(
                operationID: operationID,
                planDigest: plan.planDigest,
                using: SHA256ContentDigester()
            )
        )
        let receipt: DesignCommitReceipt
        switch try await handle.submit(submission) {
        case .committed(let committed):
            receipt = committed
        case .rejected(let rejection):
            throw CircuitDatabaseRuntimeTestFailure(
                "Candidate rejected: \(rejection)"
            )
        case .outcomeUnknown:
            throw CircuitDatabaseRuntimeTestFailure(
                "The in-memory candidate outcome was unknown."
            )
        }
        let candidate = try await handle.openSnapshot(
            at: receipt.candidateRevision
        )
        let stored = try await CircuitDesignDatabaseSnapshotReader().readCircuit(
            from: candidate,
            budget: CircuitDatabaseReadBudget()
        )

        #expect(stored == state)
        #expect(
            try await handle.commitStatus(
                operation: receipt.operation,
                requestDigest: submission.requestDigest
            ) == .committed(receipt)
        )
        #expect(try await handle.resolve(.named(.main)) == genesis)
        #expect(await candidate.close() == .closed)
        #expect(await handle.close() == .closed)
        #expect(await provider.close() == .closed)
    }

    private func digest(_ value: String) throws -> ContentDigest {
        try CircuitDatabaseDigesting.sha256(Array(value.utf8))
    }
}

private struct CircuitDatabaseRuntimeTestFailure: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}
