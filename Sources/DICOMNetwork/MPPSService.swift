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

    // MARK: - N-CREATE specific attributes (PS3.4 Table F.7.2-1)

    /// Patient's Name (0010,0010) — Type 1
    public let patientName: String?

    /// Patient ID (0010,0020) — Type 1
    public let patientID: String?

    /// Modality (0008,0060) — Type 1
    public let modality: String?

    /// Performed Procedure Step ID (0040,0253) — Type 1
    public let procedureStepID: String?

    /// Performed Procedure Step Description (0040,0254) — Type 2
    public let procedureStepDescription: String?

    /// Performed Station AE Title (0040,0241) — Type 1
    public let performedStationAETitle: String?

    /// Performing Physician's Name (0008,1050) — Type 2
    public let performingPhysicianName: String?

    /// Performed Station Name (0040,0242) — Type 2
    public let performedStationName: String?

    /// Accession Number (0008,0050) — Type 2
    public let accessionNumber: String?

    /// Scheduled Procedure Step ID for the Scheduled Step Attributes Sequence (0040,0009)
    public let scheduledProcedureStepID: String?
    
    public init(
        sopInstanceUID: String,
        status: MPPSStatus,
        studyInstanceUID: String? = nil,
        startDateTime: Date? = nil,
        endDateTime: Date? = nil,
        referencedSOPs: [(studyUID: String, seriesUID: String, sopInstanceUID: String)] = [],
        attributes: [Tag: Data] = [:],
        patientName: String? = nil,
        patientID: String? = nil,
        modality: String? = nil,
        procedureStepID: String? = nil,
        procedureStepDescription: String? = nil,
        performedStationAETitle: String? = nil,
        performingPhysicianName: String? = nil,
        performedStationName: String? = nil,
        accessionNumber: String? = nil,
        scheduledProcedureStepID: String? = nil
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.status = status
        self.studyInstanceUID = studyInstanceUID
        self.startDateTime = startDateTime
        self.endDateTime = endDateTime
        self.referencedSOPs = referencedSOPs
        self.attributes = attributes
        self.patientName = patientName
        self.patientID = patientID
        self.modality = modality
        self.procedureStepID = procedureStepID
        self.procedureStepDescription = procedureStepDescription
        self.performedStationAETitle = performedStationAETitle
        self.performingPhysicianName = performingPhysicianName
        self.performedStationName = performedStationName
        self.accessionNumber = accessionNumber
        self.scheduledProcedureStepID = scheduledProcedureStepID
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
    ///   - patientName: Patient's Name (0010,0010)
    ///   - patientID: Patient ID (0010,0020)
    ///   - modality: Modality (0008,0060)
    ///   - procedureStepID: Performed Procedure Step ID (0040,0253)
    ///   - procedureStepDescription: Performed Procedure Step Description (0040,0254)
    ///   - performingPhysicianName: Performing Physician's Name (0008,1050)
    ///   - performedStationName: Performed Station Name (0040,0242)
    ///   - accessionNumber: Accession Number (0008,0050)
    ///   - scheduledProcedureStepID: Scheduled Procedure Step ID (0040,0009) for the Scheduled Step Attributes Sequence
    /// - Returns: The created MPPS SOP Instance UID
    /// - Throws: `DICOMNetworkError` for connection or protocol errors
    public static func create(
        host: String,
        port: UInt16 = dicomDefaultPort,
        callingAE: String,
        calledAE: String,
        studyInstanceUID: String,
        status: MPPSStatus = .inProgress,
        timeout: TimeInterval = 60,
        patientName: String? = nil,
        patientID: String? = nil,
        modality: String? = nil,
        procedureStepID: String? = nil,
        procedureStepDescription: String? = nil,
        performingPhysicianName: String? = nil,
        performedStationName: String? = nil,
        accessionNumber: String? = nil,
        scheduledProcedureStepID: String? = nil
    ) async throws -> String {
        let callingAETitle = try AETitle(callingAE)
        let calledAETitle = try AETitle(calledAE)
        
        let config = MPPSConfiguration(
            callingAETitle: callingAETitle,
            calledAETitle: calledAETitle,
            timeout: timeout
        )
        
        // Generate a new SOP Instance UID for the MPPS
        let mppsInstanceUID = UIDGenerator.generateUID().value
        
        let procedureStep = MPPSProcedureStep(
            sopInstanceUID: mppsInstanceUID,
            status: status,
            studyInstanceUID: studyInstanceUID,
            startDateTime: Date(),
            patientName: patientName,
            patientID: patientID,
            modality: modality,
            procedureStepID: procedureStepID,
            procedureStepDescription: procedureStepDescription,
            performedStationAETitle: callingAE,
            performingPhysicianName: performingPhysicianName,
            performedStationName: performedStationName,
            accessionNumber: accessionNumber,
            scheduledProcedureStepID: scheduledProcedureStepID
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
            commandSet: try CommandSet.decode(from: commandData),
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
            let responseCommandSet = message.commandSet
            let response = NCreateResponse(commandSet: responseCommandSet, presentationContextID: presentationContextID)
            
            guard response.status.isSuccess else {
                throw DICOMNetworkError.storeFailed(response.status)
            }
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
        // Build the N-SET modification list (only update-allowed attributes)
        let modificationData = buildNSetAttributes(procedureStep: procedureStep, transferSyntax: transferSyntax)
        
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
            commandSet: try CommandSet.decode(from: commandData),
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
            let responseCommandSet = message.commandSet
            let response = NSetResponse(commandSet: responseCommandSet, presentationContextID: presentationContextID)
            
            guard response.status.isSuccess else {
                throw DICOMNetworkError.storeFailed(response.status)
            }
        }
    }
    
    /// Builds the MPPS attributes data set per PS3.4 Annex F, Table F.7.2-1.
    ///
    /// For N-CREATE: encodes all required Type 1/2 attributes including the
    /// mandatory Scheduled Step Attributes Sequence (0040,0270) and Performed
    /// Series Sequence (0040,0340).
    private static func buildMPPSAttributes(
        procedureStep: MPPSProcedureStep,
        transferSyntax: String
    ) -> Data {
        var data = Data()
        let isExplicitVR = transferSyntax == explicitVRLittleEndianTransferSyntaxUID

        // ---- Common attributes (sorted by tag ascending for DICOM conformance) ----

        // Specific Character Set (0008,0005) — Type 1C
        data.append(encodeElement(
            tag: Tag(group: 0x0008, element: 0x0005),
            vr: .CS,
            value: "ISO_IR 100",
            explicit: isExplicitVR
        ))

        // Modality (0008,0060) — Type 1
        if let modality = procedureStep.modality, !modality.isEmpty {
            data.append(encodeElement(
                tag: Tag(group: 0x0008, element: 0x0060),
                vr: .CS,
                value: modality,
                explicit: isExplicitVR
            ))
        }

        // Performing Physician's Name (0008,1050) — Type 2
        data.append(encodeElement(
            tag: Tag(group: 0x0008, element: 0x1050),
            vr: .PN,
            value: procedureStep.performingPhysicianName ?? "",
            explicit: isExplicitVR
        ))

        // Patient's Name (0010,0010) — Type 1
        if let patientName = procedureStep.patientName, !patientName.isEmpty {
            data.append(encodeElement(
                tag: Tag(group: 0x0010, element: 0x0010),
                vr: .PN,
                value: patientName,
                explicit: isExplicitVR
            ))
        }

        // Patient ID (0010,0020) — Type 2
        data.append(encodeElement(
            tag: Tag(group: 0x0010, element: 0x0020),
            vr: .LO,
            value: procedureStep.patientID ?? "",
            explicit: isExplicitVR
        ))

        // Study Instance UID (0020,000D) — used in Scheduled Step Attributes Sequence
        if let studyUID = procedureStep.studyInstanceUID {
            data.append(encodeElement(
                tag: .studyInstanceUID,
                vr: .UI,
                value: studyUID,
                explicit: isExplicitVR
            ))
        }

        // Performed Station AE Title (0040,0241) — Type 1
        data.append(encodeElement(
            tag: Tag(group: 0x0040, element: 0x0241),
            vr: .AE,
            value: procedureStep.performedStationAETitle ?? "",
            explicit: isExplicitVR
        ))

        // Performed Station Name (0040,0242) — Type 2
        data.append(encodeElement(
            tag: Tag(group: 0x0040, element: 0x0242),
            vr: .SH,
            value: procedureStep.performedStationName ?? "",
            explicit: isExplicitVR
        ))

        // Performed Procedure Step Start Date (0040,0244) — Type 1
        // Performed Procedure Step Start Time (0040,0245) — Type 1
        if let startDate = procedureStep.startDateTime {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HHmmss"
            timeFormatter.locale = Locale(identifier: "en_US_POSIX")

            data.append(encodeElement(
                tag: Tag(group: 0x0040, element: 0x0244),
                vr: .DA,
                value: dateFormatter.string(from: startDate),
                explicit: isExplicitVR
            ))
            data.append(encodeElement(
                tag: Tag(group: 0x0040, element: 0x0245),
                vr: .TM,
                value: timeFormatter.string(from: startDate),
                explicit: isExplicitVR
            ))
        }

        // Performed Procedure Step End Date (0040,0250) — Type 2
        // Performed Procedure Step End Time (0040,0251) — Type 2
        if let endDateTime = procedureStep.endDateTime {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HHmmss"
            timeFormatter.locale = Locale(identifier: "en_US_POSIX")

            data.append(encodeElement(
                tag: Tag(group: 0x0040, element: 0x0250),
                vr: .DA,
                value: dateFormatter.string(from: endDateTime),
                explicit: isExplicitVR
            ))
            data.append(encodeElement(
                tag: Tag(group: 0x0040, element: 0x0251),
                vr: .TM,
                value: timeFormatter.string(from: endDateTime),
                explicit: isExplicitVR
            ))
        } else {
            // Type 2: must be present (empty for IN PROGRESS in N-CREATE)
            data.append(encodeElement(
                tag: Tag(group: 0x0040, element: 0x0250),
                vr: .DA,
                value: "",
                explicit: isExplicitVR
            ))
            data.append(encodeElement(
                tag: Tag(group: 0x0040, element: 0x0251),
                vr: .TM,
                value: "",
                explicit: isExplicitVR
            ))
        }

        // Performed Procedure Step Status (0040,0252) — Type 1
        data.append(encodeElement(
            tag: Tag(group: 0x0040, element: 0x0252),
            vr: .CS,
            value: procedureStep.status.rawValue,
            explicit: isExplicitVR
        ))

        // Performed Procedure Step ID (0040,0253) — Type 1
        data.append(encodeElement(
            tag: Tag(group: 0x0040, element: 0x0253),
            vr: .SH,
            value: procedureStep.procedureStepID ?? "1",
            explicit: isExplicitVR
        ))

        // Performed Procedure Step Description (0040,0254) — Type 2
        data.append(encodeElement(
            tag: Tag(group: 0x0040, element: 0x0254),
            vr: .LO,
            value: procedureStep.procedureStepDescription ?? "",
            explicit: isExplicitVR
        ))

        // ---- Scheduled Step Attributes Sequence (0040,0270) — Type 1 ----
        // This is the attribute that was causing status 0x0121 errors.
        // Must contain at minimum: Accession Number (0008,0050),
        // Study Instance UID (0020,000D), Referenced Study Sequence (0008,1110),
        // Requested Procedure ID (0040,1001), Scheduled Procedure Step ID (0040,0009),
        // Scheduled Procedure Step Description (0040,0007).
        data.append(buildScheduledStepAttributesSequence(
            procedureStep: procedureStep,
            explicit: isExplicitVR
        ))

        // ---- Performed Series Sequence (0040,0340) — Type 1 ----
        // Required but can be empty for IN PROGRESS; populated for COMPLETED.
        data.append(buildPerformedSeriesSequence(
            procedureStep: procedureStep,
            explicit: isExplicitVR
        ))

        return data
    }

    /// Builds the N-SET modification attribute list per PS3.4 Annex F, Table F.7.2-2.
    ///
    /// N-SET only sends attributes being modified:
    /// - Performed Procedure Step End Date (0040,0250)
    /// - Performed Procedure Step End Time (0040,0251)
    /// - Performed Procedure Step Status (0040,0252)
    /// - Performed Procedure Step Description (0040,0254) — optional
    /// - Performed Series Sequence (0040,0340) — with referenced SOPs
    private static func buildNSetAttributes(
        procedureStep: MPPSProcedureStep,
        transferSyntax: String
    ) -> Data {
        var data = Data()
        let isExplicitVR = transferSyntax == explicitVRLittleEndianTransferSyntaxUID

        // Performed Procedure Step End Date (0040,0250) — Type 1 for COMPLETED
        // Performed Procedure Step End Time (0040,0251) — Type 1 for COMPLETED
        if let endDateTime = procedureStep.endDateTime {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HHmmss"
            timeFormatter.locale = Locale(identifier: "en_US_POSIX")

            data.append(encodeElement(
                tag: Tag(group: 0x0040, element: 0x0250),
                vr: .DA,
                value: dateFormatter.string(from: endDateTime),
                explicit: isExplicitVR
            ))
            data.append(encodeElement(
                tag: Tag(group: 0x0040, element: 0x0251),
                vr: .TM,
                value: timeFormatter.string(from: endDateTime),
                explicit: isExplicitVR
            ))
        } else {
            // Current time as end date/time for completed/discontinued
            let now = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HHmmss"
            timeFormatter.locale = Locale(identifier: "en_US_POSIX")

            data.append(encodeElement(
                tag: Tag(group: 0x0040, element: 0x0250),
                vr: .DA,
                value: dateFormatter.string(from: now),
                explicit: isExplicitVR
            ))
            data.append(encodeElement(
                tag: Tag(group: 0x0040, element: 0x0251),
                vr: .TM,
                value: timeFormatter.string(from: now),
                explicit: isExplicitVR
            ))
        }

        // Performed Procedure Step Status (0040,0252) — Type 1
        data.append(encodeElement(
            tag: Tag(group: 0x0040, element: 0x0252),
            vr: .CS,
            value: procedureStep.status.rawValue,
            explicit: isExplicitVR
        ))

        // Performed Procedure Step Description (0040,0254) — Type 2
        if let desc = procedureStep.procedureStepDescription, !desc.isEmpty {
            data.append(encodeElement(
                tag: Tag(group: 0x0040, element: 0x0254),
                vr: .LO,
                value: desc,
                explicit: isExplicitVR
            ))
        }

        // ---- Performed Series Sequence (0040,0340) — Type 1 ----
        data.append(buildPerformedSeriesSequence(
            procedureStep: procedureStep,
            explicit: isExplicitVR
        ))

        return data
    }

    // MARK: - Sequence builders

    /// Builds the Scheduled Step Attributes Sequence (0040,0270) — Type 1.
    /// Per PS3.4 Table F.7.2-1, this must be present in N-CREATE.
    private static func buildScheduledStepAttributesSequence(
        procedureStep: MPPSProcedureStep,
        explicit: Bool
    ) -> Data {
        // Build item attributes
        var itemData = Data()

        // Accession Number (0008,0050) — Type 2
        itemData.append(encodeElement(
            tag: Tag(group: 0x0008, element: 0x0050),
            vr: .SH,
            value: procedureStep.accessionNumber ?? "",
            explicit: explicit
        ))

        // Referenced Study Sequence (0008,1110) — Type 2 (empty sequence)
        itemData.append(encodeEmptySequence(
            tag: Tag(group: 0x0008, element: 0x1110),
            explicit: explicit
        ))

        // Study Instance UID (0020,000D) — Type 1
        itemData.append(encodeElement(
            tag: Tag(group: 0x0020, element: 0x000D),
            vr: .UI,
            value: procedureStep.studyInstanceUID ?? "",
            explicit: explicit
        ))

        // Scheduled Procedure Step Description (0040,0007) — Type 2
        itemData.append(encodeElement(
            tag: Tag(group: 0x0040, element: 0x0007),
            vr: .LO,
            value: procedureStep.procedureStepDescription ?? "",
            explicit: explicit
        ))

        // Scheduled Procedure Step ID (0040,0009) — Type 1
        itemData.append(encodeElement(
            tag: Tag(group: 0x0040, element: 0x0009),
            vr: .SH,
            value: procedureStep.scheduledProcedureStepID ?? procedureStep.procedureStepID ?? "1",
            explicit: explicit
        ))

        // Requested Procedure ID (0040,1001) — Type 2
        itemData.append(encodeElement(
            tag: Tag(group: 0x0040, element: 0x1001),
            vr: .SH,
            value: procedureStep.procedureStepID ?? "",
            explicit: explicit
        ))

        return encodeSequenceWithItem(
            tag: Tag(group: 0x0040, element: 0x0270),
            itemData: itemData,
            explicit: explicit
        )
    }

    /// Builds the Performed Series Sequence (0040,0340) — Type 1.
    /// Empty for IN PROGRESS; populated with referenced SOPs for COMPLETED.
    private static func buildPerformedSeriesSequence(
        procedureStep: MPPSProcedureStep,
        explicit: Bool
    ) -> Data {
        if procedureStep.referencedSOPs.isEmpty {
            // Empty sequence (no items) — still required as Type 1
            return encodeEmptySequence(
                tag: Tag(group: 0x0040, element: 0x0340),
                explicit: explicit
            )
        }

        // Group references by series UID
        var seriesMap: [String: [(studyUID: String, sopInstanceUID: String)]] = [:]
        for ref in procedureStep.referencedSOPs {
            seriesMap[ref.seriesUID, default: []].append((studyUID: ref.studyUID, sopInstanceUID: ref.sopInstanceUID))
        }

        var allItemsData = Data()
        for (seriesUID, refs) in seriesMap {
            var itemData = Data()

            // Performing Physician's Name (0008,1050) — Type 2
            itemData.append(encodeElement(
                tag: Tag(group: 0x0008, element: 0x1050),
                vr: .PN,
                value: procedureStep.performingPhysicianName ?? "",
                explicit: explicit
            ))

            // Series Instance UID (0020,000E) — Type 1
            itemData.append(encodeElement(
                tag: Tag(group: 0x0020, element: 0x000E),
                vr: .UI,
                value: seriesUID,
                explicit: explicit
            ))

            // Series Description (0008,103E) — Type 2
            itemData.append(encodeElement(
                tag: Tag(group: 0x0008, element: 0x103E),
                vr: .LO,
                value: "",
                explicit: explicit
            ))

            // Referenced Image Sequence (0008,1140) — Type 2
            var refImgData = Data()
            for ref in refs {
                var refItemData = Data()
                // Referenced SOP Class UID (0008,1150) — use a generic secondary capture
                refItemData.append(encodeElement(
                    tag: Tag(group: 0x0008, element: 0x1150),
                    vr: .UI,
                    value: "1.2.840.10008.5.1.4.1.1.7",
                    explicit: explicit
                ))
                // Referenced SOP Instance UID (0008,1155)
                refItemData.append(encodeElement(
                    tag: Tag(group: 0x0008, element: 0x1155),
                    vr: .UI,
                    value: ref.sopInstanceUID,
                    explicit: explicit
                ))
                refImgData.append(encodeSequenceItem(itemData: refItemData))
            }
            itemData.append(encodeSequenceTag(
                tag: Tag(group: 0x0008, element: 0x1140),
                explicit: explicit
            ))
            itemData.append(refImgData)
            itemData.append(sequenceDelimiter())

            allItemsData.append(encodeSequenceItem(itemData: itemData))
        }

        var data = Data()
        data.append(encodeSequenceTag(
            tag: Tag(group: 0x0040, element: 0x0340),
            explicit: explicit
        ))
        data.append(allItemsData)
        data.append(sequenceDelimiter())
        return data
    }

    // MARK: - Sequence encoding helpers

    /// Encodes a complete sequence with a single item.
    private static func encodeSequenceWithItem(tag: Tag, itemData: Data, explicit: Bool) -> Data {
        var data = Data()
        data.append(encodeSequenceTag(tag: tag, explicit: explicit))
        data.append(encodeSequenceItem(itemData: itemData))
        data.append(sequenceDelimiter())
        return data
    }

    /// Encodes an empty sequence (no items).
    private static func encodeEmptySequence(tag: Tag, explicit: Bool) -> Data {
        var data = Data()
        data.append(encodeSequenceTag(tag: tag, explicit: explicit))
        data.append(sequenceDelimiter())
        return data
    }

    /// Encodes a sequence tag with undefined length.
    private static func encodeSequenceTag(tag: Tag, explicit: Bool) -> Data {
        var data = Data()
        var group = tag.group.littleEndian
        var element = tag.element.littleEndian
        data.append(Data(bytes: &group, count: 2))
        data.append(Data(bytes: &element, count: 2))
        if explicit {
            data.append(contentsOf: [0x53, 0x51])   // "SQ"
            data.append(contentsOf: [0x00, 0x00])   // reserved
        }
        data.append(le32(0xFFFFFFFF))                // undefined length
        return data
    }

    /// Encodes a sequence item with undefined length.
    private static func encodeSequenceItem(itemData: Data) -> Data {
        var data = Data()
        // Item tag (FFFE,E000)
        data.append(contentsOf: [0xFE, 0xFF, 0x00, 0xE0])
        data.append(le32(0xFFFFFFFF))   // undefined length
        data.append(itemData)
        // Item delimiter (FFFE,E00D)
        data.append(contentsOf: [0xFE, 0xFF, 0x0D, 0xE0])
        data.append(le32(0x00000000))
        return data
    }

    /// Encodes a sequence delimiter (FFFE,E0DD).
    private static func sequenceDelimiter() -> Data {
        var data = Data()
        data.append(contentsOf: [0xFE, 0xFF, 0xDD, 0xE0])
        data.append(le32(0x00000000))
        return data
    }

    /// Little-endian 32-bit helper.
    private static func le32(_ v: UInt32) -> Data {
        Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF),
              UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)])
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
            let paddingChar: UInt8 = (vr == .UI) ? 0x00 : (vr.isStringVR ? 0x20 : 0x00)
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
