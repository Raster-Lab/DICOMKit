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

/// Default maximum PDU size (64KB)
///
/// A larger PDU size improves throughput for bulk transfers (C-FIND,
/// C-STORE, etc.) and avoids interoperability issues with servers that
/// send larger responses.  64 KB is widely supported by contemporary
/// DICOM implementations.
///
/// Reference: PS3.8 Section 9.3.1
public let defaultMaxPDUSize: UInt32 = 65536

/// Minimum PDU size
public let minimumPDUSize: UInt32 = 4096

/// Maximum PDU size limit
public let maximumPDUSize: UInt32 = 0xFFFFFFFF
