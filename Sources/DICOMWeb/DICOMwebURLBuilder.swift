import Foundation

/// Builder for constructing DICOMweb URLs
///
/// Provides utilities for building standard DICOMweb endpoint URLs
/// according to PS3.18 specification.
///
/// Reference: PS3.18 Section 10 - URI Templates
public struct DICOMwebURLBuilder: Sendable {
    /// The base URL of the DICOMweb server
    public let baseURL: URL
    
    /// Creates a URL builder with the specified base URL
    /// - Parameter baseURL: The base URL of the DICOMweb server
    public init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    /// Creates a URL builder from a string URL
    /// - Parameter baseURLString: The base URL string
    /// - Throws: DICOMwebError.invalidURL if the string is not a valid URL
    public init(baseURLString: String) throws {
        guard let url = URL(string: baseURLString) else {
            throw DICOMwebError.invalidURL(url: baseURLString)
        }
        self.baseURL = url
    }
    
    // MARK: - Studies Resource URLs
    
    /// URL for the studies endpoint
    /// - Returns: URL for `/studies`
    public var studiesURL: URL {
        return baseURL.appendingPathComponent("studies")
    }
    
    /// URL for a specific study
    /// - Parameter studyUID: The Study Instance UID
    /// - Returns: URL for `/studies/{studyUID}`
    public func studyURL(studyUID: String) -> URL {
        return studiesURL.appendingPathComponent(studyUID)
    }
    
    /// URL for study metadata
    /// - Parameter studyUID: The Study Instance UID
    /// - Returns: URL for `/studies/{studyUID}/metadata`
    public func studyMetadataURL(studyUID: String) -> URL {
        return studyURL(studyUID: studyUID).appendingPathComponent("metadata")
    }
    
    /// URL for study rendered representation
    /// - Parameter studyUID: The Study Instance UID
    /// - Returns: URL for `/studies/{studyUID}/rendered`
    public func studyRenderedURL(studyUID: String) -> URL {
        return studyURL(studyUID: studyUID).appendingPathComponent("rendered")
    }
    
    /// URL for study thumbnail
    /// - Parameter studyUID: The Study Instance UID
    /// - Returns: URL for `/studies/{studyUID}/thumbnail`
    public func studyThumbnailURL(studyUID: String) -> URL {
        return studyURL(studyUID: studyUID).appendingPathComponent("thumbnail")
    }
    
    // MARK: - Series Resource URLs
    
    /// URL for series within a study
    /// - Parameter studyUID: The Study Instance UID
    /// - Returns: URL for `/studies/{studyUID}/series`
    public func seriesURL(studyUID: String) -> URL {
        return studyURL(studyUID: studyUID).appendingPathComponent("series")
    }
    
    /// URL for a specific series
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    /// - Returns: URL for `/studies/{studyUID}/series/{seriesUID}`
    public func seriesURL(studyUID: String, seriesUID: String) -> URL {
        return seriesURL(studyUID: studyUID).appendingPathComponent(seriesUID)
    }
    
    /// URL for series metadata
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    /// - Returns: URL for `/studies/{studyUID}/series/{seriesUID}/metadata`
    public func seriesMetadataURL(studyUID: String, seriesUID: String) -> URL {
        return seriesURL(studyUID: studyUID, seriesUID: seriesUID)
            .appendingPathComponent("metadata")
    }
    
    /// URL for series rendered representation
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    /// - Returns: URL for `/studies/{studyUID}/series/{seriesUID}/rendered`
    public func seriesRenderedURL(studyUID: String, seriesUID: String) -> URL {
        return seriesURL(studyUID: studyUID, seriesUID: seriesUID)
            .appendingPathComponent("rendered")
    }
    
    /// URL for series thumbnail
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    /// - Returns: URL for `/studies/{studyUID}/series/{seriesUID}/thumbnail`
    public func seriesThumbnailURL(studyUID: String, seriesUID: String) -> URL {
        return seriesURL(studyUID: studyUID, seriesUID: seriesUID)
            .appendingPathComponent("thumbnail")
    }
    
    // MARK: - Instances Resource URLs
    
    /// URL for instances within a series
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    /// - Returns: URL for `/studies/{studyUID}/series/{seriesUID}/instances`
    public func instancesURL(studyUID: String, seriesUID: String) -> URL {
        return seriesURL(studyUID: studyUID, seriesUID: seriesUID)
            .appendingPathComponent("instances")
    }
    
    /// URL for a specific instance
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID
    /// - Returns: URL for `/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}`
    public func instanceURL(studyUID: String, seriesUID: String, instanceUID: String) -> URL {
        return instancesURL(studyUID: studyUID, seriesUID: seriesUID)
            .appendingPathComponent(instanceUID)
    }
    
    /// URL for instance metadata
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID
    /// - Returns: URL for `/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/metadata`
    public func instanceMetadataURL(studyUID: String, seriesUID: String, instanceUID: String) -> URL {
        return instanceURL(studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID)
            .appendingPathComponent("metadata")
    }
    
    /// URL for instance rendered representation
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID
    /// - Returns: URL for `/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/rendered`
    public func instanceRenderedURL(studyUID: String, seriesUID: String, instanceUID: String) -> URL {
        return instanceURL(studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID)
            .appendingPathComponent("rendered")
    }
    
    /// URL for instance thumbnail
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID
    /// - Returns: URL for `/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/thumbnail`
    public func instanceThumbnailURL(studyUID: String, seriesUID: String, instanceUID: String) -> URL {
        return instanceURL(studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID)
            .appendingPathComponent("thumbnail")
    }
    
    // MARK: - Frames Resource URLs
    
    /// URL for specific frames of an instance
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID
    ///   - frames: Array of frame numbers (1-based)
    /// - Returns: URL for `/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/frames/{frameList}`
    public func framesURL(studyUID: String, seriesUID: String, instanceUID: String, frames: [Int]) -> URL {
        let frameList = frames.map { String($0) }.joined(separator: ",")
        return instanceURL(studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID)
            .appendingPathComponent("frames")
            .appendingPathComponent(frameList)
    }
    
    /// URL for rendered frames
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID
    ///   - frames: Array of frame numbers (1-based)
    /// - Returns: URL for `/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/frames/{frameList}/rendered`
    public func framesRenderedURL(studyUID: String, seriesUID: String, instanceUID: String, frames: [Int]) -> URL {
        return framesURL(studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID, frames: frames)
            .appendingPathComponent("rendered")
    }
    
    /// URL for frame thumbnails
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID
    ///   - frames: Array of frame numbers (1-based)
    /// - Returns: URL for `/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/frames/{frameList}/thumbnail`
    public func framesThumbnailURL(studyUID: String, seriesUID: String, instanceUID: String, frames: [Int]) -> URL {
        return framesURL(studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID, frames: frames)
            .appendingPathComponent("thumbnail")
    }
    
    // MARK: - Bulk Data URLs
    
    /// URL for bulk data retrieval
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - instanceUID: The SOP Instance UID
    ///   - attributePath: The attribute path (e.g., "00080018" for SOP Instance UID)
    /// - Returns: URL for `/studies/{studyUID}/series/{seriesUID}/instances/{instanceUID}/bulkdata/{attributePath}`
    public func bulkdataURL(studyUID: String, seriesUID: String, instanceUID: String, attributePath: String) -> URL {
        return instanceURL(studyUID: studyUID, seriesUID: seriesUID, instanceUID: instanceUID)
            .appendingPathComponent("bulkdata")
            .appendingPathComponent(attributePath)
    }
    
    // MARK: - URL with Query Parameters
    
    /// Appends query parameters to a URL
    /// - Parameters:
    ///   - url: The base URL
    ///   - parameters: Dictionary of query parameters
    /// - Returns: URL with query string appended
    public static func appendQueryParameters(to url: URL, parameters: [String: String]) -> URL {
        guard !parameters.isEmpty else { return url }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        
        for (key, value) in parameters.sorted(by: { $0.key < $1.key }) {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        
        components?.queryItems = queryItems
        return components?.url ?? url
    }
    
    /// Creates a QIDO-RS search URL with query parameters
    /// - Parameter parameters: Search parameters
    /// - Returns: URL for studies search
    public func searchStudiesURL(parameters: [String: String]) -> URL {
        return Self.appendQueryParameters(to: studiesURL, parameters: parameters)
    }
    
    /// Creates a QIDO-RS search URL for series with query parameters
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - parameters: Search parameters
    /// - Returns: URL for series search
    public func searchSeriesURL(studyUID: String, parameters: [String: String]) -> URL {
        return Self.appendQueryParameters(to: seriesURL(studyUID: studyUID), parameters: parameters)
    }
    
    /// Creates a QIDO-RS search URL for instances with query parameters
    /// - Parameters:
    ///   - studyUID: The Study Instance UID
    ///   - seriesUID: The Series Instance UID
    ///   - parameters: Search parameters
    /// - Returns: URL for instances search
    public func searchInstancesURL(studyUID: String, seriesUID: String, parameters: [String: String]) -> URL {
        return Self.appendQueryParameters(
            to: instancesURL(studyUID: studyUID, seriesUID: seriesUID),
            parameters: parameters
        )
    }
}

// MARK: - Viewport and Window Query Parameters

extension DICOMwebURLBuilder {
    /// Standard query parameter names for DICOMweb
    public enum QueryParameter {
        // MARK: - QIDO-RS Parameters
        
        /// Limit number of results
        public static let limit = "limit"
        
        /// Offset for pagination
        public static let offset = "offset"
        
        /// Include field in response (can be repeated)
        public static let includefield = "includefield"
        
        /// Fuzzy matching for patient name
        public static let fuzzymatching = "fuzzymatching"
        
        // MARK: - Rendered Image Parameters
        
        /// Window center for windowing
        public static let windowCenter = "windowcenter"
        
        /// Window width for windowing
        public static let windowWidth = "windowwidth"
        
        /// Viewport width (columns)
        public static let viewportWidth = "columns"
        
        /// Viewport height (rows)
        public static let viewportHeight = "rows"
        
        /// Quality (0-100) for lossy compression
        public static let quality = "quality"
        
        /// ICC Profile for color management
        public static let iccprofile = "iccprofile"
        
        /// Annotation types
        public static let annotation = "annotation"
        
        // MARK: - WADO-RS Parameters
        
        /// Accept parameter for multipart (override header)
        public static let accept = "accept"
        
        // MARK: - DICOM Attribute Tags (Common)
        
        /// Patient ID (0010,0020)
        public static let patientID = "00100020"
        
        /// Patient Name (0010,0010)
        public static let patientName = "00100010"
        
        /// Study Date (0008,0020)
        public static let studyDate = "00080020"
        
        /// Study Instance UID (0020,000D)
        public static let studyInstanceUID = "0020000D"
        
        /// Series Instance UID (0020,000E)
        public static let seriesInstanceUID = "0020000E"
        
        /// SOP Instance UID (0008,0018)
        public static let sopInstanceUID = "00080018"
        
        /// Modality (0008,0060)
        public static let modality = "00080060"
        
        /// Accession Number (0008,0050)
        public static let accessionNumber = "00080050"
    }
    
    /// Creates rendered URL with viewport and windowing parameters
    /// - Parameters:
    ///   - baseRenderedURL: The base rendered URL
    ///   - windowCenter: Window center value
    ///   - windowWidth: Window width value
    ///   - viewportWidth: Viewport width in pixels
    ///   - viewportHeight: Viewport height in pixels
    ///   - quality: Quality value (0-100) for lossy formats
    /// - Returns: URL with query parameters
    public static func renderedURL(
        base baseRenderedURL: URL,
        windowCenter: Double? = nil,
        windowWidth: Double? = nil,
        viewportWidth: Int? = nil,
        viewportHeight: Int? = nil,
        quality: Int? = nil
    ) -> URL {
        var params: [String: String] = [:]
        
        if let wc = windowCenter {
            params[QueryParameter.windowCenter] = String(wc)
        }
        if let ww = windowWidth {
            params[QueryParameter.windowWidth] = String(ww)
        }
        if let vw = viewportWidth {
            params[QueryParameter.viewportWidth] = String(vw)
        }
        if let vh = viewportHeight {
            params[QueryParameter.viewportHeight] = String(vh)
        }
        if let q = quality {
            params[QueryParameter.quality] = String(min(100, max(0, q)))
        }
        
        return appendQueryParameters(to: baseRenderedURL, parameters: params)
    }
}
