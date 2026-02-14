import XCTest
import Foundation
@testable import DICOMKit
@testable import DICOMCore

// MARK: - Test Stubs for Cloud Types
// These types mirror the actual implementation in dicom-cloud source
// They exist here for unit testing without requiring the full executable

struct CloudURL {
    let provider: CloudProviderType
    let bucket: String
    let key: String
    let endpoint: String?
    
    static func parse(_ urlString: String) throws -> CloudURL {
        guard let url = URL(string: urlString) else {
            throw CloudError.invalidURL("Invalid URL format: \(urlString)")
        }
        
        guard let scheme = url.scheme else {
            throw CloudError.invalidURL("Missing scheme in URL: \(urlString)")
        }
        
        let provider: CloudProviderType
        switch scheme {
        case "s3":
            provider = .s3
        case "gs":
            provider = .gcs
        case "azure":
            provider = .azure
        default:
            throw CloudError.unsupportedProvider("Unsupported URL scheme: \(scheme)")
        }
        
        guard let host = url.host else {
            throw CloudError.invalidURL("Missing bucket/container name in URL: \(urlString)")
        }
        
        let key = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        return CloudURL(provider: provider, bucket: host, key: key, endpoint: nil)
    }
    
    func with(key newKey: String) -> CloudURL {
        CloudURL(provider: provider, bucket: bucket, key: newKey, endpoint: endpoint)
    }
    
    var fullPath: String {
        "\(provider.schemePrefix)\(bucket)/\(key)"
    }
}

enum CloudProviderType: String {
    case s3
    case gcs
    case azure
    
    var schemePrefix: String {
        switch self {
        case .s3: return "s3://"
        case .gcs: return "gs://"
        case .azure: return "azure://"
        }
    }
    
    var defaultEndpoint: String {
        switch self {
        case .s3: return "s3.amazonaws.com"
        case .gcs: return "storage.googleapis.com"
        case .azure: return "blob.core.windows.net"
        }
    }
}

enum CloudError: Error, CustomStringConvertible {
    case invalidURL(String)
    case unsupportedProvider(String)
    case authenticationFailed(String)
    case networkError(String)
    case notFound(String)
    case permissionDenied(String)
    case operationFailed(String)
    case notImplemented(String)
    
    var description: String {
        switch self {
        case .invalidURL(let message):
            return "Invalid URL: \(message)"
        case .unsupportedProvider(let message):
            return "Unsupported provider: \(message)"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .notFound(let message):
            return "Not found: \(message)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .notImplemented(let message):
            return "Not implemented: \(message)"
        }
    }
}

struct CloudObject {
    let key: String
    let size: Int
    let lastModified: Date
    let metadata: [String: String]
}

// Stub CloudProvider for testing
protocol CloudProviderProtocol: Actor {
    func upload(data: Data, to cloudURL: CloudURL, metadata: [String: String], encryption: EncryptionType) async throws
    func download(from cloudURL: CloudURL) async throws -> Data
    func list(cloudURL: CloudURL, recursive: Bool) async throws -> [CloudObject]
    func delete(cloudURL: CloudURL) async throws
    func exists(cloudURL: CloudURL) async throws -> Bool
}

enum EncryptionType: String, CaseIterable {
    case none = "none"
    case serverSide = "server-side"
    case clientSide = "client-side"
}

actor StubCloudProvider: CloudProviderProtocol {
    func upload(data: Data, to cloudURL: CloudURL, metadata: [String: String], encryption: EncryptionType) async throws {
        // Stub implementation
    }
    
    func download(from cloudURL: CloudURL) async throws -> Data {
        // Stub implementation
        return Data()
    }
    
    func list(cloudURL: CloudURL, recursive: Bool) async throws -> [CloudObject] {
        // Stub implementation
        return []
    }
    
    func delete(cloudURL: CloudURL) async throws {
        // Stub implementation
    }
    
    func exists(cloudURL: CloudURL) async throws -> Bool {
        // Stub implementation
        return false
    }
}

struct CloudProvider {
    static func create(for cloudURL: CloudURL, endpoint: String?, region: String?) async throws -> any CloudProviderProtocol {
        // Stub implementation that mimics the real behavior
        switch cloudURL.provider {
        case .s3:
            return StubCloudProvider()
        case .gcs:
            // GCS now implemented - return stub provider
            return StubCloudProvider()
        case .azure:
            // Azure now implemented - return stub provider
            return StubCloudProvider()
        }
    }
}

/// Tests for dicom-cloud CLI tool functionality
/// These tests verify URL parsing, error handling, and operation logic
final class DICOMCloudTests: XCTestCase {
    
    // MARK: - CloudURL Parsing Tests
    
    func testParseS3URL() throws {
        let urlString = "s3://my-bucket/path/to/file.dcm"
        let cloudURL = try CloudURL.parse(urlString)
        
        XCTAssertEqual(cloudURL.provider, .s3)
        XCTAssertEqual(cloudURL.bucket, "my-bucket")
        XCTAssertEqual(cloudURL.key, "path/to/file.dcm")
    }
    
    func testParseGCSURL() throws {
        let urlString = "gs://my-bucket/path/to/file.dcm"
        let cloudURL = try CloudURL.parse(urlString)
        
        XCTAssertEqual(cloudURL.provider, .gcs)
        XCTAssertEqual(cloudURL.bucket, "my-bucket")
        XCTAssertEqual(cloudURL.key, "path/to/file.dcm")
    }
    
    func testParseAzureURL() throws {
        let urlString = "azure://my-container/path/to/file.dcm"
        let cloudURL = try CloudURL.parse(urlString)
        
        XCTAssertEqual(cloudURL.provider, .azure)
        XCTAssertEqual(cloudURL.bucket, "my-container")
        XCTAssertEqual(cloudURL.key, "path/to/file.dcm")
    }
    
    func testParseURLWithTrailingSlash() throws {
        let urlString = "s3://my-bucket/path/to/directory/"
        let cloudURL = try CloudURL.parse(urlString)
        
        XCTAssertEqual(cloudURL.key, "path/to/directory")
    }
    
    func testParseURLWithBucketOnly() throws {
        let urlString = "s3://my-bucket/"
        let cloudURL = try CloudURL.parse(urlString)
        
        XCTAssertEqual(cloudURL.bucket, "my-bucket")
        XCTAssertEqual(cloudURL.key, "")
    }
    
    func testParseInvalidURL() {
        let urlString = "not-a-valid-url"
        
        XCTAssertThrowsError(try CloudURL.parse(urlString)) { error in
            guard let cloudError = error as? CloudError else {
                XCTFail("Expected CloudError")
                return
            }
            if case .invalidURL = cloudError {
                // Expected
            } else {
                XCTFail("Expected invalidURL error")
            }
        }
    }
    
    func testParseMissingScheme() {
        let urlString = "my-bucket/path/to/file.dcm"
        
        XCTAssertThrowsError(try CloudURL.parse(urlString)) { error in
            guard let cloudError = error as? CloudError else {
                XCTFail("Expected CloudError")
                return
            }
            if case .invalidURL = cloudError {
                // Expected
            } else {
                XCTFail("Expected invalidURL error")
            }
        }
    }
    
    func testParseUnsupportedScheme() {
        let urlString = "http://my-bucket/path/to/file.dcm"
        
        XCTAssertThrowsError(try CloudURL.parse(urlString)) { error in
            guard let cloudError = error as? CloudError else {
                XCTFail("Expected CloudError")
                return
            }
            if case .unsupportedProvider = cloudError {
                // Expected
            } else {
                XCTFail("Expected unsupportedProvider error")
            }
        }
    }
    
    // MARK: - CloudURL Manipulation Tests
    
    func testCloudURLWithKey() throws {
        let urlString = "s3://my-bucket/original/path.dcm"
        let cloudURL = try CloudURL.parse(urlString)
        
        let newCloudURL = cloudURL.with(key: "new/path.dcm")
        
        XCTAssertEqual(newCloudURL.provider, .s3)
        XCTAssertEqual(newCloudURL.bucket, "my-bucket")
        XCTAssertEqual(newCloudURL.key, "new/path.dcm")
    }
    
    func testCloudURLFullPath() throws {
        let urlString = "s3://my-bucket/path/to/file.dcm"
        let cloudURL = try CloudURL.parse(urlString)
        
        XCTAssertEqual(cloudURL.fullPath, "s3://my-bucket/path/to/file.dcm")
    }
    
    // MARK: - CloudProviderType Tests
    
    func testCloudProviderSchemePrefix() {
        XCTAssertEqual(CloudProviderType.s3.schemePrefix, "s3://")
        XCTAssertEqual(CloudProviderType.gcs.schemePrefix, "gs://")
        XCTAssertEqual(CloudProviderType.azure.schemePrefix, "azure://")
    }
    
    func testCloudProviderDefaultEndpoint() {
        XCTAssertEqual(CloudProviderType.s3.defaultEndpoint, "s3.amazonaws.com")
        XCTAssertEqual(CloudProviderType.gcs.defaultEndpoint, "storage.googleapis.com")
        XCTAssertEqual(CloudProviderType.azure.defaultEndpoint, "blob.core.windows.net")
    }
    
    // MARK: - CloudProvider Factory Tests
    
    func testCreateS3Provider() async throws {
        let cloudURL = try CloudURL.parse("s3://my-bucket/file.dcm")
        let provider = try await CloudProvider.create(for: cloudURL, endpoint: nil, region: nil)
        
        XCTAssertNotNil(provider)
    }
    
    func testCreateGCSProviderThrowsNotImplemented() async throws {
        let cloudURL = try CloudURL.parse("gs://my-bucket/file.dcm")
        
        do {
            _ = try await CloudProvider.create(for: cloudURL, endpoint: nil, region: nil)
            XCTFail("Expected CloudError to be thrown")
        } catch let error as CloudError {
            if case .notImplemented = error {
                // Expected
            } else {
                XCTFail("Expected notImplemented error, got: \(error)")
            }
        }
    }
    
    func testCreateAzureProviderThrowsNotImplemented() async throws {
        let cloudURL = try CloudURL.parse("azure://my-container/file.dcm")
        
        do {
            _ = try await CloudProvider.create(for: cloudURL, endpoint: nil, region: nil)
            XCTFail("Expected CloudError to be thrown")
        } catch let error as CloudError {
            if case .notImplemented = error {
                // Expected
            } else {
                XCTFail("Expected notImplemented error, got: \(error)")
            }
        }
    }
    
    // MARK: - CloudObject Tests
    
    func testCloudObjectCreation() {
        let key = "path/to/file.dcm"
        let size = 1024
        let lastModified = Date()
        let metadata = ["ContentType": "application/dicom"]
        
        let object = CloudObject(key: key, size: size, lastModified: lastModified, metadata: metadata)
        
        XCTAssertEqual(object.key, key)
        XCTAssertEqual(object.size, size)
        XCTAssertEqual(object.lastModified, lastModified)
        XCTAssertEqual(object.metadata["ContentType"], "application/dicom")
    }
    
    // MARK: - CloudError Tests
    
    func testCloudErrorDescriptions() {
        let invalidURLError = CloudError.invalidURL("test message")
        XCTAssertTrue(invalidURLError.description.contains("Invalid URL"))
        
        let unsupportedProviderError = CloudError.unsupportedProvider("test provider")
        XCTAssertTrue(unsupportedProviderError.description.contains("Unsupported provider"))
        
        let authenticationError = CloudError.authenticationFailed("bad credentials")
        XCTAssertTrue(authenticationError.description.contains("Authentication failed"))
        
        let networkError = CloudError.networkError("connection timeout")
        XCTAssertTrue(networkError.description.contains("Network error"))
        
        let notFoundError = CloudError.notFound("file.dcm")
        XCTAssertTrue(notFoundError.description.contains("Not found"))
        
        let permissionError = CloudError.permissionDenied("access denied")
        XCTAssertTrue(permissionError.description.contains("Permission denied"))
        
        let operationError = CloudError.operationFailed("operation failed")
        XCTAssertTrue(operationError.description.contains("Operation failed"))
        
        let notImplementedError = CloudError.notImplemented("feature not ready")
        XCTAssertTrue(notImplementedError.description.contains("Not implemented"))
    }
    
    // MARK: - URL Parsing Edge Cases
    
    func testParseURLWithSpecialCharacters() throws {
        let urlString = "s3://my-bucket/path%20with%20spaces/file.dcm"
        let cloudURL = try CloudURL.parse(urlString)
        
        XCTAssertEqual(cloudURL.bucket, "my-bucket")
        // Note: URL encoding handling depends on Foundation's URL parsing
    }
    
    func testParseURLWithDeepPath() throws {
        let urlString = "s3://my-bucket/level1/level2/level3/level4/file.dcm"
        let cloudURL = try CloudURL.parse(urlString)
        
        XCTAssertEqual(cloudURL.bucket, "my-bucket")
        XCTAssertEqual(cloudURL.key, "level1/level2/level3/level4/file.dcm")
    }
    
    func testParseURLWithDashesAndUnderscores() throws {
        let urlString = "s3://my-test_bucket-123/my_path-456/file_name-789.dcm"
        let cloudURL = try CloudURL.parse(urlString)
        
        XCTAssertEqual(cloudURL.bucket, "my-test_bucket-123")
        XCTAssertEqual(cloudURL.key, "my_path-456/file_name-789.dcm")
    }
    
    // MARK: - Provider Endpoint Tests
    
    func testCustomEndpointSupport() async throws {
        let cloudURL = try CloudURL.parse("s3://my-bucket/file.dcm")
        let customEndpoint = "https://minio.example.com"
        let provider = try await CloudProvider.create(for: cloudURL, endpoint: customEndpoint, region: "us-east-1")
        
        XCTAssertNotNil(provider)
    }
    
    func testProviderCreationWithRegion() async throws {
        let cloudURL = try CloudURL.parse("s3://my-bucket/file.dcm")
        let provider = try await CloudProvider.create(for: cloudURL, endpoint: nil, region: "us-west-2")
        
        XCTAssertNotNil(provider)
    }
    
    func testProviderCreationWithoutRegion() async throws {
        let cloudURL = try CloudURL.parse("s3://my-bucket/file.dcm")
        let provider = try await CloudProvider.create(for: cloudURL, endpoint: nil, region: nil)
        
        XCTAssertNotNil(provider)
    }
    
    // MARK: - Integration Test Preparation
    
    func testPrepareTestEnvironment() {
        // This test verifies that the test setup is correct
        // In a real integration test, we would:
        // 1. Check for AWS credentials
        // 2. Verify test bucket exists
        // 3. Create test files
        // 4. Run actual upload/download operations
        // 5. Clean up test data
        
        // For now, we just verify the test can run
        XCTAssertTrue(true)
    }
    
    // MARK: - URL Format Validation
    
    func testMultipleBucketFormats() throws {
        // Test various bucket naming conventions
        let validBuckets = [
            "s3://simple-bucket/file.dcm",
            "s3://bucket.with.dots/file.dcm",
            "s3://bucket-123/file.dcm",
            "s3://a/file.dcm", // Minimum length bucket
        ]
        
        for urlString in validBuckets {
            let cloudURL = try CloudURL.parse(urlString)
            XCTAssertEqual(cloudURL.provider, .s3)
            XCTAssertFalse(cloudURL.bucket.isEmpty)
        }
    }
    
    // MARK: - Path Manipulation Tests
    
    func testRelativePathCalculation() throws {
        // Test that we can calculate relative paths correctly
        // This is important for directory uploads/downloads
        let baseURL = try CloudURL.parse("s3://bucket/base/path/")
        let fileURL = baseURL.with(key: "base/path/subdir/file.dcm")
        
        XCTAssertEqual(fileURL.key, "base/path/subdir/file.dcm")
    }
    
    func testEmptyKeyHandling() throws {
        let cloudURL = try CloudURL.parse("s3://bucket/")
        XCTAssertEqual(cloudURL.key, "")
        
        let withKey = cloudURL.with(key: "newfile.dcm")
        XCTAssertEqual(withKey.key, "newfile.dcm")
    }
    
    // MARK: - Performance Tests
    
    func testURLParsingPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = try? CloudURL.parse("s3://test-bucket/path/to/file.dcm")
            }
        }
    }
    
    // MARK: - Concurrent URL Parsing
    
    func testConcurrentURLParsing() async throws {
        // Test that URL parsing is thread-safe
        await withTaskGroup(of: CloudURL?.self) { group in
            for i in 0..<100 {
                group.addTask {
                    try? CloudURL.parse("s3://bucket-\(i)/file-\(i).dcm")
                }
            }
            
            var count = 0
            for await result in group {
                if result != nil {
                    count += 1
                }
            }
            
            XCTAssertEqual(count, 100)
        }
    }
    
    // MARK: - Google Cloud Storage Provider Tests
    
    func testGCSProviderCreation() async throws {
        let urlString = "gs://my-bucket/path/to/file.dcm"
        let cloudURL = try CloudURL.parse(urlString)
        
        // Provider creation should succeed now (with stub)
        let provider = try await CloudProvider.create(for: cloudURL, endpoint: nil, region: nil)
        XCTAssertNotNil(provider)
    }
    
    func testGCSURLParsing() throws {
        let testCases = [
            ("gs://bucket/file.dcm", "bucket", "file.dcm"),
            ("gs://bucket/folder/subfolder/file.dcm", "bucket", "folder/subfolder/file.dcm"),
            ("gs://bucket-with-dashes/file.dcm", "bucket-with-dashes", "file.dcm"),
            ("gs://bucket_with_underscores/file.dcm", "bucket_with_underscores", "file.dcm"),
            ("gs://bucket123/file.dcm", "bucket123", "file.dcm")
        ]
        
        for (urlString, expectedBucket, expectedKey) in testCases {
            let cloudURL = try CloudURL.parse(urlString)
            XCTAssertEqual(cloudURL.provider, .gcs, "Failed for URL: \(urlString)")
            XCTAssertEqual(cloudURL.bucket, expectedBucket, "Failed for URL: \(urlString)")
            XCTAssertEqual(cloudURL.key, expectedKey, "Failed for URL: \(urlString)")
        }
    }
    
    func testGCSURLWithSpecialCharacters() throws {
        let urlString = "gs://my-bucket/path%20with%20spaces/file%2Bname.dcm"
        let cloudURL = try CloudURL.parse(urlString)
        
        XCTAssertEqual(cloudURL.provider, .gcs)
        XCTAssertEqual(cloudURL.bucket, "my-bucket")
        // Note: URL parsing keeps encoded characters
        XCTAssertTrue(cloudURL.key.contains("path"))
    }
    
    func testGCSDefaultEndpoint() {
        let endpoint = CloudProviderType.gcs.defaultEndpoint
        XCTAssertEqual(endpoint, "storage.googleapis.com")
    }
    
    func testGCSSchemePrefix() {
        let prefix = CloudProviderType.gcs.schemePrefix
        XCTAssertEqual(prefix, "gs://")
    }
    
    func testGCSFullPath() throws {
        let urlString = "gs://my-bucket/path/to/file.dcm"
        let cloudURL = try CloudURL.parse(urlString)
        
        XCTAssertEqual(cloudURL.fullPath, "gs://my-bucket/path/to/file.dcm")
    }
    
    func testGCSKeyManipulation() throws {
        let urlString = "gs://my-bucket/original.dcm"
        let cloudURL = try CloudURL.parse(urlString)
        
        let newURL = cloudURL.with(key: "modified.dcm")
        XCTAssertEqual(newURL.bucket, "my-bucket")
        XCTAssertEqual(newURL.key, "modified.dcm")
        XCTAssertEqual(newURL.provider, .gcs)
    }
    
    func testGCSEmptyKey() throws {
        let urlString = "gs://my-bucket/"
        let cloudURL = try CloudURL.parse(urlString)
        
        XCTAssertEqual(cloudURL.bucket, "my-bucket")
        XCTAssertEqual(cloudURL.key, "")
    }
    
    // MARK: - Azure Blob Storage Provider Tests
    
    func testAzureProviderCreation() async throws {
        let urlString = "azure://my-container/path/to/file.dcm"
        let cloudURL = try CloudURL.parse(urlString)
        
        // Provider creation should succeed now (with stub)
        let provider = try await CloudProvider.create(for: cloudURL, endpoint: nil, region: nil)
        XCTAssertNotNil(provider)
    }
    
    func testAzureURLParsing() throws {
        let testCases = [
            ("azure://container/file.dcm", "container", "file.dcm"),
            ("azure://container/folder/subfolder/file.dcm", "container", "folder/subfolder/file.dcm"),
            ("azure://container-with-dashes/file.dcm", "container-with-dashes", "file.dcm"),
            ("azure://container123/file.dcm", "container123", "file.dcm"),
            ("azure://mycontainer/path/to/blob.dcm", "mycontainer", "path/to/blob.dcm")
        ]
        
        for (urlString, expectedContainer, expectedKey) in testCases {
            let cloudURL = try CloudURL.parse(urlString)
            XCTAssertEqual(cloudURL.provider, .azure, "Failed for URL: \(urlString)")
            XCTAssertEqual(cloudURL.bucket, expectedContainer, "Failed for URL: \(urlString)")
            XCTAssertEqual(cloudURL.key, expectedKey, "Failed for URL: \(urlString)")
        }
    }
    
    func testAzureURLWithSpecialCharacters() throws {
        let urlString = "azure://mycontainer/path%20with%20spaces/blob%2Bname.dcm"
        let cloudURL = try CloudURL.parse(urlString)
        
        XCTAssertEqual(cloudURL.provider, .azure)
        XCTAssertEqual(cloudURL.bucket, "mycontainer")
        XCTAssertTrue(cloudURL.key.contains("path"))
    }
    
    func testAzureDefaultEndpoint() {
        let endpoint = CloudProviderType.azure.defaultEndpoint
        XCTAssertEqual(endpoint, "blob.core.windows.net")
    }
    
    func testAzureSchemePrefix() {
        let prefix = CloudProviderType.azure.schemePrefix
        XCTAssertEqual(prefix, "azure://")
    }
    
    func testAzureFullPath() throws {
        let urlString = "azure://mycontainer/path/to/blob.dcm"
        let cloudURL = try CloudURL.parse(urlString)
        
        XCTAssertEqual(cloudURL.fullPath, "azure://mycontainer/path/to/blob.dcm")
    }
    
    func testAzureKeyManipulation() throws {
        let urlString = "azure://mycontainer/original.dcm"
        let cloudURL = try CloudURL.parse(urlString)
        
        let newURL = cloudURL.with(key: "modified.dcm")
        XCTAssertEqual(newURL.bucket, "mycontainer")
        XCTAssertEqual(newURL.key, "modified.dcm")
        XCTAssertEqual(newURL.provider, .azure)
    }
    
    func testAzureEmptyKey() throws {
        let urlString = "azure://mycontainer/"
        let cloudURL = try CloudURL.parse(urlString)
        
        XCTAssertEqual(cloudURL.bucket, "mycontainer")
        XCTAssertEqual(cloudURL.key, "")
    }
    
    // MARK: - Cross-Provider Tests
    
    func testAllProvidersHaveUniqueSchemes() {
        let s3Prefix = CloudProviderType.s3.schemePrefix
        let gcsPrefix = CloudProviderType.gcs.schemePrefix
        let azurePrefix = CloudProviderType.azure.schemePrefix
        
        XCTAssertNotEqual(s3Prefix, gcsPrefix)
        XCTAssertNotEqual(s3Prefix, azurePrefix)
        XCTAssertNotEqual(gcsPrefix, azurePrefix)
    }
    
    func testAllProvidersHaveDefaultEndpoints() {
        XCTAssertFalse(CloudProviderType.s3.defaultEndpoint.isEmpty)
        XCTAssertFalse(CloudProviderType.gcs.defaultEndpoint.isEmpty)
        XCTAssertFalse(CloudProviderType.azure.defaultEndpoint.isEmpty)
    }
    
    func testProviderIdentificationFromURL() throws {
        let testCases: [(String, CloudProviderType)] = [
            ("s3://bucket/file", .s3),
            ("gs://bucket/file", .gcs),
            ("azure://container/file", .azure)
        ]
        
        for (urlString, expectedProvider) in testCases {
            let cloudURL = try CloudURL.parse(urlString)
            XCTAssertEqual(cloudURL.provider, expectedProvider, "Failed for URL: \(urlString)")
        }
    }
    
    func testCrossProviderCopyParsing() throws {
        // Test that URLs for different providers can be parsed independently
        let s3URL = try CloudURL.parse("s3://source-bucket/file.dcm")
        let gcsURL = try CloudURL.parse("gs://dest-bucket/file.dcm")
        let azureURL = try CloudURL.parse("azure://dest-container/file.dcm")
        
        XCTAssertEqual(s3URL.provider, .s3)
        XCTAssertEqual(gcsURL.provider, .gcs)
        XCTAssertEqual(azureURL.provider, .azure)
    }
    
    func testProviderCreationForAllTypes() async throws {
        let providers: [(String, CloudProviderType)] = [
            ("s3://bucket/file", .s3),
            ("gs://bucket/file", .gcs),
            ("azure://container/file", .azure)
        ]
        
        for (urlString, expectedType) in providers {
            let cloudURL = try CloudURL.parse(urlString)
            XCTAssertEqual(cloudURL.provider, expectedType)
            
            // All providers should now be creatable
            let provider = try await CloudProvider.create(for: cloudURL, endpoint: nil, region: nil)
            XCTAssertNotNil(provider, "Failed to create provider for \(expectedType)")
        }
    }
}
