import Foundation

/// Descriptor for DICOM pixel data attributes
///
/// Contains all necessary metadata to interpret pixel data bytes.
/// Reference: DICOM PS3.3 C.7.6.3 - Image Pixel Module
///
/// NEMA-verified: 2026a, checked 2026-09-25 — attribute semantics checked against PS3.3 2026a Table C.7-11c (Image Pixel Description Macro), C.7.6.3.1.1-C.7.6.3.1.3 and PS3.5 2026a §8.1.1. The per-property citations that pointed at C.7.6.3.1.1 (which is "Samples per Pixel") for Rows, Columns, Bits Allocated, Bits Stored, High Bit and Pixel Representation were corrected.
public struct PixelDataDescriptor: Sendable, Equatable {
    // MARK: - Image Dimensions
    
    /// Number of rows (height) in the image
    /// Reference: PS3.3 Table C.7-11c - Rows (0028,0010)
    public let rows: Int
    
    /// Number of columns (width) in the image
    /// Reference: PS3.3 Table C.7-11c - Columns (0028,0011)
    public let columns: Int
    
    /// Number of frames in the image (1 for single-frame images)
    /// Reference: PS3.3 C.7.6.6.1.1 - Number of Frames
    public let numberOfFrames: Int
    
    // MARK: - Pixel Encoding
    
    /// Number of bits allocated for each pixel sample
    /// Shall be 1 or a multiple of 8 (PS3.5 §8.1.1); usually 8 or 16.
    /// Reference: PS3.3 Table C.7-11c - Bits Allocated (0028,0100); PS3.5 §8.1.1
    public let bitsAllocated: Int
    
    /// Number of bits stored for each pixel sample
    /// Must be less than or equal to Bits Allocated.
    /// Reference: PS3.3 Table C.7-11c - Bits Stored (0028,0101); PS3.5 §8.1.1
    public let bitsStored: Int
    
    /// Most significant bit of the pixel sample data
    /// Shall be Bits Stored - 1 (PS3.5 §8.1.1; older objects may differ, see PS3.5 2014c).
    /// Reference: PS3.3 Table C.7-11c - High Bit (0028,0102); PS3.5 §8.1.1
    public let highBit: Int
    
    /// Whether pixel samples are signed (1) or unsigned (0)
    /// Reference: PS3.3 Table C.7-11c - Pixel Representation (0028,0103): 0 unsigned, 1 two's complement
    public let isSigned: Bool
    
    // MARK: - Color Encoding
    
    /// Number of separate planes (samples) per pixel
    /// 1 for grayscale, 3 for RGB/YBR
    /// Reference: PS3.3 C.7.6.3.1.1 - Samples per Pixel
    public let samplesPerPixel: Int
    
    /// Photometric interpretation of the pixel data
    /// Reference: PS3.3 C.7.6.3.1.2 - Photometric Interpretation
    public let photometricInterpretation: PhotometricInterpretation
    
    /// Planar configuration for color images
    /// 0 = color-by-pixel (R1G1B1R2G2B2...), 1 = color-by-plane (R1R2...G1G2...B1B2...)
    /// Reference: PS3.3 C.7.6.3.1.3 - Planar Configuration
    public let planarConfiguration: Int
    
    // MARK: - Computed Properties
    
    /// Bytes per pixel sample
    public var bytesPerSample: Int {
        (bitsAllocated + 7) / 8
    }
    
    /// Total bytes per pixel (all samples)
    public var bytesPerPixel: Int {
        bytesPerSample * samplesPerPixel
    }
    
    /// Total number of pixels per frame
    public var pixelsPerFrame: Int {
        rows * columns
    }
    
    /// Total bytes per frame
    public var bytesPerFrame: Int {
        pixelsPerFrame * bytesPerPixel
    }
    
    /// Total bytes for all frames
    public var totalBytes: Int {
        bytesPerFrame * numberOfFrames
    }
    
    /// Whether this is a multi-frame image
    public var isMultiFrame: Bool {
        numberOfFrames > 1
    }
    
    /// The bit mask for extracting stored bits
    public var storedBitMask: Int {
        (1 << bitsStored) - 1
    }
    
    /// The bit shift to align stored bits (from high bit)
    public var bitShift: Int {
        highBit - bitsStored + 1
    }
    
    /// Minimum possible pixel value (based on Pixel Representation)
    public var minPossibleValue: Int {
        isSigned ? -(1 << (bitsStored - 1)) : 0
    }
    
    /// Maximum possible pixel value (based on Bits Stored)
    public var maxPossibleValue: Int {
        isSigned ? (1 << (bitsStored - 1)) - 1 : (1 << bitsStored) - 1
    }
    
    // MARK: - Initialization
    
    /// Creates a new pixel data descriptor
    /// - Parameters:
    ///   - rows: Number of rows (height)
    ///   - columns: Number of columns (width)
    ///   - numberOfFrames: Number of frames (default 1)
    ///   - bitsAllocated: Bits allocated per sample
    ///   - bitsStored: Bits stored per sample
    ///   - highBit: High bit position
    ///   - isSigned: Whether pixel values are signed
    ///   - samplesPerPixel: Samples per pixel (default 1)
    ///   - photometricInterpretation: Photometric interpretation
    ///   - planarConfiguration: Planar configuration (default 0)
    public init(
        rows: Int,
        columns: Int,
        numberOfFrames: Int = 1,
        bitsAllocated: Int,
        bitsStored: Int,
        highBit: Int,
        isSigned: Bool,
        samplesPerPixel: Int = 1,
        photometricInterpretation: PhotometricInterpretation,
        planarConfiguration: Int = 0
    ) {
        self.rows = rows
        self.columns = columns
        self.numberOfFrames = max(1, numberOfFrames)
        self.bitsAllocated = bitsAllocated
        self.bitsStored = bitsStored
        self.highBit = highBit
        self.isSigned = isSigned
        self.samplesPerPixel = samplesPerPixel
        self.photometricInterpretation = photometricInterpretation
        self.planarConfiguration = planarConfiguration
    }
}
