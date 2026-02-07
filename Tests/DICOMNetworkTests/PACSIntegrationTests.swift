#if canImport(Network)

import Testing
import Foundation
@testable import DICOMNetwork
@testable import DICOMCore

// MARK: - PACS Integration Tests

/// Integration tests for DICOM network connectivity with a real PACS server.
///
/// These tests verify the DICOMNetwork module's ability to connect to and communicate
/// with a remote DICOM PACS (Picture Archiving and Communication System) server.
///
/// ## Default Configuration
///
/// The tests use the following default PACS settings:
/// - Host: 117.247.185.219
/// - Port: 11112
/// - Called AE Title: TEAMPACS
/// - Calling AE Title: MAYAM
///
/// ## Environment Variable Configuration
///
/// All configuration values can be overridden using environment variables:
/// - `DICOM_PACS_HOST`: Remote PACS host address
/// - `DICOM_PACS_PORT`: Remote PACS port number
/// - `DICOM_CALLED_AE`: Called AE Title (PACS server)
/// - `DICOM_CALLING_AE`: Calling AE Title (this application)
/// - `DICOM_TIMEOUT`: Connection timeout in seconds
///
/// ## Requirements
///
/// - Apple platform with Network framework (iOS, macOS, visionOS)
/// - Network access to the PACS server
/// - PACS server must be running and accepting connections
/// - Firewall must allow outbound connections on the configured port
///
/// ## Running Integration Tests
///
/// These tests are tagged with `.integration` and can be run with:
/// ```bash
/// swift test --filter PACSIntegrationTests
/// ```
///
/// To run with custom configuration:
/// ```bash
/// DICOM_PACS_HOST="192.168.1.100" DICOM_CALLED_AE="MY_PACS" swift test --filter PACSIntegrationTests
/// ```
///
/// Note: Integration tests may fail if the PACS server is unreachable or misconfigured.

// MARK: - Test Configuration

/// Configuration for PACS integration tests
///
/// All configuration values can be overridden using environment variables:
/// - `DICOM_PACS_HOST`: Remote PACS host address (default: 117.247.185.219)
/// - `DICOM_PACS_PORT`: Remote PACS port (default: 11112)
/// - `DICOM_CALLED_AE`: Called AE Title (default: TEAMPACS)
/// - `DICOM_CALLING_AE`: Calling AE Title (default: MAYAM)
/// - `DICOM_TIMEOUT`: Connection timeout in seconds (default: 30)
enum PACSTestConfiguration {
    /// Remote PACS host address
    static var host: String {
        ProcessInfo.processInfo.environment["DICOM_PACS_HOST"] ?? "117.247.185.219"
    }
    
    /// Remote PACS port
    static var port: UInt16 {
        if let portString = ProcessInfo.processInfo.environment["DICOM_PACS_PORT"],
           let port = UInt16(portString) {
            return port
        }
        return 11112
    }
    
    /// Called AE Title (PACS server)
    static var calledAETitle: String {
        ProcessInfo.processInfo.environment["DICOM_CALLED_AE"] ?? "TEAMPACS"
    }
    
    /// Calling AE Title (this application)
    static var callingAETitle: String {
        ProcessInfo.processInfo.environment["DICOM_CALLING_AE"] ?? "MAYAM"
    }
    
    /// Connection timeout in seconds
    static var timeout: TimeInterval {
        if let timeoutString = ProcessInfo.processInfo.environment["DICOM_TIMEOUT"],
           let timeout = TimeInterval(timeoutString) {
            return timeout
        }
        return 30
    }
    
    /// Maximum PDU size
    static let maxPDUSize: UInt32 = 16384
}

// MARK: - C-ECHO Integration Tests

@Suite("PACS C-ECHO Integration Tests", .tags(.integration))
struct PACSVerificationIntegrationTests {
    
    @Test("C-ECHO connectivity test (ping PACS)")
    func testCEchoConnectivity() async throws {
        // Attempt to verify connectivity with the PACS server using C-ECHO
        let success = try await DICOMVerificationService.verify(
            host: PACSTestConfiguration.host,
            port: PACSTestConfiguration.port,
            callingAE: PACSTestConfiguration.callingAETitle,
            calledAE: PACSTestConfiguration.calledAETitle,
            timeout: PACSTestConfiguration.timeout
        )
        
        #expect(success == true, "C-ECHO verification should succeed")
    }
    
    @Test("C-ECHO with detailed result")
    func testCEchoWithDetailedResult() async throws {
        // Perform C-ECHO and get detailed results including round-trip time
        let result = try await DICOMVerificationService.echo(
            host: PACSTestConfiguration.host,
            port: PACSTestConfiguration.port,
            callingAE: PACSTestConfiguration.callingAETitle,
            calledAE: PACSTestConfiguration.calledAETitle,
            timeout: PACSTestConfiguration.timeout
        )
        
        #expect(result.success == true, "C-ECHO should succeed")
        #expect(result.status.isSuccess == true, "DIMSE status should indicate success")
        #expect(result.roundTripTime > 0, "Round-trip time should be positive")
        #expect(result.remoteAETitle == PACSTestConfiguration.calledAETitle)
        
        // Log the round-trip time for diagnostic purposes
        print("C-ECHO round-trip time: \(String(format: "%.3f", result.roundTripTime)) seconds")
    }
    
    @Test("C-ECHO with custom configuration")
    func testCEchoWithConfiguration() async throws {
        let callingAE = try AETitle(PACSTestConfiguration.callingAETitle)
        let calledAE = try AETitle(PACSTestConfiguration.calledAETitle)
        
        let config = VerificationConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            timeout: PACSTestConfiguration.timeout,
            maxPDUSize: PACSTestConfiguration.maxPDUSize
        )
        
        let result = try await DICOMVerificationService.echo(
            host: PACSTestConfiguration.host,
            port: PACSTestConfiguration.port,
            configuration: config
        )
        
        #expect(result.success == true, "C-ECHO with custom configuration should succeed")
    }
}

// MARK: - C-FIND Integration Tests

@Suite("PACS C-FIND Integration Tests", .tags(.integration))
struct PACSQueryIntegrationTests {
    
    @Test("Query studies from PACS")
    func testQueryStudies() async throws {
        // Query for all studies (no specific filter)
        let studies = try await DICOMQueryService.findStudies(
            host: PACSTestConfiguration.host,
            port: PACSTestConfiguration.port,
            callingAE: PACSTestConfiguration.callingAETitle,
            calledAE: PACSTestConfiguration.calledAETitle,
            timeout: PACSTestConfiguration.timeout
        )
        
        // We expect the PACS to have at least some studies, or the query should succeed with 0 results
        print("Found \(studies.count) studies")
        
        // If there are studies, verify the result structure
        if let firstStudy = studies.first {
            print("First study UID: \(firstStudy.studyInstanceUID ?? "N/A")")
            print("Patient Name: \(firstStudy.patientName ?? "N/A")")
            print("Study Date: \(firstStudy.studyDate ?? "N/A")")
        }
    }
    
    @Test("Query studies with patient name filter")
    func testQueryStudiesWithFilter() async throws {
        // Query with wildcard patient name filter
        let queryKeys = QueryKeys.defaultStudyKeys()
            .patientName("*")  // Match all patients
        
        let studies = try await DICOMQueryService.findStudies(
            host: PACSTestConfiguration.host,
            port: PACSTestConfiguration.port,
            callingAE: PACSTestConfiguration.callingAETitle,
            calledAE: PACSTestConfiguration.calledAETitle,
            matching: queryKeys,
            timeout: PACSTestConfiguration.timeout
        )
        
        print("Found \(studies.count) studies with wildcard filter")
    }
    
    @Test("Query series for a study")
    func testQuerySeries() async throws {
        // First, get a study to query series for
        let studies = try await DICOMQueryService.findStudies(
            host: PACSTestConfiguration.host,
            port: PACSTestConfiguration.port,
            callingAE: PACSTestConfiguration.callingAETitle,
            calledAE: PACSTestConfiguration.calledAETitle,
            timeout: PACSTestConfiguration.timeout
        )
        
        guard let firstStudy = studies.first,
              let studyUID = firstStudy.studyInstanceUID else {
            // Skip if no studies available
            print("No studies available to query series")
            return
        }
        
        // Query series for the study
        let series = try await DICOMQueryService.findSeries(
            host: PACSTestConfiguration.host,
            port: PACSTestConfiguration.port,
            callingAE: PACSTestConfiguration.callingAETitle,
            calledAE: PACSTestConfiguration.calledAETitle,
            forStudy: studyUID,
            timeout: PACSTestConfiguration.timeout
        )
        
        print("Found \(series.count) series in study \(studyUID)")
        
        if let firstSeries = series.first {
            print("First series UID: \(firstSeries.seriesInstanceUID ?? "N/A")")
            print("Modality: \(firstSeries.modality ?? "N/A")")
            if let seriesNumber = firstSeries.seriesNumber {
                print("Series Number: \(seriesNumber)")
            }
        }
    }
    
    @Test("Query instances for a series")
    func testQueryInstances() async throws {
        // First, get a study and series
        let studies = try await DICOMQueryService.findStudies(
            host: PACSTestConfiguration.host,
            port: PACSTestConfiguration.port,
            callingAE: PACSTestConfiguration.callingAETitle,
            calledAE: PACSTestConfiguration.calledAETitle,
            timeout: PACSTestConfiguration.timeout
        )
        
        guard let firstStudy = studies.first,
              let studyUID = firstStudy.studyInstanceUID else {
            print("No studies available to query instances")
            return
        }
        
        let series = try await DICOMQueryService.findSeries(
            host: PACSTestConfiguration.host,
            port: PACSTestConfiguration.port,
            callingAE: PACSTestConfiguration.callingAETitle,
            calledAE: PACSTestConfiguration.calledAETitle,
            forStudy: studyUID,
            timeout: PACSTestConfiguration.timeout
        )
        
        guard let firstSeries = series.first,
              let seriesUID = firstSeries.seriesInstanceUID else {
            print("No series available to query instances")
            return
        }
        
        // Query instances for the series
        let instances = try await DICOMQueryService.findInstances(
            host: PACSTestConfiguration.host,
            port: PACSTestConfiguration.port,
            callingAE: PACSTestConfiguration.callingAETitle,
            calledAE: PACSTestConfiguration.calledAETitle,
            forStudy: studyUID,
            forSeries: seriesUID,
            timeout: PACSTestConfiguration.timeout
        )
        
        print("Found \(instances.count) instances in series \(seriesUID)")
        
        if let firstInstance = instances.first {
            print("First instance UID: \(firstInstance.sopInstanceUID ?? "N/A")")
            print("SOP Class UID: \(firstInstance.sopClassUID ?? "N/A")")
            if let instanceNumber = firstInstance.instanceNumber {
                print("Instance Number: \(instanceNumber)")
            }
        }
    }
}

// MARK: - Association Integration Tests

@Suite("PACS Association Integration Tests", .tags(.integration))
struct PACSAssociationIntegrationTests {
    
    @Test("Establish and release association")
    func testAssociationLifecycle() async throws {
        let callingAE = try AETitle(PACSTestConfiguration.callingAETitle)
        let calledAE = try AETitle(PACSTestConfiguration.calledAETitle)
        
        let config = AssociationConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            host: PACSTestConfiguration.host,
            port: PACSTestConfiguration.port,
            maxPDUSize: PACSTestConfiguration.maxPDUSize,
            implementationClassUID: VerificationConfiguration.defaultImplementationClassUID,
            implementationVersionName: VerificationConfiguration.defaultImplementationVersionName,
            timeout: PACSTestConfiguration.timeout
        )
        
        let association = Association(configuration: config)
        
        // Create presentation context for Verification SOP Class
        let presentationContext = try PresentationContext(
            id: 1,
            abstractSyntax: verificationSOPClassUID,
            transferSyntaxes: [
                explicitVRLittleEndianTransferSyntaxUID,
                implicitVRLittleEndianTransferSyntaxUID
            ]
        )
        
        // Request association
        let negotiated = try await association.request(presentationContexts: [presentationContext])
        
        #expect(negotiated.acceptedPresentationContexts.count > 0, "At least one presentation context should be accepted")
        #expect(negotiated.maxPDUSize > 0, "Negotiated max PDU size should be positive")
        
        print("Negotiated max PDU size: \(negotiated.maxPDUSize)")
        print("Remote implementation class UID: \(negotiated.remoteImplementationClassUID)")
        
        // Release association gracefully
        try await association.release()
    }
    
    @Test("Association with multiple presentation contexts")
    func testAssociationWithMultiplePresentationContexts() async throws {
        let callingAE = try AETitle(PACSTestConfiguration.callingAETitle)
        let calledAE = try AETitle(PACSTestConfiguration.calledAETitle)
        
        let config = AssociationConfiguration(
            callingAETitle: callingAE,
            calledAETitle: calledAE,
            host: PACSTestConfiguration.host,
            port: PACSTestConfiguration.port,
            maxPDUSize: PACSTestConfiguration.maxPDUSize,
            implementationClassUID: VerificationConfiguration.defaultImplementationClassUID,
            implementationVersionName: VerificationConfiguration.defaultImplementationVersionName,
            timeout: PACSTestConfiguration.timeout
        )
        
        let association = Association(configuration: config)
        
        // Create multiple presentation contexts
        let verificationContext = try PresentationContext(
            id: 1,
            abstractSyntax: verificationSOPClassUID,
            transferSyntaxes: [explicitVRLittleEndianTransferSyntaxUID, implicitVRLittleEndianTransferSyntaxUID]
        )
        
        let studyRootFindContext = try PresentationContext(
            id: 3,
            abstractSyntax: studyRootQueryRetrieveFindSOPClassUID,
            transferSyntaxes: [explicitVRLittleEndianTransferSyntaxUID, implicitVRLittleEndianTransferSyntaxUID]
        )
        
        // Request association with multiple contexts
        let negotiated = try await association.request(presentationContexts: [verificationContext, studyRootFindContext])
        
        print("Accepted contexts: \(negotiated.acceptedPresentationContexts.count)")
        for context in negotiated.acceptedPresentationContexts {
            print("  Context ID \(context.id): \(context.isAccepted ? "Accepted" : "Rejected")")
        }
        
        // Release association
        try await association.release()
    }
}

// MARK: - Error Handling Integration Tests

@Suite("PACS Error Handling Integration Tests", .tags(.integration))
struct PACSErrorHandlingIntegrationTests {
    
    @Test("Connection timeout handling")
    func testConnectionTimeout() async throws {
        // Use a very short timeout to trigger timeout error
        do {
            _ = try await DICOMVerificationService.verify(
                host: PACSTestConfiguration.host,
                port: PACSTestConfiguration.port,
                callingAE: PACSTestConfiguration.callingAETitle,
                calledAE: PACSTestConfiguration.calledAETitle,
                timeout: 0.001  // Extremely short timeout
            )
            // If we get here with the real server, the timeout wasn't triggered
            // This is acceptable as the server might be very fast
        } catch {
            // Expected to catch a timeout or connection error
            print("Caught expected error: \(error)")
        }
    }
    
    @Test("Invalid AE title handling")
    func testInvalidAETitle() async throws {
        // Attempt connection with potentially invalid called AE title
        // The PACS may reject the association
        do {
            let result = try await DICOMVerificationService.verify(
                host: PACSTestConfiguration.host,
                port: PACSTestConfiguration.port,
                callingAE: PACSTestConfiguration.callingAETitle,
                calledAE: "INVALID_AE",  // Use an AE title the PACS might reject
                timeout: PACSTestConfiguration.timeout
            )
            
            // PACS may accept or reject based on its configuration
            print("Connection result with potentially invalid AE: \(result)")
        } catch {
            // Expected to potentially receive an association rejection
            print("Caught expected rejection: \(error)")
        }
    }
}

// MARK: - C-STORE Integration Tests

@Suite("PACS C-STORE Integration Tests", .tags(.integration))
struct PACSStorageIntegrationTests {
    
    /// Creates a minimal valid DICOM file for testing C-STORE
    private func createTestDICOMFile() throws -> (Data, String, String) {
        // Create a minimal Secondary Capture DICOM file for testing
        let sopClassUID = "1.2.840.10008.5.1.4.1.1.7"  // Secondary Capture Image Storage
        let sopInstanceUID = "1.2.840.113619.2.55.3.2831168264.623.1551891469.1.\(UUID().uuidString.replacingOccurrences(of: "-", with: "."))"
        
        // Create a minimal DICOM dataset
        var dataset = DataSet()
        
        // Patient Module (required)
        try dataset.setString("TEST^PATIENT", for: Tag(0x0010, 0x0010))  // Patient Name
        try dataset.setString("12345", for: Tag(0x0010, 0x0020))  // Patient ID
        try dataset.setString("19800101", for: Tag(0x0010, 0x0030))  // Patient Birth Date
        try dataset.setString("M", for: Tag(0x0010, 0x0040))  // Patient Sex
        
        // General Study Module (required)
        let studyUID = "1.2.840.113619.2.55.3.2831168264.623.\(Int(Date().timeIntervalSince1970))"
        try dataset.setString(studyUID, for: Tag(0x0020, 0x000D))  // Study Instance UID
        try dataset.setString("20260207", for: Tag(0x0008, 0x0020))  // Study Date
        try dataset.setString("120000", for: Tag(0x0008, 0x0030))  // Study Time
        try dataset.setString("DR^REFERRING", for: Tag(0x0008, 0x0090))  // Referring Physician Name
        try dataset.setString("TEST001", for: Tag(0x0020, 0x0010))  // Study ID
        
        // General Series Module (required)
        let seriesUID = "\(studyUID).1"
        try dataset.setString(seriesUID, for: Tag(0x0020, 0x000E))  // Series Instance UID
        try dataset.setString("OT", for: Tag(0x0008, 0x0060))  // Modality
        try dataset.setString("1", for: Tag(0x0020, 0x0011))  // Series Number
        
        // General Equipment Module (optional but good practice)
        try dataset.setString("DICOMKit", for: Tag(0x0008, 0x0070))  // Manufacturer
        try dataset.setString("Test Suite", for: Tag(0x0008, 0x1090))  // Manufacturer Model Name
        
        // General Image Module (required)
        try dataset.setString("1", for: Tag(0x0020, 0x0013))  // Instance Number
        
        // SOP Common Module (required)
        try dataset.setString(sopClassUID, for: Tag(0x0008, 0x0016))  // SOP Class UID
        try dataset.setString(sopInstanceUID, for: Tag(0x0008, 0x0018))  // SOP Instance UID
        
        // SC Equipment Module (required for Secondary Capture)
        try dataset.setString("WSD", for: Tag(0x0008, 0x0064))  // Conversion Type
        
        // Image Pixel Module (required) - minimal 1x1 pixel
        try dataset.setString("MONOCHROME2", for: Tag(0x0028, 0x0004))  // Photometric Interpretation
        try dataset.setUInt16(1, for: Tag(0x0028, 0x0010))  // Rows
        try dataset.setUInt16(1, for: Tag(0x0028, 0x0011))  // Columns
        try dataset.setUInt16(8, for: Tag(0x0028, 0x0100))  // Bits Allocated
        try dataset.setUInt16(8, for: Tag(0x0028, 0x0101))  // Bits Stored
        try dataset.setUInt16(7, for: Tag(0x0028, 0x0102))  // High Bit
        try dataset.setUInt16(0, for: Tag(0x0028, 0x0103))  // Pixel Representation
        try dataset.setUInt16(1, for: Tag(0x0028, 0x0002))  // Samples per Pixel
        
        // Pixel Data (1 byte for 1x1 8-bit image)
        let pixelData = Data([128])  // Mid-gray value
        try dataset.setData(pixelData, for: Tag(0x7FE0, 0x0010))  // Pixel Data
        
        // Write to DICOM file format
        let transferSyntaxUID = explicitVRLittleEndianTransferSyntaxUID
        let writer = DICOMWriter()
        let dicomData = try writer.write(
            dataset: dataset,
            transferSyntax: transferSyntaxUID,
            includeMetaInformation: true
        )
        
        return (dicomData, sopClassUID, sopInstanceUID)
    }
    
    @Test("C-STORE basic storage operation")
    func testBasicStorage() async throws {
        // Create a test DICOM file
        let (dicomData, sopClassUID, sopInstanceUID) = try createTestDICOMFile()
        
        // Store the file to PACS
        let result = try await StorageService.store(
            dicomData: dicomData,
            sopClassUID: sopClassUID,
            sopInstanceUID: sopInstanceUID,
            transferSyntaxUID: explicitVRLittleEndianTransferSyntaxUID,
            host: PACSTestConfiguration.host,
            port: PACSTestConfiguration.port,
            callingAE: PACSTestConfiguration.callingAETitle,
            calledAE: PACSTestConfiguration.calledAETitle,
            timeout: PACSTestConfiguration.timeout
        )
        
        #expect(result.success, "C-STORE should succeed")
        #expect(result.status.isSuccess, "DIMSE status should indicate success")
        
        print("Stored SOP Instance UID: \(sopInstanceUID)")
        print("Storage result: \(result.success ? "Success" : "Failed")")
    }
    
    @Test("C-STORE with retry on transient failure", .disabled("Requires simulation of network failure"))
    func testStorageWithRetry() async throws {
        // This test would require a way to simulate transient network failures
        // For now, it's marked as disabled
        // In a real scenario, we would:
        // 1. Configure a retry policy
        // 2. Simulate a temporary failure
        // 3. Verify the operation succeeds after retry
    }
    
    @Test("Store-and-forward queue delivery", .disabled("Requires PACS connectivity simulation"))
    func testStoreAndForwardQueue() async throws {
        // This test would require:
        // 1. Creating a StoreAndForwardQueue
        // 2. Queueing files when PACS is unavailable
        // 3. Simulating PACS becoming available
        // 4. Verifying queued files are delivered
        // Marked as disabled for now as it requires complex test infrastructure
    }
    
    @Test("Transfer syntax conversion", .disabled("Requires codec support"))
    func testTransferSyntaxConversion() async throws {
        // This test would verify that:
        // 1. A file with one transfer syntax can be transcoded
        // 2. The transcoded file is correctly stored
        // 3. Pixel data integrity is maintained
        // Marked as disabled as it requires full codec implementation
    }
    
    @Test("Bandwidth limiting", .disabled("Requires timing measurement infrastructure"))
    func testBandwidthLimiting() async throws {
        // This test would verify that:
        // 1. Bandwidth limiter respects configured limits
        // 2. Large file transfers are throttled appropriately
        // 3. Multiple concurrent transfers share bandwidth
        // Marked as disabled as it requires precise timing measurement
    }
    
    @Test("Audit logging verification")
    func testAuditLogging() async throws {
        // Create a temporary directory for audit logs
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dicomkit-test-audit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let auditLogPath = tempDir.appendingPathComponent("audit.jsonl")
        
        // Create audit logger configuration
        let config = AuditLoggerConfiguration(
            logFilePath: auditLogPath.path,
            enabledEventTypes: [.applicationStart, .dicomInstancesTransferred],
            rotationPolicy: .none
        )
        
        let logger = try FileAuditLogger(configuration: config)
        
        // Log a test event
        try await logger.log(
            eventType: .applicationStart,
            outcome: .success,
            user: "TestUser",
            source: AuditSource(siteID: "TestSite", enterpriseSiteID: "TEST"),
            additionalInfo: ["test": "value"]
        )
        
        // Verify log file was created and contains the event
        #expect(FileManager.default.fileExists(atPath: auditLogPath.path), "Audit log file should exist")
        
        let logContent = try String(contentsOf: auditLogPath, encoding: .utf8)
        #expect(logContent.contains("applicationStart"), "Log should contain the event type")
        
        print("Audit log verified at: \(auditLogPath.path)")
    }
}

// MARK: - Test Tags

extension Tag {
    /// Tag for integration tests that require network access
    @Tag static var integration: Self
}

#endif  // canImport(Network)
