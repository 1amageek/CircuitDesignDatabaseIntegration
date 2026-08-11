import CircuiteFoundation
import DesignDatabaseCore

public enum CircuitDesignDatabaseSchema {
    public static let adapterVersion = "1.0.0"
    public static let bindingManifest = """
    lsi.circuit-design-database-schema/v1
    entity=CircuitDatabaseFacetPage
    directory=design-database/circuit-facets/{facetID}/{documentDigest}/pages
    fields=id,facetID,ordinal,pageCount,documentByteCount,documentDigest,payload
    facets=circuit.structural
    canonicalSource=exact-spice-content-identity
    photonic=unsupported-until-independent-p1-integration
    pageByteCount=65536
    """

    public static var schemaID: DesignSchemaID {
        get throws {
            try DesignSchemaID(rawValue: "lsi.circuit-design")
        }
    }
}
