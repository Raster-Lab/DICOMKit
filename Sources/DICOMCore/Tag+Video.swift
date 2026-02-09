/// DICOM Tag Extensions - Video Information
///
/// Tags specific to DICOM Video storage and multi-frame cine modules.
/// Many video-related tags are already defined in Tag+ImageInformation.swift
/// (numberOfFrames, frameTime, frameDelay, cineRate, etc.).
/// This extension adds video-specific tags not covered elsewhere.
///
/// Reference: DICOM PS3.3 - Video IODs
/// Reference: PS3.3 C.7.6.5 - Cine Module
/// Reference: PS3.3 A.32.5 - Video Endoscopic Image IOD
/// Reference: PS3.3 A.32.6 - Video Microscopic Image IOD
/// Reference: PS3.3 A.32.7 - Video Photographic Image IOD
extension Tag {

    // MARK: - Cine Module (PS3.3 C.7.6.5)

    /// Recommended Display Frame Rate (0008,2144)
    /// VR: IS, VM: 1
    /// Recommended rate at which frames should be displayed, in frames/second
    public static let recommendedDisplayFrameRate = Tag(group: 0x0008, element: 0x2144)

    /// Start Trim (0008,2142)
    /// VR: IS, VM: 1
    /// The frame number of the first frame of interest in a multi-frame cine image
    public static let startTrim = Tag(group: 0x0008, element: 0x2142)

    /// Stop Trim (0008,2143)
    /// VR: IS, VM: 1
    /// The frame number of the last frame of interest in a multi-frame cine image
    public static let stopTrim = Tag(group: 0x0008, element: 0x2143)

    // MARK: - Acquisition Context Module

    /// Acquisition Duration (0018,9073)
    /// VR: FD, VM: 1
    /// Duration of acquisition in seconds
    public static let acquisitionDuration = Tag(group: 0x0018, element: 0x9073)

    // MARK: - SC Multi-frame Image Module

    /// Nominal Scanned Pixel Spacing (0018,2010)
    /// VR: DS, VM: 2
    /// Physical distance between adjacent pixels in mm
    public static let nominalScannedPixelSpacing = Tag(group: 0x0018, element: 0x2010)
}
