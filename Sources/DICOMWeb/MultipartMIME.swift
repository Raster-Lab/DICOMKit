import Foundation

/// Parser and generator for multipart MIME messages
///
/// Handles the multipart/related format used in DICOMweb for
/// transferring multiple DICOM objects or parts.
///
/// Reference: PS3.18 Section 8 - Multipart MIME
public struct MultipartMIME: Sendable {
    
    // MARK: - Types
    
    /// A single part in a multipart message
    public struct Part: Sendable {
        /// Content-Type header of this part
        public let contentType: DICOMMediaType
        
        /// Additional headers for this part
        public let headers: [String: String]
        
        /// Body data of this part
        public let body: Data
        
        /// Creates a multipart part
        /// - Parameters:
        ///   - contentType: The content type of this part
        ///   - headers: Additional headers
        ///   - body: The body data
        public init(contentType: DICOMMediaType, headers: [String: String] = [:], body: Data) {
            self.contentType = contentType
            self.headers = headers
            self.body = body
        }
        
        /// Creates a DICOM part with Part 10 file data
        /// - Parameter data: The DICOM Part 10 file data
        /// - Returns: A multipart part with application/dicom content type
        public static func dicom(_ data: Data, transferSyntax: String? = nil) -> Part {
            var mediaType = DICOMMediaType.dicom
            if let ts = transferSyntax {
                mediaType = mediaType.withParameter("transfer-syntax", value: ts)
            }
            return Part(contentType: mediaType, body: data)
        }
        
        /// Creates a JSON part
        /// - Parameter data: The JSON data
        /// - Returns: A multipart part with application/dicom+json content type
        public static func dicomJSON(_ data: Data) -> Part {
            return Part(contentType: .dicomJSON, body: data)
        }
        
        /// Creates a bulk data part
        /// - Parameters:
        ///   - data: The binary data
        ///   - contentID: Optional Content-ID header value
        /// - Returns: A multipart part with application/octet-stream content type
        public static func bulkData(_ data: Data, contentID: String? = nil) -> Part {
            var headers: [String: String] = [:]
            if let cid = contentID {
                headers["Content-ID"] = "<\(cid)>"
            }
            return Part(contentType: .octetStream, headers: headers, body: data)
        }
    }
    
    // MARK: - Properties
    
    /// The boundary string used to separate parts
    public let boundary: String
    
    /// The type of the root part (first part)
    public let rootType: DICOMMediaType?
    
    /// The parts in this multipart message
    public let parts: [Part]
    
    // MARK: - Initialization
    
    /// Creates a multipart message
    /// - Parameters:
    ///   - boundary: The boundary string (auto-generated if nil)
    ///   - rootType: The type of the root part
    ///   - parts: The parts to include
    public init(boundary: String? = nil, rootType: DICOMMediaType? = nil, parts: [Part] = []) {
        self.boundary = boundary ?? Self.generateBoundary()
        self.rootType = rootType ?? parts.first?.contentType
        self.parts = parts
    }
    
    // MARK: - Encoding
    
    /// Encodes the multipart message to data
    /// - Returns: The encoded multipart data
    public func encode() -> Data {
        var result = Data()
        
        for part in parts {
            // Boundary delimiter
            result.append(Data("--\(boundary)\r\n".utf8))
            
            // Content-Type header
            result.append(Data("Content-Type: \(part.contentType.description)\r\n".utf8))
            
            // Additional headers
            for (name, value) in part.headers.sorted(by: { $0.key < $1.key }) {
                result.append(Data("\(name): \(value)\r\n".utf8))
            }
            
            // Blank line before body
            result.append(Data("\r\n".utf8))
            
            // Body
            result.append(part.body)
            
            // End of body
            result.append(Data("\r\n".utf8))
        }
        
        // Final boundary
        result.append(Data("--\(boundary)--\r\n".utf8))
        
        return result
    }
    
    /// Returns the Content-Type header value for this multipart message
    public var contentType: DICOMMediaType {
        var mediaType = DICOMMediaType.multipartRelated
            .withParameter("boundary", value: boundary)
        
        if let root = rootType {
            mediaType = mediaType.withParameter("type", value: root.description)
        }
        
        return mediaType
    }
    
    // MARK: - Decoding
    
    /// Parses a multipart message from data
    /// - Parameters:
    ///   - data: The multipart data to parse
    ///   - boundary: The boundary string (if known from Content-Type header)
    /// - Returns: The parsed MultipartMIME
    /// - Throws: DICOMwebError if parsing fails
    public static func parse(data: Data, boundary: String? = nil) throws -> MultipartMIME {
        let boundaryStr: String
        
        if let b = boundary {
            boundaryStr = b
        } else {
            // Try to detect boundary from the data
            guard let detected = detectBoundary(in: data) else {
                throw DICOMwebError.invalidMultipart(reason: "Could not detect boundary")
            }
            boundaryStr = detected
        }
        
        let parts = try parseParts(data: data, boundary: boundaryStr)
        let rootType = parts.first?.contentType
        
        return MultipartMIME(boundary: boundaryStr, rootType: rootType, parts: parts)
    }
    
    /// Parses a multipart message from data using Content-Type header
    /// - Parameters:
    ///   - data: The multipart data to parse
    ///   - contentType: The Content-Type header value
    /// - Returns: The parsed MultipartMIME
    /// - Throws: DICOMwebError if parsing fails
    public static func parse(data: Data, contentType: String) throws -> MultipartMIME {
        guard let mediaType = DICOMMediaType.parse(contentType) else {
            throw DICOMwebError.invalidMultipart(reason: "Invalid Content-Type: \(contentType)")
        }
        
        guard mediaType.type == "multipart" else {
            throw DICOMwebError.invalidMultipart(reason: "Expected multipart type, got: \(mediaType.type)")
        }
        
        guard let boundary = mediaType.parameters["boundary"] else {
            throw DICOMwebError.invalidMultipart(reason: "Missing boundary parameter")
        }
        
        return try parse(data: data, boundary: boundary)
    }
    
    // MARK: - Private Methods
    
    private static func generateBoundary() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        let randomPart = String((0..<24).map { _ in chars.randomElement()! })
        return "----DICOMKitBoundary\(randomPart)"
    }
    
    private static func detectBoundary(in data: Data) -> String? {
        // Look for the first line starting with "--"
        guard let string = String(data: data.prefix(1000), encoding: .utf8) else {
            return nil
        }
        
        let lines = string.components(separatedBy: CharacterSet.newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("--") && trimmed.count > 2 && !trimmed.hasSuffix("--") {
                return String(trimmed.dropFirst(2))
            }
        }
        
        return nil
    }
    
    private static func parseParts(data: Data, boundary: String) throws -> [Part] {
        var parts: [Part] = []
        
        let delimiter = "--\(boundary)"
        let endDelimiter = "--\(boundary)--"
        
        guard let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw DICOMwebError.invalidMultipart(reason: "Could not decode multipart data")
        }
        
        // Split by delimiter
        let segments = string.components(separatedBy: delimiter)
        
        for (index, segment) in segments.enumerated() {
            // Skip preamble (first segment) and epilogue (after final delimiter)
            if index == 0 { continue }
            
            // Check for final delimiter
            let trimmed = segment.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if trimmed.hasPrefix("--") { break } // End delimiter
            
            // Parse this part
            if let part = try parsePartSegment(segment) {
                parts.append(part)
            }
        }
        
        return parts
    }
    
    private static func parsePartSegment(_ segment: String) throws -> Part? {
        // Remove leading CRLF using UTF8 view to handle grapheme cluster issues
        var content = segment
        let utf8 = content.utf8
        var dropCount = 0
        
        if let first = utf8.first, first == 13 {  // CR
            dropCount += 1
            if utf8.count > 1, utf8.dropFirst().first == 10 {  // LF
                dropCount += 1
            }
        } else if let first = utf8.first, first == 10 {  // LF only
            dropCount += 1
        }
        
        if dropCount > 0 {
            let startIndex = content.utf8.index(content.utf8.startIndex, offsetBy: dropCount)
            // String(Substring) is guaranteed to succeed for valid UTF8 slices
            content = String(content.utf8[startIndex...])!
        }
        
        // Find the blank line separating headers from body
        let headerBodySeparator: String
        if content.contains("\r\n\r\n") {
            headerBodySeparator = "\r\n\r\n"
        } else if content.contains("\n\n") {
            headerBodySeparator = "\n\n"
        } else {
            // No headers, entire content is body - create part with default content type
            let bodyData = content.data(using: .utf8) ?? Data()
            return Part(contentType: .octetStream, body: bodyData)
        }
        
        guard let separatorRange = content.range(of: headerBodySeparator) else {
            let bodyData = content.data(using: .utf8) ?? Data()
            return Part(contentType: .octetStream, body: bodyData)
        }
        
        let headerSection = String(content[..<separatorRange.lowerBound])
        let bodySection = String(content[separatorRange.upperBound...])
        
        // Parse headers
        var contentType: DICOMMediaType = .octetStream
        var headers: [String: String] = [:]
        
        // Parse headers - split by either CRLF or LF
        let headerLines: [String]
        if headerSection.contains("\r\n") {
            headerLines = headerSection.components(separatedBy: "\r\n")
        } else {
            headerLines = headerSection.components(separatedBy: "\n")
        }
        
        for line in headerLines {
            let trimmedLine = line.trimmingCharacters(in: CharacterSet.whitespaces)
            guard !trimmedLine.isEmpty else { continue }
            
            if let colonIndex = trimmedLine.firstIndex(of: ":") {
                let name = String(trimmedLine[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmedLine[trimmedLine.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                
                if name.lowercased() == "content-type" {
                    if let parsed = DICOMMediaType.parse(value) {
                        contentType = parsed
                    }
                } else {
                    headers[name] = value
                }
            }
        }
        
        // Convert body to data
        var bodyData = bodySection.data(using: .utf8) ?? Data()
        
        // Remove trailing CRLF if present
        if bodyData.count >= 2 {
            let suffix = bodyData.suffix(2)
            if suffix == Data([0x0D, 0x0A]) { // CRLF
                bodyData = bodyData.dropLast(2)
            }
        }
        if bodyData.count >= 1 {
            let suffix = bodyData.suffix(1)
            if suffix == Data([0x0A]) { // LF
                bodyData = bodyData.dropLast(1)
            }
        }
        
        return Part(contentType: contentType, headers: headers, body: bodyData)
    }
}

// MARK: - Builder Pattern

extension MultipartMIME {
    /// Builder for creating multipart messages
    public struct Builder: Sendable {
        private var boundary: String?
        private var rootType: DICOMMediaType?
        private var parts: [Part] = []
        
        /// Creates a new builder
        public init() {}
        
        /// Sets the boundary string
        /// - Parameter boundary: The boundary string
        /// - Returns: The builder for chaining
        public func withBoundary(_ boundary: String) -> Builder {
            var copy = self
            copy.boundary = boundary
            return copy
        }
        
        /// Sets the root type
        /// - Parameter type: The root part type
        /// - Returns: The builder for chaining
        public func withRootType(_ type: DICOMMediaType) -> Builder {
            var copy = self
            copy.rootType = type
            return copy
        }
        
        /// Adds a part
        /// - Parameter part: The part to add
        /// - Returns: The builder for chaining
        public func addPart(_ part: Part) -> Builder {
            var copy = self
            copy.parts.append(part)
            return copy
        }
        
        /// Adds a DICOM part
        /// - Parameters:
        ///   - data: The DICOM Part 10 data
        ///   - transferSyntax: Optional transfer syntax
        /// - Returns: The builder for chaining
        public func addDICOM(_ data: Data, transferSyntax: String? = nil) -> Builder {
            return addPart(.dicom(data, transferSyntax: transferSyntax))
        }
        
        /// Adds a DICOM JSON part
        /// - Parameter data: The JSON data
        /// - Returns: The builder for chaining
        public func addDICOMJSON(_ data: Data) -> Builder {
            return addPart(.dicomJSON(data))
        }
        
        /// Adds a bulk data part
        /// - Parameters:
        ///   - data: The binary data
        ///   - contentID: Optional Content-ID
        /// - Returns: The builder for chaining
        public func addBulkData(_ data: Data, contentID: String? = nil) -> Builder {
            return addPart(.bulkData(data, contentID: contentID))
        }
        
        /// Builds the multipart message
        /// - Returns: The built MultipartMIME
        public func build() -> MultipartMIME {
            return MultipartMIME(boundary: boundary, rootType: rootType, parts: parts)
        }
    }
    
    /// Creates a builder for this multipart message
    public static func builder() -> Builder {
        return Builder()
    }
}
