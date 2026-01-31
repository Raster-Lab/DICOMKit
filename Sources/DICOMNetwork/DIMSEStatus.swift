import Foundation

/// DIMSE Status Codes
///
/// Status codes returned in DIMSE response messages indicating the result of an operation.
///
/// Reference: PS3.7 Annex C - Status Type Encoding
public enum DIMSEStatus: Sendable, Hashable {
    // MARK: - General Status Categories
    
    /// Operation completed successfully (0x0000)
    case success
    
    /// Pending - More matches/results to follow (0xFF00, 0xFF01)
    case pending(warningOptionalKeys: Bool)
    
    /// Cancel - Operation was cancelled (0xFE00)
    case cancel
    
    // MARK: - Failure Status
    
    /// Refused - Out of resources (0xA700)
    case refusedOutOfResources
    
    /// Refused - SOP Class not supported (0x0122)
    case refusedSOPClassNotSupported
    
    /// Error - Identifier/Data does not match SOP Class (0xA900)
    /// Used for both "identifier does not match" and "data set does not match" conditions
    case errorIdentifierDoesNotMatchSOPClass
    
    /// Error - Cannot understand (0xC000-0xCFFF)
    case errorCannotUnderstand(UInt16)
    
    /// Failed - Unable to process (0x0110)
    case failedUnableToProcess
    
    /// Failed - Duplicate SOP Instance (0x0111)
    case failedDuplicateSOPInstance
    
    /// Failed - No such SOP Class (0x0118)
    case failedNoSuchSOPClass
    
    /// Failed - No such SOP Instance (0x0112)
    case failedNoSuchSOPInstance
    
    /// Failed - Resource limitation (0x0213)
    case failedResourceLimitation
    
    /// Failed - Out of resources (0xA701, 0xA702)
    case failedOutOfResources(UInt16)
    
    /// Failed - Move destination unknown (0xA801)
    case failedMoveDestinationUnknown
    
    // MARK: - Warning Status
    
    /// Warning - Coercion of data elements or sub-operations complete with warnings (0xB000)
    /// Used for both coercion warnings and C-GET/C-MOVE sub-operation warnings
    case warningCoercionOfDataElements
    
    /// Warning - Data set does not match SOP Class (0xB007)
    case warningDataSetDoesNotMatchSOPClass
    
    /// Warning - Elements discarded (0xB006)
    case warningElementsDiscarded
    
    // MARK: - Other/Unknown
    
    /// Unknown or unmapped status code
    case unknown(UInt16)
    
    /// The raw 16-bit status code value
    public var rawValue: UInt16 {
        switch self {
        case .success:
            return 0x0000
        case .pending(let warningOptionalKeys):
            return warningOptionalKeys ? 0xFF01 : 0xFF00
        case .cancel:
            return 0xFE00
        case .refusedOutOfResources:
            return 0xA700
        case .refusedSOPClassNotSupported:
            return 0x0122
        case .errorIdentifierDoesNotMatchSOPClass:
            return 0xA900
        case .errorCannotUnderstand(let code):
            return code
        case .failedUnableToProcess:
            return 0x0110
        case .failedDuplicateSOPInstance:
            return 0x0111
        case .failedNoSuchSOPClass:
            return 0x0118
        case .failedNoSuchSOPInstance:
            return 0x0112
        case .failedResourceLimitation:
            return 0x0213
        case .failedOutOfResources(let code):
            return code
        case .failedMoveDestinationUnknown:
            return 0xA801
        case .warningCoercionOfDataElements:
            return 0xB000
        case .warningDataSetDoesNotMatchSOPClass:
            return 0xB007
        case .warningElementsDiscarded:
            return 0xB006
        case .unknown(let code):
            return code
        }
    }
    
    /// Creates a DIMSEStatus from a raw status code value
    ///
    /// - Parameter rawValue: The 16-bit status code
    /// - Returns: The corresponding DIMSEStatus
    public static func from(_ rawValue: UInt16) -> DIMSEStatus {
        switch rawValue {
        case 0x0000:
            return .success
        case 0xFF00:
            return .pending(warningOptionalKeys: false)
        case 0xFF01:
            return .pending(warningOptionalKeys: true)
        case 0xFE00:
            return .cancel
        case 0x0110:
            return .failedUnableToProcess
        case 0x0111:
            return .failedDuplicateSOPInstance
        case 0x0112:
            return .failedNoSuchSOPInstance
        case 0x0118:
            return .failedNoSuchSOPClass
        case 0x0122:
            return .refusedSOPClassNotSupported
        case 0x0213:
            return .failedResourceLimitation
        case 0xA700:
            return .refusedOutOfResources
        case 0xA701, 0xA702:
            return .failedOutOfResources(rawValue)
        case 0xA801:
            return .failedMoveDestinationUnknown
        case 0xA900:
            return .errorIdentifierDoesNotMatchSOPClass
        case 0xB000:
            return .warningCoercionOfDataElements
        case 0xB006:
            return .warningElementsDiscarded
        case 0xB007:
            return .warningDataSetDoesNotMatchSOPClass
        case 0xC000...0xCFFF:
            return .errorCannotUnderstand(rawValue)
        default:
            return .unknown(rawValue)
        }
    }
    
    /// Whether this is a success status
    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    /// Whether this is a pending status (more results to follow)
    public var isPending: Bool {
        if case .pending = self { return true }
        return false
    }
    
    /// Whether this is a failure status
    public var isFailure: Bool {
        switch self {
        case .refusedOutOfResources, .refusedSOPClassNotSupported,
             .errorIdentifierDoesNotMatchSOPClass, .errorCannotUnderstand,
             .failedUnableToProcess, .failedDuplicateSOPInstance,
             .failedNoSuchSOPClass, .failedNoSuchSOPInstance,
             .failedResourceLimitation, .failedOutOfResources,
             .failedMoveDestinationUnknown:
            return true
        case .unknown(let code):
            // Status codes 0x0001-0x00FF and 0xA000-0xAFFF are failures
            return (code >= 0x0001 && code <= 0x00FF) || (code >= 0xA000 && code <= 0xAFFF)
        default:
            return false
        }
    }
    
    /// Whether this is a warning status
    public var isWarning: Bool {
        switch self {
        case .warningCoercionOfDataElements, .warningDataSetDoesNotMatchSOPClass,
             .warningElementsDiscarded:
            return true
        case .unknown(let code):
            // Status codes 0xB000-0xBFFF are warnings
            return code >= 0xB000 && code <= 0xBFFF
        default:
            return false
        }
    }
    
    /// Whether this is a cancel status
    public var isCancel: Bool {
        if case .cancel = self { return true }
        return false
    }
    
    /// Whether this status indicates the operation is complete (not pending)
    public var isFinal: Bool {
        !isPending
    }
}

// MARK: - CustomStringConvertible
extension DIMSEStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .success:
            return "Success (0x0000)"
        case .pending(let warningOptionalKeys):
            let code = warningOptionalKeys ? "0xFF01" : "0xFF00"
            return "Pending (\(code))"
        case .cancel:
            return "Cancel (0xFE00)"
        case .refusedOutOfResources:
            return "Refused: Out of resources (0xA700)"
        case .refusedSOPClassNotSupported:
            return "Refused: SOP Class not supported (0x0122)"
        case .errorIdentifierDoesNotMatchSOPClass:
            return "Error: Identifier/Data does not match SOP Class (0xA900)"
        case .errorCannotUnderstand(let code):
            return "Error: Cannot understand (0x\(String(format: "%04X", code)))"
        case .failedUnableToProcess:
            return "Failed: Unable to process (0x0110)"
        case .failedDuplicateSOPInstance:
            return "Failed: Duplicate SOP Instance (0x0111)"
        case .failedNoSuchSOPClass:
            return "Failed: No such SOP Class (0x0118)"
        case .failedNoSuchSOPInstance:
            return "Failed: No such SOP Instance (0x0112)"
        case .failedResourceLimitation:
            return "Failed: Resource limitation (0x0213)"
        case .failedOutOfResources(let code):
            return "Failed: Out of resources (0x\(String(format: "%04X", code)))"
        case .failedMoveDestinationUnknown:
            return "Failed: Move destination unknown (0xA801)"
        case .warningCoercionOfDataElements:
            return "Warning: Coercion of data elements (0xB000)"
        case .warningDataSetDoesNotMatchSOPClass:
            return "Warning: Data set does not match SOP Class (0xB007)"
        case .warningElementsDiscarded:
            return "Warning: Elements discarded (0xB006)"
        case .unknown(let code):
            return "Unknown status (0x\(String(format: "%04X", code)))"
        }
    }
}
