import CircuiteFoundation
import DesignDatabaseCore

public enum CircuitDatabaseFacet: String, Sendable, Hashable, Codable, CaseIterable {
    case structural = "circuit.structural"

    public var designFacetID: DesignFacetID {
        get throws {
            try DesignFacetID(rawValue: rawValue)
        }
    }
}
