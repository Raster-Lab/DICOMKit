#if canImport(Network)

import Testing
import Foundation
@testable import DICOMNetwork

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

// MARK: - Test Tags

extension Tag {
    /// Tag for integration tests that require network access
    @Tag static var integration: Self
}

#endif  // canImport(Network)
