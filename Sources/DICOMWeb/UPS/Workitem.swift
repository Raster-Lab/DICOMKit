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

// MARK: - Workitem Validation

/// Validation errors for Workitem
public enum WorkitemValidationError: Error, Sendable, Equatable, CustomStringConvertible {
    /// The workitem UID is empty
    case emptyWorkitemUID
    /// A workitem in IN PROGRESS state must have a transaction UID
    case missingTransactionUID
    /// A workitem in a final state cannot be modified
    case finalStateViolation(state: UPSState)
    /// Custom validation failure
    case invalidField(name: String, reason: String)
    
    public var description: String {
        switch self {
        case .emptyWorkitemUID:
            return "Workitem UID must not be empty"
        case .missingTransactionUID:
            return "Transaction UID is required for IN PROGRESS workitems"
        case .finalStateViolation(let state):
            return "Workitem is in final state: \(state.rawValue)"
        case .invalidField(let name, let reason):
            return "Invalid field '\(name)': \(reason)"
        }
    }
}

extension Workitem {
    
    /// Validates that the workitem has the minimum required attributes per the DICOM standard
    ///
    /// Checks:
    /// - Workitem UID must be non-empty
    /// - If state is `.inProgress`, a `transactionUID` should be present
    /// - If state is `.completed` or `.canceled`, the workitem is in a final state
    ///
    /// Reference: PS3.4 Annex CC - Unified Procedure Step Service
    ///
    /// - Returns: An array of validation errors (empty if valid)
    public func validate() -> [WorkitemValidationError] {
        var errors: [WorkitemValidationError] = []
        
        if workitemUID.isEmpty {
            errors.append(.emptyWorkitemUID)
        }
        
        if state == .inProgress && transactionUID == nil {
            errors.append(.missingTransactionUID)
        }
        
        if state.isFinal {
            errors.append(.finalStateViolation(state: state))
        }
        
        return errors
    }
    
    /// Returns whether the workitem passes all validations
    public var isValid: Bool {
        validate().isEmpty
    }
}

// MARK: - Workitem DICOM JSON Serialization

extension Workitem {
    
    /// Converts this Workitem to DICOM JSON format
    ///
    /// Produces a dictionary conforming to the DICOM JSON Model (PS3.18 Annex F)
    /// with all populated attributes serialized using proper Value Representations.
    ///
    /// Reference: PS3.18 Section 11 - UPS-RS
    /// Reference: PS3.18 Annex F - DICOM JSON Model
    ///
    /// - Returns: A DICOM JSON dictionary representation of this workitem
    public func toDICOMJSON() -> [String: Any] {
        var json: [String: Any] = [:]
        
        // SOP Instance UID (0008,0018) - VR: UI
        json[UPSTag.sopInstanceUID] = [
            "vr": "UI",
            "Value": [workitemUID]
        ]
        
        // Procedure Step State (0074,1000) - VR: CS
        json[UPSTag.procedureStepState] = [
            "vr": "CS",
            "Value": [state.rawValue]
        ]
        
        // Scheduled Procedure Step Priority (0074,1200) - VR: CS
        json[UPSTag.scheduledProcedureStepPriority] = [
            "vr": "CS",
            "Value": [priority.rawValue]
        ]
        
        // Patient Name (0010,0010) - VR: PN
        if let patientName = patientName {
            json[UPSTag.patientName] = [
                "vr": "PN",
                "Value": [["Alphabetic": patientName]]
            ]
        }
        
        // Patient ID (0010,0020) - VR: LO
        if let patientID = patientID {
            json[UPSTag.patientID] = [
                "vr": "LO",
                "Value": [patientID]
            ]
        }
        
        // Patient Birth Date (0010,0030) - VR: DA
        if let patientBirthDate = patientBirthDate {
            json[UPSTag.patientBirthDate] = [
                "vr": "DA",
                "Value": [patientBirthDate]
            ]
        }
        
        // Patient Sex (0010,0040) - VR: CS
        if let patientSex = patientSex {
            json[UPSTag.patientSex] = [
                "vr": "CS",
                "Value": [patientSex]
            ]
        }
        
        // Scheduled Procedure Step Start DateTime (0040,4005) - VR: DT
        if let scheduledStartDateTime = scheduledStartDateTime {
            json[UPSTag.scheduledProcedureStepStartDateTime] = [
                "vr": "DT",
                "Value": [Workitem.formatDateTime(scheduledStartDateTime)]
            ]
        }
        
        // Expected Completion DateTime (0040,4011) - VR: DT
        if let expectedCompletionDateTime = expectedCompletionDateTime {
            json[UPSTag.expectedCompletionDateTime] = [
                "vr": "DT",
                "Value": [Workitem.formatDateTime(expectedCompletionDateTime)]
            ]
        }
        
        // Scheduled Procedure Step Modification DateTime (0040,4010) - VR: DT
        if let modificationDateTime = modificationDateTime {
            json[UPSTag.scheduledProcedureStepModificationDateTime] = [
                "vr": "DT",
                "Value": [Workitem.formatDateTime(modificationDateTime)]
            ]
        }
        
        // Study Instance UID (0020,000D) - VR: UI
        if let studyUID = studyInstanceUID {
            json[UPSTag.studyInstanceUID] = [
                "vr": "UI",
                "Value": [studyUID]
            ]
        }
        
        // Accession Number (0008,0050) - VR: SH
        if let accession = accessionNumber {
            json[UPSTag.accessionNumber] = [
                "vr": "SH",
                "Value": [accession]
            ]
        }
        
        // Referring Physician's Name (0008,0090) - VR: PN
        if let referringPhysicianName = referringPhysicianName {
            json[UPSTag.referringPhysicianName] = [
                "vr": "PN",
                "Value": [["Alphabetic": referringPhysicianName]]
            ]
        }
        
        // Procedure Step Label (0074,1204) - VR: LO
        if let label = procedureStepLabel {
            json[UPSTag.procedureStepLabel] = [
                "vr": "LO",
                "Value": [label]
            ]
        }
        
        // Worklist Label (0074,1202) - VR: LO
        if let worklistLabel = worklistLabel {
            json[UPSTag.worklistLabel] = [
                "vr": "LO",
                "Value": [worklistLabel]
            ]
        }
        
        // Scheduled Procedure Step ID (0040,0009) - VR: SH
        if let stepID = scheduledProcedureStepID {
            json[UPSTag.scheduledProcedureStepID] = [
                "vr": "SH",
                "Value": [stepID]
            ]
        }
        
        // Comments on Scheduled Procedure Step (0040,0400) - VR: LT
        if let comments = comments {
            json[UPSTag.commentsOnScheduledProcedureStep] = [
                "vr": "LT",
                "Value": [comments]
            ]
        }
        
        // Transaction UID (0008,1195) - VR: UI
        if let txUID = transactionUID {
            json[UPSTag.transactionUID] = [
                "vr": "UI",
                "Value": [txUID]
            ]
        }
        
        // Procedure Step Cancellation DateTime (0040,4052) - VR: DT
        if let cancellationDateTime = cancellationDateTime {
            json[UPSTag.procedureStepCancellationDateTime] = [
                "vr": "DT",
                "Value": [Workitem.formatDateTime(cancellationDateTime)]
            ]
        }
        
        // Reason For Cancellation (0074,1238) - VR: LT
        if let cancellationReason = cancellationReason {
            json[UPSTag.reasonForCancellation] = [
                "vr": "LT",
                "Value": [cancellationReason]
            ]
        }
        
        // Input Information Sequence (0040,4021) - VR: SQ
        if let inputInfo = inputInformation, !inputInfo.isEmpty {
            json[UPSTag.inputInformationSequence] = [
                "vr": "SQ",
                "Value": inputInfo.map { Workitem.referencedInstanceToJSON($0) }
            ]
        }
        
        // Output Information Sequence (0040,4033) - VR: SQ
        if let outputInfo = outputInformation, !outputInfo.isEmpty {
            json[UPSTag.outputInformationSequence] = [
                "vr": "SQ",
                "Value": outputInfo.map { Workitem.referencedInstanceToJSON($0) }
            ]
        }
        
        // Scheduled Human Performers Sequence (0040,4034) - VR: SQ
        if let performers = scheduledHumanPerformers, !performers.isEmpty {
            json[UPSTag.scheduledHumanPerformersSequence] = [
                "vr": "SQ",
                "Value": performers.map { Workitem.humanPerformerToJSON($0) }
            ]
        }
        
        // Actual Human Performers Sequence (0040,4035) - VR: SQ
        if let performers = actualHumanPerformers, !performers.isEmpty {
            json[UPSTag.actualHumanPerformersSequence] = [
                "vr": "SQ",
                "Value": performers.map { Workitem.humanPerformerToJSON($0) }
            ]
        }
        
        // Scheduled Workitem Code Sequence (0040,4018) - VR: SQ
        if let code = scheduledWorkitemCode {
            json[UPSTag.scheduledWorkitemCodeSequence] = [
                "vr": "SQ",
                "Value": [Workitem.codedEntryToJSON(code)]
            ]
        }
        
        // Progress Information
        if let progress = progressInformation {
            if let pct = progress.progressPercentage {
                json[UPSTag.procedureStepProgress] = [
                    "vr": "DS",
                    "Value": [pct]
                ]
            }
            if let desc = progress.progressDescription {
                json[UPSTag.procedureStepProgressDescription] = [
                    "vr": "LO",
                    "Value": [desc]
                ]
            }
        }
        
        return json
    }
    
    // MARK: - Private Serialization Helpers
    
    /// Shared ISO8601 date formatter for DICOM DT serialization
    nonisolated(unsafe) private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter
    }()
    
    /// Formats a Date to a DICOM DT string
    private static func formatDateTime(_ date: Date) -> String {
        return iso8601Formatter.string(from: date)
    }
    
    /// Converts a ReferencedInstance to DICOM JSON
    private static func referencedInstanceToJSON(_ ref: ReferencedInstance) -> [String: Any] {
        var item: [String: Any] = [:]
        item[UPSTag.referencedSOPClassUID] = ["vr": "UI", "Value": [ref.sopClassUID]]
        item[UPSTag.referencedSOPInstanceUID] = ["vr": "UI", "Value": [ref.sopInstanceUID]]
        if let studyUID = ref.studyInstanceUID {
            item[UPSTag.studyInstanceUID] = ["vr": "UI", "Value": [studyUID]]
        }
        if let seriesUID = ref.seriesInstanceUID {
            item[UPSTag.seriesInstanceUID] = ["vr": "UI", "Value": [seriesUID]]
        }
        if let typeOfInstances = ref.typeOfInstances {
            item[UPSTag.typeOfInstances] = ["vr": "CS", "Value": [typeOfInstances]]
        }
        if let retrieveURI = ref.retrieveURI {
            item[UPSTag.retrieveURI] = ["vr": "UR", "Value": [retrieveURI]]
        }
        return item
    }
    
    /// Converts a HumanPerformer to DICOM JSON
    private static func humanPerformerToJSON(_ performer: HumanPerformer) -> [String: Any] {
        var item: [String: Any] = [:]
        if let code = performer.performerCode {
            item[UPSTag.humanPerformerCodeSequence] = [
                "vr": "SQ",
                "Value": [codedEntryToJSON(code)]
            ]
        }
        if let name = performer.performerName {
            item[UPSTag.humanPerformerName] = [
                "vr": "LO",
                "Value": [name]
            ]
        }
        if let org = performer.performerOrganization {
            item[UPSTag.humanPerformerOrganization] = [
                "vr": "LO",
                "Value": [org]
            ]
        }
        return item
    }
    
    /// Converts a CodedEntry to DICOM JSON
    private static func codedEntryToJSON(_ entry: CodedEntry) -> [String: Any] {
        var item: [String: Any] = [:]
        item[UPSTag.codeValue] = ["vr": "SH", "Value": [entry.codeValue]]
        item[UPSTag.codingSchemeDesignator] = ["vr": "SH", "Value": [entry.codingSchemeDesignator]]
        if let version = entry.codingSchemeVersion {
            item[UPSTag.codingSchemeVersion] = ["vr": "SH", "Value": [version]]
        }
        item[UPSTag.codeMeaning] = ["vr": "LO", "Value": [entry.codeMeaning]]
        return item
    }
}

// MARK: - Workitem DICOM JSON Parsing

extension Workitem {
    
    /// Parses a Workitem from DICOM JSON format
    ///
    /// Creates a fully populated Workitem from a DICOM JSON dictionary.
    /// The workitem UID (SOP Instance UID) is required; all other fields are optional.
    ///
    /// Reference: PS3.18 Annex F - DICOM JSON Model
    ///
    /// - Parameter json: A DICOM JSON dictionary
    /// - Returns: A parsed Workitem, or nil if the workitem UID is missing
    public static func parse(json: [String: Any]) -> Workitem? {
        guard let uid = extractString(from: json, tag: UPSTag.sopInstanceUID) else {
            return nil
        }
        
        let stateStr = extractString(from: json, tag: UPSTag.procedureStepState)
        let state = stateStr.flatMap { UPSState(rawValue: $0) } ?? .scheduled
        
        let priorityStr = extractString(from: json, tag: UPSTag.scheduledProcedureStepPriority)
        let priority = priorityStr.flatMap { UPSPriority(rawValue: $0) } ?? .medium
        
        var workitem = Workitem(workitemUID: uid, state: state, priority: priority)
        
        // Patient
        workitem.patientName = extractPersonName(from: json, tag: UPSTag.patientName)
        workitem.patientID = extractString(from: json, tag: UPSTag.patientID)
        workitem.patientBirthDate = extractString(from: json, tag: UPSTag.patientBirthDate)
        workitem.patientSex = extractString(from: json, tag: UPSTag.patientSex)
        
        // Scheduling
        if let dtStr = extractString(from: json, tag: UPSTag.scheduledProcedureStepStartDateTime) {
            workitem.scheduledStartDateTime = parseDateTime(dtStr)
        }
        if let dtStr = extractString(from: json, tag: UPSTag.expectedCompletionDateTime) {
            workitem.expectedCompletionDateTime = parseDateTime(dtStr)
        }
        if let dtStr = extractString(from: json, tag: UPSTag.scheduledProcedureStepModificationDateTime) {
            workitem.modificationDateTime = parseDateTime(dtStr)
        }
        
        // Study reference
        workitem.studyInstanceUID = extractString(from: json, tag: UPSTag.studyInstanceUID)
        workitem.accessionNumber = extractString(from: json, tag: UPSTag.accessionNumber)
        workitem.referringPhysicianName = extractPersonName(from: json, tag: UPSTag.referringPhysicianName)
        
        // Identification
        workitem.procedureStepLabel = extractString(from: json, tag: UPSTag.procedureStepLabel)
        workitem.worklistLabel = extractString(from: json, tag: UPSTag.worklistLabel)
        workitem.scheduledProcedureStepID = extractString(from: json, tag: UPSTag.scheduledProcedureStepID)
        workitem.comments = extractString(from: json, tag: UPSTag.commentsOnScheduledProcedureStep)
        
        // Transaction
        workitem.transactionUID = extractString(from: json, tag: UPSTag.transactionUID)
        
        // Cancellation
        if let dtStr = extractString(from: json, tag: UPSTag.procedureStepCancellationDateTime) {
            workitem.cancellationDateTime = parseDateTime(dtStr)
        }
        workitem.cancellationReason = extractString(from: json, tag: UPSTag.reasonForCancellation)
        
        // Input Information Sequence
        workitem.inputInformation = extractReferencedInstances(from: json, tag: UPSTag.inputInformationSequence)
        
        // Output Information Sequence
        workitem.outputInformation = extractReferencedInstances(from: json, tag: UPSTag.outputInformationSequence)
        
        // Human Performers
        workitem.scheduledHumanPerformers = extractHumanPerformers(from: json, tag: UPSTag.scheduledHumanPerformersSequence)
        workitem.actualHumanPerformers = extractHumanPerformers(from: json, tag: UPSTag.actualHumanPerformersSequence)
        
        // Scheduled Workitem Code
        workitem.scheduledWorkitemCode = extractCodedEntry(from: json, tag: UPSTag.scheduledWorkitemCodeSequence)
        
        // Progress
        let progressPct = extractInt(from: json, tag: UPSTag.procedureStepProgress)
        let progressDesc = extractString(from: json, tag: UPSTag.procedureStepProgressDescription)
        if progressPct != nil || progressDesc != nil {
            workitem.progressInformation = ProgressInformation(
                progressPercentage: progressPct,
                progressDescription: progressDesc
            )
        }
        
        return workitem
    }
    
    // MARK: - Private Parsing Helpers
    
    /// Extracts a string value from DICOM JSON
    private static func extractString(from json: [String: Any], tag: String) -> String? {
        guard let element = json[tag] as? [String: Any],
              let values = element["Value"] as? [Any],
              let first = values.first else {
            return nil
        }
        return first as? String
    }
    
    /// Extracts an integer value from DICOM JSON
    private static func extractInt(from json: [String: Any], tag: String) -> Int? {
        guard let element = json[tag] as? [String: Any],
              let values = element["Value"] as? [Any],
              let first = values.first else {
            return nil
        }
        if let intValue = first as? Int {
            return intValue
        }
        if let stringValue = first as? String {
            return Int(stringValue)
        }
        return nil
    }
    
    /// Extracts a person name value from DICOM JSON (handles PN VR format)
    private static func extractPersonName(from json: [String: Any], tag: String) -> String? {
        guard let element = json[tag] as? [String: Any],
              let values = element["Value"] as? [Any],
              let first = values.first else {
            return nil
        }
        if let stringValue = first as? String {
            return stringValue
        }
        if let dictValue = first as? [String: Any],
           let alphabetic = dictValue["Alphabetic"] as? String {
            return alphabetic
        }
        return nil
    }
    
    /// Parses a DICOM DT string to a Date
    private static func parseDateTime(_ string: String) -> Date? {
        return iso8601Formatter.date(from: string)
    }
    
    /// Extracts a sequence of ReferencedInstance from DICOM JSON
    private static func extractReferencedInstances(from json: [String: Any], tag: String) -> [ReferencedInstance]? {
        guard let element = json[tag] as? [String: Any],
              let items = element["Value"] as? [[String: Any]] else {
            return nil
        }
        let instances = items.compactMap { item -> ReferencedInstance? in
            guard let sopClassUID = extractString(from: item, tag: UPSTag.referencedSOPClassUID),
                  let sopInstanceUID = extractString(from: item, tag: UPSTag.referencedSOPInstanceUID) else {
                return nil
            }
            return ReferencedInstance(
                sopClassUID: sopClassUID,
                sopInstanceUID: sopInstanceUID,
                studyInstanceUID: extractString(from: item, tag: UPSTag.studyInstanceUID),
                seriesInstanceUID: extractString(from: item, tag: UPSTag.seriesInstanceUID),
                typeOfInstances: extractString(from: item, tag: UPSTag.typeOfInstances),
                retrieveURI: extractString(from: item, tag: UPSTag.retrieveURI)
            )
        }
        return instances.isEmpty ? nil : instances
    }
    
    /// Extracts a sequence of HumanPerformer from DICOM JSON
    private static func extractHumanPerformers(from json: [String: Any], tag: String) -> [HumanPerformer]? {
        guard let element = json[tag] as? [String: Any],
              let items = element["Value"] as? [[String: Any]] else {
            return nil
        }
        let performers = items.map { item -> HumanPerformer in
            let code = extractCodedEntry(from: item, tag: UPSTag.humanPerformerCodeSequence)
            let name = extractString(from: item, tag: UPSTag.humanPerformerName)
            let org = extractString(from: item, tag: UPSTag.humanPerformerOrganization)
            return HumanPerformer(performerCode: code, performerName: name, performerOrganization: org)
        }
        return performers.isEmpty ? nil : performers
    }
    
    /// Extracts a CodedEntry from a sequence tag in DICOM JSON
    private static func extractCodedEntry(from json: [String: Any], tag: String) -> CodedEntry? {
        guard let element = json[tag] as? [String: Any],
              let items = element["Value"] as? [[String: Any]],
              let first = items.first else {
            return nil
        }
        guard let codeValue = extractString(from: first, tag: UPSTag.codeValue),
              let designator = extractString(from: first, tag: UPSTag.codingSchemeDesignator),
              let meaning = extractString(from: first, tag: UPSTag.codeMeaning) else {
            return nil
        }
        return CodedEntry(
            codeValue: codeValue,
            codingSchemeDesignator: designator,
            codingSchemeVersion: extractString(from: first, tag: UPSTag.codingSchemeVersion),
            codeMeaning: meaning
        )
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
    
    // Series
    public static let seriesInstanceUID = "0020000E"
    
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
