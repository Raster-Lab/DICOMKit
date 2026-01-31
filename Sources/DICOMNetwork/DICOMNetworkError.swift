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
