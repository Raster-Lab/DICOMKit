import XCTest
import ArgumentParser
import DICOMWeb
@testable import dicom_wado

/// Pins the `dicom-wado` option values to the DICOM 2026a text:
/// PS3.18 Section 9 (WADO-URI), 8.3.4 (QIDO-RS query parameters), 11.7.1.4 (UPS Change
/// State) and PS3.3 Tables C.30.1-1 / C.30.2-1 / C.7-1.
final class WADOOptionRulesTests: XCTestCase {

    // MARK: - WADO-URI contentType (PS3.18 9.1.2.2.1, Table 8.7.4-1)

    func testURIContentTypesAreApplicationDicomOrRenderedMediaTypes() throws {
        // application/dicom plus the Table 8.7.4-1 Rendered Media Types WADOURIClient carries.
        XCTAssertEqual(WADOOptionRules.uriContentTypes,
                       ["application/dicom", "image/jpeg", "image/gif", "image/png", "image/jp2", "image/jph", "video/mpeg"])
        for value in WADOOptionRules.uriContentTypes {
            XCTAssertEqual(try WADOOptionRules.uriContentType(value).rawValue, value)
        }
    }

    func testAbsentContentTypeIsApplicationDicom() throws {
        XCTAssertEqual(try WADOOptionRules.uriContentType(nil), .dicom)
        XCTAssertEqual(try WADOOptionRules.uriContentType(""), .dicom)
        XCTAssertEqual(try WADOOptionRules.uriContentType("jpeg"), .jpeg)  // short alias kept
    }

    func testUnrequestableContentTypeIsRejectedNotFetchedAsDicom() {
        // image/jxl is a Rendered Media Type in 2026a but WADOURIClient cannot request it;
        // before, it silently downloaded application/dicom.
        XCTAssertThrowsError(try WADOOptionRules.uriContentType("image/jxl"))
        XCTAssertThrowsError(try WADOOptionRules.uriContentType("text/html"))
        XCTAssertThrowsError(try RetrieveCommand.parse(["http://h/wado", "--uri", "--study", "1",
                                                        "--content-type", "image/bmp"]))
    }

    // MARK: - WADO-URI frameNumber / rows / columns (9.5.1.2.1, 9.5.1.2.4)

    func testFrameNumberIsASinglePositiveInteger() throws {
        XCTAssertNil(try WADOOptionRules.uriFrameNumber(nil))
        XCTAssertEqual(try WADOOptionRules.uriFrameNumber("3")?.frame, 3)
        XCTAssertEqual(try WADOOptionRules.uriFrameNumber("3")?.notSent, 0)
        let list = try WADOOptionRules.uriFrameNumber("2, 4,6")
        XCTAssertEqual(list?.frame, 2)
        XCTAssertEqual(list?.notSent, 2)
        XCTAssertThrowsError(try WADOOptionRules.uriFrameNumber("0"))   // starts at 1, not 0
        XCTAssertThrowsError(try WADOOptionRules.uriFrameNumber("-1"))
        XCTAssertThrowsError(try WADOOptionRules.uriFrameNumber("abc"))
        XCTAssertThrowsError(try RetrieveCommand.parse(["http://h/wado", "--uri", "--study", "1", "--frames", "0"]))
    }

    func testRowsAndColumnsArePositiveAndNeedURI() throws {
        XCTAssertNoThrow(try RetrieveCommand.parse(["http://h/wado", "--uri", "--study", "1",
                                                    "--content-type", "image/jpeg", "--rows", "256", "--columns", "256"]))
        XCTAssertThrowsError(try RetrieveCommand.parse(["http://h/wado", "--uri", "--study", "1", "--rows", "0"]))
        XCTAssertThrowsError(try RetrieveCommand.parse(["http://h/wado", "--uri", "--study", "1", "--columns", "0"]))
        // WADO-URI query parameters (PS3.18 Section 9) without --uri
        XCTAssertThrowsError(try RetrieveCommand.parse(["http://h/rs", "--study", "1", "--anonymize"]))
        XCTAssertThrowsError(try RetrieveCommand.parse(["http://h/rs", "--study", "1", "--transfer-syntax", "1.2.840.10008.1.2.1"]))
    }

    func testParametersOutsideTheirTransactionWarn() {
        // Table 9.4.1-1 (application/dicom): anonymize, annotation, transferSyntax.
        // Table 9.5.1-1 (rendered): frameNumber, rows, columns, ...
        XCTAssertEqual(WADOOptionRules.uriParameterWarnings(contentType: .dicom, frame: 2, rows: nil, columns: nil,
                                                            transferSyntax: "1.2.840.10008.1.2.1", anonymize: true).count, 1)
        XCTAssertTrue(WADOOptionRules.uriParameterWarnings(contentType: .dicom, frame: nil, rows: nil, columns: nil,
                                                           transferSyntax: "1.2.840.10008.1.2.1", anonymize: true).isEmpty)
        XCTAssertTrue(WADOOptionRules.uriParameterWarnings(contentType: .jpeg, frame: 2, rows: 64, columns: 64,
                                                           transferSyntax: nil, anonymize: false).isEmpty)
        let w = WADOOptionRules.uriParameterWarnings(contentType: .jpeg, frame: nil, rows: nil, columns: nil,
                                                     transferSyntax: nil, anonymize: true)
        XCTAssertEqual(w.count, 1)
        XCTAssertTrue(w[0].contains("Table 9.4.1-1"))
    }

    // MARK: - QIDO-RS (PS3.18 8.3.4)

    func testLimitAndOffsetAreUnsigned() {
        XCTAssertNoThrow(try QueryCommand.parse(["http://h/rs", "--limit", "0", "--offset", "0"]))
        XCTAssertThrowsError(try QueryCommand.parse(["http://h/rs", "--limit=-1"]))
        XCTAssertThrowsError(try QueryCommand.parse(["http://h/rs", "--offset=-5"]))
    }

    func testFuzzyMatchingSendsTheStandardParameter() throws {
        let on = try QueryCommand.parse(["http://h/rs", "--fuzzy-matching", "--patient-name", "DOE*"]).buildQuery()
        XCTAssertEqual(on.toParameters()["fuzzymatching"], "true")
        let off = try QueryCommand.parse(["http://h/rs"]).buildQuery()
        XCTAssertNil(off.toParameters()["fuzzymatching"])
        XCTAssertEqual(off.toParameters()["limit"], "100")
        XCTAssertEqual(off.toParameters()["offset"], "0")
    }

    func testModalityKeyFollowsTheQueryLevel() throws {
        // Table 10.6.1-5: Modalities In Study (0008,0061) at study level, Modality (0008,0060) at series level.
        let study = try QueryCommand.parse(["http://h/rs", "--modality", "CT"]).buildQuery().toParameters()
        XCTAssertEqual(study["00080061"], "CT")
        XCTAssertNil(study["00080060"])
        let series = try QueryCommand.parse(["http://h/rs", "--level", "series", "--modality", "CT"]).buildQuery().toParameters()
        XCTAssertEqual(series["00080060"], "CT")
    }

    // MARK: - UPS-RS (PS3.3 Table C.30.1-1, PS3.18 11.7.1.4)

    func testProcedureStepStateAcceptsTheStandardSpelling() {
        XCTAssertEqual(WADOOptionRules.upsState("IN PROGRESS"), .inProgress)
        XCTAssertEqual(WADOOptionRules.upsState("in progress"), .inProgress)
        XCTAssertEqual(WADOOptionRules.upsState("IN_PROGRESS"), .inProgress)
        XCTAssertEqual(WADOOptionRules.upsState("INPROGRESS"), .inProgress)
        XCTAssertEqual(WADOOptionRules.upsState("SCHEDULED"), .scheduled)
        XCTAssertEqual(WADOOptionRules.upsState("COMPLETED"), .completed)
        XCTAssertEqual(WADOOptionRules.upsState("CANCELED"), .canceled)
        XCTAssertNil(WADOOptionRules.upsState("CANCELLED"))
        XCTAssertEqual(UPSState.inProgress.rawValue, "IN PROGRESS")  // the value sent
        XCTAssertNoThrow(try UPSCommand.parse(["http://h/rs", "--update", "1.2.3", "--state", "IN PROGRESS"]))
        XCTAssertThrowsError(try UPSCommand.parse(["http://h/rs", "--update", "1.2.3", "--state", "DONE"]))
    }

    func testChangeStateTargetsAreTheThreeOf11_7_1_4() {
        XCTAssertEqual(WADOOptionRules.changeStateTargets.map(\.rawValue), ["IN PROGRESS", "COMPLETED", "CANCELED"])
        XCTAssertFalse(WADOOptionRules.changeStateTargets.contains(.scheduled))
    }

    func testFilterStateInProgressReachesTheSharedSearchBuilder() throws {
        XCTAssertEqual(WADOOptionRules.searchFilterState("IN PROGRESS"), "IN_PROGRESS")
        XCTAssertEqual(WADOOptionRules.searchFilterState("SCHEDULED"), "SCHEDULED")
        XCTAssertNil(WADOOptionRules.searchFilterState(nil))
        XCTAssertNoThrow(try UPSQuery.workitemSearch(filterState: WADOOptionRules.searchFilterState("IN PROGRESS"),
                                                     scheduledStation: nil))
    }

    func testUPSHelpNamesTheStandardTerms() {
        let help = UPSCommand.helpMessage().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        XCTAssertTrue(help.contains("HIGH, MEDIUM, LOW (PS3.3 Table C.30.2-1"))
        XCTAssertTrue(help.contains("IN PROGRESS, COMPLETED, CANCELED (PS3.18 11.7.1.4)"))
        XCTAssertTrue(help.contains("M, F, O (PS3.3 Table C.7-1)"))
        XCTAssertTrue(help.contains("table, json, csv"))
    }

    // MARK: - Store exit status, --timeout

    func testStoreFailsWhenAnyInstanceWasNotStored() {
        XCTAssertNil(StoreCommand.exitCode(failed: 0))
        XCTAssertEqual(StoreCommand.exitCode(failed: 1), .failure)
    }

    func testTimeoutDrivesTheRequestTimeout() {
        let t = WADOOptionRules.timeouts(seconds: 600)
        XCTAssertEqual(t.readTimeout, 600)
        XCTAssertGreaterThanOrEqual(t.resourceTimeout, 600)
        XCTAssertEqual(WADOOptionRules.timeouts(seconds: 60).readTimeout, 60)
    }
}
