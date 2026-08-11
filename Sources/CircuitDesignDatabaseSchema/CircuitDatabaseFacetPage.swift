import DatabaseKit
import DatabaseTypes

@Persistable
public struct CircuitDatabaseFacetPage {
    #Directory<CircuitDatabaseFacetPage>(
        "design-database",
        "circuit-facets",
        \CircuitDatabaseFacetPage.facetID,
        \CircuitDatabaseFacetPage.documentDigest,
        "pages",
        layer: .partition
    )

    public var id: String = ""
    public var facetID: String = ""
    public var ordinal: UInt64 = 0
    public var pageCount: UInt64 = 0
    public var documentByteCount: UInt64 = 0
    public var documentDigest: String = ""
    public var payload: ByteString = ByteString()
}
