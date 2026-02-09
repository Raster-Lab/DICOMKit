import Foundation

// MARK: - UPSEventType

/// UPS Event Type
///
/// Defines the types of events that can be generated for UPS workitems.
///
/// Reference: PS3.18 Section 11.6 - UPS Event Service
/// Reference: PS3.4 Annex CC.2.6 - Event Reports
public enum UPSEventType: String, Sendable, Codable, CaseIterable {
    /// State Report - workitem state has changed
    case stateReport = "StateReport"
    
    /// Progress Report - workitem progress has been updated
    case progressReport = "ProgressReport"
    
    /// Cancel Requested - cancellation has been requested
    case cancelRequested = "CancelRequested"
    
    /// Assigned - workitem has been assigned to a performer
    case assigned = "Assigned"
    
    /// Completed - workitem has been completed
    case completed = "Completed"
    
    /// Canceled - workitem has been canceled
    case canceled = "Canceled"
}

// MARK: - UPSEvent Protocol

/// Base protocol for all UPS events
///
/// Events are generated when workitem state or properties change and are
/// delivered to subscribers via WebSocket or long polling.
public protocol UPSEvent: Sendable {
    /// The type of event
    var eventType: UPSEventType { get }
    
    /// The UID of the workitem this event is about
    var workitemUID: String { get }
    
    /// Transaction UID for this event
    var transactionUID: String? { get }
    
    /// Timestamp when the event was generated
    var timestamp: Date { get }
    
    /// Converts the event to a DICOM JSON dictionary
    func toDICOMJSON() -> [String: Any]
}

// MARK: - UPSStateReportEvent

/// Event generated when a workitem's state changes
///
/// Reference: PS3.4 Annex CC.2.6.1 - State Report
public struct UPSStateReportEvent: UPSEvent, Sendable, Equatable {
    public let eventType: UPSEventType = .stateReport
    public let workitemUID: String
    public let transactionUID: String?
    public let timestamp: Date
    
    /// Previous state
    public let previousState: UPSState
    
    /// New state
    public let newState: UPSState
    
    /// Optional reason for the state change
    public let reason: String?
    
    /// Creates a state report event
    public init(
        workitemUID: String,
        transactionUID: String? = nil,
        timestamp: Date = Date(),
        previousState: UPSState,
        newState: UPSState,
        reason: String? = nil
    ) {
        self.workitemUID = workitemUID
        self.transactionUID = transactionUID
        self.timestamp = timestamp
        self.previousState = previousState
        self.newState = newState
        self.reason = reason
    }
    
    public func toDICOMJSON() -> [String: Any] {
        var json: [String: Any] = [
            "00081195": ["vr": "UI", "Value": [transactionUID ?? ""]],  // Transaction UID
            "00741000": ["vr": "CS", "Value": [newState.rawValue]],     // Procedure Step State
            "EventType": ["vr": "CS", "Value": [eventType.rawValue]]
        ]
        
        if let reason = reason {
            json["ReasonForStateChange"] = ["vr": "LO", "Value": [reason]]
        }
        
        return json
    }
}

// MARK: - UPSProgressReportEvent

/// Event generated when a workitem's progress is updated
///
/// Reference: PS3.4 Annex CC.2.6.2 - Progress Report
public struct UPSProgressReportEvent: UPSEvent, Sendable, Equatable {
    public let eventType: UPSEventType = .progressReport
    public let workitemUID: String
    public let transactionUID: String?
    public let timestamp: Date
    
    /// Progress information
    public let progressInformation: ProgressInformation
    
    /// Creates a progress report event
    public init(
        workitemUID: String,
        transactionUID: String? = nil,
        timestamp: Date = Date(),
        progressInformation: ProgressInformation
    ) {
        self.workitemUID = workitemUID
        self.transactionUID = transactionUID
        self.timestamp = timestamp
        self.progressInformation = progressInformation
    }
    
    public func toDICOMJSON() -> [String: Any] {
        var json: [String: Any] = [
            "00081195": ["vr": "UI", "Value": [transactionUID ?? ""]],  // Transaction UID
            "EventType": ["vr": "CS", "Value": [eventType.rawValue]]
        ]
        
        // Add progress information
        if let percentage = progressInformation.progressPercentage {
            json["00741004"] = ["vr": "DS", "Value": ["\(percentage)"]]  // Progress
        }
        
        if let description = progressInformation.progressDescription {
            json["00741006"] = ["vr": "ST", "Value": [description]]  // Progress Description
        }
        
        if let contactName = progressInformation.contactDisplayName {
            json["ContactDisplayName"] = ["vr": "LO", "Value": [contactName]]
        }
        
        if let contactURI = progressInformation.contactURI {
            json["ContactURI"] = ["vr": "UR", "Value": [contactURI]]
        }
        
        return json
    }
}

// MARK: - UPSCancelRequestedEvent

/// Event generated when cancellation is requested for a workitem
///
/// Reference: PS3.4 Annex CC.2.6.3 - Cancel Requested
public struct UPSCancelRequestedEvent: UPSEvent, Sendable, Equatable {
    public let eventType: UPSEventType = .cancelRequested
    public let workitemUID: String
    public let transactionUID: String?
    public let timestamp: Date
    
    /// Reason for cancellation
    public let reason: String?
    
    /// Contact display name (who requested cancellation)
    public let contactDisplayName: String?
    
    /// Contact URI
    public let contactURI: String?
    
    /// Discontinuation reason codes
    public let discontinuationReasonCodes: [CodedEntry]?
    
    /// Creates a cancel requested event
    public init(
        workitemUID: String,
        transactionUID: String? = nil,
        timestamp: Date = Date(),
        reason: String? = nil,
        contactDisplayName: String? = nil,
        contactURI: String? = nil,
        discontinuationReasonCodes: [CodedEntry]? = nil
    ) {
        self.workitemUID = workitemUID
        self.transactionUID = transactionUID
        self.timestamp = timestamp
        self.reason = reason
        self.contactDisplayName = contactDisplayName
        self.contactURI = contactURI
        self.discontinuationReasonCodes = discontinuationReasonCodes
    }
    
    public func toDICOMJSON() -> [String: Any] {
        var json: [String: Any] = [
            "00081195": ["vr": "UI", "Value": [transactionUID ?? ""]],  // Transaction UID
            "EventType": ["vr": "CS", "Value": [eventType.rawValue]]
        ]
        
        if let reason = reason {
            json["00741238"] = ["vr": "LT", "Value": [reason]]  // Reason for Cancellation
        }
        
        if let contactName = contactDisplayName {
            json["ContactDisplayName"] = ["vr": "LO", "Value": [contactName]]
        }
        
        if let contactURI = contactURI {
            json["ContactURI"] = ["vr": "UR", "Value": [contactURI]]
        }
        
        return json
    }
}

// MARK: - UPSAssignedEvent

/// Event generated when a workitem is assigned to a performer
///
/// Reference: PS3.4 Annex CC.2.6.4 - Assigned
public struct UPSAssignedEvent: UPSEvent, Sendable, Equatable {
    public let eventType: UPSEventType = .assigned
    public let workitemUID: String
    public let transactionUID: String?
    public let timestamp: Date
    
    /// Assigned performer
    public let performer: HumanPerformer
    
    /// Creates an assigned event
    public init(
        workitemUID: String,
        transactionUID: String? = nil,
        timestamp: Date = Date(),
        performer: HumanPerformer
    ) {
        self.workitemUID = workitemUID
        self.transactionUID = transactionUID
        self.timestamp = timestamp
        self.performer = performer
    }
    
    public func toDICOMJSON() -> [String: Any] {
        var json: [String: Any] = [
            "00081195": ["vr": "UI", "Value": [transactionUID ?? ""]],  // Transaction UID
            "EventType": ["vr": "CS", "Value": [eventType.rawValue]]
        ]
        
        // Add performer information
        var performerSeq: [[String: Any]] = []
        var performerItem: [String: Any] = [:]
        
        if let name = performer.performerName {
            performerItem["00404037"] = ["vr": "PN", "Value": [name]]  // Human Performer Name
        }
        
        if let org = performer.performerOrganization {
            performerItem["00404009"] = ["vr": "LO", "Value": [org]]  // Human Performer Organization
        }
        
        if !performerItem.isEmpty {
            performerSeq.append(performerItem)
        }
        
        if !performerSeq.isEmpty {
            json["00404035"] = ["vr": "SQ", "Value": performerSeq]  // Actual Human Performers Sequence
        }
        
        return json
    }
}

// MARK: - UPSCompletedEvent

/// Event generated when a workitem is completed
///
/// Reference: PS3.4 Annex CC.2.6.5 - Completed
public struct UPSCompletedEvent: UPSEvent, Sendable, Equatable {
    public let eventType: UPSEventType = .completed
    public let workitemUID: String
    public let transactionUID: String?
    public let timestamp: Date
    
    /// Completion reason or notes
    public let completionNotes: String?
    
    /// Creates a completed event
    public init(
        workitemUID: String,
        transactionUID: String? = nil,
        timestamp: Date = Date(),
        completionNotes: String? = nil
    ) {
        self.workitemUID = workitemUID
        self.transactionUID = transactionUID
        self.timestamp = timestamp
        self.completionNotes = completionNotes
    }
    
    public func toDICOMJSON() -> [String: Any] {
        var json: [String: Any] = [
            "00081195": ["vr": "UI", "Value": [transactionUID ?? ""]],  // Transaction UID
            "00741000": ["vr": "CS", "Value": [UPSState.completed.rawValue]],  // State
            "EventType": ["vr": "CS", "Value": [eventType.rawValue]]
        ]
        
        if let notes = completionNotes {
            json["CompletionNotes"] = ["vr": "ST", "Value": [notes]]
        }
        
        return json
    }
}

// MARK: - UPSCanceledEvent

/// Event generated when a workitem is canceled
///
/// Reference: PS3.4 Annex CC.2.6.6 - Canceled
public struct UPSCanceledEvent: UPSEvent, Sendable, Equatable {
    public let eventType: UPSEventType = .canceled
    public let workitemUID: String
    public let transactionUID: String?
    public let timestamp: Date
    
    /// Reason for cancellation
    public let reason: String?
    
    /// Discontinuation reason codes
    public let discontinuationReasonCodes: [CodedEntry]?
    
    /// Creates a canceled event
    public init(
        workitemUID: String,
        transactionUID: String? = nil,
        timestamp: Date = Date(),
        reason: String? = nil,
        discontinuationReasonCodes: [CodedEntry]? = nil
    ) {
        self.workitemUID = workitemUID
        self.transactionUID = transactionUID
        self.timestamp = timestamp
        self.reason = reason
        self.discontinuationReasonCodes = discontinuationReasonCodes
    }
    
    public func toDICOMJSON() -> [String: Any] {
        var json: [String: Any] = [
            "00081195": ["vr": "UI", "Value": [transactionUID ?? ""]],  // Transaction UID
            "00741000": ["vr": "CS", "Value": [UPSState.canceled.rawValue]],  // State
            "EventType": ["vr": "CS", "Value": [eventType.rawValue]]
        ]
        
        if let reason = reason {
            json["00741238"] = ["vr": "LT", "Value": [reason]]  // Reason for Cancellation
        }
        
        return json
    }
}

// MARK: - Type-Erased Event Container

/// Type-erased container for UPS events
public struct AnyUPSEvent: Sendable {
    private let _eventType: UPSEventType
    private let _workitemUID: String
    private let _transactionUID: String?
    private let _timestamp: Date
    private let _toDICOMJSON: @Sendable () -> [String: Any]
    
    public var eventType: UPSEventType { _eventType }
    public var workitemUID: String { _workitemUID }
    public var transactionUID: String? { _transactionUID }
    public var timestamp: Date { _timestamp }
    
    public init<E: UPSEvent>(_ event: E) {
        self._eventType = event.eventType
        self._workitemUID = event.workitemUID
        self._transactionUID = event.transactionUID
        self._timestamp = event.timestamp
        self._toDICOMJSON = { event.toDICOMJSON() }
    }
    
    public func toDICOMJSON() -> [String: Any] {
        return _toDICOMJSON()
    }
}
