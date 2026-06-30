import Foundation
import DICOMCore

// Shared compression workflow engine for the `dicom-compress` CLI and
// DICOMStudio. Builds on the already-shared CodecRegistry / CompressionQuality /
// TransferSyntax (DICOMCore). Adapters call the public entry points (info /
// compress / decompress, file- and in-memory variants) and format the result;
// the codec dispatch + Part-10 serialization helpers stay internal.

// MARK: - Compression Info

@available(macOS 10.15, *)
public struct CompressionInfo {
    public let transferSyntaxUID: String
    public let transferSyntaxName: String
    public let isCompressed: Bool
    public let isLossless: Bool
    public let isJPEG: Bool
    public let isJPEG2000: Bool
    public let isJPEGLS: Bool
    public let isJPEGXL: Bool
    public let isRLE: Bool
    public let isDeflated: Bool
    public let pixelDataSize: Int?
    public let rows: UInt16?
    public let columns: UInt16?
    public let bitsAllocated: UInt16?
    public let bitsStored: UInt16?
    public let samplesPerPixel: UInt16?
    public let photometricInterpretation: String?
    public let numberOfFrames: String?
}

// MARK: - Compression Manager

@available(macOS 10.15, *)
public struct CompressionManager {

    public init() {}

    // MARK: - Codec Name Mapping

    static let codecMap: [(names: [String], syntax: TransferSyntax)] = [
        (["jpeg", "jpeg-baseline"], .jpegBaseline),
        (["jpeg-extended"], .jpegExtended),
        (["jpeg-lossless"], .jpegLossless),
        (["jpeg-lossless-sv1"], .jpegLosslessSV1),
        (["jpeg2000", "j2k"], .jpeg2000),
        (["jpeg2000-lossless", "j2k-lossless"], .jpeg2000Lossless),
        (["j2k-part2", "jpeg2000-part2"], .jpeg2000Part2),
        (["j2k-part2-lossless", "jpeg2000-part2-lossless"], .jpeg2000Part2Lossless),
        (["htj2k", "htj2k-lossy"], .htj2kLossy),
        (["htj2k-lossless"], .htj2kLossless),
        (["htj2k-rpcl", "htj2k-lossless-rpcl"], .htj2kRPCLLossless),
        (["jpeg-ls-lossless", "jpegls-lossless", "jls-lossless"], .jpegLSLossless),
        (["jpeg-ls", "jpegls", "jls"], .jpegLSNearLossless),
        // JPEG XL ENCODE is lossless-only (JXLSwift Modular, distance 0); the general/
        // lossy JXL .112 and recompression .111 are decode-only / unsupported. So the
        // canonical name is the explicit `jpeg-xl-lossless` — `jpeg-xl`/`jxl` remain
        // accepted aliases but, unlike `jpeg2000`/`htj2k` (whose generic name → lossy),
        // they resolve to the lossless syntax because there is no lossy JXL to produce.
        (["jpeg-xl-lossless", "jpeg-xl", "jxl", "jxl-lossless"], .jpegXLLossless),
        (["rle"], .rleLossless),
        (["explicit-le"], .explicitVRLittleEndian),
        (["implicit-le"], .implicitVRLittleEndian),
        (["deflate"], .deflatedExplicitVRLittleEndian),
    ]

    public static func transferSyntax(for codecName: String) -> TransferSyntax? {
        let lower = codecName.lowercased()
        for entry in codecMap {
            if entry.names.contains(lower) {
                return entry.syntax
            }
        }
        return nil
    }

    static func codecName(for syntax: TransferSyntax) -> String {
        for entry in codecMap {
            if entry.syntax.uid == syntax.uid {
                return entry.names[0]
            }
        }
        return syntax.uid
    }

    public static func transferSyntaxDisplayName(_ syntax: TransferSyntax) -> String {
        switch syntax.uid {
        case TransferSyntax.implicitVRLittleEndian.uid:
            return "Implicit VR Little Endian"
        case TransferSyntax.explicitVRLittleEndian.uid:
            return "Explicit VR Little Endian"
        case TransferSyntax.deflatedExplicitVRLittleEndian.uid:
            return "Deflated Explicit VR Little Endian"
        case TransferSyntax.explicitVRBigEndian.uid:
            return "Explicit VR Big Endian"
        case TransferSyntax.jpegBaseline.uid:
            return "JPEG Baseline (Process 1)"
        case TransferSyntax.jpegExtended.uid:
            return "JPEG Extended (Process 2 & 4)"
        case TransferSyntax.jpegLossless.uid:
            return "JPEG Lossless (Process 14)"
        case TransferSyntax.jpegLosslessSV1.uid:
            return "JPEG Lossless SV1 (Process 14, SV 1)"
        case TransferSyntax.jpeg2000Lossless.uid:
            return "JPEG 2000 Lossless"
        case TransferSyntax.jpeg2000.uid:
            return "JPEG 2000"
        case TransferSyntax.jpeg2000Part2Lossless.uid:
            return "JPEG 2000 Part 2 Lossless"
        case TransferSyntax.jpeg2000Part2.uid:
            return "JPEG 2000 Part 2"
        case TransferSyntax.htj2kLossless.uid:
            return "HTJ2K Lossless"
        case TransferSyntax.htj2kRPCLLossless.uid:
            return "HTJ2K RPCL Lossless"
        case TransferSyntax.htj2kLossy.uid:
            return "HTJ2K"
        case TransferSyntax.jpegLSLossless.uid:
            return "JPEG-LS Lossless"
        case TransferSyntax.jpegLSNearLossless.uid:
            return "JPEG-LS Near-Lossless"
        case TransferSyntax.jpegXLLossless.uid:
            return "JPEG XL Lossless"
        case TransferSyntax.jpegXL.uid:
            return "JPEG XL"
        case TransferSyntax.jpegXLRecompression.uid:
            return "JPEG XL JPEG Recompression"
        case TransferSyntax.rleLossless.uid:
            return "RLE Lossless"
        default:
            return syntax.description
        }
    }

    // MARK: - Info

    public func getCompressionInfo(path: String) throws -> CompressionInfo {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try getCompressionInfo(data: data)
    }

    /// In-memory variant — used by DICOMStudio (reads via a security-scoped URL).
    public func getCompressionInfo(data: Data) throws -> CompressionInfo {
        let file = try DICOMFile.read(from: data)

        let tsUID = file.fileMetaInformation.string(for: .transferSyntaxUID)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")) ?? "1.2.840.10008.1.2"
        let syntax = TransferSyntax.from(uid: tsUID)

        let pixelElement = file.dataSet[.pixelData]

        // Pixel Data size: for native (non-encapsulated) data the element length
        // is the byte count. For encapsulated data the length field is the
        // 0xFFFFFFFF undefined-length sentinel — not a byte count — so report the
        // actual compressed payload, the sum of the encapsulated fragment sizes
        // (the Basic Offset Table is metadata, not pixel bytes). Without this,
        // every compressed file reported the sentinel literally as ≈4.0 GB.
        let pixelDataSize: Int? = pixelElement.map { element in
            if let fragments = element.encapsulatedFragments {
                return fragments.reduce(0) { $0 + $1.count }
            }
            // Defend against a stray undefined-length sentinel with no parsed
            // fragments (malformed input): fall back to the actual value bytes.
            if element.length == 0xFFFFFFFF {
                return element.valueData.count
            }
            return Int(element.length)
        }

        return CompressionInfo(
            transferSyntaxUID: tsUID,
            transferSyntaxName: syntax.map { CompressionManager.transferSyntaxDisplayName($0) } ?? tsUID,
            isCompressed: syntax?.isEncapsulated ?? false,
            isLossless: syntax?.isLossless ?? true,
            isJPEG: syntax?.isJPEG ?? false,
            isJPEG2000: syntax?.isJPEG2000 ?? false,
            isJPEGLS: syntax?.isJPEGLS ?? false,
            isJPEGXL: syntax?.isJPEGXL ?? false,
            isRLE: syntax?.isRLE ?? false,
            isDeflated: syntax?.isDeflated ?? false,
            pixelDataSize: pixelDataSize,
            rows: file.dataSet.uint16(for: .rows),
            columns: file.dataSet.uint16(for: .columns),
            bitsAllocated: file.dataSet.uint16(for: .bitsAllocated),
            bitsStored: file.dataSet.uint16(for: .bitsStored),
            samplesPerPixel: file.dataSet.uint16(for: .samplesPerPixel),
            photometricInterpretation: file.dataSet.string(for: .photometricInterpretation)?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")),
            numberOfFrames: file.dataSet.string(for: .numberOfFrames)?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
        )
    }

    // MARK: - Compress

    public func compressFile(
        inputPath: String,
        outputPath: String,
        codec: String,
        quality: CompressionQuality?
    ) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: inputPath))
        let outputData = try compressData(data, codec: codec, quality: quality)
        try outputData.write(to: URL(fileURLWithPath: outputPath))
    }

    /// In-memory compress (no file I/O) — used by DICOMStudio, which writes the
    /// result through its sandbox-aware OutputAccess path.
    public func compressData(_ inputData: Data, codec: String, quality: CompressionQuality?) throws -> Data {
        guard let targetSyntax = CompressionManager.transferSyntax(for: codec) else {
            throw CompressionError.unknownCodec(codec)
        }

        let file = try DICOMFile.read(from: inputData)

        // Resolve the source transfer syntax so we can decide whether this
        // call is an actual compression, a recompression (transcode), a
        // decompression, or just a UID rewrite for two uncompressed forms.
        let sourceSyntax = CompressionManager.resolveSourceTransferSyntax(file: file)

        var workingDataSet = file.dataSet

        // Actually invoke the codec when the target requires encapsulated
        // (compressed) pixel data. The prior implementation only ever
        // rewrote the Transfer Syntax UID, leaving uncompressed bytes in
        // place — every `--codec` flag was silently a no-op for 13/13
        // codecs (output size ≈ input size). See dicom-compress bug
        // report (2026-05-11).
        if targetSyntax.isEncapsulated && !sourceSyntax.isEncapsulated {
            try CompressionManager.encodePixelDataInPlace(
                dataSet: &workingDataSet,
                targetSyntax: targetSyntax,
                quality: quality
            )
        } else if targetSyntax.isEncapsulated && sourceSyntax.isEncapsulated
                  && targetSyntax.uid != sourceSyntax.uid {
            // Recompression: decompress source then encode to target.
            try CompressionManager.transcodeEncapsulatedInPlace(
                dataSet: &workingDataSet,
                sourceSyntax: sourceSyntax,
                targetSyntax: targetSyntax,
                quality: quality
            )
        } else if !targetSyntax.isEncapsulated && sourceSyntax.isEncapsulated {
            // Decompress: decode pixel data into uncompressed bytes.
            // Callers wanting decompression should generally use the
            // `decompress` subcommand, but `compress --codec explicit-le`
            // (and similar) reach here and must do the right thing.
            try CompressionManager.decodePixelDataInPlace(
                dataSet: &workingDataSet,
                sourceSyntax: sourceSyntax,
                targetSyntax: targetSyntax
            )
        }
        // else: both source and target are uncompressed (or syntaxes are
        // identical) — UID rewrite via TransferSyntaxHelper is correct.

        let converter = TransferSyntaxHelper()
        return try converter.convert(
            dataSet: workingDataSet,
            to: targetSyntax,
            preservePixelData: true
        )
    }

    // MARK: - Codec dispatch helpers (v9.1 fix)

    /// Resolves the source transfer syntax from a parsed DICOM file's
    /// File Meta Information. Falls back to Explicit VR Little Endian
    /// when the UID is missing (matches DICOMFile.read's default).
    static func resolveSourceTransferSyntax(file: DICOMFile) -> TransferSyntax {
        let sourceUID = file.fileMetaInformation.string(for: .transferSyntaxUID)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
            ?? TransferSyntax.explicitVRLittleEndian.uid

        // Try to find the canonical TransferSyntax by UID. If the UID
        // isn't one of the known constants, build a synthetic one with
        // sensible defaults — encapsulated flag is critical for branching
        // so we infer it from the standard UID prefix conventions.
        if let known = TransferSyntax.fromKnownUID(sourceUID) {
            return known
        }
        let isEncap = !TransferSyntax.uncompressedUIDs.contains(sourceUID)
        return TransferSyntax(
            uid: sourceUID,
            isExplicitVR: true,
            byteOrder: .littleEndian,
            isEncapsulated: isEncap
        )
    }

    /// Compresses uncompressed pixel data using the encoder registered
    /// for the target transfer syntax UID, then replaces the data set's
    /// PixelData element with an encapsulated pixel data element holding
    /// the compressed fragments.
    ///
    /// Bug-fix for the previous behaviour where compressFile only
    /// rewrote the Transfer Syntax UID without invoking any encoder.
    static func encodePixelDataInPlace(
        dataSet: inout DataSet,
        targetSyntax: TransferSyntax,
        quality: CompressionQuality?
    ) throws {
        guard let encoder = CodecRegistry.shared.encoder(for: targetSyntax.uid) else {
            throw CompressionError.encoderNotAvailable(targetSyntax.uid)
        }
        guard let pixelDataElement = dataSet[.pixelData] else {
            throw CompressionError.noPixelData
        }
        // Source pixel data must be uncompressed bytes here (caller
        // guarantees source !isEncapsulated). The encoder takes the
        // contiguous byte buffer for all frames concatenated.
        let uncompressedBytes = pixelDataElement.valueData

        let descriptor = try buildPixelDataDescriptor(from: dataSet)

        let configuration: CompressionConfiguration = {
            if targetSyntax.isLossless {
                return .lossless
            }
            // For lossy paths honour the user's --quality if supplied.
            if let q = quality {
                return CompressionConfiguration(quality: q, speed: .balanced)
            }
            return .default
        }()

        guard encoder.canEncode(with: configuration, descriptor: descriptor) else {
            throw CompressionError.unsupportedPixelDataConfiguration(
                "Encoder for \(targetSyntax.uid) cannot handle "
                + "bitsAllocated=\(descriptor.bitsAllocated), "
                + "samplesPerPixel=\(descriptor.samplesPerPixel), "
                + "photometricInterpretation=\(descriptor.photometricInterpretation.rawValue)"
            )
        }

        let compressedFrames = try encoder.encode(
            uncompressedBytes,
            descriptor: descriptor,
            configuration: configuration
        )

        let offsetTable = buildBasicOffsetTable(for: compressedFrames)
        dataSet[.pixelData] = DataElement(
            tag: .pixelData,
            vr: .OB,                         // Encapsulated pixel data is always OB
            length: 0xFFFFFFFF,              // Undefined length sentinel
            valueData: Data(),
            encapsulatedFragments: compressedFrames,
            encapsulatedOffsetTable: offsetTable
        )
    }

    /// Decodes encapsulated pixel data back into uncompressed bytes,
    /// then replaces the PixelData element with an un-encapsulated form
    /// suitable for the (uncompressed) target syntax.
    static func decodePixelDataInPlace(
        dataSet: inout DataSet,
        sourceSyntax: TransferSyntax,
        targetSyntax: TransferSyntax
    ) throws {
        guard let codec = CodecRegistry.shared.codec(for: sourceSyntax.uid) else {
            throw CompressionError.decoderNotAvailable(sourceSyntax.uid)
        }
        guard let pixelDataElement = dataSet[.pixelData] else {
            throw CompressionError.noPixelData
        }
        guard let fragments = pixelDataElement.encapsulatedFragments else {
            throw CompressionError.conversionFailed(
                "Source declares encapsulated transfer syntax \(sourceSyntax.uid) "
                + "but PixelData element has no encapsulated fragments"
            )
        }

        let descriptor = try buildPixelDataDescriptor(from: dataSet)

        // Decode each frame, concatenate. Most codecs produce one fragment
        // per frame, but the spec permits multi-fragment frames; we
        // delegate that responsibility to the codec via decode(...) which
        // handles both cases.
        var combined = Data()
        combined.reserveCapacity(descriptor.totalBytes)
        if fragments.count == descriptor.numberOfFrames {
            for (frameIndex, frame) in fragments.enumerated() {
                let frameBytes = try codec.decodeFrame(
                    frame,
                    descriptor: descriptor,
                    frameIndex: frameIndex
                )
                combined.append(frameBytes)
            }
        } else {
            // Fall back to the multi-frame decode entry point with the
            // contiguous concatenation of all fragments.
            var concatenated = Data()
            for frame in fragments { concatenated.append(frame) }
            combined = try codec.decode(concatenated, descriptor: descriptor)
        }

        // Even byte length padding per DICOM PS3.5 Section 7.1.
        if combined.count % 2 != 0 {
            combined.append(0x00)
        }

        dataSet[.pixelData] = DataElement(
            tag: .pixelData,
            vr: descriptor.bitsAllocated > 8 ? .OW : .OB,
            length: UInt32(combined.count),
            valueData: combined
        )
    }

    /// Recompression path — decode then re-encode. Operates only on
    /// the PixelData element in-place.
    static func transcodeEncapsulatedInPlace(
        dataSet: inout DataSet,
        sourceSyntax: TransferSyntax,
        targetSyntax: TransferSyntax,
        quality: CompressionQuality?
    ) throws {
        // Step 1: decode to uncompressed bytes.
        try decodePixelDataInPlace(
            dataSet: &dataSet,
            sourceSyntax: sourceSyntax,
            targetSyntax: TransferSyntax.explicitVRLittleEndian
        )
        // Step 2: encode to target.
        try encodePixelDataInPlace(
            dataSet: &dataSet,
            targetSyntax: targetSyntax,
            quality: quality
        )
    }

    /// Builds a PixelDataDescriptor from a parsed DataSet. Mirrors
    /// DICOMCore.TransferSyntaxConverter.extractPixelDataDescriptor
    /// (which is private to that type).
    static func buildPixelDataDescriptor(from dataSet: DataSet) throws -> PixelDataDescriptor {
        guard let rows = dataSet.uint16(for: .rows),
              let columns = dataSet.uint16(for: .columns),
              let bitsAllocated = dataSet.uint16(for: .bitsAllocated),
              let bitsStored = dataSet.uint16(for: .bitsStored),
              let highBit = dataSet.uint16(for: .highBit) else {
            throw CompressionError.conversionFailed(
                "Missing required pixel data attributes "
                + "(rows / columns / bitsAllocated / bitsStored / highBit)"
            )
        }
        let pixelRepresentation = dataSet.uint16(for: .pixelRepresentation) ?? 0
        let samplesPerPixel = dataSet.uint16(for: .samplesPerPixel) ?? 1
        let planarConfiguration = dataSet.uint16(for: .planarConfiguration) ?? 0

        let numberOfFrames: Int
        if let nfStr = dataSet.string(for: .numberOfFrames)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")),
           let nfVal = Int(nfStr), nfVal > 0 {
            numberOfFrames = nfVal
        } else {
            numberOfFrames = 1
        }

        let piRaw = dataSet.string(for: .photometricInterpretation)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
        let photometricInterpretation: PhotometricInterpretation = {
            if let raw = piRaw, let pi = PhotometricInterpretation(rawValue: raw) {
                return pi
            }
            return samplesPerPixel == 1 ? .monochrome2 : .rgb
        }()

        return PixelDataDescriptor(
            rows: Int(rows),
            columns: Int(columns),
            numberOfFrames: numberOfFrames,
            bitsAllocated: Int(bitsAllocated),
            bitsStored: Int(bitsStored),
            highBit: Int(highBit),
            isSigned: pixelRepresentation == 1,
            samplesPerPixel: Int(samplesPerPixel),
            photometricInterpretation: photometricInterpretation,
            planarConfiguration: Int(planarConfiguration)
        )
    }

    /// Builds a Basic Offset Table (BOT) for an encapsulated pixel data
    /// element. Per DICOM PS3.5 A.4, the BOT is an array of UInt32
    /// offsets from the first byte of the first fragment (i.e. just
    /// after the BOT item) to the first byte of each frame's first
    /// fragment. We emit one offset per frame.
    static func buildBasicOffsetTable(for fragments: [Data]) -> [UInt32] {
        var offsets: [UInt32] = []
        offsets.reserveCapacity(fragments.count)
        var current: UInt32 = 0
        for fragment in fragments {
            offsets.append(current)
            // 8 bytes for the Item tag + length, then the fragment bytes.
            current = current &+ 8 &+ UInt32(fragment.count)
        }
        return offsets
    }

    // MARK: - Decompress

    public func decompressFile(
        inputPath: String,
        outputPath: String,
        syntax: TransferSyntax
    ) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: inputPath))
        let outputData = try decompressData(data, syntax: syntax)
        try outputData.write(to: URL(fileURLWithPath: outputPath))
    }

    /// In-memory decompress (no file I/O) — used by DICOMStudio.
    public func decompressData(_ inputData: Data, syntax: TransferSyntax) throws -> Data {
        let file = try DICOMFile.read(from: inputData)

        let sourceSyntax = CompressionManager.resolveSourceTransferSyntax(file: file)
        var workingDataSet = file.dataSet

        if sourceSyntax.isEncapsulated && !syntax.isEncapsulated {
            // Source compressed → target uncompressed: actually decode.
            try CompressionManager.decodePixelDataInPlace(
                dataSet: &workingDataSet,
                sourceSyntax: sourceSyntax,
                targetSyntax: syntax
            )
        }
        // else: source already uncompressed OR target is encapsulated
        // (caller misuse) — UID rewrite via TransferSyntaxHelper.

        let converter = TransferSyntaxHelper()
        return try converter.convert(
            dataSet: workingDataSet,
            to: syntax,
            preservePixelData: true
        )
    }

    // MARK: - Supported Codecs

    public static func supportedCodecs() -> [(name: String, syntax: TransferSyntax, aliases: [String])] {
        return codecMap.map { entry in
            (name: entry.names[0], syntax: entry.syntax, aliases: Array(entry.names.dropFirst()))
        }
    }

    // MARK: - DICOM File Discovery

    public static func findDICOMFiles(in directory: String, recursive: Bool) throws -> [String] {
        let fm = FileManager.default
        var files: [String] = []

        if recursive {
            guard let enumerator = fm.enumerator(atPath: directory) else {
                throw CompressionError.directoryNotFound(directory)
            }
            while let path = enumerator.nextObject() as? String {
                let fullPath = (directory as NSString).appendingPathComponent(path)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue {
                    if isDICOMFile(fullPath) {
                        files.append(fullPath)
                    }
                }
            }
        } else {
            let contents = try fm.contentsOfDirectory(atPath: directory)
            for name in contents {
                let fullPath = (directory as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue {
                    if isDICOMFile(fullPath) {
                        files.append(fullPath)
                    }
                }
            }
        }

        return files.sorted()
    }

    private static func isDICOMFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        if ext == "dcm" || ext == "dicom" || ext == "dic" {
            return true
        }
        // Try to detect DICOM files without extension by checking for DICM magic
        if ext.isEmpty {
            guard let handle = FileHandle(forReadingAtPath: path) else { return false }
            defer { handle.closeFile() }
            let header = handle.readData(ofLength: 132)
            if header.count >= 132 {
                let prefix = header.subdata(in: 128..<132)
                return String(data: prefix, encoding: .ascii) == "DICM"
            }
        }
        return false
    }
}

// MARK: - Transfer Syntax Helper (matches dicom-convert Converter pattern)

@available(macOS 10.15, *)
struct TransferSyntaxHelper {
    func convert(
        dataSet: DataSet,
        to targetSyntax: TransferSyntax,
        preservePixelData: Bool = true
    ) throws -> Data {
        var fileMeta = DataSet()

        // File Meta Information Version
        let versionTag = Tag.fileMetaInformationVersion
        fileMeta[versionTag] = DataElement(
            tag: versionTag,
            vr: .OB,
            length: 2,
            valueData: Data([0x00, 0x01])
        )

        // Media Storage SOP Class UID
        if let sopClassUID = dataSet.string(for: .sopClassUID),
           let data = sopClassUID.data(using: .ascii) {
            fileMeta[.mediaStorageSOPClassUID] = DataElement(
                tag: .mediaStorageSOPClassUID,
                vr: .UI,
                length: UInt32(data.count),
                valueData: data
            )
        }

        // Media Storage SOP Instance UID
        if let sopInstanceUID = dataSet.string(for: .sopInstanceUID),
           let data = sopInstanceUID.data(using: .ascii) {
            fileMeta[.mediaStorageSOPInstanceUID] = DataElement(
                tag: .mediaStorageSOPInstanceUID,
                vr: .UI,
                length: UInt32(data.count),
                valueData: data
            )
        }

        // Transfer Syntax UID
        if let tsData = targetSyntax.uid.data(using: .ascii) {
            fileMeta[.transferSyntaxUID] = DataElement(
                tag: .transferSyntaxUID,
                vr: .UI,
                length: UInt32(tsData.count),
                valueData: tsData
            )
        }

        // Implementation Class UID
        if let implData = "1.2.826.0.1.3680043.10.1".data(using: .ascii) {
            fileMeta[.implementationClassUID] = DataElement(
                tag: .implementationClassUID,
                vr: .UI,
                length: UInt32(implData.count),
                valueData: implData
            )
        }

        // Implementation Version Name
        if let versionData = "DICOMKIT-1.0".data(using: .ascii) {
            fileMeta[.implementationVersionName] = DataElement(
                tag: .implementationVersionName,
                vr: .SH,
                length: UInt32(versionData.count),
                valueData: versionData
            )
        }

        // Build output
        var output = Data()

        // Preamble + DICM prefix
        output.append(Data(repeating: 0, count: 128))
        output.append(contentsOf: "DICM".utf8)

        // Write file meta information (always Explicit VR Little Endian)
        let metaWriter = DICOMWriter(byteOrder: .littleEndian, explicitVR: true)
        let metaData = writeDataSet(fileMeta, writer: metaWriter)

        // File Meta Information Group Length
        let lengthData = metaWriter.serializeUInt32(UInt32(metaData.count))
        let groupLengthElement = DataElement(
            tag: .fileMetaInformationGroupLength,
            vr: .UL,
            length: UInt32(lengthData.count),
            valueData: lengthData
        )
        output.append(metaWriter.serializeElement(groupLengthElement))
        output.append(metaData)

        // Write main dataset with target transfer syntax. A Deflated Explicit VR
        // Little Endian target (PS3.5 A.5) serializes the Data Set as Explicit VR
        // LE and then DEFLATE-compresses it — the File Meta Information above stays
        // uncompressed. Without this the file was labeled 1.2.840.10008.1.2.1.99
        // but carried raw (un-deflated) bytes, so readers failed with
        // "Failed to decompress deflated data".
        let dataWriter = createWriter(for: targetSyntax)
        var dataSetData = try writeDataSet(dataSet, writer: dataWriter)
        if targetSyntax.isDeflated {
            guard let deflated = dataSetData.deflateCompressed() else {
                throw CompressionError.conversionFailed(
                    "Failed to deflate the Data Set for \(targetSyntax.uid). "
                    + "Deflate compression is unavailable on this platform."
                )
            }
            dataSetData = deflated
        }
        output.append(dataSetData)

        return output
    }

    private func createWriter(for transferSyntax: TransferSyntax) -> DICOMWriter {
        let byteOrder: ByteOrder = transferSyntax.byteOrder
        let explicitVR = transferSyntax.isExplicitVR
        return DICOMWriter(byteOrder: byteOrder, explicitVR: explicitVR)
    }

    private func writeDataSet(_ dataSet: DataSet, writer: DICOMWriter) -> Data {
        var output = Data()
        for tag in dataSet.tags.sorted() {
            guard let element = dataSet[tag] else { continue }
            // Encapsulated (compressed) PixelData needs the BOT + Item-tagged
            // fragment + Sequence Delimitation structure, which the shared
            // DICOMWriter does not emit (it skips undefined-length values), so it
            // keeps its dedicated serializer.
            if element.tag == .pixelData
                && element.encapsulatedFragments != nil {
                output.append(serializeEncapsulatedPixelData(element, writer: writer))
                continue
            }
            // Everything else goes through the library's real element serializer.
            // The previous bespoke writer dumped each element's raw `valueData`
            // under the *target* framing — which corrupted sequences carried over
            // from an Implicit VR source (their bytes are implicit-encoded) and
            // truncated the declared length of >64 KB 16-bit-VR elements, both of
            // which desynced the reader so it stopped before PixelData ("No pixel
            // data found in DICOM file"). DICOMWriter re-encodes sequences from
            // their parsed items; the sanitizer keeps oversized short-VR values
            // representable under Explicit VR.
            output.append(writer.serializeElement(
                sanitizedForExplicitVR(element, explicitVR: writer.explicitVR)))
        }
        return output
    }

    /// Promotes an element whose value exceeds the 0xFFFF that a 16-bit Explicit
    /// VR length field can hold — legal under Implicit VR's 32-bit length — to UN,
    /// which carries a 32-bit length. Without this, transcoding Implicit→Explicit
    /// VR either silently truncated the declared length (desyncing every later
    /// element, including PixelData) or trapped on `UInt16(overflow)`.
    private func sanitizedForExplicitVR(_ element: DataElement, explicitVR: Bool) -> DataElement {
        guard explicitVR, element.vr != .SQ, !element.vr.uses32BitLength,
              element.valueData.count > 0xFFFF else { return element }
        return DataElement(tag: element.tag, vr: .UN,
                           length: UInt32(element.valueData.count),
                           valueData: element.valueData)
    }

    /// Serialises an encapsulated PixelData element per DICOM PS3.5 A.4
    /// (Encapsulation of Encoded Pixel Data). Layout:
    ///
    ///   (7FE0,0010) OB  undefined-length
    ///   (FFFE,E000) Item  <BOT length>  <BOT bytes>
    ///   (FFFE,E000) Item  <frag-1 length>  <frag-1 bytes>
    ///   ...
    ///   (FFFE,E000) Item  <frag-N length>  <frag-N bytes>
    ///   (FFFE,E0DD) Sequence Delimitation Item, length 0
    ///
    /// All length fields are 4-byte little-endian unsigned. Encapsulated
    /// pixel data is always written with Explicit VR Little Endian per
    /// PS3.5; the `writer` byte order is honoured for completeness.
    private func serializeEncapsulatedPixelData(
        _ element: DataElement,
        writer: DICOMWriter
    ) -> Data {
        var output = Data()

        // PixelData element header: tag(7FE0,0010) + VR(OB) + 2 reserved
        // + undefined length (0xFFFFFFFF).
        output.append(writer.serializeUInt16(element.tag.group))
        output.append(writer.serializeUInt16(element.tag.element))
        output.append(contentsOf: "OB".utf8)
        output.append(contentsOf: [0x00, 0x00])
        output.append(writer.serializeUInt32(0xFFFFFFFF))

        // Basic Offset Table (BOT) Item: (FFFE,E000) + length + offsets.
        let offsetTable = element.encapsulatedOffsetTable ?? []
        var botBytes = Data()
        for offset in offsetTable {
            botBytes.append(writer.serializeUInt32(offset))
        }
        output.append(writer.serializeUInt16(0xFFFE))
        output.append(writer.serializeUInt16(0xE000))
        output.append(writer.serializeUInt32(UInt32(botBytes.count)))
        output.append(botBytes)

        // Fragment items.
        if let fragments = element.encapsulatedFragments {
            for fragment in fragments {
                output.append(writer.serializeUInt16(0xFFFE))
                output.append(writer.serializeUInt16(0xE000))
                // Fragment bytes must be even-length per PS3.5; pad
                // with a trailing 0x00 if the codec returned odd-sized
                // data (rare but spec-required).
                let padded: Data
                if fragment.count % 2 != 0 {
                    var p = fragment
                    p.append(0x00)
                    padded = p
                } else {
                    padded = fragment
                }
                output.append(writer.serializeUInt32(UInt32(padded.count)))
                output.append(padded)
            }
        }

        // Sequence Delimitation Item (FFFE,E0DD) length 0.
        output.append(writer.serializeUInt16(0xFFFE))
        output.append(writer.serializeUInt16(0xE0DD))
        output.append(writer.serializeUInt32(0))

        return output
    }

    private func writeElement(_ element: DataElement, writer: DICOMWriter) throws -> Data {
        var output = Data()

        // Tag
        output.append(writer.serializeUInt16(element.tag.group))
        output.append(writer.serializeUInt16(element.tag.element))

        let vr = element.vr
        let valueData = element.valueData

        if writer.explicitVR {
            output.append(contentsOf: vr.rawValue.utf8)
            if vr.uses32BitLength {
                output.append(contentsOf: [0x00, 0x00])
                output.append(writer.serializeUInt32(UInt32(valueData.count)))
            } else {
                let length = min(valueData.count, 0xFFFF)
                output.append(writer.serializeUInt16(UInt16(length)))
            }
        } else {
            output.append(writer.serializeUInt32(UInt32(valueData.count)))
        }

        output.append(valueData)
        return output
    }
}

// MARK: - Errors

public enum CompressionError: Error, CustomStringConvertible {
    case unknownCodec(String)
    case fileNotFound(String)
    case directoryNotFound(String)
    case noPixelData
    case conversionFailed(String)
    case encoderNotAvailable(String)
    case decoderNotAvailable(String)
    case unsupportedPixelDataConfiguration(String)
    case invalidQuality(String)

    public var description: String {
        switch self {
        case .unknownCodec(let name):
            return "Unknown codec '\(name)'. Use 'dicom-compress compress --help' for supported codecs."
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .noPixelData:
            return "No pixel data found in DICOM file"
        case .conversionFailed(let reason):
            return "Conversion failed: \(reason)"
        case .encoderNotAvailable(let uid):
            return "No encoder registered for transfer syntax \(uid). "
                + "The codec may be decode-only or unsupported on this platform."
        case .decoderNotAvailable(let uid):
            return "No decoder registered for transfer syntax \(uid). "
                + "Cannot decompress source pixel data."
        case .unsupportedPixelDataConfiguration(let detail):
            return "Encoder rejected pixel-data configuration: \(detail)"
        case .invalidQuality(let value):
            return "Invalid --quality value '\(value)'. "
                + "Use maximum / high / medium / low, or a number in 0.0...1.0."
        }
    }
}

// MARK: - TransferSyntax convenience for source-UID resolution

extension TransferSyntax {
    /// UIDs of the three uncompressed transfer syntaxes per DICOM PS3.5.
    /// Used to decide whether a parsed file's transfer syntax is
    /// encapsulated when only the UID string is available.
    fileprivate static let uncompressedUIDs: Set<String> = [
        TransferSyntax.implicitVRLittleEndian.uid,
        TransferSyntax.explicitVRLittleEndian.uid,
        TransferSyntax.explicitVRBigEndian.uid,
        TransferSyntax.deflatedExplicitVRLittleEndian.uid,
    ]

    /// Returns the canonical TransferSyntax instance for a given UID
    /// string, if it matches one of the standard transfer syntaxes that
    /// the dicom-compress codec map recognises. Looks up via the
    /// CompressionManager's codecMap entries so this stays in sync with
    /// supported codecs.
    fileprivate static func fromKnownUID(_ uid: String) -> TransferSyntax? {
        for entry in CompressionManager.codecMap where entry.syntax.uid == uid {
            return entry.syntax
        }
        return nil
    }
}
