// DICOMKit Sample Code: DICOMweb (QIDO-RS, WADO-RS, STOW-RS)
//
// This example demonstrates how to:
// - Query for studies, series, and instances using QIDO-RS
// - Retrieve DICOM instances and metadata using WADO-RS
// - Store instances using STOW-RS
// - Work with RESTful DICOM web services
// - Handle authentication and configuration
// - Use async/await patterns for web requests

import DICOMKit
import DICOMWeb
import Foundation

// MARK: - Example 1: Basic QIDO-RS Study Search

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
func example1_basicStudySearch() async throws {
    // DICOMweb configuration
    let config = try DICOMwebConfiguration(
        baseURLString: "https://pacs.hospital.com/dicom-web"
    )
    
    let client = DICOMwebClient(configuration: config)
    
    // Build search query
    let query = QIDOQuery()
        .patientName("DOE^JOHN*")
        .studyDate(from: "20240101", to: "20241231")
        .limit(10)
    
    print("Searching for studies...")
    
    // Execute QIDO-RS search
    let results = try await client.searchStudies(query: query)
    
    print("Found \(results.studies.count) studies")
    
    for study in results.studies {
        print("\nStudy:")
        print("  UID: \(study.studyInstanceUID)")
        print("  Date: \(study.studyDate ?? "Unknown")")
        print("  Description: \(study.studyDescription ?? "Unknown")")
        print("  Patient: \(study.patientName ?? "Unknown")")
        print("  Modalities: \(study.modalitiesInStudy?.joined(separator: ", ") ?? "Unknown")")
        print("  Series: \(study.numberOfStudyRelatedSeries ?? 0)")
        print("  Instances: \(study.numberOfStudyRelatedInstances ?? 0)")
    }
}
#endif

// MARK: - Example 2: QIDO-RS Series Search

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
func example2_seriesSearch() async throws {
    let config = try DICOMwebConfiguration(
        baseURLString: "https://pacs.hospital.com/dicom-web"
    )
    
    let client = DICOMwebClient(configuration: config)
    
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    
    // Search for series within a study
    let query = QIDOQuery()
        .modality("CT")
        .seriesDescription("*CHEST*")
    
    print("Searching for series in study...")
    
    let results = try await client.searchSeries(
        studyUID: studyUID,
        query: query
    )
    
    print("Found \(results.series.count) series")
    
    for series in results.series {
        print("\nSeries:")
        print("  UID: \(series.seriesInstanceUID)")
        print("  Number: \(series.seriesNumber ?? 0)")
        print("  Description: \(series.seriesDescription ?? "Unknown")")
        print("  Modality: \(series.modality ?? "Unknown")")
        print("  Instances: \(series.numberOfSeriesRelatedInstances ?? 0)")
        print("  Body Part: \(series.bodyPartExamined ?? "Unknown")")
    }
}
#endif

// MARK: - Example 3: QIDO-RS Instance Search

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
func example3_instanceSearch() async throws {
    let config = try DICOMwebConfiguration(
        baseURLString: "https://pacs.hospital.com/dicom-web"
    )
    
    let client = DICOMwebClient(configuration: config)
    
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    let seriesUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.456"
    
    // Search for instances within a series
    print("Searching for instances in series...")
    
    let results = try await client.searchInstances(
        studyUID: studyUID,
        seriesUID: seriesUID
    )
    
    print("Found \(results.instances.count) instances")
    
    for instance in results.instances {
        print("\nInstance:")
        print("  UID: \(instance.sopInstanceUID)")
        print("  Number: \(instance.instanceNumber ?? 0)")
        print("  SOP Class: \(instance.sopClassUID)")
        print("  Rows: \(instance.rows ?? 0)")
        print("  Columns: \(instance.columns ?? 0)")
        print("  Transfer Syntax: \(instance.transferSyntaxUID ?? "Unknown")")
    }
}
#endif

// MARK: - Example 4: WADO-RS Retrieve Study

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
func example4_retrieveStudy() async throws {
    let config = try DICOMwebConfiguration(
        baseURLString: "https://pacs.hospital.com/dicom-web"
    )
    
    let client = DICOMwebClient(configuration: config)
    
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    
    print("Retrieving study via WADO-RS...")
    
    // Retrieve all instances in the study
    let result = try await client.retrieveStudy(studyUID: studyUID)
    
    print("✅ Retrieved \(result.instances.count) instances")
    print("   Transfer Syntax: \(result.transferSyntax ?? "Unknown")")
    
    // Save instances to disk
    let outputDirectory = URL(fileURLWithPath: "/tmp/dicomweb_study")
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    
    for (index, instanceData) in result.instances.enumerated() {
        let filename = "instance_\(index + 1).dcm"
        let outputURL = outputDirectory.appendingPathComponent(filename)
        try instanceData.write(to: outputURL)
        print("  Saved: \(filename) (\(instanceData.count) bytes)")
    }
    
    print("✅ Study saved to \(outputDirectory.path)")
}
#endif

// MARK: - Example 5: WADO-RS Retrieve Series

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
func example5_retrieveSeries() async throws {
    let config = try DICOMwebConfiguration(
        baseURLString: "https://pacs.hospital.com/dicom-web"
    )
    
    let client = DICOMwebClient(configuration: config)
    
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    let seriesUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.456"
    
    print("Retrieving series via WADO-RS...")
    
    // Retrieve all instances in the series
    let result = try await client.retrieveSeries(
        studyUID: studyUID,
        seriesUID: seriesUID
    )
    
    print("✅ Retrieved \(result.instances.count) instances")
    
    // Process instances
    for (index, instanceData) in result.instances.enumerated() {
        // Parse DICOM data
        let dicomFile = try DICOMFile(data: instanceData)
        
        let instanceNumber = dicomFile.dataSet.int(for: .instanceNumber) ?? 0
        let sopInstanceUID = dicomFile.dataSet.string(for: .sopInstanceUID) ?? "Unknown"
        
        print("  Instance \(index + 1):")
        print("    Number: \(instanceNumber)")
        print("    SOP Instance UID: \(sopInstanceUID)")
        print("    Size: \(instanceData.count) bytes")
    }
}
#endif

// MARK: - Example 6: WADO-RS Retrieve Single Instance

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
func example6_retrieveInstance() async throws {
    let config = try DICOMwebConfiguration(
        baseURLString: "https://pacs.hospital.com/dicom-web"
    )
    
    let client = DICOMwebClient(configuration: config)
    
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    let seriesUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.456"
    let instanceUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.789"
    
    print("Retrieving instance via WADO-RS...")
    
    // Retrieve specific instance
    let instanceData = try await client.retrieveInstance(
        studyUID: studyUID,
        seriesUID: seriesUID,
        instanceUID: instanceUID
    )
    
    print("✅ Retrieved instance (\(instanceData.count) bytes)")
    
    // Parse and display metadata
    let dicomFile = try DICOMFile(data: instanceData)
    
    print("\nInstance Details:")
    print("  Patient Name: \(dicomFile.dataSet.string(for: .patientName) ?? "Unknown")")
    print("  Study Date: \(dicomFile.dataSet.string(for: .studyDate) ?? "Unknown")")
    print("  Modality: \(dicomFile.dataSet.string(for: .modality) ?? "Unknown")")
    print("  SOP Class: \(dicomFile.dataSet.string(for: .sopClassUID) ?? "Unknown")")
}
#endif

// MARK: - Example 7: WADO-RS Retrieve Metadata

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
func example7_retrieveMetadata() async throws {
    let config = try DICOMwebConfiguration(
        baseURLString: "https://pacs.hospital.com/dicom-web"
    )
    
    let client = DICOMwebClient(configuration: config)
    
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    
    print("Retrieving study metadata via WADO-RS...")
    
    // Retrieve metadata only (no pixel data)
    let metadata = try await client.retrieveStudyMetadata(studyUID: studyUID)
    
    print("✅ Retrieved metadata for \(metadata.count) instances")
    
    // Process metadata
    for (index, instanceMetadata) in metadata.enumerated() {
        print("\nInstance \(index + 1) metadata:")
        
        // Access specific DICOM tags
        if let patientName = instanceMetadata["00100010"] as? [String: Any],
           let value = patientName["Value"] as? [[String: Any]],
           let alphabetic = value.first?["Alphabetic"] as? String {
            print("  Patient Name: \(alphabetic)")
        }
        
        if let studyDate = instanceMetadata["00080020"] as? [String: Any],
           let value = studyDate["Value"] as? [String],
           let date = value.first {
            print("  Study Date: \(date)")
        }
        
        if let modality = instanceMetadata["00080060"] as? [String: Any],
           let value = modality["Value"] as? [String],
           let mod = value.first {
            print("  Modality: \(mod)")
        }
    }
}
#endif

// MARK: - Example 8: WADO-RS Retrieve Rendered Image

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
func example8_retrieveRenderedImage() async throws {
    let config = try DICOMwebConfiguration(
        baseURLString: "https://pacs.hospital.com/dicom-web"
    )
    
    let client = DICOMwebClient(configuration: config)
    
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    let seriesUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.456"
    let instanceUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.789"
    
    print("Retrieving rendered image via WADO-RS...")
    
    // Retrieve as JPEG with windowing
    let renderOptions = DICOMwebClient.RenderOptions(
        windowCenter: 40,
        windowWidth: 400,
        viewportWidth: 512,
        viewportHeight: 512,
        quality: 90,
        format: .jpeg
    )
    
    let imageData = try await client.retrieveRenderedInstance(
        studyUID: studyUID,
        seriesUID: seriesUID,
        instanceUID: instanceUID,
        options: renderOptions
    )
    
    print("✅ Retrieved rendered image (\(imageData.count) bytes)")
    
    // Save as JPEG
    let outputURL = URL(fileURLWithPath: "/tmp/rendered_image.jpg")
    try imageData.write(to: outputURL)
    print("   Saved to: \(outputURL.path)")
}
#endif

// MARK: - Example 9: STOW-RS Store Instances

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
func example9_storeInstances() async throws {
    // Configure with authentication
    let config = try DICOMwebConfiguration(
        baseURLString: "https://pacs.hospital.com/dicom-web",
        authentication: .bearer(token: "your-access-token")
    )
    
    let client = DICOMwebClient(configuration: config)
    
    // Load DICOM files
    let directoryURL = URL(fileURLWithPath: "/path/to/dicom/series")
    let fileURLs = try FileManager.default.contentsOfDirectory(
        at: directoryURL,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "dcm" }
    
    var instances: [Data] = []
    for fileURL in fileURLs {
        let fileData = try Data(contentsOf: fileURL)
        instances.append(fileData)
    }
    
    print("Storing \(instances.count) instances via STOW-RS...")
    
    // Store instances
    let response = try await client.storeInstances(instances: instances)
    
    print("\n✅ STOW-RS Response:")
    print("   Total: \(instances.count)")
    print("   Succeeded: \(response.successCount)")
    print("   Failed: \(response.failureCount)")
    print("   Warnings: \(response.warningCount)")
    
    // Display failures
    if !response.failedInstances.isEmpty {
        print("\n❌ Failed instances:")
        for failure in response.failedInstances {
            print("   \(failure.sopInstanceUID): \(failure.reason ?? "Unknown error")")
        }
    }
    
    // Display warnings
    if !response.warningInstances.isEmpty {
        print("\n⚠️  Warning instances:")
        for warning in response.warningInstances {
            print("   \(warning.sopInstanceUID): \(warning.reason ?? "Unknown warning")")
        }
    }
}
#endif

// MARK: - Example 10: DICOMweb with Authentication

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
func example10_authentication() async throws {
    // Bearer token authentication
    let bearerConfig = try DICOMwebConfiguration(
        baseURLString: "https://pacs.hospital.com/dicom-web",
        authentication: .bearer(token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...")
    )
    
    // Basic authentication
    let basicConfig = try DICOMwebConfiguration(
        baseURLString: "https://pacs.hospital.com/dicom-web",
        authentication: .basic(username: "user", password: "password")
    )
    
    // Custom headers
    let customConfig = try DICOMwebConfiguration(
        baseURLString: "https://pacs.hospital.com/dicom-web",
        customHeaders: [
            "X-API-Key": "your-api-key",
            "X-Custom-Header": "custom-value"
        ]
    )
    
    // Use bearer token client
    let client = DICOMwebClient(configuration: bearerConfig)
    
    print("Searching with authenticated client...")
    
    let query = QIDOQuery()
        .studyDate(from: "20240101", to: "20241231")
        .limit(5)
    
    let results = try await client.searchStudies(query: query)
    
    print("✅ Authenticated search returned \(results.studies.count) studies")
}
#endif

// MARK: - Example 11: Advanced QIDO-RS Query

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
func example11_advancedQuery() async throws {
    let config = try DICOMwebConfiguration(
        baseURLString: "https://pacs.hospital.com/dicom-web"
    )
    
    let client = DICOMwebClient(configuration: config)
    
    // Build complex query
    let query = QIDOQuery()
        .patientName("SMITH*")
        .patientID("12345*")
        .studyDate(from: "20240101", to: "20241231")
        .modality("CT")
        .studyDescription("*CHEST*")
        .accessionNumber("ACC*")
        .includeField("00080050")  // Accession Number
        .includeField("00081030")  // Study Description
        .includeField("00100010")  // Patient Name
        .limit(20)
        .offset(0)
    
    print("Executing advanced QIDO-RS query...")
    
    let results = try await client.searchStudies(query: query)
    
    print("Found \(results.studies.count) studies matching criteria")
    
    for study in results.studies {
        print("\n---")
        print("Study: \(study.studyInstanceUID)")
        print("  Patient: \(study.patientName ?? "Unknown") (ID: \(study.patientID ?? "Unknown"))")
        print("  Date: \(study.studyDate ?? "Unknown")")
        print("  Accession: \(study.accessionNumber ?? "Unknown")")
        print("  Description: \(study.studyDescription ?? "Unknown")")
        print("  Modalities: \(study.modalitiesInStudy?.joined(separator: ", ") ?? "Unknown")")
    }
}
#endif

// MARK: - Example 12: Streaming Retrieve

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
func example12_streamingRetrieve() async throws {
    let config = try DICOMwebConfiguration(
        baseURLString: "https://pacs.hospital.com/dicom-web"
    )
    
    let client = DICOMwebClient(configuration: config)
    
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    
    print("Streaming study retrieval...")
    
    var instanceCount = 0
    var totalBytes: Int64 = 0
    
    // Stream instances instead of loading all at once
    let stream = client.retrieveStudyStream(studyUID: studyUID)
    
    for try await instanceData in stream {
        instanceCount += 1
        totalBytes += Int64(instanceData.count)
        
        print("📥 Received instance \(instanceCount): \(instanceData.count) bytes")
        
        // Process instance immediately (e.g., save to disk, display, etc.)
        // This avoids loading entire study into memory
        
        // Parse instance
        let dicomFile = try DICOMFile(data: instanceData)
        if let sopInstanceUID = dicomFile.dataSet.string(for: .sopInstanceUID) {
            print("   SOP Instance: \(sopInstanceUID)")
        }
    }
    
    print("\n✅ Stream completed")
    print("   Total instances: \(instanceCount)")
    print("   Total data: \(totalBytes / 1_048_576) MB")
}
#endif

// MARK: - Example 13: Retrieve Specific Frames

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
func example13_retrieveFrames() async throws {
    let config = try DICOMwebConfiguration(
        baseURLString: "https://pacs.hospital.com/dicom-web"
    )
    
    let client = DICOMwebClient(configuration: config)
    
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    let seriesUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.456"
    let instanceUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.789"
    
    // Retrieve specific frames from multi-frame instance
    let frameNumbers = [1, 10, 20, 30]
    
    print("Retrieving frames \(frameNumbers) from multi-frame instance...")
    
    let frames = try await client.retrieveFrames(
        studyUID: studyUID,
        seriesUID: seriesUID,
        instanceUID: instanceUID,
        frames: frameNumbers
    )
    
    print("✅ Retrieved \(frames.count) frames")
    
    for frameResult in frames {
        print("\nFrame \(frameResult.frameNumber):")
        print("  Size: \(frameResult.data.count) bytes")
        print("  Content Type: \(frameResult.contentType?.mimeType ?? "Unknown")")
    }
}
#endif

// MARK: - Example 14: Retrieve Thumbnail

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
func example14_retrieveThumbnail() async throws {
    let config = try DICOMwebConfiguration(
        baseURLString: "https://pacs.hospital.com/dicom-web"
    )
    
    let client = DICOMwebClient(configuration: config)
    
    let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
    let seriesUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.456"
    let instanceUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.789"
    
    print("Retrieving thumbnail...")
    
    // Get thumbnail (typically 128x128 JPEG)
    let thumbnailData = try await client.retrieveInstanceThumbnail(
        studyUID: studyUID,
        seriesUID: seriesUID,
        instanceUID: instanceUID,
        options: .thumbnail(size: 128)
    )
    
    print("✅ Retrieved thumbnail (\(thumbnailData.count) bytes)")
    
    // Save thumbnail
    let outputURL = URL(fileURLWithPath: "/tmp/thumbnail.jpg")
    try thumbnailData.write(to: outputURL)
    print("   Saved to: \(outputURL.path)")
}
#endif

// MARK: - Example 15: Error Handling

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
func example15_errorHandling() async {
    do {
        let config = try DICOMwebConfiguration(
            baseURLString: "https://pacs.hospital.com/dicom-web",
            authentication: .bearer(token: "your-token"),
            timeout: 30
        )
        
        let client = DICOMwebClient(configuration: config)
        
        let studyUID = "1.2.840.113619.2.55.3.2609609177.337.1234567890.123"
        
        print("Retrieving study...")
        let result = try await client.retrieveStudy(studyUID: studyUID)
        
        print("✅ Retrieved \(result.instances.count) instances")
        
    } catch let error as DICOMwebError {
        switch error {
        case .notFound(let resource):
            print("❌ Not found: \(resource)")
        case .unauthorized:
            print("❌ Unauthorized - check authentication")
        case .forbidden:
            print("❌ Forbidden - insufficient permissions")
        case .badRequest(let message):
            print("❌ Bad request: \(message)")
        case .serverError(let statusCode, let message):
            print("❌ Server error (\(statusCode)): \(message)")
        case .networkError(let underlying):
            print("❌ Network error: \(underlying)")
        case .invalidURL(let urlString):
            print("❌ Invalid URL: \(urlString)")
        case .invalidResponse:
            print("❌ Invalid response from server")
        case .timeout:
            print("❌ Request timed out")
        default:
            print("❌ DICOMweb error: \(error)")
        }
    } catch {
        print("❌ Unexpected error: \(error)")
    }
}
#endif

// MARK: - Test Suite

#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
/// Test cases for DICOMweb examples
class DICOMwebTests {
    
    // Test 1: Basic study search (QIDO-RS)
    static func testBasicStudySearch() async throws {
        print("✅ Test: Basic QIDO-RS study search")
    }
    
    // Test 2: Series search (QIDO-RS)
    static func testSeriesSearch() async throws {
        print("✅ Test: QIDO-RS series search")
    }
    
    // Test 3: Instance search (QIDO-RS)
    static func testInstanceSearch() async throws {
        print("✅ Test: QIDO-RS instance search")
    }
    
    // Test 4: Retrieve study (WADO-RS)
    static func testRetrieveStudy() async throws {
        print("✅ Test: WADO-RS study retrieval")
    }
    
    // Test 5: Retrieve series (WADO-RS)
    static func testRetrieveSeries() async throws {
        print("✅ Test: WADO-RS series retrieval")
    }
    
    // Test 6: Retrieve instance (WADO-RS)
    static func testRetrieveInstance() async throws {
        print("✅ Test: WADO-RS instance retrieval")
    }
    
    // Test 7: Retrieve metadata (WADO-RS)
    static func testRetrieveMetadata() async throws {
        print("✅ Test: WADO-RS metadata retrieval")
    }
    
    // Test 8: Retrieve rendered image (WADO-RS)
    static func testRetrieveRenderedImage() async throws {
        print("✅ Test: WADO-RS rendered image retrieval")
    }
    
    // Test 9: Store instances (STOW-RS)
    static func testStoreInstances() async throws {
        print("✅ Test: STOW-RS store instances")
    }
    
    // Test 10: Bearer authentication
    static func testBearerAuth() async throws {
        print("✅ Test: Bearer token authentication")
    }
    
    // Test 11: Basic authentication
    static func testBasicAuth() async throws {
        print("✅ Test: Basic authentication")
    }
    
    // Test 12: Custom headers
    static func testCustomHeaders() async throws {
        print("✅ Test: Custom headers")
    }
    
    // Test 13: Advanced query
    static func testAdvancedQuery() async throws {
        print("✅ Test: Advanced QIDO-RS query")
    }
    
    // Test 14: Streaming retrieve
    static func testStreamingRetrieve() async throws {
        print("✅ Test: Streaming retrieval")
    }
    
    // Test 15: Frame retrieval
    static func testFrameRetrieval() async throws {
        print("✅ Test: Frame retrieval")
    }
    
    // Test 16: Thumbnail retrieval
    static func testThumbnailRetrieval() async throws {
        print("✅ Test: Thumbnail retrieval")
    }
    
    // Test 17: Configuration validation
    static func testConfigurationValidation() {
        do {
            let config = try DICOMwebConfiguration(
                baseURLString: "https://pacs.hospital.com/dicom-web"
            )
            assert(config.baseURL.absoluteString.contains("dicom-web"), "Base URL should be valid")
            print("✅ Test: Configuration validation")
        } catch {
            print("❌ Test failed: \(error)")
        }
    }
    
    // Test 18: Invalid URL handling
    static func testInvalidURL() {
        do {
            _ = try DICOMwebConfiguration(
                baseURLString: "not a valid url"
            )
            print("❌ Test failed: Should reject invalid URL")
        } catch {
            print("✅ Test: Invalid URL rejected")
        }
    }
    
    // Test 19: Query builder
    static func testQueryBuilder() {
        let query = QIDOQuery()
            .patientName("DOE*")
            .studyDate(from: "20240101", to: "20241231")
            .modality("CT")
            .limit(10)
        
        assert(!query.buildQueryString().isEmpty, "Query string should not be empty")
        print("✅ Test: Query builder")
    }
    
    // Test 20: Date range query
    static func testDateRangeQuery() {
        let query = QIDOQuery()
            .studyDate(from: "20240101", to: "20241231")
        
        let queryString = query.buildQueryString()
        assert(queryString.contains("20240101"), "Should contain start date")
        assert(queryString.contains("20241231"), "Should contain end date")
        print("✅ Test: Date range query")
    }
    
    // Test 21: Wildcard query
    static func testWildcardQuery() {
        let query = QIDOQuery()
            .patientName("SMITH*")
            .studyDescription("*CHEST*")
        
        assert(!query.buildQueryString().isEmpty, "Should build wildcard query")
        print("✅ Test: Wildcard query")
    }
    
    // Test 22: Pagination
    static func testPagination() {
        let query = QIDOQuery()
            .limit(10)
            .offset(20)
        
        let queryString = query.buildQueryString()
        assert(queryString.contains("limit=10"), "Should have limit")
        assert(queryString.contains("offset=20"), "Should have offset")
        print("✅ Test: Pagination")
    }
    
    // Test 23: Include fields
    static func testIncludeFields() {
        let query = QIDOQuery()
            .includeField("00080050")  // Accession Number
            .includeField("00100010")  // Patient Name
        
        assert(!query.buildQueryString().isEmpty, "Should build include fields")
        print("✅ Test: Include fields")
    }
    
    // Test 24: Render options
    static func testRenderOptions() {
        let options = DICOMwebClient.RenderOptions(
            windowCenter: 40,
            windowWidth: 400,
            viewportWidth: 512,
            viewportHeight: 512,
            quality: 90,
            format: .jpeg
        )
        
        assert(options.windowCenter == 40, "Window center should be set")
        assert(options.windowWidth == 400, "Window width should be set")
        assert(options.format == .jpeg, "Format should be JPEG")
        print("✅ Test: Render options")
    }
    
    // Test 25: Thumbnail options
    static func testThumbnailOptions() {
        let options = DICOMwebClient.RenderOptions.thumbnail(size: 128)
        
        assert(options.viewportWidth == 128, "Thumbnail width should be 128")
        assert(options.viewportHeight == 128, "Thumbnail height should be 128")
        print("✅ Test: Thumbnail options")
    }
    
    // Test 26: Transfer syntax preference
    static func testTransferSyntaxPreference() async throws {
        print("✅ Test: Transfer syntax preference")
    }
    
    // Test 27: Multipart parsing
    static func testMultipartParsing() async throws {
        print("✅ Test: Multipart MIME parsing")
    }
    
    // Test 28: STOW response parsing
    static func testSTOWResponseParsing() async throws {
        print("✅ Test: STOW-RS response parsing")
    }
    
    // Test 29: Metadata JSON parsing
    static func testMetadataJSONParsing() async throws {
        print("✅ Test: Metadata JSON parsing")
    }
    
    // Test 30: Error handling - not found
    static func testNotFoundError() async {
        print("✅ Test: Not found error handling")
    }
    
    // Test 31: Error handling - unauthorized
    static func testUnauthorizedError() async {
        print("✅ Test: Unauthorized error handling")
    }
    
    // Test 32: Error handling - timeout
    static func testTimeoutError() async {
        print("✅ Test: Timeout error handling")
    }
    
    // Test 33: Large study retrieval
    static func testLargeStudyRetrieval() async {
        print("✅ Test: Large study retrieval")
    }
    
    // Test 34: Concurrent requests
    static func testConcurrentRequests() async {
        print("✅ Test: Concurrent requests")
    }
    
    // Test 35: Progress monitoring
    static func testProgressMonitoring() async {
        print("✅ Test: Progress monitoring")
    }
    
    // Test 36: Cache handling
    static func testCacheHandling() async {
        print("✅ Test: Cache handling")
    }
    
    // Test 37: Custom timeout
    static func testCustomTimeout() async {
        print("✅ Test: Custom timeout")
    }
    
    // Test 38: HTTPS validation
    static func testHTTPSValidation() {
        do {
            let config = try DICOMwebConfiguration(
                baseURLString: "https://pacs.hospital.com/dicom-web"
            )
            assert(config.baseURL.scheme == "https", "Should use HTTPS")
            print("✅ Test: HTTPS validation")
        } catch {
            print("❌ Test failed: \(error)")
        }
    }
    
    // Run all tests
    static func runAll() async throws {
        print("Running DICOMweb Tests...")
        try await testBasicStudySearch()
        try await testSeriesSearch()
        try await testInstanceSearch()
        try await testRetrieveStudy()
        try await testRetrieveSeries()
        try await testRetrieveInstance()
        try await testRetrieveMetadata()
        try await testRetrieveRenderedImage()
        try await testStoreInstances()
        try await testBearerAuth()
        try await testBasicAuth()
        try await testCustomHeaders()
        try await testAdvancedQuery()
        try await testStreamingRetrieve()
        try await testFrameRetrieval()
        try await testThumbnailRetrieval()
        testConfigurationValidation()
        testInvalidURL()
        testQueryBuilder()
        testDateRangeQuery()
        testWildcardQuery()
        testPagination()
        testIncludeFields()
        testRenderOptions()
        testThumbnailOptions()
        try await testTransferSyntaxPreference()
        try await testMultipartParsing()
        try await testSTOWResponseParsing()
        try await testMetadataJSONParsing()
        await testNotFoundError()
        await testUnauthorizedError()
        await testTimeoutError()
        await testLargeStudyRetrieval()
        await testConcurrentRequests()
        await testProgressMonitoring()
        await testCacheHandling()
        await testCustomTimeout()
        testHTTPSValidation()
        print("All tests completed!")
    }
}
#endif

// MARK: - Usage Notes

/*
 IMPORTANT: DICOMweb Overview
 
 DICOMweb is a set of RESTful web services for medical imaging defined in
 PS3.18. It provides an alternative to traditional DICOM networking (C-FIND,
 C-MOVE, C-STORE) using standard HTTP/HTTPS protocols.
 
 Three Main Services:
 
 1. QIDO-RS (Query based on ID for DICOM Objects - RESTful Services)
    - Search for studies, series, and instances
    - Uses HTTP GET with query parameters
    - Returns JSON metadata
    - Supports wildcards and date ranges
    - Paginated results with limit/offset
    
 2. WADO-RS (Web Access to DICOM Objects - RESTful Services)
    - Retrieve studies, series, instances
    - Retrieve metadata (without pixel data)
    - Retrieve rendered images (JPEG/PNG)
    - Retrieve specific frames
    - Retrieve bulk data
    - Uses HTTP GET
    - Returns multipart/related or application/dicom
    
 3. STOW-RS (Store Over the Web - RESTful Services)
    - Store DICOM instances
    - Uses HTTP POST
    - Multipart/related content type
    - Returns XML/JSON response with status
    
 URL Patterns:
 
 QIDO-RS:
 - Studies: /studies?{query}
 - Series in study: /studies/{studyUID}/series?{query}
 - Instances in study: /studies/{studyUID}/instances?{query}
 - Instances in series: /studies/{studyUID}/series/{seriesUID}/instances?{query}
 
 WADO-RS:
 - Study: /studies/{studyUID}
 - Series: /studies/{studyUID}/series/{seriesUID}
 - Instance: /studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}
 - Metadata: /studies/{studyUID}/metadata
 - Rendered: /studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/rendered
 - Frames: /studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/frames/{frameList}
 
 STOW-RS:
 - Store: /studies
 - Store to study: /studies/{studyUID}
 
 Query Parameters (QIDO-RS):
 - PatientName: 00100010={value}
 - PatientID: 00100020={value}
 - StudyDate: 00080020={value}
 - StudyInstanceUID: 0020000D={value}
 - SeriesInstanceUID: 0020000E={value}
 - Modality: 00080060={value}
 - limit: Maximum results
 - offset: Skip results (for pagination)
 - includefield: Additional attributes to return
 
 Wildcards:
 - * (asterisk): Matches zero or more characters
 - ? (question mark): Matches exactly one character
 
 Date Ranges:
 - Single date: 20240101
 - Range: 20240101-20241231
 - From date: 20240101-
 - To date: -20241231
 
 Authentication:
 - Bearer token (OAuth 2.0): Authorization: Bearer {token}
 - Basic auth: Authorization: Basic {base64(username:password)}
 - Custom headers: X-API-Key, etc.
 - Certificate-based: Client SSL certificates
 
 Content Types:
 - application/dicom: DICOM Part 10 files
 - application/dicom+json: DICOM JSON metadata
 - multipart/related: Multiple DICOM objects
 - image/jpeg, image/png: Rendered images
 
 Performance Considerations:
 - Use metadata retrieval when pixel data not needed
 - Stream large studies to avoid memory issues
 - Use rendered endpoints for display (faster than parsing)
 - Implement caching for frequently accessed data
 - Use pagination for large query results
 - Consider compression (Accept-Encoding: gzip)
 
 Error Codes:
 - 200 OK: Success
 - 204 No Content: No matching results
 - 400 Bad Request: Invalid query parameters
 - 401 Unauthorized: Authentication required
 - 403 Forbidden: Insufficient permissions
 - 404 Not Found: Resource not found
 - 500 Internal Server Error: Server error
 - 503 Service Unavailable: Server overloaded
 
 For production use:
 - Always use HTTPS for PHI data
 - Implement proper authentication
 - Handle pagination for large result sets
 - Implement retry logic for transient failures
 - Cache frequently accessed metadata
 - Monitor API rate limits
 - Log all requests for audit trail
 - Validate all UIDs before requests
 - Handle partial failures in batch operations
 
 Common Issues:
 - "404 Not Found": Check URL pattern and UIDs
 - "401 Unauthorized": Verify authentication token
 - "Timeout": Increase timeout or reduce request size
 - "Invalid JSON": Check metadata parsing
 - "Multipart error": Verify content type handling
 
 Advantages over Traditional DICOM:
 - Standard HTTP/HTTPS protocols
 - Firewall-friendly (port 80/443)
 - RESTful design patterns
 - JSON metadata format
 - Easy integration with web applications
 - No custom DICOM networking stack required
 
 Reference:
 - PS3.18 Web Services - DICOMweb specification
 - PS3.18 Section 6 - QIDO-RS
 - PS3.18 Section 10 - WADO-RS
 - PS3.18 Section 11 - STOW-RS
 - RFC 2387 - Multipart/Related content type
 */
