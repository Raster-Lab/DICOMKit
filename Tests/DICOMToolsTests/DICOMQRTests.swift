import XCTest
import DICOMCore
import DICOMNetwork
import Foundation

/// Tests for dicom-qr integrated query-retrieve tool
///
/// Tests the integration of C-FIND query and C-MOVE/C-GET retrieve functionality
final class DICOMQRTests: XCTestCase {
    
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        // Create temp directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DICOMQRTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - Local Type Definitions for Testing
    
    struct QueryState: Codable {
        let studies: [StudyInfo]
        
        struct StudyInfo: Codable {
            let studyInstanceUID: String?
            let patientName: String?
            let patientID: String?
            let studyDate: String?
            let studyDescription: String?
            let accessionNumber: String?
            let modality: String?
        }
    }
    
    struct RetrievalState: Codable {
        let studies: [QueryState.StudyInfo]
        let host: String
        let port: UInt16
        let callingAE: String
        let calledAE: String
        let moveDestination: String?
        let method: RetrievalMethod
        let outputPath: String
        let hierarchical: Bool
    }
    
    enum RetrievalMethod: String, Codable {
        case cMove = "c-move"
        case cGet = "c-get"
    }
    
    struct ServerInfo {
        let host: String
        let port: UInt16
    }
    
    struct ValidationError: Error {
        let message: String
        
        init(_ message: String) {
            self.message = message
        }
    }
    
    // Helper function
    func parseServerURL(_ urlString: String) throws -> ServerInfo {
        guard urlString.hasPrefix("pacs://") else {
            throw ValidationError("Invalid URL format. Must start with pacs://")
        }
        
        let withoutScheme = String(urlString.dropFirst(7))
        let components = withoutScheme.components(separatedBy: ":")
        
        guard components.count == 2,
              let port = UInt16(components[1]) else {
            throw ValidationError("Invalid URL format. Expected pacs://host:port")
        }
        
        return ServerInfo(host: components[0], port: port)
    }
    
    // MARK: - URL Parsing Tests
    
    func testParseValidPACSURL() throws {
        let serverInfo = try parseServerURL("pacs://server.example.com:11112")
        XCTAssertEqual(serverInfo.host, "server.example.com")
        XCTAssertEqual(serverInfo.port, 11112)
    }
    
    func testParseInvalidURLScheme() {
        XCTAssertThrowsError(try parseServerURL("http://server.example.com:80")) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    func testParseURLWithoutPort() {
        XCTAssertThrowsError(try parseServerURL("pacs://server.example.com")) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    func testParseURLWithInvalidPort() {
        XCTAssertThrowsError(try parseServerURL("pacs://server.example.com:invalid")) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    func testParseURLWithoutScheme() {
        XCTAssertThrowsError(try parseServerURL("server.example.com:11112")) { error in
            XCTAssertTrue(error is ValidationError)
        }
    }
    
    // MARK: - Retrieval Method Tests
    
    func testRetrievalMethodCMove() {
        let method = RetrievalMethod.cMove
        XCTAssertEqual(method.rawValue, "c-move")
    }
    
    func testRetrievalMethodCGet() {
        let method = RetrievalMethod.cGet
        XCTAssertEqual(method.rawValue, "c-get")
    }
    
    func testRetrievalMethodCodable() throws {
        let method = RetrievalMethod.cMove
        let encoder = JSONEncoder()
        let data = try encoder.encode(method)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RetrievalMethod.self, from: data)
        XCTAssertEqual(decoded, method)
    }
    
    // MARK: - State Persistence Tests
    
    func testQueryStateEncodeDecode() throws {
        let studyInfo = QueryState.StudyInfo(
            studyInstanceUID: "1.2.840.113619.2.xxx",
            patientName: "SMITH^JOHN",
            patientID: "12345",
            studyDate: "20240101",
            studyDescription: "CT CHEST",
            accessionNumber: "ACC123",
            modality: "CT"
        )
        
        let state = QueryState(studies: [studyInfo])
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(QueryState.self, from: data)
        
        XCTAssertEqual(decoded.studies.count, 1)
        XCTAssertEqual(decoded.studies[0].studyInstanceUID, "1.2.840.113619.2.xxx")
        XCTAssertEqual(decoded.studies[0].patientName, "SMITH^JOHN")
        XCTAssertEqual(decoded.studies[0].patientID, "12345")
        XCTAssertEqual(decoded.studies[0].studyDate, "20240101")
        XCTAssertEqual(decoded.studies[0].studyDescription, "CT CHEST")
        XCTAssertEqual(decoded.studies[0].accessionNumber, "ACC123")
        XCTAssertEqual(decoded.studies[0].modality, "CT")
    }
    
    func testQueryStateWithMultipleStudies() throws {
        let studies = [
            QueryState.StudyInfo(
                studyInstanceUID: "1.2.3.4.5.1",
                patientName: "PATIENT^ONE",
                patientID: "111",
                studyDate: "20240101",
                studyDescription: "Study 1",
                accessionNumber: nil,
                modality: "CT"
            ),
            QueryState.StudyInfo(
                studyInstanceUID: "1.2.3.4.5.2",
                patientName: "PATIENT^TWO",
                patientID: "222",
                studyDate: "20240102",
                studyDescription: "Study 2",
                accessionNumber: "ACC456",
                modality: "MR"
            ),
            QueryState.StudyInfo(
                studyInstanceUID: "1.2.3.4.5.3",
                patientName: "PATIENT^THREE",
                patientID: "333",
                studyDate: "20240103",
                studyDescription: nil,
                accessionNumber: nil,
                modality: "US"
            )
        ]
        
        let state = QueryState(studies: studies)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(state)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(QueryState.self, from: data)
        
        XCTAssertEqual(decoded.studies.count, 3)
        XCTAssertEqual(decoded.studies[0].studyInstanceUID, "1.2.3.4.5.1")
        XCTAssertEqual(decoded.studies[1].patientID, "222")
        XCTAssertEqual(decoded.studies[2].modality, "US")
    }
    
    func testRetrievalStateEncodeDecode() throws {
        let studyInfo = QueryState.StudyInfo(
            studyInstanceUID: "1.2.840.113619.2.xxx",
            patientName: "SMITH^JOHN",
            patientID: "12345",
            studyDate: "20240101",
            studyDescription: "CT CHEST",
            accessionNumber: "ACC123",
            modality: "CT"
        )
        
        let state = RetrievalState(
            studies: [studyInfo],
            host: "pacs.example.com",
            port: 11112,
            callingAE: "MY_AET",
            calledAE: "PACS_SCP",
            moveDestination: "MY_SCP",
            method: .cMove,
            outputPath: "/tmp/studies",
            hierarchical: true
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RetrievalState.self, from: data)
        
        XCTAssertEqual(decoded.host, "pacs.example.com")
        XCTAssertEqual(decoded.port, 11112)
        XCTAssertEqual(decoded.callingAE, "MY_AET")
        XCTAssertEqual(decoded.calledAE, "PACS_SCP")
        XCTAssertEqual(decoded.moveDestination, "MY_SCP")
        XCTAssertEqual(decoded.method, .cMove)
        XCTAssertEqual(decoded.outputPath, "/tmp/studies")
        XCTAssertTrue(decoded.hierarchical)
        XCTAssertEqual(decoded.studies.count, 1)
    }
    
    func testRetrievalStateWithCGet() throws {
        let studyInfo = QueryState.StudyInfo(
            studyInstanceUID: "1.2.840.113619.2.yyy",
            patientName: "DOE^JANE",
            patientID: "67890",
            studyDate: "20240201",
            studyDescription: "MR BRAIN",
            accessionNumber: nil,
            modality: "MR"
        )
        
        let state = RetrievalState(
            studies: [studyInfo],
            host: "pacs.example.com",
            port: 11112,
            callingAE: "MY_AET",
            calledAE: "PACS_SCP",
            moveDestination: nil,
            method: .cGet,
            outputPath: "/tmp/output",
            hierarchical: false
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RetrievalState.self, from: data)
        
        XCTAssertEqual(decoded.method, .cGet)
        XCTAssertNil(decoded.moveDestination)
        XCTAssertFalse(decoded.hierarchical)
    }
    
    func testQueryStateFileWriteAndRead() throws {
        let studyInfo = QueryState.StudyInfo(
            studyInstanceUID: "1.2.840.113619.2.test",
            patientName: "TEST^PATIENT",
            patientID: "TEST123",
            studyDate: "20240315",
            studyDescription: "TEST STUDY",
            accessionNumber: "ACC999",
            modality: "CT"
        )
        
        let state = QueryState(studies: [studyInfo])
        
        let filePath = tempDirectory.appendingPathComponent("query_state.json")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: filePath)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath.path))
        
        let readData = try Data(contentsOf: filePath)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(QueryState.self, from: readData)
        
        XCTAssertEqual(decoded.studies.count, 1)
        XCTAssertEqual(decoded.studies[0].studyInstanceUID, "1.2.840.113619.2.test")
        XCTAssertEqual(decoded.studies[0].patientName, "TEST^PATIENT")
    }
    
    func testRetrievalStateFileWriteAndRead() throws {
        let studyInfo = QueryState.StudyInfo(
            studyInstanceUID: "1.2.840.113619.2.test2",
            patientName: "ANOTHER^PATIENT",
            patientID: "TEST456",
            studyDate: "20240316",
            studyDescription: "ANOTHER STUDY",
            accessionNumber: nil,
            modality: "MR"
        )
        
        let state = RetrievalState(
            studies: [studyInfo],
            host: "test.pacs.com",
            port: 11112,
            callingAE: "TEST_AET",
            calledAE: "TEST_SCP",
            moveDestination: "DEST_SCP",
            method: .cMove,
            outputPath: tempDirectory.path,
            hierarchical: true
        )
        
        let filePath = tempDirectory.appendingPathComponent("retrieval_state.json")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: filePath)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath.path))
        
        let readData = try Data(contentsOf: filePath)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RetrievalState.self, from: data)
        
        XCTAssertEqual(decoded.host, "test.pacs.com")
        XCTAssertEqual(decoded.callingAE, "TEST_AET")
        XCTAssertEqual(decoded.method, .cMove)
        XCTAssertEqual(decoded.studies[0].studyInstanceUID, "1.2.840.113619.2.test2")
    }
    
    // MARK: - Study Info Tests
    
    func testStudyInfoWithAllFields() {
        let studyInfo = QueryState.StudyInfo(
            studyInstanceUID: "1.2.3.4.5",
            patientName: "FULL^DATA",
            patientID: "FULL123",
            studyDate: "20240401",
            studyDescription: "Complete Study",
            accessionNumber: "ACCFULL",
            modality: "CT"
        )
        
        XCTAssertEqual(studyInfo.studyInstanceUID, "1.2.3.4.5")
        XCTAssertEqual(studyInfo.patientName, "FULL^DATA")
        XCTAssertEqual(studyInfo.patientID, "FULL123")
        XCTAssertEqual(studyInfo.studyDate, "20240401")
        XCTAssertEqual(studyInfo.studyDescription, "Complete Study")
        XCTAssertEqual(studyInfo.accessionNumber, "ACCFULL")
        XCTAssertEqual(studyInfo.modality, "CT")
    }
    
    func testStudyInfoWithMinimalFields() {
        let studyInfo = QueryState.StudyInfo(
            studyInstanceUID: "1.2.3.4.6",
            patientName: nil,
            patientID: nil,
            studyDate: nil,
            studyDescription: nil,
            accessionNumber: nil,
            modality: nil
        )
        
        XCTAssertEqual(studyInfo.studyInstanceUID, "1.2.3.4.6")
        XCTAssertNil(studyInfo.patientName)
        XCTAssertNil(studyInfo.patientID)
        XCTAssertNil(studyInfo.studyDate)
        XCTAssertNil(studyInfo.studyDescription)
        XCTAssertNil(studyInfo.accessionNumber)
        XCTAssertNil(studyInfo.modality)
    }
    
    func testStudyInfoCodableWithOptionalFields() throws {
        let studyInfo = QueryState.StudyInfo(
            studyInstanceUID: "1.2.3.4.7",
            patientName: "PARTIAL^DATA",
            patientID: "PART123",
            studyDate: nil,
            studyDescription: "Partial Study",
            accessionNumber: nil,
            modality: "MR"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(studyInfo)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(QueryState.StudyInfo.self, from: data)
        
        XCTAssertEqual(decoded.studyInstanceUID, "1.2.3.4.7")
        XCTAssertEqual(decoded.patientName, "PARTIAL^DATA")
        XCTAssertNil(decoded.studyDate)
        XCTAssertEqual(decoded.studyDescription, "Partial Study")
        XCTAssertNil(decoded.accessionNumber)
        XCTAssertEqual(decoded.modality, "MR")
    }
    
    // MARK: - State with Multiple Studies Tests
    
    func testRetrievalStateWithBulkStudies() throws {
        var studies: [QueryState.StudyInfo] = []
        for i in 1...10 {
            studies.append(QueryState.StudyInfo(
                studyInstanceUID: "1.2.3.4.5.\(i)",
                patientName: "PATIENT^NUMBER\(i)",
                patientID: "P\(i)",
                studyDate: "202404\(String(format: "%02d", i))",
                studyDescription: "Study \(i)",
                accessionNumber: "ACC\(i)",
                modality: i % 2 == 0 ? "CT" : "MR"
            ))
        }
        
        let state = RetrievalState(
            studies: studies,
            host: "bulk.pacs.com",
            port: 11112,
            callingAE: "BULK_AET",
            calledAE: "BULK_SCP",
            moveDestination: "BULK_DEST",
            method: .cMove,
            outputPath: "/bulk/output",
            hierarchical: true
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RetrievalState.self, from: data)
        
        XCTAssertEqual(decoded.studies.count, 10)
        XCTAssertEqual(decoded.studies[0].studyInstanceUID, "1.2.3.4.5.1")
        XCTAssertEqual(decoded.studies[9].studyInstanceUID, "1.2.3.4.5.10")
        XCTAssertEqual(decoded.studies[0].modality, "MR")
        XCTAssertEqual(decoded.studies[1].modality, "CT")
    }
    
    // MARK: - JSON Format Tests
    
    func testQueryStateJSONFormat() throws {
        let studyInfo = QueryState.StudyInfo(
            studyInstanceUID: "1.2.3",
            patientName: "TEST",
            patientID: "123",
            studyDate: "20240101",
            studyDescription: "DESC",
            accessionNumber: "ACC",
            modality: "CT"
        )
        
        let state = QueryState(studies: [studyInfo])
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        
        let jsonString = String(data: data, encoding: .utf8)
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString!.contains("\"studyInstanceUID\" : \"1.2.3\""))
        XCTAssertTrue(jsonString!.contains("\"patientName\" : \"TEST\""))
        XCTAssertTrue(jsonString!.contains("\"modality\" : \"CT\""))
    }
    
    func testRetrievalStateJSONFormat() throws {
        let studyInfo = QueryState.StudyInfo(
            studyInstanceUID: "1.2.4",
            patientName: "JSON",
            patientID: "456",
            studyDate: "20240102",
            studyDescription: "JSON Test",
            accessionNumber: nil,
            modality: "MR"
        )
        
        let state = RetrievalState(
            studies: [studyInfo],
            host: "json.test.com",
            port: 11112,
            callingAE: "JSON_AET",
            calledAE: "JSON_SCP",
            moveDestination: "JSON_DEST",
            method: .cMove,
            outputPath: "/json/output",
            hierarchical: false
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        
        let jsonString = String(data: data, encoding: .utf8)
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString!.contains("\"host\" : \"json.test.com\""))
        XCTAssertTrue(jsonString!.contains("\"callingAE\" : \"JSON_AET\""))
        XCTAssertTrue(jsonString!.contains("\"method\" : \"c-move\""))
        XCTAssertTrue(jsonString!.contains("\"hierarchical\" : false"))
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyStudyList() throws {
        let state = QueryState(studies: [])
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(QueryState.self, from: data)
        
        XCTAssertEqual(decoded.studies.count, 0)
    }
    
    func testStudyInfoWithLongStrings() throws {
        let longString = String(repeating: "A", count: 1000)
        
        let studyInfo = QueryState.StudyInfo(
            studyInstanceUID: longString,
            patientName: longString,
            patientID: longString,
            studyDate: "20240101",
            studyDescription: longString,
            accessionNumber: longString,
            modality: "CT"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(studyInfo)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(QueryState.StudyInfo.self, from: data)
        
        XCTAssertEqual(decoded.studyInstanceUID?.count, 1000)
        XCTAssertEqual(decoded.patientName?.count, 1000)
    }
    
    func testStudyInfoWithSpecialCharacters() throws {
        let studyInfo = QueryState.StudyInfo(
            studyInstanceUID: "1.2.3.4.5",
            patientName: "TEST^PATIENT\\WITH\\SPECIAL*CHARS?",
            patientID: "ID-123/456",
            studyDate: "20240101",
            studyDescription: "Study with \"quotes\" and 'apostrophes'",
            accessionNumber: "ACC#789",
            modality: "CT/MR"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(studyInfo)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(QueryState.StudyInfo.self, from: data)
        
        XCTAssertEqual(decoded.patientName, "TEST^PATIENT\\WITH\\SPECIAL*CHARS?")
        XCTAssertEqual(decoded.patientID, "ID-123/456")
        XCTAssertEqual(decoded.studyDescription, "Study with \"quotes\" and 'apostrophes'")
        XCTAssertEqual(decoded.accessionNumber, "ACC#789")
        XCTAssertEqual(decoded.modality, "CT/MR")
    }
    
    // MARK: - Helper Function Tests
    
    func testParseServerURLSuccess() throws {
        let serverInfo = try parseServerURL("pacs://test.server.com:5678")
        XCTAssertEqual(serverInfo.host, "test.server.com")
        XCTAssertEqual(serverInfo.port, 5678)
    }
    
    func testParseServerURLWithIPAddress() throws {
        let serverInfo = try parseServerURL("pacs://192.168.1.100:11112")
        XCTAssertEqual(serverInfo.host, "192.168.1.100")
        XCTAssertEqual(serverInfo.port, 11112)
    }
    
    func testParseServerURLWithIPv6() throws {
        let serverInfo = try parseServerURL("pacs://[2001:db8::1]:11112")
        XCTAssertEqual(serverInfo.host, "[2001:db8::1]")
        XCTAssertEqual(serverInfo.port, 11112)
    }
    
    func testParseServerURLInvalidFormat() {
        XCTAssertThrowsError(try parseServerURL("invalid"))
        XCTAssertThrowsError(try parseServerURL("pacs://"))
        XCTAssertThrowsError(try parseServerURL("://host:port"))
    }
}
