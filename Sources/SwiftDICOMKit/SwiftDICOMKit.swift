/// SwiftDICOMKit - A pure Swift DICOM toolkit for Apple platforms
///
/// Version 0.2.0
///
/// SwiftDICOMKit provides a modern, Swift-native interface for reading and parsing
/// DICOM (Digital Imaging and Communications in Medicine) files on iOS, macOS, and visionOS.
///
/// ## Features (v0.2)
/// - Read-only DICOM file parsing
/// - Explicit VR Little Endian Transfer Syntax support
/// - Implicit VR Little Endian Transfer Syntax support
/// - Explicit VR Big Endian Transfer Syntax support (Retired)
/// - Deflated Explicit VR Little Endian Transfer Syntax support (Apple platforms only)
/// - Value semantics with Swift 6 strict concurrency
/// - Full DICOM PS3.5 2025e compliance for supported features
///
/// ## Limitations (v0.2)
/// - No pixel data decoding
/// - No DICOM writing
/// - No networking (DICOM C-* operations)
/// - No compressed pixel data transfer syntaxes (JPEG, JPEG 2000, etc.)
///
/// ## Platform Requirements
/// - iOS 17.0+
/// - macOS 14.0+
/// - visionOS 1.0+

// Re-export core types
@_exported import DICOMCore
@_exported import DICOMDictionary

/// SwiftDICOMKit version
public let version = "0.2.0"

/// Supported DICOM Standard edition
public let dicomStandardEdition = "2025e"

/// Supported Transfer Syntax UIDs
public let supportedTransferSyntaxUIDs: [String] = [
    "1.2.840.10008.1.2.1",    // Explicit VR Little Endian
    "1.2.840.10008.1.2",      // Implicit VR Little Endian
    "1.2.840.10008.1.2.2",    // Explicit VR Big Endian (Retired)
    "1.2.840.10008.1.2.1.99"  // Deflated Explicit VR Little Endian
]

/// Primary supported Transfer Syntax UID (Explicit VR Little Endian)
/// - Note: For backward compatibility. Use `supportedTransferSyntaxUIDs` for full list.
public let supportedTransferSyntaxUID = "1.2.840.10008.1.2.1"
