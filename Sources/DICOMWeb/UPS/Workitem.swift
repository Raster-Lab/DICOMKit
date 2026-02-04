import Foundation

// MARK: - Workitem

/// Represents a UPS (Unified Procedure Step) workitem
///
/// A workitem represents a unit of work to be performed. It contains
/// scheduling information, patient/procedure references, and state tracking.
///
/// Reference: PS3.18 Section 11 - UPS-RS
/// Reference: PS3.4 Annex CC - Unified Procedure Step Service
public struct Workitem: Sendable, Equatable, Codable {
    
    // MARK: - Identity
    
    /// SOP Instance UID of the workitem
    public let workitemUID: String
    
    // MARK: - Procedure Information
    
    /// Scheduled Procedure Step ID
    public var scheduledProcedureStepID: String?
    
    /// Scheduled Workitem Code Sequence (single item)
    public var scheduledWorkitemCode: CodedEntry?
    
    /// Scheduled Station Name Code Sequence
    public var scheduledStationNameCodes: [CodedEntry]?
    
    /// Scheduled Station Class Code Sequence
    public var scheduledStationClassCodes: [CodedEntry]?
    
    /// Scheduled Station Geographic Location Code Sequence
    public var scheduledStationGeographicLocationCodes: [CodedEntry]?
    
    // MARK: - Scheduling
    
    /// Scheduled Procedure Step Start DateTime
    public var scheduledStartDateTime: Date?
    
    /// Expected Completion DateTime
    public var expectedCompletionDateTime: Date?
    
    /// Scheduled Procedure Step Modification DateTime
    public var modificationDateTime: Date?
    
    // MARK: - Priority
    
    /// Scheduled Procedure Step Priority
    public var priority: UPSPriority
    
    // MARK: - State
    
    /// Procedure Step State
    public var state: UPSState
    
    /// Transaction UID for state changes (required for state transitions)
    public var transactionUID: String?
    
    /// Procedure Step Progress Information Sequence
    public var progressInformation: ProgressInformation?
    
    // MARK: - Cancellation
    
    /// Procedure Step Cancellation DateTime
    public var cancellationDateTime: Date?
    
    /// Reason For Cancellation
    public var cancellationReason: String?
    
    /// Procedure Step Discontinuation Reason Code Sequence
    public var discontinuationReasonCodes: [CodedEntry]?
    
    // MARK: - Patient Information
    
    /// Patient Name
    public var patientName: String?
    
    /// Patient ID
    public var patientID: String?
    
    /// Patient Birth Date
    public var patientBirthDate: String?
    
    /// Patient Sex
    public var patientSex: String?
    
    /// Other Patient IDs Sequence
    public var otherPatientIDs: [String]?
    
    // MARK: - Admission/Visit Information
    
    /// Admission ID
    public var admissionID: String?
    
    /// Issuer of Admission ID Sequence
    public var issuerOfAdmissionID: String?
    
    // MARK: - Study Reference
    
    /// Study Instance UID
    public var studyInstanceUID: String?
    
    /// Accession Number
    public var accessionNumber: String?
    
    /// Referring Physician Name
    public var referringPhysicianName: String?
    
    /// Requested Procedure ID
    public var requestedProcedureID: String?
    
    // MARK: - Performer Information
    
    /// Scheduled Human Performers Sequence
    public var scheduledHumanPerformers: [HumanPerformer]?
    
    /// Actual Human Performers Sequence (for completed steps)
    public var actualHumanPerformers: [HumanPerformer]?
    
    /// Performed Station Name Code Sequence
    public var performedStationNameCodes: [CodedEntry]?
    
    // MARK: - Input/Output Information
    
    /// Input Information Sequence (referenced input objects)
    public var inputInformation: [ReferencedInstance]?
    
    /// Output Information Sequence (created output objects)
    public var outputInformation: [ReferencedInstance]?
    
    // MARK: - Procedure Description
    
    /// Procedure Step Label
    public var procedureStepLabel: String?
    
    /// Worklist Label
    public var worklistLabel: String?
    
    /// Comments on the Scheduled Procedure Step
    public var comments: String?
    
    // MARK: - Initialization
    
    /// Creates a new workitem with required fields
    /// - Parameters:
    ///   - workitemUID: The SOP Instance UID for this workitem
    ///   - state: Initial state (default: SCHEDULED)
    ///   - priority: Priority level (default: MEDIUM)
    public init(
        workitemUID: String,
        state: UPSState = .scheduled,
        priority: UPSPriority = .medium
    ) {
        self.workitemUID = workitemUID
        self.state = state
        self.priority = priority
    }
    
    /// Creates a workitem with common scheduling information
    /// - Parameters:
    ///   - workitemUID: The SOP Instance UID for this workitem
    ///   - scheduledStartDateTime: When the procedure is scheduled to start
    ///   - patientName: Patient's name
    ///   - patientID: Patient's identifier
    ///   - procedureStepLabel: Human-readable label for the procedure
    ///   - priority: Priority level
    public init(
        workitemUID: String,
        scheduledStartDateTime: Date,
        patientName: String? = nil,
        patientID: String? = nil,
        procedureStepLabel: String? = nil,
        priority: UPSPriority = .medium
    ) {
        self.workitemUID = workitemUID
        self.state = .scheduled
        self.priority = priority
        self.scheduledStartDateTime = scheduledStartDateTime
        self.patientName = patientName
        self.patientID = patientID
        self.procedureStepLabel = procedureStepLabel
    }
}

// MARK: - UPSState

/// UPS Procedure Step State
///
/// Reference: PS3.4 Annex CC.2 - State Machine
public enum UPSState: String, Sendable, Codable, CaseIterable {
    /// Workitem has been scheduled but not yet started
    case scheduled = "SCHEDULED"
    
    /// Workitem is currently being performed
    case inProgress = "IN PROGRESS"
    
    /// Workitem has been completed successfully
    case completed = "COMPLETED"
    
    /// Workitem has been canceled
    case canceled = "CANCELED"
    
    /// Returns whether the state is a final state (no further transitions allowed)
    public var isFinal: Bool {
        switch self {
        case .completed, .canceled:
            return true
        case .scheduled, .inProgress:
            return false
        }
    }
    
    /// Returns the valid target states from this state
    public var validTransitions: [UPSState] {
        switch self {
        case .scheduled:
            return [.inProgress, .canceled]
        case .inProgress:
            return [.completed, .canceled]
        case .completed, .canceled:
            return []
        }
    }
    
    /// Checks if transitioning to the given state is valid
    /// - Parameter targetState: The desired target state
    /// - Returns: True if the transition is valid
    public func canTransition(to targetState: UPSState) -> Bool {
        validTransitions.contains(targetState)
    }
}

// MARK: - UPSPriority

/// UPS Scheduled Procedure Step Priority
///
/// Reference: PS3.4 Annex CC.1.1
public enum UPSPriority: String, Sendable, Codable, CaseIterable {
    /// Highest priority - time critical
    case stat = "STAT"
    
    /// Higher than routine priority
    case high = "HIGH"
    
    /// Normal/default priority
    case medium = "MEDIUM"
    
    /// Lower than routine priority
    case low = "LOW"
    
    /// Numeric priority value (lower number = higher priority)
    public var numericValue: Int {
        switch self {
        case .stat: return 1
        case .high: return 2
        case .medium: return 3
        case .low: return 4
        }
    }
}

// MARK: - ProgressInformation

/// Information about workitem execution progress
public struct ProgressInformation: Sendable, Equatable, Codable {
    /// Progress percentage (0-100)
    public var progressPercentage: Int?
    
    /// Progress description text
    public var progressDescription: String?
    
    /// Procedure Step Communication URI Sequence
    public var communicationURIs: [String]?
    
    /// Contact Display Name
    public var contactDisplayName: String?
    
    /// Contact URI
    public var contactURI: String?
    
    public init(
        progressPercentage: Int? = nil,
        progressDescription: String? = nil,
        communicationURIs: [String]? = nil,
        contactDisplayName: String? = nil,
        contactURI: String? = nil
    ) {
        self.progressPercentage = progressPercentage
        self.progressDescription = progressDescription
        self.communicationURIs = communicationURIs
        self.contactDisplayName = contactDisplayName
        self.contactURI = contactURI
    }
}

// MARK: - HumanPerformer

/// Information about a human performer assigned to or performing a workitem
public struct HumanPerformer: Sendable, Equatable, Codable {
    /// Human Performer Code Sequence (code for the performer's role)
    public var performerCode: CodedEntry?
    
    /// Human Performer's Name
    public var performerName: String?
    
    /// Human Performer's Organization
    public var performerOrganization: String?
    
    public init(
        performerCode: CodedEntry? = nil,
        performerName: String? = nil,
        performerOrganization: String? = nil
    ) {
        self.performerCode = performerCode
        self.performerName = performerName
        self.performerOrganization = performerOrganization
    }
}

// MARK: - ReferencedInstance

/// Reference to a DICOM instance (for input/output information)
public struct ReferencedInstance: Sendable, Equatable, Codable {
    /// Referenced SOP Class UID
    public let sopClassUID: String
    
    /// Referenced SOP Instance UID
    public let sopInstanceUID: String
    
    /// Study Instance UID
    public var studyInstanceUID: String?
    
    /// Series Instance UID
    public var seriesInstanceUID: String?
    
    /// Type of instance (e.g., "DICOM", "other")
    public var typeOfInstances: String?
    
    /// Retrieve URI
    public var retrieveURI: String?
    
    public init(
        sopClassUID: String,
        sopInstanceUID: String,
        studyInstanceUID: String? = nil,
        seriesInstanceUID: String? = nil,
        typeOfInstances: String? = nil,
        retrieveURI: String? = nil
    ) {
        self.sopClassUID = sopClassUID
        self.sopInstanceUID = sopInstanceUID
        self.studyInstanceUID = studyInstanceUID
        self.seriesInstanceUID = seriesInstanceUID
        self.typeOfInstances = typeOfInstances
        self.retrieveURI = retrieveURI
    }
}

// MARK: - CodedEntry

/// A coded entry with code value, scheme, and meaning
///
/// Represents a code from a coding scheme (e.g., SNOMED, LOINC)
public struct CodedEntry: Sendable, Equatable, Codable {
    /// Code Value
    public let codeValue: String
    
    /// Coding Scheme Designator
    public let codingSchemeDesignator: String
    
    /// Coding Scheme Version (optional)
    public var codingSchemeVersion: String?
    
    /// Code Meaning
    public let codeMeaning: String
    
    public init(
        codeValue: String,
        codingSchemeDesignator: String,
        codingSchemeVersion: String? = nil,
        codeMeaning: String
    ) {
        self.codeValue = codeValue
        self.codingSchemeDesignator = codingSchemeDesignator
        self.codingSchemeVersion = codingSchemeVersion
        self.codeMeaning = codeMeaning
    }
}

// MARK: - UPSStateChangeRequest

/// Request to change workitem state
public struct UPSStateChangeRequest: Sendable, Equatable {
    /// Target state
    public let targetState: UPSState
    
    /// Transaction UID (required for IN PROGRESS → COMPLETED/CANCELED)
    public let transactionUID: String?
    
    /// Performer information (for state changes)
    public var performer: HumanPerformer?
    
    /// Reason for the state change
    public var reason: String?
    
    /// Discontinuation reason codes (for CANCELED state)
    public var discontinuationReasonCodes: [CodedEntry]?
    
    /// Creates a state change request
    /// - Parameters:
    ///   - targetState: The desired target state
    ///   - transactionUID: Transaction UID (required for completing/canceling from IN PROGRESS)
    public init(
        targetState: UPSState,
        transactionUID: String? = nil,
        performer: HumanPerformer? = nil,
        reason: String? = nil,
        discontinuationReasonCodes: [CodedEntry]? = nil
    ) {
        self.targetState = targetState
        self.transactionUID = transactionUID
        self.performer = performer
        self.reason = reason
        self.discontinuationReasonCodes = discontinuationReasonCodes
    }
}

// MARK: - UPSCancellationRequest

/// Request to cancel a workitem
public struct UPSCancellationRequest: Sendable, Equatable {
    /// Workitem UID to cancel
    public let workitemUID: String
    
    /// Reason for cancellation
    public var reason: String?
    
    /// Contact display name (who requested cancellation)
    public var contactDisplayName: String?
    
    /// Contact URI
    public var contactURI: String?
    
    /// Procedure Step Discontinuation Reason Code Sequence
    public var discontinuationReasonCodes: [CodedEntry]?
    
    public init(
        workitemUID: String,
        reason: String? = nil,
        contactDisplayName: String? = nil,
        contactURI: String? = nil,
        discontinuationReasonCodes: [CodedEntry]? = nil
    ) {
        self.workitemUID = workitemUID
        self.reason = reason
        self.contactDisplayName = contactDisplayName
        self.contactURI = contactURI
        self.discontinuationReasonCodes = discontinuationReasonCodes
    }
}

// MARK: - Workitem Extensions

extension Workitem: CustomStringConvertible {
    public var description: String {
        var parts = ["Workitem(\(workitemUID))"]
        parts.append("state=\(state.rawValue)")
        parts.append("priority=\(priority.rawValue)")
        if let label = procedureStepLabel {
            parts.append("label=\(label)")
        }
        if let patientName = patientName {
            parts.append("patient=\(patientName)")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - DICOM Tags for UPS

/// DICOM tags used for UPS (Unified Procedure Step)
public enum UPSTag {
    // SOP Common
    public static let sopClassUID = "00080016"
    public static let sopInstanceUID = "00080018"
    
    // UPS Progress Information
    public static let procedureStepProgress = "00741004"
    public static let procedureStepProgressDescription = "00741006"
    
    // UPS Relationship
    public static let scheduledWorkitemCodeSequence = "00404018"
    public static let scheduledProcessingParametersSequence = "00741210"
    public static let scheduledStationNameCodeSequence = "00404025"
    public static let scheduledStationClassCodeSequence = "00404026"
    public static let scheduledStationGeographicLocationCodeSequence = "00404027"
    public static let scheduledHumanPerformersSequence = "00404034"
    public static let actualHumanPerformersSequence = "00404035"
    public static let humanPerformerCodeSequence = "00404036"
    public static let humanPerformerName = "00404037"
    public static let humanPerformerOrganization = "00404009"
    
    // UPS Scheduled Procedure Step
    public static let scheduledProcedureStepStartDateTime = "00404005"
    public static let scheduledProcedureStepModificationDateTime = "00404010"
    public static let expectedCompletionDateTime = "00404011"
    public static let scheduledProcedureStepPriority = "00741200"
    public static let procedureStepLabel = "00741204"
    public static let worklistLabel = "00741202"
    public static let scheduledProcedureStepID = "00400009"
    
    // UPS Performed Procedure Step
    public static let procedureStepState = "00741000"
    public static let procedureStepCancellationDateTime = "00404052"
    public static let reasonForCancellation = "00741238"
    public static let procedureStepDiscontinuationReasonCodeSequence = "00741236"
    
    // Transaction
    public static let transactionUID = "00081195"
    
    // Input/Output Information
    public static let inputInformationSequence = "00404021"
    public static let outputInformationSequence = "00404033"
    
    // Referenced SOP
    public static let referencedSOPSequence = "00081199"
    public static let referencedSOPClassUID = "00081150"
    public static let referencedSOPInstanceUID = "00081155"
    public static let retrieveURI = "00401002"
    public static let typeOfInstances = "0040E020"
    
    // Study Reference
    public static let referencedStudySequence = "00081110"
    
    // Coded Entry
    public static let codeValue = "00080100"
    public static let codingSchemeDesignator = "00080102"
    public static let codingSchemeVersion = "00080103"
    public static let codeMeaning = "00080104"
    
    // Comments
    public static let commentsOnScheduledProcedureStep = "00400400"
    
    // Patient
    public static let patientName = "00100010"
    public static let patientID = "00100020"
    public static let patientBirthDate = "00100030"
    public static let patientSex = "00100040"
    
    // Study
    public static let studyInstanceUID = "0020000D"
    public static let accessionNumber = "00080050"
    public static let referringPhysicianName = "00080090"
}
