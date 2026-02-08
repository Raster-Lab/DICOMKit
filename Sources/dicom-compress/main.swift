import Foundation
import ArgumentParser
import DICOMCore
import DICOMKit
import DICOMDictionary

@available(macOS 10.15, *)
struct DICOMCompress: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-compress",
        abstract: "DICOM compression and decompression utilities",
        discussion: """
            Compress, decompress, and analyze DICOM file transfer syntaxes.
            
            Examples:
              dicom-compress info file.dcm
              dicom-compress info file.dcm --json
              dicom-compress compress input.dcm --output output.dcm --codec jpeg-lossless
              dicom-compress compress input.dcm --output output.dcm --codec jpeg2000 --quality high
              dicom-compress decompress compressed.dcm --output uncompressed.dcm
              dicom-compress decompress compressed.dcm --output uncompressed.dcm --syntax explicit-le
              dicom-compress batch input_dir/ --output output_dir/ --codec jpeg-lossless --recursive
              dicom-compress batch input_dir/ --output output_dir/ --decompress --recursive
            """,
        version: "1.3.3",
        subcommands: [Compress.self, Decompress.self, Info.self, Batch.self],
        defaultSubcommand: Info.self
    )
}

// MARK: - Compress Subcommand

@available(macOS 10.15, *)
extension DICOMCompress {
    struct Compress: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Compress a DICOM file using a specified codec",
            discussion: """
                Compress uncompressed DICOM images to various codecs.
                
                Supported codecs:
                  jpeg, jpeg-baseline    JPEG Baseline (lossy, 8-bit)
                  jpeg-extended          JPEG Extended (lossy, 8/12-bit)
                  jpeg-lossless          JPEG Lossless (Process 14)
                  jpeg-lossless-sv1      JPEG Lossless SV1 (default lossless JPEG)
                  jpeg2000, j2k          JPEG 2000 (lossy)
                  jpeg2000-lossless,     JPEG 2000 Lossless
                    j2k-lossless
                  rle                    RLE Lossless
                  deflate                Deflated Explicit VR Little Endian
                  explicit-le            Explicit VR Little Endian
                  implicit-le            Implicit VR Little Endian
                
                Examples:
                  dicom-compress compress input.dcm --output output.dcm --codec jpeg-lossless
                  dicom-compress compress input.dcm --output output.dcm --codec jpeg2000 --quality high
                  dicom-compress compress input.dcm --output output.dcm --codec jpeg-baseline --quality 0.85
                """
        )

        @Argument(help: "Input DICOM file path")
        var input: String

        @Option(name: .shortAndLong, help: "Output DICOM file path")
        var output: String

        @Option(name: .shortAndLong, help: "Target codec (e.g., jpeg-lossless, jpeg2000, rle)")
        var codec: String

        @Option(name: .shortAndLong, help: "Quality: maximum, high, medium, low, or a value 0.0-1.0")
        var quality: String?

        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false

        mutating func validate() throws {
            guard FileManager.default.fileExists(atPath: input) else {
                throw ValidationError("Input file not found: \(input)")
            }
            guard CompressionManager.transferSyntax(for: codec) != nil else {
                let supported = CompressionManager.supportedCodecs().map { $0.name }.joined(separator: ", ")
                throw ValidationError("Unknown codec '\(codec)'. Supported: \(supported)")
            }
        }

        mutating func run() throws {
            let manager = CompressionManager()

            if verbose {
                fprintln("Compressing: \(input)")
                fprintln("Codec: \(codec)")
                if let q = quality {
                    fprintln("Quality: \(q)")
                }
            }

            let qualityPreset = try parseQuality(quality)

            do {
                try manager.compressFile(
                    inputPath: input,
                    outputPath: output,
                    codec: codec,
                    quality: qualityPreset
                )
                fprintln("Compressed: \(input) → \(output)")

                if verbose {
                    let inputSize = try FileManager.default.attributesOfItem(atPath: input)[.size] as? Int ?? 0
                    let outputSize = try FileManager.default.attributesOfItem(atPath: output)[.size] as? Int ?? 0
                    fprintln("Input size:  \(formatBytes(inputSize))")
                    fprintln("Output size: \(formatBytes(outputSize))")
                    if inputSize > 0 {
                        let ratio = Double(outputSize) / Double(inputSize) * 100.0
                        fprintln("Ratio: \(String(format: "%.1f%%", ratio))")
                    }
                }
            } catch {
                fprintln("Error: \(error)")
                throw ExitCode.failure
            }
        }
    }
}

// MARK: - Decompress Subcommand

@available(macOS 10.15, *)
extension DICOMCompress {
    struct Decompress: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Decompress a compressed DICOM file",
            discussion: """
                Decompress compressed DICOM images to an uncompressed transfer syntax.
                
                Target syntaxes:
                  explicit-le   Explicit VR Little Endian (default)
                  implicit-le   Implicit VR Little Endian
                
                Examples:
                  dicom-compress decompress compressed.dcm --output uncompressed.dcm
                  dicom-compress decompress compressed.dcm --output uncompressed.dcm --syntax explicit-le
                """
        )

        @Argument(help: "Input DICOM file path")
        var input: String

        @Option(name: .shortAndLong, help: "Output DICOM file path")
        var output: String

        @Option(name: .shortAndLong, help: "Target syntax: explicit-le (default), implicit-le")
        var syntax: String = "explicit-le"

        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false

        mutating func validate() throws {
            guard FileManager.default.fileExists(atPath: input) else {
                throw ValidationError("Input file not found: \(input)")
            }
            guard CompressionManager.transferSyntax(for: syntax) != nil else {
                throw ValidationError("Unknown syntax '\(syntax)'. Use explicit-le or implicit-le.")
            }
        }

        mutating func run() throws {
            let manager = CompressionManager()
            let targetSyntax = CompressionManager.transferSyntax(for: syntax)!

            if verbose {
                fprintln("Decompressing: \(input)")
                fprintln("Target syntax: \(CompressionManager.transferSyntaxDisplayName(targetSyntax))")
            }

            do {
                try manager.decompressFile(
                    inputPath: input,
                    outputPath: output,
                    syntax: targetSyntax
                )
                fprintln("Decompressed: \(input) → \(output)")

                if verbose {
                    let inputSize = try FileManager.default.attributesOfItem(atPath: input)[.size] as? Int ?? 0
                    let outputSize = try FileManager.default.attributesOfItem(atPath: output)[.size] as? Int ?? 0
                    fprintln("Input size:  \(formatBytes(inputSize))")
                    fprintln("Output size: \(formatBytes(outputSize))")
                }
            } catch {
                fprintln("Error: \(error)")
                throw ExitCode.failure
            }
        }
    }
}

// MARK: - Info Subcommand

@available(macOS 10.15, *)
extension DICOMCompress {
    struct Info: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show compression information about a DICOM file",
            discussion: """
                Display transfer syntax, compression status, and image parameters.
                
                Examples:
                  dicom-compress info file.dcm
                  dicom-compress info file.dcm --json
                """
        )

        @Argument(help: "DICOM file path")
        var input: String

        @Flag(name: .long, help: "Output as JSON")
        var json: Bool = false

        mutating func validate() throws {
            guard FileManager.default.fileExists(atPath: input) else {
                throw ValidationError("File not found: \(input)")
            }
        }

        mutating func run() throws {
            let manager = CompressionManager()

            do {
                let info = try manager.getCompressionInfo(path: input)

                if json {
                    try printJSON(info)
                } else {
                    printText(info)
                }
            } catch {
                fprintln("Error reading file: \(error)")
                throw ExitCode.failure
            }
        }

        private func printText(_ info: CompressionInfo) {
            print("File: \(input)")
            print("Transfer Syntax: \(info.transferSyntaxName)")
            print("Transfer Syntax UID: \(info.transferSyntaxUID)")
            print("Compressed: \(info.isCompressed ? "Yes" : "No")")
            print("Lossless: \(info.isLossless ? "Yes" : "No")")

            if info.isJPEG { print("Codec: JPEG") }
            else if info.isJPEG2000 { print("Codec: JPEG 2000") }
            else if info.isRLE { print("Codec: RLE") }
            else if info.isDeflated { print("Codec: Deflate") }
            else { print("Codec: None (uncompressed)") }

            if let size = info.pixelDataSize {
                print("Pixel Data Size: \(formatBytes(size))")
            } else {
                print("Pixel Data Size: N/A (no pixel data)")
            }

            if let rows = info.rows, let cols = info.columns {
                print("Image Dimensions: \(cols) x \(rows)")
            }
            if let ba = info.bitsAllocated {
                print("Bits Allocated: \(ba)")
            }
            if let bs = info.bitsStored {
                print("Bits Stored: \(bs)")
            }
            if let spp = info.samplesPerPixel {
                print("Samples Per Pixel: \(spp)")
            }
            if let pi = info.photometricInterpretation {
                print("Photometric Interpretation: \(pi)")
            }
            if let nf = info.numberOfFrames {
                print("Number of Frames: \(nf)")
            }
        }

        private func printJSON(_ info: CompressionInfo) throws {
            var dict: [String: Any] = [
                "file": input,
                "transferSyntax": info.transferSyntaxName,
                "transferSyntaxUID": info.transferSyntaxUID,
                "compressed": info.isCompressed,
                "lossless": info.isLossless,
            ]

            if info.isJPEG { dict["codec"] = "JPEG" }
            else if info.isJPEG2000 { dict["codec"] = "JPEG 2000" }
            else if info.isRLE { dict["codec"] = "RLE" }
            else if info.isDeflated { dict["codec"] = "Deflate" }
            else { dict["codec"] = "None" }

            if let size = info.pixelDataSize { dict["pixelDataSize"] = size }
            if let rows = info.rows { dict["rows"] = rows }
            if let cols = info.columns { dict["columns"] = cols }
            if let ba = info.bitsAllocated { dict["bitsAllocated"] = ba }
            if let bs = info.bitsStored { dict["bitsStored"] = bs }
            if let spp = info.samplesPerPixel { dict["samplesPerPixel"] = spp }
            if let pi = info.photometricInterpretation { dict["photometricInterpretation"] = pi }
            if let nf = info.numberOfFrames { dict["numberOfFrames"] = nf }

            let jsonData = try JSONSerialization.data(
                withJSONObject: dict,
                options: [.prettyPrinted, .sortedKeys]
            )
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        }
    }
}

// MARK: - Batch Subcommand

@available(macOS 10.15, *)
extension DICOMCompress {
    struct Batch: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Batch compress or decompress DICOM files in a directory",
            discussion: """
                Process all DICOM files in a directory, optionally recursing into subdirectories.
                
                Examples:
                  dicom-compress batch input_dir/ --output output_dir/ --codec jpeg-lossless
                  dicom-compress batch input_dir/ --output output_dir/ --codec jpeg2000 --quality high --recursive
                  dicom-compress batch input_dir/ --output output_dir/ --decompress --recursive
                """
        )

        @Argument(help: "Input directory path")
        var input: String

        @Option(name: .shortAndLong, help: "Output directory path")
        var output: String

        @Option(name: .shortAndLong, help: "Target codec for compression (e.g., jpeg-lossless, jpeg2000)")
        var codec: String?

        @Flag(name: .long, help: "Decompress files instead of compressing")
        var decompress: Bool = false

        @Option(name: .shortAndLong, help: "Quality: maximum, high, medium, low, or a value 0.0-1.0")
        var quality: String?

        @Option(name: .shortAndLong, help: "Target syntax for decompression (default: explicit-le)")
        var syntax: String = "explicit-le"

        @Flag(name: .shortAndLong, help: "Process subdirectories recursively")
        var recursive: Bool = false

        @Flag(name: .long, help: "Show verbose output")
        var verbose: Bool = false

        mutating func validate() throws {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: input, isDirectory: &isDir), isDir.boolValue else {
                throw ValidationError("Input directory not found: \(input)")
            }
            if !decompress && codec == nil {
                throw ValidationError("Specify --codec for compression or use --decompress for decompression")
            }
            if let c = codec {
                guard CompressionManager.transferSyntax(for: c) != nil else {
                    let supported = CompressionManager.supportedCodecs().map { $0.name }.joined(separator: ", ")
                    throw ValidationError("Unknown codec '\(c)'. Supported: \(supported)")
                }
            }
            if decompress {
                guard CompressionManager.transferSyntax(for: syntax) != nil else {
                    throw ValidationError("Unknown syntax '\(syntax)'. Use explicit-le or implicit-le.")
                }
            }
        }

        mutating func run() throws {
            let manager = CompressionManager()

            // Create output directory
            try FileManager.default.createDirectory(
                atPath: output,
                withIntermediateDirectories: true
            )

            let files: [String]
            do {
                files = try CompressionManager.findDICOMFiles(in: input, recursive: recursive)
            } catch {
                fprintln("Error scanning directory: \(error)")
                throw ExitCode.failure
            }

            if files.isEmpty {
                fprintln("No DICOM files found in: \(input)")
                throw ExitCode.failure
            }

            fprintln("Found \(files.count) DICOM file(s)")

            let qualityPreset = try parseQuality(quality)
            var successCount = 0
            var failCount = 0

            for filePath in files {
                // Compute relative path and build output path
                let relativePath: String
                if filePath.hasPrefix(input) {
                    var rel = String(filePath.dropFirst(input.count))
                    if rel.hasPrefix("/") { rel = String(rel.dropFirst()) }
                    relativePath = rel
                } else {
                    relativePath = URL(fileURLWithPath: filePath).lastPathComponent
                }

                let outputPath = (output as NSString).appendingPathComponent(relativePath)

                // Create intermediate directories
                let outputDir = (outputPath as NSString).deletingLastPathComponent
                try FileManager.default.createDirectory(
                    atPath: outputDir,
                    withIntermediateDirectories: true
                )

                do {
                    if decompress {
                        let targetSyntax = CompressionManager.transferSyntax(for: syntax)!
                        try manager.decompressFile(
                            inputPath: filePath,
                            outputPath: outputPath,
                            syntax: targetSyntax
                        )
                    } else {
                        try manager.compressFile(
                            inputPath: filePath,
                            outputPath: outputPath,
                            codec: codec!,
                            quality: qualityPreset
                        )
                    }
                    successCount += 1
                    if verbose {
                        fprintln("  ✅ \(relativePath)")
                    }
                } catch {
                    failCount += 1
                    if verbose {
                        fprintln("  ❌ \(relativePath): \(error)")
                    }
                }
            }

            let action = decompress ? "Decompressed" : "Compressed"
            fprintln("\(action): \(successCount) succeeded, \(failCount) failed out of \(files.count) files")

            if failCount > 0 {
                throw ExitCode.failure
            }
        }
    }
}

// MARK: - Helpers

private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}

private func formatBytes(_ bytes: Int) -> String {
    if bytes < 1024 {
        return "\(bytes) B"
    } else if bytes < 1024 * 1024 {
        return String(format: "%.1f KB", Double(bytes) / 1024.0)
    } else if bytes < 1024 * 1024 * 1024 {
        return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
    } else {
        return String(format: "%.1f GB", Double(bytes) / (1024.0 * 1024.0 * 1024.0))
    }
}

@available(macOS 10.15, *)
private func parseQuality(_ qualityString: String?) throws -> CompressionQuality? {
    guard let qs = qualityString else { return nil }
    switch qs.lowercased() {
    case "maximum": return .maximum
    case "high": return .high
    case "medium": return .medium
    case "low": return .low
    default:
        if let value = Double(qs), value >= 0.0, value <= 1.0 {
            return .custom(value)
        }
        throw ValidationError("Invalid quality '\(qs)'. Use maximum, high, medium, low, or a value 0.0-1.0")
    }
}

DICOMCompress.main()
