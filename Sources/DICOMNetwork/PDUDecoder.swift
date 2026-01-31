import Foundation

/// PDU Decoder for parsing DICOM network PDUs from binary data
///
/// Reference: PS3.8 Section 9 - Protocol Data Units
public enum PDUDecoder {
    
    // MARK: - Helper Methods for Reading Big Endian Values
    
    private static func readUInt16BigEndian(from data: Data, at offset: Data.Index) -> UInt16 {
        return (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
    }
    
    private static func readUInt32BigEndian(from data: Data, at offset: Data.Index) -> UInt32 {
        return (UInt32(data[offset]) << 24) |
               (UInt32(data[offset + 1]) << 16) |
               (UInt32(data[offset + 2]) << 8) |
               UInt32(data[offset + 3])
    }
    
    /// Decodes a PDU from binary data
    ///
    /// - Parameter data: The raw PDU data
    /// - Returns: The decoded PDU
    /// - Throws: `DICOMNetworkError` if decoding fails
    public static func decode(from data: Data) throws -> any PDU {
        guard data.count >= 6 else {
            throw DICOMNetworkError.decodingFailed("PDU too short: need at least 6 bytes, got \(data.count)")
        }
        
        // Read PDU Type (1 byte)
        let pduTypeByte = data[data.startIndex]
        guard let pduType = PDUType(rawValue: pduTypeByte) else {
            throw DICOMNetworkError.decodingFailed("Unknown PDU type: 0x\(String(format: "%02X", pduTypeByte))")
        }
        
        // Skip reserved byte (1 byte)
        // Read PDU Length (4 bytes, big endian)
        let pduLength = readUInt32BigEndian(from: data, at: data.startIndex + 2)
        
        let expectedTotalLength = 6 + Int(pduLength)
        guard data.count >= expectedTotalLength else {
            throw DICOMNetworkError.decodingFailed("PDU data too short: expected \(expectedTotalLength) bytes, got \(data.count)")
        }
        
        let variableField = Data(data[data.startIndex + 6 ..< data.startIndex + expectedTotalLength])
        
        switch pduType {
        case .associateRequest:
            return try decodeAssociateRequest(from: variableField)
        case .associateAccept:
            return try decodeAssociateAccept(from: variableField)
        case .associateReject:
            return try decodeAssociateReject(from: variableField)
        case .dataTransfer:
            return try decodeDataTransfer(from: variableField)
        case .releaseRequest:
            return ReleaseRequestPDU()
        case .releaseResponse:
            return ReleaseResponsePDU()
        case .abort:
            return try decodeAbort(from: variableField)
        }
    }
    
    /// Reads the PDU header to determine type and length without full parsing
    ///
    /// - Parameter data: At least 6 bytes of PDU header data
    /// - Returns: Tuple of (PDU type, PDU length)
    /// - Throws: `DICOMNetworkError` if header is invalid
    public static func readHeader(from data: Data) throws -> (type: PDUType, length: UInt32) {
        guard data.count >= 6 else {
            throw DICOMNetworkError.decodingFailed("PDU header too short: need 6 bytes, got \(data.count)")
        }
        
        let pduTypeByte = data[data.startIndex]
        guard let pduType = PDUType(rawValue: pduTypeByte) else {
            throw DICOMNetworkError.decodingFailed("Unknown PDU type: 0x\(String(format: "%02X", pduTypeByte))")
        }
        
        let pduLength = readUInt32BigEndian(from: data, at: data.startIndex + 2)
        
        return (pduType, pduLength)
    }
    
    // MARK: - Private Decoding Methods
    
    private static func decodeAssociateRequest(from data: Data) throws -> AssociateRequestPDU {
        var offset = data.startIndex
        
        guard data.count >= 68 else {
            throw DICOMNetworkError.decodingFailed("A-ASSOCIATE-RQ too short")
        }
        
        // Protocol Version (2 bytes)
        offset += 2
        
        // Reserved (2 bytes)
        offset += 2
        
        // Called AE Title (16 bytes)
        let calledAEData = Data(data[offset ..< offset + 16])
        guard let calledAETitle = AETitle.from(data: calledAEData) else {
            throw DICOMNetworkError.decodingFailed("Invalid Called AE Title")
        }
        offset += 16
        
        // Calling AE Title (16 bytes)
        let callingAEData = Data(data[offset ..< offset + 16])
        guard let callingAETitle = AETitle.from(data: callingAEData) else {
            throw DICOMNetworkError.decodingFailed("Invalid Calling AE Title")
        }
        offset += 16
        
        // Reserved (32 bytes)
        offset += 32
        
        // Parse variable items
        var applicationContextName = AssociateRequestPDU.dicomApplicationContextName
        var presentationContexts: [PresentationContext] = []
        var maxPDUSize: UInt32 = defaultMaxPDUSize
        var implementationClassUID = ""
        var implementationVersionName: String?
        
        while offset < data.endIndex {
            guard offset + 4 <= data.endIndex else { break }
            
            let itemType = data[offset]
            offset += 1
            offset += 1 // Reserved
            
            let itemLength = readUInt16BigEndian(from: data, at: offset)
            offset += 2
            
            guard offset + Int(itemLength) <= data.endIndex else { break }
            let itemData = Data(data[offset ..< offset + Int(itemLength)])
            offset += Int(itemLength)
            
            switch itemType {
            case 0x10: // Application Context
                applicationContextName = String(data: itemData, encoding: .ascii) ?? applicationContextName
                
            case 0x20: // Presentation Context (RQ)
                if let context = try? decodePresentationContextRQ(from: itemData) {
                    presentationContexts.append(context)
                }
                
            case 0x50: // User Information
                let userInfo = try decodeUserInformation(from: itemData)
                maxPDUSize = userInfo.maxPDUSize ?? maxPDUSize
                implementationClassUID = userInfo.implementationClassUID ?? implementationClassUID
                implementationVersionName = userInfo.implementationVersionName
                
            default:
                break // Unknown item type, skip
            }
        }
        
        return AssociateRequestPDU(
            calledAETitle: calledAETitle,
            callingAETitle: callingAETitle,
            presentationContexts: presentationContexts,
            maxPDUSize: maxPDUSize,
            implementationClassUID: implementationClassUID,
            implementationVersionName: implementationVersionName,
            applicationContextName: applicationContextName
        )
    }
    
    private static func decodePresentationContextRQ(from data: Data) throws -> PresentationContext {
        guard data.count >= 4 else {
            throw DICOMNetworkError.decodingFailed("Presentation Context item too short")
        }
        
        var offset = data.startIndex
        
        let contextID = data[offset]
        offset += 4 // ID + 3 reserved bytes
        
        var abstractSyntax = ""
        var transferSyntaxes: [String] = []
        
        while offset < data.endIndex {
            guard offset + 4 <= data.endIndex else { break }
            
            let subItemType = data[offset]
            offset += 2 // Type + Reserved
            
            let subItemLength = readUInt16BigEndian(from: data, at: offset)
            offset += 2
            
            guard offset + Int(subItemLength) <= data.endIndex else { break }
            let subItemData = Data(data[offset ..< offset + Int(subItemLength)])
            offset += Int(subItemLength)
            
            if subItemType == 0x30 { // Abstract Syntax
                abstractSyntax = String(data: subItemData, encoding: .ascii) ?? ""
            } else if subItemType == 0x40 { // Transfer Syntax
                if let ts = String(data: subItemData, encoding: .ascii) {
                    transferSyntaxes.append(ts)
                }
            }
        }
        
        return try PresentationContext(id: contextID, abstractSyntax: abstractSyntax, transferSyntaxes: transferSyntaxes)
    }
    
    private static func decodeUserInformation(from data: Data) throws -> (maxPDUSize: UInt32?, implementationClassUID: String?, implementationVersionName: String?) {
        var offset = data.startIndex
        var maxPDUSize: UInt32?
        var implementationClassUID: String?
        var implementationVersionName: String?
        
        while offset < data.endIndex {
            guard offset + 4 <= data.endIndex else { break }
            
            let subItemType = data[offset]
            offset += 2 // Type + Reserved
            
            let subItemLength = readUInt16BigEndian(from: data, at: offset)
            offset += 2
            
            guard offset + Int(subItemLength) <= data.endIndex else { break }
            let subItemData = Data(data[offset ..< offset + Int(subItemLength)])
            offset += Int(subItemLength)
            
            switch subItemType {
            case 0x51: // Maximum Length
                if subItemLength >= 4 {
                    maxPDUSize = readUInt32BigEndian(from: subItemData, at: subItemData.startIndex)
                }
            case 0x52: // Implementation Class UID
                implementationClassUID = String(data: subItemData, encoding: .ascii)
            case 0x55: // Implementation Version Name
                implementationVersionName = String(data: subItemData, encoding: .ascii)
            default:
                break
            }
        }
        
        return (maxPDUSize, implementationClassUID, implementationVersionName)
    }
    
    private static func decodeAssociateAccept(from data: Data) throws -> AssociateAcceptPDU {
        var offset = data.startIndex
        
        guard data.count >= 68 else {
            throw DICOMNetworkError.decodingFailed("A-ASSOCIATE-AC too short")
        }
        
        // Protocol Version (2 bytes)
        let protocolVersion = readUInt16BigEndian(from: data, at: offset)
        offset += 2
        
        // Reserved (2 bytes)
        offset += 2
        
        // Called AE Title (16 bytes)
        let calledAEData = Data(data[offset ..< offset + 16])
        guard let calledAETitle = AETitle.from(data: calledAEData) else {
            throw DICOMNetworkError.decodingFailed("Invalid Called AE Title")
        }
        offset += 16
        
        // Calling AE Title (16 bytes)
        let callingAEData = Data(data[offset ..< offset + 16])
        guard let callingAETitle = AETitle.from(data: callingAEData) else {
            throw DICOMNetworkError.decodingFailed("Invalid Calling AE Title")
        }
        offset += 16
        
        // Reserved (32 bytes)
        offset += 32
        
        // Parse variable items
        var applicationContextName = AssociateRequestPDU.dicomApplicationContextName
        var presentationContexts: [AcceptedPresentationContext] = []
        var maxPDUSize: UInt32 = defaultMaxPDUSize
        var implementationClassUID = ""
        var implementationVersionName: String?
        
        while offset < data.endIndex {
            guard offset + 4 <= data.endIndex else { break }
            
            let itemType = data[offset]
            offset += 2 // Type + Reserved
            
            let itemLength = readUInt16BigEndian(from: data, at: offset)
            offset += 2
            
            guard offset + Int(itemLength) <= data.endIndex else { break }
            let itemData = Data(data[offset ..< offset + Int(itemLength)])
            offset += Int(itemLength)
            
            switch itemType {
            case 0x10: // Application Context
                applicationContextName = String(data: itemData, encoding: .ascii) ?? applicationContextName
                
            case 0x21: // Presentation Context (AC)
                if let context = decodePresentationContextAC(from: itemData) {
                    presentationContexts.append(context)
                }
                
            case 0x50: // User Information
                let userInfo = try decodeUserInformation(from: itemData)
                maxPDUSize = userInfo.maxPDUSize ?? maxPDUSize
                implementationClassUID = userInfo.implementationClassUID ?? implementationClassUID
                implementationVersionName = userInfo.implementationVersionName
                
            default:
                break
            }
        }
        
        return AssociateAcceptPDU(
            protocolVersion: protocolVersion,
            calledAETitle: calledAETitle,
            callingAETitle: callingAETitle,
            applicationContextName: applicationContextName,
            presentationContexts: presentationContexts,
            maxPDUSize: maxPDUSize,
            implementationClassUID: implementationClassUID,
            implementationVersionName: implementationVersionName
        )
    }
    
    private static func decodePresentationContextAC(from data: Data) -> AcceptedPresentationContext? {
        guard data.count >= 4 else { return nil }
        
        var offset = data.startIndex
        
        let contextID = data[offset]
        offset += 1
        offset += 1 // Reserved
        
        let resultByte = data[offset]
        let result = PresentationContextResult(rawValue: resultByte) ?? .noReasonProviderRejection
        offset += 2 // Result + Reserved
        
        var transferSyntax: String?
        
        while offset < data.endIndex {
            guard offset + 4 <= data.endIndex else { break }
            
            let subItemType = data[offset]
            offset += 2
            
            let subItemLength = readUInt16BigEndian(from: data, at: offset)
            offset += 2
            
            guard offset + Int(subItemLength) <= data.endIndex else { break }
            let subItemData = Data(data[offset ..< offset + Int(subItemLength)])
            offset += Int(subItemLength)
            
            if subItemType == 0x40 { // Transfer Syntax
                transferSyntax = String(data: subItemData, encoding: .ascii)
            }
        }
        
        return AcceptedPresentationContext(id: contextID, result: result, transferSyntax: transferSyntax)
    }
    
    private static func decodeAssociateReject(from data: Data) throws -> AssociateRejectPDU {
        guard data.count >= 4 else {
            throw DICOMNetworkError.decodingFailed("A-ASSOCIATE-RJ too short")
        }
        
        // Reserved (1 byte)
        // Result (1 byte)
        let resultByte = data[data.startIndex + 1]
        guard let result = AssociateRejectResult(rawValue: resultByte) else {
            throw DICOMNetworkError.decodingFailed("Invalid reject result: \(resultByte)")
        }
        
        // Source (1 byte)
        let sourceByte = data[data.startIndex + 2]
        guard let source = AssociateRejectSource(rawValue: sourceByte) else {
            throw DICOMNetworkError.decodingFailed("Invalid reject source: \(sourceByte)")
        }
        
        // Reason (1 byte)
        let reason = data[data.startIndex + 3]
        
        return AssociateRejectPDU(result: result, source: source, reason: reason)
    }
    
    private static func decodeDataTransfer(from data: Data) throws -> DataTransferPDU {
        var offset = data.startIndex
        var pdvs: [PresentationDataValue] = []
        
        while offset < data.endIndex {
            guard offset + 4 <= data.endIndex else { break }
            
            // PDV Item Length (4 bytes, big endian)
            let itemLength = readUInt32BigEndian(from: data, at: offset)
            offset += 4
            
            guard offset + Int(itemLength) <= data.endIndex else {
                throw DICOMNetworkError.decodingFailed("PDV item extends beyond PDU")
            }
            
            guard itemLength >= 2 else {
                throw DICOMNetworkError.decodingFailed("PDV item too short")
            }
            
            // Presentation Context ID (1 byte)
            let contextID = data[offset]
            offset += 1
            
            // Message Control Header (1 byte)
            let controlHeader = data[offset]
            offset += 1
            
            let isCommand = (controlHeader & 0x01) != 0
            let isLastFragment = (controlHeader & 0x02) != 0
            
            // Data payload
            let dataLength = Int(itemLength) - 2
            let pdvData = Data(data[offset ..< offset + dataLength])
            offset += dataLength
            
            let pdv = PresentationDataValue(
                presentationContextID: contextID,
                isCommand: isCommand,
                isLastFragment: isLastFragment,
                data: pdvData
            )
            pdvs.append(pdv)
        }
        
        return DataTransferPDU(presentationDataValues: pdvs)
    }
    
    private static func decodeAbort(from data: Data) throws -> AbortPDU {
        guard data.count >= 4 else {
            throw DICOMNetworkError.decodingFailed("A-ABORT too short")
        }
        
        // Reserved (2 bytes)
        // Source (1 byte)
        let sourceByte = data[data.startIndex + 2]
        let source = AbortSource(rawValue: sourceByte) ?? .serviceProvider
        
        // Reason (1 byte)
        let reason = data[data.startIndex + 3]
        
        return AbortPDU(source: source, reason: reason)
    }
}
