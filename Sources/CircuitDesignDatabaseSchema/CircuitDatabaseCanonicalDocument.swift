import CircuiteFoundation
import DatabaseTypes
import DatabaseTypesFoundation
import Foundation

public struct CircuitDatabaseCanonicalDocument: Sendable {
    public static let defaultPageByteCount = 64 * 1_024

    public let state: CircuitDatabaseState
    public let canonicalData: Data
    public let facetRootDigest: ContentDigest
    public let pages: [CircuitDatabaseFacetPage]

    public init(
        state: CircuitDatabaseState,
        pageByteCount: Int = Self.defaultPageByteCount
    ) throws(CircuitDatabaseSchemaError) {
        guard pageByteCount > 0 else {
            throw .invalidPageByteCount(pageByteCount)
        }
        let data = try CircuitDatabaseCanonicalCodec.encode(state)
        let digest: ContentDigest
        do {
            digest = try CircuitDatabaseDigesting.sha256(Array(data))
        } catch {
            throw .encodingFailed(reason: String(describing: error))
        }
        let byteCount = data.count
        let pageCount = max(1, (byteCount + pageByteCount - 1) / pageByteCount)
        guard let persistedPageCount = UInt64(exactly: pageCount),
              let persistedByteCount = UInt64(exactly: byteCount) else {
            throw .pageCountOverflow
        }
        let owner = ByteString(retaining: data)
        var pages: [CircuitDatabaseFacetPage] = []
        pages.reserveCapacity(pageCount)
        for index in 0..<pageCount {
            let lower = index * pageByteCount
            let upper = min(byteCount, lower + pageByteCount)
            guard let ordinal = UInt64(exactly: index) else {
                throw .pageCountOverflow
            }
            pages.append(
                CircuitDatabaseFacetPage(
                    id: Self.pageID(ordinal),
                    facetID: CircuitDatabaseFacet.structural.rawValue,
                    ordinal: ordinal,
                    pageCount: persistedPageCount,
                    documentByteCount: persistedByteCount,
                    documentDigest: digest.hexadecimalValue,
                    payload: owner[lower..<upper]
                )
            )
        }
        self.state = state
        canonicalData = data
        facetRootDigest = digest
        self.pages = pages
    }

    public static func pageCount(
        forByteCount byteCount: Int,
        pageByteCount: Int = defaultPageByteCount
    ) throws(CircuitDatabaseSchemaError) -> UInt64 {
        guard pageByteCount > 0 else {
            throw .invalidPageByteCount(pageByteCount)
        }
        let count = max(1, (byteCount + pageByteCount - 1) / pageByteCount)
        guard let result = UInt64(exactly: count) else {
            throw .pageCountOverflow
        }
        return result
    }

    /// Materializes pages from a Runtime-authenticated validation capsule.
    /// This method intentionally does not repeat domain semantic validation.
    public static func materializeValidated(
        canonicalData: Data,
        pageByteCount: Int = defaultPageByteCount
    ) throws(CircuitDatabaseSchemaError) -> (
        facetRootDigest: ContentDigest,
        pages: [CircuitDatabaseFacetPage]
    ) {
        guard pageByteCount > 0 else {
            throw .invalidPageByteCount(pageByteCount)
        }
        let digest: ContentDigest
        do {
            digest = try CircuitDatabaseDigesting.sha256(Array(canonicalData))
        } catch {
            throw .encodingFailed(reason: String(describing: error))
        }
        let pageCount = max(
            1,
            (canonicalData.count + pageByteCount - 1) / pageByteCount
        )
        guard let persistedPageCount = UInt64(exactly: pageCount),
              let persistedByteCount = UInt64(exactly: canonicalData.count) else {
            throw .pageCountOverflow
        }
        let owner = ByteString(retaining: canonicalData)
        var pages: [CircuitDatabaseFacetPage] = []
        pages.reserveCapacity(pageCount)
        for index in 0..<pageCount {
            guard let ordinal = UInt64(exactly: index) else {
                throw .pageCountOverflow
            }
            let lower = index * pageByteCount
            let upper = min(canonicalData.count, lower + pageByteCount)
            pages.append(
                CircuitDatabaseFacetPage(
                    id: pageID(ordinal),
                    facetID: CircuitDatabaseFacet.structural.rawValue,
                    ordinal: ordinal,
                    pageCount: persistedPageCount,
                    documentByteCount: persistedByteCount,
                    documentDigest: digest.hexadecimalValue,
                    payload: owner[lower..<upper]
                )
            )
        }
        return (digest, pages)
    }

    private static func pageID(_ ordinal: UInt64) -> String {
        let value = String(ordinal)
        return String(repeating: "0", count: 20 - value.count) + value
    }
}
