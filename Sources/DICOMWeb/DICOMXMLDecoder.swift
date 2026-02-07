import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import DICOMCore
import DICOMDictionary

/// Decoder for converting XML to DICOM DataSets
///
/// Implements parsing of the DICOM Native XML Model as specified in PS3.19.
///
/// Reference: PS3.19 - Application Hosting
public struct DICOMXMLDecoder: Sendable {
    /// Configuration for decoding options
    public struct Configuration: Sendable {
        /// Whether to allow missing VR attributes
        public let allowMissingVR: Bool
        
        /// Whether to fetch bulk data from URIs
        public let fetchBulkData: Bool
        
        /// Handler for bulk data URIs
        public let bulkDataHandler: (@Sendable (String) async throws -> Data)?
        
        /// Creates decoding configuration
        /// - Parameters:
        ///   - allowMissingVR: Allow missing VR (infer from tag dictionary)
        ///   - fetchBulkData: Fetch bulk data from URIs (default: false)
        ///   - bulkDataHandler: Custom handler for fetching bulk data
        public init(
            allowMissingVR: Bool = true,
            fetchBulkData: Bool = false,
            bulkDataHandler: (@Sendable (String) async throws -> Data)? = nil
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
    
    /// Creates an XML decoder with the specified configuration
    /// - Parameter configuration: Decoding configuration
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }
    
    /// Decodes XML data to a list of data elements
    /// - Parameter data: XML data to decode
    /// - Returns: Array of data elements
    /// - Throws: DICOMwebError if decoding fails
    public func decode(_ data: Data) throws -> [DataElement] {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw DICOMwebError.invalidXML(reason: "Failed to decode XML data as UTF-8")
        }
        return try decode(xmlString)
    }
    
    /// Decodes XML string to a list of data elements
    /// - Parameter xmlString: XML string to decode
    /// - Returns: Array of data elements
    /// - Throws: DICOMwebError if decoding fails
    public func decode(_ xmlString: String) throws -> [DataElement] {
        let parser = XMLParser(data: Data(xmlString.utf8))
        let delegate = ParserDelegate(configuration: configuration)
        parser.delegate = delegate
        
        guard parser.parse() else {
            if let error = parser.parserError {
                throw DICOMwebError.invalidXML(reason: "XML parsing failed: \(error.localizedDescription)")
            } else {
                throw DICOMwebError.invalidXML(reason: "XML parsing failed with unknown error")
            }
        }
        
        return delegate.elements
    }
    
    // MARK: - XML Parser Delegate
    
    private class ParserDelegate: NSObject, XMLParserDelegate {
        let configuration: Configuration
        var elements: [DataElement] = []
        
        // Stack for nested structures
        private var elementStack: [StackEntry] = []
        private var currentText = ""
        
        enum StackEntry {
            case attribute(tag: Tag, vr: VR?, values: [String], personNames: [PersonNameBuilder], items: [SequenceItem], binaryData: Data?, bulkDataURI: String?)
            case item(elements: [DataElement])
            case personName(number: Int, alphabetic: PersonNameComponents?, ideographic: PersonNameComponents?, phonetic: PersonNameComponents?, currentGroup: PersonNameGroup?, components: PersonNameComponents)
            case value(number: Int, text: String)
            case inlineBinary(data: Data?)
            
            enum PersonNameGroup {
                case alphabetic
                case ideographic
                case phonetic
            }
        }
        
        struct PersonNameComponents {
            var familyName: String?
            var givenName: String?
            var middleName: String?
            var namePrefix: String?
            var nameSuffix: String?
            
            func toString() -> String {
                let parts = [familyName, givenName, middleName, namePrefix, nameSuffix]
                    .map { $0 ?? "" }
                return parts.joined(separator: "^")
            }
        }
        
        struct PersonNameBuilder {
            var alphabetic: PersonNameComponents?
            var ideographic: PersonNameComponents?
            var phonetic: PersonNameComponents?
            
            func toString() -> String {
                let alpha = alphabetic?.toString() ?? ""
                let ideo = ideographic?.toString() ?? ""
                let phone = phonetic?.toString() ?? ""
                
                if !ideo.isEmpty || !phone.isEmpty {
                    return "\(alpha)=\(ideo)=\(phone)"
                } else {
                    return alpha
                }
            }
        }
        
        init(configuration: Configuration) {
            self.configuration = configuration
        }
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            switch elementName {
            case "DicomAttribute":
                guard let tagString = attributeDict["tag"],
                      let tag = parseTag(tagString) else {
                    return
                }
                
                let vr: VR?
                if let vrString = attributeDict["vr"] {
                    vr = VR(rawValue: vrString)
                } else if configuration.allowMissingVR {
                    // Try to infer from dictionary (use first VR)
                    vr = DataElementDictionary.lookup(tag: tag)?.vr.first
                } else {
                    vr = nil
                }
                
                elementStack.append(.attribute(tag: tag, vr: vr, values: [], personNames: [], items: [], binaryData: nil, bulkDataURI: nil))
                
            case "Item":
                elementStack.append(.item(elements: []))
                
            case "PersonName":
                if let numberString = attributeDict["number"],
                   let number = Int(numberString) {
                    elementStack.append(.personName(number: number, alphabetic: nil, ideographic: nil, phonetic: nil, currentGroup: nil, components: PersonNameComponents()))
                }
                
            case "Alphabetic":
                if case .personName(let num, let alph, let ideo, let phone, _, let comp) = elementStack.last {
                    elementStack[elementStack.count - 1] = .personName(number: num, alphabetic: alph, ideographic: ideo, phonetic: phone, currentGroup: .alphabetic, components: comp)
                }
                
            case "Ideographic":
                if case .personName(let num, let alph, let ideo, let phone, _, let comp) = elementStack.last {
                    elementStack[elementStack.count - 1] = .personName(number: num, alphabetic: alph, ideographic: ideo, phonetic: phone, currentGroup: .ideographic, components: comp)
                }
                
            case "Phonetic":
                if case .personName(let num, let alph, let ideo, let phone, _, let comp) = elementStack.last {
                    elementStack[elementStack.count - 1] = .personName(number: num, alphabetic: alph, ideographic: ideo, phonetic: phone, currentGroup: .phonetic, components: comp)
                }
                
            case "FamilyName", "GivenName", "MiddleName", "NamePrefix", "NameSuffix", "Value":
                currentText = ""
                
            case "InlineBinary":
                currentText = ""
                
            case "BulkData":
                if let uri = attributeDict["uri"],
                   case .attribute(let tag, let vr, let vals, let pn, let items, _, _) = elementStack.last {
                    elementStack[elementStack.count - 1] = .attribute(tag: tag, vr: vr, values: vals, personNames: pn, items: items, binaryData: nil, bulkDataURI: uri)
                }
                
            default:
                break
            }
        }
        
        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currentText += string
        }
        
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            switch elementName {
            case "Value":
                if case .attribute(let tag, let vr, var vals, let pn, let items, let bin, let uri) = elementStack.last {
                    vals.append(trimmed)
                    elementStack[elementStack.count - 1] = .attribute(tag: tag, vr: vr, values: vals, personNames: pn, items: items, binaryData: bin, bulkDataURI: uri)
                }
                
            case "InlineBinary":
                if let data = Data(base64Encoded: trimmed),
                   case .attribute(let tag, let vr, let vals, let pn, let items, _, let uri) = elementStack.last {
                    elementStack[elementStack.count - 1] = .attribute(tag: tag, vr: vr, values: vals, personNames: pn, items: items, binaryData: data, bulkDataURI: uri)
                }
                
            case "FamilyName":
                if case .personName(let num, let alph, let ideo, let phone, let group, var comp) = elementStack.last {
                    comp.familyName = trimmed
                    elementStack[elementStack.count - 1] = .personName(number: num, alphabetic: alph, ideographic: ideo, phonetic: phone, currentGroup: group, components: comp)
                }
                
            case "GivenName":
                if case .personName(let num, let alph, let ideo, let phone, let group, var comp) = elementStack.last {
                    comp.givenName = trimmed
                    elementStack[elementStack.count - 1] = .personName(number: num, alphabetic: alph, ideographic: ideo, phonetic: phone, currentGroup: group, components: comp)
                }
                
            case "MiddleName":
                if case .personName(let num, let alph, let ideo, let phone, let group, var comp) = elementStack.last {
                    comp.middleName = trimmed
                    elementStack[elementStack.count - 1] = .personName(number: num, alphabetic: alph, ideographic: ideo, phonetic: phone, currentGroup: group, components: comp)
                }
                
            case "NamePrefix":
                if case .personName(let num, let alph, let ideo, let phone, let group, var comp) = elementStack.last {
                    comp.namePrefix = trimmed
                    elementStack[elementStack.count - 1] = .personName(number: num, alphabetic: alph, ideographic: ideo, phonetic: phone, currentGroup: group, components: comp)
                }
                
            case "NameSuffix":
                if case .personName(let num, let alph, let ideo, let phone, let group, var comp) = elementStack.last {
                    comp.nameSuffix = trimmed
                    elementStack[elementStack.count - 1] = .personName(number: num, alphabetic: alph, ideographic: ideo, phonetic: phone, currentGroup: group, components: comp)
                }
                
            case "Alphabetic", "Ideographic", "Phonetic":
                if case .personName(let num, var alph, var ideo, var phone, let group, let comp) = elementStack.last {
                    switch group {
                    case .alphabetic:
                        alph = comp
                    case .ideographic:
                        ideo = comp
                    case .phonetic:
                        phone = comp
                    case .none:
                        break
                    }
                    elementStack[elementStack.count - 1] = .personName(number: num, alphabetic: alph, ideographic: ideo, phonetic: phone, currentGroup: nil, components: PersonNameComponents())
                }
                
            case "PersonName":
                guard case .personName(_, let alph, let ideo, let phone, _, _) = elementStack.popLast() else {
                    return
                }
                
                if case .attribute(let tag, let vr, let vals, var pn, let items, let bin, let uri) = elementStack.last {
                    let builder = PersonNameBuilder(alphabetic: alph, ideographic: ideo, phonetic: phone)
                    pn.append(builder)
                    elementStack[elementStack.count - 1] = .attribute(tag: tag, vr: vr, values: vals, personNames: pn, items: items, binaryData: bin, bulkDataURI: uri)
                }
                
            case "Item":
                guard case .item(let itemElements) = elementStack.popLast() else {
                    return
                }
                
                if case .attribute(let tag, let vr, let vals, let pn, var items, let bin, let uri) = elementStack.last {
                    items.append(SequenceItem(elements: itemElements))
                    elementStack[elementStack.count - 1] = .attribute(tag: tag, vr: vr, values: vals, personNames: pn, items: items, binaryData: bin, bulkDataURI: uri)
                }
                
            case "DicomAttribute":
                guard case .attribute(let tag, let vr, let vals, let personNames, let items, let binaryData, let bulkDataURI) = elementStack.popLast() else {
                    return
                }
                
                guard let vrValue = vr else {
                    // Skip elements without VR
                    return
                }
                
                let element: DataElement
                
                // Handle sequences
                if vrValue == .SQ {
                    let element = DataElement(
                        tag: tag,
                        vr: .SQ,
                        length: 0xFFFFFFFF, // Undefined length for sequences
                        valueData: Data(),
                        sequenceItems: items
                    )
                    
                    // Add to parent structure
                    if case .item(var itemElements) = elementStack.last {
                        itemElements.append(element)
                        elementStack[elementStack.count - 1] = .item(elements: itemElements)
                    } else {
                        elements.append(element)
                    }
                    return
                }
                // Handle binary data
                else if let data = binaryData {
                    element = DataElement(tag: tag, vr: vrValue, length: UInt32(data.count), valueData: data)
                }
                // Handle bulk data URI (placeholder)
                else if bulkDataURI != nil {
                    // For now, create empty element (real implementation would fetch data)
                    element = DataElement(tag: tag, vr: vrValue, length: 0, valueData: Data())
                }
                // Handle person names
                else if vrValue == .PN && !personNames.isEmpty {
                    let pnStrings = personNames.map { $0.toString() }
                    let combinedString = pnStrings.joined(separator: "\\")
                    let data = Data(combinedString.utf8)
                    element = DataElement(tag: tag, vr: vrValue, length: UInt32(data.count), valueData: data)
                }
                // Handle regular values
                else if !vals.isEmpty {
                    let combinedString = vals.joined(separator: "\\")
                    let data = Data(combinedString.utf8)
                    element = DataElement(tag: tag, vr: vrValue, length: UInt32(data.count), valueData: data)
                }
                // Empty element
                else {
                    element = DataElement(tag: tag, vr: vrValue, length: 0, valueData: Data())
                }
                
                // Add to parent structure
                if case .item(var itemElements) = elementStack.last {
                    itemElements.append(element)
                    elementStack[elementStack.count - 1] = .item(elements: itemElements)
                } else {
                    elements.append(element)
                }
                
            default:
                break
            }
            
            currentText = ""
        }
        
        private func parseTag(_ tagString: String) -> Tag? {
            guard tagString.count == 8 else {
                return nil
            }
            
            let groupStr = String(tagString.prefix(4))
            let elemStr = String(tagString.suffix(4))
            
            guard let group = UInt16(groupStr, radix: 16),
                  let element = UInt16(elemStr, radix: 16) else {
                return nil
            }
            
            return Tag(group: group, element: element)
        }
    }
}
