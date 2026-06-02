// J2KTestBenchModels.swift
// DICOMStudio
//
// DICOM Studio — J2K Test Bench data model.
//
// The test bench runs a matrix of (fixture × transfer syntax × codec) cells,
// scores each against a real pass/fail criterion — bit-exact reconstruction
// for lossless syntaxes, a PSNR threshold for lossy — and persists every run
// so codec speed/quality regressions are visible over time.

import Foundation
import DICOMCore

// MARK: - Errors

/// A lightweight, message-carrying error so bench sub-operations can surface a
/// human-readable reason through `Result`.
public struct J2KBenchError: Error, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
}

// MARK: - Codec

/// A compression family the bench can exercise. Each format names one
/// reference Swift codec (which produces the codestream) plus the same-family
/// peer codecs that decode it — mirroring how J2KSwift is compared against
/// Kakadu/Grok/OpenJPEG, replicated per format.
public enum J2KBenchFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case jpeg2000 = "JPEG 2000"
    case jpeg     = "JPEG"
    case jpegLS   = "JPEG-LS"
    case jpegXL   = "JPEG XL"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .jpeg2000: return "square.stack.3d.up"
        case .jpeg:     return "photo"
        case .jpegLS:   return "waveform"
        case .jpegXL:   return "sparkles"
        }
    }

    /// The Swift codec that produces this format's reference codestream.
    public var referenceCodec: J2KBenchCodec {
        switch self {
        case .jpeg2000: return .j2kSwift
        case .jpeg:     return .jliSwift
        case .jpegLS:   return .jlSwift
        case .jpegXL:   return .jxlSwift
        }
    }

    /// All codecs in this format's bench, reference first then same-family peers.
    public var codecs: [J2KBenchCodec] {
        switch self {
        case .jpeg2000: return [.j2kSwift, .openJPEG, .kakadu, .grok]
        case .jpeg:     return [.jliSwift, .djpeg]
        case .jpegLS:   return [.jlSwift]
        case .jpegXL:   return [.jxlSwift, .djxl]
        }
    }
}

/// A codec participating in a test-bench run.
public enum J2KBenchCodec: String, CaseIterable, Identifiable, Codable, Sendable {
    // JPEG 2000 family
    case j2kSwift = "J2KSwift"
    case openJPEG = "OpenJPEG"
    case kakadu   = "Kakadu"
    case grok     = "Grok"
    // JPEG family
    case jliSwift = "JLISwift"
    case djpeg    = "djpeg"
    // JPEG-LS family
    case jlSwift  = "JLSwift"
    // JPEG XL family
    case jxlSwift = "JXLSwift"
    case djxl     = "djxl"

    public var id: String { rawValue }

    /// The compression family this codec belongs to.
    public var format: J2KBenchFormat {
        switch self {
        case .j2kSwift, .openJPEG, .kakadu, .grok: return .jpeg2000
        case .jliSwift, .djpeg:                    return .jpeg
        case .jlSwift:                             return .jpegLS
        case .jxlSwift, .djxl:                     return .jpegXL
        }
    }

    /// True for the reference codec of each format — the one that produces the
    /// codestream its peers decode. Peers are decode-only in the bench.
    public var encodes: Bool { self == format.referenceCodec }

    /// SF Symbol shown beside the codec in the results grid.
    public var systemImage: String {
        switch self {
        case .j2kSwift, .jliSwift, .jlSwift, .jxlSwift: return "swift"
        case .openJPEG:                                 return "shippingbox"
        case .kakadu, .grok, .djpeg, .djxl:             return "terminal"
        }
    }
}

// MARK: - Transfer syntax

/// A transfer syntax / mode the bench can exercise, tagged with its codec
/// family. JPEG 2000 has several; the other formats currently expose a single
/// lossless mode (the bench's axis is bit-exact round-trip + peer decode).
public struct J2KBenchSyntax: Identifiable, Hashable, Codable, Sendable {
    public let uid: String
    public let shortName: String
    /// The codec family this syntax belongs to.
    public let format: J2KBenchFormat
    /// Lossless syntaxes must reconstruct bit-exact; lossy ones are scored
    /// against a PSNR threshold.
    public let isLossless: Bool

    public var id: String { uid }

    public init(uid: String, shortName: String,
                format: J2KBenchFormat = .jpeg2000, isLossless: Bool? = nil) {
        self.uid = uid
        self.shortName = shortName
        self.format = format
        // JPEG 2000 keeps the original UID-suffix heuristic when not specified.
        self.isLossless = isLossless
            ?? (!uid.hasSuffix(".91") && !uid.hasSuffix(".93") && !uid.hasSuffix(".203"))
    }

    /// Every syntax across all formats. JPEG XL is bench-only (synthetic id, no
    /// DICOM transfer syntax); the rest use their real DICOM UIDs.
    public static let all: [J2KBenchSyntax] = [
        // JPEG 2000 / HTJ2K
        J2KBenchSyntax(uid: "1.2.840.10008.1.2.4.90",  shortName: "J2K Lossless"),
        J2KBenchSyntax(uid: "1.2.840.10008.1.2.4.91",  shortName: "J2K Lossy"),
        J2KBenchSyntax(uid: "1.2.840.10008.1.2.4.92",  shortName: "J2K Part 2 Lossless"),
        J2KBenchSyntax(uid: "1.2.840.10008.1.2.4.93",  shortName: "J2K Part 2 Lossy"),
        J2KBenchSyntax(uid: "1.2.840.10008.1.2.4.201", shortName: "HTJ2K Lossless"),
        J2KBenchSyntax(uid: "1.2.840.10008.1.2.4.202", shortName: "HTJ2K RPCL Lossless"),
        J2KBenchSyntax(uid: "1.2.840.10008.1.2.4.203", shortName: "HTJ2K Lossy"),
        // JPEG (JLISwift) — lossless SOF3 (DICOM JPEG Lossless, First-Order Prediction)
        J2KBenchSyntax(uid: "1.2.840.10008.1.2.4.70",  shortName: "JPEG Lossless",
                       format: .jpeg, isLossless: true),
        // JPEG-LS (JLSwift)
        J2KBenchSyntax(uid: "1.2.840.10008.1.2.4.80",  shortName: "JPEG-LS Lossless",
                       format: .jpegLS, isLossless: true),
        // JPEG XL (JXLSwift) — bench-only; no DICOM transfer syntax assigned
        J2KBenchSyntax(uid: "bench.jpegxl.lossless",   shortName: "JPEG XL Lossless",
                       format: .jpegXL, isLossless: true),
    ]

    /// Syntaxes belonging to a given format, in canonical order.
    public static func all(for format: J2KBenchFormat) -> [J2KBenchSyntax] {
        all.filter { $0.format == format }
    }

    public static func named(_ uid: String) -> J2KBenchSyntax? {
        all.first { $0.uid == uid }
    }
}

// MARK: - Fixture

/// One DICOM image in the test corpus. Geometry is cached on add so the
/// corpus list renders without re-reading every file.
public struct J2KTestFixture: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let path: String
    /// Absolute path of the original source file, used to de-duplicate the
    /// corpus. Optional so corpora saved before this field still decode.
    public let sourcePath: String?
    public var name: String
    public let columns: Int
    public let rows: Int
    public let bitsAllocated: Int
    public let samplesPerPixel: Int
    public let frameCount: Int
    public let photometric: String
    public let modality: String

    public init(id: UUID = UUID(), path: String, sourcePath: String? = nil,
                name: String, columns: Int, rows: Int, bitsAllocated: Int,
                samplesPerPixel: Int, frameCount: Int,
                photometric: String, modality: String) {
        self.id = id
        self.path = path
        self.sourcePath = sourcePath
        self.name = name
        self.columns = columns
        self.rows = rows
        self.bitsAllocated = bitsAllocated
        self.samplesPerPixel = samplesPerPixel
        self.frameCount = frameCount
        self.photometric = photometric
        self.modality = modality
    }

    /// Pixels per frame — used for nearest-baseline matching.
    public var pixelCount: Int { columns * rows }

    /// "512×512 · 16-bit · MONOCHROME2 · 3 frames"
    public var geometrySummary: String {
        let frames = frameCount == 1 ? "1 frame" : "\(frameCount) frames"
        let kind = samplesPerPixel >= 3 ? "RGB" : photometric
        return "\(columns)×\(rows) · \(bitsAllocated)-bit · \(kind) · \(frames)"
    }
}

// MARK: - Outcome

/// Outcome of one test cell against its pass criterion.
public enum J2KTestOutcome: Codable, Equatable, Sendable {
    /// Met the criterion — bit-exact (lossless) or PSNR ≥ threshold (lossy).
    case pass
    /// Ran cleanly but missed the criterion.
    case fail(String)
    /// Encode or decode threw.
    case error(String)
    /// Codec unavailable, or the operation does not apply.
    case skipped(String)

    public var isPass: Bool { if case .pass = self { return true } else { return false } }
    public var isFail: Bool { if case .fail = self { return true } else { return false } }
    public var isError: Bool { if case .error = self { return true } else { return false } }
    public var isSkipped: Bool { if case .skipped = self { return true } else { return false } }

    /// Human-readable detail for the results grid.
    public var detail: String {
        switch self {
        case .pass: return "Pass"
        case .fail(let reason): return reason
        case .error(let reason): return reason
        case .skipped(let reason): return reason
        }
    }
}

// MARK: - Cell

/// Result for one (fixture, syntax, codec) cell of the test matrix.
///
/// The fixture and syntax names are denormalized into the cell so a persisted
/// run is fully self-describing without the live corpus.
public struct J2KTestCell: Identifiable, Codable, Sendable {
    public let id: UUID
    public let fixtureName: String
    /// Modality of the source fixture (e.g. "CT") — denormalized so a loaded
    /// historical run can still be matched against the published baseline.
    public let fixtureModality: String
    /// Pixels per frame of the source fixture, for nearest-baseline matching.
    public let fixturePixelCount: Int
    public let syntaxUID: String
    public let syntaxName: String
    public let codec: J2KBenchCodec

    /// Encode time (ms) — populated only for the encoding codec (J2KSwift).
    public var encodeMs: Double?
    /// Decode time (ms) — median of the timed runs.
    public var decodeMs: Double?
    /// Encoded codestream size (bytes).
    public var encodedBytes: Int?
    /// Raw frame size (bytes) before encoding.
    public var rawBytes: Int?
    public var compressionRatio: Double?
    /// PSNR of the decoded frame vs the original, in dB. `nil` means infinite
    /// (bit-exact reconstruction).
    public var psnrDb: Double?
    public var outcome: J2KTestOutcome

    public init(id: UUID = UUID(), fixtureName: String,
                fixtureModality: String = "", fixturePixelCount: Int = 0,
                syntaxUID: String, syntaxName: String, codec: J2KBenchCodec,
                encodeMs: Double? = nil, decodeMs: Double? = nil,
                encodedBytes: Int? = nil, rawBytes: Int? = nil,
                compressionRatio: Double? = nil, psnrDb: Double? = nil,
                outcome: J2KTestOutcome) {
        self.id = id
        self.fixtureName = fixtureName
        self.fixtureModality = fixtureModality
        self.fixturePixelCount = fixturePixelCount
        self.syntaxUID = syntaxUID
        self.syntaxName = syntaxName
        self.codec = codec
        self.encodeMs = encodeMs
        self.decodeMs = decodeMs
        self.encodedBytes = encodedBytes
        self.rawBytes = rawBytes
        self.compressionRatio = compressionRatio
        self.psnrDb = psnrDb
        self.outcome = outcome
    }

    /// Stable identity across runs — used to line up regression deltas.
    public var matchKey: String { "\(fixtureName)|\(syntaxUID)|\(codec.rawValue)" }
}

// MARK: - Run

/// A complete test-bench run — the unit of history and regression diffing.
public struct J2KTestRun: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    /// "J2KSwift 10.9.3 · arm64" — the environment the run was captured on.
    public let environment: String
    public let cells: [J2KTestCell]
    public let fixtureCount: Int
    public let syntaxCount: Int

    public init(id: UUID = UUID(), timestamp: Date = Date(),
                environment: String, cells: [J2KTestCell],
                fixtureCount: Int, syntaxCount: Int) {
        self.id = id
        self.timestamp = timestamp
        self.environment = environment
        self.cells = cells
        self.fixtureCount = fixtureCount
        self.syntaxCount = syntaxCount
    }

    public var passCount: Int { cells.filter { $0.outcome.isPass }.count }
    public var failCount: Int { cells.filter { !$0.outcome.isPass }.count }
    public var totalCount: Int { cells.count }

    /// Cells keyed by `matchKey` for O(1) regression lookup.
    public var cellsByKey: [String: J2KTestCell] {
        Dictionary(cells.map { ($0.matchKey, $0) }, uniquingKeysWith: { a, _ in a })
    }
}

// MARK: - Plan

/// Configuration for a test-bench run.
public struct J2KTestPlan: Sendable {
    /// The compression family being benchmarked.
    public var format: J2KBenchFormat
    /// Transfer syntaxes to exercise (by UID).
    public var selectedSyntaxUIDs: Set<String>
    public var includeOpenJPEG: Bool
    public var includeKakadu: Bool
    public var includeGrok: Bool
    /// JPEG peer (libjpeg-turbo djpeg) — decodes the JLISwift codestream.
    public var includeDjpeg: Bool
    /// JPEG XL peer (libjxl djxl) — decodes the JXLSwift codestream.
    public var includeDjxl: Bool
    /// Which J2KSwift encode API produces the reference codestream (JPEG 2000 only).
    public var encodeMode: J2KSwiftEncodeMode
    /// Which J2KSwift decode API the J2KSwift row exercises (JPEG 2000 only).
    public var decodeMode: J2KSwiftDecodeMode
    /// Untimed warmups before timing (cross-host bench default: 2).
    public var warmups: Int
    /// Timed runs; the median is reported (cross-host bench default: 7).
    public var timedRuns: Int
    /// Minimum PSNR (dB) for a lossy cell to pass.
    public var lossyPSNRThresholdDb: Double

    public init(format: J2KBenchFormat = .jpeg2000,
                selectedSyntaxUIDs: Set<String> = ["1.2.840.10008.1.2.4.90",
                                                   "1.2.840.10008.1.2.4.201",
                                                   "1.2.840.10008.1.2.4.70",
                                                   "1.2.840.10008.1.2.4.80",
                                                   "bench.jpegxl.lossless"],
                includeOpenJPEG: Bool = true,
                includeKakadu: Bool = true,
                includeGrok: Bool = true,
                includeDjpeg: Bool = true,
                includeDjxl: Bool = true,
                encodeMode: J2KSwiftEncodeMode = .cpu,
                decodeMode: J2KSwiftDecodeMode = .cpu,
                warmups: Int = 2,
                timedRuns: Int = 7,
                lossyPSNRThresholdDb: Double = 40.0) {
        self.format = format
        self.selectedSyntaxUIDs = selectedSyntaxUIDs
        self.includeOpenJPEG = includeOpenJPEG
        self.includeKakadu = includeKakadu
        self.includeGrok = includeGrok
        self.includeDjpeg = includeDjpeg
        self.includeDjxl = includeDjxl
        self.encodeMode = encodeMode
        self.decodeMode = decodeMode
        self.warmups = warmups
        self.timedRuns = timedRuns
        self.lossyPSNRThresholdDb = lossyPSNRThresholdDb
    }

    /// Selected syntaxes for the active format, in canonical order.
    public var syntaxes: [J2KBenchSyntax] {
        J2KBenchSyntax.all(for: format).filter { selectedSyntaxUIDs.contains($0.uid) }
    }
}
