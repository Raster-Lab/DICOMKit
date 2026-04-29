// JPEG2000Backend.swift
// DICOMCore
//
// User-selectable JPEG 2000 codec backend for transfer syntax conversion.
// Used by the dicom-convert CLI (`--j2kswift` / `--openjpeg`) and the matching
// DICOMStudio CLI Workshop picker.

import Foundation

/// Selects which JPEG 2000 implementation should handle JPEG 2000 family
/// transfer syntaxes during transcoding.
///
/// Only affects encode/decode of JPEG 2000 family transfer syntaxes
/// (Part 1 `.4.90/.91`, Part 2 `.4.92/.93`, HTJ2K `.4.201/.202/.203`).
/// For all other transfer syntaxes (RLE, JPEG-LS, JPEG, uncompressed, …) the
/// backend selection is silently ignored and the existing dedicated codec is
/// used.
public enum JPEG2000Backend: String, Sendable, CaseIterable {
    /// Pure-Swift J2KSwift codec (default). Supports Part 1, Part 2, and HTJ2K
    /// across all platforms.
    case j2kSwift = "j2kswift"

    /// OpenJPEG 2.x via the bundled `COpenJPEG` C module. macOS only,
    /// JPEG 2000 Part 1 and Part 2 only — does NOT support HTJ2K.
    case openJPEG = "openjpeg"

    /// Default backend when the user does not specify one.
    public static let `default`: JPEG2000Backend = .j2kSwift

    /// Human-readable display name used in CLI banners and the GUI picker.
    public var displayName: String {
        switch self {
        case .j2kSwift: return "J2KSwift"
        case .openJPEG: return "OpenJPEG"
        }
    }

    /// Returns `true` when this backend can encode/decode the given transfer
    /// syntax UID. For non-JPEG 2000 family syntaxes always returns `true`
    /// (the selector is a no-op for those).
    public func canHandle(transferSyntaxUID uid: String) -> Bool {
        guard let syntax = TransferSyntax.from(uid: uid) else { return true }
        // Non-JPEG 2000 transfer syntaxes are unaffected by this selection.
        guard syntax.isJPEG2000 else { return true }

        switch self {
        case .j2kSwift:
            // J2KSwift handles every JPEG 2000 family UID DICOMKit exposes.
            return true
        case .openJPEG:
            // libopenjpeg has no HTJ2K (Part 15) support.
            return !syntax.isHTJ2K
        }
    }

    /// Convenience: returns `true` when the given UID is a JPEG 2000 family
    /// transfer syntax for which the backend selection is meaningful.
    public static func appliesTo(transferSyntaxUID uid: String) -> Bool {
        TransferSyntax.from(uid: uid)?.isJPEG2000 ?? false
    }

    /// Human-readable explanation of why this backend cannot handle a UID.
    /// Returns `nil` if the backend supports the syntax.
    public func incompatibilityReason(forTransferSyntaxUID uid: String) -> String? {
        guard !canHandle(transferSyntaxUID: uid) else { return nil }
        switch self {
        case .openJPEG:
            return "OpenJPEG does not support HTJ2K (ISO/IEC 15444-15) transfer syntaxes. " +
                "Use J2KSwift (--j2kswift) for HTJ2K targets."
        case .j2kSwift:
            return nil
        }
    }
}
