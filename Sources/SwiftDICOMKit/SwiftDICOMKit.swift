/// SwiftDICOMKit - A pure Swift DICOM toolkit for Apple platforms
///
/// Version 0.1.0
///
/// SwiftDICOMKit provides a modern, Swift-native interface for reading and parsing
/// DICOM (Digital Imaging and Communications in Medicine) files on iOS, macOS, and visionOS.
///
/// ## Features (v0.1)
/// - Read-only DICOM file parsing
/// - Explicit VR Little Endian Transfer Syntax support
/// - Implicit VR Little Endian Transfer Syntax support
/// - Value semantics with Swift 6 strict concurrency
/// - Full DICOM PS3.5 2025e compliance for supported features
///
/// ## Limitations (v0.1)
/// - No pixel data decoding
/// - No DICOM writing
/// - No networking (DICOM C-* operations)
/// - No Big Endian or compressed transfer syntaxes
///
/// ## Platform Requirements
/// - iOS 17.0+
/// - macOS 14.0+
/// - visionOS 1.0+
/// - Apple Silicon only

// Re-export core types
@_exported import DICOMCore
@_exported import DICOMDictionary

/// SwiftDICOMKit version
public let version = "0.1.0"

/// Supported DICOM Standard edition
public let dicomStandardEdition = "2025e"

/// Supported Transfer Syntax UIDs
public let supportedTransferSyntaxUIDs: [String] = [
    "1.2.840.10008.1.2.1", // Explicit VR Little Endian
    "1.2.840.10008.1.2"    // Implicit VR Little Endian
]

/// Primary supported Transfer Syntax UID (Explicit VR Little Endian)
/// - Note: For backward compatibility. Use `supportedTransferSyntaxUIDs` for full list.
public let supportedTransferSyntaxUID = "1.2.840.10008.1.2.1"
