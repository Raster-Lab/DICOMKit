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

// MARK: - QIDO-RS Query Methods

extension DICOMwebClient {
    
    // MARK: - Search Studies (QIDO-RS)
    
    /// Searches for studies matching the query criteria
    ///
    /// - Parameters:
    ///   - query: Query parameters (optional, returns all studies if empty)
    /// - Returns: QIDO study results with pagination info
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: PS3.18 Section 10.6.1 - SearchForStudies
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Search for all CT studies in 2024
    /// let query = QIDOQuery()
    ///     .modality("CT")
    ///     .studyDate(from: "20240101", to: "20241231")
    ///     .limit(10)
    ///
    /// let results = try await client.searchStudies(query: query)
    /// for study in results.results {
    ///     print("Study: \(study.studyInstanceUID ?? "unknown")")
    /// }
    /// ```
    public func searchStudies(query: QIDOQuery = QIDOQuery()) async throws -> QIDOStudyResults {
        let url = urlBuilder.searchStudiesURL(parameters: query.toParameters())
        return try await performQIDOQuery(url: url, query: query)
    }
    
    /// Searches for studies with raw parameters
    ///
    /// - Parameter parameters: Raw query parameters dictionary
    /// - Returns: QIDO study results
    /// - Throws: DICOMwebError on failure
    public func searchStudies(parameters: [String: String]) async throws -> QIDOStudyResults {
        let url = urlBuilder.searchStudiesURL(parameters: parameters)
        return try await performQIDOQuery(url: url, query: QIDOQuery(parameters: parameters))
    }
    
    // MARK: - Search Series (QIDO-RS)
    
    /// Searches for series within a specific study
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - query: Query parameters (optional)
    /// - Returns: QIDO series results with pagination info
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: PS3.18 Section 10.6.1 - SearchForSeries
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// let results = try await client.searchSeries(
    ///     studyUID: "1.2.3.4.5",
    ///     query: QIDOQuery().modality("CT")
    /// )
    /// ```
    public func searchSeries(
        studyUID: String,
        query: QIDOQuery = QIDOQuery()
    ) async throws -> QIDOSeriesResults {
        let url = urlBuilder.searchSeriesURL(studyUID: studyUID, parameters: query.toParameters())
        return try await performQIDOQuery(url: url, query: query)
    }
    
    /// Searches for series across all studies
    ///
    /// - Parameter query: Query parameters
    /// - Returns: QIDO series results with pagination info
    /// - Throws: DICOMwebError on failure
    ///
    /// Note: Some servers may not support cross-study series searches.
    public func searchAllSeries(query: QIDOQuery = QIDOQuery()) async throws -> QIDOSeriesResults {
        let url = DICOMwebURLBuilder.appendQueryParameters(
            to: baseSeriesURL,
            parameters: query.toParameters()
        )
        return try await performQIDOQuery(url: url, query: query)
    }
    
    // MARK: - Search Instances (QIDO-RS)
    
    /// Searches for instances within a specific series
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - query: Query parameters (optional)
    /// - Returns: QIDO instance results with pagination info
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: PS3.18 Section 10.6.1 - SearchForInstances
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// let results = try await client.searchInstances(
    ///     studyUID: "1.2.3.4.5",
    ///     seriesUID: "1.2.3.4.5.6",
    ///     query: QIDOQuery().limit(50)
    /// )
    /// ```
    public func searchInstances(
        studyUID: String,
        seriesUID: String,
        query: QIDOQuery = QIDOQuery()
    ) async throws -> QIDOInstanceResults {
        let url = urlBuilder.searchInstancesURL(
            studyUID: studyUID,
            seriesUID: seriesUID,
            parameters: query.toParameters()
        )
        return try await performQIDOQuery(url: url, query: query)
    }
    
    /// Searches for instances within a specific study (across all series)
    ///
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - query: Query parameters (optional)
    /// - Returns: QIDO instance results with pagination info
    /// - Throws: DICOMwebError on failure
    public func searchInstances(
        studyUID: String,
        query: QIDOQuery = QIDOQuery()
    ) async throws -> QIDOInstanceResults {
        let url = DICOMwebURLBuilder.appendQueryParameters(
            to: urlBuilder.instancesInStudyURL(studyUID: studyUID),
            parameters: query.toParameters()
        )
        return try await performQIDOQuery(url: url, query: query)
    }
    
    /// Searches for instances across all studies
    ///
    /// - Parameter query: Query parameters
    /// - Returns: QIDO instance results with pagination info
    /// - Throws: DICOMwebError on failure
    ///
    /// Note: Some servers may not support cross-study instance searches.
    public func searchAllInstances(query: QIDOQuery = QIDOQuery()) async throws -> QIDOInstanceResults {
        let url = DICOMwebURLBuilder.appendQueryParameters(
            to: baseInstancesURL,
            parameters: query.toParameters()
        )
        return try await performQIDOQuery(url: url, query: query)
    }
    
    // MARK: - Private Helper Methods
    
    /// Base URL for series search across all studies
    private var baseSeriesURL: URL {
        return configuration.baseURL.appendingPathComponent("series")
    }
    
    /// Base URL for instances search across all studies
    private var baseInstancesURL: URL {
        return configuration.baseURL.appendingPathComponent("instances")
    }
    
    /// Performs a QIDO-RS query and parses results
    private func performQIDOQuery<T: QIDOResult>(
        url: URL,
        query: QIDOQuery
    ) async throws -> QIDOResults<T> {
        let headers = ["Accept": DICOMMediaType.dicomJSON.description]
        let response = try await httpClient.get(url, headers: headers)
        
        // Parse JSON array response
        guard let jsonArray = try JSONSerialization.jsonObject(with: response.body) as? [[String: Any]] else {
            throw DICOMwebError.invalidJSON(reason: "Expected array of DICOM JSON objects")
        }
        
        // Extract total count from headers if available
        let totalCount: Int?
        if let totalCountHeader = response.header("X-Total-Count") {
            totalCount = Int(totalCountHeader)
        } else {
            totalCount = nil
        }
        
        // Parse limit and offset from query
        let params = query.toParameters()
        let limit = params[DICOMwebURLBuilder.QueryParameter.limit].flatMap { Int($0) }
        let offset = params[DICOMwebURLBuilder.QueryParameter.offset].flatMap { Int($0) } ?? 0
        
        // Create result objects
        let results: [T] = jsonArray.map { T.init(attributes: $0) }
        
        return QIDOResults(
            results: results,
            totalCount: totalCount,
            offset: offset,
            limit: limit
        )
    }
}

// MARK: - STOW-RS Store Methods

extension DICOMwebClient {
    
    // MARK: - Types
    
    /// Progress information for store operations
    public struct StoreProgress: Sendable {
        /// Number of instances stored so far
        public let instancesStored: Int
        
        /// Total number of instances to store
        public let totalInstances: Int
        
        /// Bytes uploaded so far
        public let bytesUploaded: Int64
        
        /// Total bytes to upload (may be unknown)
        public let totalBytes: Int64?
        
        /// Fraction completed (0.0 to 1.0)
        public var fractionCompleted: Double {
            if totalInstances > 0 {
                return Double(instancesStored) / Double(totalInstances)
            }
            if let total = totalBytes, total > 0 {
                return Double(bytesUploaded) / Double(total)
            }
            return 0
        }
    }
    
    /// Options for store operations
    public struct StoreOptions: Sendable {
        /// Maximum number of instances per request
        /// Set to nil for unlimited (all instances in single request)
        public let batchSize: Int?
        
        /// Continue uploading remaining instances if some fail
        public let continueOnError: Bool
        
        /// Creates store options
        /// - Parameters:
        ///   - batchSize: Maximum instances per request (nil for unlimited)
        ///   - continueOnError: Whether to continue on partial failure
        public init(batchSize: Int? = nil, continueOnError: Bool = true) {
            self.batchSize = batchSize
            self.continueOnError = continueOnError
        }
        
        /// Default options (single request, continue on error)
        public static let `default` = StoreOptions()
    }
    
    // MARK: - Store Single Instance
    
    /// Stores a single DICOM instance
    ///
    /// - Parameters:
    ///   - data: The DICOM Part 10 file data
    ///   - studyUID: Optional Study Instance UID (instances will be added to this study)
    /// - Returns: Store response with result information
    /// - Throws: DICOMwebError on failure
    ///
    /// Reference: PS3.18 Section 10.5 - STOW-RS
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// let dicomData = try Data(contentsOf: dicomFileURL)
    /// let response = try await client.storeInstance(data: dicomData)
    ///
    /// if response.isFullSuccess {
    ///     print("Stored instance: \(response.storedInstances.first?.sopInstanceUID ?? "unknown")")
    /// }
    /// ```
    public func storeInstance(
        data: Data,
        studyUID: String? = nil
    ) async throws -> STOWResponse {
        return try await storeInstances(instances: [data], studyUID: studyUID)
    }
    
    // MARK: - Store Multiple Instances
    
    /// Stores multiple DICOM instances
    ///
    /// - Parameters:
    ///   - instances: Array of DICOM Part 10 file data
    ///   - studyUID: Optional Study Instance UID (all instances will be added to this study)
    ///   - options: Store options (batch size, error handling)
    /// - Returns: Combined store response with all results
    /// - Throws: DICOMwebError on complete failure
    ///
    /// Reference: PS3.18 Section 10.5 - STOW-RS
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// let instances = try dicomFiles.map { try Data(contentsOf: $0) }
    /// let response = try await client.storeInstances(
    ///     instances: instances,
    ///     studyUID: "1.2.3.4.5"
    /// )
    ///
    /// print("Stored: \(response.successCount), Failed: \(response.failureCount)")
    /// ```
    public func storeInstances(
        instances: [Data],
        studyUID: String? = nil,
        options: StoreOptions = .default
    ) async throws -> STOWResponse {
        guard !instances.isEmpty else {
            return STOWResponse()
        }
        
        // Determine batch size
        let batchSize = options.batchSize ?? instances.count
        
        // If all instances fit in one batch, do a single request
        if instances.count <= batchSize {
            return try await performStoreRequest(instances: instances, studyUID: studyUID)
        }
        
        // Otherwise, batch the requests
        var allStoredInstances: [STOWResponse.InstanceResult] = []
        var allFailedInstances: [STOWResponse.InstanceFailure] = []
        var allWarnings: [STOWResponse.Warning] = []
        var lastRetrieveURL: String?
        
        // Split into batches
        let batches = stride(from: 0, to: instances.count, by: batchSize).map {
            Array(instances[$0..<min($0 + batchSize, instances.count)])
        }
        
        for batch in batches {
            do {
                let response = try await performStoreRequest(instances: batch, studyUID: studyUID)
                allStoredInstances.append(contentsOf: response.storedInstances)
                allFailedInstances.append(contentsOf: response.failedInstances)
                allWarnings.append(contentsOf: response.warnings)
                if let url = response.retrieveURL {
                    lastRetrieveURL = url
                }
            } catch {
                if !options.continueOnError {
                    throw error
                }
                // On error, mark all instances in this batch as failed
                for _ in batch {
                    allFailedInstances.append(STOWResponse.InstanceFailure(
                        failureDescription: error.localizedDescription
                    ))
                }
            }
        }
        
        return STOWResponse(
            storedInstances: allStoredInstances,
            failedInstances: allFailedInstances,
            warnings: allWarnings,
            retrieveURL: lastRetrieveURL
        )
    }
    
    /// Stores multiple DICOM instances with progress reporting
    ///
    /// - Parameters:
    ///   - instances: Array of DICOM Part 10 file data
    ///   - studyUID: Optional Study Instance UID
    ///   - options: Store options
    /// - Returns: AsyncThrowingStream of progress updates and final response
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// for try await event in client.storeInstancesWithProgress(instances: dicomFiles) {
    ///     switch event {
    ///     case .progress(let progress):
    ///         print("Progress: \(Int(progress.fractionCompleted * 100))%")
    ///     case .completed(let response):
    ///         print("Complete: \(response.successCount) stored")
    ///     }
    /// }
    /// ```
    public func storeInstancesWithProgress(
        instances: [Data],
        studyUID: String? = nil,
        options: StoreOptions = .default
    ) -> AsyncThrowingStream<StoreEvent, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard !instances.isEmpty else {
                        continuation.yield(.completed(STOWResponse()))
                        continuation.finish()
                        return
                    }
                    
                    let batchSize = options.batchSize ?? instances.count
                    let batches = stride(from: 0, to: instances.count, by: batchSize).map {
                        Array(instances[$0..<min($0 + batchSize, instances.count)])
                    }
                    
                    var allStoredInstances: [STOWResponse.InstanceResult] = []
                    var allFailedInstances: [STOWResponse.InstanceFailure] = []
                    var allWarnings: [STOWResponse.Warning] = []
                    var lastRetrieveURL: String?
                    var instancesProcessed = 0
                    
                    let totalBytes = Int64(instances.reduce(0) { $0 + $1.count })
                    var bytesUploaded: Int64 = 0
                    
                    for batch in batches {
                        try Task.checkCancellation()
                        
                        let batchBytes = Int64(batch.reduce(0) { $0 + $1.count })
                        
                        do {
                            let response = try await performStoreRequest(instances: batch, studyUID: studyUID)
                            allStoredInstances.append(contentsOf: response.storedInstances)
                            allFailedInstances.append(contentsOf: response.failedInstances)
                            allWarnings.append(contentsOf: response.warnings)
                            if let url = response.retrieveURL {
                                lastRetrieveURL = url
                            }
                        } catch {
                            if !options.continueOnError {
                                throw error
                            }
                            for _ in batch {
                                allFailedInstances.append(STOWResponse.InstanceFailure(
                                    failureDescription: error.localizedDescription
                                ))
                            }
                        }
                        
                        instancesProcessed += batch.count
                        bytesUploaded += batchBytes
                        
                        let progress = StoreProgress(
                            instancesStored: instancesProcessed,
                            totalInstances: instances.count,
                            bytesUploaded: bytesUploaded,
                            totalBytes: totalBytes
                        )
                        continuation.yield(.progress(progress))
                    }
                    
                    let finalResponse = STOWResponse(
                        storedInstances: allStoredInstances,
                        failedInstances: allFailedInstances,
                        warnings: allWarnings,
                        retrieveURL: lastRetrieveURL
                    )
                    continuation.yield(.completed(finalResponse))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Event types for progress reporting
    public enum StoreEvent: Sendable {
        /// Progress update
        case progress(StoreProgress)
        
        /// Store operation completed
        case completed(STOWResponse)
    }
    
    // MARK: - Private Methods
    
    /// Performs a single STOW-RS request
    private func performStoreRequest(
        instances: [Data],
        studyUID: String?
    ) async throws -> STOWResponse {
        // Build URL
        let url: URL
        if let studyUID = studyUID {
            url = urlBuilder.storeURL(studyUID: studyUID)
        } else {
            url = urlBuilder.storeURL
        }
        
        // Build multipart body
        let multipart = buildMultipartRequest(instances: instances)
        let body = multipart.encode()
        
        // Build headers
        let headers: [String: String] = [
            "Content-Type": multipart.contentType.description,
            "Accept": DICOMMediaType.dicomJSON.description
        ]
        
        // Execute request
        let response = try await httpClient.post(url, body: body, headers: headers)
        
        // Parse response based on status code
        switch response.statusCode {
        case 200:
            // Full success - parse response body
            return try parseSTOWResponse(data: response.body)
            
        case 202:
            // Partial success (some warnings or failures)
            return try parseSTOWResponse(data: response.body)
            
        case 409:
            // Conflict - typically instance already exists
            let parsed = try? parseSTOWResponse(data: response.body)
            if let parsed = parsed, !parsed.failedInstances.isEmpty {
                return parsed
            }
            throw DICOMwebError.conflict(message: String(data: response.body, encoding: .utf8))
            
        default:
            // Other errors are already handled by HTTPClient
            throw DICOMwebError.fromHTTPStatus(
                response.statusCode,
                message: String(data: response.body, encoding: .utf8)
            )
        }
    }
    
    /// Builds a multipart request body for STOW-RS
    private func buildMultipartRequest(instances: [Data]) -> MultipartMIME {
        var builder = MultipartMIME.builder()
            .withRootType(.dicom)
        
        for instance in instances {
            builder = builder.addDICOM(instance)
        }
        
        return builder.build()
    }
    
    /// Parses a STOW-RS JSON response
    private func parseSTOWResponse(data: Data) throws -> STOWResponse {
        // Empty response is considered success with no details
        if data.isEmpty {
            return STOWResponse()
        }
        
        // Parse JSON
        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            // If not valid JSON, return empty success
            return STOWResponse()
        }
        
        // Response can be a single object or array
        if let jsonObject = json as? [String: Any] {
            return try STOWResponse.parse(json: jsonObject)
        } else if let jsonArray = json as? [[String: Any]], let first = jsonArray.first {
            return try STOWResponse.parse(json: first)
        } else {
            return STOWResponse()
        }
    }
}
#endif
