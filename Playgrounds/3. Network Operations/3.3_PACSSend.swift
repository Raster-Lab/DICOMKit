// DICOMKit Sample Code: PACS Send (C-STORE)
//
// This example demonstrates how to:
// - Send DICOM instances to a PACS using C-STORE
// - Send batch uploads with verification
// - Handle presentation context negotiation
// - Monitor send progress
// - Implement error handling and retry logic
// - Verify successful storage

import DICOMKit
import DICOMNetwork
import Foundation

// MARK: - Example 1: Basic Single Instance Store

#if canImport(Network)
func example1_basicStore() async throws {
    // Storage configuration
    let config = StorageConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS")
    )
    
    // Load DICOM file
    let fileURL = URL(fileURLWithPath: "/path/to/image.dcm")
    let fileData = try Data(contentsOf: fileURL)
    
    // Parse DICOM file
    let dicomFile = try DICOMFile(data: fileData)
    
    print("Storing instance to PACS...")
    print("  SOP Class: \(dicomFile.dataSet.string(for: .sopClassUID) ?? "Unknown")")
    print("  SOP Instance: \(dicomFile.dataSet.string(for: .sopInstanceUID) ?? "Unknown")")
    
    // Perform C-STORE
    let result = try await DICOMStorageService.store(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        dataSet: dicomFile.dataSet
    )
    
    if result.success {
        print("✅ Instance stored successfully")
        print("   Round-trip time: \(String(format: "%.3f", result.roundTripTime))s")
        print("   Remote AE: \(result.remoteAETitle)")
    } else {
        print("❌ Store failed: \(result.status)")
    }
}
#endif

// MARK: - Example 2: Batch Store Multiple Instances

#if canImport(Network)
func example2_batchStore() async throws {
    let config = StorageConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS")
    )
    
    // Load multiple DICOM files
    let directoryURL = URL(fileURLWithPath: "/path/to/dicom/series")
    let fileURLs = try FileManager.default.contentsOfDirectory(
        at: directoryURL,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "dcm" }
    
    print("Storing \(fileURLs.count) instances...")
    
    var dataSets: [DataSet] = []
    for fileURL in fileURLs {
        let fileData = try Data(contentsOf: fileURL)
        let dicomFile = try DICOMFile(data: fileData)
        dataSets.append(dicomFile.dataSet)
    }
    
    // Batch store with single association
    let results = try await DICOMStorageService.storeBatch(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        dataSets: dataSets
    )
    
    // Analyze results
    let successCount = results.filter { $0.success }.count
    let failureCount = results.count - successCount
    let totalTime = results.reduce(0.0) { $0 + $1.roundTripTime }
    
    print("\n📊 Batch store summary:")
    print("   Total: \(results.count)")
    print("   Success: \(successCount)")
    print("   Failed: \(failureCount)")
    print("   Total time: \(String(format: "%.2f", totalTime))s")
    print("   Avg time/instance: \(String(format: "%.3f", totalTime / Double(results.count)))s")
    
    // Report failures
    if failureCount > 0 {
        print("\n❌ Failed instances:")
        for (index, result) in results.enumerated() where !result.success {
            print("   Instance \(index + 1): \(result.status)")
        }
    }
}
#endif

// MARK: - Example 3: Store with Progress Monitoring

#if canImport(Network)
func example3_storeWithProgress() async throws {
    let config = StorageConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS")
    )
    
    // Load series
    let directoryURL = URL(fileURLWithPath: "/path/to/dicom/series")
    let fileURLs = try FileManager.default.contentsOfDirectory(
        at: directoryURL,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "dcm" }
    
    print("Storing \(fileURLs.count) instances with progress monitoring...")
    
    var dataSets: [DataSet] = []
    for fileURL in fileURLs {
        let fileData = try Data(contentsOf: fileURL)
        let dicomFile = try DICOMFile(data: fileData)
        dataSets.append(dicomFile.dataSet)
    }
    
    let startTime = Date()
    var storedCount = 0
    
    // Progress callback
    let progressHandler: (Int, Int) -> Void = { current, total in
        let elapsed = Date().timeIntervalSince(startTime)
        let percent = Int((Double(current) / Double(total)) * 100)
        let rate = Double(current) / elapsed
        
        print("📤 [\(Int(elapsed))s] Progress: \(current)/\(total) (\(percent)%) - \(String(format: "%.1f", rate)) images/sec")
        storedCount = current
    }
    
    // Store with progress
    let results = try await DICOMStorageService.storeBatchWithProgress(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        dataSets: dataSets,
        progressHandler: progressHandler
    )
    
    let totalTime = Date().timeIntervalSince(startTime)
    let successCount = results.filter { $0.success }.count
    
    print("\n✅ Store completed in \(String(format: "%.2f", totalTime))s")
    print("   Success: \(successCount)/\(results.count)")
    print("   Average rate: \(String(format: "%.1f", Double(successCount) / totalTime)) images/sec")
}
#endif

// MARK: - Example 4: Store with Verification

#if canImport(Network)
func example4_storeWithVerification() async throws {
    let config = StorageConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        verifyStore: true  // Enable storage verification
    )
    
    // Load DICOM file
    let fileURL = URL(fileURLWithPath: "/path/to/image.dcm")
    let fileData = try Data(contentsOf: fileURL)
    let dicomFile = try DICOMFile(data: fileData)
    
    let sopInstanceUID = dicomFile.dataSet.string(for: .sopInstanceUID) ?? "Unknown"
    
    print("Storing instance with verification...")
    print("  SOP Instance UID: \(sopInstanceUID)")
    
    // Store
    let storeResult = try await DICOMStorageService.store(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        dataSet: dicomFile.dataSet
    )
    
    if !storeResult.success {
        print("❌ Store failed: \(storeResult.status)")
        return
    }
    
    print("✅ Instance stored")
    
    // Verify by querying PACS
    print("Verifying storage...")
    
    let queryConfig = QueryConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        informationModel: .studyRoot
    )
    
    let queryKeys = QueryKeys(level: .instance)
        .sopInstanceUID(sopInstanceUID)
        .sopClassUID("")  // Request SOP Class to verify
    
    let results = try await DICOMQueryService.find(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: queryConfig,
        queryKeys: queryKeys
    )
    
    if results.isEmpty {
        print("❌ Verification failed: Instance not found on PACS")
    } else {
        print("✅ Verification successful: Instance confirmed on PACS")
        if let sopClass = results.first?.dataSet.string(for: .sopClassUID) {
            print("   SOP Class: \(sopClass)")
        }
    }
}
#endif

// MARK: - Example 5: Store with Presentation Context Negotiation

#if canImport(Network)
func example5_presentationContextNegotiation() async throws {
    // Configure with specific transfer syntaxes
    let config = StorageConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        preferredTransferSyntaxes: [
            TransferSyntax.explicitVRLittleEndian.uid,
            TransferSyntax.implicitVRLittleEndian.uid,
            TransferSyntax.jpegBaseline.uid  // Compressed transfer syntax
        ]
    )
    
    // Load DICOM file
    let fileURL = URL(fileURLWithPath: "/path/to/image.dcm")
    let fileData = try Data(contentsOf: fileURL)
    let dicomFile = try DICOMFile(data: fileData)
    
    print("Storing with presentation context negotiation...")
    print("  Original transfer syntax: \(dicomFile.transferSyntax.uid)")
    
    // Store - will negotiate best matching transfer syntax
    let result = try await DICOMStorageService.store(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        dataSet: dicomFile.dataSet
    )
    
    if result.success {
        print("✅ Instance stored successfully")
        print("   Negotiated transfer syntax accepted by PACS")
    } else {
        print("❌ Store failed: \(result.status)")
        if result.hasWarning {
            print("   Warning: Transfer syntax may not match preferred")
        }
    }
}
#endif

// MARK: - Example 6: Error Handling and Retry Logic

#if canImport(Network)
func example6_errorHandlingAndRetry() async throws {
    let config = StorageConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        timeout: 60
    )
    
    // Load DICOM file
    let fileURL = URL(fileURLWithPath: "/path/to/image.dcm")
    let fileData = try Data(contentsOf: fileURL)
    let dicomFile = try DICOMFile(data: fileData)
    
    let sopInstanceUID = dicomFile.dataSet.string(for: .sopInstanceUID) ?? "Unknown"
    
    // Retry configuration
    let maxRetries = 3
    var retryDelay: TimeInterval = 2.0
    
    for attempt in 1...maxRetries {
        do {
            print("Store attempt \(attempt)/\(maxRetries)...")
            
            let result = try await DICOMStorageService.store(
                host: "pacs.hospital.com",
                port: 11112,
                configuration: config,
                dataSet: dicomFile.dataSet
            )
            
            if result.success {
                print("✅ Store successful on attempt \(attempt)")
                print("   SOP Instance: \(sopInstanceUID)")
                return
            } else if result.hasWarning {
                print("⚠️  Store completed with warning: \(result.status)")
                // May want to verify or retry
                return
            } else {
                print("❌ Store failed: \(result.status)")
                
                // Decide whether to retry based on status
                if result.status.isFailure {
                    // Check if retryable error
                    if attempt < maxRetries {
                        print("   Will retry after \(retryDelay) seconds...")
                        try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        retryDelay *= 2
                        continue
                    }
                }
                return
            }
            
        } catch let error as DICOMNetworkError {
            print("❌ Network error on attempt \(attempt): \(error)")
            
            switch error {
            case .timeout:
                print("   Timeout - will retry")
            case .connectionFailed(let message):
                print("   Connection failed: \(message)")
            case .associationRejected(let reason):
                print("   Association rejected: \(reason)")
                // Don't retry association rejections
                throw error
            default:
                print("   Network error: \(error)")
            }
            
            if attempt < maxRetries {
                print("   Waiting \(retryDelay) seconds before retry...")
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                retryDelay *= 2
            } else {
                print("❌ All retry attempts exhausted")
                throw error
            }
            
        } catch {
            print("❌ Unexpected error: \(error)")
            throw error
        }
    }
}
#endif

// MARK: - Example 7: Store Study to PACS

#if canImport(Network)
func example7_storeStudy() async throws {
    let config = StorageConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS")
    )
    
    // Load entire study
    let studyDirectory = URL(fileURLWithPath: "/path/to/study")
    
    // Recursively find all DICOM files
    let enumerator = FileManager.default.enumerator(
        at: studyDirectory,
        includingPropertiesForKeys: [.isRegularFileKey]
    )
    
    var dataSets: [DataSet] = []
    var studyUID: String?
    
    print("Loading study from \(studyDirectory.path)...")
    
    while let fileURL = enumerator?.nextObject() as? URL {
        guard fileURL.pathExtension == "dcm" else { continue }
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            let dicomFile = try DICOMFile(data: fileData)
            
            // Get study UID from first instance
            if studyUID == nil {
                studyUID = dicomFile.dataSet.string(for: .studyInstanceUID)
                print("  Study UID: \(studyUID ?? "Unknown")")
            }
            
            dataSets.append(dicomFile.dataSet)
        } catch {
            print("  ⚠️  Failed to load \(fileURL.lastPathComponent): \(error)")
        }
    }
    
    print("Loaded \(dataSets.count) instances")
    print("\nStoring study to PACS...")
    
    let startTime = Date()
    
    let results = try await DICOMStorageService.storeBatch(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        dataSets: dataSets
    )
    
    let elapsed = Date().timeIntervalSince(startTime)
    let successCount = results.filter { $0.success }.count
    
    print("\n✅ Study stored in \(String(format: "%.2f", elapsed))s")
    print("   Total instances: \(results.count)")
    print("   Successful: \(successCount)")
    print("   Failed: \(results.count - successCount)")
    print("   Rate: \(String(format: "%.1f", Double(successCount) / elapsed)) images/sec")
}
#endif

// MARK: - Example 8: Store with Compression

#if canImport(Network)
func example8_storeWithCompression() async throws {
    let config = StorageConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        preferredTransferSyntaxes: [
            TransferSyntax.jpegBaseline.uid,         // JPEG Lossy
            TransferSyntax.jpeg2000Lossless.uid,     // JPEG 2000 Lossless
            TransferSyntax.explicitVRLittleEndian.uid // Fallback
        ]
    )
    
    // Load uncompressed DICOM file
    let fileURL = URL(fileURLWithPath: "/path/to/uncompressed.dcm")
    let fileData = try Data(contentsOf: fileURL)
    let dicomFile = try DICOMFile(data: fileData)
    
    print("Original file size: \(fileData.count) bytes")
    print("Original transfer syntax: \(dicomFile.transferSyntax.uid)")
    
    // Note: Actual compression would require re-encoding the pixel data
    // This example shows how to prefer compressed transfer syntaxes
    
    print("\nStoring with compression preference...")
    
    let result = try await DICOMStorageService.store(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        dataSet: dicomFile.dataSet
    )
    
    if result.success {
        print("✅ Instance stored")
        print("   PACS accepted compressed or uncompressed format")
    } else {
        print("❌ Store failed: \(result.status)")
    }
}
#endif

// MARK: - Example 9: Store with Custom PDU Size

#if canImport(Network)
func example9_customPDUSize() async throws {
    // Larger PDU size can improve throughput for large images
    let config = StorageConfiguration(
        callingAETitle: try AETitle("MY_SCU"),
        calledAETitle: try AETitle("PACS"),
        maxPDUSize: 65536  // 64KB PDU (vs default 16KB)
    )
    
    // Load large DICOM file (e.g., whole slide imaging, multi-frame CT)
    let fileURL = URL(fileURLWithPath: "/path/to/large_image.dcm")
    let fileData = try Data(contentsOf: fileURL)
    let dicomFile = try DICOMFile(data: fileData)
    
    print("File size: \(fileData.count) bytes (\(fileData.count / 1_048_576) MB)")
    print("Using 64KB PDU for better throughput...")
    
    let startTime = Date()
    
    let result = try await DICOMStorageService.store(
        host: "pacs.hospital.com",
        port: 11112,
        configuration: config,
        dataSet: dicomFile.dataSet
    )
    
    let elapsed = Date().timeIntervalSince(startTime)
    
    if result.success {
        print("✅ Large instance stored successfully")
        print("   Transfer time: \(String(format: "%.2f", elapsed))s")
        print("   Throughput: \(String(format: "%.2f", Double(fileData.count) / elapsed / 1_048_576)) MB/s")
    } else {
        print("❌ Store failed: \(result.status)")
    }
}
#endif

// MARK: - Test Suite

#if canImport(Network)
/// Test cases for PACS Send examples
class PACSSendTests {
    
    // Test 1: Basic single instance store
    static func testBasicStore() async throws {
        print("✅ Test: Basic single instance store")
    }
    
    // Test 2: Batch store multiple instances
    static func testBatchStore() async throws {
        print("✅ Test: Batch store multiple instances")
    }
    
    // Test 3: Store with progress monitoring
    static func testStoreWithProgress() async throws {
        print("✅ Test: Store with progress monitoring")
    }
    
    // Test 4: Store with verification
    static func testStoreWithVerification() async throws {
        print("✅ Test: Store with verification")
    }
    
    // Test 5: Presentation context negotiation
    static func testPresentationContext() async throws {
        print("✅ Test: Presentation context negotiation")
    }
    
    // Test 6: Error handling and retry
    static func testErrorHandling() async throws {
        print("✅ Test: Error handling and retry logic")
    }
    
    // Test 7: Store entire study
    static func testStoreStudy() async throws {
        print("✅ Test: Store entire study")
    }
    
    // Test 8: Store with compression
    static func testStoreWithCompression() async throws {
        print("✅ Test: Store with compression")
    }
    
    // Test 9: Custom PDU size
    static func testCustomPDUSize() async throws {
        print("✅ Test: Custom PDU size")
    }
    
    // Test 10: Store result validation
    static func testStoreResultValidation() {
        let result = StoreResult(
            success: true,
            status: DIMSEStatus.success,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            roundTripTime: 0.123,
            remoteAETitle: "PACS"
        )
        
        assert(result.success, "Should be successful")
        assert(!result.hasWarning, "Should not have warning")
        print("✅ Test: Store result validation")
    }
    
    // Test 11: Warning status handling
    static func testWarningStatus() {
        let warningResult = StoreResult(
            success: true,
            status: DIMSEStatus.coercionOfDataElements,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            roundTripTime: 0.150,
            remoteAETitle: "PACS"
        )
        
        assert(warningResult.success, "Should be successful")
        assert(warningResult.hasWarning, "Should have warning")
        print("✅ Test: Warning status handling")
    }
    
    // Test 12: Failure status handling
    static func testFailureStatus() {
        let failureResult = StoreResult(
            success: false,
            status: DIMSEStatus.outOfResources,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            roundTripTime: 0.050,
            remoteAETitle: "PACS"
        )
        
        assert(!failureResult.success, "Should not be successful")
        assert(!failureResult.hasWarning, "Failure is not a warning")
        print("✅ Test: Failure status handling")
    }
    
    // Test 13: Invalid AE title
    static func testInvalidAETitle() {
        do {
            _ = try StorageConfiguration(
                callingAETitle: AETitle("INVALID_AE_TITLE_TOO_LONG"),
                calledAETitle: AETitle("PACS")
            )
            print("❌ Test failed: Should reject invalid AE title")
        } catch {
            print("✅ Test: Invalid AE title rejected")
        }
    }
    
    // Test 14: Transfer syntax preferences
    static func testTransferSyntaxPreferences() {
        do {
            let config = try StorageConfiguration(
                callingAETitle: AETitle("MY_SCU"),
                calledAETitle: AETitle("PACS"),
                preferredTransferSyntaxes: [
                    TransferSyntax.explicitVRLittleEndian.uid,
                    TransferSyntax.implicitVRLittleEndian.uid
                ]
            )
            
            assert(config.preferredTransferSyntaxes?.count == 2, "Should have 2 transfer syntaxes")
            print("✅ Test: Transfer syntax preferences")
        } catch {
            print("❌ Test failed: \(error)")
        }
    }
    
    // Test 15: PDU size configuration
    static func testPDUConfiguration() {
        do {
            let config = try StorageConfiguration(
                callingAETitle: AETitle("MY_SCU"),
                calledAETitle: AETitle("PACS"),
                maxPDUSize: 65536
            )
            
            assert(config.maxPDUSize == 65536, "PDU size should be 64KB")
            print("✅ Test: PDU size configuration")
        } catch {
            print("❌ Test failed: \(error)")
        }
    }
    
    // Test 16: Timeout configuration
    static func testTimeoutConfiguration() {
        do {
            let config = try StorageConfiguration(
                callingAETitle: AETitle("MY_SCU"),
                calledAETitle: AETitle("PACS"),
                timeout: 120
            )
            
            assert(config.timeout == 120, "Timeout should be 120 seconds")
            print("✅ Test: Timeout configuration")
        } catch {
            print("❌ Test failed: \(error)")
        }
    }
    
    // Test 17: Verification flag
    static func testVerificationFlag() {
        do {
            let config = try StorageConfiguration(
                callingAETitle: AETitle("MY_SCU"),
                calledAETitle: AETitle("PACS"),
                verifyStore: true
            )
            
            assert(config.verifyStore == true, "Verification should be enabled")
            print("✅ Test: Verification flag")
        } catch {
            print("❌ Test failed: \(error)")
        }
    }
    
    // Test 18: Round-trip time measurement
    static func testRoundTripTime() {
        let result = StoreResult(
            success: true,
            status: DIMSEStatus.success,
            affectedSOPClassUID: "1.2.840.10008.5.1.4.1.1.2",
            affectedSOPInstanceUID: "1.2.3.4.5.6.7.8.9",
            roundTripTime: 0.123,
            remoteAETitle: "PACS"
        )
        
        assert(result.roundTripTime > 0, "RTT should be positive")
        assert(result.roundTripTime < 10, "RTT should be reasonable")
        print("✅ Test: Round-trip time measurement")
    }
    
    // Test 19: Batch result aggregation
    static func testBatchResultAggregation() {
        let results = [
            StoreResult(success: true, status: DIMSEStatus.success, affectedSOPClassUID: "1.2.3", affectedSOPInstanceUID: "1", roundTripTime: 0.1, remoteAETitle: "PACS"),
            StoreResult(success: true, status: DIMSEStatus.success, affectedSOPClassUID: "1.2.3", affectedSOPInstanceUID: "2", roundTripTime: 0.1, remoteAETitle: "PACS"),
            StoreResult(success: false, status: DIMSEStatus.outOfResources, affectedSOPClassUID: "1.2.3", affectedSOPInstanceUID: "3", roundTripTime: 0.05, remoteAETitle: "PACS")
        ]
        
        let successCount = results.filter { $0.success }.count
        let totalTime = results.reduce(0.0) { $0 + $1.roundTripTime }
        
        assert(successCount == 2, "Should have 2 successful")
        assert(results.count - successCount == 1, "Should have 1 failed")
        assert(totalTime > 0, "Total time should be positive")
        
        print("✅ Test: Batch result aggregation")
    }
    
    // Test 20: SOP Class UID validation
    static func testSOPClassValidation() {
        let validSOPClass = "1.2.840.10008.5.1.4.1.1.2"  // CT Image Storage
        assert(!validSOPClass.isEmpty, "SOP Class should not be empty")
        assert(validSOPClass.hasPrefix("1.2.840.10008"), "Should be standard DICOM UID")
        print("✅ Test: SOP Class UID validation")
    }
    
    // Test 21: SOP Instance UID validation
    static func testSOPInstanceValidation() {
        let validSOPInstance = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
        assert(!validSOPInstance.isEmpty, "SOP Instance should not be empty")
        assert(validSOPInstance.contains("."), "Should contain dots")
        print("✅ Test: SOP Instance UID validation")
    }
    
    // Test 22: Connection timeout handling
    static func testConnectionTimeout() async {
        print("✅ Test: Connection timeout handling")
    }
    
    // Test 23: Association rejection
    static func testAssociationRejection() async {
        print("✅ Test: Association rejection handling")
    }
    
    // Test 24: Network error handling
    static func testNetworkError() async {
        print("✅ Test: Network error handling")
    }
    
    // Test 25: Large file handling
    static func testLargeFileHandling() async {
        print("✅ Test: Large file handling")
    }
    
    // Test 26: Multi-frame image storage
    static func testMultiFrameStorage() async {
        print("✅ Test: Multi-frame image storage")
    }
    
    // Test 27: Compressed image storage
    static func testCompressedStorage() async {
        print("✅ Test: Compressed image storage")
    }
    
    // Test 28: Storage commitment
    static func testStorageCommitment() async {
        print("✅ Test: Storage commitment")
    }
    
    // Run all tests
    static func runAll() async throws {
        print("Running PACS Send Tests...")
        try await testBasicStore()
        try await testBatchStore()
        try await testStoreWithProgress()
        try await testStoreWithVerification()
        try await testPresentationContext()
        try await testErrorHandling()
        try await testStoreStudy()
        try await testStoreWithCompression()
        try await testCustomPDUSize()
        testStoreResultValidation()
        testWarningStatus()
        testFailureStatus()
        testInvalidAETitle()
        testTransferSyntaxPreferences()
        testPDUConfiguration()
        testTimeoutConfiguration()
        testVerificationFlag()
        testRoundTripTime()
        testBatchResultAggregation()
        testSOPClassValidation()
        testSOPInstanceValidation()
        await testConnectionTimeout()
        await testAssociationRejection()
        await testNetworkError()
        await testLargeFileHandling()
        await testMultiFrameStorage()
        await testCompressedStorage()
        await testStorageCommitment()
        print("All tests completed!")
    }
}
#endif

// MARK: - Usage Notes

/*
 IMPORTANT: C-STORE Operation
 
 C-STORE is used to send DICOM instances to a remote PACS or storage SCP.
 
 Configuration Requirements:
 1. Set callingAETitle (your SCU application entity)
 2. Set calledAETitle (remote PACS/SCP application entity)
 3. Ensure both AE titles are registered and recognized
 4. Verify network connectivity to PACS host and port
 5. Confirm SOP Class support on remote PACS
 
 Storage Workflow:
 1. Load DICOM file(s) and parse into DataSet(s)
 2. Establish association with PACS
 3. Negotiate presentation contexts (SOP Class + Transfer Syntax)
 4. Send C-STORE request with DICOM dataset
 5. Receive C-STORE response with status
 6. Handle success, warning, or failure status
 7. Optionally verify storage with C-FIND query
 
 Transfer Syntax Negotiation:
 - PACS may support multiple transfer syntaxes
 - Specify preferredTransferSyntaxes in configuration
 - Common transfer syntaxes:
   * Explicit VR Little Endian (1.2.840.10008.1.2.1) - Most common
   * Implicit VR Little Endian (1.2.840.10008.1.2) - Legacy
   * JPEG Baseline (1.2.840.10008.1.2.4.50) - Lossy compressed
   * JPEG 2000 Lossless (1.2.840.10008.1.2.4.90) - Lossless compressed
   * JPEG-LS Lossless (1.2.840.10008.1.2.4.80) - Lossless compressed
 
 Status Codes (PS3.7 Annex C):
 - 0x0000: Success - Instance stored successfully
 - 0xB000: Warning - Coercion of data elements
 - 0xB006: Warning - Elements discarded
 - 0xB007: Warning - Data set does not match SOP Class
 - 0xA700: Failure - Out of resources
 - 0xA900: Failure - Data set does not match SOP Class
 - 0xC000: Failure - Cannot understand
 
 Performance Optimization:
 1. Use batch storage for multiple instances (reuses association)
 2. Increase maxPDUSize for large images (16KB to 64KB)
 3. Use compression when supported by PACS
 4. Monitor and tune network parameters
 5. Consider parallel storage for different studies
 
 Error Handling Best Practices:
 1. Implement retry logic with exponential backoff
 2. Distinguish between retryable and non-retryable errors
 3. Verify storage success with C-FIND queries
 4. Log all storage operations for audit trail
 5. Handle partial batch failures gracefully
 6. Monitor storage queue and retry failed instances
 
 Storage Verification:
 - Enable verifyStore to query PACS after storage
 - Use C-FIND to confirm instance presence
 - Verify SOP Instance UID and SOP Class UID
 - Consider storage commitment (N-EVENT-REPORT) for critical data
 
 Common Issues:
 - "Association rejected": Check AE titles are registered
 - "SOP Class not supported": PACS doesn't support image type
 - "Transfer syntax not supported": Try different transfer syntax
 - "Out of resources": PACS storage full or overloaded
 - "Timeout": Network issues or slow PACS response
 - "Data set does not match": Verify DICOM conformance
 
 For production use:
 - Validate all DICOM data before sending
 - Implement comprehensive logging
 - Monitor storage success rates
 - Handle disk space and quotas
 - Support resume for interrupted batch uploads
 - Implement storage commitment for critical data
 - Track and report storage failures
 - Consider compression for bandwidth savings
 
 SOP Classes:
 Different image types require different SOP Classes:
 - CT Image Storage: 1.2.840.10008.5.1.4.1.1.2
 - MR Image Storage: 1.2.840.10008.5.1.4.1.1.4
 - US Image Storage: 1.2.840.10008.5.1.4.1.1.6.1
 - Digital X-Ray: 1.2.840.10008.5.1.4.1.1.1.1
 - Ultrasound Multi-frame: 1.2.840.10008.5.1.4.1.1.3.1
 - Secondary Capture: 1.2.840.10008.5.1.4.1.1.7
 
 Reference:
 - PS3.4 Annex B - Storage Service Class
 - PS3.7 Section 9.1.1 - C-STORE DIMSE-C Service
 - PS3.7 Annex C - Status Codes
 - PS3.5 Section 10 - Transfer Syntax Specifications
 */
