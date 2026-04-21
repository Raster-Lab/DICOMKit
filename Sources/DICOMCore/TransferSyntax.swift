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

    /// JPEG 2000 Part 2 Multi-component Image Compression (Lossless Only) (1.2.840.10008.1.2.4.92)
    public static let jpeg2000Part2Lossless = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.92",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )

    /// JPEG 2000 Part 2 Multi-component Image Compression (1.2.840.10008.1.2.4.93)
    public static let jpeg2000Part2 = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.93",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )

    /// High-Throughput JPEG 2000 Image Compression (Lossless Only) (1.2.840.10008.1.2.4.201)
    public static let htj2kLossless = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.201",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )

    /// High-Throughput JPEG 2000 with RPCL options (Lossless Only) (1.2.840.10008.1.2.4.202)
    public static let htj2kRPCLLossless = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.202",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )

    /// High-Throughput JPEG 2000 Image Compression (1.2.840.10008.1.2.4.203)
    public static let htj2kLossy = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.203",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )
    
    // MARK: - JP3D Experimental Transfer Syntaxes
    
    /// JP3D Lossless (Experimental) — private vendor extension
    ///
    /// ISO/IEC 15444-10 volumetric JPEG 2000 lossless compression.
    /// DICOM does not define a standard JP3D transfer syntax; this private UID
    /// is used for round-trip testing and internal storage only.
    /// Clearly labelled experimental — not for interoperability.
    public static let jp3dLossless = TransferSyntax(
        uid: "1.2.826.0.1.3680043.10.511.1",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )
    
    /// JP3D Lossy (Experimental) — private vendor extension
    ///
    /// ISO/IEC 15444-10 volumetric JPEG 2000 lossy compression.
    /// DICOM does not define a standard JP3D transfer syntax; this private UID
    /// is used for round-trip testing and internal storage only.
    /// Clearly labelled experimental — not for interoperability.
    public static let jp3dLossy = TransferSyntax(
        uid: "1.2.826.0.1.3680043.10.511.2",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )
    
    // MARK: - JPIP Transfer Syntaxes
    
    /// JPIP Referenced (1.2.840.10008.1.2.4.94)
    ///
    /// JPEG 2000 Interactive Protocol — the pixel data is a URI reference to a
    /// JPIP server endpoint rather than inline pixel data.
    /// Reference: PS3.5 Table A-1, PS3.5 Annex A.8
    public static let jpipReferenced = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.94",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: false
    )
    
    /// JPIP Referenced Deflate (1.2.840.10008.1.2.4.95)
    ///
    /// Like ``jpipReferenced`` but the DICOM dataset is deflate-compressed.
    /// Reference: PS3.5 Table A-1, PS3.5 Annex A.8
    public static let jpipReferencedDeflate = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.95",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: false,
        isDeflated: true
    )
    
    // MARK: - JPEG-LS Transfer Syntaxes
    
    /// JPEG-LS Lossless Image Compression (1.2.840.10008.1.2.4.80)
    ///
    /// JPEG-LS lossless image compression using the HP LOCO-I/JPEG-LS algorithm.
    ///
    /// Reference: PS3.5 Section A.4.5, ITU-T T.87 / ISO/IEC 14495-1
    public static let jpegLSLossless = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.80",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )
    
    /// JPEG-LS Lossy (Near-Lossless) Image Compression (1.2.840.10008.1.2.4.81)
    ///
    /// JPEG-LS near-lossless image compression using the HP LOCO-I/JPEG-LS algorithm
    /// with a configurable maximum error tolerance (NEAR parameter).
    ///
    /// Reference: PS3.5 Section A.4.5, ITU-T T.87 / ISO/IEC 14495-1
    public static let jpegLSNearLossless = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.81",
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
    
    // MARK: - Video Transfer Syntaxes
    
    /// MPEG2 Main Profile @ Main Level (1.2.840.10008.1.2.4.100)
    ///
    /// MPEG2 video compression at Main Profile, Main Level.
    /// Supports up to 720x576 at 30fps or 720x480 at 30fps.
    ///
    /// Reference: PS3.5 Section A.4.5
    public static let mpeg2MainProfile = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.100",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )
    
    /// MPEG2 Main Profile @ High Level (1.2.840.10008.1.2.4.101)
    ///
    /// MPEG2 video compression at Main Profile, High Level.
    /// Supports up to 1920x1080 at 30fps (HD video).
    ///
    /// Reference: PS3.5 Section A.4.5
    public static let mpeg2MainProfileHighLevel = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.101",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )
    
    /// MPEG-4 AVC/H.264 High Profile / Level 4.1 (1.2.840.10008.1.2.4.102)
    ///
    /// H.264/AVC video compression at High Profile, Level 4.1.
    /// Supports up to 1920x1080 at 30fps or 1280x720 at 60fps.
    ///
    /// Reference: PS3.5 Section A.4.6
    public static let mpeg4AVCHP41 = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.102",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )
    
    /// MPEG-4 AVC/H.264 BD-compatible High Profile / Level 4.1 (1.2.840.10008.1.2.4.103)
    ///
    /// H.264/AVC video compression compatible with Blu-ray Disc format.
    /// Supports up to 1920x1080 at 30fps.
    ///
    /// Reference: PS3.5 Section A.4.6
    public static let mpeg4AVCHP41BD = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.103",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )
    
    /// HEVC/H.265 Main Profile / Level 5.1 (1.2.840.10008.1.2.4.107)
    ///
    /// H.265/HEVC video compression at Main Profile, Level 5.1.
    /// Supports up to 3840x2160 at 30fps (4K UHD video).
    ///
    /// Reference: PS3.5 Section A.4.7
    public static let hevcH265MainProfile = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.107",
        isExplicitVR: true,
        byteOrder: .littleEndian,
        isEncapsulated: true
    )
    
    /// HEVC/H.265 Main 10 Profile / Level 5.1 (1.2.840.10008.1.2.4.108)
    ///
    /// H.265/HEVC video compression at Main 10 Profile, Level 5.1.
    /// Supports 10-bit depth for HDR video, up to 3840x2160 at 30fps.
    ///
    /// Reference: PS3.5 Section A.4.7
    public static let hevcH265Main10Profile = TransferSyntax(
        uid: "1.2.840.10008.1.2.4.108",
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
        case jpeg2000Part2Lossless.uid:
            return .jpeg2000Part2Lossless
        case jpeg2000Part2.uid:
            return .jpeg2000Part2
        case htj2kLossless.uid:
            return .htj2kLossless
        case htj2kRPCLLossless.uid:
            return .htj2kRPCLLossless
        case htj2kLossy.uid:
            return .htj2kLossy
        // JP3D (experimental)
        case jp3dLossless.uid:
            return .jp3dLossless
        case jp3dLossy.uid:
            return .jp3dLossy
        // JPIP
        case jpipReferenced.uid:
            return .jpipReferenced
        case jpipReferencedDeflate.uid:
            return .jpipReferencedDeflate
        // JPEG-LS
        case jpegLSLossless.uid:
            return .jpegLSLossless
        case jpegLSNearLossless.uid:
            return .jpegLSNearLossless
        // RLE
        case rleLossless.uid:
            return .rleLossless
        // Video
        case mpeg2MainProfile.uid:
            return .mpeg2MainProfile
        case mpeg2MainProfileHighLevel.uid:
            return .mpeg2MainProfileHighLevel
        case mpeg4AVCHP41.uid:
            return .mpeg4AVCHP41
        case mpeg4AVCHP41BD.uid:
            return .mpeg4AVCHP41BD
        case hevcH265MainProfile.uid:
            return .hevcH265MainProfile
        case hevcH265Main10Profile.uid:
            return .hevcH265Main10Profile
        default:
            return nil
        }
    }

    /// Parses a transfer syntax from a user-facing alias or UID string.
    ///
    /// Accepts standard UIDs plus common CLI names such as
    /// explicit-vr-le, jpeg2000-lossless, htj2k-lossless, htj2k-rpcl, and htj2k.
    ///
    /// - Parameter nameOrUID: The transfer syntax alias or UID.
    /// - Returns: The matching transfer syntax, or nil when unrecognized.
    public static func parse(_ nameOrUID: String) -> TransferSyntax? {
        let trimmed = nameOrUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let syntax = from(uid: trimmed) {
            return syntax
        }

        let normalized = trimmed
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")

        switch normalized {
        case "implicitvrlittleendian", "implicit-vr-le", "implicit", "ivle":
            return .implicitVRLittleEndian
        case "explicitvrlittleendian", "explicit-vr-le", "explicit", "evle":
            return .explicitVRLittleEndian
        case "explicitvrbigendian", "explicit-vr-be", "big-endian", "evbe":
            return .explicitVRBigEndian
        case "deflate", "deflated-explicit-vr-le":
            return .deflatedExplicitVRLittleEndian
        case "jpeg-baseline", "jpegbaseline", "jpeg":
            return .jpegBaseline
        case "jpeg-extended", "jpegextended":
            return .jpegExtended
        case "jpeg-lossless", "jpeglossless":
            return .jpegLossless
        case "jpeg-lossless-sv1", "jpeglosslesssv1":
            return .jpegLosslessSV1
        case "jpeg2000-lossless", "jpeg2000lossless", "j2k-lossless":
            return .jpeg2000Lossless
        case "jpeg2000", "jpeg2000-lossy", "j2k":
            return .jpeg2000
        case "jpeg2000-part2-lossless", "jpeg2000part2lossless", "j2k-part2-lossless":
            return .jpeg2000Part2Lossless
        case "jpeg2000-part2", "jpeg2000part2", "j2k-part2":
            return .jpeg2000Part2
        case "htj2k-lossless", "htj2klossless":
            return .htj2kLossless
        case "htj2k-rpcl", "htj2k-lossless-rpcl", "htj2krpcllossless":
            return .htj2kRPCLLossless
        case "htj2k", "htj2k-lossy", "htj2klossy":
            return .htj2kLossy
        case "jpeg-ls-lossless", "jpegls-lossless", "jls-lossless":
            return .jpegLSLossless
        case "jpeg-ls", "jpegls", "jls":
            return .jpegLSNearLossless
        case "rle", "rle-lossless":
            return .rleLossless
        case "jp3d-lossless", "jp3dlossless":
            return .jp3dLossless
        case "jp3d", "jp3d-lossy", "jp3dlossy":
            return .jp3dLossy
        case "jpip", "jpip-referenced":
            return .jpipReferenced
        case "jpip-deflate", "jpip-referenced-deflate":
            return .jpipReferencedDeflate
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
             TransferSyntax.jpeg2000.uid,
             TransferSyntax.jpeg2000Part2Lossless.uid,
             TransferSyntax.jpeg2000Part2.uid,
             TransferSyntax.htj2kLossless.uid,
             TransferSyntax.htj2kRPCLLossless.uid,
             TransferSyntax.htj2kLossy.uid:
            return true
        default:
            return false
        }
    }

    /// Whether this transfer syntax uses JPEG 2000 Part 2 compression.
    public var isJPEG2000Part2: Bool {
        switch uid {
        case TransferSyntax.jpeg2000Part2Lossless.uid,
             TransferSyntax.jpeg2000Part2.uid:
            return true
        default:
            return false
        }
    }

    /// Whether this transfer syntax uses High-Throughput JPEG 2000 compression.
    public var isHTJ2K: Bool {
        switch uid {
        case TransferSyntax.htj2kLossless.uid,
             TransferSyntax.htj2kRPCLLossless.uid,
             TransferSyntax.htj2kLossy.uid:
            return true
        default:
            return false
        }
    }
    
    /// Whether this transfer syntax is a JPIP referenced transfer syntax.
    ///
    /// JPIP transfer syntaxes contain a URI reference rather than inline pixel data.
    /// The URI points to a JPIP server where the actual JPEG 2000 image resides.
    public var isJPIP: Bool {
        switch uid {
        case TransferSyntax.jpipReferenced.uid,
             TransferSyntax.jpipReferencedDeflate.uid:
            return true
        default:
            return false
        }
    }

    /// Whether this transfer syntax uses JP3D volumetric compression (experimental)
    public var isJP3D: Bool {
        switch uid {
        case TransferSyntax.jp3dLossless.uid,
             TransferSyntax.jp3dLossy.uid:
            return true
        default:
            return false
        }
    }
    
    /// Whether this transfer syntax uses JPEG-LS compression
    public var isJPEGLS: Bool {
        switch uid {
        case TransferSyntax.jpegLSLossless.uid,
             TransferSyntax.jpegLSNearLossless.uid:
            return true
        default:
            return false
        }
    }
    
    /// Whether this transfer syntax uses RLE compression
    public var isRLE: Bool {
        uid == TransferSyntax.rleLossless.uid
    }
    
    /// Whether this transfer syntax uses video compression (MPEG2, H.264, or H.265)
    public var isVideo: Bool {
        switch uid {
        case TransferSyntax.mpeg2MainProfile.uid,
             TransferSyntax.mpeg2MainProfileHighLevel.uid,
             TransferSyntax.mpeg4AVCHP41.uid,
             TransferSyntax.mpeg4AVCHP41BD.uid,
             TransferSyntax.hevcH265MainProfile.uid,
             TransferSyntax.hevcH265Main10Profile.uid:
            return true
        default:
            return false
        }
    }
    
    /// Whether this transfer syntax uses MPEG2 compression
    public var isMPEG2: Bool {
        switch uid {
        case TransferSyntax.mpeg2MainProfile.uid,
             TransferSyntax.mpeg2MainProfileHighLevel.uid:
            return true
        default:
            return false
        }
    }
    
    /// Whether this transfer syntax uses H.264/AVC compression
    public var isH264: Bool {
        switch uid {
        case TransferSyntax.mpeg4AVCHP41.uid,
             TransferSyntax.mpeg4AVCHP41BD.uid:
            return true
        default:
            return false
        }
    }
    
    /// Whether this transfer syntax uses H.265/HEVC compression
    public var isH265: Bool {
        switch uid {
        case TransferSyntax.hevcH265MainProfile.uid,
             TransferSyntax.hevcH265Main10Profile.uid:
            return true
        default:
            return false
        }
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
             TransferSyntax.jpeg2000Part2Lossless.uid,
             TransferSyntax.htj2kLossless.uid,
             TransferSyntax.htj2kRPCLLossless.uid,
             TransferSyntax.jpegLSLossless.uid,
             TransferSyntax.rleLossless.uid,
             TransferSyntax.jp3dLossless.uid:
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
