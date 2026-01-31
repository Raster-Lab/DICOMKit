/// DICOM Transfer Syntax
///
/// Defines the encoding rules for a DICOM data set, including byte ordering
/// and whether Value Representations (VR) are explicitly or implicitly encoded.
///
/// Reference: DICOM PS3.5 Section 10 - Transfer Syntax Specification
public struct TransferSyntax: Sendable, Hashable {
    /// Transfer Syntax UID
    public let uid: String
    
    /// Whether VR is explicitly encoded in data elements
    ///
    /// - Explicit VR: VR is encoded as 2 ASCII characters following the tag
    /// - Implicit VR: VR must be determined from the Data Element Dictionary
    ///
    /// Reference: PS3.5 Section 7.1
    public let isExplicitVR: Bool
    
    /// Byte ordering for multi-byte values
    ///
    /// Reference: PS3.5 Section 7.3
    public let byteOrder: ByteOrder
    
    /// Whether this transfer syntax uses encapsulated (compressed) pixel data
    ///
    /// Reference: PS3.5 Section A.4
    public let isEncapsulated: Bool
    
    /// Whether the data set is deflate compressed
    ///
    /// Reference: PS3.5 Section A.5
    public let isDeflated: Bool
    
    /// Creates a transfer syntax specification
    /// - Parameters:
    ///   - uid: Transfer Syntax UID
    ///   - isExplicitVR: Whether VR is explicitly encoded
    ///   - byteOrder: Byte ordering for multi-byte values
    ///   - isEncapsulated: Whether pixel data is encapsulated
    ///   - isDeflated: Whether data set uses deflate compression
    public init(uid: String, isExplicitVR: Bool, byteOrder: ByteOrder, isEncapsulated: Bool = false, isDeflated: Bool = false) {
        self.uid = uid
        self.isExplicitVR = isExplicitVR
        self.byteOrder = byteOrder
        self.isEncapsulated = isEncapsulated
        self.isDeflated = isDeflated
    }
}

// MARK: - Standard Transfer Syntaxes
extension TransferSyntax {
    /// Implicit VR Little Endian (1.2.840.10008.1.2)
    ///
    /// Default Transfer Syntax for DICOM.
    /// VR is not explicitly encoded and must be looked up from the Data Element Dictionary.
    ///
    /// Reference: PS3.5 Section A.1
    public static let implicitVRLittleEndian = TransferSyntax(
        uid: "1.2.840.10008.1.2",
        isExplicitVR: false,
        byteOrder: .littleEndian
    )
    
    /// Explicit VR Little Endian (1.2.840.10008.1.2.1)
    ///
    /// Most commonly used transfer syntax in modern DICOM implementations.
    /// VR is explicitly encoded as 2 ASCII characters following the tag.
    ///
    /// Reference: PS3.5 Section A.1
    public static let explicitVRLittleEndian = TransferSyntax(
        uid: "1.2.840.10008.1.2.1",
        isExplicitVR: true,
        byteOrder: .littleEndian
    )
    
    /// Deflated Explicit VR Little Endian (1.2.840.10008.1.2.1.99)
    ///
    /// Same encoding as Explicit VR Little Endian, but the Data Set is compressed
    /// using the Deflate algorithm (RFC 1951). The File Meta Information is not deflated.
    ///
    /// Reference: PS3.5 Section A.5
    public static let deflatedExplicitVRLittleEndian = TransferSyntax(
        uid: "1.2.840.10008.1.2.1.99",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isDeflated: true
    )
    
    /// Explicit VR Big Endian (1.2.840.10008.1.2.2) - Retired
    ///
    /// Retired in DICOM PS3.5 (2011). Included for compatibility with legacy files.
    /// VR is explicitly encoded, multi-byte values use big endian byte order.
    ///
    /// Reference: PS3.5 Section A.1
    public static let explicitVRBigEndian = TransferSyntax(
        uid: "1.2.840.10008.1.2.2",
        isExplicitVR: true,
        byteOrder: .bigEndian
    )
    
    // MARK: - JPEG Transfer Syntaxes
    
    /// JPEG Baseline (Process 1) (1.2.840.10008.1.2.4.50)
    ///
    /// Default Transfer Syntax for Lossy JPEG 8 Bit Image Compression.
    /// Uses lossy compression with 8-bit samples.
    ///
    /// Reference: PS3.5 Section A.4.1
    public static let jpegBaseline = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.50",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )
    
    /// JPEG Extended (Process 2 & 4) (1.2.840.10008.1.2.4.51)
    ///
    /// Default Transfer Syntax for Lossy JPEG 12 Bit Image Compression.
    /// Uses lossy compression with 8 or 12-bit samples.
    ///
    /// Reference: PS3.5 Section A.4.2
    public static let jpegExtended = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.51",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )
    
    /// JPEG Lossless, Non-Hierarchical (Process 14) (1.2.840.10008.1.2.4.57)
    ///
    /// Lossless JPEG compression.
    ///
    /// Reference: PS3.5 Section A.4.3
    public static let jpegLossless = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.57",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )
    
    /// JPEG Lossless, Non-Hierarchical, First-Order Prediction (Process 14, Selection Value 1) (1.2.840.10008.1.2.4.70)
    ///
    /// Default Transfer Syntax for Lossless JPEG Image Compression.
    /// Most commonly used lossless JPEG transfer syntax.
    ///
    /// Reference: PS3.5 Section A.4.3
    public static let jpegLosslessSV1 = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.70",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )
    
    // MARK: - JPEG 2000 Transfer Syntaxes
    
    /// JPEG 2000 Image Compression (Lossless Only) (1.2.840.10008.1.2.4.90)
    ///
    /// JPEG 2000 lossless image compression.
    ///
    /// Reference: PS3.5 Section A.4.4
    public static let jpeg2000Lossless = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.90",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )
    
    /// JPEG 2000 Image Compression (1.2.840.10008.1.2.4.91)
    ///
    /// JPEG 2000 lossy image compression.
    ///
    /// Reference: PS3.5 Section A.4.4
    public static let jpeg2000 = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.91",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )
    
    // MARK: - RLE Transfer Syntax
    
    /// RLE Lossless (1.2.840.10008.1.2.5)
    ///
    /// Run-length encoding lossless compression.
    ///
    /// Reference: PS3.5 Section A.4.2 and Annex G
    public static let rleLossless = TransferSyntax(
        uid: "1.2.840.10008.1.2.5",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )
    
    /// Creates a TransferSyntax from a UID string
    ///
    /// Returns nil if the UID is not a recognized transfer syntax.
    /// - Parameter uid: Transfer Syntax UID string
    /// - Returns: TransferSyntax if recognized, nil otherwise
    public static func from(uid: String) -> TransferSyntax? {
        switch uid {
        // Uncompressed
        case implicitVRLittleEndian.uid:
            return .implicitVRLittleEndian
        case explicitVRLittleEndian.uid:
            return .explicitVRLittleEndian
        case deflatedExplicitVRLittleEndian.uid:
            return .deflatedExplicitVRLittleEndian
        case explicitVRBigEndian.uid:
            return .explicitVRBigEndian
        // JPEG
        case jpegBaseline.uid:
            return .jpegBaseline
        case jpegExtended.uid:
            return .jpegExtended
        case jpegLossless.uid:
            return .jpegLossless
        case jpegLosslessSV1.uid:
            return .jpegLosslessSV1
        // JPEG 2000
        case jpeg2000Lossless.uid:
            return .jpeg2000Lossless
        case jpeg2000.uid:
            return .jpeg2000
        // RLE
        case rleLossless.uid:
            return .rleLossless
        default:
            return nil
        }
    }
    
    /// Whether this transfer syntax uses JPEG compression
    public var isJPEG: Bool {
        switch uid {
        case TransferSyntax.jpegBaseline.uid,
             TransferSyntax.jpegExtended.uid,
             TransferSyntax.jpegLossless.uid,
             TransferSyntax.jpegLosslessSV1.uid:
            return true
        default:
            return false
        }
    }
    
    /// Whether this transfer syntax uses JPEG 2000 compression
    public var isJPEG2000: Bool {
        switch uid {
        case TransferSyntax.jpeg2000Lossless.uid,
             TransferSyntax.jpeg2000.uid:
            return true
        default:
            return false
        }
    }
    
    /// Whether this transfer syntax uses RLE compression
    public var isRLE: Bool {
        uid == TransferSyntax.rleLossless.uid
    }
    
    /// Whether this is a lossless transfer syntax
    public var isLossless: Bool {
        switch uid {
        case TransferSyntax.implicitVRLittleEndian.uid,
             TransferSyntax.explicitVRLittleEndian.uid,
             TransferSyntax.deflatedExplicitVRLittleEndian.uid,
             TransferSyntax.explicitVRBigEndian.uid,
             TransferSyntax.jpegLossless.uid,
             TransferSyntax.jpegLosslessSV1.uid,
             TransferSyntax.jpeg2000Lossless.uid,
             TransferSyntax.rleLossless.uid:
            return true
        default:
            return false
        }
    }
}

// MARK: - CustomStringConvertible
extension TransferSyntax: CustomStringConvertible {
    public var description: String {
        let vrType = isExplicitVR ? "Explicit VR" : "Implicit VR"
        let endian = byteOrder == .littleEndian ? "Little Endian" : "Big Endian"
        let deflated = isDeflated ? " Deflated" : ""
        return "\(deflated)\(vrType) \(endian) (\(uid))".trimmingCharacters(in: .whitespaces)
    }
}

/// Byte ordering for DICOM data
///
/// Specifies how multi-byte numeric values are stored in memory.
/// Reference: PS3.5 Section 7.3
public enum ByteOrder: Sendable, Hashable {
    /// Little Endian byte ordering (least significant byte first)
    ///
    /// Default for most DICOM transfer syntaxes.
    case littleEndian
    
    /// Big Endian byte ordering (most significant byte first)
    ///
    /// Used by the retired Explicit VR Big Endian transfer syntax.
    case bigEndian
}
