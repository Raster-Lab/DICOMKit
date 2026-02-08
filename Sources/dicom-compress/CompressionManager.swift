import Foundation
import DICOMCore
import DICOMKit

// MARK: - Compression Info

@available(macOS 10.15, *)
struct CompressionInfo {
    let transferSyntaxUID: String
    let transferSyntaxName: String
    let isCompressed: Bool
    let isLossless: Bool
    let isJPEG: Bool
    let isJPEG2000: Bool
    let isRLE: Bool
    let isDeflated: Bool
    let pixelDataSize: Int?
    let rows: UInt16?
    let columns: UInt16?
    let bitsAllocated: UInt16?
    let bitsStored: UInt16?
    let samplesPerPixel: UInt16?
    let photometricInterpretation: String?
    let numberOfFrames: String?
}

// MARK: - Compression Manager

@available(macOS 10.15, *)
struct CompressionManager {

    // MARK: - Codec Name Mapping

    static let codecMap: [(names: [String], syntax: TransferSyntax)] = [
        (["jpeg", "jpeg-baseline"], .jpegBaseline),
        (["jpeg-extended"], .jpegExtended),
        (["jpeg-lossless"], .jpegLossless),
        (["jpeg-lossless-sv1"], .jpegLosslessSV1),
        (["jpeg2000", "j2k"], .jpeg2000),
        (["jpeg2000-lossless", "j2k-lossless"], .jpeg2000Lossless),
        (["rle"], .rleLossless),
        (["explicit-le"], .explicitVRLittleEndian),
        (["implicit-le"], .implicitVRLittleEndian),
        (["deflate"], .deflatedExplicitVRLittleEndian),
    ]

    static func transferSyntax(for codecName: String) -> TransferSyntax? {
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

    static func transferSyntaxDisplayName(_ syntax: TransferSyntax) -> String {
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
        case TransferSyntax.rleLossless.uid:
            return "RLE Lossless"
        default:
            return syntax.description
        }
    }

    // MARK: - Info

    func getCompressionInfo(path: String) throws -> CompressionInfo {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let file = try DICOMFile.read(from: data)

        let tsUID = file.fileMetaInformation.string(for: .transferSyntaxUID)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")) ?? "1.2.840.10008.1.2"
        let syntax = TransferSyntax.from(uid: tsUID)

        let pixelElement = file.dataSet[.pixelData]
        let pixelDataSize = pixelElement.map { Int($0.length) }

        return CompressionInfo(
            transferSyntaxUID: tsUID,
            transferSyntaxName: syntax.map { CompressionManager.transferSyntaxDisplayName($0) } ?? tsUID,
            isCompressed: syntax?.isEncapsulated ?? false,
            isLossless: syntax?.isLossless ?? true,
            isJPEG: syntax?.isJPEG ?? false,
            isJPEG2000: syntax?.isJPEG2000 ?? false,
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

    func compressFile(
        inputPath: String,
        outputPath: String,
        codec: String,
        quality: CompressionQuality?
    ) throws {
        guard let targetSyntax = CompressionManager.transferSyntax(for: codec) else {
            throw CompressionError.unknownCodec(codec)
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: inputPath))
        let file = try DICOMFile.read(from: data)

        let converter = TransferSyntaxHelper()
        let outputData = try converter.convert(
            dataSet: file.dataSet,
            to: targetSyntax,
            preservePixelData: true
        )

        try outputData.write(to: URL(fileURLWithPath: outputPath))
    }

    // MARK: - Decompress

    func decompressFile(
        inputPath: String,
        outputPath: String,
        syntax: TransferSyntax
    ) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: inputPath))
        let file = try DICOMFile.read(from: data)

        let converter = TransferSyntaxHelper()
        let outputData = try converter.convert(
            dataSet: file.dataSet,
            to: syntax,
            preservePixelData: true
        )

        try outputData.write(to: URL(fileURLWithPath: outputPath))
    }

    // MARK: - Supported Codecs

    static func supportedCodecs() -> [(name: String, syntax: TransferSyntax, aliases: [String])] {
        return codecMap.map { entry in
            (name: entry.names[0], syntax: entry.syntax, aliases: Array(entry.names.dropFirst()))
        }
    }

    // MARK: - DICOM File Discovery

    static func findDICOMFiles(in directory: String, recursive: Bool) throws -> [String] {
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
        if ext.isEmpty || ext == "" {
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
        let metaData = try writeDataSet(fileMeta, writer: metaWriter)

        // File Meta Information Group Length
        let lengthData = metaWriter.serializeUInt32(UInt32(metaData.count))
        let groupLengthElement = DataElement(
            tag: .fileMetaInformationGroupLength,
            vr: .UL,
            length: UInt32(lengthData.count),
            valueData: lengthData
        )
        output.append(try writeElement(groupLengthElement, writer: metaWriter))
        output.append(metaData)

        // Write main dataset with target transfer syntax
        let dataWriter = createWriter(for: targetSyntax)
        let dataSetData = try writeDataSet(dataSet, writer: dataWriter)
        output.append(dataSetData)

        return output
    }

    private func createWriter(for transferSyntax: TransferSyntax) -> DICOMWriter {
        let byteOrder: ByteOrder = transferSyntax.byteOrder
        let explicitVR = transferSyntax.isExplicitVR
        return DICOMWriter(byteOrder: byteOrder, explicitVR: explicitVR)
    }

    private func writeDataSet(_ dataSet: DataSet, writer: DICOMWriter) throws -> Data {
        var output = Data()
        for tag in dataSet.tags.sorted() {
            guard let element = dataSet[tag] else { continue }
            output.append(try writeElement(element, writer: writer))
        }
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

// MARK: - VR Extension (matches dicom-convert pattern)

extension VR {
    var uses32BitLengthForCompress: Bool {
        switch self {
        case .OB, .OD, .OF, .OL, .OW, .SQ, .UC, .UN, .UR, .UT:
            return true
        default:
            return false
        }
    }
}

// MARK: - Errors

enum CompressionError: Error, CustomStringConvertible {
    case unknownCodec(String)
    case fileNotFound(String)
    case directoryNotFound(String)
    case noPixelData
    case conversionFailed(String)

    var description: String {
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
        }
    }
}
