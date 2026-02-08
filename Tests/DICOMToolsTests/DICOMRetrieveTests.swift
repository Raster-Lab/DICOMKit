import XCTest
import Foundation
import DICOMCore
import DICOMNetwork

/// Tests for dicom-retrieve CLI tool functionality
/// Tests URL parsing, UID list handling, retrieval methods, query levels, output organization, and parallelism
final class DICOMRetrieveTests: XCTestCase {
    
    // MARK: - URL Parsing Tests
    
    /// Test parsing valid PACS URL with hostname and port
    func testParseValidPACSURL() throws {
        let result = try parseServerURL("pacs://server.example.com:11112")
        XCTAssertEqual(result.scheme, "pacs")
        XCTAssertEqual(result.host, "server.example.com")
        XCTAssertEqual(result.port, 11112)
    }
    
    /// Test parsing PACS URL without explicit port (should default to 104)
    func testParseURLWithDefaultPort() throws {
        let result = try parseServerURL("pacs://server.example.com")
        XCTAssertEqual(result.scheme, "pacs")
        XCTAssertEqual(result.host, "server.example.com")
        XCTAssertEqual(result.port, 104) // DICOM default port
    }
    
    /// Test parsing PACS URL with IP address
    func testParseURLWithIPAddress() throws {
        let result = try parseServerURL("pacs://192.168.1.100:4242")
        XCTAssertEqual(result.scheme, "pacs")
        XCTAssertEqual(result.host, "192.168.1.100")
        XCTAssertEqual(result.port, 4242)
    }
    
    /// Test parsing PACS URL with IPv6 address
    func testParseURLWithIPv6Address() throws {
        let result = try parseServerURL("pacs://[::1]:11112")
        XCTAssertEqual(result.scheme, "pacs")
        XCTAssertEqual(result.host, "::1")
        XCTAssertEqual(result.port, 11112)
    }
    
    /// Test that invalid URL strings are rejected
    func testInvalidURL() {
        XCTAssertThrowsError(try parseServerURL("not-a-url"))
        XCTAssertThrowsError(try parseServerURL(""))
        XCTAssertThrowsError(try parseServerURL("://noscheme"))
    }
    
    /// Test that non-PACS schemes are rejected
    func testInvalidScheme() {
        XCTAssertThrowsError(try parseServerURL("http://server.example.com"))
        XCTAssertThrowsError(try parseServerURL("ftp://server.example.com"))
        XCTAssertThrowsError(try parseServerURL("dicom://server.example.com"))
    }
    
    /// Test that URLs without hostnames are rejected
    func testURLWithoutHost() {
        XCTAssertThrowsError(try parseServerURL("pacs://"))
        XCTAssertThrowsError(try parseServerURL("pacs://:11112"))
    }
    
    // MARK: - UID List Parsing Tests
    
    /// Test parsing valid UID list from text content
    func testLoadValidUIDList() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let uidFile = tempDir.appendingPathComponent("uids.txt")
        
        let content = """
        1.2.840.113619.2.1.1.1
        1.2.840.113619.2.1.1.2
        1.2.840.113619.2.1.1.3
        """
        try content.write(to: uidFile, atomically: true, encoding: .utf8)
        
        let uids = try loadUIDList(from: uidFile.path)
        XCTAssertEqual(uids.count, 3)
        XCTAssertEqual(uids[0], "1.2.840.113619.2.1.1.1")
        XCTAssertEqual(uids[1], "1.2.840.113619.2.1.1.2")
        XCTAssertEqual(uids[2], "1.2.840.113619.2.1.1.3")
        
        // Cleanup
        try? FileManager.default.removeItem(at: uidFile)
    }
    
    /// Test that empty lines are filtered out
    func testLoadUIDListWithEmptyLines() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let uidFile = tempDir.appendingPathComponent("uids_empty.txt")
        
        let content = """
        1.2.840.113619.2.1.1.1
        
        1.2.840.113619.2.1.1.2
        
        
        1.2.840.113619.2.1.1.3
        """
        try content.write(to: uidFile, atomically: true, encoding: .utf8)
        
        let uids = try loadUIDList(from: uidFile.path)
        XCTAssertEqual(uids.count, 3)
        
        // Cleanup
        try? FileManager.default.removeItem(at: uidFile)
    }
    
    /// Test that comment lines (starting with #) are filtered out
    func testLoadUIDListWithComments() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let uidFile = tempDir.appendingPathComponent("uids_comments.txt")
        
        let content = """
        # Study UIDs to retrieve
        1.2.840.113619.2.1.1.1
        # Another comment
        1.2.840.113619.2.1.1.2
        #1.2.840.113619.2.1.1.999
        1.2.840.113619.2.1.1.3
        """
        try content.write(to: uidFile, atomically: true, encoding: .utf8)
        
        let uids = try loadUIDList(from: uidFile.path)
        XCTAssertEqual(uids.count, 3)
        XCTAssertFalse(uids.contains("1.2.840.113619.2.1.1.999"))
        
        // Cleanup
        try? FileManager.default.removeItem(at: uidFile)
    }
    
    /// Test handling of whitespace trimming
    func testLoadUIDListWithWhitespace() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let uidFile = tempDir.appendingPathComponent("uids_whitespace.txt")
        
        let content = """
          1.2.840.113619.2.1.1.1  
        \t1.2.840.113619.2.1.1.2\t
           1.2.840.113619.2.1.1.3   
        """
        try content.write(to: uidFile, atomically: true, encoding: .utf8)
        
        let uids = try loadUIDList(from: uidFile.path)
        XCTAssertEqual(uids.count, 3)
        XCTAssertEqual(uids[0], "1.2.840.113619.2.1.1.1")
        XCTAssertEqual(uids[1], "1.2.840.113619.2.1.1.2")
        XCTAssertEqual(uids[2], "1.2.840.113619.2.1.1.3")
        
        // Cleanup
        try? FileManager.default.removeItem(at: uidFile)
    }
    
    /// Test handling of large UID lists
    func testLoadLargeUIDList() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let uidFile = tempDir.appendingPathComponent("uids_large.txt")
        
        // Generate 1000 UIDs
        var content = ""
        for i in 1...1000 {
            content += "1.2.840.113619.2.1.1.\(i)\n"
        }
        try content.write(to: uidFile, atomically: true, encoding: .utf8)
        
        let uids = try loadUIDList(from: uidFile.path)
        XCTAssertEqual(uids.count, 1000)
        XCTAssertEqual(uids.first, "1.2.840.113619.2.1.1.1")
        XCTAssertEqual(uids.last, "1.2.840.113619.2.1.1.1000")
        
        // Cleanup
        try? FileManager.default.removeItem(at: uidFile)
    }
    
    // MARK: - Retrieval Method Tests
    
    /// Test RetrievalMethod enum parsing from string
    func testRetrievalMethodParsing() {
        let cMove = RetrievalMethodTest(rawValue: "c-move")
        XCTAssertEqual(cMove, .cMove)
        
        let cGet = RetrievalMethodTest(rawValue: "c-get")
        XCTAssertEqual(cGet, .cGet)
        
        let invalid = RetrievalMethodTest(rawValue: "invalid")
        XCTAssertNil(invalid)
    }
    
    /// Test validation that C-MOVE requires move destination
    func testCMoveRequiresMoveDestination() {
        let method = RetrievalMethodTest.cMove
        let moveDestination: String? = nil
        
        // C-MOVE without destination should fail validation
        XCTAssertThrowsError(try validateRetrievalMethod(method, moveDestination: moveDestination))
    }
    
    /// Test that C-MOVE with destination is valid
    func testCMoveWithMoveDestination() throws {
        let method = RetrievalMethodTest.cMove
        let moveDestination: String? = "MY_DEST_AE"
        
        // C-MOVE with destination should pass validation
        try validateRetrievalMethod(method, moveDestination: moveDestination)
    }
    
    /// Test that C-GET doesn't require move destination
    func testCGetDoesNotRequireMoveDestination() throws {
        let method = RetrievalMethodTest.cGet
        let moveDestination: String? = nil
        
        // C-GET without destination should pass validation
        try validateRetrievalMethod(method, moveDestination: moveDestination)
    }
    
    // MARK: - Query Level Tests
    
    /// Test study-level retrieval (only study UID required)
    func testStudyLevelRetrieval() throws {
        let studyUID = "1.2.840.113619.2.1.1.1"
        let seriesUID: String? = nil
        let instanceUID: String? = nil
        
        let level = try determineQueryLevel(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID
        )
        
        XCTAssertEqual(level, .study)
    }
    
    /// Test series-level retrieval (study + series UID required)
    func testSeriesLevelRetrieval() throws {
        let studyUID = "1.2.840.113619.2.1.1.1"
        let seriesUID = "1.2.840.113619.2.1.2.1"
        let instanceUID: String? = nil
        
        let level = try determineQueryLevel(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID
        )
        
        XCTAssertEqual(level, .series)
    }
    
    /// Test instance-level retrieval (study + series + instance UID required)
    func testInstanceLevelRetrieval() throws {
        let studyUID = "1.2.840.113619.2.1.1.1"
        let seriesUID = "1.2.840.113619.2.1.2.1"
        let instanceUID = "1.2.840.113619.2.1.3.1"
        
        let level = try determineQueryLevel(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID
        )
        
        XCTAssertEqual(level, .instance)
    }
    
    /// Test that series-level requires study UID
    func testSeriesLevelRequiresStudyUID() {
        let studyUID: String? = nil
        let seriesUID = "1.2.840.113619.2.1.2.1"
        let instanceUID: String? = nil
        
        XCTAssertThrowsError(try determineQueryLevel(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID
        ))
    }
    
    /// Test that instance-level requires study and series UID
    func testInstanceLevelRequiresStudyAndSeriesUID() {
        let studyUID = "1.2.840.113619.2.1.1.1"
        let seriesUID: String? = nil
        let instanceUID = "1.2.840.113619.2.1.3.1"
        
        XCTAssertThrowsError(try determineQueryLevel(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID
        ))
    }
    
    /// Test that at least study UID is required
    func testQueryLevelRequiresStudyUID() {
        let studyUID: String? = nil
        let seriesUID: String? = nil
        let instanceUID: String? = nil
        
        XCTAssertThrowsError(try determineQueryLevel(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID
        ))
    }
    
    // MARK: - Output Organization Tests
    
    /// Test flat directory structure (all files in output root)
    func testFlatDirectoryOrganization() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let outputDir = tempDir.appendingPathComponent("flat_output")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        let sopInstanceUID = "1.2.840.113619.2.1.3.1"
        let studyUID = "1.2.840.113619.2.1.1.1"
        let seriesUID = "1.2.840.113619.2.1.2.1"
        
        let path = generateOutputPath(
            outputDir: outputDir.path,
            hierarchical: false,
            sopInstanceUID: sopInstanceUID,
            studyUID: studyUID,
            seriesUID: seriesUID
        )
        
        // Should be directly in output directory
        let expectedPath = (outputDir.path as NSString).appendingPathComponent("\(sopInstanceUID).dcm")
        XCTAssertEqual(path, expectedPath)
        
        // Cleanup
        try? FileManager.default.removeItem(at: outputDir)
    }
    
    /// Test hierarchical directory organization (patient/study/series)
    func testHierarchicalDirectoryOrganization() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let outputDir = tempDir.appendingPathComponent("hierarchical_output")
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        let sopInstanceUID = "1.2.840.113619.2.1.3.1"
        let studyUID = "1.2.840.113619.2.1.1.1"
        let seriesUID = "1.2.840.113619.2.1.2.1"
        
        let path = generateOutputPath(
            outputDir: outputDir.path,
            hierarchical: true,
            sopInstanceUID: sopInstanceUID,
            studyUID: studyUID,
            seriesUID: seriesUID
        )
        
        // Should be organized as study/series/instance
        let expectedPath = (outputDir.path as NSString)
            .appendingPathComponent(studyUID)
            .appendingPathComponent(seriesUID)
            .appendingPathComponent("\(sopInstanceUID).dcm")
        XCTAssertEqual(path, expectedPath)
        
        // Cleanup
        try? FileManager.default.removeItem(at: outputDir)
    }
    
    /// Test output directory creation
    func testOutputDirectoryCreation() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let outputDir = tempDir.appendingPathComponent("new_output_test")
        
        // Directory should not exist initially
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputDir.path))
        
        // Create directory
        try createOutputDirectory(outputDir.path)
        
        // Directory should now exist
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputDir.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        
        // Cleanup
        try? FileManager.default.removeItem(at: outputDir)
    }
    
    /// Test that existing directory is acceptable
    func testExistingOutputDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let outputDir = tempDir.appendingPathComponent("existing_output")
        
        // Create directory first
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        // Should not throw error for existing directory
        try createOutputDirectory(outputDir.path)
        
        // Cleanup
        try? FileManager.default.removeItem(at: outputDir)
    }
    
    /// Test that file as output path is rejected
    func testOutputPathAsFileThrowsError() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let outputFile = tempDir.appendingPathComponent("output_file.txt")
        
        // Create a file at the path
        try "test".write(to: outputFile, atomically: true, encoding: .utf8)
        
        // Should throw error because path is a file, not a directory
        XCTAssertThrowsError(try createOutputDirectory(outputFile.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: outputFile)
    }
    
    // MARK: - Parallelism Tests
    
    /// Test chunking of UID lists for parallel processing
    func testChunkingUIDList() {
        let uids = (1...10).map { "1.2.840.113619.2.1.1.\($0)" }
        
        // Chunk into batches of 3
        let chunks = uids.chunked(into: 3)
        
        XCTAssertEqual(chunks.count, 4) // 10 items in chunks of 3 = 4 chunks
        XCTAssertEqual(chunks[0].count, 3)
        XCTAssertEqual(chunks[1].count, 3)
        XCTAssertEqual(chunks[2].count, 3)
        XCTAssertEqual(chunks[3].count, 1) // Remainder
    }
    
    /// Test chunking with exact division
    func testChunkingWithExactDivision() {
        let uids = (1...12).map { "1.2.840.113619.2.1.1.\($0)" }
        
        // Chunk into batches of 4
        let chunks = uids.chunked(into: 4)
        
        XCTAssertEqual(chunks.count, 3) // 12 items in chunks of 4 = 3 chunks
        XCTAssertEqual(chunks[0].count, 4)
        XCTAssertEqual(chunks[1].count, 4)
        XCTAssertEqual(chunks[2].count, 4)
    }
    
    /// Test chunking with single item per chunk
    func testChunkingSingleItems() {
        let uids = (1...5).map { "1.2.840.113619.2.1.1.\($0)" }
        
        // Chunk into batches of 1
        let chunks = uids.chunked(into: 1)
        
        XCTAssertEqual(chunks.count, 5)
        for chunk in chunks {
            XCTAssertEqual(chunk.count, 1)
        }
    }
    
    /// Test chunking with chunk size larger than array
    func testChunkingLargerThanArray() {
        let uids = (1...3).map { "1.2.840.113619.2.1.1.\($0)" }
        
        // Chunk into batches of 10 (larger than array)
        let chunks = uids.chunked(into: 10)
        
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].count, 3)
    }
    
    // MARK: - Byte Formatting Tests
    
    /// Test byte size formatting
    func testFormatBytes() {
        XCTAssertEqual(formatBytes(100), "100 B")
        XCTAssertEqual(formatBytes(1024), "1.0 KB")
        XCTAssertEqual(formatBytes(1048576), "1.0 MB")
        XCTAssertEqual(formatBytes(1073741824), "1.0 GB")
        XCTAssertEqual(formatBytes(512 * 1024), "512.0 KB")
        XCTAssertEqual(formatBytes(1536 * 1024), "1.5 MB")
    }
    
    // MARK: - Error Tests
    
    /// Test RetrieveError descriptions
    func testRetrieveErrorDescriptions() {
        let missingDestError = RetrieveErrorTest.missingMoveDestination
        XCTAssertTrue(missingDestError.description.contains("move destination"))
        
        let partialError = RetrieveErrorTest.partialFailure(succeeded: 10, failed: 3)
        XCTAssertTrue(partialError.description.contains("10"))
        XCTAssertTrue(partialError.description.contains("3"))
    }
    
    // MARK: - Helper Functions
    
    private func parseServerURL(_ urlString: String) throws -> (scheme: String, host: String, port: UInt16) {
        guard let url = URL(string: urlString) else {
            throw RetrieveTestError.invalidURL
        }
        
        guard let scheme = url.scheme, scheme == "pacs" else {
            throw RetrieveTestError.invalidScheme
        }
        
        guard let host = url.host else {
            throw RetrieveTestError.missingHost
        }
        
        let port: UInt16
        if let urlPort = url.port {
            port = UInt16(urlPort)
        } else {
            port = 104 // DICOM default port
        }
        
        return (scheme, host, port)
    }
    
    private func loadUIDList(from path: String) throws -> [String] {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        return content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }
    
    private func validateRetrievalMethod(_ method: RetrievalMethodTest, moveDestination: String?) throws {
        if method == .cMove && moveDestination == nil {
            throw RetrieveTestError.missingMoveDestination
        }
    }
    
    private func determineQueryLevel(
        studyUID: String?,
        seriesUID: String?,
        instanceUID: String?
    ) throws -> QueryLevelTest {
        guard studyUID != nil else {
            throw RetrieveTestError.missingStudyUID
        }
        
        if instanceUID != nil {
            guard seriesUID != nil else {
                throw RetrieveTestError.missingSeriesUID
            }
            return .instance
        } else if seriesUID != nil {
            return .series
        } else {
            return .study
        }
    }
    
    private func generateOutputPath(
        outputDir: String,
        hierarchical: Bool,
        sopInstanceUID: String,
        studyUID: String,
        seriesUID: String
    ) -> String {
        let filename = "\(sopInstanceUID).dcm"
        
        if hierarchical {
            let studyDir = (outputDir as NSString).appendingPathComponent(studyUID)
            let seriesDir = (studyDir as NSString).appendingPathComponent(seriesUID)
            return (seriesDir as NSString).appendingPathComponent(filename)
        } else {
            return (outputDir as NSString).appendingPathComponent(filename)
        }
    }
    
    private func createOutputDirectory(_ path: String) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                throw RetrieveTestError.pathIsNotDirectory
            }
        } else {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1024.0 {
            if kb < 1.0 {
                return "\(bytes) B"
            }
            return String(format: "%.1f KB", kb)
        }
        let mb = kb / 1024.0
        if mb < 1024.0 {
            return String(format: "%.1f MB", mb)
        }
        let gb = mb / 1024.0
        return String(format: "%.1f GB", gb)
    }
}

// MARK: - Test Helpers

enum RetrieveTestError: Error, LocalizedError {
    case invalidURL
    case invalidScheme
    case missingHost
    case missingMoveDestination
    case missingStudyUID
    case missingSeriesUID
    case pathIsNotDirectory
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidScheme:
            return "Invalid scheme"
        case .missingHost:
            return "Missing host"
        case .missingMoveDestination:
            return "C-MOVE requires a move destination"
        case .missingStudyUID:
            return "Study UID is required"
        case .missingSeriesUID:
            return "Series UID is required for instance-level retrieval"
        case .pathIsNotDirectory:
            return "Path exists but is not a directory"
        }
    }
}

enum RetrievalMethodTest: String {
    case cMove = "c-move"
    case cGet = "c-get"
}

enum QueryLevelTest {
    case study
    case series
    case instance
}

enum RetrieveErrorTest: Error, CustomStringConvertible {
    case missingMoveDestination
    case partialFailure(succeeded: Int, failed: Int)
    
    var description: String {
        switch self {
        case .missingMoveDestination:
            return "C-MOVE requires a move destination AE title"
        case .partialFailure(let succeeded, let failed):
            return "Bulk retrieval partially failed: \(succeeded) succeeded, \(failed) failed"
        }
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
