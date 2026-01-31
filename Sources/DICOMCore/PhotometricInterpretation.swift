/// DICOM Photometric Interpretation
///
/// Specifies the intended interpretation of the pixel data.
/// Reference: DICOM PS3.3 C.7.6.3.1.2 - Photometric Interpretation
public enum PhotometricInterpretation: String, Sendable, Equatable, Hashable {
    /// Pixel data represent a single monochrome image plane where minimum sample value
    /// is intended to be displayed as white after any VOI gray scale transformations.
    /// Reference: PS3.3 C.7.6.3.1.2
    case monochrome1 = "MONOCHROME1"
    
    /// Pixel data represent a single monochrome image plane where minimum sample value
    /// is intended to be displayed as black after any VOI gray scale transformations.
    /// This is the most common monochrome photometric interpretation.
    /// Reference: PS3.3 C.7.6.3.1.2
    case monochrome2 = "MONOCHROME2"
    
    /// Pixel data represent a color image with RGB (red, green, blue) color model.
    /// Reference: PS3.3 C.7.6.3.1.2
    case rgb = "RGB"
    
    /// Pixel data represent an image described using a palette lookup table.
    /// Reference: PS3.3 C.7.6.3.1.2
    case paletteColor = "PALETTE COLOR"
    
    /// Pixel data represent a color image with YBR_FULL color model.
    /// Reference: PS3.3 C.7.6.3.1.2
    case ybrFull = "YBR_FULL"
    
    /// Pixel data represent a color image with YBR_FULL_422 color model.
    /// Reference: PS3.3 C.7.6.3.1.2
    case ybrFull422 = "YBR_FULL_422"
    
    /// Pixel data represent a color image with YBR_PARTIAL_422 color model (retired).
    /// Reference: PS3.3 C.7.6.3.1.2
    case ybrPartial422 = "YBR_PARTIAL_422"
    
    /// Pixel data represent a color image with YBR_PARTIAL_420 color model.
    /// Reference: PS3.3 C.7.6.3.1.2
    case ybrPartial420 = "YBR_PARTIAL_420"
    
    /// Pixel data represent a color image with YBR_ICT color model (JPEG 2000).
    /// Reference: PS3.3 C.7.6.3.1.2
    case ybrICT = "YBR_ICT"
    
    /// Pixel data represent a color image with YBR_RCT color model (JPEG 2000 lossless).
    /// Reference: PS3.3 C.7.6.3.1.2
    case ybrRCT = "YBR_RCT"
    
    /// Whether this photometric interpretation represents a monochrome image
    public var isMonochrome: Bool {
        switch self {
        case .monochrome1, .monochrome2:
            return true
        default:
            return false
        }
    }
    
    /// Whether this photometric interpretation represents a color image
    public var isColor: Bool {
        !isMonochrome
    }
    
    /// Whether this photometric interpretation uses a palette lookup table
    public var isPaletteColor: Bool {
        self == .paletteColor
    }
    
    /// The expected number of samples per pixel for this photometric interpretation
    public var expectedSamplesPerPixel: Int {
        switch self {
        case .monochrome1, .monochrome2, .paletteColor:
            // PALETTE COLOR has 1 sample per pixel (the index value)
            return 1
        case .rgb, .ybrFull, .ybrFull422, .ybrPartial422, .ybrPartial420, .ybrICT, .ybrRCT:
            return 3
        }
    }
    
    /// Creates a PhotometricInterpretation from a DICOM string value
    /// - Parameter string: The DICOM Photometric Interpretation string
    /// - Returns: PhotometricInterpretation if valid, nil otherwise
    public static func parse(_ string: String) -> PhotometricInterpretation? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return PhotometricInterpretation(rawValue: trimmed)
    }
}
