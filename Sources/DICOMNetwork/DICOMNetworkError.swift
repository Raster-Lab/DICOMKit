import Foundation

// MARK: - Error Category

/// Category classification for DICOM network errors
///
/// Error categories help determine the appropriate response to network failures:
/// - **transient**: Temporary failures that may succeed on retry (network hiccups, server busy)
/// - **permanent**: Failures that won't succeed on retry without intervention (invalid credentials, unsupported features)
/// - **configuration**: Errors due to misconfigured client or server settings
/// - **protocol**: Errors in DICOM protocol handling or unexpected peer behavior
/// - **timeout**: Time-based failures (connection or operation timeouts)
/// - **resource**: Resource availability issues (rate limiting, circuit breaker)
///
/// Reference: DICOM PS3.8 - Network Communication Support
public enum ErrorCategory: String, Sendable, Hashable, CaseIterable {
    /// Transient error that may succeed on retry
    ///
    /// Examples: Network hiccup, server temporarily unavailable, connection reset
    case transient
    
    /// Permanent error that will not succeed on retry without intervention
    ///
    /// Examples: Invalid AE title, SOP class not supported, authentication failure
    case permanent
    
    /// Configuration error requiring settings change
    ///
    /// Examples: Invalid PDU size, incorrect port, wrong AE title format
    case configuration
    
    /// Protocol error indicating unexpected DICOM communication behavior
    ///
    /// Examples: Invalid PDU format, unexpected PDU type, encoding/decoding failures
    case `protocol`
    
    /// Timeout error when operation exceeded time limits
    ///
    /// Examples: Connection timeout, operation timeout, ARTIM timer expired
    case timeout
    
    /// Resource error due to rate limiting or protection mechanisms
    ///
    /// Examples: Circuit breaker open, too many concurrent connections
    case resource
}

extension ErrorCategory: CustomStringConvertible {
    public var description: String {
        switch self {
        case .transient:
            return "Transient"
        case .permanent:
            return "Permanent"
        case .configuration:
            return "Configuration"
        case .protocol:
            return "Protocol"
        case .timeout:
            return "Timeout"
        case .resource:
            return "Resource"
        }
    }
}

// MARK: - Recovery Suggestion

/// Suggested recovery actions for DICOM network errors
///
/// Recovery suggestions provide actionable guidance for handling errors:
/// - **retry**: Simple retry may succeed (with exponential backoff)
/// - **retryWithBackoff**: Retry after a delay with increasing intervals
/// - **checkConfiguration**: Review client/server configuration settings
/// - **contactAdministrator**: Escalate to system administrator
/// - **waitAndRetry**: Wait for external condition to change (circuit breaker, rate limit)
/// - **useAlternateServer**: Try a different PACS server if available
/// - **noRecovery**: Error cannot be recovered programmatically
public enum RecoverySuggestion: Sendable, Hashable {
    /// Retry the operation immediately
    case retry
    
    /// Retry the operation after waiting with exponential backoff
    case retryWithBackoff(initialDelay: TimeInterval)
    
    /// Check and fix client or server configuration
    case checkConfiguration(details: String)
    
    /// Contact system administrator for assistance
    case contactAdministrator(reason: String)
    
    /// Wait for specified duration before retrying
    case waitAndRetry(duration: TimeInterval)
    
    /// Try an alternate server or endpoint
    case useAlternateServer
    
    /// No automatic recovery possible
    case noRecovery(reason: String)
}

extension RecoverySuggestion: CustomStringConvertible {
    public var description: String {
        switch self {
        case .retry:
            return "Retry the operation"
        case .retryWithBackoff(let delay):
            return "Retry with exponential backoff starting at \(delay)s"
        case .checkConfiguration(let details):
            return "Check configuration: \(details)"
        case .contactAdministrator(let reason):
            return "Contact administrator: \(reason)"
        case .waitAndRetry(let duration):
            return "Wait \(Int(duration))s and retry"
        case .useAlternateServer:
            return "Try an alternate server"
        case .noRecovery(let reason):
            return "No recovery possible: \(reason)"
        }
    }
}

// MARK: - Timeout Configuration

/// Configuration for different types of network timeouts
///
/// Allows fine-grained control over timeout behavior for different phases
/// of DICOM network operations.
///
/// ## Timeout Types
///
/// - **connect**: Time allowed to establish TCP connection
/// - **read**: Time allowed for reading data from the network
/// - **write**: Time allowed for writing data to the network
/// - **operation**: Total time allowed for completing a DICOM operation (e.g., C-FIND, C-STORE)
/// - **association**: Time allowed for ARTIM (Association Request/Release Timer)
///
/// ## Usage
///
/// ```swift
/// // Default configuration
/// let defaults = TimeoutConfiguration.default
///
/// // Fast local network
/// let fast = TimeoutConfiguration(
///     connect: 5,
///     read: 10,
///     write: 10,
///     operation: 60,
///     association: 15
/// )
///
/// // Slow WAN connection
/// let slow = TimeoutConfiguration(
///     connect: 30,
///     read: 60,
///     write: 60,
///     operation: 300,
///     association: 45
/// )
/// ```
///
/// Reference: PS3.8 Section 9.1.1 - ARTIM Timer
public struct TimeoutConfiguration: Sendable, Hashable {
    /// Time allowed to establish TCP connection (in seconds)
    public let connect: TimeInterval
    
    /// Time allowed for reading data from the network (in seconds)
    public let read: TimeInterval
    
    /// Time allowed for writing data to the network (in seconds)
    public let write: TimeInterval
    
    /// Total time allowed for completing a DICOM operation (in seconds)
    ///
    /// This covers the entire duration of an operation like C-FIND or C-STORE,
    /// including multiple PDU exchanges.
    public let operation: TimeInterval
    
    /// Time allowed for ARTIM timer - association establishment/release (in seconds)
    ///
    /// Reference: PS3.8 Section 9.1.1 - ARTIM Timer
    public let association: TimeInterval
    
    /// Creates a timeout configuration with specified values
    ///
    /// - Parameters:
    ///   - connect: Connection timeout in seconds (default: 30)
    ///   - read: Read timeout in seconds (default: 30)
    ///   - write: Write timeout in seconds (default: 30)
    ///   - operation: Operation timeout in seconds (default: 120)
    ///   - association: Association/ARTIM timeout in seconds (default: 30)
    public init(
        connect: TimeInterval = 30,
        read: TimeInterval = 30,
        write: TimeInterval = 30,
        operation: TimeInterval = 120,
        association: TimeInterval = 30
    ) {
        self.connect = connect
        self.read = read
        self.write = write
        self.operation = operation
        self.association = association
    }
    
    /// Default timeout configuration suitable for most networks
    ///
    /// - connect: 30 seconds
    /// - read: 30 seconds
    /// - write: 30 seconds
    /// - operation: 120 seconds
    /// - association: 30 seconds
    public static let `default` = TimeoutConfiguration()
    
    /// Fast timeout configuration for local networks or testing
    ///
    /// - connect: 5 seconds
    /// - read: 10 seconds
    /// - write: 10 seconds
    /// - operation: 30 seconds
    /// - association: 10 seconds
    public static let fast = TimeoutConfiguration(
        connect: 5,
        read: 10,
        write: 10,
        operation: 30,
        association: 10
    )
    
    /// Slow timeout configuration for WAN or high-latency connections
    ///
    /// - connect: 60 seconds
    /// - read: 120 seconds
    /// - write: 120 seconds
    /// - operation: 600 seconds
    /// - association: 90 seconds
    public static let slow = TimeoutConfiguration(
        connect: 60,
        read: 120,
        write: 120,
        operation: 600,
        association: 90
    )
}

extension TimeoutConfiguration: CustomStringConvertible {
    public var description: String {
        "TimeoutConfiguration(connect: \(connect)s, read: \(read)s, write: \(write)s, operation: \(operation)s, association: \(association)s)"
    }
}

// MARK: - Timeout Type

/// Type of timeout that occurred
///
/// Used to provide specific information about which phase of an operation timed out.
public enum TimeoutType: String, Sendable, Hashable, CaseIterable {
    /// Connection establishment timed out
    case connect
    
    /// Reading from network timed out
    case read
    
    /// Writing to network timed out
    case write
    
    /// Overall operation timed out
    case operation
    
    /// Association (ARTIM timer) timed out
    case association
}

extension TimeoutType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .connect:
            return "Connection"
        case .read:
            return "Read"
        case .write:
            return "Write"
        case .operation:
            return "Operation"
        case .association:
            return "Association"
        }
    }
}

// MARK: - DICOM Network Error

/// Errors that can occur during DICOM network operations
///
/// Reference: DICOM PS3.8 - Network Communication Support
public enum DICOMNetworkError: Error, Sendable {
    /// Connection to remote host failed
    case connectionFailed(String)
    
    /// Connection timed out
    case timeout
    
    /// Invalid PDU received
    case invalidPDU(String)
    
    /// PDU too large for buffer
    case pduTooLarge(received: UInt32, maximum: UInt32)
    
    /// Unexpected PDU type received
    case unexpectedPDUType(expected: PDUType, received: PDUType)
    
    /// Association was rejected by the remote peer
    ///
    /// - Parameters:
    ///   - result: The rejection result code
    ///   - source: The source of the rejection
    ///   - reason: The reason for rejection
    case associationRejected(result: AssociateRejectResult, source: AssociateRejectSource, reason: UInt8)
    
    /// Association was aborted
    ///
    /// - Parameters:
    ///   - source: The source of the abort
    ///   - reason: The reason for abort
    case associationAborted(source: AbortSource, reason: UInt8)
    
    /// No presentation context was accepted for the requested operation
    case noPresentationContextAccepted
    
    /// The requested SOP Class is not supported
    case sopClassNotSupported(String)
    
    /// Invalid Application Entity title
    ///
    /// AE titles must be 1-16 ASCII characters
    case invalidAETitle(String)
    
    /// Network connection was closed unexpectedly
    case connectionClosed
    
    /// Invalid protocol state for the requested operation
    case invalidState(String)
    
    /// Encoding error when serializing PDU
    case encodingFailed(String)
    
    /// Decoding error when deserializing PDU
    case decodingFailed(String)
    
    /// Query operation failed with a DIMSE status
    case queryFailed(DIMSEStatus)
    
    /// Retrieve operation failed with a DIMSE status
    case retrieveFailed(DIMSEStatus)
    
    /// ARTIM timer expired while waiting for association response
    ///
    /// The ARTIM (Association Request/Release Timer) fires when waiting
    /// for an A-ASSOCIATE-AC/RJ or A-RELEASE-RP response takes too long.
    ///
    /// Reference: PS3.8 Section 9.1.1 - ARTIM Timer
    case artimTimerExpired
    
    /// Circuit breaker is open for this server
    ///
    /// The server has failed repeatedly and the circuit breaker has tripped
    /// to prevent further requests. Wait for the reset timeout before retrying.
    ///
    /// - Parameters:
    ///   - host: The server host
    ///   - port: The server port
    ///   - retryAfter: When the circuit may allow requests again
    case circuitBreakerOpen(host: String, port: UInt16, retryAfter: Date)
    
    /// Detailed timeout with specific timeout type
    ///
    /// Provides more granular information about which phase of the operation timed out.
    ///
    /// - Parameters:
    ///   - type: The type of timeout that occurred
    ///   - duration: The timeout duration that was exceeded
    ///   - operation: Optional description of the operation that timed out
    case operationTimeout(type: TimeoutType, duration: TimeInterval, operation: String?)
    
    /// Store operation failed with a DIMSE status
    case storeFailed(DIMSEStatus)
    
    /// Partial operation failure
    ///
    /// Some operations succeeded while others failed. Used for batch operations.
    ///
    /// - Parameters:
    ///   - succeeded: Number of operations that succeeded
    ///   - failed: Number of operations that failed
    ///   - details: Optional details about the failures
    case partialFailure(succeeded: Int, failed: Int, details: String?)
}

// MARK: - CustomStringConvertible
extension DICOMNetworkError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .timeout:
            return "Connection timed out"
        case .invalidPDU(let message):
            return "Invalid PDU: \(message)"
        case .pduTooLarge(let received, let maximum):
            return "PDU too large: received \(received) bytes, maximum is \(maximum) bytes"
        case .unexpectedPDUType(let expected, let received):
            return "Unexpected PDU type: expected \(expected), received \(received)"
        case .associationRejected(let result, let source, let reason):
            return "Association rejected: result=\(result), source=\(source), reason=\(reason)"
        case .associationAborted(let source, let reason):
            return "Association aborted: source=\(source), reason=\(reason)"
        case .noPresentationContextAccepted:
            return "No presentation context was accepted"
        case .sopClassNotSupported(let uid):
            return "SOP Class not supported: \(uid)"
        case .invalidAETitle(let ae):
            return "Invalid AE Title: '\(ae)'"
        case .connectionClosed:
            return "Connection was closed unexpectedly"
        case .invalidState(let message):
            return "Invalid protocol state: \(message)"
        case .encodingFailed(let message):
            return "Encoding failed: \(message)"
        case .decodingFailed(let message):
            return "Decoding failed: \(message)"
        case .queryFailed(let status):
            return "Query failed: \(status)"
        case .retrieveFailed(let status):
            return "Retrieve failed: \(status)"
        case .artimTimerExpired:
            return "ARTIM timer expired: remote peer did not respond in time"
        case .circuitBreakerOpen(let host, let port, let retryAfter):
            let retryInSeconds = max(0, Int(retryAfter.timeIntervalSinceNow))
            return "Circuit breaker open for \(host):\(port). Retry in \(retryInSeconds) seconds."
        case .operationTimeout(let type, let duration, let operation):
            if let op = operation {
                return "\(type) timeout after \(Int(duration))s during \(op)"
            }
            return "\(type) timeout after \(Int(duration))s"
        case .storeFailed(let status):
            return "Store failed: \(status)"
        case .partialFailure(let succeeded, let failed, let details):
            var message = "Partial failure: \(succeeded) succeeded, \(failed) failed"
            if let details = details {
                message += ". \(details)"
            }
            return message
        }
    }
}

// MARK: - Error Helpers

extension DICOMNetworkError {
    /// Returns true if this error is an ARTIM timer expiration
    public var isARTIMExpired: Bool {
        if case .artimTimerExpired = self {
            return true
        }
        return false
    }
    
    /// The category of this error
    ///
    /// Use this to determine the general class of error and make decisions
    /// about retry strategies and user notifications.
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     try await client.verify()
    /// } catch let error as DICOMNetworkError {
    ///     switch error.category {
    ///     case .transient:
    ///         // Retry with exponential backoff
    ///         break
    ///     case .configuration:
    ///         // Display configuration error to user
    ///         break
    ///     case .timeout:
    ///         // Offer to increase timeout or retry
    ///         break
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    public var category: ErrorCategory {
        switch self {
        case .connectionFailed:
            return .transient
        case .timeout:
            return .timeout
        case .invalidPDU:
            return .protocol
        case .pduTooLarge:
            return .configuration
        case .unexpectedPDUType:
            return .protocol
        case .associationRejected(let result, _, _):
            return result == .rejectedTransient ? .transient : .permanent
        case .associationAborted:
            return .transient
        case .noPresentationContextAccepted:
            return .configuration
        case .sopClassNotSupported:
            return .permanent
        case .invalidAETitle:
            return .configuration
        case .connectionClosed:
            return .transient
        case .invalidState:
            return .protocol
        case .encodingFailed:
            return .protocol
        case .decodingFailed:
            return .protocol
        case .queryFailed:
            return .permanent
        case .retrieveFailed:
            return .permanent
        case .artimTimerExpired:
            return .timeout
        case .circuitBreakerOpen:
            return .resource
        case .operationTimeout:
            return .timeout
        case .storeFailed:
            return .permanent
        case .partialFailure:
            return .transient
        }
    }
    
    /// Whether this error is potentially recoverable through retry
    ///
    /// Returns `true` if retrying the operation might succeed.
    /// For transient errors, retrying with exponential backoff is recommended.
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     try await client.verify()
    /// } catch let error as DICOMNetworkError where error.isRetryable {
    ///     // Retry with exponential backoff
    ///     try await Task.sleep(for: .seconds(1))
    ///     try await client.verify()
    /// }
    /// ```
    public var isRetryable: Bool {
        switch self {
        case .connectionFailed,
             .timeout,
             .connectionClosed,
             .artimTimerExpired,
             .partialFailure:
            return true
        case .associationRejected(let result, _, _):
            return result == .rejectedTransient
        case .associationAborted:
            return true
        case .circuitBreakerOpen:
            return true // After waiting
        case .operationTimeout:
            return true
        case .invalidPDU,
             .pduTooLarge,
             .unexpectedPDUType,
             .noPresentationContextAccepted,
             .sopClassNotSupported,
             .invalidAETitle,
             .invalidState,
             .encodingFailed,
             .decodingFailed,
             .queryFailed,
             .retrieveFailed,
             .storeFailed:
            return false
        }
    }
    
    /// Recovery suggestion for this error
    ///
    /// Provides actionable guidance for handling the error, including
    /// whether to retry, check configuration, or escalate to an administrator.
    ///
    /// ## Example
    ///
    /// ```swift
    /// do {
    ///     try await client.verify()
    /// } catch let error as DICOMNetworkError {
    ///     print("Error: \(error.description)")
    ///     print("Suggestion: \(error.recoverySuggestion)")
    /// }
    /// ```
    public var recoverySuggestion: RecoverySuggestion {
        switch self {
        case .connectionFailed:
            return .retryWithBackoff(initialDelay: 1.0)
        case .timeout:
            return .retryWithBackoff(initialDelay: 2.0)
        case .invalidPDU(let message):
            return .checkConfiguration(details: "Invalid PDU received: \(message). Check protocol compatibility.")
        case .pduTooLarge(let received, let maximum):
            return .checkConfiguration(details: "Increase maxPDUSize (currently \(maximum) bytes) or configure remote to send smaller PDUs (received \(received) bytes)")
        case .unexpectedPDUType:
            return .checkConfiguration(details: "Unexpected PDU type. Check protocol version compatibility.")
        case .associationRejected(let result, let source, _):
            if result == .rejectedTransient {
                return .retryWithBackoff(initialDelay: 5.0)
            }
            return .checkConfiguration(details: "Association rejected by \(source). Verify AE titles and presentation contexts.")
        case .associationAborted:
            return .retryWithBackoff(initialDelay: 1.0)
        case .noPresentationContextAccepted:
            return .checkConfiguration(details: "No presentation context accepted. Verify SOP classes and transfer syntaxes are supported by the remote peer.")
        case .sopClassNotSupported(let uid):
            return .noRecovery(reason: "SOP Class \(uid) is not supported by the remote peer")
        case .invalidAETitle(let ae):
            return .checkConfiguration(details: "AE Title '\(ae)' is invalid. Must be 1-16 ASCII characters.")
        case .connectionClosed:
            return .retry
        case .invalidState:
            return .checkConfiguration(details: "Operation attempted in invalid state. Reset connection and try again.")
        case .encodingFailed(let message):
            return .contactAdministrator(reason: "PDU encoding failed: \(message)")
        case .decodingFailed(let message):
            return .checkConfiguration(details: "PDU decoding failed: \(message). Check protocol compatibility.")
        case .queryFailed(let status):
            return .noRecovery(reason: "Query failed with status: \(status)")
        case .retrieveFailed(let status):
            return .noRecovery(reason: "Retrieve failed with status: \(status)")
        case .artimTimerExpired:
            return .retryWithBackoff(initialDelay: 5.0)
        case .circuitBreakerOpen(_, _, let retryAfter):
            let waitTime = max(1.0, retryAfter.timeIntervalSinceNow)
            return .waitAndRetry(duration: waitTime)
        case .operationTimeout(let type, let duration, _):
            switch type {
            case .connect:
                return .checkConfiguration(details: "Connection timeout (\(Int(duration))s). Check host/port or increase connect timeout.")
            case .read, .write:
                return .retryWithBackoff(initialDelay: 2.0)
            case .operation:
                return .checkConfiguration(details: "Operation timeout (\(Int(duration))s). Consider increasing operation timeout for large transfers.")
            case .association:
                return .retryWithBackoff(initialDelay: 5.0)
            }
        case .storeFailed(let status):
            return .noRecovery(reason: "Store failed with status: \(status)")
        case .partialFailure(_, let failed, _):
            if failed > 0 {
                return .retry
            }
            return .noRecovery(reason: "Partial operation completed with failures")
        }
    }
    
    /// Human-readable explanation of the error
    ///
    /// Provides a detailed, user-friendly explanation of what went wrong.
    public var explanation: String {
        switch self {
        case .connectionFailed(let message):
            return "Failed to establish a connection to the remote DICOM server. \(message)"
        case .timeout:
            return "The operation timed out waiting for a response from the remote server."
        case .invalidPDU(let message):
            return "Received an invalid Protocol Data Unit from the remote server. \(message)"
        case .pduTooLarge(let received, let maximum):
            return "The remote server sent a PDU (\(received) bytes) larger than the maximum allowed size (\(maximum) bytes)."
        case .unexpectedPDUType(let expected, let received):
            return "Expected \(expected) but received \(received). The remote server may be in an unexpected state."
        case .associationRejected(let result, let source, let reason):
            return "The remote server (\(source)) rejected the association request. Result: \(result), Reason code: \(reason)."
        case .associationAborted(let source, let reason):
            return "The association was aborted by \(source). Reason code: \(reason)."
        case .noPresentationContextAccepted:
            return "The remote server did not accept any of the proposed presentation contexts (SOP classes or transfer syntaxes)."
        case .sopClassNotSupported(let uid):
            return "The SOP Class (\(uid)) is not supported by the remote DICOM server."
        case .invalidAETitle(let ae):
            return "The Application Entity title '\(ae)' is not valid. AE titles must be 1-16 ASCII characters."
        case .connectionClosed:
            return "The network connection was closed unexpectedly by the remote server or due to a network issue."
        case .invalidState(let message):
            return "The operation cannot be performed in the current connection state. \(message)"
        case .encodingFailed(let message):
            return "Failed to encode the DICOM message for transmission. \(message)"
        case .decodingFailed(let message):
            return "Failed to decode the DICOM message received from the server. \(message)"
        case .queryFailed(let status):
            return "The query operation failed with DIMSE status: \(status)."
        case .retrieveFailed(let status):
            return "The retrieve operation failed with DIMSE status: \(status)."
        case .artimTimerExpired:
            return "The ARTIM (Association Request/Release Timer) expired. The remote server did not respond to the association request in time."
        case .circuitBreakerOpen(let host, let port, let retryAfter):
            let seconds = max(0, Int(retryAfter.timeIntervalSinceNow))
            return "The circuit breaker is open for \(host):\(port) due to repeated failures. Requests will be allowed again in \(seconds) seconds."
        case .operationTimeout(let type, let duration, let operation):
            var base = "\(type) timeout occurred after \(Int(duration)) seconds"
            if let op = operation {
                base += " during \(op)"
            }
            return base + "."
        case .storeFailed(let status):
            return "The store operation failed with DIMSE status: \(status)."
        case .partialFailure(let succeeded, let failed, let details):
            var base = "The operation partially completed: \(succeeded) items succeeded, \(failed) items failed"
            if let d = details {
                base += ". \(d)"
            }
            return base + "."
        }
    }
}

// MARK: - Association Reject Types

/// Result code for A-ASSOCIATE-RJ PDU
///
/// Reference: PS3.8 Section 9.3.4
public enum AssociateRejectResult: UInt8, Sendable, Hashable {
    /// Rejected permanent - no retry possible
    case rejectedPermanent = 1
    
    /// Rejected transient - retry may be possible
    case rejectedTransient = 2
}

extension AssociateRejectResult: CustomStringConvertible {
    public var description: String {
        switch self {
        case .rejectedPermanent:
            return "Rejected (Permanent)"
        case .rejectedTransient:
            return "Rejected (Transient)"
        }
    }
}

/// Source of A-ASSOCIATE-RJ PDU
///
/// Reference: PS3.8 Section 9.3.4
public enum AssociateRejectSource: UInt8, Sendable, Hashable {
    /// DICOM UL service-user
    case serviceUser = 1
    
    /// DICOM UL service-provider (ACSE related function)
    case serviceProviderACSE = 2
    
    /// DICOM UL service-provider (Presentation related function)
    case serviceProviderPresentation = 3
}

extension AssociateRejectSource: CustomStringConvertible {
    public var description: String {
        switch self {
        case .serviceUser:
            return "Service User"
        case .serviceProviderACSE:
            return "Service Provider (ACSE)"
        case .serviceProviderPresentation:
            return "Service Provider (Presentation)"
        }
    }
}

// MARK: - Abort Types

/// Source of A-ABORT PDU
///
/// Reference: PS3.8 Section 9.3.8
public enum AbortSource: UInt8, Sendable, Hashable {
    /// DICOM UL service-user initiated abort
    case serviceUser = 0
    
    /// DICOM UL service-provider initiated abort
    case serviceProvider = 2
}

extension AbortSource: CustomStringConvertible {
    public var description: String {
        switch self {
        case .serviceUser:
            return "Service User"
        case .serviceProvider:
            return "Service Provider"
        }
    }
}

/// Reason for service-provider initiated abort
///
/// Reference: PS3.8 Section 9.3.8
public enum AbortReason: UInt8, Sendable, Hashable {
    /// Reason not specified
    case notSpecified = 0
    
    /// Unrecognized PDU
    case unrecognizedPDU = 1
    
    /// Unexpected PDU
    case unexpectedPDU = 2
    
    /// Reserved
    case reserved = 3
    
    /// Unrecognized PDU parameter
    case unrecognizedPDUParameter = 4
    
    /// Unexpected PDU parameter
    case unexpectedPDUParameter = 5
    
    /// Invalid PDU parameter value
    case invalidPDUParameterValue = 6
}

extension AbortReason: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notSpecified:
            return "Reason not specified"
        case .unrecognizedPDU:
            return "Unrecognized PDU"
        case .unexpectedPDU:
            return "Unexpected PDU"
        case .reserved:
            return "Reserved"
        case .unrecognizedPDUParameter:
            return "Unrecognized PDU parameter"
        case .unexpectedPDUParameter:
            return "Unexpected PDU parameter"
        case .invalidPDUParameterValue:
            return "Invalid PDU parameter value"
        }
    }
}
