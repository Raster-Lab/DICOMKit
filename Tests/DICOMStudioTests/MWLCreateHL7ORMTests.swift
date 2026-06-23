// MWLCreateHL7ORMTests.swift
// Locks the dicom-mwl HL7 "create" path's ORM^O01 field placement to dcm4chee-arc's
// DEFAULT inbound order stylesheet (hl7-order2dcm.xsl). The original bug: the Scheduled
// Station AE Title was written into OBR-20, which that stylesheet reads as the Scheduled
// Procedure Step ID (0040,0009) in its ZDS/OBR path — so a user's Station AET surfaced on
// the server as the SPS ID. These tests assert each UI value lands at its correct HL7
// position (OBR fallback + IPC segment) so the mismap cannot silently return.

import XCTest
@testable import DICOMNetwork

#if canImport(Network)
@available(macOS 14.0, *)
final class MWLCreateHL7ORMTests: XCTestCase {

    // Distinct sentinels so a wrong field is obvious (no value can be confused for another).
    private let accession   = "ACC-001"
    private let reqProcID   = "RP-002"
    private let spsID       = "SPS-003"
    private let stationAET  = "STATION_AET_004"
    private let stationName = "StationName005"
    private let modality    = "CT"
    private let spsDesc     = "Head CT"
    private let dateTime    = "20240315103000"

    private func buildMessage() -> String {
        DICOMModalityWorklistService.buildHL7ORM(
            messageControlID: "MSG1",
            timestamp: "20240315103000",
            sendingApplication: "DICOMSTUDIO",
            sendingFacility: "IMAGING",
            receivingApplication: "DCM4CHEE",
            receivingFacility: "HOSPITAL",
            patientName: "DOE^JOHN",
            patientID: "PID-100",
            patientBirthDate: "19800101",
            patientSex: "M",
            accessionNumber: accession,
            referringPhysicianName: "SMITH^JANE",
            requestedProcedureID: reqProcID,
            requestedProcedureDescription: "CT of the head",
            studyInstanceUID: "1.2.3.4.5",
            modality: modality,
            scheduledStationAETitle: stationAET,
            scheduledStationName: stationName,
            scheduledDateTime: dateTime,
            scheduledProcedureStepID: spsID,
            scheduledProcedureStepDescription: spsDesc,
            scheduledPerformingPhysicianName: "BROWN^BOB"
        )
    }

    /// Returns the `|`-split fields of the first segment named `name`; index N == HL7 field N.
    private func segmentFields(_ name: String, in message: String) -> [String]? {
        for line in message.split(separator: "\r") {
            let parts = line.components(separatedBy: "|")
            if parts.first == name { return parts }
        }
        return nil
    }

    // MARK: OBR fallback path (dcm4chee ZDS/OBR builder)

    /// The regression guard: dcm4chee's ZDS/OBR path reads SPS ID (0040,0009) from OBR-20.
    /// OBR-20 must be the SPS ID — never the Station AE Title (the original defect).
    func testOBR20IsScheduledProcedureStepID() throws {
        let obr = try XCTUnwrap(segmentFields("OBR", in: buildMessage()))
        XCTAssertGreaterThan(obr.count, 20, "OBR must extend to at least field 20")
        XCTAssertEqual(obr[20], spsID, "OBR-20 (Filler Field 1) must carry the Scheduled Procedure Step ID")
        XCTAssertNotEqual(obr[20], stationAET, "OBR-20 must NOT carry the Station AE Title (the original bug)")
    }

    /// The Station AE Title must not appear ANYWHERE in the OBR segment — there is no OBR
    /// slot for it in the default mapping, so its presence would mean a field shift.
    func testStationAETAbsentFromOBR() throws {
        let obr = try XCTUnwrap(segmentFields("OBR", in: buildMessage()))
        XCTAssertFalse(obr.contains(stationAET), "Station AE Title must not occupy any OBR field")
    }

    func testOBRPlacerFieldsAccessionAndRequestedProcedureID() throws {
        let obr = try XCTUnwrap(segmentFields("OBR", in: buildMessage()))
        XCTAssertEqual(obr[18], accession, "OBR-18 (Placer Field 1) → Accession Number (0008,0050)")
        XCTAssertEqual(obr[19], reqProcID, "OBR-19 (Placer Field 2) → Requested Procedure ID (0040,1001)")
    }

    func testOBRModalityAndStartDateTime() throws {
        let obr = try XCTUnwrap(segmentFields("OBR", in: buildMessage()))
        XCTAssertEqual(obr[24], modality, "OBR-24 → Modality (0008,0060)")
        // SPS Start Date/Time is read from OBR-27's 4th component (field[27]/component[3]).
        XCTAssertEqual(obr[27], "^^^\(dateTime)", "OBR-27 must place the date/time in the 4th component")
    }

    // MARK: IPC path (dcm4chee spsSeq builder — config-independent, carries every SPS field)

    func testIPCSegmentCarriesEverySPSField() throws {
        let ipc = try XCTUnwrap(segmentFields("IPC", in: buildMessage()), "an IPC segment must be emitted")
        XCTAssertGreaterThan(ipc.count, 9, "IPC must extend to at least field 9")
        XCTAssertEqual(ipc[1], accession,   "IPC-1 → Accession Number (0008,0050)")
        XCTAssertEqual(ipc[2], reqProcID,   "IPC-2 → Requested Procedure ID (0040,1001)")
        XCTAssertEqual(ipc[3], "1.2.3.4.5", "IPC-3 → Study Instance UID (0020,000D)")
        XCTAssertEqual(ipc[4], spsID,       "IPC-4 → Scheduled Procedure Step ID (0040,0009)")
        XCTAssertEqual(ipc[5], modality,    "IPC-5 → Modality (0008,0060)")
        XCTAssertEqual(ipc[6], "^\(spsDesc)", "IPC-6 → SPS Description (0040,0007) in the text component")
        XCTAssertEqual(ipc[7], stationName, "IPC-7 → Scheduled Station Name (0040,0010)")
        XCTAssertEqual(ipc[9], stationAET,  "IPC-9 → Scheduled Station AE Title (0040,0001)")
    }

    // MARK: message shape

    func testMessageHasExpectedSegments() {
        let msg = buildMessage()
        for seg in ["MSH", "PID", "PV1", "ORC", "OBR", "IPC", "ZDS"] {
            XCTAssertNotNil(segmentFields(seg, in: msg), "message must contain a \(seg) segment")
        }
    }

    /// An empty SPS description must not emit a stray IPC-6 (would create a blank protocol code).
    func testEmptySPSDescriptionOmitsIPC6() throws {
        let msg = DICOMModalityWorklistService.buildHL7ORM(
            messageControlID: "MSG1", timestamp: "20240315103000",
            sendingApplication: "A", sendingFacility: "B",
            receivingApplication: "C", receivingFacility: "D",
            patientName: "DOE^JOHN", patientID: "PID-100",
            patientBirthDate: nil, patientSex: nil,
            accessionNumber: accession, referringPhysicianName: nil,
            requestedProcedureID: reqProcID, requestedProcedureDescription: "",
            studyInstanceUID: "1.2.3.4.5", modality: modality,
            scheduledStationAETitle: stationAET, scheduledStationName: stationName,
            scheduledDateTime: dateTime, scheduledProcedureStepID: spsID,
            scheduledProcedureStepDescription: "", scheduledPerformingPhysicianName: nil
        )
        let ipc = try XCTUnwrap(segmentFields("IPC", in: msg))
        XCTAssertEqual(ipc[6], "", "IPC-6 must be empty when no SPS description was supplied")
        XCTAssertEqual(ipc[9], stationAET, "IPC-9 must still carry the Station AE Title")
    }
}
#endif
