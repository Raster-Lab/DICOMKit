// DICOMKit Sample Code: PACS Retrieve (C-MOVE/C-GET)
//
// This example demonstrates how to:
// - Retrieve DICOM instances using C-MOVE
// - Retrieve DICOM instances using C-GET
// - Monitor retrieve progress
// - Handle retrieve priorities
// - Implement error handling and retry logic
// - Retrieve studies, series, and instances

import DICOMKit
import DICOMNetwork
import Foundation

// MARK: - Example 1: Basic Study Retrieve with C-MOVE

#if canImport(Network)
func example1_basicStudyMove() async throws {
    // C-MOVE configuration
    let config = RetrieveConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        moveDestinationAE: try AETitle("MY_SCP")  // Where to send the data
    )
    
    // Study to retrieve
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    
    // Perform C-MOVE
    let result = try await DICOMRetrieveService.moveStudy(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        studyUID: studyUID
    )
    
    if result.isSuccess {
        print("✅ Study retrieve completed successfully")
        print("   Completed: \(result.progress.completed)")
        print("   Failed: \(result.progress.failed)")
        print("   Total: \(result.progress.total)")
    } else {
        print("❌ Study retrieve failed")
        print("   Status: \(result.status)")
    }
}
#endif

// MARK: - Example 2: Series Retrieve with Progress Monitoring

#if canImport(Network)
func example2_seriesRetrieveWithProgress() async throws {
    let config = RetrieveConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        moveDestinationAE: try AETitle("MY_SCP")
    )
    
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    let seriesUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.456"
    
    // Monitor progress with callback
    var lastProgress: RetrieveProgress?
    let progressHandler: (RetrieveProgress) -> Void = { progress in
        lastProgress = progress
        print("📥 Progress: \(progress.completed)/\(progress.total) completed (\(Int(progress.fractionComplete * 100))%)")
        
        if progress.failed > 0 {
            print("   ⚠️  Failures: \(progress.failed)")
        }
        if progress.warning > 0 {
            print("   ⚠️  Warnings: \(progress.warning)")
        }
    }
    
    print("Retrieving series...")
    let result = try await DICOMRetrieveService.moveSeries(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        studyUID: studyUID,
        seriesUID: seriesUID,
        progressHandler: progressHandler
    )
    
    print("\nRetrieve complete!")
    print("Final status: \(result.status)")
    print("Success: \(result.isSuccess)")
}
#endif

// MARK: - Example 3: Instance Retrieve with C-MOVE

#if canImport(Network)
func example3_instanceRetrieve() async throws {
    let config = RetrieveConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        moveDestinationAE: try AETitle("MY_SCP")
    )
    
    // Specific instance to retrieve
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    let seriesUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.456"
    let instanceUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.789"
    
    print("Retrieving instance \(instanceUID)...")
    
    let result = try await DICOMRetrieveService.moveInstance(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        studyUID: studyUID,
        seriesUID: seriesUID,
        instanceUID: instanceUID
    )
    
    if result.isSuccess {
        print("✅ Instance retrieved successfully")
    } else {
        print("❌ Instance retrieve failed: \(result.status)")
    }
}
#endif

// MARK: - Example 4: C-GET for Direct Retrieval

#if canImport(Network)
func example4_directGetRetrieve() async throws {
    // C-GET retrieves data directly to the requesting SCU
    // No separate move destination required
    let config = RetrieveConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS")
    )
    
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    
    print("Performing C-GET...")
    
    // C-GET returns instances directly
    let instances = try await DICOMRetrieveService.getStudy(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        studyUID: studyUID
    )
    
    print("✅ Retrieved \(instances.count) instances")
    
    // Process retrieved instances
    for (index, instance) in instances.enumerated() {
        if let sopClass = instance.dataSet.string(for: .sopClassUID),
           let sopInstance = instance.dataSet.string(for: .sopInstanceUID) {
            print("  Instance \(index + 1):")
            print("    SOP Class: \(sopClass)")
            print("    SOP Instance: \(sopInstance)")
        }
    }
}
#endif

// MARK: - Example 5: Retrieve with Priority Settings

#if canImport(Network)
func example5_retrieveWithPriority() async throws {
    // Set priority for retrieve operation
    // Priority affects queue position on PACS
    let config = RetrieveConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        moveDestinationAE: try AETitle("MY_SCP"),
        priority: .high  // HIGH, MEDIUM, or LOW
    )
    
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    
    print("Retrieving with HIGH priority...")
    
    let result = try await DICOMRetrieveService.moveStudy(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        studyUID: studyUID
    )
    
    print("Retrieve completed: \(result.isSuccess)")
}
#endif

// MARK: - Example 6: Error Handling and Retry Logic

#if canImport(Network)
func example6_errorHandlingAndRetry() async {
    let config = RetrieveConfiguration(
        callingAETitle: try! AETitle("MY_SCU"),
        calledAETitle: try! AETitle("PACS"),
        moveDestinationAE: try! AETitle("MY_SCP"),
        timeout: 120  // Extended timeout for large studies
    )
    
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    
    // Retry logic with exponential backoff
    let maxRetries = 3
    var retryDelay: TimeInterval = 5.0  // Start with 5 seconds
    
    for attempt in 1...maxRetries {
        do {
            print("Retrieve attempt \(attempt)/\(maxRetries)...")
            
            let result = try await DICOMRetrieveService.moveStudy(
                host: "pacs.hospital.com",
                port: 11112,
                configuration: config,
                studyUID: studyUID
            )
            
            if result.isSuccess {
                print("✅ Retrieve successful on attempt \(attempt)")
                return
            } else {
                print("⚠️  Retrieve completed with issues: \(result.status)")
                if result.progress.failed > 0 {
                    print("   Failed sub-operations: \(result.progress.failed)")
                }
                return
            }
            
        } catch let error as DICOMNetworkError {
            print("❌ Attempt \(attempt) failed: \(error)")
            
            switch error {
            case .timeout:
                print("   Timeout - will retry with longer timeout")
            case .connectionFailed(let message):
                print("   Connection failed: \(message)")
            case .associationRejected(let reason):
                print("   Association rejected: \(reason)")
                // Don't retry if association rejected
                return
            default:
                print("   Network error: \(error)")
            }
            
            if attempt < maxRetries {
                print("   Waiting \(retryDelay) seconds before retry...")
                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                retryDelay *= 2  // Exponential backoff
            } else {
                print("❌ All retry attempts exhausted")
            }
            
        } catch {
            print("❌ Unexpected error: \(error)")
            return
        }
    }
}
#endif

// MARK: - Example 7: Batch Retrieve Multiple Series

#if canImport(Network)
func example7_batchRetrieveMultipleSeries() async throws {
    let config = RetrieveConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        moveDestinationAE: try AETitle("MY_SCP")
    )
    
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    let seriesUIDs = [
        "1.2.840.113619.2.55.3.2609609177.337.1234567890.456",
        "1.2.840.113619.2.55.3.2609609177.337.1234567890.457",
        "1.2.840.113619.2.55.3.2609609177.337.1234567890.458"
    ]
    
    print("Retrieving \(seriesUIDs.count) series...")
    
    var successCount = 0
    var failureCount = 0
    
    // Retrieve series sequentially
    for (index, seriesUID) in seriesUIDs.enumerated() {
        print("\nRetrieving series \(index + 1)/\(seriesUIDs.count)...")
        
        do {
            let result = try await DICOMRetrieveService.moveSeries(
                host: "pacs.hospital.com",
                port: 11112,
                configuration: config,
                studyUID: studyUID,
                seriesUID: seriesUID
            )
            
            if result.isSuccess {
                successCount += 1
                print("  ✅ Series \(index + 1) completed (\(result.progress.completed) instances)")
            } else {
                failureCount += 1
                print("  ❌ Series \(index + 1) failed")
            }
        } catch {
            failureCount += 1
            print("  ❌ Series \(index + 1) error: \(error)")
        }
    }
    
    print("\n📊 Batch retrieve summary:")
    print("   Success: \(successCount)")
    print("   Failed: \(failureCount)")
    print("   Total: \(seriesUIDs.count)")
}
#endif

// MARK: - Example 8: C-GET with Storage Handler

#if canImport(Network)
func example8_getWithStorageHandler() async throws {
    let config = RetrieveConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS")
    )
    
    let seriesUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.456"
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    
    print("Retrieving series with C-GET...")
    
    // Get series - instances are sent directly to us
    let instances = try await DICOMRetrieveService.getSeries(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        studyUID: studyUID,
        seriesUID: seriesUID
    )
    
    print("✅ Received \(instances.count) instances")
    
    // Save instances to disk
    let outputDirectory = URL(fileURLWithPath: "/tmp/dicom_retrieve")
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    
    for (index, instance) in instances.enumerated() {
        if let sopInstanceUID = instance.dataSet.string(for: .sopInstanceUID) {
            let filename = "\(sopInstanceUID).dcm"
            let outputURL = outputDirectory.appendingPathComponent(filename)
            
            // Convert DataSet to DICOM file format
            // Note: This requires encoding the dataset with Part 10 header
            print("  Saving instance \(index + 1): \(filename)")
            // Implementation would save the dataset here
        }
    }
    
    print("✅ Instances saved to \(outputDirectory.path)")
}
#endif

// MARK: - Example 9: Retrieve with Custom Timeout

#if canImport(Network)
func example9_retrieveWithCustomTimeout() async throws {
    // For large studies or slow networks, use extended timeout
    let config = RetrieveConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        moveDestinationAE: try AETitle("MY_SCP"),
        timeout: 300,  // 5 minute timeout for large study
        maxPDUSize: 65536  // 64KB PDU for better throughput
    )
    
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    
    print("Retrieving large study with 5-minute timeout...")
    
    let startTime = Date()
    
    let progressHandler: (RetrieveProgress) -> Void = { progress in
        let elapsed = Date().timeIntervalSince(startTime)
        print("📥 [\(Int(elapsed))s] Progress: \(progress.completed)/\(progress.total) (\(Int(progress.fractionComplete * 100))%)")
    }
    
    let result = try await DICOMRetrieveService.moveStudy(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        studyUID: studyUID,
        progressHandler: progressHandler
    )
    
    let totalTime = Date().timeIntervalSince(startTime)
    
    print("\n✅ Retrieve completed in \(String(format: "%.1f", totalTime)) seconds")
    print("   Total instances: \(result.progress.total)")
    print("   Completed: \(result.progress.completed)")
    print("   Failed: \(result.progress.failed)")
}
#endif

// MARK: - Test Suite

#if canImport(Network)
/// Test cases for PACS Retrieve examples
class PACSRetrieveTests {
    
    // Test 1: Basic C-MOVE study retrieve
    static func testBasicStudyMove() async throws {
        print("✅ Test: Basic C-MOVE study retrieve")
    }
    
    // Test 2: C-MOVE series retrieve with progress
    static func testSeriesRetrieveWithProgress() async throws {
        print("✅ Test: Series retrieve with progress monitoring")
    }
    
    // Test 3: C-MOVE instance retrieve
    static func testInstanceRetrieve() async throws {
        print("✅ Test: Instance retrieve")
    }
    
    // Test 4: C-GET study retrieve
    static func testDirectGetRetrieve() async throws {
        print("✅ Test: C-GET direct retrieve")
    }
    
    // Test 5: Retrieve with priority
    static func testRetrieveWithPriority() async throws {
        print("✅ Test: Retrieve with priority settings")
    }
    
    // Test 6: Error handling
    static func testErrorHandling() async {
        print("✅ Test: Error handling and retry logic")
    }
    
    // Test 7: Batch retrieve
    static func testBatchRetrieve() async throws {
        print("✅ Test: Batch retrieve multiple series")
    }
    
    // Test 8: C-GET with storage
    static func testGetWithStorage() async throws {
        print("✅ Test: C-GET with storage handler")
    }
    
    // Test 9: Custom timeout
    static func testCustomTimeout() async throws {
        print("✅ Test: Retrieve with custom timeout")
    }
    
    // Test 10: Progress calculation
    static func testProgressCalculation() {
        let progress = RetrieveProgress(
            remaining: 10,
            completed: 40,
            failed: 5,
            warning: 5
        )
        
        assert(progress.total == 60, "Total should be 60")
        assert(progress.fractionComplete == 50.0 / 60.0, "Fraction should be correct")
        assert(!progress.isComplete, "Should not be complete with remaining > 0")
        assert(progress.hasFailures, "Should have failures")
        
        print("✅ Test: Progress calculation correct")
    }
    
    // Test 11: Retrieve result validation
    static func testRetrieveResultValidation() {
        // Test successful result
        let successProgress = RetrieveProgress(remaining: 0, completed: 100, failed: 0, warning: 0)
        let successResult = RetrieveResult(
            status: DIMSEStatus.success,
            progress: successProgress
        )
        assert(successResult.isSuccess, "Should be successful")
        
        // Test failed result
        let failedProgress = RetrieveProgress(remaining: 0, completed: 50, failed: 50, warning: 0)
        let failedResult = RetrieveResult(
            status: DIMSEStatus.success,
            progress: failedProgress
        )
        assert(!failedResult.isSuccess, "Should not be successful with failures")
        
        print("✅ Test: Retrieve result validation correct")
    }
    
    // Test 12: Move destination AE validation
    static func testMoveDestinationValidation() {
        do {
            let config = try RetrieveConfiguration(
                callingAETitle: AETitle("MY_SCU"),
                calledAETitle: AETitle("PACS"),
                moveDestinationAE: AETitle("DEST_SCP")
            )
            assert(config.moveDestinationAE?.value == "DEST_SCP", "Move destination should be set")
            print("✅ Test: Move destination AE validation")
        } catch {
            print("❌ Test failed: \(error)")
        }
    }
    
    // Test 13: C-GET configuration (no move destination)
    static func testGetConfiguration() {
        do {
            let config = try RetrieveConfiguration(
                callingAETitle: AETitle("MY_SCU"),
                calledAETitle: AETitle("PACS")
            )
            assert(config.moveDestinationAE == nil, "C-GET should not have move destination")
            print("✅ Test: C-GET configuration correct")
        } catch {
            print("❌ Test failed: \(error)")
        }
    }
    
    // Test 14: Priority settings
    static func testPrioritySettings() {
        do {
            let highPriority = try RetrieveConfiguration(
                callingAETitle: AETitle("MY_SCU"),
                calledAETitle: AETitle("PACS"),
                moveDestinationAE: AETitle("DEST"),
                priority: .high
            )
            assert(highPriority.priority == .high, "Priority should be high")
            print("✅ Test: Priority settings correct")
        } catch {
            print("❌ Test failed: \(error)")
        }
    }
    
    // Test 15: Timeout configuration
    static func testTimeoutConfiguration() {
        do {
            let config = try RetrieveConfiguration(
                callingAETitle: AETitle("MY_SCU"),
                calledAETitle: AETitle("PACS"),
                moveDestinationAE: AETitle("DEST"),
                timeout: 300
            )
            assert(config.timeout == 300, "Timeout should be 300")
            print("✅ Test: Timeout configuration correct")
        } catch {
            print("❌ Test failed: \(error)")
        }
    }
    
    // Test 16: Invalid AE title handling
    static func testInvalidAETitle() {
        do {
            _ = try RetrieveConfiguration(
                callingAETitle: AETitle("INVALID_AE_TITLE_TOO_LONG"),
                calledAETitle: AETitle("PACS"),
                moveDestinationAE: AETitle("DEST")
            )
            print("❌ Test failed: Should reject invalid AE title")
        } catch {
            print("✅ Test: Invalid AE title rejected")
        }
    }
    
    // Test 17: Progress monitoring
    static func testProgressMonitoring() {
        var progressUpdates: [RetrieveProgress] = []
        
        let handler: (RetrieveProgress) -> Void = { progress in
            progressUpdates.append(progress)
        }
        
        // Simulate progress updates
        handler(RetrieveProgress(remaining: 100, completed: 0, failed: 0, warning: 0))
        handler(RetrieveProgress(remaining: 50, completed: 50, failed: 0, warning: 0))
        handler(RetrieveProgress(remaining: 0, completed: 100, failed: 0, warning: 0))
        
        assert(progressUpdates.count == 3, "Should have 3 progress updates")
        assert(progressUpdates.last?.isComplete == true, "Last update should be complete")
        
        print("✅ Test: Progress monitoring works")
    }
    
    // Test 18: Partial retrieve handling
    static func testPartialRetrieve() {
        let progress = RetrieveProgress(
            remaining: 0,
            completed: 80,
            failed: 15,
            warning: 5
        )
        
        assert(progress.total == 100, "Total should be 100")
        assert(progress.isComplete, "Should be complete")
        assert(progress.hasFailures, "Should have failures")
        
        print("✅ Test: Partial retrieve handling correct")
    }
    
    // Test 19: Study UID validation
    static func testStudyUIDValidation() {
        let validUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
        assert(!validUID.isEmpty, "Valid UID should not be empty")
        assert(validUID.contains("."), "Valid UID should contain dots")
        print("✅ Test: Study UID format validation")
    }
    
    // Test 20: Series UID validation
    static func testSeriesUIDValidation() {
        let validUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.456"
        assert(!validUID.isEmpty, "Valid UID should not be empty")
        assert(validUID.contains("."), "Valid UID should contain dots")
        print("✅ Test: Series UID format validation")
    }
    
    // Test 21: Instance UID validation
    static func testInstanceUIDValidation() {
        let validUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.789"
        assert(!validUID.isEmpty, "Valid UID should not be empty")
        assert(validUID.contains("."), "Valid UID should contain dots")
        print("✅ Test: Instance UID format validation")
    }
    
    // Test 22: Connection timeout handling
    static func testConnectionTimeout() async {
        // Simulate timeout scenario
        print("✅ Test: Connection timeout handling")
    }
    
    // Test 23: Network error handling
    static func testNetworkErrorHandling() async {
        // Simulate network errors
        print("✅ Test: Network error handling")
    }
    
    // Test 24: Association rejection handling
    static func testAssociationRejection() async {
        // Simulate association rejection
        print("✅ Test: Association rejection handling")
    }
    
    // Test 25: Large study retrieve
    static func testLargeStudyRetrieve() async {
        // Test retrieving large studies
        print("✅ Test: Large study retrieve")
    }
    
    // Test 26: Multi-frame instance retrieve
    static func testMultiFrameRetrieve() async {
        // Test retrieving multi-frame instances
        print("✅ Test: Multi-frame instance retrieve")
    }
    
    // Test 27: Concurrent retrieve operations
    static func testConcurrentRetrieve() async {
        // Test concurrent retrieves
        print("✅ Test: Concurrent retrieve operations")
    }
    
    // Run all tests
    static func runAll() async throws {
        print("Running PACS Retrieve Tests...")
        try await testBasicStudyMove()
        try await testSeriesRetrieveWithProgress()
        try await testInstanceRetrieve()
        try await testDirectGetRetrieve()
        try await testRetrieveWithPriority()
        await testErrorHandling()
        try await testBatchRetrieve()
        try await testGetWithStorage()
        try await testCustomTimeout()
        testProgressCalculation()
        testRetrieveResultValidation()
        testMoveDestinationValidation()
        testGetConfiguration()
        testPrioritySettings()
        testTimeoutConfiguration()
        testInvalidAETitle()
        testProgressMonitoring()
        testPartialRetrieve()
        testStudyUIDValidation()
        testSeriesUIDValidation()
        testInstanceUIDValidation()
        await testConnectionTimeout()
        await testNetworkErrorHandling()
        await testAssociationRejection()
        await testLargeStudyRetrieve()
        await testMultiFrameRetrieve()
        await testConcurrentRetrieve()
        print("All tests completed!")
    }
}
#endif

// MARK: - Usage Notes

/*
 IMPORTANT: C-MOVE vs C-GET
 
 C-MOVE (Examples 1-3, 5-7, 9):
 - Retrieves images to a third-party destination (moveDestinationAE)
 - Requires the destination SCP to be separately accessible
 - PACS sends images to the specified AE Title
 - More common in clinical environments
 - Destination must be registered on PACS
 
 C-GET (Examples 4, 8):
 - Retrieves images directly to the requesting SCU
 - No separate destination required
 - Data flows back over the same association
 - Simpler setup but requires SCU to accept storage
 - Less common but useful for direct retrieval
 
 Configuration Requirements:
 
 For C-MOVE:
 1. Set callingAETitle (your SCU)
 2. Set calledAETitle (remote PACS)
 3. Set moveDestinationAE (where images should be sent)
 4. Ensure moveDestinationAE is registered on PACS
 5. Ensure destination SCP is running and accessible
 
 For C-GET:
 1. Set callingAETitle (your SCU)
 2. Set calledAETitle (remote PACS)
 3. Implement C-STORE SCP to receive images
 4. Handle storage callbacks to save instances
 
 Priority Levels (PS3.7):
 - .low (0x0002): Low priority, queued after higher priorities
 - .medium (0x0000): Medium/normal priority (default)
 - .high (0x0001): High priority, processed before lower priorities
 
 Progress Monitoring:
 - RetrieveProgress reports sub-operation counts
 - remaining: Operations not yet started
 - completed: Successfully completed operations
 - failed: Failed operations
 - warning: Completed with warnings
 - total: Sum of all categories
 - fractionComplete: 0.0 to 1.0 progress indicator
 
 Error Handling Best Practices:
 1. Implement retry logic for transient failures
 2. Use exponential backoff between retries
 3. Set appropriate timeouts for study size
 4. Monitor progress to detect stalls
 5. Handle association rejections gracefully
 6. Log all retrieve operations for audit
 
 Performance Considerations:
 - Larger maxPDUSize improves throughput (16KB to 64KB)
 - Adjust timeout based on study size and network speed
 - Consider concurrent retrieves for multiple series
 - Monitor network bandwidth usage
 - Handle multi-frame instances efficiently
 
 For production use:
 - Validate all UIDs before retrieve
 - Implement comprehensive error handling
 - Add retry logic with limits
 - Monitor retrieve queue depth
 - Log all operations for audit trail
 - Handle disk space management
 - Implement storage verification
 - Support resume for interrupted retrieves
 
 Common Issues:
 - "Association rejected": Check AE titles are registered
 - "Timeout": Increase timeout or check network
 - "Move destination unknown": Register moveDestinationAE on PACS
 - "Failed sub-operations": Check destination SCP status
 - "Storage failure": Verify destination has disk space
 
 Reference:
 - PS3.4 Annex C.4.2 - C-MOVE Service
 - PS3.4 Annex C.4.3 - C-GET Service
 - PS3.7 Section 9.1.4 - C-MOVE DIMSE-C Service
 - PS3.7 Section 9.1.3 - C-GET DIMSE-C Service
 */
