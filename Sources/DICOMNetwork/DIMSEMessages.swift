import Foundation
import DICOMCore

/// Protocol for DIMSE messages
///
/// All DIMSE messages have a command set and optionally a data set.
public protocol DIMSEMessage: Sendable {
    /// The command set for this message
    var commandSet: CommandSet { get }
    
    /// Whether this message has a data set
    var hasDataSet: Bool { get }
    
    /// The presentation context ID for this message
    var presentationContextID: UInt8 { get }
}

// MARK: - DIMSEMessage Default Implementation
extension DIMSEMessage {
    public var hasDataSet: Bool {
        commandSet.hasDataSet
    }
}

/// Protocol for DIMSE request messages
public protocol DIMSERequest: DIMSEMessage {
    /// The message ID for this request
    var messageID: UInt16 { get }
}

/// Protocol for DIMSE response messages
public protocol DIMSEResponse: DIMSEMessage {
    /// The message ID being responded to
    var messageIDBeingRespondedTo: UInt16 { get }
    
    /// The status of the response
    var status: DIMSEStatus { get }
}

// MARK: - C-ECHO Messages

/// C-ECHO Request
///
/// Verification SOP Class request to test connectivity.
///
/// Reference: PS3.7 Section 9.1.5 - C-ECHO Service
public struct CEchoRequest: DIMSERequest, Hashable {
    public let commandSet: CommandSet
    public let presentationContextID: UInt8
    
    public var messageID: UInt16 {
        commandSet.messageID ?? 0
    }
    
    public var affectedSOPClassUID: String {
        commandSet.affectedSOPClassUID ?? ""
    }
    
    /// Creates a C-ECHO request
    ///
    /// - Parameters:
    ///   - messageID: The message ID (unique within association)
    ///   - affectedSOPClassUID: The Verification SOP Class UID (default: 1.2.840.10008.1.1)
    ///   - presentationContextID: The negotiated presentation context ID
    public init(
        messageID: UInt16,
        affectedSOPClassUID: String = "1.2.840.10008.1.1",
        presentationContextID: UInt8
    ) {
        var cmd = CommandSet()
        cmd.setCommand(.cEchoRequest)
        cmd.setMessageID(messageID)
        cmd.setAffectedSOPClassUID(affectedSOPClassUID)
        cmd.setHasDataSet(false)
        self.commandSet = cmd
        self.presentationContextID = presentationContextID
    }
    
    /// Creates a C-ECHO request from an existing command set
    public init(commandSet: CommandSet, presentationContextID: UInt8) {
        self.commandSet = commandSet
        self.presentationContextID = presentationContextID
    }
}

/// C-ECHO Response
///
/// Verification SOP Class response.
///
/// Reference: PS3.7 Section 9.1.5 - C-ECHO Service
public struct CEchoResponse: DIMSEResponse, Hashable {
    public let commandSet: CommandSet
    public let presentationContextID: UInt8
    
    public var messageIDBeingRespondedTo: UInt16 {
        commandSet.messageIDBeingRespondedTo ?? 0
    }
    
    public var status: DIMSEStatus {
        commandSet.status ?? .unknown(0xFFFF)
    }
    
    public var affectedSOPClassUID: String {
        commandSet.affectedSOPClassUID ?? ""
    }
    
    /// Creates a C-ECHO response
    ///
    /// - Parameters:
    ///   - messageIDBeingRespondedTo: The message ID of the request
    ///   - affectedSOPClassUID: The Verification SOP Class UID
    ///   - status: The response status (default: success)
    ///   - presentationContextID: The presentation context ID
    public init(
        messageIDBeingRespondedTo: UInt16,
        affectedSOPClassUID: String = "1.2.840.10008.1.1",
        status: DIMSEStatus = .success,
        presentationContextID: UInt8
    ) {
        var cmd = CommandSet()
        cmd.setCommand(.cEchoResponse)
        cmd.setMessageIDBeingRespondedTo(messageIDBeingRespondedTo)
        cmd.setAffectedSOPClassUID(affectedSOPClassUID)
        cmd.setStatus(status)
        cmd.setHasDataSet(false)
        self.commandSet = cmd
        self.presentationContextID = presentationContextID
    }
    
    /// Creates a C-ECHO response from an existing command set
    public init(commandSet: CommandSet, presentationContextID: UInt8) {
        self.commandSet = commandSet
        self.presentationContextID = presentationContextID
    }
}

// MARK: - C-STORE Messages

/// C-STORE Request
///
/// Request to store a DICOM object.
///
/// Reference: PS3.7 Section 9.1.1 - C-STORE Service
public struct CStoreRequest: DIMSERequest, Hashable {
    public let commandSet: CommandSet
    public let presentationContextID: UInt8
    
    public var messageID: UInt16 {
        commandSet.messageID ?? 0
    }
    
    public var affectedSOPClassUID: String {
        commandSet.affectedSOPClassUID ?? ""
    }
    
    public var affectedSOPInstanceUID: String {
        commandSet.affectedSOPInstanceUID ?? ""
    }
    
    public var priority: DIMSEPriority {
        commandSet.priority ?? .medium
    }
    
    /// Move originator AE title (for C-MOVE initiated stores)
    public var moveOriginatorAETitle: String? {
        commandSet.getString(.moveOriginatorApplicationEntityTitle)
    }
    
    /// Move originator message ID (for C-MOVE initiated stores)
    public var moveOriginatorMessageID: UInt16? {
        commandSet.getUInt16(.moveOriginatorMessageID)
    }
    
    /// Creates a C-STORE request
    ///
    /// - Parameters:
    ///   - messageID: The message ID
    ///   - affectedSOPClassUID: The SOP Class UID of the object
    ///   - affectedSOPInstanceUID: The SOP Instance UID of the object
    ///   - priority: The operation priority (default: medium)
    ///   - moveOriginatorAETitle: The AE title of the move originator (optional)
    ///   - moveOriginatorMessageID: The message ID of the move operation (optional)
    ///   - presentationContextID: The presentation context ID
    public init(
        messageID: UInt16,
        affectedSOPClassUID: String,
        affectedSOPInstanceUID: String,
        priority: DIMSEPriority = .medium,
        moveOriginatorAETitle: String? = nil,
        moveOriginatorMessageID: UInt16? = nil,
        presentationContextID: UInt8
    ) {
        var cmd = CommandSet()
        cmd.setCommand(.cStoreRequest)
        cmd.setMessageID(messageID)
        cmd.setAffectedSOPClassUID(affectedSOPClassUID)
        cmd.setAffectedSOPInstanceUID(affectedSOPInstanceUID)
        cmd.setPriority(priority)
        cmd.setHasDataSet(true)
        
        if let moveAE = moveOriginatorAETitle {
            cmd.setString(moveAE, for: .moveOriginatorApplicationEntityTitle)
        }
        if let moveID = moveOriginatorMessageID {
            cmd.setUInt16(moveID, for: .moveOriginatorMessageID)
        }
        
        self.commandSet = cmd
        self.presentationContextID = presentationContextID
    }
    
    /// Creates a C-STORE request from an existing command set
    public init(commandSet: CommandSet, presentationContextID: UInt8) {
        self.commandSet = commandSet
        self.presentationContextID = presentationContextID
    }
}

/// C-STORE Response
///
/// Response to a C-STORE request.
///
/// Reference: PS3.7 Section 9.1.1 - C-STORE Service
public struct CStoreResponse: DIMSEResponse, Hashable {
    public let commandSet: CommandSet
    public let presentationContextID: UInt8
    
    public var messageIDBeingRespondedTo: UInt16 {
        commandSet.messageIDBeingRespondedTo ?? 0
    }
    
    public var status: DIMSEStatus {
        commandSet.status ?? .unknown(0xFFFF)
    }
    
    public var affectedSOPClassUID: String {
        commandSet.affectedSOPClassUID ?? ""
    }
    
    public var affectedSOPInstanceUID: String {
        commandSet.affectedSOPInstanceUID ?? ""
    }
    
    /// Creates a C-STORE response
    ///
    /// - Parameters:
    ///   - messageIDBeingRespondedTo: The message ID of the request
    ///   - affectedSOPClassUID: The SOP Class UID
    ///   - affectedSOPInstanceUID: The SOP Instance UID
    ///   - status: The response status (default: success)
    ///   - presentationContextID: The presentation context ID
    public init(
        messageIDBeingRespondedTo: UInt16,
        affectedSOPClassUID: String,
        affectedSOPInstanceUID: String,
        status: DIMSEStatus = .success,
        presentationContextID: UInt8
    ) {
        var cmd = CommandSet()
        cmd.setCommand(.cStoreResponse)
        cmd.setMessageIDBeingRespondedTo(messageIDBeingRespondedTo)
        cmd.setAffectedSOPClassUID(affectedSOPClassUID)
        cmd.setAffectedSOPInstanceUID(affectedSOPInstanceUID)
        cmd.setStatus(status)
        cmd.setHasDataSet(false)
        self.commandSet = cmd
        self.presentationContextID = presentationContextID
    }
    
    /// Creates a C-STORE response from an existing command set
    public init(commandSet: CommandSet, presentationContextID: UInt8) {
        self.commandSet = commandSet
        self.presentationContextID = presentationContextID
    }
}

// MARK: - C-FIND Messages

/// C-FIND Request
///
/// Request to query for DICOM objects.
///
/// Reference: PS3.7 Section 9.1.2 - C-FIND Service
public struct CFindRequest: DIMSERequest, Hashable {
    public let commandSet: CommandSet
    public let presentationContextID: UInt8
    
    public var messageID: UInt16 {
        commandSet.messageID ?? 0
    }
    
    public var affectedSOPClassUID: String {
        commandSet.affectedSOPClassUID ?? ""
    }
    
    public var priority: DIMSEPriority {
        commandSet.priority ?? .medium
    }
    
    /// Creates a C-FIND request
    ///
    /// - Parameters:
    ///   - messageID: The message ID
    ///   - affectedSOPClassUID: The Query/Retrieve Information Model SOP Class UID
    ///   - priority: The operation priority (default: medium)
    ///   - presentationContextID: The presentation context ID
    public init(
        messageID: UInt16,
        affectedSOPClassUID: String,
        priority: DIMSEPriority = .medium,
        presentationContextID: UInt8
    ) {
        var cmd = CommandSet()
        cmd.setCommand(.cFindRequest)
        cmd.setMessageID(messageID)
        cmd.setAffectedSOPClassUID(affectedSOPClassUID)
        cmd.setPriority(priority)
        cmd.setHasDataSet(true)
        self.commandSet = cmd
        self.presentationContextID = presentationContextID
    }
    
    /// Creates a C-FIND request from an existing command set
    public init(commandSet: CommandSet, presentationContextID: UInt8) {
        self.commandSet = commandSet
        self.presentationContextID = presentationContextID
    }
}

/// C-FIND Response
///
/// Response to a C-FIND request. May be sent multiple times (pending status)
/// until final response (success/failure).
///
/// Reference: PS3.7 Section 9.1.2 - C-FIND Service
public struct CFindResponse: DIMSEResponse, Hashable {
    public let commandSet: CommandSet
    public let presentationContextID: UInt8
    
    public var messageIDBeingRespondedTo: UInt16 {
        commandSet.messageIDBeingRespondedTo ?? 0
    }
    
    public var status: DIMSEStatus {
        commandSet.status ?? .unknown(0xFFFF)
    }
    
    public var affectedSOPClassUID: String {
        commandSet.affectedSOPClassUID ?? ""
    }
    
    /// Creates a C-FIND response
    ///
    /// - Parameters:
    ///   - messageIDBeingRespondedTo: The message ID of the request
    ///   - affectedSOPClassUID: The SOP Class UID
    ///   - status: The response status
    ///   - hasDataSet: Whether a matching data set follows
    ///   - presentationContextID: The presentation context ID
    public init(
        messageIDBeingRespondedTo: UInt16,
        affectedSOPClassUID: String,
        status: DIMSEStatus,
        hasDataSet: Bool,
        presentationContextID: UInt8
    ) {
        var cmd = CommandSet()
        cmd.setCommand(.cFindResponse)
        cmd.setMessageIDBeingRespondedTo(messageIDBeingRespondedTo)
        cmd.setAffectedSOPClassUID(affectedSOPClassUID)
        cmd.setStatus(status)
        cmd.setHasDataSet(hasDataSet)
        self.commandSet = cmd
        self.presentationContextID = presentationContextID
    }
    
    /// Creates a C-FIND response from an existing command set
    public init(commandSet: CommandSet, presentationContextID: UInt8) {
        self.commandSet = commandSet
        self.presentationContextID = presentationContextID
    }
}

// MARK: - C-MOVE Messages

/// C-MOVE Request
///
/// Request to move DICOM objects to a destination AE.
///
/// Reference: PS3.7 Section 9.1.4 - C-MOVE Service
public struct CMoveRequest: DIMSERequest, Hashable {
    public let commandSet: CommandSet
    public let presentationContextID: UInt8
    
    public var messageID: UInt16 {
        commandSet.messageID ?? 0
    }
    
    public var affectedSOPClassUID: String {
        commandSet.affectedSOPClassUID ?? ""
    }
    
    public var priority: DIMSEPriority {
        commandSet.priority ?? .medium
    }
    
    public var moveDestination: String {
        commandSet.moveDestination ?? ""
    }
    
    /// Creates a C-MOVE request
    ///
    /// - Parameters:
    ///   - messageID: The message ID
    ///   - affectedSOPClassUID: The Query/Retrieve Information Model SOP Class UID
    ///   - moveDestination: The AE title to move objects to
    ///   - priority: The operation priority (default: medium)
    ///   - presentationContextID: The presentation context ID
    public init(
        messageID: UInt16,
        affectedSOPClassUID: String,
        moveDestination: String,
        priority: DIMSEPriority = .medium,
        presentationContextID: UInt8
    ) {
        var cmd = CommandSet()
        cmd.setCommand(.cMoveRequest)
        cmd.setMessageID(messageID)
        cmd.setAffectedSOPClassUID(affectedSOPClassUID)
        cmd.setMoveDestination(moveDestination)
        cmd.setPriority(priority)
        cmd.setHasDataSet(true)
        self.commandSet = cmd
        self.presentationContextID = presentationContextID
    }
    
    /// Creates a C-MOVE request from an existing command set
    public init(commandSet: CommandSet, presentationContextID: UInt8) {
        self.commandSet = commandSet
        self.presentationContextID = presentationContextID
    }
}

/// C-MOVE Response
///
/// Response to a C-MOVE request. May be sent multiple times (pending status)
/// with sub-operation counts until final response.
///
/// Reference: PS3.7 Section 9.1.4 - C-MOVE Service
public struct CMoveResponse: DIMSEResponse, Hashable {
    public let commandSet: CommandSet
    public let presentationContextID: UInt8
    
    public var messageIDBeingRespondedTo: UInt16 {
        commandSet.messageIDBeingRespondedTo ?? 0
    }
    
    public var status: DIMSEStatus {
        commandSet.status ?? .unknown(0xFFFF)
    }
    
    public var affectedSOPClassUID: String {
        commandSet.affectedSOPClassUID ?? ""
    }
    
    /// Number of remaining sub-operations
    public var numberOfRemainingSuboperations: UInt16? {
        commandSet.numberOfRemainingSuboperations
    }
    
    /// Number of completed sub-operations
    public var numberOfCompletedSuboperations: UInt16? {
        commandSet.numberOfCompletedSuboperations
    }
    
    /// Number of failed sub-operations
    public var numberOfFailedSuboperations: UInt16? {
        commandSet.numberOfFailedSuboperations
    }
    
    /// Number of warning sub-operations
    public var numberOfWarningSuboperations: UInt16? {
        commandSet.numberOfWarningSuboperations
    }
    
    /// Creates a C-MOVE response
    ///
    /// - Parameters:
    ///   - messageIDBeingRespondedTo: The message ID of the request
    ///   - affectedSOPClassUID: The SOP Class UID
    ///   - status: The response status
    ///   - remaining: Number of remaining sub-operations (optional)
    ///   - completed: Number of completed sub-operations (optional)
    ///   - failed: Number of failed sub-operations (optional)
    ///   - warning: Number of warning sub-operations (optional)
    ///   - presentationContextID: The presentation context ID
    public init(
        messageIDBeingRespondedTo: UInt16,
        affectedSOPClassUID: String,
        status: DIMSEStatus,
        remaining: UInt16? = nil,
        completed: UInt16? = nil,
        failed: UInt16? = nil,
        warning: UInt16? = nil,
        presentationContextID: UInt8
    ) {
        var cmd = CommandSet()
        cmd.setCommand(.cMoveResponse)
        cmd.setMessageIDBeingRespondedTo(messageIDBeingRespondedTo)
        cmd.setAffectedSOPClassUID(affectedSOPClassUID)
        cmd.setStatus(status)
        cmd.setHasDataSet(false)
        
        if let r = remaining { cmd.setNumberOfRemainingSuboperations(r) }
        if let c = completed { cmd.setNumberOfCompletedSuboperations(c) }
        if let f = failed { cmd.setNumberOfFailedSuboperations(f) }
        if let w = warning { cmd.setNumberOfWarningSuboperations(w) }
        
        self.commandSet = cmd
        self.presentationContextID = presentationContextID
    }
    
    /// Creates a C-MOVE response from an existing command set
    public init(commandSet: CommandSet, presentationContextID: UInt8) {
        self.commandSet = commandSet
        self.presentationContextID = presentationContextID
    }
}

// MARK: - C-GET Messages

/// C-GET Request
///
/// Request to retrieve DICOM objects on the same association.
///
/// Reference: PS3.7 Section 9.1.3 - C-GET Service
public struct CGetRequest: DIMSERequest, Hashable {
    public let commandSet: CommandSet
    public let presentationContextID: UInt8
    
    public var messageID: UInt16 {
        commandSet.messageID ?? 0
    }
    
    public var affectedSOPClassUID: String {
        commandSet.affectedSOPClassUID ?? ""
    }
    
    public var priority: DIMSEPriority {
        commandSet.priority ?? .medium
    }
    
    /// Creates a C-GET request
    ///
    /// - Parameters:
    ///   - messageID: The message ID
    ///   - affectedSOPClassUID: The Query/Retrieve Information Model SOP Class UID
    ///   - priority: The operation priority (default: medium)
    ///   - presentationContextID: The presentation context ID
    public init(
        messageID: UInt16,
        affectedSOPClassUID: String,
        priority: DIMSEPriority = .medium,
        presentationContextID: UInt8
    ) {
        var cmd = CommandSet()
        cmd.setCommand(.cGetRequest)
        cmd.setMessageID(messageID)
        cmd.setAffectedSOPClassUID(affectedSOPClassUID)
        cmd.setPriority(priority)
        cmd.setHasDataSet(true)
        self.commandSet = cmd
        self.presentationContextID = presentationContextID
    }
    
    /// Creates a C-GET request from an existing command set
    public init(commandSet: CommandSet, presentationContextID: UInt8) {
        self.commandSet = commandSet
        self.presentationContextID = presentationContextID
    }
}

/// C-GET Response
///
/// Response to a C-GET request. May be sent multiple times (pending status)
/// with sub-operation counts until final response.
///
/// Reference: PS3.7 Section 9.1.3 - C-GET Service
public struct CGetResponse: DIMSEResponse, Hashable {
    public let commandSet: CommandSet
    public let presentationContextID: UInt8
    
    public var messageIDBeingRespondedTo: UInt16 {
        commandSet.messageIDBeingRespondedTo ?? 0
    }
    
    public var status: DIMSEStatus {
        commandSet.status ?? .unknown(0xFFFF)
    }
    
    public var affectedSOPClassUID: String {
        commandSet.affectedSOPClassUID ?? ""
    }
    
    /// Number of remaining sub-operations
    public var numberOfRemainingSuboperations: UInt16? {
        commandSet.numberOfRemainingSuboperations
    }
    
    /// Number of completed sub-operations
    public var numberOfCompletedSuboperations: UInt16? {
        commandSet.numberOfCompletedSuboperations
    }
    
    /// Number of failed sub-operations
    public var numberOfFailedSuboperations: UInt16? {
        commandSet.numberOfFailedSuboperations
    }
    
    /// Number of warning sub-operations
    public var numberOfWarningSuboperations: UInt16? {
        commandSet.numberOfWarningSuboperations
    }
    
    /// Creates a C-GET response
    ///
    /// - Parameters:
    ///   - messageIDBeingRespondedTo: The message ID of the request
    ///   - affectedSOPClassUID: The SOP Class UID
    ///   - status: The response status
    ///   - remaining: Number of remaining sub-operations (optional)
    ///   - completed: Number of completed sub-operations (optional)
    ///   - failed: Number of failed sub-operations (optional)
    ///   - warning: Number of warning sub-operations (optional)
    ///   - presentationContextID: The presentation context ID
    public init(
        messageIDBeingRespondedTo: UInt16,
        affectedSOPClassUID: String,
        status: DIMSEStatus,
        remaining: UInt16? = nil,
        completed: UInt16? = nil,
        failed: UInt16? = nil,
        warning: UInt16? = nil,
        presentationContextID: UInt8
    ) {
        var cmd = CommandSet()
        cmd.setCommand(.cGetResponse)
        cmd.setMessageIDBeingRespondedTo(messageIDBeingRespondedTo)
        cmd.setAffectedSOPClassUID(affectedSOPClassUID)
        cmd.setStatus(status)
        cmd.setHasDataSet(false)
        
        if let r = remaining { cmd.setNumberOfRemainingSuboperations(r) }
        if let c = completed { cmd.setNumberOfCompletedSuboperations(c) }
        if let f = failed { cmd.setNumberOfFailedSuboperations(f) }
        if let w = warning { cmd.setNumberOfWarningSuboperations(w) }
        
        self.commandSet = cmd
        self.presentationContextID = presentationContextID
    }
    
    /// Creates a C-GET response from an existing command set
    public init(commandSet: CommandSet, presentationContextID: UInt8) {
        self.commandSet = commandSet
        self.presentationContextID = presentationContextID
    }
}

// MARK: - C-CANCEL Message

/// C-CANCEL Request
///
/// Request to cancel an outstanding operation (C-FIND, C-MOVE, C-GET).
///
/// Reference: PS3.7 Section 9.3.2.3 - C-CANCEL Service
public struct CCancelRequest: DIMSERequest, Hashable {
    public let commandSet: CommandSet
    public let presentationContextID: UInt8
    
    public var messageID: UInt16 {
        commandSet.messageID ?? 0
    }
    
    public var messageIDBeingCancelled: UInt16 {
        commandSet.messageIDBeingRespondedTo ?? 0
    }
    
    /// Creates a C-CANCEL request
    ///
    /// - Parameters:
    ///   - messageIDBeingCancelled: The message ID of the operation to cancel
    ///   - presentationContextID: The presentation context ID
    public init(
        messageIDBeingCancelled: UInt16,
        presentationContextID: UInt8
    ) {
        var cmd = CommandSet()
        cmd.setCommand(.cCancelRequest)
        cmd.setMessageIDBeingRespondedTo(messageIDBeingCancelled)
        cmd.setHasDataSet(false)
        self.commandSet = cmd
        self.presentationContextID = presentationContextID
    }
    
    /// Creates a C-CANCEL request from an existing command set
    public init(commandSet: CommandSet, presentationContextID: UInt8) {
        self.commandSet = commandSet
        self.presentationContextID = presentationContextID
    }
}

// MARK: - N-ACTION Messages

/// N-ACTION Request
///
/// Request to perform an action on a managed SOP Instance.
/// Used for Storage Commitment and other normalized services.
///
/// Reference: PS3.7 Section 10.1 - N-ACTION Service
public struct NActionRequest: DIMSERequest, Hashable {
    public let commandSet: CommandSet
    public let presentationContextID: UInt8
    
    public var messageID: UInt16 {
        commandSet.messageID ?? 0
    }
    
    public var requestedSOPClassUID: String {
        commandSet.requestedSOPClassUID ?? ""
    }
    
    public var requestedSOPInstanceUID: String {
        commandSet.requestedSOPInstanceUID ?? ""
    }
    
    public var actionTypeID: UInt16 {
        commandSet.actionTypeID ?? 0
    }
    
    /// Creates an N-ACTION request
    ///
    /// - Parameters:
    ///   - messageID: The message ID (unique within association)
    ///   - requestedSOPClassUID: The SOP Class UID of the managed instance
    ///   - requestedSOPInstanceUID: The SOP Instance UID of the managed instance
    ///   - actionTypeID: The type of action to perform
    ///   - hasDataSet: Whether a data set follows (default: true)
    ///   - presentationContextID: The negotiated presentation context ID
    public init(
        messageID: UInt16,
        requestedSOPClassUID: String,
        requestedSOPInstanceUID: String,
        actionTypeID: UInt16,
        hasDataSet: Bool = true,
        presentationContextID: UInt8
    ) {
        var cmd = CommandSet()
        cmd.setCommand(.nActionRequest)
        cmd.setMessageID(messageID)
        cmd.setRequestedSOPClassUID(requestedSOPClassUID)
        cmd.setRequestedSOPInstanceUID(requestedSOPInstanceUID)
        cmd.setActionTypeID(actionTypeID)
        cmd.setHasDataSet(hasDataSet)
        self.commandSet = cmd
        self.presentationContextID = presentationContextID
    }
    
    /// Creates an N-ACTION request from an existing command set
    public init(commandSet: CommandSet, presentationContextID: UInt8) {
        self.commandSet = commandSet
        self.presentationContextID = presentationContextID
    }
}

/// N-ACTION Response
///
/// Response to an N-ACTION request.
///
/// Reference: PS3.7 Section 10.1 - N-ACTION Service
public struct NActionResponse: DIMSEResponse, Hashable {
    public let commandSet: CommandSet
    public let presentationContextID: UInt8
    
    public var messageIDBeingRespondedTo: UInt16 {
        commandSet.messageIDBeingRespondedTo ?? 0
    }
    
    public var status: DIMSEStatus {
        commandSet.status ?? .unknown(0xFFFF)
    }
    
    public var affectedSOPClassUID: String {
        commandSet.affectedSOPClassUID ?? ""
    }
    
    public var affectedSOPInstanceUID: String {
        commandSet.affectedSOPInstanceUID ?? ""
    }
    
    public var actionTypeID: UInt16? {
        commandSet.actionTypeID
    }
    
    /// Creates an N-ACTION response
    ///
    /// - Parameters:
    ///   - messageIDBeingRespondedTo: The message ID of the request
    ///   - affectedSOPClassUID: The SOP Class UID
    ///   - affectedSOPInstanceUID: The SOP Instance UID
    ///   - actionTypeID: The action type ID (optional in response)
    ///   - status: The response status (default: success)
    ///   - hasDataSet: Whether a data set follows (default: false)
    ///   - presentationContextID: The presentation context ID
    public init(
        messageIDBeingRespondedTo: UInt16,
        affectedSOPClassUID: String,
        affectedSOPInstanceUID: String,
        actionTypeID: UInt16? = nil,
        status: DIMSEStatus = .success,
        hasDataSet: Bool = false,
        presentationContextID: UInt8
    ) {
        var cmd = CommandSet()
        cmd.setCommand(.nActionResponse)
        cmd.setMessageIDBeingRespondedTo(messageIDBeingRespondedTo)
        cmd.setAffectedSOPClassUID(affectedSOPClassUID)
        cmd.setAffectedSOPInstanceUID(affectedSOPInstanceUID)
        if let actionTypeID = actionTypeID {
            cmd.setActionTypeID(actionTypeID)
        }
        cmd.setStatus(status)
        cmd.setHasDataSet(hasDataSet)
        self.commandSet = cmd
        self.presentationContextID = presentationContextID
    }
    
    /// Creates an N-ACTION response from an existing command set
    public init(commandSet: CommandSet, presentationContextID: UInt8) {
        self.commandSet = commandSet
        self.presentationContextID = presentationContextID
    }
}

// MARK: - N-EVENT-REPORT Messages

/// N-EVENT-REPORT Request
///
/// Request to report an event from a managed SOP Instance.
/// Used for Storage Commitment notifications and other event-based services.
///
/// Reference: PS3.7 Section 10.3 - N-EVENT-REPORT Service
public struct NEventReportRequest: DIMSERequest, Hashable {
    public let commandSet: CommandSet
    public let presentationContextID: UInt8
    
    public var messageID: UInt16 {
        commandSet.messageID ?? 0
    }
    
    public var affectedSOPClassUID: String {
        commandSet.affectedSOPClassUID ?? ""
    }
    
    public var affectedSOPInstanceUID: String {
        commandSet.affectedSOPInstanceUID ?? ""
    }
    
    public var eventTypeID: UInt16 {
        commandSet.eventTypeID ?? 0
    }
    
    /// Creates an N-EVENT-REPORT request
    ///
    /// - Parameters:
    ///   - messageID: The message ID (unique within association)
    ///   - affectedSOPClassUID: The SOP Class UID of the managed instance
    ///   - affectedSOPInstanceUID: The SOP Instance UID of the managed instance
    ///   - eventTypeID: The type of event being reported
    ///   - hasDataSet: Whether a data set follows (default: true)
    ///   - presentationContextID: The negotiated presentation context ID
    public init(
        messageID: UInt16,
        affectedSOPClassUID: String,
        affectedSOPInstanceUID: String,
        eventTypeID: UInt16,
        hasDataSet: Bool = true,
        presentationContextID: UInt8
    ) {
        var cmd = CommandSet()
        cmd.setCommand(.nEventReportRequest)
        cmd.setMessageID(messageID)
        cmd.setAffectedSOPClassUID(affectedSOPClassUID)
        cmd.setAffectedSOPInstanceUID(affectedSOPInstanceUID)
        cmd.setEventTypeID(eventTypeID)
        cmd.setHasDataSet(hasDataSet)
        self.commandSet = cmd
        self.presentationContextID = presentationContextID
    }
    
    /// Creates an N-EVENT-REPORT request from an existing command set
    public init(commandSet: CommandSet, presentationContextID: UInt8) {
        self.commandSet = commandSet
        self.presentationContextID = presentationContextID
    }
}

/// N-EVENT-REPORT Response
///
/// Response to an N-EVENT-REPORT request.
///
/// Reference: PS3.7 Section 10.3 - N-EVENT-REPORT Service
public struct NEventReportResponse: DIMSEResponse, Hashable {
    public let commandSet: CommandSet
    public let presentationContextID: UInt8
    
    public var messageIDBeingRespondedTo: UInt16 {
        commandSet.messageIDBeingRespondedTo ?? 0
    }
    
    public var status: DIMSEStatus {
        commandSet.status ?? .unknown(0xFFFF)
    }
    
    public var affectedSOPClassUID: String {
        commandSet.affectedSOPClassUID ?? ""
    }
    
    public var affectedSOPInstanceUID: String {
        commandSet.affectedSOPInstanceUID ?? ""
    }
    
    public var eventTypeID: UInt16? {
        commandSet.eventTypeID
    }
    
    /// Creates an N-EVENT-REPORT response
    ///
    /// - Parameters:
    ///   - messageIDBeingRespondedTo: The message ID of the request
    ///   - affectedSOPClassUID: The SOP Class UID
    ///   - affectedSOPInstanceUID: The SOP Instance UID
    ///   - eventTypeID: The event type ID (optional in response)
    ///   - status: The response status (default: success)
    ///   - hasDataSet: Whether a data set follows (default: false)
    ///   - presentationContextID: The presentation context ID
    public init(
        messageIDBeingRespondedTo: UInt16,
        affectedSOPClassUID: String,
        affectedSOPInstanceUID: String,
        eventTypeID: UInt16? = nil,
        status: DIMSEStatus = .success,
        hasDataSet: Bool = false,
        presentationContextID: UInt8
    ) {
        var cmd = CommandSet()
        cmd.setCommand(.nEventReportResponse)
        cmd.setMessageIDBeingRespondedTo(messageIDBeingRespondedTo)
        cmd.setAffectedSOPClassUID(affectedSOPClassUID)
        cmd.setAffectedSOPInstanceUID(affectedSOPInstanceUID)
        if let eventTypeID = eventTypeID {
            cmd.setEventTypeID(eventTypeID)
        }
        cmd.setStatus(status)
        cmd.setHasDataSet(hasDataSet)
        self.commandSet = cmd
        self.presentationContextID = presentationContextID
    }
    
    /// Creates an N-EVENT-REPORT response from an existing command set
    public init(commandSet: CommandSet, presentationContextID: UInt8) {
        self.commandSet = commandSet
        self.presentationContextID = presentationContextID
    }
}
