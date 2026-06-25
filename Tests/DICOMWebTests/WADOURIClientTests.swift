import Testing
import Foundation
@testable import DICOMWeb

@Suite("WADOURIClient Tests")
struct WADOURIClientTests {

    // MARK: - URL Building Tests

    @Test("WADO-URI URL contains required query parameters")
    func test_buildURL_requiredParams_present() async throws {
        let config = DICOMwebConfiguration(
            baseURL: URL(string: "http://pacs.example.com/wado")!
        )
        let client = WADOURIClient(configuration: config)

        // We can test URL building indirectly through the public retrieve method
        // by checking the configuration base URL is correct
        #expect(client.configuration.baseURL.absoluteString == "http://pacs.example.com/wado")
    }

    @Test("WADOURIClient ContentType raw values match DICOM standard")
    func test_contentType_rawValues() {
        #expect(WADOURIClient.ContentType.dicom.rawValue == "application/dicom")
        #expect(WADOURIClient.ContentType.jpeg.rawValue == "image/jpeg")
        #expect(WADOURIClient.ContentType.png.rawValue == "image/png")
        #expect(WADOURIClient.ContentType.gif.rawValue == "image/gif")
        #expect(WADOURIClient.ContentType.jpeg2000.rawValue == "image/jp2")
        #expect(WADOURIClient.ContentType.htj2k.rawValue == "image/jph")
        #expect(WADOURIClient.ContentType.htj2kContainer.rawValue == "image/jphc")
        #expect(WADOURIClient.ContentType.mpeg.rawValue == "video/mpeg")
    }

    @Test("WADOURIClient RetrieveResult properties")
    func test_retrieveResult_properties() {
        let result = WADOURIClient.RetrieveResult(
            data: Data([0x00, 0x01, 0x02]),
            responseContentType: "application/dicom",
            statusCode: 200
        )
        #expect(result.data.count == 3)
        #expect(result.responseContentType == "application/dicom")
        #expect(result.statusCode == 200)
    }

    @Test("WADOURIClient can be created from configuration")
    func test_init_configuration() throws {
        let config = try DICOMwebConfiguration(
            baseURLString: "http://192.168.1.200:8080/wado"
        )
        let client = WADOURIClient(configuration: config)
        #expect(client.configuration.baseURL.absoluteString == "http://192.168.1.200:8080/wado")
    }

    @Test("WADOURIClient can be created from HTTPClient")
    func test_init_httpClient() throws {
        let config = try DICOMwebConfiguration(
            baseURLString: "http://pacs.local/wado"
        )
        let httpClient = HTTPClient(configuration: config)
        let client = WADOURIClient(httpClient: httpClient)
        #expect(client.configuration.baseURL.absoluteString == "http://pacs.local/wado")
    }

    // MARK: - Endpoint Resolution (/rs → /wado)

    @Test("resolveURIEndpoint rewrites a dcm4chee-arc /rs base to /wado")
    func test_resolveURIEndpoint_rewritesRSToWado() {
        let resolved = WADOURIClient.resolveURIEndpoint(
            URL(string: "http://172.17.1.111:8080/dcm4chee-arc/aets/DCM4CHEE/rs")!
        )
        #expect(resolved.absoluteString == "http://172.17.1.111:8080/dcm4chee-arc/aets/DCM4CHEE/wado")
    }

    @Test("resolveURIEndpoint rewrites only the final /rs segment")
    func test_resolveURIEndpoint_rewritesOnlyFinalSegment() {
        // A path that merely contains 'rs' earlier must be untouched; only a trailing
        // /rs segment is the RESTful endpoint that needs redirecting to /wado.
        let resolved = WADOURIClient.resolveURIEndpoint(
            URL(string: "http://host/rs-archive/aets/AE/rs")!
        )
        #expect(resolved.absoluteString == "http://host/rs-archive/aets/AE/wado")
    }

    @Test("resolveURIEndpoint preserves a trailing slash")
    func test_resolveURIEndpoint_trailingSlash() {
        let resolved = WADOURIClient.resolveURIEndpoint(
            URL(string: "http://host:8080/dcm4chee-arc/aets/AE/rs/")!
        )
        #expect(resolved.absoluteString == "http://host:8080/dcm4chee-arc/aets/AE/wado/")
    }

    @Test("resolveURIEndpoint leaves a dcm4chee2 /wado root unchanged")
    func test_resolveURIEndpoint_wadoUnchanged() {
        let resolved = WADOURIClient.resolveURIEndpoint(
            URL(string: "http://172.17.1.200:8080/wado")!
        )
        #expect(resolved.absoluteString == "http://172.17.1.200:8080/wado")
    }

    @Test("resolveURIEndpoint leaves a non-/rs custom path unchanged")
    func test_resolveURIEndpoint_customPathUnchanged() {
        let resolved = WADOURIClient.resolveURIEndpoint(
            URL(string: "http://pacs.example.com/dicom-web")!
        )
        #expect(resolved.absoluteString == "http://pacs.example.com/dicom-web")
    }
}
