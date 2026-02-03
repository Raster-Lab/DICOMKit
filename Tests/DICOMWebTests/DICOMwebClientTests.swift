import Testing
import Foundation
@testable import DICOMWeb

@Suite("DICOMwebClient Tests")
struct DICOMwebClientTests {
    
    let testURL = URL(string: "https://pacs.example.com/dicom-web")!
    
    // MARK: - Initialization Tests
    
    @Test("Client initialization with configuration")
    func testClientInitWithConfiguration() {
        let config = DICOMwebConfiguration(baseURL: testURL)
        let client = DICOMwebClient(configuration: config)
        
        #expect(client.configuration.baseURL == testURL)
    }
    
    @Test("Client initialization with HTTP client")
    func testClientInitWithHTTPClient() {
        let config = DICOMwebConfiguration(baseURL: testURL)
        let httpClient = HTTPClient(configuration: config)
        let client = DICOMwebClient(httpClient: httpClient)
        
        #expect(client.configuration.baseURL == testURL)
    }
    
    @Test("URL builder accessible from client")
    func testClientURLBuilder() {
        let config = DICOMwebConfiguration(baseURL: testURL)
        let client = DICOMwebClient(configuration: config)
        
        let studyURL = client.urlBuilder.studyURL(studyUID: "1.2.3.4.5")
        #expect(studyURL.absoluteString == "https://pacs.example.com/dicom-web/studies/1.2.3.4.5")
    }
    
    // MARK: - RetrieveProgress Tests
    
    @Test("RetrieveProgress fraction with total bytes")
    func testProgressFractionWithBytes() {
        let progress = DICOMwebClient.RetrieveProgress(
            bytesReceived: 500,
            totalBytes: 1000,
            instancesReceived: 0,
            totalInstances: nil
        )
        
        #expect(progress.fractionCompleted == 0.5)
    }
    
    @Test("RetrieveProgress fraction with total instances")
    func testProgressFractionWithInstances() {
        let progress = DICOMwebClient.RetrieveProgress(
            bytesReceived: 0,
            totalBytes: nil,
            instancesReceived: 3,
            totalInstances: 10
        )
        
        #expect(progress.fractionCompleted == 0.3)
    }
    
    @Test("RetrieveProgress fraction with no totals")
    func testProgressFractionWithNoTotals() {
        let progress = DICOMwebClient.RetrieveProgress(
            bytesReceived: 100,
            totalBytes: nil,
            instancesReceived: 1,
            totalInstances: nil
        )
        
        #expect(progress.fractionCompleted == 0)
    }
    
    @Test("RetrieveProgress prefers bytes over instances")
    func testProgressPrefersBytesOverInstances() {
        let progress = DICOMwebClient.RetrieveProgress(
            bytesReceived: 250,
            totalBytes: 1000,
            instancesReceived: 9,
            totalInstances: 10
        )
        
        // Should use bytes: 250/1000 = 0.25, not instances: 9/10 = 0.9
        #expect(progress.fractionCompleted == 0.25)
    }
    
    // MARK: - RetrieveResult Tests
    
    @Test("RetrieveResult transfer syntax from content type")
    func testRetrieveResultTransferSyntax() {
        let contentType = DICOMMediaType.dicom(transferSyntax: "1.2.840.10008.1.2.1")
        let result = DICOMwebClient.RetrieveResult(
            instances: [Data()],
            contentType: contentType
        )
        
        #expect(result.transferSyntax == "1.2.840.10008.1.2.1")
    }
    
    @Test("RetrieveResult with no content type")
    func testRetrieveResultNoContentType() {
        let result = DICOMwebClient.RetrieveResult(
            instances: [Data()],
            contentType: nil
        )
        
        #expect(result.transferSyntax == nil)
    }
    
    // MARK: - FrameResult Tests
    
    @Test("FrameResult initialization")
    func testFrameResultInit() {
        let data = Data([0x01, 0x02, 0x03])
        let result = DICOMwebClient.FrameResult(
            frameNumber: 5,
            data: data,
            contentType: .jpeg
        )
        
        #expect(result.frameNumber == 5)
        #expect(result.data == data)
        #expect(result.contentType?.matches(.jpeg) == true)
    }
    
    // MARK: - RenderOptions Tests
    
    @Test("RenderOptions default initialization")
    func testRenderOptionsDefault() {
        let options = DICOMwebClient.RenderOptions.default
        
        #expect(options.windowCenter == nil)
        #expect(options.windowWidth == nil)
        #expect(options.viewportWidth == nil)
        #expect(options.viewportHeight == nil)
        #expect(options.quality == nil)
    }
    
    @Test("RenderOptions thumbnail preset")
    func testRenderOptionsThumbnail() {
        let options = DICOMwebClient.RenderOptions.thumbnail(size: 256)
        
        #expect(options.viewportWidth == 256)
        #expect(options.viewportHeight == 256)
        #expect(options.quality == 80)
    }
    
    @Test("RenderOptions custom initialization")
    func testRenderOptionsCustom() {
        let options = DICOMwebClient.RenderOptions(
            windowCenter: 40,
            windowWidth: 400,
            viewportWidth: 512,
            viewportHeight: 512,
            quality: 90,
            format: .png
        )
        
        #expect(options.windowCenter == 40)
        #expect(options.windowWidth == 400)
        #expect(options.viewportWidth == 512)
        #expect(options.viewportHeight == 512)
        #expect(options.quality == 90)
    }
    
    @Test("RenderOptions image format media types")
    func testRenderOptionsImageFormatMediaTypes() {
        let jpegOptions = DICOMwebClient.RenderOptions(format: .jpeg)
        let pngOptions = DICOMwebClient.RenderOptions(format: .png)
        let gifOptions = DICOMwebClient.RenderOptions(format: .gif)
        
        #expect(jpegOptions.format.mediaType.matches(.jpeg))
        #expect(pngOptions.format.mediaType.matches(.png))
        #expect(gifOptions.format.mediaType.matches(.gif))
    }
}

// MARK: - URL Building Tests

@Suite("DICOMwebClient URL Building Tests")
struct DICOMwebClientURLBuildingTests {
    
    let testURL = URL(string: "https://pacs.example.com/dicom-web")!
    
    @Test("Study URL construction")
    func testStudyURL() {
        let config = DICOMwebConfiguration(baseURL: testURL)
        let client = DICOMwebClient(configuration: config)
        
        let url = client.urlBuilder.studyURL(studyUID: "1.2.3.4.5")
        #expect(url.absoluteString == "https://pacs.example.com/dicom-web/studies/1.2.3.4.5")
    }
    
    @Test("Series URL construction")
    func testSeriesURL() {
        let config = DICOMwebConfiguration(baseURL: testURL)
        let client = DICOMwebClient(configuration: config)
        
        let url = client.urlBuilder.seriesURL(studyUID: "1.2.3", seriesUID: "1.2.3.4")
        #expect(url.absoluteString == "https://pacs.example.com/dicom-web/studies/1.2.3/series/1.2.3.4")
    }
    
    @Test("Instance URL construction")
    func testInstanceURL() {
        let config = DICOMwebConfiguration(baseURL: testURL)
        let client = DICOMwebClient(configuration: config)
        
        let url = client.urlBuilder.instanceURL(
            studyUID: "1.2.3",
            seriesUID: "1.2.3.4",
            instanceUID: "1.2.3.4.5"
        )
        #expect(url.absoluteString == "https://pacs.example.com/dicom-web/studies/1.2.3/series/1.2.3.4/instances/1.2.3.4.5")
    }
    
    @Test("Metadata URL construction")
    func testMetadataURL() {
        let config = DICOMwebConfiguration(baseURL: testURL)
        let client = DICOMwebClient(configuration: config)
        
        let studyMetadataURL = client.urlBuilder.studyMetadataURL(studyUID: "1.2.3")
        #expect(studyMetadataURL.absoluteString == "https://pacs.example.com/dicom-web/studies/1.2.3/metadata")
        
        let seriesMetadataURL = client.urlBuilder.seriesMetadataURL(studyUID: "1.2.3", seriesUID: "1.2.3.4")
        #expect(seriesMetadataURL.absoluteString == "https://pacs.example.com/dicom-web/studies/1.2.3/series/1.2.3.4/metadata")
    }
    
    @Test("Frames URL construction")
    func testFramesURL() {
        let config = DICOMwebConfiguration(baseURL: testURL)
        let client = DICOMwebClient(configuration: config)
        
        let url = client.urlBuilder.framesURL(
            studyUID: "1.2.3",
            seriesUID: "1.2.3.4",
            instanceUID: "1.2.3.4.5",
            frames: [1, 3, 5]
        )
        #expect(url.absoluteString.contains("/frames/1,3,5"))
    }
    
    @Test("Rendered URL construction")
    func testRenderedURL() {
        let config = DICOMwebConfiguration(baseURL: testURL)
        let client = DICOMwebClient(configuration: config)
        
        let url = client.urlBuilder.instanceRenderedURL(
            studyUID: "1.2.3",
            seriesUID: "1.2.3.4",
            instanceUID: "1.2.3.4.5"
        )
        #expect(url.absoluteString.contains("/rendered"))
    }
    
    @Test("Thumbnail URL construction")
    func testThumbnailURL() {
        let config = DICOMwebConfiguration(baseURL: testURL)
        let client = DICOMwebClient(configuration: config)
        
        let studyThumbnailURL = client.urlBuilder.studyThumbnailURL(studyUID: "1.2.3")
        #expect(studyThumbnailURL.absoluteString.contains("/thumbnail"))
        
        let seriesThumbnailURL = client.urlBuilder.seriesThumbnailURL(studyUID: "1.2.3", seriesUID: "1.2.3.4")
        #expect(seriesThumbnailURL.absoluteString.contains("/thumbnail"))
        
        let instanceThumbnailURL = client.urlBuilder.instanceThumbnailURL(
            studyUID: "1.2.3",
            seriesUID: "1.2.3.4",
            instanceUID: "1.2.3.4.5"
        )
        #expect(instanceThumbnailURL.absoluteString.contains("/thumbnail"))
    }
    
    @Test("Bulk data URL construction")
    func testBulkdataURL() {
        let config = DICOMwebConfiguration(baseURL: testURL)
        let client = DICOMwebClient(configuration: config)
        
        let url = client.urlBuilder.bulkdataURL(
            studyUID: "1.2.3",
            seriesUID: "1.2.3.4",
            instanceUID: "1.2.3.4.5",
            attributePath: "7FE00010"
        )
        #expect(url.absoluteString.contains("/bulkdata/7FE00010"))
    }
}

// MARK: - Render Options Query Parameter Tests

@Suite("DICOMwebClient Render Options Tests")
struct DICOMwebClientRenderOptionsTests {
    
    @Test("Render options URL with window parameters")
    func testRenderOptionsWithWindowParams() {
        let baseURL = URL(string: "https://example.com/rendered")!
        let url = DICOMwebURLBuilder.renderedURL(
            base: baseURL,
            windowCenter: 40,
            windowWidth: 400
        )
        
        #expect(url.absoluteString.contains("windowcenter=40"))
        #expect(url.absoluteString.contains("windowwidth=400"))
    }
    
    @Test("Render options URL with viewport parameters")
    func testRenderOptionsWithViewportParams() {
        let baseURL = URL(string: "https://example.com/rendered")!
        let url = DICOMwebURLBuilder.renderedURL(
            base: baseURL,
            viewportWidth: 512,
            viewportHeight: 512
        )
        
        #expect(url.absoluteString.contains("columns=512"))
        #expect(url.absoluteString.contains("rows=512"))
    }
    
    @Test("Render options URL with quality parameter")
    func testRenderOptionsWithQuality() {
        let baseURL = URL(string: "https://example.com/rendered")!
        let url = DICOMwebURLBuilder.renderedURL(
            base: baseURL,
            quality: 85
        )
        
        #expect(url.absoluteString.contains("quality=85"))
    }
    
    @Test("Render options URL with all parameters")
    func testRenderOptionsWithAllParams() {
        let baseURL = URL(string: "https://example.com/rendered")!
        let url = DICOMwebURLBuilder.renderedURL(
            base: baseURL,
            windowCenter: 40,
            windowWidth: 400,
            viewportWidth: 256,
            viewportHeight: 256,
            quality: 90
        )
        
        #expect(url.absoluteString.contains("windowcenter=40"))
        #expect(url.absoluteString.contains("windowwidth=400"))
        #expect(url.absoluteString.contains("columns=256"))
        #expect(url.absoluteString.contains("rows=256"))
        #expect(url.absoluteString.contains("quality=90"))
    }
    
    @Test("Render options URL with quality clamping")
    func testRenderOptionsQualityClamping() {
        let baseURL = URL(string: "https://example.com/rendered")!
        
        // Quality over 100 should be clamped to 100
        let urlOver = DICOMwebURLBuilder.renderedURL(base: baseURL, quality: 150)
        #expect(urlOver.absoluteString.contains("quality=100"))
        
        // Quality under 0 should be clamped to 0
        let urlUnder = DICOMwebURLBuilder.renderedURL(base: baseURL, quality: -50)
        #expect(urlUnder.absoluteString.contains("quality=0"))
    }
}

// MARK: - Accept Header Tests

@Suite("DICOMwebClient Accept Header Tests")
struct DICOMwebClientAcceptHeaderTests {
    
    @Test("Default accept types from configuration")
    func testDefaultAcceptTypes() {
        let testURL = URL(string: "https://pacs.example.com/dicom-web")!
        let config = DICOMwebConfiguration(
            baseURL: testURL,
            defaultAcceptTypes: [.dicomJSON, .dicom]
        )
        
        let headers = config.headers()
        #expect(headers["Accept"]?.contains("application/dicom+json") == true)
        #expect(headers["Accept"]?.contains("application/dicom") == true)
    }
    
    @Test("Custom accept header overrides default")
    func testCustomAcceptHeaderOverridesDefault() {
        let testURL = URL(string: "https://pacs.example.com/dicom-web")!
        let config = DICOMwebConfiguration(
            baseURL: testURL,
            defaultAcceptTypes: [.dicomJSON]
        )
        
        let headers = config.headers(accept: [.jpeg])
        #expect(headers["Accept"] == "image/jpeg")
    }
    
    @Test("Preferred transfer syntaxes configuration")
    func testPreferredTransferSyntaxes() {
        let testURL = URL(string: "https://pacs.example.com/dicom-web")!
        let config = DICOMwebConfiguration(
            baseURL: testURL,
            preferredTransferSyntaxes: [
                DICOMMediaType.TransferSyntax.jpegLosslessSV1,
                DICOMMediaType.TransferSyntax.explicitVRLittleEndian
            ]
        )
        
        #expect(config.preferredTransferSyntaxes.count == 2)
        #expect(config.preferredTransferSyntaxes[0] == "1.2.840.10008.1.2.4.70")
    }
}

// MARK: - Multipart Parsing Tests

@Suite("DICOMwebClient Multipart Parsing Tests")
struct DICOMwebClientMultipartParsingTests {
    
    @Test("Parse single part response as non-multipart")
    func testSinglePartResponse() throws {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let contentType = "application/dicom"
        
        // When content type is not multipart, the entire data should be returned as a single part
        let mediaType = DICOMMediaType.parse(contentType)
        #expect(mediaType?.type == "application")
        #expect(mediaType?.subtype == "dicom")
    }
    
    @Test("Parse multipart boundary extraction")
    func testMultipartBoundaryExtraction() throws {
        let contentType = "multipart/related; boundary=----DICOMBoundary123"
        let mediaType = DICOMMediaType.parse(contentType)
        
        #expect(mediaType?.parameters["boundary"] == "----DICOMBoundary123")
    }
    
    @Test("Parse multipart with type parameter")
    func testMultipartTypeParameter() throws {
        let contentType = "multipart/related; type=\"application/dicom\"; boundary=abc"
        let mediaType = DICOMMediaType.parse(contentType)
        
        #expect(mediaType?.parameters["type"] == "application/dicom")
        #expect(mediaType?.parameters["boundary"] == "abc")
    }
}

// MARK: - Error Handling Tests

@Suite("DICOMwebClient Error Handling Tests")
struct DICOMwebClientErrorHandlingTests {
    
    @Test("Invalid bulk data URI validation")
    func testInvalidBulkDataURIValidation() async {
        // Test that URL parsing handles various invalid cases
        // The URL(string:) initializer is lenient, but we can test the pattern
        
        // Test with empty string - URL(string: "") returns nil
        let emptyURL = URL(string: "")
        #expect(emptyURL == nil)
        
        // Test that the DICOMwebError has the correct format
        let error = DICOMwebError.invalidBulkDataReference(uri: "test-uri")
        #expect(error.errorDescription?.contains("bulk data") == true)
    }
    
    @Test("Empty bulk data URI throws error")
    func testEmptyBulkDataURIThrows() async {
        let testURL = URL(string: "https://pacs.example.com/dicom-web")!
        let config = DICOMwebConfiguration(baseURL: testURL)
        let client = DICOMwebClient(configuration: config)
        
        do {
            // Empty string returns nil from URL(string:), which should throw invalidBulkDataReference
            _ = try await client.retrieveBulkData(uri: "")
            #expect(Bool(false), "Expected error for empty URI")
        } catch let error as DICOMwebError {
            if case .invalidBulkDataReference = error {
                // Expected
            } else {
                #expect(Bool(false), "Expected invalidBulkDataReference error, got \(error)")
            }
        } catch {
            #expect(Bool(false), "Expected DICOMwebError")
        }
    }
    
    @Test("Empty frames array throws error")
    func testEmptyFramesArrayThrows() async {
        let testURL = URL(string: "https://pacs.example.com/dicom-web")!
        let config = DICOMwebConfiguration(baseURL: testURL)
        let client = DICOMwebClient(configuration: config)
        
        do {
            _ = try await client.retrieveFrames(
                studyUID: "1.2.3",
                seriesUID: "1.2.3.4",
                instanceUID: "1.2.3.4.5",
                frames: []
            )
            #expect(Bool(false), "Expected error for empty frames")
        } catch let error as DICOMwebError {
            if case .badRequest = error {
                // Expected
            } else {
                #expect(Bool(false), "Expected badRequest error")
            }
        } catch {
            #expect(Bool(false), "Expected DICOMwebError")
        }
    }
    
    @Test("Invalid frame number throws error")
    func testInvalidFrameNumberThrows() async {
        let testURL = URL(string: "https://pacs.example.com/dicom-web")!
        let config = DICOMwebConfiguration(baseURL: testURL)
        let client = DICOMwebClient(configuration: config)
        
        do {
            // Frame numbers must be >= 1
            _ = try await client.retrieveFrames(
                studyUID: "1.2.3",
                seriesUID: "1.2.3.4",
                instanceUID: "1.2.3.4.5",
                frames: [0]
            )
            #expect(Bool(false), "Expected error for invalid frame number")
        } catch let error as DICOMwebError {
            if case .invalidFrameNumber = error {
                // Expected
            } else {
                #expect(Bool(false), "Expected invalidFrameNumber error, got \(error)")
            }
        } catch {
            #expect(Bool(false), "Expected DICOMwebError")
        }
    }
    
    @Test("Negative frame number throws error")
    func testNegativeFrameNumberThrows() async {
        let testURL = URL(string: "https://pacs.example.com/dicom-web")!
        let config = DICOMwebConfiguration(baseURL: testURL)
        let client = DICOMwebClient(configuration: config)
        
        do {
            _ = try await client.retrieveFrames(
                studyUID: "1.2.3",
                seriesUID: "1.2.3.4",
                instanceUID: "1.2.3.4.5",
                frames: [-1]
            )
            #expect(Bool(false), "Expected error for negative frame number")
        } catch let error as DICOMwebError {
            if case .invalidFrameNumber = error {
                // Expected
            } else {
                #expect(Bool(false), "Expected invalidFrameNumber error")
            }
        } catch {
            #expect(Bool(false), "Expected DICOMwebError")
        }
    }
}
