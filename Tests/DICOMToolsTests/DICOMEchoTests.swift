import XCTest
import DICOMCore
import DICOMNetwork
@testable import dicom_echo

final class DICOMEchoTests: XCTestCase {
    
    // MARK: - URL Parsing Tests
    
    func testParsePACSURL() throws {
        let echo = DICOMEcho()
        let result = try echo.parseServerURL("pacs://server.example.com:11112")
        XCTAssertEqual(result.scheme, "pacs")
        XCTAssertEqual(result.host, "server.example.com")
        XCTAssertEqual(result.port, 11112)
    }
    
    func testParsePACSURLWithoutPort() throws {
        let echo = DICOMEcho()
        let result = try echo.parseServerURL("pacs://server.example.com")
        XCTAssertEqual(result.scheme, "pacs")
        XCTAssertEqual(result.host, "server.example.com")
        XCTAssertEqual(result.port, 104) // DICOM default port
    }
    
    func testParsePACSURLWithCustomPort() throws {
        let echo = DICOMEcho()
        let result = try echo.parseServerURL("pacs://192.168.1.100:5104")
        XCTAssertEqual(result.scheme, "pacs")
        XCTAssertEqual(result.host, "192.168.1.100")
        XCTAssertEqual(result.port, 5104)
    }
    
    func testInvalidURL() {
        let echo = DICOMEcho()
        XCTAssertThrowsError(try echo.parseServerURL("not-a-url"))
    }
    
    func testInvalidScheme() {
        let echo = DICOMEcho()
        XCTAssertThrowsError(try echo.parseServerURL("http://server.example.com"))
    }
    
    func testFTPScheme() {
        let echo = DICOMEcho()
        XCTAssertThrowsError(try echo.parseServerURL("ftp://server.example.com"))
    }
    
    func testURLWithoutHost() {
        let echo = DICOMEcho()
        XCTAssertThrowsError(try echo.parseServerURL("pacs://"))
    }
    
    func testURLWithIPAddress() throws {
        let echo = DICOMEcho()
        let result = try echo.parseServerURL("pacs://10.0.0.1:104")
        XCTAssertEqual(result.scheme, "pacs")
        XCTAssertEqual(result.host, "10.0.0.1")
        XCTAssertEqual(result.port, 104)
    }
    
    func testURLWithIPv6Address() throws {
        let echo = DICOMEcho()
        // IPv6 addresses in URLs require brackets
        let result = try echo.parseServerURL("pacs://[::1]:11112")
        XCTAssertEqual(result.scheme, "pacs")
        XCTAssertEqual(result.host, "::1")
        XCTAssertEqual(result.port, 11112)
    }
    
    // MARK: - Default Value Tests
    
    func testDefaultCalledAETitle() {
        var echo = DICOMEcho()
        echo.url = "pacs://server:104"
        echo.aet = "TEST_SCU"
        XCTAssertEqual(echo.calledAet, "ANY-SCP")
    }
    
    func testDefaultCount() {
        var echo = DICOMEcho()
        echo.url = "pacs://server:104"
        echo.aet = "TEST_SCU"
        XCTAssertEqual(echo.count, 1)
    }
    
    func testDefaultTimeout() {
        var echo = DICOMEcho()
        echo.url = "pacs://server:104"
        echo.aet = "TEST_SCU"
        XCTAssertEqual(echo.timeout, 30)
    }
    
    func testDefaultFlags() {
        var echo = DICOMEcho()
        echo.url = "pacs://server:104"
        echo.aet = "TEST_SCU"
        XCTAssertFalse(echo.stats)
        XCTAssertFalse(echo.diagnose)
        XCTAssertFalse(echo.verbose)
    }
    
    // MARK: - Command Configuration Tests
    
    func testCommandName() {
        XCTAssertEqual(DICOMEcho.configuration.commandName, "dicom-echo")
    }
    
    func testCommandVersion() {
        XCTAssertEqual(DICOMEcho.configuration.version, "1.0.0")
    }
    
    func testCommandAbstract() {
        XCTAssertTrue(DICOMEcho.configuration.abstract.contains("C-ECHO"))
        XCTAssertTrue(DICOMEcho.configuration.abstract.contains("verification"))
    }
    
    func testCommandDiscussion() {
        let discussion = DICOMEcho.configuration.discussion ?? ""
        XCTAssertTrue(discussion.contains("Examples:"))
        XCTAssertTrue(discussion.contains("pacs://"))
    }
    
    // MARK: - Validation Tests
    
    func testCountValidation() throws {
        var echo = DICOMEcho()
        echo.url = "pacs://server:104"
        echo.aet = "TEST_SCU"
        echo.count = 0
        
        // Count must be greater than 0
        // This would be validated in the run() method
        XCTAssertEqual(echo.count, 0)
    }
    
    func testNegativeCount() throws {
        var echo = DICOMEcho()
        echo.url = "pacs://server:104"
        echo.aet = "TEST_SCU"
        echo.count = -1
        
        // Negative count should be handled
        XCTAssertEqual(echo.count, -1)
    }
    
    func testLargeCount() throws {
        var echo = DICOMEcho()
        echo.url = "pacs://server:104"
        echo.aet = "TEST_SCU"
        echo.count = 1000
        
        XCTAssertEqual(echo.count, 1000)
    }
    
    func testCustomTimeout() throws {
        var echo = DICOMEcho()
        echo.url = "pacs://server:104"
        echo.aet = "TEST_SCU"
        echo.timeout = 60
        
        XCTAssertEqual(echo.timeout, 60)
    }
    
    func testShortTimeout() throws {
        var echo = DICOMEcho()
        echo.url = "pacs://server:104"
        echo.aet = "TEST_SCU"
        echo.timeout = 5
        
        XCTAssertEqual(echo.timeout, 5)
    }
    
    // MARK: - Integration Test Setup (Mock)
    
    // These tests verify the command structure but don't actually
    // connect to a PACS server since that requires network infrastructure
    
    func testCommandStructureWithMinimalArgs() throws {
        var echo = DICOMEcho()
        echo.url = "pacs://localhost:11112"
        echo.aet = "TEST_SCU"
        
        let parsed = try echo.parseServerURL(echo.url)
        XCTAssertEqual(parsed.host, "localhost")
        XCTAssertEqual(parsed.port, 11112)
    }
    
    func testCommandStructureWithAllArgs() throws {
        var echo = DICOMEcho()
        echo.url = "pacs://pacs.example.com:5104"
        echo.aet = "MY_SCU"
        echo.calledAet = "PACS_SCP"
        echo.count = 5
        echo.timeout = 45
        echo.stats = true
        echo.diagnose = false
        echo.verbose = true
        
        let parsed = try echo.parseServerURL(echo.url)
        XCTAssertEqual(parsed.host, "pacs.example.com")
        XCTAssertEqual(parsed.port, 5104)
        XCTAssertEqual(echo.aet, "MY_SCU")
        XCTAssertEqual(echo.calledAet, "PACS_SCP")
        XCTAssertEqual(echo.count, 5)
        XCTAssertEqual(echo.timeout, 45)
        XCTAssertTrue(echo.stats)
        XCTAssertFalse(echo.diagnose)
        XCTAssertTrue(echo.verbose)
    }
    
    func testCommandStructureWithDiagnose() throws {
        var echo = DICOMEcho()
        echo.url = "pacs://diag.example.com:11112"
        echo.aet = "DIAG_SCU"
        echo.diagnose = true
        
        let parsed = try echo.parseServerURL(echo.url)
        XCTAssertEqual(parsed.host, "diag.example.com")
        XCTAssertTrue(echo.diagnose)
    }
}
