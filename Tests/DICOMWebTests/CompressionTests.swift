import XCTest
@testable import DICOMWeb

/// Tests for HTTP compression middleware
final class CompressionTests: XCTestCase {
    
    // MARK: - Compression Availability Check
    
    /// Check if compression is available on the current platform
    private var isCompressionAvailable: Bool {
        let middleware = CompressionMiddleware()
        let testData = String(repeating: "Test data ", count: 100).data(using: .utf8)!
        return middleware.compress(data: testData, using: .gzip) != nil ||
               middleware.compress(data: testData, using: .deflate) != nil
    }
    
    // MARK: - CompressionConfiguration Tests
    
    func test_CompressionConfiguration_default() {
        let config = CompressionConfiguration.default
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.algorithms, [.gzip, .deflate])
        XCTAssertEqual(config.minimumSize, 1024)
        XCTAssertEqual(config.level, 6)
    }
    
    func test_CompressionConfiguration_disabled() {
        let config = CompressionConfiguration.disabled
        XCTAssertFalse(config.enabled)
    }
    
    func test_CompressionConfiguration_highCompression() {
        let config = CompressionConfiguration.highCompression
        XCTAssertEqual(config.level, 9)
        XCTAssertEqual(config.minimumSize, 512)
    }
    
    func test_CompressionConfiguration_fast() {
        let config = CompressionConfiguration.fast
        XCTAssertEqual(config.level, 1)
        XCTAssertEqual(config.minimumSize, 2048)
    }
    
    func test_CompressionConfiguration_customInit() {
        let config = CompressionConfiguration(
            enabled: true,
            algorithms: [.deflate],
            minimumSize: 2048,
            level: 8
        )
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.algorithms, [.deflate])
        XCTAssertEqual(config.minimumSize, 2048)
        XCTAssertEqual(config.level, 8)
    }
    
    func test_CompressionConfiguration_levelClamping() {
        // Test level is clamped to valid range
        let configLow = CompressionConfiguration(level: -5)
        XCTAssertEqual(configLow.level, 0)
        
        let configHigh = CompressionConfiguration(level: 100)
        XCTAssertEqual(configHigh.level, 9)
    }
    
    func test_CompressionConfiguration_minimumSizeClamping() {
        // Test minimum size is clamped to 0 or greater
        let config = CompressionConfiguration(minimumSize: -100)
        XCTAssertEqual(config.minimumSize, 0)
    }
    
    func test_CompressionConfiguration_defaultExcludedTypes() {
        let excludedTypes = CompressionConfiguration.defaultExcludedTypes
        XCTAssertTrue(excludedTypes.contains("image/jpeg"))
        XCTAssertTrue(excludedTypes.contains("image/png"))
        XCTAssertTrue(excludedTypes.contains("video/mp4"))
        XCTAssertTrue(excludedTypes.contains("application/gzip"))
    }
    
    func test_CompressionConfiguration_dicomwebCompressibleTypes() {
        let compressible = CompressionConfiguration.dicomwebCompressibleTypes
        XCTAssertTrue(compressible.contains("application/dicom+json"))
        XCTAssertTrue(compressible.contains("application/json"))
        XCTAssertTrue(compressible.contains("application/dicom"))
    }
    
    // MARK: - CompressionAlgorithm Tests
    
    func test_CompressionAlgorithm_headerValue() {
        XCTAssertEqual(CompressionAlgorithm.gzip.headerValue, "gzip")
        XCTAssertEqual(CompressionAlgorithm.deflate.headerValue, "deflate")
    }
    
    func test_CompressionAlgorithm_parse() {
        XCTAssertEqual(CompressionAlgorithm.parse("gzip"), .gzip)
        XCTAssertEqual(CompressionAlgorithm.parse("GZIP"), .gzip)
        XCTAssertEqual(CompressionAlgorithm.parse("deflate"), .deflate)
        XCTAssertEqual(CompressionAlgorithm.parse("gzip;q=0.8"), .gzip)
        XCTAssertNil(CompressionAlgorithm.parse("br")) // Brotli not supported
        XCTAssertNil(CompressionAlgorithm.parse("identity"))
    }
    
    // MARK: - AcceptEncodingEntry Tests
    
    func test_AcceptEncodingEntry_parse_simple() {
        let entry = AcceptEncodingEntry.parse("gzip")
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.algorithm, .gzip)
        XCTAssertEqual(entry?.quality, 1.0)
    }
    
    func test_AcceptEncodingEntry_parse_withQuality() {
        let entry = AcceptEncodingEntry.parse("gzip;q=0.8")
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.algorithm, .gzip)
        XCTAssertEqual(entry?.quality, 0.8)
    }
    
    func test_AcceptEncodingEntry_parse_withQualitySpaces() {
        let entry = AcceptEncodingEntry.parse("  deflate ; q=0.5  ")
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.algorithm, .deflate)
        XCTAssertEqual(entry?.quality, 0.5)
    }
    
    func test_AcceptEncodingEntry_parse_invalid() {
        XCTAssertNil(AcceptEncodingEntry.parse("br"))
        XCTAssertNil(AcceptEncodingEntry.parse("invalid"))
    }
    
    func test_AcceptEncodingEntry_qualityClamping() {
        // Quality should be clamped to 0.0-1.0
        let entry = AcceptEncodingEntry(algorithm: .gzip, quality: 2.0)
        XCTAssertEqual(entry.quality, 1.0)
        
        let entryLow = AcceptEncodingEntry(algorithm: .gzip, quality: -0.5)
        XCTAssertEqual(entryLow.quality, 0.0)
    }
    
    // MARK: - CompressionMiddleware Accept-Encoding Parsing Tests
    
    func test_parseAcceptEncoding_empty() {
        let middleware = CompressionMiddleware()
        let entries = middleware.parseAcceptEncoding(nil)
        XCTAssertTrue(entries.isEmpty)
        
        let entriesEmpty = middleware.parseAcceptEncoding("")
        XCTAssertTrue(entriesEmpty.isEmpty)
    }
    
    func test_parseAcceptEncoding_single() {
        let middleware = CompressionMiddleware()
        let entries = middleware.parseAcceptEncoding("gzip")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].algorithm, .gzip)
        XCTAssertEqual(entries[0].quality, 1.0)
    }
    
    func test_parseAcceptEncoding_multiple() {
        let middleware = CompressionMiddleware()
        let entries = middleware.parseAcceptEncoding("gzip, deflate")
        XCTAssertEqual(entries.count, 2)
    }
    
    func test_parseAcceptEncoding_withQualityValues() {
        let middleware = CompressionMiddleware()
        let entries = middleware.parseAcceptEncoding("gzip;q=1.0, deflate;q=0.8")
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].algorithm, .gzip) // Highest quality first
        XCTAssertEqual(entries[0].quality, 1.0)
        XCTAssertEqual(entries[1].algorithm, .deflate)
        XCTAssertEqual(entries[1].quality, 0.8)
    }
    
    func test_parseAcceptEncoding_sortedByQuality() {
        let middleware = CompressionMiddleware()
        let entries = middleware.parseAcceptEncoding("deflate;q=0.9, gzip;q=1.0")
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].algorithm, .gzip) // Higher quality first
        XCTAssertEqual(entries[1].algorithm, .deflate)
    }
    
    func test_parseAcceptEncoding_excludesZeroQuality() {
        let middleware = CompressionMiddleware()
        let entries = middleware.parseAcceptEncoding("gzip;q=0, deflate;q=0.5")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].algorithm, .deflate)
    }
    
    func test_parseAcceptEncoding_ignoresUnsupported() {
        let middleware = CompressionMiddleware()
        let entries = middleware.parseAcceptEncoding("br, gzip, identity")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].algorithm, .gzip)
    }
    
    // MARK: - Algorithm Selection Tests
    
    func test_selectAlgorithm_clientPreference() {
        let middleware = CompressionMiddleware()
        let algorithm = middleware.selectAlgorithm(acceptEncoding: "gzip")
        XCTAssertEqual(algorithm, .gzip)
    }
    
    func test_selectAlgorithm_clientPreferenceMultiple() {
        let middleware = CompressionMiddleware()
        let algorithm = middleware.selectAlgorithm(acceptEncoding: "deflate;q=1.0, gzip;q=0.8")
        XCTAssertEqual(algorithm, .deflate) // Client prefers deflate
    }
    
    func test_selectAlgorithm_serverPreference() {
        // Server prefers gzip over deflate
        let config = CompressionConfiguration(algorithms: [.gzip, .deflate])
        let middleware = CompressionMiddleware(configuration: config)
        
        // Client accepts both equally
        let algorithm = middleware.selectAlgorithm(acceptEncoding: "gzip, deflate")
        XCTAssertEqual(algorithm, .gzip) // First in client list that server supports
    }
    
    func test_selectAlgorithm_noMatch() {
        let config = CompressionConfiguration(algorithms: [.gzip])
        let middleware = CompressionMiddleware(configuration: config)
        
        // Client only accepts deflate
        let algorithm = middleware.selectAlgorithm(acceptEncoding: "deflate")
        XCTAssertNil(algorithm)
    }
    
    func test_selectAlgorithm_disabled() {
        let config = CompressionConfiguration.disabled
        let middleware = CompressionMiddleware(configuration: config)
        
        let algorithm = middleware.selectAlgorithm(acceptEncoding: "gzip, deflate")
        XCTAssertNil(algorithm)
    }
    
    func test_selectAlgorithm_noClientHeader() {
        let middleware = CompressionMiddleware()
        let algorithm = middleware.selectAlgorithm(acceptEncoding: nil)
        XCTAssertNil(algorithm)
    }
    
    // MARK: - Content Type Compression Tests
    
    func test_shouldCompress_json() {
        let middleware = CompressionMiddleware()
        XCTAssertTrue(middleware.shouldCompress(contentType: "application/json"))
        XCTAssertTrue(middleware.shouldCompress(contentType: "application/dicom+json"))
        XCTAssertTrue(middleware.shouldCompress(contentType: "application/json; charset=utf-8"))
    }
    
    func test_shouldCompress_xml() {
        let middleware = CompressionMiddleware()
        XCTAssertTrue(middleware.shouldCompress(contentType: "application/xml"))
        XCTAssertTrue(middleware.shouldCompress(contentType: "application/dicom+xml"))
        XCTAssertTrue(middleware.shouldCompress(contentType: "text/xml"))
    }
    
    func test_shouldCompress_text() {
        let middleware = CompressionMiddleware()
        XCTAssertTrue(middleware.shouldCompress(contentType: "text/plain"))
        XCTAssertTrue(middleware.shouldCompress(contentType: "text/html"))
    }
    
    func test_shouldCompress_dicom() {
        let middleware = CompressionMiddleware()
        XCTAssertTrue(middleware.shouldCompress(contentType: "application/dicom"))
    }
    
    func test_shouldNotCompress_images() {
        let middleware = CompressionMiddleware()
        XCTAssertFalse(middleware.shouldCompress(contentType: "image/jpeg"))
        XCTAssertFalse(middleware.shouldCompress(contentType: "image/png"))
        XCTAssertFalse(middleware.shouldCompress(contentType: "image/gif"))
    }
    
    func test_shouldNotCompress_compressedFormats() {
        let middleware = CompressionMiddleware()
        XCTAssertFalse(middleware.shouldCompress(contentType: "application/gzip"))
        XCTAssertFalse(middleware.shouldCompress(contentType: "application/zip"))
        XCTAssertFalse(middleware.shouldCompress(contentType: "video/mp4"))
    }
    
    func test_shouldNotCompress_nil() {
        let middleware = CompressionMiddleware()
        XCTAssertFalse(middleware.shouldCompress(contentType: nil))
    }
    
    func test_shouldCompress_customCompressibleTypes() {
        let config = CompressionConfiguration(
            compressibleTypes: Set(["application/custom"])
        )
        let middleware = CompressionMiddleware(configuration: config)
        
        XCTAssertTrue(middleware.shouldCompress(contentType: "application/custom"))
        XCTAssertFalse(middleware.shouldCompress(contentType: "application/json"))
    }
    
    // MARK: - Response Compression Tests (Platform-dependent)
    
    func test_compressResponse_compressesJSON() throws {
        try XCTSkipUnless(isCompressionAvailable, "Compression not available on this platform")
        
        let middleware = CompressionMiddleware()
        let largeJSON = String(repeating: "{\"key\": \"value\"}", count: 200)
        let response = DICOMwebResponse.ok(
            json: largeJSON.data(using: .utf8)!,
            headers: [:]
        )
        
        let compressed = middleware.compressResponse(response, acceptEncoding: "gzip")
        
        XCTAssertEqual(compressed.headers["Content-Encoding"], "gzip")
        XCTAssertNotNil(compressed.headers["Vary"])
        XCTAssertTrue(compressed.headers["Vary"]!.contains("Accept-Encoding"))
        XCTAssertLessThan(compressed.body!.count, response.body!.count)
    }
    
    func test_compressResponse_deflate() throws {
        try XCTSkipUnless(isCompressionAvailable, "Compression not available on this platform")
        
        let middleware = CompressionMiddleware()
        let largeText = String(repeating: "Hello, World! ", count: 200)
        let response = DICOMwebResponse(
            statusCode: 200,
            headers: ["Content-Type": "text/plain"],
            body: largeText.data(using: .utf8)
        )
        
        let compressed = middleware.compressResponse(response, acceptEncoding: "deflate")
        
        XCTAssertEqual(compressed.headers["Content-Encoding"], "deflate")
        XCTAssertLessThan(compressed.body!.count, response.body!.count)
    }
    
    func test_compressResponse_skipsSmallResponses() {
        let config = CompressionConfiguration(minimumSize: 1024)
        let middleware = CompressionMiddleware(configuration: config)
        
        let smallJSON = "{\"small\": true}"
        let response = DICOMwebResponse.ok(json: smallJSON.data(using: .utf8)!)
        
        let result = middleware.compressResponse(response, acceptEncoding: "gzip")
        
        XCTAssertNil(result.headers["Content-Encoding"])
        XCTAssertEqual(result.body, response.body)
    }
    
    func test_compressResponse_skipsWhenDisabled() {
        let config = CompressionConfiguration.disabled
        let middleware = CompressionMiddleware(configuration: config)
        
        let largeJSON = String(repeating: "{\"key\": \"value\"}", count: 200)
        let response = DICOMwebResponse.ok(json: largeJSON.data(using: .utf8)!)
        
        let result = middleware.compressResponse(response, acceptEncoding: "gzip")
        
        XCTAssertNil(result.headers["Content-Encoding"])
        XCTAssertEqual(result.body, response.body)
    }
    
    func test_compressResponse_skipsAlreadyCompressed() {
        let middleware = CompressionMiddleware()
        let data = Data(repeating: 0x00, count: 2000)
        let response = DICOMwebResponse(
            statusCode: 200,
            headers: ["Content-Type": "text/plain", "Content-Encoding": "gzip"],
            body: data
        )
        
        let result = middleware.compressResponse(response, acceptEncoding: "gzip")
        
        XCTAssertEqual(result.headers["Content-Encoding"], "gzip") // Original preserved
        XCTAssertEqual(result.body, response.body)
    }
    
    func test_compressResponse_skipsUncompressibleTypes() {
        let middleware = CompressionMiddleware()
        let imageData = Data(repeating: 0xFF, count: 2000)
        let response = DICOMwebResponse(
            statusCode: 200,
            headers: ["Content-Type": "image/jpeg"],
            body: imageData
        )
        
        let result = middleware.compressResponse(response, acceptEncoding: "gzip")
        
        XCTAssertNil(result.headers["Content-Encoding"])
        XCTAssertEqual(result.body, response.body)
    }
    
    func test_compressResponse_noAcceptEncoding() {
        let middleware = CompressionMiddleware()
        let largeJSON = String(repeating: "{\"key\": \"value\"}", count: 200)
        let response = DICOMwebResponse.ok(json: largeJSON.data(using: .utf8)!)
        
        let result = middleware.compressResponse(response, acceptEncoding: nil)
        
        XCTAssertNil(result.headers["Content-Encoding"])
    }
    
    func test_compressResponse_noBody() {
        let middleware = CompressionMiddleware()
        let response = DICOMwebResponse.noContent()
        
        let result = middleware.compressResponse(response, acceptEncoding: "gzip")
        
        XCTAssertNil(result.headers["Content-Encoding"])
    }
    
    func test_compressResponse_updatesContentLength() throws {
        try XCTSkipUnless(isCompressionAvailable, "Compression not available on this platform")
        
        let middleware = CompressionMiddleware()
        let largeText = String(repeating: "Compress me! ", count: 200)
        let response = DICOMwebResponse(
            statusCode: 200,
            headers: ["Content-Type": "text/plain", "Content-Length": "\(largeText.count)"],
            body: largeText.data(using: .utf8)
        )
        
        let compressed = middleware.compressResponse(response, acceptEncoding: "gzip")
        
        if let body = compressed.body {
            XCTAssertEqual(compressed.headers["Content-Length"], "\(body.count)")
        }
    }
    
    // MARK: - Compression/Decompression Round Trip Tests (Platform-dependent)
    
    func test_gzip_roundTrip() throws {
        try XCTSkipUnless(isCompressionAvailable, "Compression not available on this platform")
        
        let middleware = CompressionMiddleware()
        let originalData = String(repeating: "Test data for compression ", count: 100).data(using: .utf8)!
        
        // Compress
        guard let compressed = middleware.compress(data: originalData, using: .gzip) else {
            XCTFail("Compression failed")
            return
        }
        
        XCTAssertLessThan(compressed.count, originalData.count, "Compressed data should be smaller")
        
        // Decompress
        guard let decompressed = middleware.decompress(data: compressed, using: .gzip) else {
            XCTFail("Decompression failed")
            return
        }
        
        XCTAssertEqual(decompressed, originalData, "Round-trip should produce identical data")
    }
    
    func test_deflate_roundTrip() throws {
        try XCTSkipUnless(isCompressionAvailable, "Compression not available on this platform")
        
        let middleware = CompressionMiddleware()
        let originalData = String(repeating: "Test data for deflate compression ", count: 100).data(using: .utf8)!
        
        // Compress
        guard let compressed = middleware.compress(data: originalData, using: .deflate) else {
            XCTFail("Compression failed")
            return
        }
        
        XCTAssertLessThan(compressed.count, originalData.count, "Compressed data should be smaller")
        
        // Decompress
        guard let decompressed = middleware.decompress(data: compressed, using: .deflate) else {
            XCTFail("Decompression failed")
            return
        }
        
        XCTAssertEqual(decompressed, originalData, "Round-trip should produce identical data")
    }
    
    // MARK: - Vary Header Tests (Platform-dependent)
    
    func test_compressResponse_addsVaryHeader() throws {
        try XCTSkipUnless(isCompressionAvailable, "Compression not available on this platform")
        
        let middleware = CompressionMiddleware()
        let largeText = String(repeating: "Test ", count: 500)
        let response = DICOMwebResponse(
            statusCode: 200,
            headers: ["Content-Type": "text/plain"],
            body: largeText.data(using: .utf8)
        )
        
        let compressed = middleware.compressResponse(response, acceptEncoding: "gzip")
        
        XCTAssertEqual(compressed.headers["Vary"], "Accept-Encoding")
    }
    
    func test_compressResponse_appendsToExistingVaryHeader() throws {
        try XCTSkipUnless(isCompressionAvailable, "Compression not available on this platform")
        
        let middleware = CompressionMiddleware()
        let largeText = String(repeating: "Test ", count: 500)
        let response = DICOMwebResponse(
            statusCode: 200,
            headers: ["Content-Type": "text/plain", "Vary": "Origin"],
            body: largeText.data(using: .utf8)
        )
        
        let compressed = middleware.compressResponse(response, acceptEncoding: "gzip")
        
        XCTAssertTrue(compressed.headers["Vary"]!.contains("Origin"))
        XCTAssertTrue(compressed.headers["Vary"]!.contains("Accept-Encoding"))
    }
    
    func test_compressResponse_doesNotDuplicateVaryHeader() throws {
        try XCTSkipUnless(isCompressionAvailable, "Compression not available on this platform")
        
        let middleware = CompressionMiddleware()
        let largeText = String(repeating: "Test ", count: 500)
        let response = DICOMwebResponse(
            statusCode: 200,
            headers: ["Content-Type": "text/plain", "Vary": "Accept-Encoding"],
            body: largeText.data(using: .utf8)
        )
        
        let compressed = middleware.compressResponse(response, acceptEncoding: "gzip")
        
        // Should not duplicate
        let varyOccurrences = compressed.headers["Vary"]!.lowercased()
            .components(separatedBy: "accept-encoding").count - 1
        XCTAssertEqual(varyOccurrences, 1)
    }
    
    // MARK: - DICOMwebRequest Extension Tests
    
    func test_request_acceptEncoding() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["Accept-Encoding": "gzip, deflate"]
        )
        
        XCTAssertEqual(request.acceptEncoding, "gzip, deflate")
    }
    
    func test_request_acceptEncodingCaseInsensitive() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies",
            headers: ["accept-encoding": "gzip"]
        )
        
        XCTAssertEqual(request.acceptEncoding, "gzip")
    }
    
    func test_request_noAcceptEncoding() {
        let request = DICOMwebRequest(
            method: .get,
            path: "/studies"
        )
        
        XCTAssertNil(request.acceptEncoding)
    }
    
    // MARK: - Compression Availability Test
    
    func test_compression_availabilityCheck() {
        // This test just documents the compression availability on this platform
        let middleware = CompressionMiddleware()
        let testData = String(repeating: "Test ", count: 100).data(using: .utf8)!
        
        let gzipResult = middleware.compress(data: testData, using: .gzip)
        let deflateResult = middleware.compress(data: testData, using: .deflate)
        
        // Log the results (this is informational)
        if gzipResult == nil && deflateResult == nil {
            print("Note: HTTP compression is not available on this platform (Linux without Compression framework)")
        } else {
            print("HTTP compression is available on this platform")
        }
        
        // This test always passes - it's just for documentation
        XCTAssertTrue(true)
    }
}

