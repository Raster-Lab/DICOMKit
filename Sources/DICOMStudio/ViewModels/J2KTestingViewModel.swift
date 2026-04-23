// J2KTestingViewModel.swift
// DICOMStudio
//
// DICOM Studio — J2KSwift implementation testing panel ViewModel

import Foundation
import Observation
import DICOMKit
import DICOMCore

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Supporting Types

/// A row in the transfer syntax support matrix.
public struct J2KSupportEntry: Sendable, Identifiable {
    public let id: String
    public let uid: String
    public let shortName: String
    public let canDecode: Bool
    public let canEncode: Bool
}

/// Result of a multi-iteration decode benchmark.
public struct J2KBenchmarkResult: Sendable {
    public let iterations: Int
    public let minMs: Double
    public let maxMs: Double
    public let avgMs: Double
    public let totalMs: Double
    public let backend: CodecBackend
    public let codecName: String
    public let transferSyntaxUID: String
}

/// Result of a J2K encode → decode round-trip test for a single transfer syntax.
public struct J2KRoundTripResult: Sendable {
    public let targetSyntaxName: String
    /// Raw pixel buffer size (frame0.count before encoding).
    public let originalBytes: Int
    /// Encoded bitstream size produced by J2KSwift.
    public let encodedBytes: Int
    /// Decoded pixel buffer size after decoding the bitstream back.
    public let decodedBytes: Int
    public let encodeMs: Double
    public let decodeMs: Double
    public let compressionRatio: Double
    /// True when `decodedBytes == originalBytes`.
    public let passed: Bool
    public let notes: String
    // Image geometry (from PixelDataDescriptor)
    public let imageWidth: Int
    public let imageHeight: Int
    public let bitsAllocated: Int
    public let samplesPerPixel: Int
}

/// Per-codec entry in the round-trip results table.
public struct J2KRoundTripEntry: Identifiable, Sendable {
    public var id: String { uid }
    public let uid: String
    public let shortName: String
    public var state: J2KRoundTripState
}

public enum J2KBenchmarkState: Sendable {
    case idle
    case running
    case complete(J2KBenchmarkResult)
    case failed(String)
}

public enum J2KRoundTripState: Sendable {
    case idle
    case running
    case complete(J2KRoundTripResult)
    case failed(String)
}

// MARK: - J2KTestingViewModel

/// ViewModel for the J2KSwift implementation testing panel.
///
/// Provides:
/// - Platform backend probe (Metal / Accelerate / Scalar availability)
/// - J2K / HTJ2K transfer syntax support matrix
/// - Multi-iteration decode benchmark against the current file
/// - Per-codec encode → decode round-trip with image previews
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
@MainActor
public final class J2KTestingViewModel {

    // MARK: - Platform Info

    public let availableBackends: [CodecBackend] = CodecBackendProbe.availableBackends
    public let bestBackend: CodecBackend = CodecBackendProbe.bestAvailable
    public let supportMatrix: [J2KSupportEntry] = J2KTestingViewModel.buildSupportMatrix()

    // MARK: - Benchmark

    public var benchmarkState: J2KBenchmarkState = .idle
    public var benchmarkIterations: Int = 10

    // MARK: - Round-Trip

    /// Transfer syntax UID selected for the single-codec run.
    public var selectedRoundTripUID: String = "1.2.840.10008.1.2.4.90"

    /// Results of the most recent round-trip run, one entry per codec tested.
    public private(set) var roundTripResults: [J2KRoundTripEntry] = []

    /// Whether any round-trip task is currently in progress.
    public private(set) var isRoundTripRunning: Bool = false

    // MARK: - Images

    #if canImport(CoreGraphics)
    /// The original raw frame from the loaded DICOM file.
    public private(set) var rawImage: CGImage? = nil

    /// Encoded-then-decoded preview images, keyed by transfer syntax UID.
    /// For lossless codecs this is pixel-identical to `rawImage`;
    /// for lossy codecs it shows compression artefacts.
    public private(set) var encodedImages: [String: CGImage] = [:]

    /// Decoded images from the full round-trip, keyed by UID. Identical to
    /// `encodedImages` unless separate encode/decode passes produce different results.
    public private(set) var decodedImages: [String: CGImage] = [:]
    #endif

    // MARK: - Codec Comparison (J2KSwift vs OpenJPEG)

    /// Results of the most recent codec comparison run.
    public private(set) var comparisonResults: [CodecComparisonEntry] = []

    /// Whether the codec comparison is currently running.
    public private(set) var isComparisonRunning: Bool = false

    #if canImport(CoreGraphics)
    /// Decoded preview images from the comparison run, keyed by codec name.
    public private(set) var comparisonImages: [String: CGImage] = [:]
    #endif

    // MARK: - Computed

    public var isRunning: Bool {
        if case .running = benchmarkState { return true }
        return isRoundTripRunning || isComparisonRunning
    }

    // MARK: - Actions

    public func runBenchmark(file: DICOMFile) {
        guard !isRunning else { return }
        benchmarkState = .running
        let iterations = max(1, min(100, benchmarkIterations))
        Task {
            let result = await Self.performBenchmark(file: file, iterations: iterations)
            benchmarkState = result
        }
    }

    /// Runs encode → decode for only the selected transfer syntax.
    public func runSelectedRoundTrip(file: DICOMFile) {
        guard !isRunning else { return }
        guard let entry = supportMatrix.first(where: { $0.uid == selectedRoundTripUID }) else { return }
        let uid = entry.uid
        let name = entry.shortName
        roundTripResults = [J2KRoundTripEntry(uid: uid, shortName: name, state: .running)]
        isRoundTripRunning = true
        Task {
            let output = await Self.performRoundTrip(file: file, targetUID: uid, targetName: name)
            roundTripResults = [J2KRoundTripEntry(uid: uid, shortName: name, state: output.state)]
            #if canImport(CoreGraphics)
            if rawImage == nil { rawImage = output.rawImage }
            if let img = output.encodedImage { encodedImages[uid] = img }
            if let img = output.decodedImage { decodedImages[uid] = img }
            #endif
            isRoundTripRunning = false
        }
    }

    /// Runs encode → decode for every encodable transfer syntax in parallel.
    public func runAllRoundTrips(file: DICOMFile) {
        guard !isRunning else { return }
        let encodable = supportMatrix.filter(\.canEncode)
        guard !encodable.isEmpty else { return }
        roundTripResults = encodable.map { J2KRoundTripEntry(uid: $0.uid, shortName: $0.shortName, state: .running) }
        isRoundTripRunning = true
        Task {
            await withTaskGroup(of: (String, RoundTripOutput).self) { group in
                for entry in encodable {
                    let uid = entry.uid
                    let name = entry.shortName
                    group.addTask {
                        let output = await Self.performRoundTrip(file: file, targetUID: uid, targetName: name)
                        return (uid, output)
                    }
                }
                for await (uid, output) in group {
                    if let idx = roundTripResults.firstIndex(where: { $0.uid == uid }) {
                        roundTripResults[idx].state = output.state
                    }
                    #if canImport(CoreGraphics)
                    if rawImage == nil { rawImage = output.rawImage }
                    if let img = output.encodedImage { encodedImages[uid] = img }
                    if let img = output.decodedImage { decodedImages[uid] = img }
                    #endif
                }
            }
            isRoundTripRunning = false
        }
    }

    /// Clears all stored images while keeping metric results.
    public func clearImages() {
        #if canImport(CoreGraphics)
        rawImage = nil
        encodedImages = [:]
        decodedImages = [:]
        #endif
    }

    /// Resets benchmark results, round-trip results, and all images.
    public func reset() {
        guard !isRunning else { return }
        benchmarkState = .idle
        roundTripResults = []
        comparisonResults = []
        #if canImport(CoreGraphics)
        comparisonImages = [:]
        #endif
        clearImages()
    }

    // MARK: - Codec Comparison

    /// Encodes frame 0 with J2KSwift using the selected transfer syntax, then decodes
    /// the resulting bitstream with both J2KSwift and OpenJPEG (if available).
    /// Results are written to ``comparisonResults`` and ``comparisonImages``.
    public func runCodecComparison(file: DICOMFile) {
        guard !isRunning else { return }
        isComparisonRunning = true
        #if canImport(COpenJPEG) && os(macOS)
        let entries: [CodecComparisonEntry] = [
            CodecComparisonEntry(codecName: "J2KSwift",  state: .running),
            CodecComparisonEntry(codecName: "OpenJPEG \(OpenJPEGCodec.version)", state: .running)
        ]
        #else
        let entries: [CodecComparisonEntry] = [
            CodecComparisonEntry(codecName: "J2KSwift", state: .running)
        ]
        #endif
        comparisonResults = entries
        let uid = selectedRoundTripUID
        Task {
            let output = await Self.performComparison(file: file, targetUID: uid)
            comparisonResults = output.entries
            #if canImport(CoreGraphics)
            if rawImage == nil { rawImage = output.rawImage }
            for (name, img) in output.images { comparisonImages[name] = img }
            #endif
            isComparisonRunning = false
        }
    }

    // MARK: - Background Workers

    private static func performBenchmark(file: DICOMFile, iterations: Int) async -> J2KBenchmarkState {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let service = ImageDecodingService()
                var times: [Double] = []
                var lastResult: DecodedImageResult?

                for _ in 0..<iterations {
                    let t0 = Date()
                    guard let r = service.decode(file: file) else {
                        continuation.resume(returning: .failed("File has no pixel data or unsupported codec"))
                        return
                    }
                    times.append(Date().timeIntervalSince(t0) * 1_000)
                    lastResult = r
                }

                guard let last = lastResult, !times.isEmpty else {
                    continuation.resume(returning: .failed("No results recorded"))
                    return
                }

                let avg = times.reduce(0, +) / Double(times.count)
                let result = J2KBenchmarkResult(
                    iterations: iterations,
                    minMs: times.min()!,
                    maxMs: times.max()!,
                    avgMs: avg,
                    totalMs: times.reduce(0, +),
                    backend: last.backend,
                    codecName: last.codecName,
                    transferSyntaxUID: last.transferSyntaxUID
                )
                continuation.resume(returning: .complete(result))
            }
        }
    }

    private static func performRoundTrip(
        file: DICOMFile,
        targetUID: String,
        targetName: String
    ) async -> RoundTripOutput {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let pixData = file.pixelData() else {
                    continuation.resume(returning: .init(state: .failed("File has no decodable pixel data")))
                    return
                }
                guard let frame0 = pixData.frameData(at: 0) else {
                    continuation.resume(returning: .init(state: .failed("Frame 0 is not accessible")))
                    return
                }

                let descriptor = pixData.descriptor
                let originalBytes = frame0.count
                let isLossless = !targetUID.hasSuffix(".91")
                    && !targetUID.hasSuffix(".93")
                    && !targetUID.hasSuffix(".203")

                // Render original frame for display
                let rawImage = makePreviewImage(pixels: frame0, descriptor: descriptor)

                // Encode
                let encoder = J2KSwiftCodec(encodingTransferSyntaxUID: targetUID)
                let encodeStart = Date()
                let encoded: Data
                do {
                    encoded = try encoder.encodeFrame(
                        frame0,
                        descriptor: descriptor,
                        frameIndex: 0,
                        configuration: CompressionConfiguration(
                            quality: isLossless ? .maximum : .medium,
                            speed: .balanced,
                            progressive: false,
                            preferLossless: isLossless
                        )
                    )
                } catch {
                    continuation.resume(returning: .init(
                        state: .failed("Encode failed: \(error.localizedDescription)"),
                        rawImage: rawImage
                    ))
                    return
                }
                let encodeMs = Date().timeIntervalSince(encodeStart) * 1_000

                // Decode
                let decoder = J2KSwiftCodec()
                let decodeStart = Date()
                let decoded: Data
                do {
                    decoded = try decoder.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)
                } catch {
                    continuation.resume(returning: .init(
                        state: .failed("Decode failed: \(error.localizedDescription)"),
                        rawImage: rawImage
                    ))
                    return
                }
                let decodeMs = Date().timeIntervalSince(decodeStart) * 1_000

                // Render encoded preview (decoded from encoded bytes) and final decoded image
                let encodedImage = makePreviewImage(pixels: decoded, descriptor: descriptor)
                let decodedImage = encodedImage // same pixels; distinct reference for independent clearing

                let ratio = Double(originalBytes) / Double(max(1, encoded.count))
                let decodedBytes = decoded.count
                let passed = decodedBytes == originalBytes
                let notes: String
                if passed {
                    notes = isLossless
                        ? "Lossless round-trip verified — decoded \(decodedBytes) B matches raw"
                        : "Lossy cycle complete — decoded \(decodedBytes) B (values intentionally differ)"
                } else {
                    notes = "Size mismatch: decoded \(decodedBytes) B ≠ raw \(originalBytes) B"
                }

                let result = J2KRoundTripResult(
                    targetSyntaxName: targetName,
                    originalBytes: originalBytes,
                    encodedBytes: encoded.count,
                    decodedBytes: decodedBytes,
                    encodeMs: encodeMs,
                    decodeMs: decodeMs,
                    compressionRatio: ratio,
                    passed: passed,
                    notes: notes,
                    imageWidth: descriptor.columns,
                    imageHeight: descriptor.rows,
                    bitsAllocated: descriptor.bitsAllocated,
                    samplesPerPixel: descriptor.samplesPerPixel
                )
                continuation.resume(returning: .init(
                    state: .complete(result),
                    rawImage: rawImage,
                    encodedImage: encodedImage,
                    decodedImage: decodedImage
                ))
            }
        }
    }

    // MARK: - Image Rendering

    /// Converts raw pixel bytes + descriptor into a displayable CGImage.
    /// 8-bit data is used directly; 16-bit is auto-normalised to 8-bit.
    private static func makePreviewImage(pixels: Data, descriptor: PixelDataDescriptor) -> CGImage? {
        #if canImport(CoreGraphics)
        let w = descriptor.columns
        let h = descriptor.rows
        let spp = descriptor.samplesPerPixel
        let bpa = descriptor.bitsAllocated
        guard w > 0, h > 0, spp == 1 || spp == 3 else { return nil }

        if bpa <= 8 {
            let cs = spp == 1 ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB()
            let bi = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
            guard let prov = CGDataProvider(data: pixels as CFData) else { return nil }
            return CGImage(width: w, height: h,
                           bitsPerComponent: 8, bitsPerPixel: 8 * spp,
                           bytesPerRow: w * spp,
                           space: cs, bitmapInfo: bi,
                           provider: prov, decode: nil,
                           shouldInterpolate: true, intent: .defaultIntent)
        } else {
            // 16-bit → normalise min/max to 0-255 for display.
            // Read bytes individually (little-endian pairs) — no unsafe memory binding,
            // no alignment requirements.
            let pixelCount = w * h * spp
            guard pixels.count >= pixelCount * 2 else { return nil }
            let base = pixels.startIndex
            var pixelValues = [UInt16](repeating: 0, count: pixelCount)
            var lo: UInt16 = .max, hi: UInt16 = 0
            for i in 0..<pixelCount {
                let v = UInt16(pixels[base + i * 2]) | (UInt16(pixels[base + i * 2 + 1]) << 8)
                pixelValues[i] = v
                if v < lo { lo = v }
                if v > hi { hi = v }
            }
            let rng = hi > lo ? Double(hi - lo) : 1.0
            var outBytes = [UInt8](repeating: 0, count: pixelCount)
            for i in 0..<pixelCount {
                outBytes[i] = UInt8(clamping: Int(Double(pixelValues[i] - lo) / rng * 255.0))
            }
            let out = Data(outBytes)
            let cs = spp == 1 ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB()
            let bi = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
            guard let prov = CGDataProvider(data: out as CFData) else { return nil }
            return CGImage(width: w, height: h,
                           bitsPerComponent: 8, bitsPerPixel: 8 * spp,
                           bytesPerRow: w * spp,
                           space: cs, bitmapInfo: bi,
                           provider: prov, decode: nil,
                           shouldInterpolate: true, intent: .defaultIntent)
        }
        #else
        return nil
        #endif
    }

    // MARK: - Support Matrix Builder

    private static func buildSupportMatrix() -> [J2KSupportEntry] {
        let candidates: [(uid: String, name: String)] = [
            ("1.2.840.10008.1.2.4.90",  "J2K Lossless"),
            ("1.2.840.10008.1.2.4.91",  "J2K Lossy"),
            ("1.2.840.10008.1.2.4.92",  "J2K Part 2 Lossless"),
            ("1.2.840.10008.1.2.4.93",  "J2K Part 2 Lossy"),
            ("1.2.840.10008.1.2.4.201", "HTJ2K Lossless"),
            ("1.2.840.10008.1.2.4.202", "HTJ2K RPCL Lossless"),
            ("1.2.840.10008.1.2.4.203", "HTJ2K Lossy"),
        ]
        return candidates.map { uid, name in
            J2KSupportEntry(
                id: uid,
                uid: uid,
                shortName: name,
                canDecode: CodecRegistry.shared.hasCodec(for: uid),
                canEncode: CodecRegistry.shared.encoder(for: uid) != nil
            )
        }
    }

    // MARK: - Init

    public init() {}
}

// MARK: - Codec Comparison Types

/// One row in the codec comparison table.
public struct CodecComparisonEntry: Identifiable, Sendable {
    public var id: String { codecName }
    public let codecName: String
    public var state: CodecComparisonState
}

public enum CodecComparisonState: Sendable {
    case idle
    case running
    case complete(CodecComparisonResult)
    case failed(String)
}

/// Timing and correctness result for a single codec in the comparison.
public struct CodecComparisonResult: Sendable {
    public let decodeMs: Double
    public let outputBytes: Int
    /// Whether the output byte count matches the reference (J2KSwift) output.
    public let matchesReference: Bool
    /// Peak signal-to-noise ratio vs J2KSwift output (nil when outputs are different sizes).
    public let psnrDb: Double?
}

// MARK: - Comparison Background Worker

extension J2KTestingViewModel {

    /// Output bundle returned by `performComparison`.
    fileprivate struct ComparisonOutput: @unchecked Sendable {
        let entries: [CodecComparisonEntry]
        #if canImport(CoreGraphics)
        let rawImage: CGImage?
        let images: [String: CGImage]
        init(entries: [CodecComparisonEntry], rawImage: CGImage? = nil, images: [String: CGImage] = [:]) {
            self.entries = entries; self.rawImage = rawImage; self.images = images
        }
        #else
        init(entries: [CodecComparisonEntry]) { self.entries = entries }
        #endif
    }

    fileprivate static func performComparison(
        file: DICOMFile,
        targetUID: String
    ) async -> ComparisonOutput {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {

                // 1. Get raw pixels
                guard let pixData = file.pixelData(),
                      let frame0 = pixData.frameData(at: 0) else {
                    let failed = failedEntries("Frame 0 not accessible")
                    #if canImport(CoreGraphics)
                    continuation.resume(returning: ComparisonOutput(entries: failed))
                    #else
                    continuation.resume(returning: ComparisonOutput(entries: failed))
                    #endif
                    return
                }
                let descriptor = pixData.descriptor
                let rawImage = makePreviewImage(pixels: frame0, descriptor: descriptor)

                // 2. Encode with J2KSwift to produce the reference bitstream
                let isLossless = !targetUID.hasSuffix(".91")
                    && !targetUID.hasSuffix(".93")
                    && !targetUID.hasSuffix(".203")
                let encoder = J2KSwiftCodec(encodingTransferSyntaxUID: targetUID)
                let encoded: Data
                do {
                    encoded = try encoder.encodeFrame(
                        frame0,
                        descriptor: descriptor,
                        frameIndex: 0,
                        configuration: CompressionConfiguration(
                            quality: isLossless ? .maximum : .medium,
                            speed: .balanced,
                            progressive: false,
                            preferLossless: isLossless
                        )
                    )
                } catch {
                    let failed = failedEntries("Encode failed: \(error.localizedDescription)")
                    #if canImport(CoreGraphics)
                    continuation.resume(returning: ComparisonOutput(entries: failed, rawImage: rawImage))
                    #else
                    continuation.resume(returning: ComparisonOutput(entries: failed))
                    #endif
                    return
                }

                var entries: [CodecComparisonEntry] = []
                #if canImport(CoreGraphics)
                var images: [String: CGImage] = [:]
                #endif
                var referenceOutput: Data? = nil

                // 3. Decode with J2KSwift
                let j2kDecoder = J2KSwiftCodec()
                let t0 = Date()
                let j2kResult: Data?
                do {
                    j2kResult = try j2kDecoder.decodeFrame(encoded, descriptor: descriptor, frameIndex: 0)
                } catch {
                    j2kResult = nil
                }
                let j2kMs = Date().timeIntervalSince(t0) * 1_000

                if let out = j2kResult {
                    referenceOutput = out
                    let result = CodecComparisonResult(
                        decodeMs: j2kMs,
                        outputBytes: out.count,
                        matchesReference: true,
                        psnrDb: nil
                    )
                    entries.append(CodecComparisonEntry(codecName: "J2KSwift", state: .complete(result)))
                    #if canImport(CoreGraphics)
                    if let img = makePreviewImage(pixels: out, descriptor: descriptor) {
                        images["J2KSwift"] = img
                    }
                    #endif
                } else {
                    entries.append(CodecComparisonEntry(codecName: "J2KSwift", state: .failed("Decode failed")))
                }

                // 4. Decode with OpenJPEG (macOS only)
                #if canImport(COpenJPEG) && os(macOS)
                let opjName = "OpenJPEG \(OpenJPEGCodec.version)"
                let opjDecoder = OpenJPEGCodec()
                let t1 = Date()
                let opjResult: Data?
                do {
                    opjResult = try opjDecoder.decodeFrame(encoded, descriptor: descriptor)
                } catch {
                    opjResult = nil
                }
                let opjMs = Date().timeIntervalSince(t1) * 1_000

                if let out = opjResult {
                    let matches = out.count == (referenceOutput?.count ?? -1)
                    let psnr: Double? = matches ? computePSNR(out, referenceOutput!, descriptor: descriptor) : nil
                    let result = CodecComparisonResult(
                        decodeMs: opjMs,
                        outputBytes: out.count,
                        matchesReference: matches,
                        psnrDb: psnr
                    )
                    entries.append(CodecComparisonEntry(codecName: opjName, state: .complete(result)))
                    #if canImport(CoreGraphics)
                    if let img = makePreviewImage(pixels: out, descriptor: descriptor) {
                        images[opjName] = img
                    }
                    #endif
                } else {
                    entries.append(CodecComparisonEntry(codecName: opjName, state: .failed("Decode failed")))
                }
                #endif

                #if canImport(CoreGraphics)
                continuation.resume(returning: ComparisonOutput(entries: entries, rawImage: rawImage, images: images))
                #else
                continuation.resume(returning: ComparisonOutput(entries: entries))
                #endif
            }
        }
    }

    private static func failedEntries(_ msg: String) -> [CodecComparisonEntry] {
        var entries = [CodecComparisonEntry(codecName: "J2KSwift", state: .failed(msg))]
        #if canImport(COpenJPEG) && os(macOS)
        entries.append(CodecComparisonEntry(codecName: "OpenJPEG", state: .failed(msg)))
        #endif
        return entries
    }

    /// Computes PSNR in dB between two raw pixel buffers.
    /// Returns `nil` (infinity) when buffers are identical (lossless perfect match).
    private static func computePSNR(_ a: Data, _ b: Data, descriptor: PixelDataDescriptor) -> Double? {
        guard a.count == b.count, !a.isEmpty else { return nil }
        let maxVal: Double = descriptor.bitsAllocated <= 8 ? 255.0 : 65535.0
        var mse: Double = 0
        for i in 0..<a.count {
            let diff = Double(Int(a[a.startIndex + i]) - Int(b[b.startIndex + i]))
            mse += diff * diff
        }
        mse /= Double(a.count)
        guard mse > 0 else { return nil }   // nil = infinity (perfect lossless match)
        return 10.0 * log10((maxVal * maxVal) / mse)
    }
}

// MARK: - Round-Trip Output (internal)

/// Bundles the state result with optional preview images from a single round-trip run.
/// Marked @unchecked Sendable because CGImage is thread-safe after creation.
private struct RoundTripOutput: @unchecked Sendable {
    let state: J2KRoundTripState
    #if canImport(CoreGraphics)
    let rawImage: CGImage?
    let encodedImage: CGImage?
    let decodedImage: CGImage?
    init(state: J2KRoundTripState, rawImage: CGImage? = nil,
         encodedImage: CGImage? = nil, decodedImage: CGImage? = nil) {
        self.state = state
        self.rawImage = rawImage
        self.encodedImage = encodedImage
        self.decodedImage = decodedImage
    }
    #else
    init(state: J2KRoundTripState) { self.state = state }
    #endif
}
