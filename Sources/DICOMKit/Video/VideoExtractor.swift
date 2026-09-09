//
// VideoExtractor.swift
// DICOMKit
//
// Copyright © 2026 DICOMKit. All rights reserved.
//

import Foundation
import DICOMCore

/// Why a DICOM object's video payload could not be extracted.
public enum VideoExtractionError: Error, Sendable, Equatable {
    /// The file's transfer syntax is not a video one.
    case notAVideoTransferSyntax(uid: String)
    /// The object carries no Pixel Data element.
    case missingPixelData
    /// Pixel Data is present but holds no bytes.
    case emptyPixelData
    /// The transfer syntax is non-fragmentable, yet the object carries several
    /// fragments — the payload cannot be reassembled with confidence.
    case unexpectedFragmentCount(count: Int, transferSyntax: String)

    /// A message naming the problem and, where useful, the remedy.
    public var message: String {
        switch self {
        case let .notAVideoTransferSyntax(uid):
            return """
                error: transfer syntax \(uid) is not a video transfer syntax.
                       dicom-video extracts H.264/HEVC/MPEG-2 payloads only. \
                Use dicom-image for still-image objects.
                """
        case .missingPixelData:
            return "error: the object carries no Pixel Data (7FE0,0010)."
        case .emptyPixelData:
            return "error: the object's Pixel Data is empty."
        case let .unexpectedFragmentCount(count, transferSyntax):
            return """
                error: transfer syntax \(transferSyntax) requires the whole bit \
                stream in one fragment, but the object carries \(count).
                """
        }
    }
}

/// The video payload recovered from a DICOM object.
public struct ExtractedVideo: Sendable {
    /// The bit stream, exactly as it was encapsulated.
    public let bitstream: Data
    /// The transfer syntax it was carried in.
    public let transferSyntax: TransferSyntax
    /// The codec, derived from the transfer syntax.
    public let codec: VideoCodec
    /// The container the payload is in, detected from its own bytes.
    public let container: VideoContainer
    /// The number of fragments the payload was split across.
    public let fragmentCount: Int

    /// The file extension that suits this payload.
    ///
    /// The payload retains the container it was encapsulated with, so the
    /// extension follows the bytes rather than the codec.
    public var suggestedFileExtension: String {
        switch container {
        case .mp4: return "mp4"
        case .quickTime: return "mov"
        case .mpegTS: return "ts"
        case .elementaryStream, .unknown:
            switch codec {
            case .h264: return "264"
            case .h265: return "265"
            case .mpeg2: return "m2v"
            case .unknown: return "bin"
            }
        }
    }
}

/// Recovers the video bit stream from a DICOM object.
///
/// This is the reverse of the encapsulation Phase 1 fixed, and shares its rule:
/// the bytes written are the bytes read back, unchanged.
///
/// Reference: PS3.5 Section A.4 - Encapsulation of Encoded Pixel Data
public enum VideoExtractor {

    /// Extracts the video payload from a parsed DICOM file.
    ///
    /// - Parameters:
    ///   - dataSet: The object's data set.
    ///   - transferSyntax: The transfer syntax the object was encoded with.
    /// - Returns: The recovered payload.
    /// - Throws: ``VideoExtractionError`` when there is nothing to extract.
    public static func extract(
        from dataSet: DataSet,
        transferSyntax: TransferSyntax
    ) throws -> ExtractedVideo {
        guard transferSyntax.isVideo else {
            throw VideoExtractionError.notAVideoTransferSyntax(uid: transferSyntax.uid)
        }

        guard let element = dataSet[.pixelData] else {
            throw VideoExtractionError.missingPixelData
        }

        let bitstream: Data
        let fragmentCount: Int

        if let fragments = element.encapsulatedFragments, !fragments.isEmpty {
            // A non-fragmentable transfer syntax requires exactly one fragment
            // holding the whole bit stream. More than one means the object
            // disagrees with its own transfer syntax, and concatenating them
            // would paper over that.
            if !transferSyntax.allowsMultipleFragments, fragments.count > 1 {
                throw VideoExtractionError.unexpectedFragmentCount(
                    count: fragments.count,
                    transferSyntax: transferSyntax.uid
                )
            }
            var combined = Data()
            for fragment in fragments { combined.append(fragment) }
            bitstream = combined
            fragmentCount = fragments.count
        } else if !element.valueData.isEmpty {
            // Legacy objects that stored the stream as a native OB value.
            bitstream = element.valueData
            fragmentCount = 0
        } else {
            throw VideoExtractionError.emptyPixelData
        }

        guard !bitstream.isEmpty else {
            throw VideoExtractionError.emptyPixelData
        }

        return ExtractedVideo(
            bitstream: bitstream,
            transferSyntax: transferSyntax,
            codec: VideoCodec(transferSyntaxUID: transferSyntax.uid),
            container: MP4ContainerParser.detectContainer(bitstream),
            fragmentCount: fragmentCount
        )
    }

    /// Extracts the video payload from a DICOM file, reading the transfer syntax
    /// from its File Meta Information.
    ///
    /// - Parameter file: A parsed DICOM file.
    /// - Returns: The recovered payload.
    /// - Throws: ``VideoExtractionError`` when there is nothing to extract.
    public static func extract(from file: DICOMFile) throws -> ExtractedVideo {
        let uid = file.transferSyntaxUID ?? TransferSyntax.explicitVRLittleEndian.uid
        guard let transferSyntax = TransferSyntax.from(uid: uid) else {
            throw VideoExtractionError.notAVideoTransferSyntax(uid: uid)
        }
        return try extract(from: file.dataSet, transferSyntax: transferSyntax)
    }
}
