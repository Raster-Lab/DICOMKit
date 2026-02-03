import Foundation
import DICOMCore

/// Encoder for converting DICOM DataSets to JSON format
///
/// Implements the DICOM JSON Model as specified in PS3.18 Section F.
/// The JSON format uses the tag as the key and includes value representation
/// and values in a structured format.
///
/// Reference: PS3.18 Annex F - DICOM JSON Model
public struct DICOMJSONEncoder: Sendable {
    /// Configuration for encoding options
    public struct Configuration: Sendable {
        /// Whether to include empty values
        public let includeEmptyValues: Bool
        
        /// Whether to use inline binary (Base64) for bulk data
        public let inlineBinaryThreshold: Int?
        
        /// Base URL for generating bulk data URIs
        public let bulkDataBaseURL: URL?
        
        /// Whether to output pretty-printed JSON
        public let prettyPrinted: Bool
        
        /// Whether to sort keys alphabetically
        public let sortedKeys: Bool
        
        /// Creates encoding configuration
        /// - Parameters:
        ///   - includeEmptyValues: Include empty values (default: false)
        ///   - inlineBinaryThreshold: Inline binary up to this size in bytes (nil for always URI)
        ///   - bulkDataBaseURL: Base URL for bulk data URIs
        ///   - prettyPrinted: Pretty print JSON (default: false)
        ///   - sortedKeys: Sort keys (default: true)
        public init(
            includeEmptyValues: Bool = false,
            inlineBinaryThreshold: Int? = 1024,
            bulkDataBaseURL: URL? = nil,
            prettyPrinted: Bool = false,
            sortedKeys: Bool = true
        ) {
            self.includeEmptyValues = includeEmptyValues
            self.inlineBinaryThreshold = inlineBinaryThreshold
            self.bulkDataBaseURL = bulkDataBaseURL
            self.prettyPrinted = prettyPrinted
            self.sortedKeys = sortedKeys
        }
        
        /// Default configuration
        public static let `default` = Configuration()
    }
    
    /// The encoding configuration
    public let configuration: Configuration
    
    /// Creates a JSON encoder with the specified configuration
    /// - Parameter configuration: Encoding configuration
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }
    
    /// Encodes a list of data elements to JSON data
    /// - Parameter elements: The data elements to encode
    /// - Returns: JSON encoded data
    /// - Throws: DICOMwebError if encoding fails
    public func encode(_ elements: [DataElement]) throws -> Data {
        let jsonObject = try encodeToObject(elements)
        
        var options: JSONSerialization.WritingOptions = []
        if configuration.prettyPrinted {
            options.insert(.prettyPrinted)
        }
        if configuration.sortedKeys {
            options.insert(.sortedKeys)
        }
        
        return try JSONSerialization.data(withJSONObject: jsonObject, options: options)
    }
    
    /// Encodes a list of data elements to a JSON string
    /// - Parameter elements: The data elements to encode
    /// - Returns: JSON string
    /// - Throws: DICOMwebError if encoding fails
    public func encodeToString(_ elements: [DataElement]) throws -> String {
        let data = try encode(elements)
        guard let string = String(data: data, encoding: .utf8) else {
            throw DICOMwebError.invalidJSON(reason: "Failed to create UTF-8 string")
        }
        return string
    }
    
    /// Encodes a list of data elements to a JSON-compatible dictionary
    /// - Parameter elements: The data elements to encode
    /// - Returns: Dictionary representing the DICOM JSON
    /// - Throws: DICOMwebError if encoding fails
    public func encodeToObject(_ elements: [DataElement]) throws -> [String: Any] {
        var result: [String: Any] = [:]
        
        for element in elements {
            let tagKey = element.tag.hexString
            let encoded = try encodeElement(element)
            if !encoded.isEmpty || configuration.includeEmptyValues {
                result[tagKey] = encoded
            }
        }
        
        return result
    }
    
    /// Encodes multiple data element lists (for search results)
    /// - Parameter elementLists: Array of data element lists
    /// - Returns: JSON encoded data as array
    /// - Throws: DICOMwebError if encoding fails
    public func encodeMultiple(_ elementLists: [[DataElement]]) throws -> Data {
        let jsonArray = try elementLists.map { try encodeToObject($0) }
        
        var options: JSONSerialization.WritingOptions = []
        if configuration.prettyPrinted {
            options.insert(.prettyPrinted)
        }
        if configuration.sortedKeys {
            options.insert(.sortedKeys)
        }
        
        return try JSONSerialization.data(withJSONObject: jsonArray, options: options)
    }
    
    // MARK: - Private Methods
    
    private func encodeElement(_ element: DataElement) throws -> [String: Any] {
        var result: [String: Any] = [:]
        
        // VR field
        result["vr"] = element.vr.rawValue
        
        // Value field
        let value = try encodeValue(element)
        if let v = value {
            result["Value"] = v
        }
        
        return result
    }
    
    private func encodeValue(_ element: DataElement) throws -> [Any]? {
        // Handle sequences
        if element.vr == .SQ {
            return try encodeSequence(element)
        }
        
        // Handle bulk data (OB, OD, OF, OL, OW, UN with large data)
        if shouldEncodeBulkData(element) {
            return try encodeBulkData(element)
        }
        
        // Handle inline binary (OB, OD, OF, OL, OW, UN with small data)
        if isInlineBinaryVR(element.vr) && !element.valueData.isEmpty {
            return [["InlineBinary": element.valueData.base64EncodedString()]]
        }
        
        // Handle string-based VRs
        if let stringValues = encodeStringValues(element) {
            return stringValues.isEmpty && !configuration.includeEmptyValues ? nil : stringValues
        }
        
        // Handle numeric VRs
        if let numericValues = encodeNumericValues(element) {
            return numericValues.isEmpty && !configuration.includeEmptyValues ? nil : numericValues
        }
        
        // Handle Person Name
        if element.vr == .PN {
            return try encodePersonName(element)
        }
        
        // Handle empty value
        if element.valueData.isEmpty {
            return configuration.includeEmptyValues ? [] : nil
        }
        
        // Fallback: encode as string
        if let stringValue = element.stringValue {
            return [stringValue]
        }
        
        return nil
    }
    
    private func encodeSequence(_ element: DataElement) throws -> [Any]? {
        guard let items = element.sequenceItems else {
            return nil
        }
        
        var result: [[String: Any]] = []
        
        for item in items {
            let itemEncoded = try encodeToObject(item.allElements)
            result.append(itemEncoded)
        }
        
        return result.isEmpty && !configuration.includeEmptyValues ? nil : result
    }
    
    private func shouldEncodeBulkData(_ element: DataElement) -> Bool {
        guard isInlineBinaryVR(element.vr) else { return false }
        
        if let threshold = configuration.inlineBinaryThreshold {
            return element.valueData.count > threshold
        }
        return configuration.bulkDataBaseURL != nil
    }
    
    private func isInlineBinaryVR(_ vr: VR) -> Bool {
        switch vr {
        case .OB, .OD, .OF, .OL, .OW, .UN:
            return true
        default:
            return false
        }
    }
    
    private func encodeBulkData(_ element: DataElement) throws -> [Any]? {
        // If we have a bulk data URL, generate a BulkDataURI
        if let baseURL = configuration.bulkDataBaseURL {
            let uri = baseURL.appendingPathComponent(element.tag.hexString).absoluteString
            return [["BulkDataURI": uri]]
        }
        
        // Otherwise, encode as inline binary
        return [["InlineBinary": element.valueData.base64EncodedString()]]
    }
    
    private func encodeStringValues(_ element: DataElement) -> [Any]? {
        switch element.vr {
        case .AE, .AS, .CS, .DA, .DS, .DT, .IS, .LO, .LT, .SH, .ST, .TM, .UC, .UI, .UR, .UT:
            if let values = element.stringValues {
                return values
            } else if let value = element.stringValue {
                return [value]
            }
            return element.valueData.isEmpty ? [] : nil
        default:
            return nil
        }
    }
    
    private func encodeNumericValues(_ element: DataElement) -> [Any]? {
        switch element.vr {
        case .FL:
            return element.float32Values.map { $0.map { $0 as Any } }
        case .FD:
            return element.float64Values.map { $0.map { $0 as Any } }
        case .SL:
            return element.int32Values.map { $0.map { $0 as Any } }
        case .SS:
            return element.int16Values.map { $0.map { $0 as Any } }
        case .UL:
            return element.uint32Values.map { $0.map { $0 as Any } }
        case .US:
            return element.uint16Values.map { $0.map { $0 as Any } }
        case .AT:
            // Attribute Tag - encode as string "GGGGEEEE"
            if let values = element.uint32Values {
                return values.map { String(format: "%08X", $0) }
            }
            return nil
        default:
            return nil
        }
    }
    
    private func encodePersonName(_ element: DataElement) throws -> [Any]? {
        guard let pnValues = element.personNameValues else {
            if let pn = element.personNameValue {
                return [encodePersonNameValue(pn)]
            }
            return element.valueData.isEmpty ? [] : nil
        }
        
        return pnValues.map { encodePersonNameValue($0) }
    }
    
    private func encodePersonNameValue(_ pn: DICOMPersonName) -> [String: Any] {
        var result: [String: Any] = [:]
        
        // Alphabetic component
        let alphabeticStr = pn.alphabetic.dicomString
        if !alphabeticStr.isEmpty {
            result["Alphabetic"] = alphabeticStr
        }
        
        // Ideographic component
        let ideographicStr = pn.ideographic.dicomString
        if !ideographicStr.isEmpty {
            result["Ideographic"] = ideographicStr
        }
        
        // Phonetic component
        let phoneticStr = pn.phonetic.dicomString
        if !phoneticStr.isEmpty {
            result["Phonetic"] = phoneticStr
        }
        
        return result
    }
}

// MARK: - Tag Extension

extension Tag {
    /// Returns the tag as an 8-character hexadecimal string (GGGGEEEE)
    var hexString: String {
        return String(format: "%04X%04X", group, element)
    }
}
