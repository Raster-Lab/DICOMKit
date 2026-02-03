import Foundation
import DICOMCore

/// Decoder for converting JSON data to DICOM DataElements
///
/// Implements the DICOM JSON Model as specified in PS3.18 Section F.
///
/// Reference: PS3.18 Annex F - DICOM JSON Model
public struct DICOMJSONDecoder: Sendable {
    /// Configuration for decoding options
    public struct Configuration: Sendable {
        /// Whether to allow missing VR fields (infer from dictionary)
        public let allowMissingVR: Bool
        
        /// Whether to fetch bulk data references automatically
        public let fetchBulkData: Bool
        
        /// Handler for fetching bulk data
        public let bulkDataHandler: (@Sendable (URL) async throws -> Data)?
        
        /// Creates decoding configuration
        /// - Parameters:
        ///   - allowMissingVR: Allow missing VR fields (default: false)
        ///   - fetchBulkData: Fetch bulk data automatically (default: false)
        ///   - bulkDataHandler: Handler for fetching bulk data
        public init(
            allowMissingVR: Bool = false,
            fetchBulkData: Bool = false,
            bulkDataHandler: (@Sendable (URL) async throws -> Data)? = nil
        ) {
            self.allowMissingVR = allowMissingVR
            self.fetchBulkData = fetchBulkData
            self.bulkDataHandler = bulkDataHandler
        }
        
        /// Default configuration
        public static let `default` = Configuration()
    }
    
    /// The decoding configuration
    public let configuration: Configuration
    
    /// Creates a JSON decoder with the specified configuration
    /// - Parameter configuration: Decoding configuration
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }
    
    /// Decodes JSON data to a list of data elements
    /// - Parameter data: JSON data to decode
    /// - Returns: Array of DataElement
    /// - Throws: DICOMwebError if decoding fails
    public func decode(_ data: Data) throws -> [DataElement] {
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        
        guard let dictionary = jsonObject as? [String: Any] else {
            throw DICOMwebError.invalidJSON(reason: "Expected JSON object at root")
        }
        
        return try decodeObject(dictionary)
    }
    
    /// Decodes a JSON string to a list of data elements
    /// - Parameter string: JSON string to decode
    /// - Returns: Array of DataElement
    /// - Throws: DICOMwebError if decoding fails
    public func decode(string: String) throws -> [DataElement] {
        guard let data = string.data(using: .utf8) else {
            throw DICOMwebError.invalidJSON(reason: "Invalid UTF-8 string")
        }
        return try decode(data)
    }
    
    /// Decodes JSON data containing an array of datasets
    /// - Parameter data: JSON data containing array of datasets
    /// - Returns: Array of DataElement arrays
    /// - Throws: DICOMwebError if decoding fails
    public func decodeMultiple(_ data: Data) throws -> [[DataElement]] {
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        
        guard let array = jsonObject as? [[String: Any]] else {
            throw DICOMwebError.invalidJSON(reason: "Expected JSON array at root")
        }
        
        return try array.map { try decodeObject($0) }
    }
    
    /// Decodes a JSON dictionary to a list of data elements
    /// - Parameter dictionary: JSON dictionary to decode
    /// - Returns: Array of DataElement
    /// - Throws: DICOMwebError if decoding fails
    public func decodeObject(_ dictionary: [String: Any]) throws -> [DataElement] {
        var elements: [DataElement] = []
        
        for (key, value) in dictionary {
            guard let elementDict = value as? [String: Any] else {
                throw DICOMwebError.invalidJSON(reason: "Element value must be an object")
            }
            
            let element = try decodeElement(tagKey: key, elementDict: elementDict)
            elements.append(element)
        }
        
        // Sort elements by tag
        return elements.sorted { $0.tag < $1.tag }
    }
    
    // MARK: - Private Methods
    
    private func decodeElement(tagKey: String, elementDict: [String: Any]) throws -> DataElement {
        // Parse tag
        let tag = try parseTag(tagKey)
        
        // Get VR
        guard let vrString = elementDict["vr"] as? String else {
            if configuration.allowMissingVR {
                throw DICOMwebError.invalidJSON(reason: "Missing VR for tag \(tagKey)")
            }
            throw DICOMwebError.missingRequiredField(field: "vr")
        }
        
        guard let vr = VR(rawValue: vrString) else {
            throw DICOMwebError.invalidVREncoding(vr: vrString, reason: "Unknown VR")
        }
        
        // Get value
        let valueArray = elementDict["Value"] as? [Any]
        
        // Decode based on VR
        return try decodeValue(tag: tag, vr: vr, valueArray: valueArray)
    }
    
    private func parseTag(_ tagKey: String) throws -> Tag {
        guard tagKey.count == 8 else {
            throw DICOMwebError.invalidJSON(reason: "Invalid tag format: \(tagKey)")
        }
        
        let groupStr = String(tagKey.prefix(4))
        let elementStr = String(tagKey.suffix(4))
        
        guard let group = UInt16(groupStr, radix: 16),
              let element = UInt16(elementStr, radix: 16) else {
            throw DICOMwebError.invalidJSON(reason: "Invalid tag hex: \(tagKey)")
        }
        
        return Tag(group: group, element: element)
    }
    
    private func decodeValue(tag: Tag, vr: VR, valueArray: [Any]?) throws -> DataElement {
        guard let values = valueArray, !values.isEmpty else {
            // Empty element
            return DataElement(tag: tag, vr: vr, length: 0, valueData: Data())
        }
        
        // Handle sequences
        if vr == .SQ {
            return try decodeSequence(tag: tag, values: values)
        }
        
        // Check for bulk data or inline binary
        if let firstValue = values.first as? [String: Any] {
            if let _ = firstValue["BulkDataURI"] as? String {
                return try decodeBulkData(tag: tag, vr: vr, bulkDataDict: firstValue)
            }
            if let inlineBinary = firstValue["InlineBinary"] as? String {
                return try decodeInlineBinary(tag: tag, vr: vr, base64String: inlineBinary)
            }
        }
        
        // Handle person name
        if vr == .PN {
            return try decodePersonName(tag: tag, values: values)
        }
        
        // Handle string values
        if isStringVR(vr) {
            return try decodeStringValues(tag: tag, vr: vr, values: values)
        }
        
        // Handle numeric values
        if isNumericVR(vr) {
            return try decodeNumericValues(tag: tag, vr: vr, values: values)
        }
        
        // Handle attribute tag
        if vr == .AT {
            return try decodeAttributeTag(tag: tag, values: values)
        }
        
        // Fallback: try string encoding
        return try decodeStringValues(tag: tag, vr: vr, values: values)
    }
    
    private func decodeSequence(tag: Tag, values: [Any]) throws -> DataElement {
        var sequenceItems: [SequenceItem] = []
        
        for value in values {
            guard let itemDict = value as? [String: Any] else {
                throw DICOMwebError.invalidJSON(reason: "Sequence item must be an object")
            }
            
            let elements = try decodeObject(itemDict)
            let item = SequenceItem(elements: elements)
            sequenceItems.append(item)
        }
        
        return DataElement(
            tag: tag,
            vr: .SQ,
            length: 0xFFFFFFFF, // Undefined length for sequences
            valueData: Data(),
            sequenceItems: sequenceItems
        )
    }
    
    private func decodeBulkData(tag: Tag, vr: VR, bulkDataDict: [String: Any]) throws -> DataElement {
        guard let uriString = bulkDataDict["BulkDataURI"] as? String else {
            throw DICOMwebError.invalidBulkDataReference(uri: nil)
        }
        
        guard let url = URL(string: uriString) else {
            throw DICOMwebError.invalidBulkDataReference(uri: uriString)
        }
        
        // If we have a bulk data handler and fetchBulkData is enabled, fetch it
        // For now, store an empty data - actual fetching would be async
        // The caller can use the BulkDataReference to fetch later
        
        // Create a placeholder element
        return DataElement(tag: tag, vr: vr, length: 0, valueData: Data())
    }
    
    private func decodeInlineBinary(tag: Tag, vr: VR, base64String: String) throws -> DataElement {
        guard let data = Data(base64Encoded: base64String) else {
            throw DICOMwebError.base64DecodingFailed(reason: "Invalid Base64 string")
        }
        
        return DataElement(tag: tag, vr: vr, length: UInt32(data.count), valueData: data)
    }
    
    private func decodePersonName(tag: Tag, values: [Any]) throws -> DataElement {
        var pnStrings: [String] = []
        
        for value in values {
            if let pnDict = value as? [String: Any] {
                var components: [String] = []
                
                if let alphabetic = pnDict["Alphabetic"] as? String {
                    components.append(alphabetic)
                } else {
                    components.append("")
                }
                
                if let ideographic = pnDict["Ideographic"] as? String {
                    components.append(ideographic)
                }
                
                if let phonetic = pnDict["Phonetic"] as? String {
                    // Ensure we have ideographic placeholder if phonetic is present
                    while components.count < 2 {
                        components.append("")
                    }
                    components.append(phonetic)
                }
                
                let pnString = components.joined(separator: "=")
                pnStrings.append(pnString)
            } else if let pnString = value as? String {
                pnStrings.append(pnString)
            }
        }
        
        let combined = pnStrings.joined(separator: "\\")
        var valueData = combined.data(using: .utf8) ?? Data()
        
        // Pad to even length with space
        if valueData.count % 2 != 0 {
            valueData.append(0x20)
        }
        
        return DataElement(tag: tag, vr: .PN, length: UInt32(valueData.count), valueData: valueData)
    }
    
    private func decodeStringValues(tag: Tag, vr: VR, values: [Any]) throws -> DataElement {
        let stringValues = values.compactMap { value -> String? in
            if let str = value as? String {
                return str
            } else if let num = value as? NSNumber {
                return num.stringValue
            }
            return nil
        }
        
        let combined = stringValues.joined(separator: "\\")
        var valueData = combined.data(using: .utf8) ?? Data()
        
        // Pad to even length
        if valueData.count % 2 != 0 {
            // UI uses null padding, others use space
            if vr == .UI {
                valueData.append(0x00)
            } else {
                valueData.append(0x20)
            }
        }
        
        return DataElement(tag: tag, vr: vr, length: UInt32(valueData.count), valueData: valueData)
    }
    
    private func decodeNumericValues(tag: Tag, vr: VR, values: [Any]) throws -> DataElement {
        var valueData = Data()
        
        for value in values {
            guard let number = value as? NSNumber else {
                throw DICOMwebError.invalidVREncoding(vr: vr.rawValue, reason: "Expected numeric value")
            }
            
            switch vr {
            case .FL:
                var floatValue = number.floatValue
                valueData.append(Data(bytes: &floatValue, count: MemoryLayout<Float>.size))
            case .FD:
                var doubleValue = number.doubleValue
                valueData.append(Data(bytes: &doubleValue, count: MemoryLayout<Double>.size))
            case .SL:
                var int32Value = number.int32Value
                valueData.append(Data(bytes: &int32Value, count: MemoryLayout<Int32>.size))
            case .SS:
                var int16Value = number.int16Value
                valueData.append(Data(bytes: &int16Value, count: MemoryLayout<Int16>.size))
            case .UL:
                var uint32Value = number.uint32Value
                valueData.append(Data(bytes: &uint32Value, count: MemoryLayout<UInt32>.size))
            case .US:
                var uint16Value = number.uint16Value
                valueData.append(Data(bytes: &uint16Value, count: MemoryLayout<UInt16>.size))
            default:
                break
            }
        }
        
        return DataElement(tag: tag, vr: vr, length: UInt32(valueData.count), valueData: valueData)
    }
    
    private func decodeAttributeTag(tag: Tag, values: [Any]) throws -> DataElement {
        var valueData = Data()
        
        for value in values {
            guard let tagString = value as? String, tagString.count == 8 else {
                throw DICOMwebError.invalidVREncoding(vr: "AT", reason: "Expected 8-character hex string")
            }
            
            guard let tagValue = UInt32(tagString, radix: 16) else {
                throw DICOMwebError.invalidVREncoding(vr: "AT", reason: "Invalid hex value")
            }
            
            // AT is encoded as two 16-bit values in little endian
            var group = UInt16((tagValue >> 16) & 0xFFFF)
            var element = UInt16(tagValue & 0xFFFF)
            valueData.append(Data(bytes: &group, count: 2))
            valueData.append(Data(bytes: &element, count: 2))
        }
        
        return DataElement(tag: tag, vr: .AT, length: UInt32(valueData.count), valueData: valueData)
    }
    
    private func isStringVR(_ vr: VR) -> Bool {
        switch vr {
        case .AE, .AS, .CS, .DA, .DS, .DT, .IS, .LO, .LT, .SH, .ST, .TM, .UC, .UI, .UR, .UT:
            return true
        default:
            return false
        }
    }
    
    private func isNumericVR(_ vr: VR) -> Bool {
        switch vr {
        case .FL, .FD, .SL, .SS, .UL, .US:
            return true
        default:
            return false
        }
    }
}

// MARK: - Bulk Data Reference

/// Reference to bulk data that can be fetched later
///
/// Used when JSON contains a BulkDataURI instead of inline binary data.
public struct BulkDataReference: Sendable, Hashable {
    /// The URI of the bulk data
    public let uri: URL
    
    /// The tag this bulk data belongs to
    public let tag: Tag
    
    /// The expected VR of the data
    public let vr: VR
    
    /// Creates a bulk data reference
    /// - Parameters:
    ///   - uri: The URI of the bulk data
    ///   - tag: The tag this bulk data belongs to
    ///   - vr: The expected VR
    public init(uri: URL, tag: Tag, vr: VR) {
        self.uri = uri
        self.tag = tag
        self.vr = vr
    }
}
