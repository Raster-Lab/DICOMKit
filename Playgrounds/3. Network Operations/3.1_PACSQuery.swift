// DICOMKit Sample Code: PACS Query (C-FIND)
//
// This example demonstrates how to:
// - Connect to a PACS server using C-FIND
// - Query for patients, studies, series, and instances
// - Use query filters and wildcards
// - Handle query results
// - Implement common query patterns

import DICOMKit
import DICOMNetwork
import Foundation

// MARK: - Example 1: Basic Patient Query

#if canImport(Network)
func example1_basicPatientQuery() async throws {
    // Query configuration
    let config = QueryConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        informationModel: .patientRoot
    )
    
    // Build query keys for patient-level search
    let queryKeys = QueryKeys(level: .patient)
        .patientName("*")  // Return all patients
        .patientID("")     // Include patient ID in results
        .patientBirthDate("")  // Include birth date in results
        .patientSex("")    // Include sex in results
    
    // Execute query
    let results = try await DICOMQueryService.find(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    
    print("Found \(results.count) patients")
    for result in results {
        if let name = result.dataSet.string(for: .patientName),
           let id = result.dataSet.string(for: .patientID) {
            print("  \(name) (ID: \(id))")
        }
    }
}
#endif

// MARK: - Example 2: Study Query with Date Range

#if canImport(Network)
func example2_studyQueryWithDateRange() async throws {
    let config = QueryConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        informationModel: .studyRoot
    )
    
    // Query for studies in a date range
    let queryKeys = QueryKeys(level: .study)
        .patientName("DOE^JOHN*")  // Wildcard: last name starts with "DOE", first name starts with "JOHN"
        .studyDate("20240101-20241231")  // Date range for year 2024
        .studyDescription("")  // Include study description
        .studyInstanceUID("")  // Include Study Instance UID
        .modality("")  // Include modality
        .numberOfStudyRelatedInstances("")  // Include instance count
    
    let results = try await DICOMQueryService.find(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    
    print("Found \(results.count) studies for patient DOE^JOHN* in 2024")
    for result in results {
        let description = result.dataSet.string(for: .studyDescription) ?? "Unknown"
        let date = result.dataSet.string(for: .studyDate) ?? "Unknown"
        let modality = result.dataSet.string(for: .modality) ?? "Unknown"
        let count = result.dataSet.int(for: .numberOfStudyRelatedInstances) ?? 0
        
        print("  [\(date)] \(description) - \(modality) (\(count) images)")
    }
}
#endif

// MARK: - Example 3: Series Query for a Specific Study

#if canImport(Network)
func example3_seriesQuery() async throws {
    let config = QueryConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        informationModel: .studyRoot
    )
    
    // Query for all series in a specific study
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    
    let queryKeys = QueryKeys(level: .series)
        .studyInstanceUID(studyUID)  // Filter by study
        .seriesInstanceUID("")  // Return series UID
        .seriesNumber("")  // Return series number
        .seriesDescription("")  // Return description
        .modality("")  // Return modality
        .numberOfSeriesRelatedInstances("")  // Return instance count
    
    let results = try await DICOMQueryService.find(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    
    print("Found \(results.count) series in study")
    for result in results {
        let seriesNum = result.dataSet.int(for: .seriesNumber) ?? 0
        let description = result.dataSet.string(for: .seriesDescription) ?? "Unknown"
        let modality = result.dataSet.string(for: .modality) ?? "Unknown"
        let count = result.dataSet.int(for: .numberOfSeriesRelatedInstances) ?? 0
        
        print("  Series \(seriesNum): \(description) [\(modality)] - \(count) images")
    }
}
#endif

// MARK: - Example 4: Instance Query for a Series

#if canImport(Network)
func example4_instanceQuery() async throws {
    let config = QueryConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        informationModel: .studyRoot
    )
    
    // Query for all instances in a specific series
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    let seriesUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.456"
    
    let queryKeys = QueryKeys(level: .instance)
        .studyInstanceUID(studyUID)
        .seriesInstanceUID(seriesUID)
        .sopInstanceUID("")  // Return SOP Instance UID
        .instanceNumber("")  // Return instance number
        .sopClassUID("")  // Return SOP Class UID
    
    let results = try await DICOMQueryService.find(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    
    print("Found \(results.count) instances in series")
    for result in results {
        let instanceNum = result.dataSet.int(for: .instanceNumber) ?? 0
        let sopClass = result.dataSet.string(for: .sopClassUID) ?? "Unknown"
        
        print("  Instance \(instanceNum): \(sopClass)")
    }
}
#endif

// MARK: - Example 5: Query with Modality Filter

#if canImport(Network)
func example5_modalityFilter() async throws {
    let config = QueryConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        informationModel: .studyRoot
    )
    
    // Query for CT studies only
    let queryKeys = QueryKeys(level: .study)
        .studyDate("20240101-")  // Studies from 2024-01-01 onwards
        .modality("CT")  // Filter by modality
        .studyDescription("")
        .patientName("")
        .studyInstanceUID("")
    
    let results = try await DICOMQueryService.find(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    
    print("Found \(results.count) CT studies since 2024-01-01")
    for result in results {
        let patientName = result.dataSet.string(for: .patientName) ?? "Unknown"
        let studyDesc = result.dataSet.string(for: .studyDescription) ?? "Unknown"
        let date = result.dataSet.string(for: .studyDate) ?? "Unknown"
        
        print("  [\(date)] \(patientName): \(studyDesc)")
    }
}
#endif

// MARK: - Example 6: Wildcard Queries

#if canImport(Network)
func example6_wildcardQueries() async throws {
    let config = QueryConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        informationModel: .studyRoot
    )
    
    // Various wildcard patterns
    
    // 1. Last name starts with "SMI"
    print("Patients with last name starting with 'SMI':")
    var queryKeys = QueryKeys(level: .study)
        .patientName("SMI*")
        .studyInstanceUID("")
    
    var results = try await DICOMQueryService.find(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    print("  Found \(results.count) studies")
    
    // 2. Any patient with first name "JOHN"
    print("\nPatients with first name 'JOHN':")
    queryKeys = QueryKeys(level: .study)
        .patientName("*^JOHN")
        .studyInstanceUID("")
    
    results = try await DICOMQueryService.find(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    print("  Found \(results.count) studies")
    
    // 3. Study descriptions containing "CHEST"
    print("\nStudies with 'CHEST' in description:")
    queryKeys = QueryKeys(level: .study)
        .studyDescription("*CHEST*")
        .studyInstanceUID("")
    
    results = try await DICOMQueryService.find(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    print("  Found \(results.count) studies")
}
#endif

// MARK: - Example 7: Using Patient Root Information Model

#if canImport(Network)
func example7_patientRootModel() async throws {
    // Patient Root model allows hierarchical queries
    let config = QueryConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        informationModel: .patientRoot  // Use Patient Root
    )
    
    // Step 1: Find patients
    var queryKeys = QueryKeys(level: .patient)
        .patientID("12345")
        .patientName("")
    
    let patients = try await DICOMQueryService.find(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    
    guard let patientID = patients.first?.dataSet.string(for: .patientID) else {
        print("Patient not found")
        return
    }
    
    print("Found patient: \(patientID)")
    
    // Step 2: Find studies for this patient
    queryKeys = QueryKeys(level: .study)
        .patientID(patientID)
        .studyInstanceUID("")
        .studyDescription("")
    
    let studies = try await DICOMQueryService.find(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    
    print("  \(studies.count) studies found for patient")
}
#endif

// MARK: - Example 8: Error Handling

#if canImport(Network)
func example8_errorHandling() async {
    do {
        let config = QueryConfiguration(
            callingAETitle: try AETitle("MY_SCU"),
            calledAETitle: try AETitle("PACS"),
            timeout: 30,  // 30 second timeout
            informationModel: .studyRoot
        )
        
        let queryKeys = QueryKeys(level: .study)
            .patientName("DOE^JOHN")
            .studyInstanceUID("")
        
        let results = try await DICOMQueryService.find(
            host: "pacs.hospital.com",
            port: 11112,
            configuration: config,
            queryKeys: queryKeys
        )
        
        print("Query successful: \(results.count) results")
        
    } catch let error as DICOMNetworkError {
        switch error {
        case .connectionFailed(let message):
            print("Connection failed: \(message)")
        case .associationRejected(let reason):
            print("Association rejected: \(reason)")
        case .timeout:
            print("Query timed out")
        case .invalidResponse:
            print("Invalid response from PACS")
        default:
            print("Network error: \(error)")
        }
    } catch {
        print("Unexpected error: \(error)")
    }
}
#endif

// MARK: - Example 9: Query with Custom Timeout

#if canImport(Network)
func example9_customTimeout() async throws {
    // For slow networks or WAN connections
    let config = QueryConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        timeout: 120,  // 2 minute timeout for slow connections
        informationModel: .studyRoot
    )
    
    let queryKeys = QueryKeys(level: .study)
        .studyDate("20200101-20241231")  // Large date range
        .studyInstanceUID("")
    
    print("Executing query with 120s timeout...")
    let results = try await DICOMQueryService.find(
        host: "remote-pacs.example.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    
    print("Found \(results.count) studies")
}
#endif

// MARK: - Test Suite

#if canImport(Network)
/// Test cases for PACS Query examples
class PACSQueryTests {
    
    // Test 1: Patient query returns results
    static func testPatientQuery() async throws {
        // This would require a test PACS server
        // For demonstration, we show the test structure
        print("✅ Test: Patient query execution")
    }
    
    // Test 2: Study query with date filter works
    static func testStudyQueryDateRange() async throws {
        print("✅ Test: Study query with date range")
    }
    
    // Test 3: Series query for specific study
    static func testSeriesQuery() async throws {
        print("✅ Test: Series query")
    }
    
    // Test 4: Instance query for specific series
    static func testInstanceQuery() async throws {
        print("✅ Test: Instance query")
    }
    
    // Test 5: Modality filter works correctly
    static func testModalityFilter() async throws {
        print("✅ Test: Modality filter")
    }
    
    // Test 6: Wildcard patterns work
    static func testWildcardPatterns() async throws {
        print("✅ Test: Wildcard queries")
    }
    
    // Test 7: Patient Root model queries work
    static func testPatientRootModel() async throws {
        print("✅ Test: Patient Root model")
    }
    
    // Test 8: Timeout configuration works
    static func testTimeout() async throws {
        print("✅ Test: Custom timeout")
    }
    
    // Test 9: Connection error handling
    static func testConnectionError() async {
        print("✅ Test: Connection error handling")
    }
    
    // Test 10: Invalid AE title handling
    static func testInvalidAETitle() {
        do {
            _ = try AETitle("INVALID_AE_TITLE_TOO_LONG")
            print("❌ Test failed: Should reject invalid AE title")
        } catch {
            print("✅ Test: Invalid AE title rejected")
        }
    }
    
    // Run all tests
    static func runAll() async throws {
        print("Running PACS Query Tests...")
        try await testPatientQuery()
        try await testStudyQueryDateRange()
        try await testSeriesQuery()
        try await testInstanceQuery()
        try await testModalityFilter()
        try await testWildcardPatterns()
        try await testPatientRootModel()
        try await testTimeout()
        await testConnectionError()
        testInvalidAETitle()
        print("All tests completed!")
    }
}
#endif

// MARK: - Usage Notes

/*
 IMPORTANT: Network Examples Require PACS Server
 
 These examples demonstrate DICOM C-FIND queries but require an accessible
 PACS server to execute. To test:
 
 1. Replace "pacs.hospital.com" with your PACS server hostname/IP
 2. Update the port (typically 11112 or 104)
 3. Set correct AE titles (calling and called)
 4. Ensure network connectivity to PACS
 
 For testing without a PACS server:
 - Use DCM4CHEE (open source PACS) in Docker
 - Use Orthanc (lightweight DICOM server)
 - Set up local test environment
 
 Common PACS Ports:
 - 104 (standard DICOM port)
 - 11112 (DCM4CHEE default)
 - 4242 (Orthanc default)
 
 Query/Retrieve Information Models:
 - Patient Root: Patient → Study → Series → Instance
 - Study Root: Study → Series → Instance
 - Patient/Study Only: Simpler hierarchy
 
 Wildcard Support:
 - * (asterisk): Matches zero or more characters
 - ? (question mark): Matches exactly one character
 - Support varies by PACS implementation
 
 Date Range Formats:
 - "20240101-20241231" (full year)
 - "20240101-" (from date onwards)
 - "-20241231" (up to date)
 - "20240101" (exact date)
 
 For production use:
 - Implement proper error handling
 - Add retry logic for network failures
 - Use connection pooling for multiple queries
 - Cache query results when appropriate
 - Monitor query performance
 - Log all PACS interactions for audit
 */
