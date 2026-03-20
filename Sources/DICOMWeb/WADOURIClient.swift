import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Client for WADO-URI (Web Access to DICOM Objects — URI-based) retrieval
///
/// Implements the WADO-URI protocol defined in DICOM PS3.18 §8 for retrieving
/// individual DICOM objects using HTTP GET with query parameters.
/// This is the older WADO standard, commonly supported by legacy PACS such as dcm4chee2.
///
/// WADO-URI differs from WADO-RS in that it uses query-string parameters
/// (`requestType=WADO&studyUID=...&seriesUID=...&objectUID=...`) rather than
/// RESTful path segments (`/studies/{uid}/series/{uid}/instances/{uid}`).
///
/// ## Example Usage
///
/// ```swift
/// let config = try DICOMwebConfiguration(
///     baseURLString: "http://pacs.hospital.org/wado"
/// )
/// let client = WADOURIClient(configuration: config)
///
/// // Retrieve a DICOM object
/// let data = try await client.retrieve(
///     studyUID: "1.2.3",
///     seriesUID: "1.2.3.4",
///     objectUID: "1.2.3.4.5"
/// )
///
/// // Retrieve as JPEG image
/// let jpeg = try await client.retrieve(
///     studyUID: "1.2.3",
///     seriesUID: "1.2.3.4",
///     objectUID: "1.2.3.4.5",
///     contentType: .jpeg
/// )
/// ```
///
/// Reference: DICOM PS3.18 §8 — WADO-URI Service
#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
public final class WADOURIClient: @unchecked Sendable {

    // MARK: - Types

    /// Content type to request from WADO-URI
    public enum ContentType: String, Sendable {
        /// DICOM Part 10 file (application/dicom)
        case dicom = "application/dicom"
        /// JPEG image (image/jpeg)
        case jpeg = "image/jpeg"
        /// PNG image (image/png)
        case png = "image/png"
        /// GIF image (image/gif)
        case gif = "image/gif"
        /// JPEG 2000 image (image/jp2)
        case jpeg2000 = "image/jp2"
        /// MPEG video (video/mpeg)
        case mpeg = "video/mpeg"
    }

    /// Result of a WADO-URI retrieve operation
    public struct RetrieveResult: Sendable {
        /// The retrieved data
        public let data: Data
        /// The Content-Type of the response
        public let responseContentType: String?
        /// The HTTP status code
        public let statusCode: Int
    }

    // MARK: - Properties

    /// The underlying HTTP client
    public let httpClient: HTTPClient

    /// The configuration
    public var configuration: DICOMwebConfiguration {
        return httpClient.configuration
    }

    // MARK: - Initialization

    /// Creates a WADO-URI client with the specified configuration
    /// - Parameter configuration: The DICOMweb configuration (baseURL is the WADO endpoint)
    public init(configuration: DICOMwebConfiguration) {
        self.httpClient = HTTPClient(configuration: configuration)
    }

    /// Creates a WADO-URI client with the specified HTTP client
    /// - Parameter httpClient: The HTTP client to use
    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    // MARK: - Retrieve

    /// Retrieves a single DICOM object via WADO-URI
    ///
    /// Constructs a URL like:
    /// `{baseURL}?requestType=WADO&studyUID=...&seriesUID=...&objectUID=...`
    ///
    /// - Parameters:
    ///   - studyUID: Study Instance UID
    ///   - seriesUID: Series Instance UID
    ///   - objectUID: SOP Instance UID
    ///   - contentType: Requested content type (default: .dicom)
    ///   - transferSyntax: Preferred transfer syntax UID (optional, for contentType .dicom)
    ///   - anonymize: Whether to anonymize the object (optional, "yes" to anonymize)
    ///   - rows: Number of pixel rows for image content types (optional)
    ///   - columns: Number of pixel columns for image content types (optional)
    ///   - frameNumber: Frame number to retrieve for multi-frame objects (optional, 1-based)
    /// - Returns: The retrieved data
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: DICOM PS3.18 §8.1.1 — WADO Retrieve
    public func retrieve(
        studyUID: String,
        seriesUID: String,
        objectUID: String,
        contentType: ContentType = .dicom,
        transferSyntax: String? = nil,
        anonymize: String? = nil,
        rows: Int? = nil,
        columns: Int? = nil,
        frameNumber: Int? = nil
    ) async throws -> RetrieveResult {
        let url = try buildURL(
            studyUID: studyUID,
            seriesUID: seriesUID,
            objectUID: objectUID,
            contentType: contentType,
            transferSyntax: transferSyntax,
            anonymize: anonymize,
            rows: rows,
            columns: columns,
            frameNumber: frameNumber
        )

        let headers = ["Accept": contentType.rawValue]
        let response = try await httpClient.get(url, headers: headers)

        guard response.isSuccess else {
            let body = String(data: response.body, encoding: .utf8)
            throw DICOMwebError.fromHTTPStatus(response.statusCode, message: body)
        }

        return RetrieveResult(
            data: response.body,
            responseContentType: response.header("Content-Type"),
            statusCode: response.statusCode
        )
    }

    /// Retrieves a DICOM object and returns only the raw data
    ///
    /// Convenience method that returns just the `Data` from a WADO-URI retrieve.
    ///
    /// - Parameters:
    ///   - studyUID: Study Instance UID
    ///   - seriesUID: Series Instance UID
    ///   - objectUID: SOP Instance UID
    ///   - contentType: Requested content type (default: .dicom)
    /// - Returns: The retrieved data bytes
    /// - Throws: DICOMwebError on failure
    public func retrieveData(
        studyUID: String,
        seriesUID: String,
        objectUID: String,
        contentType: ContentType = .dicom
    ) async throws -> Data {
        let result = try await retrieve(
            studyUID: studyUID,
            seriesUID: seriesUID,
            objectUID: objectUID,
            contentType: contentType
        )
        return result.data
    }

    // MARK: - URL Building

    /// Builds a WADO-URI request URL with query parameters
    ///
    /// Reference: PS3.18 §8.1.1 — URL format:
    ///   `{baseURL}?requestType=WADO&studyUID={studyUID}&seriesUID={seriesUID}&objectUID={objectUID}`
    private func buildURL(
        studyUID: String,
        seriesUID: String,
        objectUID: String,
        contentType: ContentType,
        transferSyntax: String?,
        anonymize: String?,
        rows: Int?,
        columns: Int?,
        frameNumber: Int?
    ) throws -> URL {
        guard var components = URLComponents(
            url: configuration.baseURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw DICOMwebError.invalidURL(url: configuration.baseURL.absoluteString)
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "requestType", value: "WADO"),
            URLQueryItem(name: "studyUID", value: studyUID),
            URLQueryItem(name: "seriesUID", value: seriesUID),
            URLQueryItem(name: "objectUID", value: objectUID),
            URLQueryItem(name: "contentType", value: contentType.rawValue),
        ]

        if let transferSyntax, !transferSyntax.isEmpty {
            queryItems.append(URLQueryItem(name: "transferSyntax", value: transferSyntax))
        }
        if let anonymize, !anonymize.isEmpty {
            queryItems.append(URLQueryItem(name: "anonymize", value: anonymize))
        }
        if let rows {
            queryItems.append(URLQueryItem(name: "rows", value: String(rows)))
        }
        if let columns {
            queryItems.append(URLQueryItem(name: "columns", value: String(columns)))
        }
        if let frameNumber {
            queryItems.append(URLQueryItem(name: "frameNumber", value: String(frameNumber)))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw DICOMwebError.invalidURL(url: configuration.baseURL.absoluteString)
        }
        return url
    }
}
#endif
