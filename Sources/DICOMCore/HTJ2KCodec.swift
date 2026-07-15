import Foundation

#if canImport(J2KCore) && canImport(J2KCodec)
import J2KCore
import J2KCodec
#endif

/// Dedicated HTJ2K (ISO/IEC 15444-15) codec adapter for DICOMKit.
///
/// Wraps `J2KSwiftCodec` with HTJ2K-specific configuration, including
/// RPCL progression ordering for `.htj2kRPCLLossless` (1.2.840.10008.1.2.4.202).
///
/// Reference: DICOM PS3.5 Section A.4.6 — JPEG 2000 Part 15 (HTJ2K) Transfer Syntaxes
public struct HTJ2KCodec: ImageCodec, ImageEncoder, Sendable {
    /// The three DICOM HTJ2K transfer syntax UIDs.
    public static let supportedTransferSyntaxes: [String] = [
        TransferSyntax.htj2kLossless.uid,
        TransferSyntax.htj2kRPCLLossless.uid,
        TransferSyntax.htj2kLossy.uid
    ]

    /// Encoding is supported for all three HTJ2K syntaxes.
    public static let supportedEncodingTransferSyntaxes: [String] = supportedTransferSyntaxes

    /// The specific transfer syntax this codec instance targets for encoding.
    private let targetTransferSyntaxUID: String?

    /// The underlying J2KSwiftCodec that performs the actual work.
    private let backing: J2KSwiftCodec

    /// Creates an HTJ2K codec, optionally pinned to a specific transfer syntax for encoding.
    ///
    /// - Parameter targetTransferSyntaxUID: The HTJ2K transfer syntax UID to target during encoding.
    ///   When `nil`, defaults to HTJ2K Lossless.
    public init(targetTransferSyntaxUID: String? = nil) {
        self.targetTransferSyntaxUID = targetTransferSyntaxUID
        self.backing = J2KSwiftCodec(
            encodingTransferSyntaxUID: targetTransferSyntaxUID ?? TransferSyntax.htj2kLossless.uid
        )
    }

    // MARK: - ImageCodec

    public func decodeFrame(_ frameData: Data, descriptor: PixelDataDescriptor, frameIndex: Int) throws -> Data {
        try backing.decodeFrame(frameData, descriptor: descriptor, frameIndex: frameIndex)
    }

    // MARK: - ImageEncoder

    public func canEncode(with configuration: CompressionConfiguration, descriptor: PixelDataDescriptor) -> Bool {
        backing.canEncode(with: configuration, descriptor: descriptor)
    }

    public func encodeFrame(
        _ frameData: Data,
        descriptor: PixelDataDescriptor,
        frameIndex: Int,
        configuration: CompressionConfiguration
    ) throws -> Data {
        try backing.encodeFrame(frameData, descriptor: descriptor, frameIndex: frameIndex, configuration: configuration)
    }

    // MARK: - Direct Codestream Transcoding

    /// Direct J2K-to-HTJ2K coefficient transcoding is temporarily unavailable.
    ///
    /// J2KSwift 11.0.2 does not preserve decoded pixels through its coefficient
    /// transcoder. Use ``TransferSyntaxConverter`` so DICOMKit can safely decode
    /// complete frames and re-encode them with the target transfer syntax.
    ///
    /// - Parameter codestreamData: A standard JPEG 2000 (Part 1) codestream.
    /// - Returns: The HTJ2K codestream.
    /// - Throws: `DICOMError` if the input is not valid J2K or transcoding fails.
    public static func transcodeToHTJ2K(_ codestreamData: Data) throws -> Data {
        throw DICOMError.unsupportedTransferSyntax(
            "Direct J2K to HTJ2K transcoding is disabled because it does not preserve pixels; "
                + "use TransferSyntaxConverter for safe decode and re-encode"
        )
    }

    /// Direct HTJ2K-to-J2K coefficient transcoding is temporarily unavailable.
    ///
    /// Use ``TransferSyntaxConverter`` for the safe decoded-pixel path.
    ///
    /// - Parameter codestreamData: An HTJ2K codestream.
    /// - Returns: The standard JPEG 2000 codestream.
    /// - Throws: `DICOMError` if the input is not valid HTJ2K or transcoding fails.
    public static func transcodeFromHTJ2K(_ codestreamData: Data) throws -> Data {
        throw DICOMError.unsupportedTransferSyntax(
            "Direct HTJ2K to J2K transcoding is disabled because it does not preserve pixels; "
                + "use TransferSyntaxConverter for safe decode and re-encode"
        )
    }

    /// Detects whether a codestream uses HTJ2K encoding.
    ///
    /// - Parameter codestreamData: A JPEG 2000 codestream.
    /// - Returns: `true` when the codestream is HTJ2K-encoded.
    public static func isHTJ2K(_ codestreamData: Data) -> Bool {
        #if canImport(J2KCore) && canImport(J2KCodec)
        return (try? J2KTranscoder().isHTJ2K(codestreamData)) ?? false
        #else
        return false
        #endif
    }

}
