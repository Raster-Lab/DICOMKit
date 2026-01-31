import Foundation

/// Protocol for all DICOM Protocol Data Units (PDUs)
///
/// Reference: PS3.8 Section 9 - Protocol Data Units
public protocol PDU: Sendable {
    /// The PDU type code
    var pduType: PDUType { get }
    
    /// Encodes the PDU to binary data for network transmission
    func encode() throws -> Data
}

/// Default maximum PDU size (16KB)
///
/// Reference: PS3.8 Section 9.3.1
public let defaultMaxPDUSize: UInt32 = 16384

/// Minimum PDU size
public let minimumPDUSize: UInt32 = 4096

/// Maximum PDU size limit
public let maximumPDUSize: UInt32 = 0xFFFFFFFF
