// ImageDecodingService.swift
// DICOMStudio
//
// DICOM Studio — Codec-aware image decoding service (Phase 8 / J2KSwift v3 integration)
//
// Routes pixel data extraction through `CodecRegistry` and records timing and
// backend metadata so the codec inspector panel can display them.

import Foundation
import DICOMKit
import DICOMCore

// MARK: - DecodedImageResult

/// The result of a codec-aware pixel data extraction.
public struct DecodedImageResult: Sendable {
    /// The decoded pixel data.
    public let pixelData: PixelData
    /// Transfer syntax UID used.
    public let transferSyntaxUID: String
    /// Human-readable codec name.
    public let codecName: String
    /// Active hardware backend.
    public let backend: CodecBackend
    /// Decode wall-clock time in milliseconds.
    public let decodeTimeMs: Double
}

// MARK: - ImageDecodingService

/// A codec-aware image decoding service that routes pixel data extraction
/// through `CodecRegistry` and records timing and backend metadata.
///
/// Use this service when you need to know which codec was used, how long
/// decoding took, and which hardware backend was active — for example to
/// populate the ``CodecInspectorViewModel``.
public final class ImageDecodingService: Sendable {

    public init() {}

    // MARK: - Decode

    /// Extracts and decodes pixel data from a DICOM file, recording codec metadata.
    ///
    /// - Parameter file: The parsed `DICOMFile`.
    /// - Returns: A `DecodedImageResult` if pixel data is available, otherwise `nil`.
    public func decode(file: DICOMFile) -> DecodedImageResult? {
        let tsUID = file.transferSyntaxUID ?? TransferSyntax.explicitVRLittleEndian.uid
        let start = Date()
        guard let pixData = file.pixelData() else { return nil }
        let elapsedMs = Date().timeIntervalSince(start) * 1000.0

        return DecodedImageResult(
            pixelData: pixData,
            transferSyntaxUID: tsUID,
            codecName: CodecInspectorHelpers.codecDisplayName(for: tsUID),
            backend: CodecRegistry.shared.activeBackend,
            decodeTimeMs: max(0, elapsedMs)
        )
    }

    // MARK: - Inspector status (metadata only)

    /// Derives a `CodecInspectorStatus` for a given `DICOMFile` by inspecting
    /// metadata only — does **not** decode pixel data.
    ///
    /// Use this to pre-populate the inspector panel before decoding starts.
    public func inspectorStatus(for file: DICOMFile) -> CodecInspectorStatus {
        guard let tsUID = file.transferSyntaxUID else {
            let desc = TransferSyntax.explicitVRLittleEndian.description
            return .uncompressed(transferSyntaxDescription: desc)
        }

        let ts = TransferSyntax.from(uid: tsUID)

        // Uncompressed transfer syntaxes never need a codec.
        if let ts, !ts.isEncapsulated {
            return .uncompressed(transferSyntaxDescription: ts.description)
        }

        guard CodecRegistry.shared.hasCodec(for: tsUID) else {
            return .unsupportedCodec(transferSyntaxUID: tsUID)
        }

        // A codec is registered — signal that decoding is about to begin.
        return .decoding
    }
}
