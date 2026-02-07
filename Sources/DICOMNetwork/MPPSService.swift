import Foundation
import DICOMCore

/// SOP Class UID for Modality Performed Procedure Step
/// Reference: PS3.4 Annex F - Modality Performed Procedure Step SOP Class
public let modalityPerformedProcedureStepSOPClassUID = "1.2.840.10008.3.1.2.3.3"

/// MPPS Status
public enum MPPSStatus: String, Sendable {
    case inProgress = "IN PROGRESS"
    case completed = "COMPLETED"
    case discontinued = "DISCONTINUED"
}

/// Configuration for the MPPS Service
public struct MPPSConfiguration: Sendable, Hashable {
    /// The local Application Entity title (calling AE)
    public let callingAETitle: AETitle
    
    /// The remote Application Entity title (called AE)
    public let calledAETitle: AETitle
    
    /// Connection timeout in seconds
    public let timeout: TimeInterval
    
    /// Maximum PDU size to propose
    public let maxPDUSize: UInt32
    
    /// Implementation Class UID for this DICOM implementation
    public let implementationClassUID: String
    
    /// Implementation Version Name (optional)
    public let implementationVersionName: String?
    
    /// User identity for authentication (optional)
    public let userIdentity: UserIdentity?
    
    /// Default Implementation Class UID for DICOMKit
    public static let defaultImplementationClassUID = "1.2.826.0.1.3680043.9.7433.1.1"
    
    /// Default Implementation Version Name for DICOMKit
    public static let defaultImplementationVersionName = "DICOMKIT_001"
    
    /// Creates an MPPS configuration
    ///
    /// - Parameters:
    ///   - callingAETitle: The local AE title
    ///   - calledAETitle: The remote AE title
    ///   - timeout: Connection timeout in seconds (default: 60)
    ///   - maxPDUSize: Maximum PDU size (default: 16KB)
    ///   - implementationClassUID: Implementation Class UID
    ///   - implementationVersionName: Implementation Version Name
    ///   - userIdentity: User identity for authentication (optional)
    public init(
        callingAETitle: AETitle,
        calledAETitle: AETitle,
        timeout: TimeInterval = 60,
        maxPDUSize: UInt32 = defaultMaxPDUSize,
        implementationClassUID: String = defaultImplementationClassUID,
        implementationVersionName: String? = defaultImplementationVersionName,
        userIdentity: UserIdentity? = nil
    ) {
        self.callingAETitle = callingAETitle
        self.calledAETitle = calledAETitle
        self.timeout = timeout
        self.maxPDUSize = maxPDUSize
        self.implementationClassUID = implementationClassUID
        self.implementationVersionName = implementationVersionName
        self.userIdentity = userIdentity
    }
}

/// MPPS procedure step data
public struct MPPSProcedureStep: Sendable {
    /// SOP Instance UID for the MPPS instance
    public let sopInstanceUID: String
    
    /// Performed Procedure Step Status
    public let status: MPPSStatus
    
    /// Study Instance UID
    public let studyInstanceUID: String?
    
    /// Performed Procedure Step Start Date/Time
    public let startDateTime: Date?
    
    /// Performed Procedure Step End Date/Time (for completed/discontinued)
    public let endDateTime: Date?
    
    /// Referenced Image SOPs (for completed procedures)
    public let referencedSOPs: [(studyUID: String, seriesUID: String, sopInstanceUID: String)]
    
    /// Additional attributes
    public let attributes: [Tag: Data]
    
    public init(
        sopInstanceUID: String,
        status: MPPSStatus,
        studyInstanceUID: String? = nil,
        startDateTime: Date? = nil,
        endDateTime: Date? = nil,
        referencedSOPs: [(studyUID: String, seriesUID: String, sopInstanceUID: String)] = [],
        attributes: [Tag: Data] = [:]
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.status = status
        self.studyInstanceUID = studyInstanceUID
        self.startDateTime = startDateTime
        self.endDateTime = endDateTime
        self.referencedSOPs = referencedSOPs
        self.attributes = attributes
    }
}

#if canImport(Network)

// MARK: - DICOM MPPS Service

/// DICOM Modality Performed Procedure Step Service
///
/// Implements the DICOM MPPS Service for creating and updating performed procedure steps.
///
/// Reference: PS3.4 Annex F - Modality Performed Procedure Step SOP Class
///
/// ## Usage
///
/// ```swift
/// // Create MPPS (procedure started)
/// let mppsUID = try await DICOMMPPSService.create(
///     host: "pacs.hospital.com",
///     port: 11112,
///     callingAE: "MODALITY",
///     calledAE: "PACS",
///     studyInstanceUID: "1.2.3.4.5",
///     status: .inProgress
/// )
///
/// // Update MPPS (procedure completed)
/// try await DICOMMPPSService.update(
///     host: "pacs.hospital.com",
///     port: 11112,
///     callingAE: "MODALITY",
///     calledAE: "PACS",
///     mppsInstanceUID: mppsUID,
///     status: .completed,
///     referencedSOPs: [(studyUID, seriesUID, sopInstanceUID)]
/// )
/// ```
public enum DICOMMPPSService {
    
    /// Creates a new MPPS instance (N-CREATE)
    ///
    /// - Parameters:
    ///   - host: The remote host address
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local AE title
    ///   - calledAE: The remote AE title
    ///   - studyInstanceUID: The Study Instance UID for the procedure
    ///   - status: The initial status (typically .inProgress)
    ///   - timeout: Connection timeout in seconds (default: 60)
    /// - Returns: The created MPPS SOP Instance UID
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func create(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        studyInstanceUID: String,
        status: MPPSStatus = .inProgress,
        timeout: TimeInterval = 60
    ) async throws -> String {
        let callingAETitle = try AETitle(callingAE)
        let calledAETitle = try AETitle(calledAE)
        
        let config = MPPSConfiguration(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: timeout
        )
        
        // Generate a new SOP Instance UID for the MPPS
        let mppsInstanceUID = UIDGenerator.generate()
        
        let procedureStep = MPPSProcedureStep(
            sopInstanceUID: mppsInstanceUID,
            status: status,
            studyInstanceUID: studyInstanceUID,
            startDateTime: Date()
        )
        
        try await performNCreate(
            host: host,
            port: port,
            configuration: config,
            procedureStep: procedureStep
        )
        
        return mppsInstanceUID
    }
    
    /// Updates an existing MPPS instance (N-SET)
    ///
    /// - Parameters:
    ///   - host: The remote host address
    ///   - port: The remote port number (default: 104)
    ///   - callingAE: The local AE title
    ///   - calledAE: The remote AE title
    ///   - mppsInstanceUID: The MPPS SOP Instance UID to update
    ///   - status: The new status (.completed or .discontinued)
    ///   - referencedSOPs: Referenced image SOPs (for completed procedures)
    ///   - timeout: Connection timeout in seconds (default: 60)
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func update(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        mppsInstanceUID: String,
        status: MPPSStatus,
        referencedSOPs: [(studyUID: String, seriesUID: String, sopInstanceUID: String)] = [],
        timeout: TimeInterval = 60
    ) async throws {
        let callingAETitle = try AETitle(callingAE)
        let calledAETitle = try AETitle(calledAE)
        
        let config = MPPSConfiguration(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: timeout
        )
        
        let procedureStep = MPPSProcedureStep(
            sopInstanceUID: mppsInstanceUID,
            status: status,
            endDateTime: Date(),
            referencedSOPs: referencedSOPs
        )
        
        try await performNSet(
            host: host,
            port: port,
            configuration: config,
            procedureStep: procedureStep
        )
    }
    
    // MARK: - Private Implementation
    
    /// Performs the N-CREATE operation
    private static func performNCreate(
        host: String,
        port: UInt16,
        configuration: MPPSConfiguration,
        procedureStep: MPPSProcedureStep
    ) async throws {
        
        // Create association configuration
        let associationConfig = AssociationConfiguration(
            callingAETitle: configuration.callingAETitle,
            calledAETitle: configuration.calledAETitle,
            host: host,
            port: port,
            maxPDUSize: configuration.maxPDUSize,
            implementationClassUID: configuration.implementationClassUID,
            implementationVersionName: configuration.implementationVersionName,
            timeout: configuration.timeout,
            userIdentity: configuration.userIdentity
        )
        
        // Create association
        let association = Association(configuration: associationConfig)
        
        // Create presentation context for MPPS
        let presentationContext = try PresentationContext(
            id: 1,
            abstractSyntax: modalityPerformedProcedureStepSOPClassUID,
            transferSyntaxes: [
                explicitVRLittleEndianTransferSyntaxUID,
                implicitVRLittleEndianTransferSyntaxUID
            ]
        )
        
        do {
            // Establish association
            let negotiated = try await association.request(presentationContexts: [presentationContext])
            
            // Verify that the SOP Class was accepted
            guard negotiated.isContextAccepted(1) else {
                try await association.abort()
                throw DICOMNetworkError.sopClassNotSupported(modalityPerformedProcedureStepSOPClassUID)
            }
            
            // Get the accepted transfer syntax
            let acceptedTransferSyntax = negotiated.acceptedTransferSyntax(forContextID: 1) 
                ?? implicitVRLittleEndianTransferSyntaxUID
            
            // Perform the N-CREATE operation
            try await sendNCreate(
                association: association,
                presentationContextID: 1,
                maxPDUSize: negotiated.maxPDUSize,
                procedureStep: procedureStep,
                transferSyntax: acceptedTransferSyntax
            )
            
            // Release association gracefully
            try await association.release()
            
        } catch {
            // Attempt to abort the association on error
            try? await association.abort()
            throw error
        }
    }
    
    /// Performs the N-SET operation
    private static func performNSet(
        host: String,
        port: UInt16,
        configuration: MPPSConfiguration,
        procedureStep: MPPSProcedureStep
    ) async throws {
        
        // Create association configuration
        let associationConfig = AssociationConfiguration(
            callingAETitle: configuration.callingAETitle,
            calledAETitle: configuration.calledAETitle,
            host: host,
            port: port,
            maxPDUSize: configuration.maxPDUSize,
            implementationClassUID: configuration.implementationClassUID,
            implementationVersionName: configuration.implementationVersionName,
            timeout: configuration.timeout,
            userIdentity: configuration.userIdentity
        )
        
        // Create association
        let association = Association(configuration: associationConfig)
        
        // Create presentation context for MPPS
        let presentationContext = try PresentationContext(
            id: 1,
            abstractSyntax: modalityPerformedProcedureStepSOPClassUID,
            transferSyntaxes: [
                explicitVRLittleEndianTransferSyntaxUID,
                implicitVRLittleEndianTransferSyntaxUID
            ]
        )
        
        do {
            // Establish association
            let negotiated = try await association.request(presentationContexts: [presentationContext])
            
            // Verify that the SOP Class was accepted
            guard negotiated.isContextAccepted(1) else {
                try await association.abort()
                throw DICOMNetworkError.sopClassNotSupported(modalityPerformedProcedureStepSOPClassUID)
            }
            
            // Get the accepted transfer syntax
            let acceptedTransferSyntax = negotiated.acceptedTransferSyntax(forContextID: 1) 
                ?? implicitVRLittleEndianTransferSyntaxUID
            
            // Perform the N-SET operation
            try await sendNSet(
                association: association,
                presentationContextID: 1,
                maxPDUSize: negotiated.maxPDUSize,
                procedureStep: procedureStep,
                transferSyntax: acceptedTransferSyntax
            )
            
            // Release association gracefully
            try await association.release()
            
        } catch {
            // Attempt to abort the association on error
            try? await association.abort()
            throw error
        }
    }
    
    /// Sends the N-CREATE request
    private static func sendNCreate(
        association: Association,
        presentationContextID: UInt8,
        maxPDUSize: UInt32,
        procedureStep: MPPSProcedureStep,
        transferSyntax: String
    ) async throws {
        // Build the attribute list
        let attributeData = buildMPPSAttributes(procedureStep: procedureStep, transferSyntax: transferSyntax)
        
        // Create N-CREATE request command set
        var commandData = Data()
        commandData.append(encodeSimpleElement(tag: Tag(group: 0x0000, element: 0x0100), vr: .US, value: Data([0x40, 0x01]))) // N-CREATE-RQ
        commandData.append(encodeSimpleElement(tag: Tag(group: 0x0000, element: 0x0110), vr: .US, value: Data([0x01, 0x00]))) // Message ID
        commandData.append(encodeSimpleElement(tag: Tag(group: 0x0000, element: 0x0002), vr: .UI, value: modalityPerformedProcedureStepSOPClassUID.data(using: .ascii)!)) // Affected SOP Class UID
        commandData.append(encodeSimpleElement(tag: Tag(group: 0x0000, element: 0x1000), vr: .UI, value: procedureStep.sopInstanceUID.data(using: .ascii)!)) // Affected SOP Instance UID
        commandData.append(encodeSimpleElement(tag: Tag(group: 0x0000, element: 0x0800), vr: .US, value: Data([0x00, 0x01]))) // Data Set Type (0x0001 = present)
        
        // Fragment and send the command and data set
        let fragmenter = MessageFragmenter(maxPDUSize: maxPDUSize)
        let pdus = fragmenter.fragmentMessage(
            commandSet: commandData,
            dataSet: attributeData,
            presentationContextID: presentationContextID
        )
        
        // Send all PDUs
        for pdu in pdus {
            for pdv in pdu.presentationDataValues {
                try await association.send(pdv: pdv)
            }
        }
        
        // Receive response
        let assembler = MessageAssembler()
        let responsePDU = try await association.receive()
        
        if let message = try assembler.addPDVs(from: responsePDU) {
            // TODO: Parse N-CREATE-RSP and validate status code
            // Status 0x0000 = success, other codes indicate failure
            // For now, assume success if we received a response
            // Future enhancement: throw DICOMNetworkError if status indicates failure
        }
    }
    
    /// Sends the N-SET request
    private static func sendNSet(
        association: Association,
        presentationContextID: UInt8,
        maxPDUSize: UInt32,
        procedureStep: MPPSProcedureStep,
        transferSyntax: String
    ) async throws {
        // Build the modification list
        let modificationData = buildMPPSAttributes(procedureStep: procedureStep, transferSyntax: transferSyntax)
        
        // Create N-SET request command set
        var commandData = Data()
        commandData.append(encodeSimpleElement(tag: Tag(group: 0x0000, element: 0x0100), vr: .US, value: Data([0x20, 0x01]))) // N-SET-RQ
        commandData.append(encodeSimpleElement(tag: Tag(group: 0x0000, element: 0x0110), vr: .US, value: Data([0x01, 0x00]))) // Message ID
        commandData.append(encodeSimpleElement(tag: Tag(group: 0x0000, element: 0x0003), vr: .UI, value: modalityPerformedProcedureStepSOPClassUID.data(using: .ascii)!)) // Requested SOP Class UID
        commandData.append(encodeSimpleElement(tag: Tag(group: 0x0000, element: 0x1001), vr: .UI, value: procedureStep.sopInstanceUID.data(using: .ascii)!)) // Requested SOP Instance UID
        commandData.append(encodeSimpleElement(tag: Tag(group: 0x0000, element: 0x0800), vr: .US, value: Data([0x00, 0x01]))) // Data Set Type (0x0001 = present)
        
        // Fragment and send the command and data set
        let fragmenter = MessageFragmenter(maxPDUSize: maxPDUSize)
        let pdus = fragmenter.fragmentMessage(
            commandSet: commandData,
            dataSet: modificationData,
            presentationContextID: presentationContextID
        )
        
        // Send all PDUs
        for pdu in pdus {
            for pdv in pdu.presentationDataValues {
                try await association.send(pdv: pdv)
            }
        }
        
        // Receive response
        let assembler = MessageAssembler()
        let responsePDU = try await association.receive()
        
        if let message = try assembler.addPDVs(from: responsePDU) {
            // TODO: Parse N-SET-RSP and validate status code
            // Status 0x0000 = success, other codes indicate failure
            // For now, assume success if we received a response
            // Future enhancement: throw DICOMNetworkError if status indicates failure
        }
    }
    
    /// Builds the MPPS attributes data set
    private static func buildMPPSAttributes(
        procedureStep: MPPSProcedureStep,
        transferSyntax: String
    ) -> Data {
        var data = Data()
        let isExplicitVR = transferSyntax == explicitVRLittleEndianTransferSyntaxUID
        
        // Performed Procedure Step Status
        data.append(encodeElement(
            tag: Tag(group: 0x0040, element: 0x0252),
            vr: .CS,
            value: procedureStep.status.rawValue,
            explicit: isExplicitVR
        ))
        
        // Study Instance UID (if available)
        if let studyUID = procedureStep.studyInstanceUID {
            data.append(encodeElement(
                tag: .studyInstanceUID,
                vr: .UI,
                value: studyUID,
                explicit: isExplicitVR
            ))
        }
        
        // End Date/Time (for completed/discontinued)
        if let endDateTime = procedureStep.endDateTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMddHHmmss"
            let dateTimeString = formatter.string(from: endDateTime)
            
            data.append(encodeElement(
                tag: Tag(group: 0x0040, element: 0x0250),
                vr: .DT,
                value: dateTimeString,
                explicit: isExplicitVR
            ))
        }
        
        return data
    }
    
    /// Encodes a simple data element (helper for command set)
    private static func encodeSimpleElement(tag: Tag, vr: VR, value: Data) -> Data {
        var data = Data()
        
        // Tag (4 bytes, little endian)
        var group = tag.group.littleEndian
        var element = tag.element.littleEndian
        data.append(Data(bytes: &group, count: 2))
        data.append(Data(bytes: &element, count: 2))
        
        // Implicit VR encoding for command set
        var length = UInt32(value.count).littleEndian
        data.append(Data(bytes: &length, count: 4))
        
        // Value
        data.append(value)
        
        return data
    }
    
    /// Encodes a single data element for the attribute list
    private static func encodeElement(tag: Tag, vr: VR, value: String, explicit: Bool) -> Data {
        var data = Data()
        
        // Tag (4 bytes, little endian)
        var group = tag.group.littleEndian
        var element = tag.element.littleEndian
        data.append(Data(bytes: &group, count: 2))
        data.append(Data(bytes: &element, count: 2))
        
        // Prepare value data with padding
        var valueData = value.data(using: .ascii) ?? Data()
        
        // Pad to even length per DICOM rules (PS3.5 Section 6.2)
        // DICOM requires all Value Fields to have even length
        if valueData.count % 2 != 0 {
            // Use space (0x20) padding for text VRs, null (0x00) for binary VRs
            // This is a DICOM-specific requirement to maintain alignment
            let paddingChar: UInt8 = vr.isStringVR ? 0x20 : 0x00
            valueData.append(paddingChar)
        }
        
        if explicit {
            // Explicit VR encoding
            // VR (2 bytes)
            if let vrBytes = vr.rawValue.data(using: .ascii) {
                data.append(vrBytes)
            } else {
                data.append(Data([0x55, 0x4E])) // "UN" fallback
            }
            
            // Check if VR uses 4-byte length
            if vr.uses4ByteLength {
                // Reserved (2 bytes)
                data.append(Data([0x00, 0x00]))
                // Value Length (4 bytes)
                var length = UInt32(valueData.count).littleEndian
                data.append(Data(bytes: &length, count: 4))
            } else {
                // Value Length (2 bytes)
                var length = UInt16(valueData.count).littleEndian
                data.append(Data(bytes: &length, count: 2))
            }
        } else {
            // Implicit VR encoding
            // Value Length (4 bytes)
            var length = UInt32(valueData.count).littleEndian
            data.append(Data(bytes: &length, count: 4))
        }
        
        // Value
        data.append(valueData)
        
        return data
    }
}

#endif
