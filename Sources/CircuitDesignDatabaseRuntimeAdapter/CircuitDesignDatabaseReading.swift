import CircuitDesignDatabaseSchema
import DesignDatabaseCore

public protocol CircuitDesignDatabaseReading: Sendable {
    func readCircuit(
        from snapshot: any DesignReadSnapshot,
        budget: CircuitDatabaseReadBudget
    ) async throws -> CircuitDatabaseState?
}
