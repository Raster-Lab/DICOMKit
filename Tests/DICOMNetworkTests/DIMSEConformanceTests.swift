import XCTest
import DICOMCore
@testable import DICOMNetwork

/// DIMSE / Query-Retrieve conformance fixes verified against DICOM 2026a
/// (PS3.4, PS3.5, PS3.7, PS3.8). Each test pins the standard's value.
final class DIMSEConformanceTests: XCTestCase {

    // MARK: - C-GET storage contexts are batched (PS3.8 9.3.2.2)

    func test_cget_storageContextBatches_170ClassesSplitInto127And43() {
        let uids = (0..<170).map { "1.2.840.10008.5.1.4.1.1.\($0)" }
        let batches = DICOMRetrieveService.storageContextBatches(uids)
        XCTAssertEqual(DICOMRetrieveService.maxStorageContextsPerAssociation, 127,
                       "odd IDs 1...255 give 128 contexts, ID 1 is the C-GET class")
        XCTAssertEqual(batches.map(\.count), [127, 43])
        XCTAssertEqual(batches.flatMap { $0 }, uids, "order is preserved")
        XCTAssertEqual(Set(batches.flatMap { $0 }).count, 170, "no duplicates")
    }

    func test_cget_storageContextBatches_tenClassesAreOneBatch() {
        let uids = (0..<10).map { "1.2.840.10008.5.1.4.1.1.\($0)" }
        XCTAssertEqual(DICOMRetrieveService.storageContextBatches(uids), [uids])
    }

    func test_cget_storageContextBatches_deduplicatesKeepingFirstPosition() {
        let batches = DICOMRetrieveService.storageContextBatches(["a", "b", "a", "c", "b"])
        XCTAssertEqual(batches, [["a", "b", "c"]])
        XCTAssertEqual(DICOMRetrieveService.storageContextBatches([]), [])
    }

    func test_cget_allStorageClassesFitTwoBatches() {
        // The package-wide registry (PS3.4 Table B.5-1) exceeds one association.
        let batches = DICOMRetrieveService.storageContextBatches(commonStorageSOPClassUIDs)
        XCTAssertGreaterThan(commonStorageSOPClassUIDs.count, 127)
        XCTAssertEqual(batches.count, 2)
        XCTAssertTrue(batches.allSatisfy { $0.count <= 127 })
    }

    func test_cget_mergeGetPassResults_sumsCompletedKeepsLastFailures() {
        let first = RetrieveResult(
            status: .warningCoercionOfDataElements,
            progress: RetrieveProgress(remaining: 0, completed: 10, failed: 3, warning: 1),
            failedSOPInstanceUIDs: ["1.1", "1.2", "1.3"])
        let second = RetrieveResult(
            status: .success,
            progress: RetrieveProgress(remaining: 0, completed: 3, failed: 0, warning: 0),
            failedSOPInstanceUIDs: [])
        let merged = DICOMRetrieveService.mergeGetPassResults(previous: first, next: second)
        XCTAssertEqual(merged.progress.completed, 13)
        XCTAssertEqual(merged.progress.failed, 0, "failures of the first pass were classes not yet proposed")
        XCTAssertEqual(merged.progress.warning, 1)
        XCTAssertEqual(merged.progress.remaining, 0)
        XCTAssertEqual(merged.failedSOPInstanceUIDs, [])
        XCTAssertTrue(merged.status.isSuccess)
        XCTAssertTrue(merged.isSuccess)
        // A first pass is returned unchanged.
        XCTAssertEqual(DICOMRetrieveService.mergeGetPassResults(previous: nil, next: first), first)
    }

    // MARK: - Rows / Columns are VR US (PS3.5 Table 6.2-1)

    func test_instanceResult_rowsAndColumnsDecodeTwoByteUnsignedLittleEndian() {
        let result = InstanceResult(attributes: [
            .rows: Data([0x00, 0x02]),      // 512
            .columns: Data([0x00, 0x01])    // 256
        ])
        XCTAssertEqual(result.rows, 512)
        XCTAssertEqual(result.columns, 256)
    }

    func test_instanceResult_rowsAcceptsASCIIDigitsFromLenientSCPs() {
        // Only strings that cannot be a 2-byte US value are read as digits.
        let result = InstanceResult(attributes: [.rows: Data("512 ".utf8), .columns: Data("640".utf8)])
        XCTAssertEqual(result.rows, 512)
        XCTAssertEqual(result.columns, 640)
        XCTAssertNil(InstanceResult(attributes: [:]).rows)
    }
}
