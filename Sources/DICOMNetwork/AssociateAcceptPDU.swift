import Foundation

/// A-ASSOCIATE-AC PDU (Association Accept)
///
/// Used by the acceptor (SCP) to indicate acceptance of an association request.
///
/// Reference: PS3.8 Section 9.3.3
public struct AssociateAcceptPDU: PDU, Sendable, Hashable {
    public let pduType: PDUType = .associateAccept
    
    /// Protocol version (always 1)
    public let protocolVersion: UInt16
    
    /// Called AE Title (the receiving application entity)
    public let calledAETitle: AETitle
    
    /// Calling AE Title (the initiating application entity)
    public let callingAETitle: AETitle
    
    /// Application Context Name
    public let applicationContextName: String
    
    /// Accepted presentation contexts with negotiation results
    public let presentationContexts: [AcceptedPresentationContext]
    
    /// Maximum PDU size that the acceptor can receive
    public let maxPDUSize: UInt32
    
    /// Implementation Class UID of the acceptor
    public let implementationClassUID: String
    
    /// Implementation Version Name of the acceptor (optional)
    public let implementationVersionName: String?
    
    /// Creates an A-ASSOCIATE-AC PDU
    public init(
        protocolVersion: UInt16 = 1,
        calledAETitle: AETitle,
        callingAETitle: AETitle,
        applicationContextName: String = AssociateRequestPDU.dicomApplicationContextName,
        presentationContexts: [AcceptedPresentationContext],
        maxPDUSize: UInt32,
        implementationClassUID: String,
        implementationVersionName: String? = nil
    ) {
        self.protocolVersion = protocolVersion
        self.calledAETitle = calledAETitle
        self.callingAETitle = callingAETitle
        self.applicationContextName = applicationContextName
        self.presentationContexts = presentationContexts
        self.maxPDUSize = maxPDUSize
        self.implementationClassUID = implementationClassUID
        self.implementationVersionName = implementationVersionName
    }
    
    /// Encodes the PDU for network transmission
    ///
    /// Reference: PS3.8 Section 9.3.3
    public func encode() throws -> Data {
        var data = Data()
        
        // Build the PDU variable field first
        var variableField = Data()
        
        // Protocol Version (2 bytes)
        variableField.append(contentsOf: withUnsafeBytes(of: protocolVersion.bigEndian) { Array($0) })
        
        // Reserved (2 bytes)
        variableField.append(contentsOf: [0x00, 0x00])
        
        // Called AE Title (16 bytes)
        variableField.append(calledAETitle.data)
        
        // Calling AE Title (16 bytes)
        variableField.append(callingAETitle.data)
        
        // Reserved (32 bytes)
        variableField.append(contentsOf: [UInt8](repeating: 0x00, count: 32))
        
        // Application Context Item
        variableField.append(encodeApplicationContextItem())
        
        // Presentation Context Items
        for context in presentationContexts {
            variableField.append(encodePresentationContextItem(context))
        }
        
        // User Information Item
        variableField.append(encodeUserInformationItem())
        
        // PDU Type (1 byte)
        data.append(pduType.rawValue)
        
        // Reserved (1 byte)
        data.append(0x00)
        
        // PDU Length (4 bytes, big endian)
        let pduLength = UInt32(variableField.count)
        data.append(contentsOf: withUnsafeBytes(of: pduLength.bigEndian) { Array($0) })
        
        // Variable field
        data.append(variableField)
        
        return data
    }
    
    // MARK: - Private Encoding Methods
    
    private func encodeApplicationContextItem() -> Data {
        var item = Data()
        item.append(0x10)  // Item Type
        item.append(0x00)  // Reserved
        
        let nameData = Data(applicationContextName.utf8)
        let itemLength = UInt16(nameData.count)
        item.append(contentsOf: withUnsafeBytes(of: itemLength.bigEndian) { Array($0) })
        item.append(nameData)
        
        return item
    }
    
    private func encodePresentationContextItem(_ context: AcceptedPresentationContext) -> Data {
        var item = Data()
        
        // Build content first
        var content = Data()
        content.append(context.id)  // Presentation Context ID
        content.append(0x00)  // Reserved
        content.append(context.result.rawValue)  // Result/Reason
        content.append(0x00)  // Reserved
        
        // Transfer Syntax Sub-Item (only if accepted)
        if let transferSyntax = context.transferSyntax {
            var subItem = Data()
            subItem.append(0x40)  // Sub-Item Type
            subItem.append(0x00)  // Reserved
            
            let tsData = Data(transferSyntax.utf8)
            let tsLength = UInt16(tsData.count)
            subItem.append(contentsOf: withUnsafeBytes(of: tsLength.bigEndian) { Array($0) })
            subItem.append(tsData)
            
            content.append(subItem)
        }
        
        // Item Type (0x21 for Presentation Context AC)
        item.append(0x21)
        item.append(0x00)  // Reserved
        
        let itemLength = UInt16(content.count)
        item.append(contentsOf: withUnsafeBytes(of: itemLength.bigEndian) { Array($0) })
        item.append(content)
        
        return item
    }
    
    private func encodeUserInformationItem() -> Data {
        var item = Data()
        
        // Build sub-items
        var subItems = Data()
        
        // Maximum Length Sub-Item
        var maxLengthSubItem = Data()
        maxLengthSubItem.append(0x51)
        maxLengthSubItem.append(0x00)
        let length = UInt16(4)
        maxLengthSubItem.append(contentsOf: withUnsafeBytes(of: length.bigEndian) { Array($0) })
        maxLengthSubItem.append(contentsOf: withUnsafeBytes(of: maxPDUSize.bigEndian) { Array($0) })
        subItems.append(maxLengthSubItem)
        
        // Implementation Class UID Sub-Item
        var implClassSubItem = Data()
        implClassSubItem.append(0x52)
        implClassSubItem.append(0x00)
        let uidData = Data(implementationClassUID.utf8)
        let uidLength = UInt16(uidData.count)
        implClassSubItem.append(contentsOf: withUnsafeBytes(of: uidLength.bigEndian) { Array($0) })
        implClassSubItem.append(uidData)
        subItems.append(implClassSubItem)
        
        // Implementation Version Name Sub-Item (optional)
        if let versionName = implementationVersionName {
            var versionSubItem = Data()
            versionSubItem.append(0x55)
            versionSubItem.append(0x00)
            let versionData = Data(versionName.utf8)
            let versionLength = UInt16(versionData.count)
            versionSubItem.append(contentsOf: withUnsafeBytes(of: versionLength.bigEndian) { Array($0) })
            versionSubItem.append(versionData)
            subItems.append(versionSubItem)
        }
        
        // User Information Item
        item.append(0x50)  // Item Type
        item.append(0x00)  // Reserved
        let itemLength = UInt16(subItems.count)
        item.append(contentsOf: withUnsafeBytes(of: itemLength.bigEndian) { Array($0) })
        item.append(subItems)
        
        return item
    }
    
    /// Gets the accepted transfer syntax for a given presentation context ID
    public func acceptedTransferSyntax(forContextID id: UInt8) -> String? {
        presentationContexts.first(where: { $0.id == id && $0.isAccepted })?.transferSyntax
    }
    
    /// Gets all accepted presentation context IDs
    public var acceptedContextIDs: [UInt8] {
        presentationContexts.filter { $0.isAccepted }.map { $0.id }
    }
}

// MARK: - CustomStringConvertible
extension AssociateAcceptPDU: CustomStringConvertible {
    public var description: String {
        let acceptedCount = presentationContexts.filter { $0.isAccepted }.count
        return """
        A-ASSOCIATE-AC:
          Called AE Title: \(calledAETitle)
          Calling AE Title: \(callingAETitle)
          Application Context: \(applicationContextName)
          Presentation Contexts: \(presentationContexts.count) (\(acceptedCount) accepted)
          Max PDU Size: \(maxPDUSize)
          Implementation Class UID: \(implementationClassUID)
          Implementation Version Name: \(implementationVersionName ?? "(none)")
        """
    }
}
