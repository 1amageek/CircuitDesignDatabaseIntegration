import CircuitDesignDatabaseSchema
import DesignDatabaseCore
import DesignDatabaseRuntime

public struct CircuitDesignDatabaseSnapshotReader:
    CircuitDesignDatabaseReading,
    Sendable
{
    public init() {}

    public func readCircuit(
        from snapshot: any DesignReadSnapshot,
        budget: CircuitDatabaseReadBudget
    ) async throws -> CircuitDatabaseState? {
        let facetID = try CircuitDatabaseFacet.structural.designFacetID
        guard let expectedRoot = snapshot.facetRoots.first(where: {
            $0.facetID == facetID
        })?.digest else {
            return nil
        }
        guard let runtimeSnapshot = snapshot as? DesignDatabaseRuntimeSnapshot else {
            throw CircuitDatabaseReadError.unsupportedSnapshotImplementation
        }
        return try await runtimeSnapshot.withRuntimeReads(
            maximumReadCount: try budget.runtimeReadCount
        ) { reads in
            try await CircuitDatabaseRuntimeReader().read(
                expectedRoot: expectedRoot,
                from: reads,
                budget: budget
            )
        }
    }
}
