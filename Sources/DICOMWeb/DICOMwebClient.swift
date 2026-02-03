import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// DICOMweb client for retrieving DICOM objects over HTTP
///
/// Implements the WADO-RS (Web Access to DICOM Objects - RESTful Services)
/// specification for retrieving studies, series, instances, and frames.
///
/// Reference: PS3.18 Section 10.4 - WADO-RS
///
/// ## Example Usage
///
/// ```swift
/// let config = try DICOMwebConfiguration(
///     baseURLString: "https://pacs.example.com/dicom-web",
///     authentication: .bearer(token: "your-token")
/// )
/// let client = DICOMwebClient(configuration: config)
///
/// // Retrieve a study
/// let instances = try await client.retrieveStudy(studyUID: "1.2.3.4.5")
///
/// // Retrieve metadata
/// let metadata = try await client.retrieveStudyMetadata(studyUID: "1.2.3.4.5")
///
/// // Retrieve a rendered image
/// let image = try await client.retrieveRenderedInstance(
///     studyUID: "1.2.3.4.5",
///     seriesUID: "1.2.3.4.5.6",
///     instanceUID: "1.2.3.4.5.6.7"
/// )
/// ```
#if canImport(FoundationNetworking) || os(macOS) || os(iOS) || os(visionOS)
public final class DICOMwebClient: @unchecked Sendable {
    
    // MARK: - Types
    
    /// Progress information for downloads
    public struct RetrieveProgress: Sendable {
        /// Bytes received so far
        public let bytesReceived: Int64
        
        /// Total bytes expected (may be unknown)
        public let totalBytes: Int64?
        
        /// Instances received so far
        public let instancesReceived: Int
        
        /// Total instances expected (may be unknown)
        public let totalInstances: Int?
        
        /// Fraction completed (0.0 to 1.0)
        public var fractionCompleted: Double {
            if let total = totalBytes, total > 0 {
                return Double(bytesReceived) / Double(total)
            }
            if let total = totalInstances, total > 0 {
                return Double(instancesReceived) / Double(total)
            }
            return 0
        }
    }
    
    /// Result of a retrieve operation containing DICOM data
    public struct RetrieveResult: Sendable {
        /// The retrieved DICOM instances as raw Part 10 data
        public let instances: [Data]
        
        /// Content type of the retrieved data
        public let contentType: DICOMMediaType?
        
        /// Transfer syntax of the retrieved data
        public var transferSyntax: String? {
            return contentType?.transferSyntax
        }
    }
    
    /// Frame data result
    public struct FrameResult: Sendable {
        /// Frame number (1-based)
        public let frameNumber: Int
        
        /// Raw frame data
        public let data: Data
        
        /// Content type of the frame data
        public let contentType: DICOMMediaType?
    }
    
    /// Rendered image options
    public struct RenderOptions: Sendable {
        /// Window center for VOI LUT
        public let windowCenter: Double?
        
        /// Window width for VOI LUT
        public let windowWidth: Double?
        
        /// Viewport width in pixels
        public let viewportWidth: Int?
        
        /// Viewport height in pixels
        public let viewportHeight: Int?
        
        /// Quality (0-100) for lossy compression
        public let quality: Int?
        
        /// Desired output format
        public let format: ImageFormat
        
        /// Image format for rendered output
        public enum ImageFormat: Sendable {
            case jpeg
            case png
            case gif
            
            var mediaType: DICOMMediaType {
                switch self {
                case .jpeg: return .jpeg
                case .png: return .png
                case .gif: return .gif
                }
            }
        }
        
        /// Creates render options
        public init(
            windowCenter: Double? = nil,
            windowWidth: Double? = nil,
            viewportWidth: Int? = nil,
            viewportHeight: Int? = nil,
            quality: Int? = nil,
            format: ImageFormat = .jpeg
        ) {
            self.windowCenter = windowCenter
            self.windowWidth = windowWidth
            self.viewportWidth = viewportWidth
            self.viewportHeight = viewportHeight
            self.quality = quality
            self.format = format
        }
        
        /// Default options
        public static let `default` = RenderOptions()
        
        /// Options for thumbnails
        public static func thumbnail(size: Int = 128) -> RenderOptions {
            return RenderOptions(
                viewportWidth: size,
                viewportHeight: size,
                quality: 80,
                format: .jpeg
            )
        }
    }
    
    // MARK: - Properties
    
    /// The underlying HTTP client
    public let httpClient: HTTPClient
    
    /// The configuration for this client
    public var configuration: DICOMwebConfiguration {
        return httpClient.configuration
    }
    
    /// URL builder for this client
    public var urlBuilder: DICOMwebURLBuilder {
        return configuration.urlBuilder
    }
    
    // MARK: - Initialization
    
    /// Creates a DICOMweb client with the specified configuration
    /// - Parameter configuration: The DICOMweb configuration
    public init(configuration: DICOMwebConfiguration) {
        self.httpClient = HTTPClient(configuration: configuration)
    }
    
    /// Creates a DICOMweb client with the specified HTTP client
    /// - Parameter httpClient: The HTTP client to use
    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }
    
    // MARK: - Study Retrieval (WADO-RS)
    
    /// Retrieves all instances in a study
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - transferSyntax: Preferred transfer syntax (optional)
    /// - Returns: Retrieved DICOM instances
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: PS3.18 Section 10.4.1 - RetrieveStudy
    public func retrieveStudy(
        studyUID: String,
        transferSyntax: String? = nil
    ) async throws -> RetrieveResult {
        let url = urlBuilder.studyURL(studyUID: studyUID)
        return try await retrieveDICOM(from: url, transferSyntax: transferSyntax)
    }
    
    /// Retrieves all instances in a study as a stream
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - transferSyntax: Preferred transfer syntax (optional)
    /// - Returns: AsyncThrowingStream of DICOM instance data
    /// - Throws: DICOMwebError on failure
    public func retrieveStudyStream(
        studyUID: String,
        transferSyntax: String? = nil
    ) -> AsyncThrowingStream<Data, Error> {
        let url = urlBuilder.studyURL(studyUID: studyUID)
        return retrieveDICOMStream(from: url, transferSyntax: transferSyntax)
    }
    
    // MARK: - Series Retrieval (WADO-RS)
    
    /// Retrieves all instances in a series
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - transferSyntax: Preferred transfer syntax (optional)
    /// - Returns: Retrieved DICOM instances
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: PS3.18 Section 10.4.1 - RetrieveSeries
    public func retrieveSeries(
        studyUID: String,
        seriesUID: String,
        transferSyntax: String? = nil
    ) async throws -> RetrieveResult {
        let url = urlBuilder.seriesURL(studyUID: studyUID, seriesUID: seriesUID)
        return try await retrieveDICOM(from: url, transferSyntax: transferSyntax)
    }
    
    /// Retrieves all instances in a series as a stream
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - transferSyntax: Preferred transfer syntax (optional)
    /// - Returns: AsyncThrowingStream of DICOM instance data
    public func retrieveSeriesStream(
        studyUID: String,
        seriesUID: String,
        transferSyntax: String? = nil
    ) -> AsyncThrowingStream<Data, Error> {
        let url = urlBuilder.seriesURL(studyUID: studyUID, seriesUID: seriesUID)
        return retrieveDICOMStream(from: url, transferSyntax: transferSyntax)
    }
    
    // MARK: - Instance Retrieval (WADO-RS)
    
    /// Retrieves a specific instance
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID
    ///   - transferSyntax: Preferred transfer syntax (optional)
    /// - Returns: Retrieved DICOM instance data
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: PS3.18 Section 10.4.1 - RetrieveInstance
    public func retrieveInstance(
        studyUID: String,
        seriesUID: String,
        instanceUID: String,
        transferSyntax: String? = nil
    ) async throws -> Data {
        let url = urlBuilder.instanceURL(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID
        )
        let result = try await retrieveDICOM(from: url, transferSyntax: transferSyntax)
        guard let first = result.instances.first else {
            throw DICOMwebError.notFound(resource: "Instance \(instanceUID)")
        }
        return first
    }
    
    // MARK: - Metadata Retrieval (WADO-RS)
    
    /// Retrieves metadata for a study
    ///
    /// - Parameter studyUID: The Study Instance UID
    /// - Returns: Array of DICOM JSON objects (one per instance)
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: PS3.18 Section 10.4.1.1 - RetrieveStudyMetadata
    public func retrieveStudyMetadata(studyUID: String) async throws -> [[String: Any]] {
        let url = urlBuilder.studyMetadataURL(studyUID: studyUID)
        return try await retrieveMetadata(from: url)
    }
    
    /// Retrieves metadata for a series
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    /// - Returns: Array of DICOM JSON objects (one per instance)
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: PS3.18 Section 10.4.1.1 - RetrieveSeriesMetadata
    public func retrieveSeriesMetadata(
        studyUID: String,
        seriesUID: String
    ) async throws -> [[String: Any]] {
        let url = urlBuilder.seriesMetadataURL(studyUID: studyUID, seriesUID: seriesUID)
        return try await retrieveMetadata(from: url)
    }
    
    /// Retrieves metadata for an instance
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID
    /// - Returns: Array with single DICOM JSON object
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: PS3.18 Section 10.4.1.1 - RetrieveInstanceMetadata
    public func retrieveInstanceMetadata(
        studyUID: String,
        seriesUID: String,
        instanceUID: String
    ) async throws -> [[String: Any]] {
        let url = urlBuilder.instanceMetadataURL(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID
        )
        return try await retrieveMetadata(from: url)
    }
    
    // MARK: - Frame Retrieval (WADO-RS)
    
    /// Retrieves specific frames from an instance
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID
    ///   - frames: Array of frame numbers (1-based)
    ///   - transferSyntax: Preferred transfer syntax (optional)
    /// - Returns: Array of frame data
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: PS3.18 Section 10.4.1 - RetrieveFrames
    public func retrieveFrames(
        studyUID: String,
        seriesUID: String,
        instanceUID: String,
        frames: [Int],
        transferSyntax: String? = nil
    ) async throws -> [FrameResult] {
        guard !frames.isEmpty else {
            throw DICOMwebError.badRequest(message: "At least one frame number is required")
        }
        
        // Validate frame numbers are positive
        for frame in frames {
            if frame < 1 {
                throw DICOMwebError.invalidFrameNumber(frame: frame, maxFrame: nil)
            }
        }
        
        let url = urlBuilder.framesURL(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID,
            frames: frames
        )
        
        let headers = buildAcceptHeader(transferSyntax: transferSyntax)
        let response = try await httpClient.get(url, headers: headers)
        
        // Parse multipart response
        let contentType = response.header("Content-Type") ?? ""
        let parts = try parseMultipartResponse(data: response.body, contentType: contentType)
        
        // Build frame results - use requested frame numbers for corresponding parts
        // WADO-RS spec states frames are returned in the order requested
        return zip(frames, parts).map { frameNumber, part in
            FrameResult(
                frameNumber: frameNumber,
                data: part.body,
                contentType: part.contentType
            )
        }
    }
    
    /// Retrieves a single frame from an instance
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID
    ///   - frame: Frame number (1-based)
    ///   - transferSyntax: Preferred transfer syntax (optional)
    /// - Returns: Frame data
    /// - Throws: DICOMwebError on failure
    public func retrieveFrame(
        studyUID: String,
        seriesUID: String,
        instanceUID: String,
        frame: Int,
        transferSyntax: String? = nil
    ) async throws -> Data {
        let results = try await retrieveFrames(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID,
            frames: [frame],
            transferSyntax: transferSyntax
        )
        guard let first = results.first else {
            throw DICOMwebError.invalidFrameNumber(frame: frame, maxFrame: nil)
        }
        return first.data
    }
    
    // MARK: - Rendered Image Retrieval (WADO-RS)
    
    /// Retrieves a rendered representation of an instance
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID
    ///   - options: Render options (windowing, viewport, format)
    /// - Returns: Rendered image data
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: PS3.18 Section 10.4.1 - RetrieveRenderedInstance
    public func retrieveRenderedInstance(
        studyUID: String,
        seriesUID: String,
        instanceUID: String,
        options: RenderOptions = .default
    ) async throws -> Data {
        var url = urlBuilder.instanceRenderedURL(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID
        )
        url = applyRenderOptions(to: url, options: options)
        
        let headers = ["Accept": options.format.mediaType.description]
        let response = try await httpClient.get(url, headers: headers)
        return response.body
    }
    
    /// Retrieves rendered representations of specific frames
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID
    ///   - frames: Array of frame numbers (1-based)
    ///   - options: Render options
    /// - Returns: Array of rendered frame data
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: PS3.18 Section 10.4.1 - RetrieveRenderedFrames
    public func retrieveRenderedFrames(
        studyUID: String,
        seriesUID: String,
        instanceUID: String,
        frames: [Int],
        options: RenderOptions = .default
    ) async throws -> [Data] {
        guard !frames.isEmpty else {
            throw DICOMwebError.badRequest(message: "At least one frame number is required")
        }
        
        var url = urlBuilder.framesRenderedURL(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID,
            frames: frames
        )
        url = applyRenderOptions(to: url, options: options)
        
        let headers = ["Accept": options.format.mediaType.description]
        let response = try await httpClient.get(url, headers: headers)
        
        // For single frame, return directly
        if frames.count == 1 {
            return [response.body]
        }
        
        // For multiple frames, parse multipart response
        let contentType = response.header("Content-Type") ?? ""
        if contentType.contains("multipart") {
            let parts = try parseMultipartResponse(data: response.body, contentType: contentType)
            return parts.map { $0.body }
        } else {
            return [response.body]
        }
    }
    
    // MARK: - Thumbnail Retrieval (WADO-RS)
    
    /// Retrieves a thumbnail for a study
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - options: Render options (viewport size controls thumbnail size)
    /// - Returns: Thumbnail image data
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: PS3.18 Section 10.4.1 - RetrieveStudyThumbnail
    public func retrieveStudyThumbnail(
        studyUID: String,
        options: RenderOptions = .thumbnail()
    ) async throws -> Data {
        var url = urlBuilder.studyThumbnailURL(studyUID: studyUID)
        url = applyRenderOptions(to: url, options: options)
        
        let headers = ["Accept": options.format.mediaType.description]
        let response = try await httpClient.get(url, headers: headers)
        return response.body
    }
    
    /// Retrieves a thumbnail for a series
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - options: Render options
    /// - Returns: Thumbnail image data
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: PS3.18 Section 10.4.1 - RetrieveSeriesThumbnail
    public func retrieveSeriesThumbnail(
        studyUID: String,
        seriesUID: String,
        options: RenderOptions = .thumbnail()
    ) async throws -> Data {
        var url = urlBuilder.seriesThumbnailURL(studyUID: studyUID, seriesUID: seriesUID)
        url = applyRenderOptions(to: url, options: options)
        
        let headers = ["Accept": options.format.mediaType.description]
        let response = try await httpClient.get(url, headers: headers)
        return response.body
    }
    
    /// Retrieves a thumbnail for an instance
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID
    ///   - options: Render options
    /// - Returns: Thumbnail image data
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: PS3.18 Section 10.4.1 - RetrieveInstanceThumbnail
    public func retrieveInstanceThumbnail(
        studyUID: String,
        seriesUID: String,
        instanceUID: String,
        options: RenderOptions = .thumbnail()
    ) async throws -> Data {
        var url = urlBuilder.instanceThumbnailURL(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID
        )
        url = applyRenderOptions(to: url, options: options)
        
        let headers = ["Accept": options.format.mediaType.description]
        let response = try await httpClient.get(url, headers: headers)
        return response.body
    }
    
    // MARK: - Bulk Data Retrieval (WADO-RS)
    
    /// Retrieves bulk data by URI
    ///
    /// - Parameters:
    ///   - uri: The bulk data URI from a metadata response
    ///   - range: Optional byte range for partial retrieval
    /// - Returns: Bulk data
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: PS3.18 Section 10.4.1 - RetrieveBulkdata
    public func retrieveBulkData(
        uri: String,
        range: Range<Int>? = nil
    ) async throws -> Data {
        guard let url = URL(string: uri) else {
            throw DICOMwebError.invalidBulkDataReference(uri: uri)
        }
        
        var headers: [String: String] = [:]
        
        if let range = range {
            headers["Range"] = "bytes=\(range.lowerBound)-\(range.upperBound - 1)"
        }
        
        let response = try await httpClient.get(url, headers: headers)
        return response.body
    }
    
    /// Retrieves bulk data for a specific attribute
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID
    ///   - attributePath: The attribute tag path (e.g., "7FE00010" for pixel data)
    /// - Returns: Bulk data
    /// - Throws: DICOMwebError on failure
    public func retrieveAttributeBulkData(
        studyUID: String,
        seriesUID: String,
        instanceUID: String,
        attributePath: String
    ) async throws -> Data {
        let url = urlBuilder.bulkdataURL(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID,
            attributePath: attributePath
        )
        
        let response = try await httpClient.get(url)
        return response.body
    }
    
    // MARK: - Private Methods
    
    /// Builds Accept header for DICOM retrieval
    private func buildAcceptHeader(transferSyntax: String? = nil) -> [String: String] {
        var accept = "multipart/related; type=\"application/dicom\""
        
        if let ts = transferSyntax {
            accept += "; transfer-syntax=\(ts)"
        } else if let preferred = configuration.preferredTransferSyntaxes.first {
            accept += "; transfer-syntax=\(preferred)"
        }
        
        return ["Accept": accept]
    }
    
    /// Retrieves DICOM objects from a URL
    private func retrieveDICOM(
        from url: URL,
        transferSyntax: String?
    ) async throws -> RetrieveResult {
        let headers = buildAcceptHeader(transferSyntax: transferSyntax)
        let response = try await httpClient.get(url, headers: headers)
        
        // Parse multipart response
        let contentType = response.header("Content-Type") ?? ""
        let parts = try parseMultipartResponse(data: response.body, contentType: contentType)
        
        return RetrieveResult(
            instances: parts.map { $0.body },
            contentType: parts.first?.contentType
        )
    }
    
    /// Retrieves DICOM objects as a stream
    private func retrieveDICOMStream(
        from url: URL,
        transferSyntax: String?
    ) -> AsyncThrowingStream<Data, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let headers = buildAcceptHeader(transferSyntax: transferSyntax)
                    let response = try await httpClient.get(url, headers: headers)
                    
                    let contentType = response.header("Content-Type") ?? ""
                    let parts = try parseMultipartResponse(data: response.body, contentType: contentType)
                    
                    for part in parts {
                        // Check for cancellation
                        try Task.checkCancellation()
                        continuation.yield(part.body)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Retrieves metadata from a URL
    private func retrieveMetadata(from url: URL) async throws -> [[String: Any]] {
        let headers = ["Accept": DICOMMediaType.dicomJSON.description]
        let response = try await httpClient.get(url, headers: headers)
        
        guard let json = try JSONSerialization.jsonObject(with: response.body) as? [[String: Any]] else {
            throw DICOMwebError.invalidJSON(reason: "Expected array of DICOM JSON objects")
        }
        
        return json
    }
    
    /// Parses a multipart MIME response
    private func parseMultipartResponse(data: Data, contentType: String) throws -> [MultipartMIME.Part] {
        // If content type is not multipart, return single part
        guard contentType.contains("multipart") else {
            let mediaType = DICOMMediaType.parse(contentType) ?? .octetStream
            return [MultipartMIME.Part(contentType: mediaType, body: data)]
        }
        
        // Parse multipart
        let multipart = try MultipartMIME.parse(data: data, contentType: contentType)
        return multipart.parts
    }
    
    /// Applies render options to a URL as query parameters
    private func applyRenderOptions(to url: URL, options: RenderOptions) -> URL {
        var params: [String: String] = [:]
        
        if let wc = options.windowCenter {
            params[DICOMwebURLBuilder.QueryParameter.windowCenter] = String(wc)
        }
        if let ww = options.windowWidth {
            params[DICOMwebURLBuilder.QueryParameter.windowWidth] = String(ww)
        }
        if let vw = options.viewportWidth {
            params[DICOMwebURLBuilder.QueryParameter.viewportWidth] = String(vw)
        }
        if let vh = options.viewportHeight {
            params[DICOMwebURLBuilder.QueryParameter.viewportHeight] = String(vh)
        }
        if let q = options.quality {
            params[DICOMwebURLBuilder.QueryParameter.quality] = String(min(100, max(0, q)))
        }
        
        return DICOMwebURLBuilder.appendQueryParameters(to: url, parameters: params)
    }
}

// MARK: - Convenience Extensions

extension DICOMwebClient {
    /// Retrieves metadata for a study and decodes it using DICOMJSONDecoder
    ///
    /// - Parameter studyUID: The Study Instance UID
    /// - Returns: Array of DataElement arrays (one per instance)
    /// - Throws: DICOMwebError on failure
    public func retrieveStudyMetadataAsElements(studyUID: String) async throws -> [[DataElement]] {
        let url = urlBuilder.studyMetadataURL(studyUID: studyUID)
        let headers = ["Accept": DICOMMediaType.dicomJSON.description]
        let response = try await httpClient.get(url, headers: headers)
        
        let decoder = DICOMJSONDecoder()
        return try decoder.decodeMultiple(response.body)
    }
    
    /// Retrieves metadata for a series and decodes it using DICOMJSONDecoder
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    /// - Returns: Array of DataElement arrays (one per instance)
    /// - Throws: DICOMwebError on failure
    public func retrieveSeriesMetadataAsElements(
        studyUID: String,
        seriesUID: String
    ) async throws -> [[DataElement]] {
        let url = urlBuilder.seriesMetadataURL(studyUID: studyUID, seriesUID: seriesUID)
        let headers = ["Accept": DICOMMediaType.dicomJSON.description]
        let response = try await httpClient.get(url, headers: headers)
        
        let decoder = DICOMJSONDecoder()
        return try decoder.decodeMultiple(response.body)
    }
    
    /// Retrieves metadata for an instance and decodes it using DICOMJSONDecoder
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID
    /// - Returns: Array of DataElement
    /// - Throws: DICOMwebError on failure
    public func retrieveInstanceMetadataAsElements(
        studyUID: String,
        seriesUID: String,
        instanceUID: String
    ) async throws -> [DataElement] {
        let url = urlBuilder.instanceMetadataURL(
            studyUID: studyUID,
            seriesUID: seriesUID,
            instanceUID: instanceUID
        )
        let headers = ["Accept": DICOMMediaType.dicomJSON.description]
        let response = try await httpClient.get(url, headers: headers)
        
        let decoder = DICOMJSONDecoder()
        let arrays = try decoder.decodeMultiple(response.body)
        return arrays.first ?? []
    }
}
#endif
