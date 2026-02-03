/// DICOMWeb module
///
/// Provides DICOMweb functionality including DICOM JSON encoding/decoding,
/// multipart MIME handling, and HTTP client infrastructure.
///
/// This module implements the DICOMweb standard (PS3.18) for RESTful
/// DICOM communication over HTTP/HTTPS.
///
/// ## Key Components
///
/// - ``DICOMJSONEncoder``: Encodes DICOM DataElements to JSON format
/// - ``DICOMJSONDecoder``: Decodes JSON to DICOM DataElements
/// - ``MultipartMIME``: Handles multipart/related messages
/// - ``HTTPClient``: HTTP client with retry and interceptor support
/// - ``DICOMwebConfiguration``: Configuration for DICOMweb clients
/// - ``DICOMwebURLBuilder``: URL construction utilities
/// - ``DICOMMediaType``: Media type definitions
/// - ``DICOMwebError``: Error types for DICOMweb operations
///
/// ## Example Usage
///
/// ```swift
/// import DICOMWeb
/// import DICOMCore
///
/// // Configure client
/// let config = try DICOMwebConfiguration(
///     baseURLString: "https://pacs.example.com/dicom-web",
///     authentication: .bearer(token: "your-token")
/// )
///
/// // Encode data to JSON
/// let encoder = DICOMJSONEncoder()
/// let jsonData = try encoder.encode(elements)
///
/// // Decode JSON to elements
/// let decoder = DICOMJSONDecoder()
/// let elements = try decoder.decode(jsonData)
/// ```
///
/// ## References
///
/// - DICOM PS3.18 - Web Services
/// - DICOM PS3.18 Annex F - DICOM JSON Model
/// - DICOM PS3.18 Section 8 - Multipart MIME
///
public enum DICOMWeb {
    /// The version of the DICOMWeb module
    public static let version = "0.8.1"
}

// Re-export DICOMCore types commonly used with DICOMWeb
@_exported import DICOMCore
