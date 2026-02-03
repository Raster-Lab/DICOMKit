import Foundation

/// Media types used in DICOMweb communications
///
/// Defines the standard media types for DICOM data exchange over HTTP.
/// Reference: PS3.18 Section 6 - Media Types and Transfer Syntaxes
public struct DICOMMediaType: Sendable, Hashable, CustomStringConvertible {
    /// The type component (e.g., "application", "image")
    public let type: String
    
    /// The subtype component (e.g., "dicom", "jpeg")
    public let subtype: String
    
    /// Optional parameters (e.g., transfer-syntax, charset)
    public let parameters: [String: String]
    
    /// Creates a media type with the specified components
    /// - Parameters:
    ///   - type: The primary type (e.g., "application")
    ///   - subtype: The subtype (e.g., "dicom+json")
    ///   - parameters: Optional key-value parameters
    public init(type: String, subtype: String, parameters: [String: String] = [:]) {
        self.type = type.lowercased()
        self.subtype = subtype.lowercased()
        self.parameters = parameters.reduce(into: [:]) { result, pair in
            result[pair.key.lowercased()] = pair.value
        }
    }
    
    /// The full media type string (e.g., "application/dicom+json")
    public var description: String {
        var result = "\(type)/\(subtype)"
        for (key, value) in parameters.sorted(by: { $0.key < $1.key }) {
            if value.contains(" ") || value.contains(";") || value.contains("\"") {
                result += "; \(key)=\"\(value)\""
            } else {
                result += "; \(key)=\(value)"
            }
        }
        return result
    }
    
    /// Parses a media type string
    /// - Parameter string: The media type string (e.g., "application/dicom+json; charset=utf-8")
    /// - Returns: A parsed DICOMMediaType, or nil if parsing fails
    public static func parse(_ string: String) -> DICOMMediaType? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        
        // Split by semicolon to separate type from parameters
        let parts = trimmed.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard !parts.isEmpty else { return nil }
        
        // Parse type/subtype
        let typeSubtype = parts[0].split(separator: "/")
        guard typeSubtype.count == 2 else { return nil }
        
        let type = String(typeSubtype[0]).trimmingCharacters(in: .whitespaces)
        let subtype = String(typeSubtype[1]).trimmingCharacters(in: .whitespaces)
        
        guard !type.isEmpty && !subtype.isEmpty else { return nil }
        
        // Parse parameters
        var parameters: [String: String] = [:]
        for i in 1..<parts.count {
            let param = parts[i]
            if let equalsIndex = param.firstIndex(of: "=") {
                let key = String(param[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
                var value = String(param[param.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)
                
                // Remove quotes if present
                if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                    value = String(value.dropFirst().dropLast())
                }
                
                parameters[key] = value
            }
        }
        
        return DICOMMediaType(type: type, subtype: subtype, parameters: parameters)
    }
    
    /// Returns a new media type with the specified parameter added/updated
    /// - Parameters:
    ///   - key: Parameter name
    ///   - value: Parameter value
    /// - Returns: A new DICOMMediaType with the parameter
    public func withParameter(_ key: String, value: String) -> DICOMMediaType {
        var newParams = parameters
        newParams[key.lowercased()] = value
        return DICOMMediaType(type: type, subtype: subtype, parameters: newParams)
    }
    
    /// Checks if this media type matches another (ignoring parameters)
    /// - Parameter other: The media type to compare against
    /// - Returns: True if type and subtype match
    public func matches(_ other: DICOMMediaType) -> Bool {
        return type == other.type && subtype == other.subtype
    }
}

// MARK: - Standard DICOM Media Types

extension DICOMMediaType {
    // MARK: - DICOM Application Types
    
    /// DICOM Part 10 file format
    /// Reference: PS3.18 Section 6.1.1.8
    public static let dicom = DICOMMediaType(type: "application", subtype: "dicom")
    
    /// DICOM JSON representation
    /// Reference: PS3.18 Section 6.1.1.1
    public static let dicomJSON = DICOMMediaType(type: "application", subtype: "dicom+json")
    
    /// DICOM XML representation
    /// Reference: PS3.18 Section 6.1.1.2
    public static let dicomXML = DICOMMediaType(type: "application", subtype: "dicom+xml")
    
    /// Generic binary data (bulk data)
    public static let octetStream = DICOMMediaType(type: "application", subtype: "octet-stream")
    
    /// JSON format
    public static let json = DICOMMediaType(type: "application", subtype: "json")
    
    // MARK: - Image Types
    
    /// JPEG image format
    public static let jpeg = DICOMMediaType(type: "image", subtype: "jpeg")
    
    /// PNG image format
    public static let png = DICOMMediaType(type: "image", subtype: "png")
    
    /// GIF image format
    public static let gif = DICOMMediaType(type: "image", subtype: "gif")
    
    /// JPEG 2000 image format
    public static let jp2 = DICOMMediaType(type: "image", subtype: "jp2")
    
    /// JPEG-LS image format
    public static let jpegLS = DICOMMediaType(type: "image", subtype: "jls")
    
    // MARK: - Video Types
    
    /// MPEG video format
    public static let mpeg = DICOMMediaType(type: "video", subtype: "mpeg")
    
    /// MP4 video format
    public static let mp4 = DICOMMediaType(type: "video", subtype: "mp4")
    
    /// H.265/HEVC video format
    public static let h265 = DICOMMediaType(type: "video", subtype: "H265")
    
    // MARK: - Multipart Types
    
    /// Multipart related for bundling multiple parts
    /// Reference: PS3.18 Section 8
    public static let multipartRelated = DICOMMediaType(type: "multipart", subtype: "related")
    
    // MARK: - Factory Methods
    
    /// Creates a DICOM media type with transfer syntax parameter
    /// - Parameter transferSyntax: The DICOM transfer syntax UID
    /// - Returns: A DICOM media type with transfer-syntax parameter
    public static func dicom(transferSyntax: String) -> DICOMMediaType {
        return dicom.withParameter("transfer-syntax", value: transferSyntax)
    }
    
    /// Creates a multipart/related media type with boundary and type parameters
    /// - Parameters:
    ///   - boundary: The MIME boundary string
    ///   - type: The type of the root part
    /// - Returns: A configured multipart/related media type
    public static func multipartRelated(boundary: String, type: DICOMMediaType) -> DICOMMediaType {
        return multipartRelated
            .withParameter("boundary", value: boundary)
            .withParameter("type", value: type.description)
    }
}

// MARK: - Transfer Syntax Parameters

extension DICOMMediaType {
    /// Common transfer syntax parameter values
    public enum TransferSyntax {
        /// Explicit VR Little Endian
        public static let explicitVRLittleEndian = "1.2.840.10008.1.2.1"
        
        /// Implicit VR Little Endian
        public static let implicitVRLittleEndian = "1.2.840.10008.1.2"
        
        /// Explicit VR Big Endian
        public static let explicitVRBigEndian = "1.2.840.10008.1.2.2"
        
        /// JPEG Baseline (Process 1)
        public static let jpegBaseline = "1.2.840.10008.1.2.4.50"
        
        /// JPEG Extended (Process 2 & 4)
        public static let jpegExtended = "1.2.840.10008.1.2.4.51"
        
        /// JPEG Lossless, Non-Hierarchical (Process 14)
        public static let jpegLossless = "1.2.840.10008.1.2.4.57"
        
        /// JPEG Lossless, Non-Hierarchical, First-Order Prediction (Process 14, Selection Value 1)
        public static let jpegLosslessSV1 = "1.2.840.10008.1.2.4.70"
        
        /// JPEG 2000 Image Compression (Lossless Only)
        public static let jpeg2000Lossless = "1.2.840.10008.1.2.4.90"
        
        /// JPEG 2000 Image Compression
        public static let jpeg2000 = "1.2.840.10008.1.2.4.91"
        
        /// RLE Lossless
        public static let rleLossless = "1.2.840.10008.1.2.5"
    }
    
    /// Gets the transfer syntax from parameters, if present
    public var transferSyntax: String? {
        return parameters["transfer-syntax"]
    }
}
