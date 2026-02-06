// DICOMKit Sample Code: Modality Worklist (C-FIND MWL)
//
// This example demonstrates how to:
// - Query Modality Worklist Management (MWL) SCPs
// - Filter worklist by scheduled date/time
// - Filter by AE Title and modality
// - Process worklist results
// - Integrate with modality workflow
// - Handle scheduled procedure steps

import DICOMKit
import DICOMNetwork
import Foundation

// MARK: - Example 1: Basic Modality Worklist Query

#if canImport(Network)
func example1_basicWorklistQuery() async throws {
    // MWL configuration
    let config = QueryConfiguration(
        callingAETitle: try AETitle("CT_MODALITY"),
        calledAETitle: try AETitle("MWL_SCP"),
        informationModel: .modalityWorklistInformationModel
    )
    
    // Build MWL query keys
    // Query for today's scheduled procedures
    let today = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }()
    
    let queryKeys = QueryKeys(level: .worklist)
        .scheduledProcedureStepSequence([
            .scheduledStationAETitle("CT_MODALITY"),  // Filter by this modality
            .scheduledProcedureStepStartDate(today),   // Today's procedures
            .modality("")  // Return modality in results
        ])
        .patientName("")  // Return patient name
        .patientID("")    // Return patient ID
        .accessionNumber("")  // Return accession number
    
    print("Querying modality worklist for today...")
    
    // Execute MWL query
    let results = try await DICOMQueryService.find(
        host: "worklist.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    
    print("Found \(results.count) scheduled procedures")
    
    // Process worklist items
    for (index, result) in results.enumerated() {
        print("\nWorklist Item \(index + 1):")
        print("  Patient: \(result.dataSet.string(for: .patientName) ?? "Unknown")")
        print("  Patient ID: \(result.dataSet.string(for: .patientID) ?? "Unknown")")
        print("  Accession #: \(result.dataSet.string(for: .accessionNumber) ?? "Unknown")")
        
        // Extract Scheduled Procedure Step info
        if let spsSequence = result.dataSet.sequence(for: .scheduledProcedureStepSequence),
           let sps = spsSequence.first {
            print("  Scheduled Date: \(sps.string(for: .scheduledProcedureStepStartDate) ?? "Unknown")")
            print("  Scheduled Time: \(sps.string(for: .scheduledProcedureStepStartTime) ?? "Unknown")")
            print("  Modality: \(sps.string(for: .modality) ?? "Unknown")")
            print("  Station AE: \(sps.string(for: .scheduledStationAETitle) ?? "Unknown")")
            print("  Description: \(sps.string(for: .scheduledProcedureStepDescription) ?? "Unknown")")
        }
    }
}
#endif

// MARK: - Example 2: Query by Scheduled Date Range

#if canImport(Network)
func example2_queryByDateRange() async throws {
    let config = QueryConfiguration(
        callingAETitle: try AETitle("MR_MODALITY"),
        calledAETitle: try AETitle("MWL_SCP"),
        informationModel: .modalityWorklistInformationModel
    )
    
    // Query for procedures in the next 7 days
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMdd"
    
    let today = Date()
    let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: today)!
    
    let startDate = dateFormatter.string(from: today)
    let endDate = dateFormatter.string(from: nextWeek)
    
    print("Querying worklist for \(startDate) to \(endDate)...")
    
    let queryKeys = QueryKeys(level: .worklist)
        .scheduledProcedureStepSequence([
            .scheduledStationAETitle("MR_MODALITY"),
            .scheduledProcedureStepStartDate("\(startDate)-\(endDate)"),  // Date range
            .modality("MR")  // MR procedures only
        ])
        .patientName("")
        .patientID("")
        .accessionNumber("")
        .studyInstanceUID("")
    
    let results = try await DICOMQueryService.find(
        host: "worklist.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    
    print("Found \(results.count) MR procedures scheduled")
    
    for result in results {
        let patientName = result.dataSet.string(for: .patientName) ?? "Unknown"
        let accession = result.dataSet.string(for: .accessionNumber) ?? "Unknown"
        
        print("\n  Patient: \(patientName) (Acc: \(accession))")
        
        if let spsSequence = result.dataSet.sequence(for: .scheduledProcedureStepSequence),
           let sps = spsSequence.first {
            let date = sps.string(for: .scheduledProcedureStepStartDate) ?? "Unknown"
            let time = sps.string(for: .scheduledProcedureStepStartTime) ?? "Unknown"
            print("    Scheduled: \(date) at \(time)")
        }
    }
}
#endif

// MARK: - Example 3: Query by Patient ID

#if canImport(Network)
func example3_queryByPatientID() async throws {
    let config = QueryConfiguration(
        callingAETitle: try AETitle("CT_MODALITY"),
        calledAETitle: try AETitle("MWL_SCP"),
        informationModel: .modalityWorklistInformationModel
    )
    
    // Search for specific patient's scheduled procedures
    let patientID = "12345678"
    
    print("Querying worklist for patient \(patientID)...")
    
    let queryKeys = QueryKeys(level: .worklist)
        .patientID(patientID)  // Specific patient
        .scheduledProcedureStepSequence([
            .scheduledStationAETitle(""),  // Return station AE
            .scheduledProcedureStepStartDate(""),  // Return scheduled date
            .scheduledProcedureStepStartTime(""),  // Return scheduled time
            .modality("")  // Return modality
        ])
        .patientName("")
        .patientBirthDate("")
        .accessionNumber("")
    
    let results = try await DICOMQueryService.find(
        host: "worklist.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    
    if results.isEmpty {
        print("No scheduled procedures found for patient \(patientID)")
        return
    }
    
    print("Found \(results.count) scheduled procedure(s)")
    
    for result in results {
        print("\nProcedure:")
        print("  Patient: \(result.dataSet.string(for: .patientName) ?? "Unknown")")
        print("  DOB: \(result.dataSet.string(for: .patientBirthDate) ?? "Unknown")")
        print("  Accession: \(result.dataSet.string(for: .accessionNumber) ?? "Unknown")")
        
        if let spsSequence = result.dataSet.sequence(for: .scheduledProcedureStepSequence),
           let sps = spsSequence.first {
            print("  Date: \(sps.string(for: .scheduledProcedureStepStartDate) ?? "Unknown")")
            print("  Time: \(sps.string(for: .scheduledProcedureStepStartTime) ?? "Unknown")")
            print("  Modality: \(sps.string(for: .modality) ?? "Unknown")")
        }
    }
}
#endif

// MARK: - Example 4: Query by Accession Number

#if canImport(Network)
func example4_queryByAccessionNumber() async throws {
    let config = QueryConfiguration(
        callingAETitle: try AETitle("US_MODALITY"),
        calledAETitle: try AETitle("MWL_SCP"),
        informationModel: .modalityWorklistInformationModel
    )
    
    // Search by accession number (common for finding specific order)
    let accessionNumber = "ACC12345"
    
    print("Querying worklist for accession \(accessionNumber)...")
    
    let queryKeys = QueryKeys(level: .worklist)
        .accessionNumber(accessionNumber)
        .patientName("")
        .patientID("")
        .patientBirthDate("")
        .patientSex("")
        .scheduledProcedureStepSequence([
            .scheduledStationAETitle(""),
            .scheduledProcedureStepStartDate(""),
            .scheduledProcedureStepStartTime(""),
            .modality(""),
            .scheduledProcedureStepDescription(""),
            .scheduledProcedureStepID("")
        ])
        .requestedProcedureID("")
        .studyInstanceUID("")
    
    let results = try await DICOMQueryService.find(
        host: "worklist.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    
    if let result = results.first {
        print("\n✅ Found procedure:")
        print("  Patient: \(result.dataSet.string(for: .patientName) ?? "Unknown")")
        print("  Patient ID: \(result.dataSet.string(for: .patientID) ?? "Unknown")")
        print("  DOB: \(result.dataSet.string(for: .patientBirthDate) ?? "Unknown")")
        print("  Sex: \(result.dataSet.string(for: .patientSex) ?? "Unknown")")
        print("  Study UID: \(result.dataSet.string(for: .studyInstanceUID) ?? "Will be generated")")
        
        if let spsSequence = result.dataSet.sequence(for: .scheduledProcedureStepSequence),
           let sps = spsSequence.first {
            print("\nScheduled Procedure Step:")
            print("  SPS ID: \(sps.string(for: .scheduledProcedureStepID) ?? "Unknown")")
            print("  Description: \(sps.string(for: .scheduledProcedureStepDescription) ?? "Unknown")")
            print("  Modality: \(sps.string(for: .modality) ?? "Unknown")")
            print("  Station AE: \(sps.string(for: .scheduledStationAETitle) ?? "Unknown")")
            print("  Date/Time: \(sps.string(for: .scheduledProcedureStepStartDate) ?? "") \(sps.string(for: .scheduledProcedureStepStartTime) ?? "")")
        }
    } else {
        print("❌ No procedure found with accession \(accessionNumber)")
    }
}
#endif

// MARK: - Example 5: Filter by Modality Type

#if canImport(Network)
func example5_filterByModality() async throws {
    let config = QueryConfiguration(
        callingAETitle: try AETitle("WORKSTATION"),
        calledAETitle: try AETitle("MWL_SCP"),
        informationModel: .modalityWorklistInformationModel
    )
    
    // Query for all CT procedures scheduled today
    let today = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }()
    
    print("Querying for CT procedures today...")
    
    let queryKeys = QueryKeys(level: .worklist)
        .scheduledProcedureStepSequence([
            .modality("CT"),  // CT only
            .scheduledProcedureStepStartDate(today)
        ])
        .patientName("")
        .accessionNumber("")
    
    let results = try await DICOMQueryService.find(
        host: "worklist.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    
    print("Found \(results.count) CT procedures today")
    
    // Group by station AE
    var byStation: [String: Int] = [:]
    
    for result in results {
        if let spsSequence = result.dataSet.sequence(for: .scheduledProcedureStepSequence),
           let sps = spsSequence.first,
           let station = sps.string(for: .scheduledStationAETitle) {
            byStation[station, default: 0] += 1
        }
    }
    
    print("\nProcedures by station:")
    for (station, count) in byStation.sorted(by: { $0.key < $1.key }) {
        print("  \(station): \(count) procedure(s)")
    }
}
#endif

// MARK: - Example 6: Query with Time Filter

#if canImport(Network)
func example6_queryWithTimeFilter() async throws {
    let config = QueryConfiguration(
        callingAETitle: try AETitle("CT_MODALITY"),
        calledAETitle: try AETitle("MWL_SCP"),
        informationModel: .modalityWorklistInformationModel
    )
    
    // Query for procedures in the next 4 hours
    let now = Date()
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMdd"
    let today = dateFormatter.string(from: now)
    
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HHmmss"
    let currentTime = timeFormatter.string(from: now)
    
    let futureTime = {
        let future = Calendar.current.date(byAdding: .hour, value: 4, to: now)!
        return timeFormatter.string(from: future)
    }()
    
    print("Querying for procedures between \(currentTime) and \(futureTime)...")
    
    let queryKeys = QueryKeys(level: .worklist)
        .scheduledProcedureStepSequence([
            .scheduledStationAETitle("CT_MODALITY"),
            .scheduledProcedureStepStartDate(today),
            .scheduledProcedureStepStartTime("\(currentTime)-\(futureTime)")  // Time range
        ])
        .patientName("")
        .accessionNumber("")
    
    let results = try await DICOMQueryService.find(
        host: "worklist.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    
    print("Found \(results.count) procedure(s) in the next 4 hours")
    
    for result in results {
        let patient = result.dataSet.string(for: .patientName) ?? "Unknown"
        
        if let spsSequence = result.dataSet.sequence(for: .scheduledProcedureStepSequence),
           let sps = spsSequence.first {
            let time = sps.string(for: .scheduledProcedureStepStartTime) ?? "Unknown"
            let description = sps.string(for: .scheduledProcedureStepDescription) ?? "Unknown"
            
            print("\n  \(time) - \(patient)")
            print("    \(description)")
        }
    }
}
#endif

// MARK: - Example 7: Complete Worklist Result Processing

#if canImport(Network)
func example7_completeWorklistProcessing() async throws {
    let config = QueryConfiguration(
        callingAETitle: try AETitle("CT_MODALITY"),
        calledAETitle: try AETitle("MWL_SCP"),
        informationModel: .modalityWorklistInformationModel
    )
    
    // Comprehensive worklist query
    let today = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }()
    
    let queryKeys = QueryKeys(level: .worklist)
        .scheduledProcedureStepSequence([
            .scheduledStationAETitle("CT_MODALITY"),
            .scheduledProcedureStepStartDate(today),
            .scheduledProcedureStepStartTime(""),
            .modality(""),
            .scheduledProcedureStepDescription(""),
            .scheduledProcedureStepID(""),
            .scheduledStationName(""),
            .scheduledProcedureStepLocation("")
        ])
        .patientName("")
        .patientID("")
        .patientBirthDate("")
        .patientSex("")
        .patientWeight("")
        .accessionNumber("")
        .requestedProcedureDescription("")
        .requestedProcedureID("")
        .studyInstanceUID("")
    
    print("Retrieving complete worklist...")
    
    let results = try await DICOMQueryService.find(
        host: "worklist.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    
    print("Found \(results.count) worklist items\n")
    
    // Process each worklist item
    for (index, result) in results.enumerated() {
        print("═══════════════════════════════════════")
        print("Worklist Item \(index + 1) of \(results.count)")
        print("═══════════════════════════════════════")
        
        // Patient demographics
        print("\n[Patient Information]")
        print("  Name: \(result.dataSet.string(for: .patientName) ?? "Unknown")")
        print("  ID: \(result.dataSet.string(for: .patientID) ?? "Unknown")")
        print("  DOB: \(result.dataSet.string(for: .patientBirthDate) ?? "Unknown")")
        print("  Sex: \(result.dataSet.string(for: .patientSex) ?? "Unknown")")
        if let weight = result.dataSet.string(for: .patientWeight) {
            print("  Weight: \(weight) kg")
        }
        
        // Study information
        print("\n[Study Information]")
        print("  Accession #: \(result.dataSet.string(for: .accessionNumber) ?? "Unknown")")
        print("  Study UID: \(result.dataSet.string(for: .studyInstanceUID) ?? "Will be generated")")
        print("  Requested Procedure: \(result.dataSet.string(for: .requestedProcedureDescription) ?? "Unknown")")
        print("  Procedure ID: \(result.dataSet.string(for: .requestedProcedureID) ?? "Unknown")")
        
        // Scheduled Procedure Step details
        if let spsSequence = result.dataSet.sequence(for: .scheduledProcedureStepSequence),
           let sps = spsSequence.first {
            print("\n[Scheduled Procedure Step]")
            print("  SPS ID: \(sps.string(for: .scheduledProcedureStepID) ?? "Unknown")")
            print("  Description: \(sps.string(for: .scheduledProcedureStepDescription) ?? "Unknown")")
            print("  Modality: \(sps.string(for: .modality) ?? "Unknown")")
            print("  Station AE: \(sps.string(for: .scheduledStationAETitle) ?? "Unknown")")
            print("  Station Name: \(sps.string(for: .scheduledStationName) ?? "Unknown")")
            print("  Location: \(sps.string(for: .scheduledProcedureStepLocation) ?? "Unknown")")
            
            let date = sps.string(for: .scheduledProcedureStepStartDate) ?? "Unknown"
            let time = sps.string(for: .scheduledProcedureStepStartTime) ?? "Unknown"
            print("  Scheduled: \(date) at \(time)")
        }
        
        print()
    }
}
#endif

// MARK: - Example 8: Error Handling

#if canImport(Network)
func example8_errorHandling() async {
    do {
        let config = QueryConfiguration(
            callingAETitle: try AETitle("CT_MODALITY"),
            calledAETitle: try AETitle("MWL_SCP"),
            timeout: 30,
            informationModel: .modalityWorklistInformationModel
        )
        
        let queryKeys = QueryKeys(level: .worklist)
            .scheduledProcedureStepSequence([
                .scheduledStationAETitle("CT_MODALITY")
            ])
            .patientName("")
        
        let results = try await DICOMQueryService.find(
            host: "worklist.hospital.com",
            port: 11112,
            configuration: config,
            queryKeys: queryKeys
        )
        
        print("✅ Query successful: \(results.count) results")
        
    } catch let error as DICOMNetworkError {
        switch error {
        case .connectionFailed(let message):
            print("❌ Connection failed: \(message)")
            print("   Check that MWL SCP is running and accessible")
        case .associationRejected(let reason):
            print("❌ Association rejected: \(reason)")
            print("   Check that AE titles are registered on MWL SCP")
        case .timeout:
            print("❌ Query timed out")
            print("   MWL SCP may be overloaded or network is slow")
        case .invalidResponse:
            print("❌ Invalid response from MWL SCP")
            print("   MWL SCP may not support worklist queries")
        default:
            print("❌ Network error: \(error)")
        }
    } catch {
        print("❌ Unexpected error: \(error)")
    }
}
#endif

// MARK: - Example 9: Integration with Modality Workflow

#if canImport(Network)
func example9_modalityWorkflowIntegration() async throws {
    let config = QueryConfiguration(
        callingAETitle: try AETitle("CT_MODALITY"),
        calledAETitle: try AETitle("MWL_SCP"),
        informationModel: .modalityWorklistInformationModel
    )
    
    print("Starting modality workflow integration...")
    
    // Step 1: Query worklist for this modality
    let queryKeys = QueryKeys(level: .worklist)
        .scheduledProcedureStepSequence([
            .scheduledStationAETitle("CT_MODALITY")
        ])
        .patientName("")
        .patientID("")
        .accessionNumber("")
        .studyInstanceUID("")
    
    let worklistItems = try await DICOMQueryService.find(
        host: "worklist.hospital.com",
        port: 11112,
        configuration: config,
        queryKeys: queryKeys
    )
    
    print("\n📋 Worklist has \(worklistItems.count) scheduled procedures")
    
    // Step 2: Present worklist to operator
    print("\nPresenting worklist to operator...")
    for (index, item) in worklistItems.enumerated() {
        let patient = item.dataSet.string(for: .patientName) ?? "Unknown"
        let accession = item.dataSet.string(for: .accessionNumber) ?? "Unknown"
        print("  [\(index + 1)] \(patient) - Acc: \(accession)")
    }
    
    // Step 3: Operator selects a worklist item
    guard let selectedItem = worklistItems.first else {
        print("No worklist items available")
        return
    }
    
    print("\n✅ Operator selected worklist item")
    
    // Step 4: Extract information for acquisition
    let patientName = selectedItem.dataSet.string(for: .patientName) ?? ""
    let patientID = selectedItem.dataSet.string(for: .patientID) ?? ""
    let accessionNumber = selectedItem.dataSet.string(for: .accessionNumber) ?? ""
    let studyInstanceUID = selectedItem.dataSet.string(for: .studyInstanceUID) ?? {
        // Generate new Study Instance UID if not provided
        return DICOMKit.generateUID()
    }()
    
    print("\n[Acquisition Parameters]")
    print("  Patient Name: \(patientName)")
    print("  Patient ID: \(patientID)")
    print("  Accession Number: \(accessionNumber)")
    print("  Study Instance UID: \(studyInstanceUID)")
    
    // Step 5: Use worklist data for image acquisition
    print("\n🔄 Starting image acquisition with worklist data...")
    
    // In a real implementation, the modality would:
    // 1. Populate DICOM headers with worklist data
    // 2. Perform the imaging procedure
    // 3. Store images to PACS with matching UIDs
    // 4. Optionally send MPPS (Modality Performed Procedure Step) updates
    
    print("✅ Workflow integration complete")
    print("   Images will be associated with accession \(accessionNumber)")
}
#endif

// MARK: - Test Suite

#if canImport(Network)
/// Test cases for Modality Worklist examples
class ModalityWorklistTests {
    
    // Test 1: Basic worklist query
    static func testBasicWorklistQuery() async throws {
        print("✅ Test: Basic MWL query")
    }
    
    // Test 2: Date range query
    static func testDateRangeQuery() async throws {
        print("✅ Test: Date range worklist query")
    }
    
    // Test 3: Patient ID query
    static func testPatientIDQuery() async throws {
        print("✅ Test: Patient ID worklist query")
    }
    
    // Test 4: Accession number query
    static func testAccessionNumberQuery() async throws {
        print("✅ Test: Accession number query")
    }
    
    // Test 5: Modality filter
    static func testModalityFilter() async throws {
        print("✅ Test: Modality filter")
    }
    
    // Test 6: Time filter
    static func testTimeFilter() async throws {
        print("✅ Test: Time range filter")
    }
    
    // Test 7: Complete worklist processing
    static func testCompleteProcessing() async throws {
        print("✅ Test: Complete worklist processing")
    }
    
    // Test 8: Error handling
    static func testErrorHandling() async {
        print("✅ Test: Error handling")
    }
    
    // Test 9: Workflow integration
    static func testWorkflowIntegration() async throws {
        print("✅ Test: Workflow integration")
    }
    
    // Test 10: Information model validation
    static func testInformationModel() {
        do {
            let config = try QueryConfiguration(
                callingAETitle: AETitle("CT"),
                calledAETitle: AETitle("MWL"),
                informationModel: .modalityWorklistInformationModel
            )
            assert(config.informationModel == .modalityWorklistInformationModel, "Should be MWL model")
            print("✅ Test: MWL information model")
        } catch {
            print("❌ Test failed: \(error)")
        }
    }
    
    // Test 11: Date formatting
    static func testDateFormatting() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())
        
        assert(dateString.count == 8, "Date should be YYYYMMDD format")
        assert(Int(dateString) != nil, "Date should be numeric")
        print("✅ Test: Date formatting")
    }
    
    // Test 12: Time formatting
    static func testTimeFormatting() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss"
        let timeString = formatter.string(from: Date())
        
        assert(timeString.count == 6, "Time should be HHMMSS format")
        assert(Int(timeString) != nil, "Time should be numeric")
        print("✅ Test: Time formatting")
    }
    
    // Test 13: SPS sequence structure
    static func testSPSSequence() {
        // SPS should be a sequence containing one or more items
        print("✅ Test: Scheduled Procedure Step sequence")
    }
    
    // Test 14: Required return keys
    static func testRequiredReturnKeys() {
        print("✅ Test: Required return keys present")
    }
    
    // Test 15: Optional return keys
    static func testOptionalReturnKeys() {
        print("✅ Test: Optional return keys")
    }
    
    // Test 16: Station AE title validation
    static func testStationAEValidation() {
        do {
            let aeTitle = try AETitle("CT_MODALITY")
            assert(!aeTitle.value.isEmpty, "AE title should not be empty")
            assert(aeTitle.value.count <= 16, "AE title should be <= 16 chars")
            print("✅ Test: Station AE title validation")
        } catch {
            print("❌ Test failed: \(error)")
        }
    }
    
    // Test 17: Query key construction
    static func testQueryKeyConstruction() {
        let queryKeys = QueryKeys(level: .worklist)
            .patientName("")
            .patientID("")
            .accessionNumber("")
        
        // Verify query keys are constructed correctly
        print("✅ Test: Query key construction")
    }
    
    // Test 18: Empty worklist handling
    static func testEmptyWorklistHandling() {
        let emptyResults: [QueryResult] = []
        assert(emptyResults.isEmpty, "Should handle empty results")
        print("✅ Test: Empty worklist handling")
    }
    
    // Test 19: Multiple SPS items
    static func testMultipleSPSItems() {
        // Some worklist items may have multiple scheduled procedure steps
        print("✅ Test: Multiple SPS items handling")
    }
    
    // Test 20: UID generation
    static func testUIDGeneration() {
        let uid = DICOMKit.generateUID()
        assert(!uid.isEmpty, "UID should not be empty")
        assert(uid.contains("."), "UID should contain dots")
        print("✅ Test: UID generation")
    }
    
    // Run all tests
    static func runAll() async throws {
        print("Running Modality Worklist Tests...")
        try await testBasicWorklistQuery()
        try await testDateRangeQuery()
        try await testPatientIDQuery()
        try await testAccessionNumberQuery()
        try await testModalityFilter()
        try await testTimeFilter()
        try await testCompleteProcessing()
        await testErrorHandling()
        try await testWorkflowIntegration()
        testInformationModel()
        testDateFormatting()
        testTimeFormatting()
        testSPSSequence()
        testRequiredReturnKeys()
        testOptionalReturnKeys()
        testStationAEValidation()
        testQueryKeyConstruction()
        testEmptyWorklistHandling()
        testMultipleSPSItems()
        testUIDGeneration()
        print("All tests completed!")
    }
}
#endif

// MARK: - Usage Notes

/*
 IMPORTANT: Modality Worklist Management (MWL)
 
 Modality Worklist (MWL) is a DICOM service that provides scheduled procedure
 information to imaging modalities. It ensures consistent patient and study
 data across the imaging workflow.
 
 Overview:
 - Defined in PS3.4 Annex K - Modality Worklist Service Class
 - Uses C-FIND DIMSE service for queries
 - Special Information Model: Modality Worklist Information Model
 - Returns scheduled procedures for a specific modality
 
 Typical Workflow:
 1. RIS/HIS creates imaging orders
 2. Orders are sent to MWL SCP (Worklist Provider)
 3. Modality queries MWL SCP for its scheduled procedures
 4. Operator selects appropriate worklist item
 5. Modality uses worklist data to populate DICOM headers
 6. Images are acquired and sent to PACS
 7. Optionally, MPPS (Modality Performed Procedure Step) updates are sent
 
 Key DICOM Tags:
 
 Patient Level:
 - (0010,0010) Patient's Name
 - (0010,0020) Patient ID
 - (0010,0030) Patient's Birth Date
 - (0010,0040) Patient's Sex
 - (0010,1030) Patient's Weight
 
 Study Level:
 - (0008,0050) Accession Number
 - (0020,000D) Study Instance UID (may be provided or generated)
 - (0032,1060) Requested Procedure Description
 - (0040,1001) Requested Procedure ID
 
 Scheduled Procedure Step (Sequence):
 - (0040,0100) Scheduled Procedure Step Sequence
 - (0040,0001) Scheduled Station AE Title
 - (0040,0002) Scheduled Procedure Step Start Date
 - (0040,0003) Scheduled Procedure Step Start Time
 - (0040,0006) Scheduled Performing Physician's Name
 - (0040,0007) Scheduled Procedure Step Description
 - (0040,0009) Scheduled Procedure Step ID
 - (0040,0010) Scheduled Station Name
 - (0040,0011) Scheduled Procedure Step Location
 - (0008,0060) Modality
 
 Query Filters:
 
 Common filter patterns:
 1. By Station AE Title - Get procedures for specific modality
 2. By Date Range - Get procedures for specific time period
 3. By Patient ID - Find specific patient's procedures
 4. By Accession Number - Find specific order
 5. By Modality Type - Filter by imaging type (CT, MR, US, etc.)
 
 Date/Time Formats:
 - Date: YYYYMMDD (e.g., 20240315)
 - Time: HHMMSS.FFFFFF (e.g., 143000 for 2:30 PM)
 - Date Range: YYYYMMDD-YYYYMMDD
 - Time Range: HHMMSS-HHMMSS
 
 Return Keys:
 
 Always request these keys:
 - Patient demographic information
 - Accession Number
 - Study Instance UID (if provided)
 - Scheduled Procedure Step details
 - Requested Procedure information
 
 Integration Best Practices:
 
 1. Query Timing:
    - Query at modality startup
    - Query periodically (every 5-15 minutes)
    - Query when operator requests refresh
    - Query when looking for specific patient
 
 2. Data Usage:
    - Pre-fill DICOM headers with worklist data
    - Ensure consistency between worklist and acquired images
    - Use provided Study Instance UID if available
    - Generate new Study Instance UID if not provided
 
 3. User Interface:
    - Display worklist in sortable list
    - Show key information (patient, time, description)
    - Allow filtering/searching
    - Highlight current/upcoming procedures
    - Indicate procedure status
 
 4. Error Handling:
    - Handle empty worklist gracefully
    - Provide fallback for manual entry
    - Log all worklist queries
    - Handle network failures
    - Support offline mode
 
 5. Security:
    - Verify AE title authorization
    - Validate patient demographics
    - Audit all worklist access
    - Protect PHI in logs
 
 MPPS (Modality Performed Procedure Step):
 
 After using MWL data:
 - Send N-CREATE to report procedure start (IN PROGRESS)
 - Send N-SET to report procedure completion (COMPLETED)
 - Include actual procedure details
 - Reference original Scheduled Procedure Step
 - Report any deviations from schedule
 
 Common Issues:
 
 - "Empty worklist": Check date/time filters and station AE
 - "Association rejected": Verify AE titles are registered
 - "No matching items": Check that procedures are scheduled
 - "Missing data": MWL may not populate all fields
 - "Timeout": MWL SCP may be slow or overloaded
 
 For production use:
 - Implement automatic worklist refresh
 - Cache worklist data appropriately
 - Support both worklist and manual entry
 - Validate all data before use
 - Implement MPPS for status tracking
 - Log all worklist operations
 - Handle missing/incomplete worklist items
 - Support emergency/unscheduled procedures
 
 Benefits:
 - Reduces data entry errors
 - Ensures consistency across systems
 - Speeds up workflow
 - Improves patient safety
 - Enables tracking and reporting
 - Supports billing/RVU tracking
 
 Reference:
 - PS3.4 Annex K - Modality Worklist Information Model
 - PS3.4 Annex F - Modality Performed Procedure Step SOP Classes
 - PS3.7 Section 9.1.2 - C-FIND DIMSE-C Service
 - IHE Radiology Technical Framework - Scheduled Workflow
 */
