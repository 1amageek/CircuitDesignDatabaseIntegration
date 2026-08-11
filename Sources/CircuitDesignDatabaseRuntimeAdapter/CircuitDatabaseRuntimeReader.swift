import CircuiteFoundation
import CircuiteFoundationCrypto
import CircuitDesignDatabaseSchema
import Database
import DatabaseTypesFoundation
import DesignDatabaseRuntime
import Foundation

public struct CircuitDatabaseRuntimeReader: Sendable {
    public init() {}

    public func read(
        expectedRoot: ContentDigest,
        from reads: DesignDatabaseRuntimeReadSnapshot,
        budget: CircuitDatabaseReadBudget
    ) async throws -> CircuitDatabaseState {
        var partition = DirectoryPath<CircuitDatabaseFacetPage>()
        partition.set(
            CircuitDatabaseFacetPage.fields.facetID,
            to: CircuitDatabaseFacet.structural.rawValue
        )
        partition.set(
            CircuitDatabaseFacetPage.fields.documentDigest,
            to: expectedRoot.hexadecimalValue
        )
        var pages: [CircuitDatabaseFacetPage] = []
        pages.reserveCapacity(min(budget.maximumPageCount, budget.pageFetchLimit))
        var continuation: DatabaseScanContinuation?
        repeat {
            let page = try await reads.scan(
                CircuitDatabaseFacetPage.self,
                in: partition,
                after: continuation,
                limit: budget.pageFetchLimit
            )
            pages.append(contentsOf: page.items)
            guard pages.count <= budget.maximumPageCount else {
                throw CircuitDatabaseReadError.pageBudgetExceeded(
                    limit: budget.maximumPageCount
                )
            }
            continuation = page.continuation
        } while continuation != nil
        return try decode(pages: pages, expectedRoot: expectedRoot)
    }

    private func decode(
        pages: [CircuitDatabaseFacetPage],
        expectedRoot: ContentDigest
    ) throws -> CircuitDatabaseState {
        guard let first = pages.first else {
            throw CircuitDatabaseReadError.missingFacetPages
        }
        let ordered = pages.sorted { $0.ordinal < $1.ordinal }
        guard first.pageCount == UInt64(ordered.count),
              ordered.allSatisfy({ page in
                  page.facetID == CircuitDatabaseFacet.structural.rawValue
                      && page.pageCount == first.pageCount
                      && page.documentByteCount == first.documentByteCount
                      && page.documentDigest == first.documentDigest
              }) else {
            throw CircuitDatabaseReadError.inconsistentPageMetadata
        }
        for (index, page) in ordered.enumerated() {
            guard page.ordinal == UInt64(index) else {
                throw CircuitDatabaseReadError.nonContiguousPages
            }
        }
        guard let capacity = Int(exactly: first.documentByteCount) else {
            throw CircuitDatabaseReadError.inconsistentPageMetadata
        }
        var data = Data()
        data.reserveCapacity(capacity)
        for page in ordered {
            page.payload.withUnsafeBytes { bytes in
                data.append(bytes.bindMemory(to: UInt8.self))
            }
        }
        guard let actualByteCount = UInt64(exactly: data.count),
              actualByteCount == first.documentByteCount else {
            throw CircuitDatabaseReadError.byteCountMismatch(
                expected: first.documentByteCount,
                actual: UInt64(data.count)
            )
        }
        let actualRoot = try SHA256ContentDigester().digest(data: data)
        guard actualRoot == expectedRoot else {
            throw CircuitDatabaseReadError.facetRootMismatch(
                expected: expectedRoot,
                actual: actualRoot
            )
        }
        do {
            return try CircuitDatabaseCanonicalCodec.decode(data)
        } catch let error {
            throw CircuitDatabaseReadError.decodeFailed(error)
        }
    }
}
