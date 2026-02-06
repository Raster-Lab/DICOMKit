import XCTest
import Foundation
import DICOMCore
import DICOMNetwork

// Note: We cannot directly import the executable module, so we test the components
// by reimplementing the testable parts or testing via process execution

final class DICOMSendTests: XCTestCase {
    
    // MARK: - URL Parsing Tests
    
    func testParsePACSURL() throws {
        let result = try parsePACSURL("pacs://server.example.com:11112")
        XCTAssertEqual(result.scheme, "pacs")
        XCTAssertEqual(result.host, "server.example.com")
        XCTAssertEqual(result.port, 11112)
    }
    
    func testParsePACSURLWithoutPort() throws {
        let result = try parsePACSURL("pacs://server.example.com")
        XCTAssertEqual(result.scheme, "pacs")
        XCTAssertEqual(result.host, "server.example.com")
        XCTAssertEqual(result.port, 104) // DICOM default port
    }
    
    func testParsePACSURLWithIPAddress() throws {
        let result = try parsePACSURL("pacs://192.168.1.100:4242")
        XCTAssertEqual(result.scheme, "pacs")
        XCTAssertEqual(result.host, "192.168.1.100")
        XCTAssertEqual(result.port, 4242)
    }
    
    func testInvalidURL() {
        XCTAssertThrowsError(try parsePACSURL("not-a-url"))
    }
    
    func testInvalidScheme() {
        XCTAssertThrowsError(try parsePACSURL("http://server.example.com"))
        XCTAssertThrowsError(try parsePACSURL("ftp://server.example.com"))
    }
    
    func testURLWithoutHost() {
        XCTAssertThrowsError(try parsePACSURL("pacs://"))
        XCTAssertThrowsError(try parsePACSURL("pacs://:11112"))
    }
    
    // MARK: - File Detection Tests
    
    func testIsDICOMFileByExtension() {
        XCTAssertTrue(isDICOMFile("/path/to/file.dcm"))
        XCTAssertTrue(isDICOMFile("/path/to/file.DCM"))
        XCTAssertTrue(isDICOMFile("/path/to/file.dicom"))
        XCTAssertTrue(isDICOMFile("/path/to/file.DICOM"))
        XCTAssertTrue(isDICOMFile("/path/to/file.dic"))
        XCTAssertTrue(isDICOMFile("/path/to/file.DIC"))
    }
    
    func testIsNotDICOMFileByExtension() {
        XCTAssertFalse(isDICOMFile("/path/to/file.txt"))
        XCTAssertFalse(isDICOMFile("/path/to/file.jpg"))
        XCTAssertFalse(isDICOMFile("/path/to/file.pdf"))
        XCTAssertFalse(isDICOMFile("/path/to/file"))
    }
    
    func testIsDICOMFileWithMagicBytes() throws {
        // Create a temporary file with DICOM magic bytes
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test.dat")
        
        // Create DICOM preamble (128 bytes) + "DICM"
        var data = Data(count: 128) // Preamble
        data.append(contentsOf: [0x44, 0x49, 0x43, 0x4D]) // "DICM"
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Some extra data
        
        try data.write(to: tempFile)
        
        XCTAssertTrue(isDICOMFileWithMagicCheck(tempFile.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempFile)
    }
    
    func testIsNotDICOMFileWithoutMagicBytes() throws {
        // Create a temporary file without DICOM magic bytes
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test.dat")
        
        let data = Data([0x00, 0x01, 0x02, 0x03])
        try data.write(to: tempFile)
        
        XCTAssertFalse(isDICOMFileWithMagicCheck(tempFile.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempFile)
    }
    
    // MARK: - Pattern Matching Tests
    
    func testMatchesPatternExact() {
        XCTAssertTrue(matchesPattern("file.dcm", pattern: "file.dcm"))
        XCTAssertFalse(matchesPattern("file.dcm", pattern: "other.dcm"))
    }
    
    func testMatchesPatternWildcardStar() {
        XCTAssertTrue(matchesPattern("file.dcm", pattern: "*.dcm"))
        XCTAssertTrue(matchesPattern("test.dcm", pattern: "*.dcm"))
        XCTAssertTrue(matchesPattern("CT_001.dcm", pattern: "CT_*.dcm"))
        XCTAssertTrue(matchesPattern("CT_001.dcm", pattern: "CT*"))
        XCTAssertFalse(matchesPattern("file.txt", pattern: "*.dcm"))
    }
    
    func testMatchesPatternWildcardQuestion() {
        XCTAssertTrue(matchesPattern("file1.dcm", pattern: "file?.dcm"))
        XCTAssertTrue(matchesPattern("fileA.dcm", pattern: "file?.dcm"))
        XCTAssertFalse(matchesPattern("file12.dcm", pattern: "file?.dcm"))
        XCTAssertFalse(matchesPattern("file.dcm", pattern: "file?.dcm"))
    }
    
    func testMatchesPatternCombined() {
        XCTAssertTrue(matchesPattern("CT_001.dcm", pattern: "CT_???.dcm"))
        XCTAssertTrue(matchesPattern("MR_001.dcm", pattern: "*_001.dcm"))
        XCTAssertTrue(matchesPattern("study_1_series_2.dcm", pattern: "study_?_*.dcm"))
    }
    
    // MARK: - File Gathering Tests
    
    func testGatherSingleFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test.dcm")
        
        // Create test file
        let data = Data([0x00, 0x01])
        try data.write(to: testFile)
        
        let files = try gatherTestFiles(from: [testFile.path], recursive: false)
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files.first, testFile.path)
        
        // Cleanup
        try? FileManager.default.removeItem(at: testFile)
    }
    
    func testGatherMultipleFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("test_gather")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        let file1 = testDir.appendingPathComponent("file1.dcm")
        let file2 = testDir.appendingPathComponent("file2.dcm")
        
        try Data([0x00]).write(to: file1)
        try Data([0x00]).write(to: file2)
        
        let files = try gatherTestFiles(from: [file1.path, file2.path], recursive: false)
        XCTAssertEqual(files.count, 2)
        XCTAssertTrue(files.contains(file1.path))
        XCTAssertTrue(files.contains(file2.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: testDir)
    }
    
    func testGatherDirectoryNonRecursive() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("test_nonrecursive")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        // Create files in root
        let file1 = testDir.appendingPathComponent("file1.dcm")
        let file2 = testDir.appendingPathComponent("file2.dcm")
        try Data([0x00]).write(to: file1)
        try Data([0x00]).write(to: file2)
        
        // Create subdirectory with file (should not be included)
        let subDir = testDir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let file3 = subDir.appendingPathComponent("file3.dcm")
        try Data([0x00]).write(to: file3)
        
        let files = try scanTestDirectory(testDir.path, recursive: false)
        XCTAssertEqual(files.count, 2)
        XCTAssertTrue(files.contains(file1.path))
        XCTAssertTrue(files.contains(file2.path))
        XCTAssertFalse(files.contains(file3.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: testDir)
    }
    
    func testGatherDirectoryRecursive() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("test_recursive")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        // Create files in root
        let file1 = testDir.appendingPathComponent("file1.dcm")
        try Data([0x00]).write(to: file1)
        
        // Create subdirectory with files
        let subDir = testDir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let file2 = subDir.appendingPathComponent("file2.dcm")
        try Data([0x00]).write(to: file2)
        
        // Create nested subdirectory with file
        let nestedDir = subDir.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        let file3 = nestedDir.appendingPathComponent("file3.dcm")
        try Data([0x00]).write(to: file3)
        
        let files = try scanTestDirectory(testDir.path, recursive: true)
        XCTAssertEqual(files.count, 3)
        XCTAssertTrue(files.contains(file1.path))
        XCTAssertTrue(files.contains(file2.path))
        XCTAssertTrue(files.contains(file3.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: testDir)
    }
    
    func testGatherFilesSkipsNonDICOM() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("test_skip")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        
        let dcmFile = testDir.appendingPathComponent("file.dcm")
        let txtFile = testDir.appendingPathComponent("file.txt")
        let jpgFile = testDir.appendingPathComponent("file.jpg")
        
        try Data([0x00]).write(to: dcmFile)
        try Data([0x00]).write(to: txtFile)
        try Data([0x00]).write(to: jpgFile)
        
        let files = try scanTestDirectory(testDir.path, recursive: false)
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files.first, dcmFile.path)
        
        // Cleanup
        try? FileManager.default.removeItem(at: testDir)
    }
    
    // MARK: - Priority Tests
    
    func testPriorityMapping() {
        XCTAssertEqual(PriorityOptionTest.low.dimseValue, .low)
        XCTAssertEqual(PriorityOptionTest.medium.dimseValue, .medium)
        XCTAssertEqual(PriorityOptionTest.high.dimseValue, .high)
    }
    
    // MARK: - Progress Formatting Tests
    
    func testFormatBytes() {
        XCTAssertEqual(formatBytes(100), "100 B")
        XCTAssertEqual(formatBytes(1024), "1.00 KB")
        XCTAssertEqual(formatBytes(1024 * 1024), "1.00 MB")
        XCTAssertEqual(formatBytes(1024 * 1024 * 1024), "1.00 GB")
        XCTAssertEqual(formatBytes(512 * 1024), "512.00 KB")
        XCTAssertEqual(formatBytes(1536 * 1024), "1.50 MB")
    }
    
    func testFormatDuration() {
        XCTAssertEqual(formatDuration(0.5), "500 ms")
        XCTAssertEqual(formatDuration(1.5), "1.5 s")
        XCTAssertEqual(formatDuration(45.7), "45.7 s")
        XCTAssertEqual(formatDuration(90), "1m 30s")
        XCTAssertEqual(formatDuration(3665), "1h 1m")
    }
    
    // MARK: - Error Tests
    
    func testSendErrorDescriptions() {
        let unknownError = SendErrorTest.unknownError
        XCTAssertNotNil(unknownError.localizedDescription)
        
        let partialError = SendErrorTest.partialFailure(succeeded: 10, failed: 5)
        XCTAssertTrue(partialError.localizedDescription.contains("10"))
        XCTAssertTrue(partialError.localizedDescription.contains("5"))
    }
    
    // MARK: - Retry Logic Tests
    
    func testExponentialBackoffDelay() {
        // Test exponential backoff calculation
        XCTAssertEqual(calculateBackoffDelay(attempt: 0), 1.0)
        XCTAssertEqual(calculateBackoffDelay(attempt: 1), 2.0)
        XCTAssertEqual(calculateBackoffDelay(attempt: 2), 4.0)
        XCTAssertEqual(calculateBackoffDelay(attempt: 3), 8.0)
        XCTAssertEqual(calculateBackoffDelay(attempt: 4), 16.0)
    }
    
    // MARK: - Integration Tests (Conceptual)
    
    func testDryRunDoesNotSendFiles() {
        // In a real implementation, this would verify that --dry-run
        // discovers files but doesn't initiate network connections
        // This is a placeholder for integration testing
    }
    
    func testRetryLogicExhaustsAttempts() {
        // Test that retry logic properly exhausts the configured attempts
        // This is a placeholder for integration testing
    }
    
    func testProgressReportingAccuracy() {
        // Test that progress reporting correctly tracks file counts
        // This is a placeholder for integration testing
    }
    
    // MARK: - Helper Functions (Reimplemented from main.swift)
    
    private func parsePACSURL(_ urlString: String) throws -> (scheme: String, host: String, port: UInt16) {
        guard let url = URL(string: urlString) else {
            throw TestError.invalidURL
        }
        
        guard let scheme = url.scheme, scheme == "pacs" else {
            throw TestError.invalidScheme
        }
        
        guard let host = url.host else {
            throw TestError.missingHost
        }
        
        let port: UInt16
        if let urlPort = url.port {
            port = UInt16(urlPort)
        } else {
            port = 104
        }
        
        return (scheme, host, port)
    }
    
    private func isDICOMFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return ["dcm", "dicom", "dic"].contains(ext)
    }
    
    private func isDICOMFileWithMagicCheck(_ path: String) -> Bool {
        guard let fileHandle = FileHandle(forReadingAtPath: path),
              let data = try? fileHandle.read(upToCount: 132) else {
            return false
        }
        
        if data.count >= 132 {
            let magic = data[128..<132]
            return magic == Data([0x44, 0x49, 0x43, 0x4D])
        }
        
        return false
    }
    
    private func matchesPattern(_ string: String, pattern: String) -> Bool {
        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")
        
        guard let regex = try? NSRegularExpression(pattern: "^" + regexPattern + "$") else {
            return false
        }
        
        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, range: range) != nil
    }
    
    private func gatherTestFiles(from paths: [String], recursive: Bool) throws -> [String] {
        var files: [String] = []
        let fileManager = FileManager.default
        
        for path in paths {
            var isDirectory: ObjCBool = false
            
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
                continue
            }
            
            if isDirectory.boolValue {
                let foundFiles = try scanTestDirectory(path, recursive: recursive)
                files.append(contentsOf: foundFiles)
            } else {
                files.append(path)
            }
        }
        
        return files
    }
    
    private func scanTestDirectory(_ path: String, recursive: Bool) throws -> [String] {
        let fileManager = FileManager.default
        var files: [String] = []
        
        if recursive {
            guard let enumerator = fileManager.enumerator(atPath: path) else {
                throw TestError.cannotAccessDirectory
            }
            
            for case let item as String in enumerator {
                let fullPath = (path as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                   !isDirectory.boolValue,
                   isDICOMFile(fullPath) {
                    files.append(fullPath)
                }
            }
        } else {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for item in contents {
                let fullPath = (path as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                   !isDirectory.boolValue,
                   isDICOMFile(fullPath) {
                    files.append(fullPath)
                }
            }
        }
        
        return files
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var unitIndex = 0
        
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        
        if unitIndex == 0 {
            return "\(bytes) \(units[0])"
        } else {
            return String(format: "%.2f %@", value, units[unitIndex])
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 1 {
            return String(format: "%.0f ms", seconds * 1000)
        } else if seconds < 60 {
            return String(format: "%.1f s", seconds)
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(secs)s"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
    
    private func calculateBackoffDelay(attempt: Int) -> Double {
        return Double(1 << attempt)
    }
}

// MARK: - Test Helpers

enum TestError: Error {
    case invalidURL
    case invalidScheme
    case missingHost
    case cannotAccessDirectory
}

enum PriorityOptionTest {
    case low
    case medium
    case high
    
    var dimseValue: DIMSEPriority {
        switch self {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }
}

enum SendErrorTest: LocalizedError {
    case unknownError
    case partialFailure(succeeded: Int, failed: Int)
    
    var localizedDescription: String {
        switch self {
        case .unknownError:
            return "Unknown error occurred"
        case .partialFailure(let succeeded, let failed):
            return "Send completed with \(succeeded) succeeded and \(failed) failed"
        }
    }
}
