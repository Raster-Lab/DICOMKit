/// Errors that can occur during pixel data extraction and decoding
///
/// Provides detailed information about why pixel data extraction failed,
/// allowing applications to provide meaningful feedback to users.
public enum PixelDataError: Error, Sendable {
    /// Required pixel data descriptor attributes are missing
    ///
    /// The DICOM file is missing one or more required attributes needed to
    /// describe the pixel data format (e.g., Rows, Columns, Bits Allocated).
    case missingDescriptor
    
    /// No pixel data element is present in the data set
    ///
    /// The DICOM file does not contain a Pixel Data element (7FE0,0010).
    case missingPixelData
    
    /// The transfer syntax UID is missing from the file metadata
    ///
    /// The DICOM file has encapsulated pixel data but the Transfer Syntax UID
    /// is not available to determine the codec to use.
    case missingTransferSyntax
    
    /// The transfer syntax is not supported for decoding
    ///
    /// The DICOM file uses a compressed transfer syntax that DICOMKit
    /// does not have a codec for. The associated value contains the
    /// unsupported transfer syntax UID.
    ///
    /// Common unsupported transfer syntaxes include:
    /// - JPEG-LS Lossless (1.2.840.10008.1.2.4.80)
    /// - JPEG-LS Near-Lossless (1.2.840.10008.1.2.4.81)
    /// - JPEG 2000 Part 2 (1.2.840.10008.1.2.4.92, 1.2.840.10008.1.2.4.93)
    /// - HTJPEG 2000 (1.2.840.10008.1.2.4.201, 1.2.840.10008.1.2.4.202)
    case unsupportedTransferSyntax(String)
    
    /// Failed to extract frame data from encapsulated pixel data
    ///
    /// The compressed pixel data structure could not be parsed correctly,
    /// or the specified frame index is out of bounds. The associated value
    /// contains the frame index that failed.
    case frameExtractionFailed(frameIndex: Int)
    
    /// Decompression of pixel data failed
    ///
    /// The codec was found but failed to decompress the pixel data.
    /// This can occur if the compressed data is corrupted or uses an
    /// unsupported variant of the compression format.
    /// The associated values contain the frame index and the underlying error message.
    case decodingFailed(frameIndex: Int, reason: String)
}

extension PixelDataError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .missingDescriptor:
            return "Pixel data extraction failed: Missing required pixel data attributes (Rows, Columns, Bits Allocated, etc.)"
        case .missingPixelData:
            return "Pixel data extraction failed: No pixel data element present in the DICOM file"
        case .missingTransferSyntax:
            return "Pixel data extraction failed: Transfer syntax UID is missing from file metadata"
        case .unsupportedTransferSyntax(let uid):
            return "Pixel data extraction failed: Unsupported transfer syntax '\(uid)' - no codec available"
        case .frameExtractionFailed(let frameIndex):
            return "Pixel data extraction failed: Could not extract frame \(frameIndex) from encapsulated pixel data"
        case .decodingFailed(let frameIndex, let reason):
            return "Pixel data decoding failed for frame \(frameIndex): \(reason)"
        }
    }
}

extension PixelDataError {
    /// Human-readable explanation of the error and potential solutions
    public var explanation: String {
        switch self {
        case .missingDescriptor:
            return "The DICOM file is missing required attributes that describe the pixel data format. " +
                   "This may indicate a malformed DICOM file or a non-image SOP class."
        case .missingPixelData:
            return "The DICOM file does not contain any pixel data. " +
                   "This may be a structured report, key object, or other non-image DICOM object."
        case .missingTransferSyntax:
            return "The DICOM file has compressed pixel data but the Transfer Syntax UID is not " +
                   "available in the file metadata. This is required to determine which codec to use."
        case .unsupportedTransferSyntax(let uid):
            return "The DICOM file uses compressed transfer syntax '\(uid)' which is not currently supported. " +
                   "Supported compressed formats include JPEG Baseline, JPEG Extended, JPEG Lossless, " +
                   "JPEG 2000 Lossless/Lossy, and RLE Lossless."
        case .frameExtractionFailed(let frameIndex):
            return "Could not extract frame \(frameIndex) from the compressed pixel data structure. " +
                   "The encapsulated pixel data may be malformed or the frame index may be out of bounds."
        case .decodingFailed(let frameIndex, let reason):
            return "The codec failed to decompress frame \(frameIndex). " +
                   "The compressed data may be corrupted or use an unsupported compression variant. " +
                   "Details: \(reason)"
        }
    }
    
    /// Known transfer syntax name for unsupported formats
    public var transferSyntaxName: String? {
        guard case .unsupportedTransferSyntax(let uid) = self else {
            return nil
        }
        
        switch uid {
        case "1.2.840.10008.1.2.4.80":
            return "JPEG-LS Lossless"
        case "1.2.840.10008.1.2.4.81":
            return "JPEG-LS Near-Lossless"
        case "1.2.840.10008.1.2.4.92":
            return "JPEG 2000 Part 2 Lossless"
        case "1.2.840.10008.1.2.4.93":
            return "JPEG 2000 Part 2 Lossy"
        case "1.2.840.10008.1.2.4.201":
            return "High-Throughput JPEG 2000 Lossless"
        case "1.2.840.10008.1.2.4.202":
            return "High-Throughput JPEG 2000 with RPCL Lossless"
        case "1.2.840.10008.1.2.4.203":
            return "High-Throughput JPEG 2000 Lossy"
        default:
            return nil
        }
    }
}
