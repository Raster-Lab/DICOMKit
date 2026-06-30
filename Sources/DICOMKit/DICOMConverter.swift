import Foundation
import DICOMCore

/// Shared DICOM transfer-syntax conversion API for the `dicom-convert` CLI and
/// DICOMStudio's CLI Workshop.
///
/// This is the single source of truth for:
///   - **the list** of transfer syntaxes `dicom-convert` can target (one ordered
///     catalog feeds the CLI `--help`/error text, the CLI Workshop picker, and the
///     representative parameter catalog — never re-hardcode it),
///   - **input** parsing of a user-supplied transfer-syntax token (UID, the CLI's
///     CamelCase names, the kebab aliases, and the historical short aliases),
///   - **the process + output rendering**: reading the source file, optionally
///     stripping private tags, transcoding the pixel data via the DICOMCore
///     ``DICOMCore/TransferSyntaxConverter``, and serialising a complete Part-10
///     byte stream (preamble + DICM + File Meta Information + transcoded data set).
///
/// Both the CLI and the app call ``convertToDICOM(dicomFile:to:stripPrivate:)`` so
/// their byte output is identical (CLI ↔ app parity); the thin shells own only their
/// environment-specific file access and console formatting.
///
/// The target syntaxes are the DICOMCore ``DICOMCore/TransferSyntax`` constants the
/// transcoder can actually encode to — uncompressed, JPEG, JPEG 2000 (incl. Part 2
/// and HTJ2K), JPEG-LS, lossless JPEG XL, and RLE. Video, JPIP-referenced, and the
/// experimental JP3D syntaxes are intentionally excluded as convert targets.
public enum DICOMConverter {

    // MARK: - Target Catalog

    /// One convert target: a DICOMCore transfer syntax plus the tokens that select it.
    public struct Target: Sendable {
        /// The DICOMCore transfer syntax this target encodes to.
        public let syntax: TransferSyntax
        /// CamelCase token used by the CLI `--transfer-syntax` flag and the CLI
        /// Workshop picker (e.g. `ExplicitVRLittleEndian`, `JPEG2000Lossless`).
        public let cliToken: String
        /// kebab-case alias used by the representative parameter catalog and accepted
        /// on input (e.g. `explicit-vr-le`, `jpeg2000-lossless`).
        public let aliasToken: String
        /// Additional historical aliases accepted on input (already lowercased).
        public let extraAliases: [String]

        /// A short, human-readable name (from ``DICOMCore/TransferSyntax/displayName``).
        public var displayName: String { syntax.displayName }

        init(_ syntax: TransferSyntax, cli: String, alias: String, extra: [String] = []) {
            self.syntax = syntax
            self.cliToken = cli
            self.aliasToken = alias
            self.extraAliases = extra
        }
    }

    /// The canonical, UI-ordered list of transfer syntaxes `dicom-convert` can target.
    ///
    /// Ordering mirrors ``DICOMCore/TransferSyntax/allKnown`` (uncompressed, JPEG,
    /// JPEG 2000 / HTJ2K, JPEG-LS, JPEG XL, RLE). JPEG XL encode is lossless-only
    /// (there is no lossy JXL encoder), so the generic `jpeg-xl`/`jxl` aliases resolve
    /// to the lossless syntax — matching `CompressionManager`'s codec map.
    public static let targets: [Target] = [
        // Uncompressed
        Target(.explicitVRLittleEndian,          cli: "ExplicitVRLittleEndian",  alias: "explicit-vr-le", extra: ["explicit", "evle"]),
        Target(.implicitVRLittleEndian,          cli: "ImplicitVRLittleEndian",  alias: "implicit-vr-le", extra: ["implicit", "ivle"]),
        Target(.explicitVRBigEndian,             cli: "ExplicitVRBigEndian",     alias: "explicit-vr-be", extra: ["evbe", "big-endian"]),
        Target(.deflatedExplicitVRLittleEndian,  cli: "DEFLATE",                 alias: "deflate",        extra: ["deflated", "deflated-explicit-vr-le"]),
        // JPEG
        Target(.jpegBaseline,                    cli: "JPEGBaseline",            alias: "jpeg-baseline",  extra: ["jpeg"]),
        Target(.jpegExtended,                    cli: "JPEGExtended",            alias: "jpeg-extended"),
        Target(.jpegLossless,                    cli: "JPEGLossless",            alias: "jpeg-lossless"),
        Target(.jpegLosslessSV1,                 cli: "JPEGLosslessSV1",         alias: "jpeg-lossless-sv1"),
        // JPEG 2000 / HTJ2K
        Target(.jpeg2000Lossless,                cli: "JPEG2000Lossless",        alias: "jpeg2000-lossless",       extra: ["j2k-lossless"]),
        Target(.jpeg2000,                        cli: "JPEG2000",                alias: "jpeg2000",                extra: ["jpeg2000-lossy", "j2k"]),
        Target(.jpeg2000Part2Lossless,           cli: "JPEG2000Part2Lossless",   alias: "jpeg2000-part2-lossless", extra: ["j2k-part2-lossless"]),
        Target(.jpeg2000Part2,                   cli: "JPEG2000Part2",           alias: "jpeg2000-part2",          extra: ["j2k-part2"]),
        Target(.htj2kLossless,                   cli: "HTJ2KLossless",           alias: "htj2k-lossless"),
        Target(.htj2kRPCLLossless,               cli: "HTJ2KRPCLLossless",       alias: "htj2k-rpcl",              extra: ["htj2k-lossless-rpcl"]),
        Target(.htj2kLossy,                      cli: "HTJ2K",                   alias: "htj2k",                   extra: ["htj2k-lossy"]),
        // JPEG-LS
        Target(.jpegLSLossless,                  cli: "JPEGLSLossless",          alias: "jpeg-ls-lossless",        extra: ["jpegls", "jpegls-lossless", "jls-lossless"]),
        Target(.jpegLSNearLossless,              cli: "JPEGLSNearLossless",      alias: "jpeg-ls-near-lossless",   extra: ["jpegls-near"]),
        // JPEG XL (encode is lossless-only)
        Target(.jpegXLLossless,                  cli: "JPEGXLLossless",          alias: "jpeg-xl-lossless",        extra: ["jpeg-xl", "jxl", "jxl-lossless", "jpegxl"]),
        // RLE
        Target(.rleLossless,                     cli: "RLELossless",             alias: "rle-lossless",            extra: ["rle"]),
    ]

    /// The CamelCase tokens, in catalog order — drives the CLI Workshop picker.
    public static var cliTokens: [String] { targets.map(\.cliToken) }

    /// The kebab-case aliases, in catalog order — drives the representative catalog picker.
    public static var aliasTokens: [String] { targets.map(\.aliasToken) }

    /// The target transfer syntaxes, in catalog order.
    public static var targetSyntaxes: [TransferSyntax] { targets.map(\.syntax) }

    // MARK: - Parsing

    /// Resolves a user-supplied transfer-syntax token to a convert target.
    ///
    /// Accepts the canonical UID, the CLI CamelCase name, the kebab alias, and the
    /// historical short aliases (case-insensitive). Returns `nil` when the token is
    /// unrecognised *or* names a transfer syntax that is not a valid convert target
    /// (e.g. a video or JPIP syntax).
    public static func parseTarget(_ nameOrUID: String) -> TransferSyntax? {
        let trimmed = nameOrUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Exact UID — only if it is one of our targets.
        if let t = targets.first(where: { $0.syntax.uid == trimmed }) {
            return t.syntax
        }

        let lower = trimmed.lowercased()
        for t in targets {
            if lower == t.cliToken.lowercased()
                || lower == t.aliasToken
                || lower == t.syntax.uid
                || t.extraAliases.contains(lower) {
                return t.syntax
            }
        }
        return nil
    }

    // MARK: - Help / Error Text

    /// One-line `--help` abstract for the `--transfer-syntax` option, listing the
    /// accepted CamelCase target names (kept in sync with ``targets``).
    public static var transferSyntaxOptionHelp: String {
        "Target transfer syntax: " + cliTokens.joined(separator: ", ")
    }

    /// A multi-line, grouped listing of the supported convert targets for error output.
    public static var targetListHelp: String {
        func names(_ predicate: (TransferSyntax) -> Bool) -> String {
            targets.filter { predicate($0.syntax) }.map(\.cliToken).joined(separator: ", ")
        }
        let uncompressed = targets.filter {
            !$0.syntax.isEncapsulated && !$0.syntax.isDeflated
        }.map(\.cliToken) + ["DEFLATE"]
        return """
            Available transfer syntaxes:
              Uncompressed: \(uncompressed.joined(separator: ", "))
              JPEG:         \(names { $0.isJPEG })
              JPEG 2000:    \(names { $0.isJPEG2000 })
              JPEG-LS:      \(names { $0.isJPEGLS })
              JPEG XL:      \(names { $0.isJPEGXL })
              RLE:          \(names { $0.isRLE })
            """
    }

    /// The full error message shown when an unrecognised transfer syntax is requested.
    public static func unknownTargetMessage(_ name: String) -> String {
        "Unknown transfer syntax: \(name).\n" + targetListHelp
    }

    // MARK: - Conversion (input → process → output)

    /// The outcome of a transfer-syntax conversion: the serialised Part-10 bytes plus
    /// metadata for the caller's console/log output.
    public struct Outcome: Sendable {
        /// The complete output DICOM file (preamble + DICM + FMI + transcoded data set).
        public let data: Data
        /// The transfer syntax the source file was encoded in.
        public let sourceSyntax: TransferSyntax
        /// The transfer syntax the output was encoded to.
        public let targetSyntax: TransferSyntax
        /// Whether the pixel data was actually re-encoded (false for a same-syntax no-op).
        public let wasTranscoded: Bool
        /// Whether the conversion was lossless end to end.
        public let isLossless: Bool
        /// The number of private tags removed (0 when `stripPrivate` was false).
        public let strippedPrivateTagCount: Int
    }

    /// Optionally strips private tags from an already-parsed DICOM file, transcodes it
    /// to `target`, and renders a complete Part-10 byte stream.
    ///
    /// This is the shared process + output pipeline used by both the CLI and the app so
    /// their output is byte-identical. The caller owns the environment-specific work:
    /// reading the input bytes from disk and parsing them with the shared
    /// ``DICOMKit/DICOMFile/read(from:force:)`` API (the CLI directly, the app via a
    /// security-scoped URL), then writing ``Outcome/data`` back out and formatting
    /// console messages.
    ///
    /// - Parameters:
    ///   - dicomFile: The already-parsed source DICOM file.
    ///   - target: The transfer syntax to encode to (typically from ``parseTarget(_:)``).
    ///   - stripPrivate: Remove all private (odd-group) tags before transcoding.
    /// - Returns: The serialised output plus conversion metadata.
    /// - Throws: A ``DICOMCore/TranscodingError`` if the transcode is unsupported.
    public static func convertToDICOM(
        dicomFile: DICOMFile,
        to target: TransferSyntax,
        stripPrivate: Bool
    ) throws -> Outcome {
        var dataSet = dicomFile.dataSet

        // Optionally strip private tags.
        var strippedCount = 0
        if stripPrivate {
            let publicTags = dataSet.tags.filter { !$0.isPrivate }
            strippedCount = dataSet.tags.count - publicTags.count
            var filtered = DataSet()
            for tag in publicTags {
                if let element = dataSet[tag] {
                    filtered[tag] = element
                }
            }
            dataSet = filtered
        }

        // Determine the source transfer syntax from the file.
        let sourceSyntaxUID = dicomFile.transferSyntaxUID ?? TransferSyntax.explicitVRLittleEndian.uid
        let sourceSyntax = TransferSyntax.from(uid: sourceSyntaxUID) ?? .explicitVRLittleEndian

        // The in-memory data set is always fully decoded (``DICOMFile/read(from:force:)``
        // inflates a Deflated source), so when the *source* is itself deflated the byte
        // stream the transcoder/deflater consumes is its un-deflated Explicit VR LE form.
        let serializationSyntax: TransferSyntax = sourceSyntax.isDeflated ? .explicitVRLittleEndian : sourceSyntax

        // File Meta Information for the output (shared by both payload paths; never deflated).
        let sopClassUID = dataSet.string(for: .sopClassUID) ?? "1.2.840.10008.5.1.4.1.1.7"
        let sopInstanceUID = dataSet.string(for: .sopInstanceUID) ?? UIDGenerator.generateSOPInstanceUID().value
        let outputFile = DICOMFile.create(
            dataSet: dataSet,
            sopClassUID: sopClassUID,
            sopInstanceUID: sopInstanceUID,
            transferSyntaxUID: target.uid
        )
        let fmiWriter = DICOMWriter(byteOrder: .littleEndian, explicitVR: true)

        // --- Process: build the data-set payload for the target syntax ---
        let dataSetPayload: Data
        let wasTranscoded: Bool
        let isLossless: Bool

        if target.isDeflated {
            // Deflated Explicit VR Little Endian (PS3.5 A.5): serialize the Data Set as
            // Explicit VR LE then DEFLATE-compress the whole stream (the File Meta
            // Information above stays uncompressed). Mirrors ``CompressionManager`` so
            // convert and compress produce equivalent deflate output. Always lossless.
            // The DICOMCore ``TransferSyntaxConverter`` only handles uncompressed and
            // encapsulated/pixel-level codecs — not data-set-level deflate — so this
            // is handled here rather than delegated to ``transcode``.
            let evleWriter = DICOMWriter(byteOrder: .littleEndian, explicitVR: true)
            let plain = dataSet.write(using: evleWriter)
            guard let deflated = plain.deflateCompressed() else {
                throw TranscodingError.encodingFailed(
                    "Failed to deflate the Data Set for \(target.uid). "
                    + "Deflate compression is unavailable on this platform."
                )
            }
            dataSetPayload = deflated
            wasTranscoded = sourceSyntax.uid != target.uid
            isLossless = true
        } else {
            // Transcode pixel data via the DICOMCore converter. Lossless compression
            // config for lossless targets, default for lossy.
            let compressionConfig: DICOMCore.CompressionConfiguration = target.isLossless
                ? .lossless
                : .default
            let converter = TransferSyntaxConverter(
                configuration: TranscodingConfiguration(
                    preferredSyntaxes: [target],
                    allowLossyCompression: !target.isLossless,
                    preservePixelDataFidelity: target.isLossless
                ),
                compressionConfiguration: compressionConfig
            )

            // Serialize the (possibly filtered) data set to bytes in the source syntax.
            let sourceWriter = DICOMWriter(
                byteOrder: serializationSyntax.byteOrder,
                explicitVR: serializationSyntax.isExplicitVR
            )
            let dataSetBytes = dataSet.write(using: sourceWriter)

            let result = try converter.transcode(
                dataSetData: dataSetBytes,
                from: serializationSyntax,
                to: target
            )
            dataSetPayload = result.data
            wasTranscoded = result.wasTranscoded
            isLossless = result.isLossless
        }

        // --- Output: render the complete Part-10 file ---
        var outputData = Data()
        outputData.append(Data(repeating: 0, count: 128))  // Preamble
        outputData.append(contentsOf: "DICM".utf8)          // DICM prefix
        outputData.append(outputFile.fileMetaInformation.write(using: fmiWriter))
        outputData.append(dataSetPayload)

        return Outcome(
            data: outputData,
            sourceSyntax: sourceSyntax,
            targetSyntax: target,
            wasTranscoded: wasTranscoded,
            isLossless: isLossless,
            strippedPrivateTagCount: strippedCount
        )
    }
}
