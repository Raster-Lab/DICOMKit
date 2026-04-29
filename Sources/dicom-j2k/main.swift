// main.swift — dicom-j2k
// JPEG 2000 / HTJ2K codestream operations on DICOM files.
//
// Phase 9.1 of J2KSwift v3 integration (J2KSWIFT_V3_2_INTEGRATION_PLAN.md).

import Foundation
import ArgumentParser
import DICOMCore
import DICOMKit
import DICOMDictionary
import J2KCore
import J2KCodec
import J2KFileFormat

@available(macOS 10.15, *)
struct DICOMJ2K: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-j2k",
        abstract: "JPEG 2000 / HTJ2K codestream operations on DICOM files",
        discussion: """
            Inspect, validate, transcode, reduce, and benchmark the JPEG 2000 or HTJ2K
            codestream embedded in a DICOM file. All operations preserve the DICOM
            metadata and re-wrap the result in a conformant DICOM file.

            Transfer Syntaxes supported:
              1.2.840.10008.1.2.4.90  JPEG 2000 Lossless
              1.2.840.10008.1.2.4.91  JPEG 2000 (Lossy)
              1.2.840.10008.1.2.4.201 JPEG 2000 Part 2 Lossless (MC)
              1.2.840.10008.1.2.4.202 JPEG 2000 Part 2 (MC, Lossy)
              1.2.840.10008.1.2.4.202 HTJ2K Lossless
              1.2.840.10008.1.2.4.203 HTJ2K RPCL Lossless
              1.2.840.10008.1.2.4.204 HTJ2K (Lossy)

            Examples:
              dicom-j2k info scan.dcm
              dicom-j2k info scan.dcm --json
              dicom-j2k validate scan.dcm
              dicom-j2k transcode j2k.dcm --output htj2k.dcm --target htj2k-lossless
              dicom-j2k transcode htj2k.dcm --output j2k.dcm --target j2k-lossless
              dicom-j2k reduce input.dcm --output small.dcm --levels 3 --layers 4
              dicom-j2k roi input.dcm --output roi.dcm --frame 0 --region 0,0,256,256
              dicom-j2k benchmark scan.dcm
              dicom-j2k benchmark scan.dcm --iterations 20 --backends all
              dicom-j2k compare ref.dcm test.dcm
              dicom-j2k completions zsh
            """,
        version: "1.0.0",
        subcommands: [
            InfoCommand.self,
            ValidateCommand.self,
            TranscodeCommand.self,
            ReduceCommand.self,
            ROICommand.self,
            BenchmarkCommand.self,
            CompareCommand.self,
            CompletionsCommand.self
        ],
        defaultSubcommand: InfoCommand.self
    )
}

// MARK: - Helpers

/// Load a DICOM file from a path string; throws a user-friendly error on failure.
@available(macOS 10.15, *)
private func loadDICOM(at path: String) throws -> DICOMFile {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else {
        throw ValidationError("File not found: \(path)")
    }
    do {
        return try DICOMFile.read(from: url)
    } catch {
        throw ValidationError("Failed to read DICOM file '\(path)': \(error.localizedDescription)")
    }
}

/// Extract the raw J2K codestream for a specific frame from a DICOM file.
/// Returns nil if the pixel data is not encapsulated (e.g., uncompressed).
@available(macOS 10.15, *)
private func j2kCodestream(from dicom: DICOMFile, frameIndex: Int = 0) -> Data? {
    guard let element = dicom.dataSet[.pixelData],
          let fragments = element.encapsulatedFragments else {
        return nil
    }
    guard frameIndex < fragments.count else {
        return nil
    }
    return fragments[frameIndex]
}

/// Sync/async bridge result box — avoids mutation-of-captured-var in @Sendable closures.
private final class AsyncResultBox<T: Sendable>: @unchecked Sendable {
    var result: Result<T, Error>?
}

/// Synchronously runs an async throwing closure and returns its result.
/// Used to bridge ParsableCommand.run() (synchronous) with async J2KSwift APIs.
@available(macOS 10.15, *)
@discardableResult
private func runAsync<T: Sendable>(_ block: @escaping @Sendable () async throws -> T) throws -> T {
    let box = AsyncResultBox<T>()
    let sema = DispatchSemaphore(value: 0)
    Task {
        do { box.result = .success(try await block()) }
        catch { box.result = .failure(error) }
        sema.signal()
    }
    sema.wait()
    switch box.result! {
    case .success(let v): return v
    case .failure(let e): throw e
    }
}

/// Decode a J2K codestream synchronously using J2KDecoder.
@available(macOS 10.15, *)
private func decodeJ2K(_ data: Data) throws -> J2KImage {
    try runAsync { try await J2KDecoder().decode(data) }
}

/// Human-readable transfer syntax label from UID.
private func tsLabel(_ uid: String?) -> String {
    guard let uid else { return "Unknown" }
    switch uid {
    case "1.2.840.10008.1.2.4.90": return "JPEG 2000 Lossless (1.2.840.10008.1.2.4.90)"
    case "1.2.840.10008.1.2.4.91": return "JPEG 2000 (1.2.840.10008.1.2.4.91)"
    case "1.2.840.10008.1.2.4.201": return "JPEG 2000 Part 2 Lossless (1.2.840.10008.1.2.4.201)"
    case "1.2.840.10008.1.2.4.202": return "HTJ2K Lossless (1.2.840.10008.1.2.4.202)"
    case "1.2.840.10008.1.2.4.203": return "HTJ2K RPCL Lossless (1.2.840.10008.1.2.4.203)"
    case "1.2.840.10008.1.2.4.204": return "HTJ2K (1.2.840.10008.1.2.4.204)"
    default: return uid
    }
}

/// True if the transfer syntax UID indicates JPEG 2000 or HTJ2K compression.
private func isJ2KTransferSyntax(_ uid: String?) -> Bool {
    guard let uid else { return false }
    return [
        "1.2.840.10008.1.2.4.90",
        "1.2.840.10008.1.2.4.91",
        "1.2.840.10008.1.2.4.201",
        "1.2.840.10008.1.2.4.202",
        "1.2.840.10008.1.2.4.203",
        "1.2.840.10008.1.2.4.204"
    ].contains(uid)
}

// MARK: - info

@available(macOS 10.15, *)
extension DICOMJ2K {
    struct InfoCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "info",
            abstract: "Show J2K/HTJ2K codestream metadata embedded in a DICOM file",
            discussion: """
                Decodes the JPEG 2000 or HTJ2K codestream header and displays
                structural metadata: dimensions, components, bit depth, tiling,
                colour space, progression order, quality layers, and HTJ2K flag.

                Examples:
                  dicom-j2k info scan.dcm
                  dicom-j2k info scan.dcm --json
                  dicom-j2k info scan.dcm --frame 2
                """
        )

        @Argument(help: "Input DICOM file path")
        var input: String

        @Option(name: .long, help: "Frame index (0-based, default 0)")
        var frame: Int = 0

        @Flag(name: .long, help: "Output as JSON")
        var json: Bool = false

        @Flag(name: .shortAndLong, help: "Verbose output")
        var verbose: Bool = false

        mutating func run() throws {
            let dicom = try loadDICOM(at: input)
            let tsUID = dicom.transferSyntaxUID

            guard isJ2KTransferSyntax(tsUID) else {
                throw ValidationError(
                    "Not a JPEG 2000 file. Transfer syntax: \(tsLabel(tsUID))"
                )
            }

            guard let codestream = j2kCodestream(from: dicom, frameIndex: frame) else {
                throw ValidationError(
                    "No encapsulated JPEG 2000 pixel data found for frame \(frame)."
                )
            }

            let image = try decodeJ2K(codestream)

            if json {
                printInfoJSON(image: image, codestream: codestream, tsUID: tsUID, dicom: dicom)
            } else {
                printInfoText(image: image, codestream: codestream, tsUID: tsUID, dicom: dicom)
            }
        }

        private func printInfoText(image: J2KImage, codestream: Data, tsUID: String?, dicom: DICOMFile) {
            print("JPEG 2000 Codestream Info")
            print("=========================")
            print("File:             \(input)")
            print("Transfer Syntax:  \(tsLabel(tsUID))")
            print("Frame:            \(frame) of \(dicom.numberOfFrames ?? 1)")
            print("Codestream Size:  \(ByteCountFormatter.string(fromByteCount: Int64(codestream.count), countStyle: .file))")
            print("")
            print("Image Geometry")
            print("--------------")
            print("Width:            \(image.width) px")
            print("Height:           \(image.height) px")
            print("Components:       \(image.componentCount)")
            print("Colour Space:     \(image.colorSpace)")
            print("Grayscale:        \(image.isGrayscale ? "Yes" : "No")")
            if image.isTiled {
                print("Tile Width:       \(image.tileWidth) px")
                print("Tile Height:      \(image.tileHeight) px")
                print("Tile Count:       \(image.tileCount) (\(image.tilesX)×\(image.tilesY))")
            } else {
                print("Tiling:           None (single tile)")
            }
            print("")
            print("Component Details")
            print("-----------------")
            for comp in image.components {
                let subsamp = comp.isSubsampled ? " [subsampled \(comp.subsamplingX)×\(comp.subsamplingY)]" : ""
                let sign = comp.signed ? "signed" : "unsigned"
                print("  Component \(comp.index): \(comp.bitDepth)-bit \(sign), \(comp.width)×\(comp.height)\(subsamp)")
            }
            if verbose {
                print("")
                print("Geometry Details")
                print("----------------")
                print("Tile Offset X:    \(image.tileOffsetX)")
                print("Tile Offset Y:    \(image.tileOffsetY)")
                print("Image Offset X:   \(image.offsetX)")
                print("Image Offset Y:   \(image.offsetY)")
                print("Aspect Ratio:     \(String(format: "%.4f", image.aspectRatio))")
                print("Pixel Count:      \(image.pixelCount)")
            }
        }

        private func printInfoJSON(image: J2KImage, codestream: Data, tsUID: String?, dicom: DICOMFile) {
            var dict: [String: Any] = [
                "file": input,
                "transferSyntaxUID": tsUID as Any,
                "transferSyntaxDescription": tsLabel(tsUID),
                "frame": frame,
                "totalFrames": dicom.numberOfFrames ?? 1,
                "codestreamBytes": codestream.count,
                "width": image.width,
                "height": image.height,
                "componentCount": image.componentCount,
                "colorSpace": "\(image.colorSpace)",
                "isGrayscale": image.isGrayscale,
                "isTiled": image.isTiled,
                "pixelCount": image.pixelCount,
                "aspectRatio": image.aspectRatio
            ]
            if image.isTiled {
                dict["tileWidth"] = image.tileWidth
                dict["tileHeight"] = image.tileHeight
                dict["tileCount"] = image.tileCount
                dict["tilesX"] = image.tilesX
                dict["tilesY"] = image.tilesY
            }
            let comps = image.components.map { c -> [String: Any] in
                [
                    "index": c.index,
                    "bitDepth": c.bitDepth,
                    "signed": c.signed,
                    "width": c.width,
                    "height": c.height,
                    "subsamplingX": c.subsamplingX,
                    "subsamplingY": c.subsamplingY
                ]
            }
            dict["components"] = comps
            if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                print(jsonStr)
            }
        }
    }
}

// MARK: - validate

@available(macOS 10.15, *)
extension DICOMJ2K {
    struct ValidateCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "validate",
            abstract: "ISO/IEC 15444-4 conformance check of the embedded J2K codestream",
            discussion: """
                Runs structural validation of the JPEG 2000 or HTJ2K codestream using
                J2KSwift's built-in conformance tester. Reports marker ordering,
                segment-length consistency, capability signalling (CAP marker for HTJ2K),
                and interoperability issues.

                Exit code 0 = valid, 1 = violations found, 2 = read error.

                Examples:
                  dicom-j2k validate scan.dcm
                  dicom-j2k validate scan.dcm --frame 0 --strict
                """
        )

        @Argument(help: "Input DICOM file path")
        var input: String

        @Option(name: .long, help: "Frame index (0-based, default 0)")
        var frame: Int = 0

        @Flag(name: .long, help: "Treat warnings as errors (strict mode)")
        var strict: Bool = false

        @Flag(name: .long, help: "Output results as JSON")
        var json: Bool = false

        mutating func run() throws {
            let dicom = try loadDICOM(at: input)
            let tsUID = dicom.transferSyntaxUID

            guard isJ2KTransferSyntax(tsUID) else {
                throw ValidationError(
                    "Not a JPEG 2000 file. Transfer syntax: \(tsLabel(tsUID))"
                )
            }

            guard let codestream = j2kCodestream(from: dicom, frameIndex: frame) else {
                throw ValidationError(
                    "No encapsulated JPEG 2000 pixel data found for frame \(frame)."
                )
            }

            let htValidator = HTJ2KConformanceTestHarness()
            let interopValidator = J2KHTInteroperabilityValidator()
            let structureViolations = htValidator.validateCodestreamStructure(codestream)
            let markerViolations = interopValidator.validateMarkerOrdering(codestream: codestream)
            let segmentViolations = interopValidator.validateSegmentLengths(codestream: codestream)
            let capResult = interopValidator.validateCapabilitySignaling(codestream: codestream)
            let interopResult = interopValidator.validateInteroperability(codestream: codestream)

            let capViolations = capResult.errors
            let allViolations = structureViolations + markerViolations + segmentViolations + capViolations
            let interopWarnings = interopResult.warnings
            let isValid = allViolations.isEmpty && (strict ? interopWarnings.isEmpty : true)

            if json {
                let out: [String: Any] = [
                    "file": input,
                    "frame": frame,
                    "transferSyntaxUID": tsUID as Any,
                    "valid": isValid,
                    "violations": allViolations,
                    "interoperabilityWarnings": interopWarnings
                ]
                if let data = try? JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys]),
                   let str = String(data: data, encoding: .utf8) {
                    print(str)
                }
            } else {
                print("Validation: \(input) (frame \(frame))")
                print("Transfer Syntax: \(tsLabel(tsUID))")
                print("")
                if allViolations.isEmpty {
                    print("✓ No structural violations found.")
                } else {
                    print("✗ \(allViolations.count) violation(s):")
                    for v in allViolations { print("  · \(v)") }
                }
                if !interopWarnings.isEmpty {
                    print("\nInteroperability warnings (\(interopWarnings.count)):")
                    for w in interopWarnings { print("  · \(w)") }
                }
                print("")
                print("Result: \(isValid ? "VALID ✓" : "INVALID ✗")")
            }

            if !isValid {
                throw ExitCode(1)
            }
        }
    }
}

// MARK: - transcode

@available(macOS 10.15, *)
extension DICOMJ2K {
    struct TranscodeCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "transcode",
            abstract: "Transcode J2K ↔ HTJ2K while preserving DICOM metadata",
            discussion: """
                Decodes the source JPEG 2000 / HTJ2K codestream and re-encodes it using
                the specified target transfer syntax. The DICOM dataset is preserved
                bit-for-bit except for the pixel data element and transfer syntax UID.

                Target transfer syntax values:
                  j2k-lossless       JPEG 2000 Lossless (1.2.840.10008.1.2.4.90)
                  j2k                JPEG 2000 Lossy (1.2.840.10008.1.2.4.91)
                  htj2k-lossless     HTJ2K Lossless (1.2.840.10008.1.2.4.202)
                  htj2k-rpcl         HTJ2K RPCL Lossless (1.2.840.10008.1.2.4.203)
                  htj2k              HTJ2K Lossy (1.2.840.10008.1.2.4.204)

                Examples:
                  dicom-j2k transcode j2k.dcm --output htj2k.dcm --target htj2k-lossless
                  dicom-j2k transcode htj2k.dcm --output j2k.dcm --target j2k-lossless
                  dicom-j2k transcode input.dcm --output out.dcm --target htj2k --quality 0.9
                """
        )

        @Argument(help: "Input DICOM file path")
        var input: String

        @Option(name: .shortAndLong, help: "Output DICOM file path")
        var output: String

        @Option(name: .shortAndLong, help: "Target transfer syntax (j2k-lossless, j2k, htj2k-lossless, htj2k-rpcl, htj2k)")
        var target: String

        @Option(name: .shortAndLong, help: "Encoding quality 0.0–1.0 (ignored for lossless targets)")
        var quality: Double = 0.9

        @Flag(name: .shortAndLong, help: "Verbose output")
        var verbose: Bool = false

        mutating func validate() throws {
            let valid = ["j2k-lossless", "j2k", "htj2k-lossless", "htj2k-rpcl", "htj2k"]
            guard valid.contains(target) else {
                throw ValidationError("Invalid target '\(target)'. Valid values: \(valid.joined(separator: ", "))")
            }
            guard (0.0...1.0).contains(quality) else {
                throw ValidationError("Quality must be between 0.0 and 1.0")
            }
        }

        mutating func run() throws {
            let dicom = try loadDICOM(at: input)
            let srcUID = dicom.transferSyntaxUID
            guard isJ2KTransferSyntax(srcUID) else {
                throw ValidationError(
                    "Not a JPEG 2000 file. Transfer syntax: \(tsLabel(srcUID))"
                )
            }

            let targetUID = targetTransferSyntaxUID(for: target)
            let isLossless = target.hasSuffix("lossless") || target == "htj2k-rpcl"

            if verbose {
                print("Source:  \(tsLabel(srcUID))")
                print("Target:  \(tsLabel(targetUID))")
                print("Quality: \(isLossless ? "lossless" : String(format: "%.2f", quality))")
            }

            // Decode all frames, re-encode, and rebuild DICOM
            let frameCount = dicom.numberOfFrames ?? 1
            let useHTJ2K = targetUID.hasPrefix("1.2.840.10008.1.2.4.20")
            var encConfig = J2KEncodingConfiguration()
            encConfig.lossless = isLossless
            encConfig.useHTJ2K = useHTJ2K
            // ISO/IEC 15444-15 conformant wire format for DICOM HTJ2K transfer syntaxes —
            // interop with OpenJPH and Part-15 PACS decoders. Requires J2KSwift 5.1.1+
            // (decoder dispatch + pixel-0 K_max fix for CT/MR 16-bit lossless round-trip).
            if useHTJ2K {
                encConfig.htj2kBlockFormat = .conformant
            }

            let encoder = J2KEncoder(encodingConfiguration: encConfig)
            var newFragments = [Data]()
            for idx in 0..<frameCount {
                guard let cs = j2kCodestream(from: dicom, frameIndex: idx) else { continue }
                let img = try decodeJ2K(cs)
                let enc: Data = try runAsync { try await encoder.encode(img) }
                newFragments.append(enc)
            }

            guard !newFragments.isEmpty else {
                throw ValidationError("No J2K frames found in input file.")
            }

            var newDataSet = dicom.dataSet
            let pixelElement = DataElement(
                tag: .pixelData,
                vr: .OB,
                length: 0xFFFFFFFF,
                valueData: Data(),
                encapsulatedFragments: newFragments,
                encapsulatedOffsetTable: []
            )
            newDataSet[.pixelData] = pixelElement

            // Update transfer syntax in file meta
            var newMeta = dicom.fileMetaInformation
            let tsTag = Tag(group: 0x0002, element: 0x0010)
            let tsData = Data(targetUID.utf8)
            newMeta[tsTag] = DataElement(
                tag: tsTag,
                vr: .UI,
                length: UInt32(tsData.count),
                valueData: tsData
            )

            let newFile = DICOMFile(fileMetaInformation: newMeta, dataSet: newDataSet)
            let outputURL = URL(fileURLWithPath: output)
            let data = try newFile.write()
            try data.write(to: outputURL)

            if verbose {
                print("Written to: \(output)")
            } else {
                print("Transcoded to \(target): \(output)")
            }
        }

        private func targetTransferSyntaxUID(for key: String) -> String {
            switch key {
            case "j2k-lossless": return "1.2.840.10008.1.2.4.90"
            case "j2k":          return "1.2.840.10008.1.2.4.91"
            case "htj2k-lossless": return "1.2.840.10008.1.2.4.202"
            case "htj2k-rpcl":   return "1.2.840.10008.1.2.4.203"
            case "htj2k":        return "1.2.840.10008.1.2.4.204"
            default:             return "1.2.840.10008.1.2.4.90"
            }
        }
    }
}

// MARK: - reduce

@available(macOS 10.15, *)
extension DICOMJ2K {
    struct ReduceCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "reduce",
            abstract: "Re-encode at lower resolution levels or fewer quality layers",
            discussion: """
                Decodes the codestream then re-encodes with fewer wavelet decomposition
                levels (lower spatial resolution) or fewer quality layers (lower quality).
                Useful for generating thumbnails or bandwidth-efficient previews.

                --levels  Number of wavelet decomposition levels (1–10, default same as source).
                          Fewer levels = lower maximum resolution.
                --layers  Number of quality layers (1–20, default same as source).
                          Fewer layers = lower maximum quality.

                Examples:
                  dicom-j2k reduce input.dcm --output thumb.dcm --levels 2
                  dicom-j2k reduce input.dcm --output preview.dcm --levels 3 --layers 4
                """
        )

        @Argument(help: "Input DICOM file path")
        var input: String

        @Option(name: .shortAndLong, help: "Output DICOM file path")
        var output: String

        @Option(name: .long, help: "Number of wavelet decomposition levels (1–10)")
        var levels: Int?

        @Option(name: .long, help: "Number of quality layers (1–20)")
        var layers: Int?

        @Flag(name: .shortAndLong, help: "Verbose output")
        var verbose: Bool = false

        mutating func validate() throws {
            if let l = levels, !(1...10).contains(l) {
                throw ValidationError("--levels must be between 1 and 10")
            }
            if let l = layers, !(1...20).contains(l) {
                throw ValidationError("--layers must be between 1 and 20")
            }
            if levels == nil && layers == nil {
                throw ValidationError("Specify at least one of --levels or --layers")
            }
        }

        mutating func run() throws {
            let dicom = try loadDICOM(at: input)
            guard isJ2KTransferSyntax(dicom.transferSyntaxUID) else {
                throw ValidationError(
                    "Not a JPEG 2000 file. Transfer syntax: \(tsLabel(dicom.transferSyntaxUID))"
                )
            }

            guard let codestream = j2kCodestream(from: dicom, frameIndex: 0) else {
                throw ValidationError("No encapsulated JPEG 2000 pixel data found.")
            }

            let srcImage = try decodeJ2K(codestream)

            var encConfig = J2KEncodingConfiguration()
            encConfig.lossless = true
            if let l = levels {
                encConfig.decompositionLevels = l
                if verbose { print("Reducing to \(l) decomposition levels") }
            }
            if let l = layers {
                encConfig.qualityLayers = l
                if verbose { print("Reducing to \(l) quality layers") }
            }

            let encoder = J2KEncoder(encodingConfiguration: encConfig)
            let encoded: Data = try runAsync { try await encoder.encode(srcImage) }

            // Re-wrap in a DICOM file preserving existing metadata
            let frameCount = dicom.numberOfFrames ?? 1
            var newFragments = [Data](repeating: encoded, count: frameCount)
            // For multi-frame files, reduce all frames
            if frameCount > 1 {
                newFragments = []
                for idx in 0..<frameCount {
                    if let cs = j2kCodestream(from: dicom, frameIndex: idx) {
                        let img = try decodeJ2K(cs)
                        let encoded2: Data = try runAsync { try await encoder.encode(img) }
                        newFragments.append(encoded2)
                    }
                }
            }

            var newDataSet = dicom.dataSet
            let pixelElement = DataElement(
                tag: .pixelData,
                vr: .OB,
                length: 0xFFFFFFFF,
                valueData: Data(),
                encapsulatedFragments: newFragments,
                encapsulatedOffsetTable: []
            )
            newDataSet[.pixelData] = pixelElement

            let newFile = DICOMFile(fileMetaInformation: dicom.fileMetaInformation, dataSet: newDataSet)
            let outputURL = URL(fileURLWithPath: output)
            let outData = try newFile.write()
            try outData.write(to: outputURL)

            if verbose {
                print("Written to: \(output)")
            } else {
                print("Reduced DICOM written to: \(output)")
            }
        }
    }
}

// MARK: - roi

@available(macOS 10.15, *)
extension DICOMJ2K {
    struct ROICommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "roi",
            abstract: "Extract a region of interest (ROI) frame into a new DICOM file",
            discussion: """
                Decodes the specified frame, crops to the given rectangle, and re-encodes
                the crop as a single-frame DICOM file preserving the original transfer syntax.

                --region x,y,width,height   Crop rectangle in pixels (origin at top-left).

                Examples:
                  dicom-j2k roi input.dcm --output roi.dcm --frame 0 --region 0,0,256,256
                  dicom-j2k roi input.dcm --output roi.dcm --region 128,128,512,512
                """
        )

        @Argument(help: "Input DICOM file path")
        var input: String

        @Option(name: .shortAndLong, help: "Output DICOM file path")
        var output: String

        @Option(name: .long, help: "Frame index (0-based, default 0)")
        var frame: Int = 0

        @Option(name: .long, help: "Region of interest: x,y,width,height")
        var region: String

        @Flag(name: .shortAndLong, help: "Verbose output")
        var verbose: Bool = false

        mutating func validate() throws {
            let parts = region.split(separator: ",").compactMap { Int($0) }
            guard parts.count == 4 else {
                throw ValidationError("--region must be x,y,width,height (four integers)")
            }
            guard parts[2] > 0, parts[3] > 0 else {
                throw ValidationError("--region width and height must be positive")
            }
        }

        mutating func run() throws {
            let parts = region.split(separator: ",").compactMap { Int($0) }
            let roiX = parts[0], roiY = parts[1], roiW = parts[2], roiH = parts[3]

            let dicom = try loadDICOM(at: input)
            guard isJ2KTransferSyntax(dicom.transferSyntaxUID) else {
                throw ValidationError(
                    "Not a JPEG 2000 file. Transfer syntax: \(tsLabel(dicom.transferSyntaxUID))"
                )
            }
            guard let codestream = j2kCodestream(from: dicom, frameIndex: frame) else {
                throw ValidationError("No encapsulated JPEG 2000 pixel data found for frame \(frame).")
            }

            let image = try decodeJ2K(codestream)
            guard roiX + roiW <= image.width, roiY + roiH <= image.height else {
                throw ValidationError(
                    "ROI \(roiX),\(roiY),\(roiW),\(roiH) extends outside image bounds \(image.width)×\(image.height)"
                )
            }

            // Crop each component's data
            let croppedComps: [J2KComponent] = image.components.map { comp in
                let srcW = comp.width, srcH = comp.height
                // Account for subsampling
                let sx = Int(ceil(Double(roiX) / Double(comp.subsamplingX)))
                let sy = Int(ceil(Double(roiY) / Double(comp.subsamplingY)))
                let sw = Int(ceil(Double(roiW) / Double(comp.subsamplingX)))
                let sh = Int(ceil(Double(roiH) / Double(comp.subsamplingY)))
                let actualW = min(sw, srcW - sx)
                let actualH = min(sh, srcH - sy)

                var croppedData = Data(capacity: actualW * actualH * (comp.bitDepth <= 8 ? 1 : 2))
                let bytesPerSample = comp.bitDepth <= 8 ? 1 : 2
                let srcData = comp.data
                for row in 0..<actualH {
                    let srcRow = sy + row
                    let srcOffset = (srcRow * srcW + sx) * bytesPerSample
                    let count = actualW * bytesPerSample
                    if srcOffset + count <= srcData.count {
                        croppedData.append(srcData[srcOffset..<(srcOffset + count)])
                    }
                }
                return J2KComponent(
                    index: comp.index,
                    bitDepth: comp.bitDepth,
                    signed: comp.signed,
                    width: actualW,
                    height: actualH,
                    subsamplingX: comp.subsamplingX,
                    subsamplingY: comp.subsamplingY,
                    data: croppedData
                )
            }

            let croppedImage = J2KImage(
                width: roiW,
                height: roiH,
                components: croppedComps,
                offsetX: 0,
                offsetY: 0,
                tileWidth: roiW,
                tileHeight: roiH,
                tileOffsetX: 0,
                tileOffsetY: 0,
                colorSpace: image.colorSpace
            )

            var encConfig = J2KEncodingConfiguration()
            encConfig.lossless = true
            let encoder = J2KEncoder(encodingConfiguration: encConfig)
            let encoded: Data = try runAsync { try await encoder.encode(croppedImage) }

            var newDataSet = dicom.dataSet
            newDataSet[.pixelData] = DataElement(
                tag: .pixelData,
                vr: .OB,
                length: 0xFFFFFFFF,
                valueData: Data(),
                encapsulatedFragments: [encoded],
                encapsulatedOffsetTable: []
            )
            // Update Rows (0028,0010) and Columns (0028,0011)
            let rowsTag = Tag(group: 0x0028, element: 0x0010)
            var rowsVal = UInt16(roiH).littleEndian
            newDataSet[rowsTag] = DataElement(
                tag: rowsTag, vr: .US,
                length: 2, valueData: Data(bytes: &rowsVal, count: 2)
            )
            let colsTag = Tag(group: 0x0028, element: 0x0011)
            var colsVal = UInt16(roiW).littleEndian
            newDataSet[colsTag] = DataElement(
                tag: colsTag, vr: .US,
                length: 2, valueData: Data(bytes: &colsVal, count: 2)
            )

            let newFile = DICOMFile(fileMetaInformation: dicom.fileMetaInformation, dataSet: newDataSet)
            let outputURL = URL(fileURLWithPath: output)
            let outData = try newFile.write()
            try outData.write(to: outputURL)

            if verbose {
                print("ROI \(roiW)×\(roiH) from frame \(frame) written to: \(output)")
            } else {
                print("ROI extracted to: \(output)")
            }
        }
    }
}

// MARK: - benchmark

@available(macOS 10.15, *)
extension DICOMJ2K {
    struct BenchmarkCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "benchmark",
            abstract: "Decode-speed benchmark across J2KSwift codec backends",
            discussion: """
                Decodes the embedded JPEG 2000 / HTJ2K codestream repeatedly and
                reports timing statistics: average, minimum, maximum, median, and
                standard deviation across all iterations.

                Examples:
                  dicom-j2k benchmark scan.dcm
                  dicom-j2k benchmark scan.dcm --iterations 50
                  dicom-j2k benchmark scan.dcm --json
                """
        )

        @Argument(help: "Input DICOM file path")
        var input: String

        @Option(name: .long, help: "Frame index (0-based, default 0)")
        var frame: Int = 0

        @Option(name: .long, help: "Number of decode iterations (default 10)")
        var iterations: Int = 10

        @Flag(name: .long, help: "Output as JSON")
        var json: Bool = false

        @Flag(name: .shortAndLong, help: "Verbose output")
        var verbose: Bool = false

        mutating func validate() throws {
            guard iterations >= 1 else {
                throw ValidationError("--iterations must be at least 1")
            }
        }

        mutating func run() throws {
            let dicom = try loadDICOM(at: input)
            guard isJ2KTransferSyntax(dicom.transferSyntaxUID) else {
                throw ValidationError(
                    "Not a JPEG 2000 file. Transfer syntax: \(tsLabel(dicom.transferSyntaxUID))"
                )
            }
            guard let codestream = j2kCodestream(from: dicom, frameIndex: frame) else {
                throw ValidationError("No encapsulated JPEG 2000 pixel data found for frame \(frame).")
            }

            if verbose { print("Benchmarking \(input) (\(iterations) iterations)…") }

            let bench = J2KBenchmark(name: "J2K Decode")
            let result = try bench.measureThrowing(iterations: iterations, warmupIterations: 3) {
                _ = try decodeJ2K(codestream)
            }

            if json {
                let out: [String: Any] = [
                    "file": input,
                    "frame": frame,
                    "iterations": iterations,
                    "codestreamBytes": codestream.count,
                    "averageMs": result.averageTime * 1000,
                    "minMs": result.minTime * 1000,
                    "maxMs": result.maxTime * 1000,
                    "medianMs": result.medianTime * 1000,
                    "stdDevMs": result.standardDeviation * 1000,
                    "operationsPerSecond": result.operationsPerSecond
                ]
                if let data = try? JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys]),
                   let str = String(data: data, encoding: .utf8) {
                    print(str)
                }
            } else {
                print("Benchmark: \(input) (frame \(frame))")
                print("Transfer Syntax: \(tsLabel(dicom.transferSyntaxUID))")
                print("Codestream: \(ByteCountFormatter.string(fromByteCount: Int64(codestream.count), countStyle: .file))")
                print("Iterations: \(iterations)")
                print("")
                print(String(format: "  Average:  %7.2f ms", result.averageTime * 1000))
                print(String(format: "  Median:   %7.2f ms", result.medianTime * 1000))
                print(String(format: "  Min:      %7.2f ms", result.minTime * 1000))
                print(String(format: "  Max:      %7.2f ms", result.maxTime * 1000))
                print(String(format: "  Std Dev:  %7.2f ms", result.standardDeviation * 1000))
                print(String(format: "  Throughput: %.1f fps", result.operationsPerSecond))
            }
        }
    }
}

// MARK: - compare

@available(macOS 10.15, *)
extension DICOMJ2K {
    struct CompareCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "compare",
            abstract: "Compute PSNR / MSE between two DICOM images",
            discussion: """
                Decodes both DICOM files and computes pixel-level fidelity metrics
                between the reference and test image:
                  MSE   — Mean Squared Error (0 = identical)
                  PSNR  — Peak Signal-to-Noise Ratio in dB (∞ = identical, ≥50 = excellent)
                  MAE   — Mean Absolute Error

                Examples:
                  dicom-j2k compare ref.dcm test.dcm
                  dicom-j2k compare ref.dcm test.dcm --json
                  dicom-j2k compare ref.dcm test.dcm --frame 3
                """
        )

        @Argument(help: "Reference DICOM file")
        var reference: String

        @Argument(help: "Test DICOM file")
        var test: String

        @Option(name: .long, help: "Frame index (0-based, default 0)")
        var frame: Int = 0

        @Flag(name: .long, help: "Output as JSON")
        var json: Bool = false

        mutating func run() throws {
            let refDICOM = try loadDICOM(at: reference)
            let tstDICOM = try loadDICOM(at: test)

            // Prefer J2K decode; fall back to PixelData for uncompressed
            let refPixels: [Double]
            let tstPixels: [Double]
            let maxVal: Double

            if isJ2KTransferSyntax(refDICOM.transferSyntaxUID),
               let cs = j2kCodestream(from: refDICOM, frameIndex: frame) {
                let img = try decodeJ2K(cs)
                refPixels = pixelDoubles(from: img)
                maxVal = Double((1 << (img.components.first?.bitDepth ?? 16)) - 1)
            } else if let pd = refDICOM.pixelData(), let fd = pd.frameData(at: frame) {
                refPixels = fd.map { Double($0) }
                maxVal = Double((1 << refDICOM.pixelDataDescriptor()!.bitsStored) - 1)
            } else {
                throw ValidationError("Cannot extract pixel data from reference file.")
            }

            if isJ2KTransferSyntax(tstDICOM.transferSyntaxUID),
               let cs = j2kCodestream(from: tstDICOM, frameIndex: frame) {
                let img = try decodeJ2K(cs)
                tstPixels = pixelDoubles(from: img)
            } else if let pd = tstDICOM.pixelData(), let fd = pd.frameData(at: frame) {
                tstPixels = fd.map { Double($0) }
            } else {
                throw ValidationError("Cannot extract pixel data from test file.")
            }

            guard refPixels.count == tstPixels.count else {
                throw ValidationError(
                    "Pixel count mismatch: reference has \(refPixels.count), test has \(tstPixels.count)."
                )
            }

            let n = Double(refPixels.count)
            let mse = zip(refPixels, tstPixels).map { pow($0 - $1, 2) }.reduce(0, +) / n
            let mae = zip(refPixels, tstPixels).map { abs($0 - $1) }.reduce(0, +) / n
            let psnr = mse == 0 ? Double.infinity : 20 * log10(maxVal) - 10 * log10(mse)
            let identical = mse == 0

            if json {
                let out: [String: Any] = [
                    "reference": reference,
                    "test": test,
                    "frame": frame,
                    "pixelCount": refPixels.count,
                    "mse": mse,
                    "mae": mae,
                    "psnr": psnr.isInfinite ? "Infinity" : psnr,
                    "identical": identical
                ]
                if let data = try? JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys]),
                   let str = String(data: data, encoding: .utf8) {
                    print(str)
                }
            } else {
                print("Comparison: \(reference) vs \(test) (frame \(frame))")
                print("")
                print(String(format: "  MSE:  %.4f", mse))
                print(String(format: "  MAE:  %.4f", mae))
                if psnr.isInfinite {
                    print("  PSNR: ∞ dB (identical)")
                } else {
                    print(String(format: "  PSNR: %.2f dB", psnr))
                }
                print("  Identical: \(identical ? "Yes" : "No")")
            }
        }

        private func pixelDoubles(from image: J2KImage) -> [Double] {
            guard let comp = image.components.first else { return [] }
            let bytesPerSample = comp.bitDepth <= 8 ? 1 : 2
            if bytesPerSample == 1 {
                return comp.data.map { Double($0) }
            } else {
                var values = [Double]()
                values.reserveCapacity(comp.data.count / 2)
                comp.data.withUnsafeBytes { ptr in
                    let shorts = ptr.bindMemory(to: UInt16.self)
                    for i in 0..<(comp.data.count / 2) {
                        values.append(Double(shorts[i]))
                    }
                }
                return values
            }
        }
    }
}

// MARK: - completions

@available(macOS 10.15, *)
extension DICOMJ2K {
    struct CompletionsCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "completions",
            abstract: "Generate shell completion scripts",
            discussion: """
                Generates shell completion scripts for bash, zsh, or fish.

                Examples:
                  dicom-j2k completions bash >> ~/.bash_profile
                  dicom-j2k completions zsh  > ~/.zsh/completions/_dicom-j2k
                  dicom-j2k completions fish > ~/.config/fish/completions/dicom-j2k.fish
                """
        )

        @Argument(help: "Shell type: bash, zsh, or fish")
        var shell: String

        mutating func validate() throws {
            guard ["bash", "zsh", "fish"].contains(shell) else {
                throw ValidationError("Shell must be bash, zsh, or fish")
            }
        }

        mutating func run() throws {
            switch shell {
            case "bash":
                print(bashCompletion())
            case "zsh":
                print(zshCompletion())
            case "fish":
                print(fishCompletion())
            default:
                break
            }
        }

        private func bashCompletion() -> String {
            """
            # bash completion for dicom-j2k
            _dicom_j2k() {
                local cur prev opts cmds
                COMPREPLY=()
                cur="${COMP_WORDS[COMP_CWORD]}"
                prev="${COMP_WORDS[COMP_CWORD-1]}"
                cmds="info validate transcode reduce roi benchmark compare completions"
                opts="--help --version"
                case "${prev}" in
                    info|validate|benchmark|compare) COMPREPLY=($(compgen -f -- "${cur}")); return 0;;
                    transcode|reduce|roi) COMPREPLY=($(compgen -f -- "${cur}")); return 0;;
                    --target) COMPREPLY=($(compgen -W "j2k-lossless j2k htj2k-lossless htj2k-rpcl htj2k" -- "${cur}")); return 0;;
                    completions) COMPREPLY=($(compgen -W "bash zsh fish" -- "${cur}")); return 0;;
                    *) COMPREPLY=($(compgen -W "${cmds} ${opts}" -- "${cur}")); return 0;;
                esac
            }
            complete -F _dicom_j2k dicom-j2k
            """
        }

        private func zshCompletion() -> String {
            """
            #compdef dicom-j2k
            _dicom_j2k() {
                local -a cmds
                cmds=(
                    'info:Show J2K codestream metadata'
                    'validate:ISO 15444-4 conformance check'
                    'transcode:Transcode J2K<->HTJ2K'
                    'reduce:Re-encode at lower resolution/quality'
                    'roi:Extract region of interest'
                    'benchmark:Decode-speed benchmark'
                    'compare:Compute PSNR/MSE between images'
                    'completions:Generate shell completions'
                )
                _describe 'command' cmds
            }
            _dicom_j2k
            """
        }

        private func fishCompletion() -> String {
            """
            # fish completion for dicom-j2k
            complete -c dicom-j2k -f
            complete -c dicom-j2k -n __fish_use_subcommand -a info       -d 'Show J2K codestream metadata'
            complete -c dicom-j2k -n __fish_use_subcommand -a validate   -d 'ISO 15444-4 conformance check'
            complete -c dicom-j2k -n __fish_use_subcommand -a transcode  -d 'Transcode J2K<->HTJ2K'
            complete -c dicom-j2k -n __fish_use_subcommand -a reduce     -d 'Re-encode at lower resolution/quality'
            complete -c dicom-j2k -n __fish_use_subcommand -a roi        -d 'Extract region of interest'
            complete -c dicom-j2k -n __fish_use_subcommand -a benchmark  -d 'Decode-speed benchmark'
            complete -c dicom-j2k -n __fish_use_subcommand -a compare    -d 'Compute PSNR/MSE between images'
            complete -c dicom-j2k -n __fish_use_subcommand -a completions -d 'Generate shell completions'
            """
        }
    }
}

// MARK: - Entry point

if #available(macOS 10.15, *) {
    DICOMJ2K.main()
} else {
    fputs("dicom-j2k requires macOS 10.15 or later.\n", stderr)
    exit(1)
}
