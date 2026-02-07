import Foundation
import DICOMCore
import DICOMDictionary

/// Encoder for converting DICOM DataSets to XML format
///
/// Implements the DICOM Native XML Model as specified in PS3.19.
/// The XML format uses the NativeDicomModel root element with DicomAttribute
/// elements for each DICOM tag.
///
/// Reference: PS3.19 - Application Hosting
public struct DICOMXMLEncoder: Sendable {
    /// Configuration for encoding options
    public struct Configuration: Sendable {
        /// Whether to include empty values
        public let includeEmptyValues: Bool
        
        /// Whether to use inline binary (Base64) for bulk data
        public let inlineBinaryThreshold: Int?
        
        /// Base URL for generating bulk data URIs
        public let bulkDataBaseURL: URL?
        
        /// Whether to output pretty-printed XML
        public let prettyPrinted: Bool
        
        /// Whether to include keyword attributes
        public let includeKeywords: Bool
        
        /// Creates encoding configuration
        /// - Parameters:
        ///   - includeEmptyValues: Include empty values (default: false)
        ///   - inlineBinaryThreshold: Inline binary up to this size in bytes (nil for always URI)
        ///   - bulkDataBaseURL: Base URL for bulk data URIs
        ///   - prettyPrinted: Pretty print XML (default: false)
        ///   - includeKeywords: Include keyword attributes (default: true)
        public init(
            includeEmptyValues: Bool = false,
            inlineBinaryThreshold: Int? = 1024,
            bulkDataBaseURL: URL? = nil,
            prettyPrinted: Bool = false,
            includeKeywords: Bool = true
        ) {
            self.includeEmptyValues = includeEmptyValues
            self.inlineBinaryThreshold = inlineBinaryThreshold
            self.bulkDataBaseURL = bulkDataBaseURL
            self.prettyPrinted = prettyPrinted
            self.includeKeywords = includeKeywords
        }
        
        /// Default configuration
        public static let `default` = Configuration()
    }
    
    /// The encoding configuration
    public let configuration: Configuration
    
    /// Creates an XML encoder with the specified configuration
    /// - Parameter configuration: Encoding configuration
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }
    
    /// Encodes a list of data elements to XML data
    /// - Parameter elements: The data elements to encode
    /// - Returns: XML encoded data
    /// - Throws: DICOMwebError if encoding fails
    public func encode(_ elements: [DataElement]) throws -> Data {
        let xmlString = try encodeToString(elements)
        guard let data = xmlString.data(using: .utf8) else {
            throw DICOMwebError.invalidXML(reason: "Failed to encode XML string to UTF-8 data")
        }
        return data
    }
    
    /// Encodes a list of data elements to an XML string
    /// - Parameter elements: The data elements to encode
    /// - Returns: XML string
    /// - Throws: DICOMwebError if encoding fails
    public func encodeToString(_ elements: [DataElement]) throws -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<NativeDicomModel xmlns=\"http://dicom.nema.org/PS3.19/models/NativeDICOM\">\n"
        
        for element in elements {
            if !configuration.includeEmptyValues && element.valueData.isEmpty {
                continue
            }
            
            let elementXML = try encodeElement(element, indent: configuration.prettyPrinted ? "  " : "")
            xml += elementXML
        }
        
        xml += "</NativeDicomModel>\n"
        return xml
    }
    
    /// Encodes a single data element to XML
    private func encodeElement(_ element: DataElement, indent: String) throws -> String {
        let tag = String(format: "%04X%04X", element.tag.group, element.tag.element)
        let vr = element.vr.rawValue
        
        var attributes = "tag=\"\(tag)\" vr=\"\(vr)\""
        
        // Add keyword if enabled
        if configuration.includeKeywords,
           let entry = DataElementDictionary.lookup(tag: element.tag) {
            attributes += " keyword=\"\(entry.keyword)\""
        }
        
        var xml = "\(indent)<DicomAttribute \(attributes)>\n"
        
        // Handle sequences
        if element.vr == .SQ, let sequence = element.sequenceItems {
            for (index, item) in sequence.enumerated() {
                xml += "\(indent)  <Item number=\"\(index + 1)\">\n"
                for childElement in item.allElements {
                    let childXML = try encodeElement(childElement, indent: indent + "    ")
                    xml += childXML
                }
                xml += "\(indent)  </Item>\n"
            }
        }
        // Handle binary bulk data
        else if isBinaryVR(element.vr) {
            let shouldInline: Bool
            if let threshold = configuration.inlineBinaryThreshold {
                shouldInline = element.valueData.count <= threshold
            } else {
                shouldInline = false
            }
            
            if shouldInline {
                let base64 = element.valueData.base64EncodedString()
                xml += "\(indent)  <InlineBinary>\(base64)</InlineBinary>\n"
            } else if let baseURL = configuration.bulkDataBaseURL {
                // Generate bulk data URI (using tag as identifier)
                let uri = baseURL.appendingPathComponent(tag).absoluteString
                xml += "\(indent)  <BulkData uri=\"\(uri)\"/>\n"
            } else {
                // Default to inline if no base URL specified
                let base64 = element.valueData.base64EncodedString()
                xml += "\(indent)  <InlineBinary>\(base64)</InlineBinary>\n"
            }
        }
        // Handle PersonName specially
        else if element.vr == .PN {
            if let values = element.stringValues {
                for (index, value) in values.enumerated() {
                    xml += encodePersonName(value, number: index + 1, indent: indent + "  ")
                }
            }
        }
        // Handle other values
        else {
            if let values = element.stringValues {
                for (index, value) in values.enumerated() {
                    let escapedValue = escapeXML(value)
                    xml += "\(indent)  <Value number=\"\(index + 1)\">\(escapedValue)</Value>\n"
                }
            }
        }
        
        xml += "\(indent)</DicomAttribute>\n"
        return xml
    }
    
    /// Encodes a PersonName value
    private func encodePersonName(_ value: String, number: Int, indent: String) -> String {
        var xml = "\(indent)<PersonName number=\"\(number)\">\n"
        
        // Parse PersonName components (Alphabetic^Ideographic^Phonetic)
        let components = value.split(separator: "=", maxSplits: 2).map(String.init)
        
        // Alphabetic component (required)
        if !components.isEmpty && !components[0].isEmpty {
            xml += "\(indent)  <Alphabetic>\n"
            xml += encodePersonNameComponent(components[0], indent: indent + "    ")
            xml += "\(indent)  </Alphabetic>\n"
        }
        
        // Ideographic component (optional)
        if components.count > 1 && !components[1].isEmpty {
            xml += "\(indent)  <Ideographic>\n"
            xml += encodePersonNameComponent(components[1], indent: indent + "    ")
            xml += "\(indent)  </Ideographic>\n"
        }
        
        // Phonetic component (optional)
        if components.count > 2 && !components[2].isEmpty {
            xml += "\(indent)  <Phonetic>\n"
            xml += encodePersonNameComponent(components[2], indent: indent + "    ")
            xml += "\(indent)  </Phonetic>\n"
        }
        
        xml += "\(indent)</PersonName>\n"
        return xml
    }
    
    /// Encodes a PersonName component (Family^Given^Middle^Prefix^Suffix)
    private func encodePersonNameComponent(_ component: String, indent: String) -> String {
        let parts = component.split(separator: "^", maxSplits: 4).map(String.init)
        var xml = ""
        
        if !parts.isEmpty && !parts[0].isEmpty {
            xml += "\(indent)<FamilyName>\(escapeXML(parts[0]))</FamilyName>\n"
        }
        if parts.count > 1 && !parts[1].isEmpty {
            xml += "\(indent)<GivenName>\(escapeXML(parts[1]))</GivenName>\n"
        }
        if parts.count > 2 && !parts[2].isEmpty {
            xml += "\(indent)<MiddleName>\(escapeXML(parts[2]))</MiddleName>\n"
        }
        if parts.count > 3 && !parts[3].isEmpty {
            xml += "\(indent)<NamePrefix>\(escapeXML(parts[3]))</NamePrefix>\n"
        }
        if parts.count > 4 && !parts[4].isEmpty {
            xml += "\(indent)<NameSuffix>\(escapeXML(parts[4]))</NameSuffix>\n"
        }
        
        return xml
    }
    
    /// Checks if a VR represents binary data
    private func isBinaryVR(_ vr: VR) -> Bool {
        switch vr {
        case .OB, .OD, .OF, .OL, .OW, .UN:
            return true
        default:
            return false
        }
    }
    
    /// Escapes special XML characters
    private func escapeXML(_ string: String) -> String {
        var escaped = string
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }
}
