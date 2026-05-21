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

/// A codec participating in a test-bench run.
public enum J2KBenchCodec: String, CaseIterable, Identifiable, Codable, Sendable {
    case j2kSwift = "J2KSwift"
    case openJPEG = "OpenJPEG"
    case kakadu   = "Kakadu"
    case grok     = "Grok"

    public var id: String { rawValue }

    /// Only J2KSwift produces the reference codestream; the others are
    /// decode-only in the bench (no Swift encode API is wired for them).
    public var encodes: Bool { self == .j2kSwift }

    /// SF Symbol shown beside the codec in the results grid.
    public var systemImage: String {
        switch self {
        case .j2kSwift: return "swift"
        case .openJPEG: return "shippingbox"
        case .kakadu, .grok: return "terminal"
        }
    }
}

// MARK: - Transfer syntax

/// A JPEG 2000 / HTJ2K transfer syntax the bench can exercise.
public struct J2KBenchSyntax: Identifiable, Hashable, Codable, Sendable {
    public let uid: String
    public let shortName: String

    public var id: String { uid }

    public init(uid: String, shortName: String) {
        self.uid = uid
        self.shortName = shortName
    }

    /// Lossless syntaxes must reconstruct bit-exact; lossy ones are scored
    /// against a PSNR threshold.
    public var isLossless: Bool {
        !uid.hasSuffix(".91") && !uid.hasSuffix(".93") && !uid.hasSuffix(".203")
    }

    /// The seven JPEG 2000 family transfer syntaxes DICOMKit can encode.
    public static let all: [J2KBenchSyntax] = [
        J2KBenchSyntax(uid: "1.2.840.10008.1.2.4.90",  shortName: "J2K Lossless"),
        J2KBenchSyntax(uid: "1.2.840.10008.1.2.4.91",  shortName: "J2K Lossy"),
        J2KBenchSyntax(uid: "1.2.840.10008.1.2.4.92",  shortName: "J2K Part 2 Lossless"),
        J2KBenchSyntax(uid: "1.2.840.10008.1.2.4.93",  shortName: "J2K Part 2 Lossy"),
        J2KBenchSyntax(uid: "1.2.840.10008.1.2.4.201", shortName: "HTJ2K Lossless"),
        J2KBenchSyntax(uid: "1.2.840.10008.1.2.4.202", shortName: "HTJ2K RPCL Lossless"),
        J2KBenchSyntax(uid: "1.2.840.10008.1.2.4.203", shortName: "HTJ2K Lossy"),
    ]

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
    /// Transfer syntaxes to exercise (by UID).
    public var selectedSyntaxUIDs: Set<String>
    public var includeOpenJPEG: Bool
    public var includeKakadu: Bool
    public var includeGrok: Bool
    /// Which J2KSwift encode API produces the reference codestream.
    public var encodeMode: J2KSwiftEncodeMode
    /// Which J2KSwift decode API the J2KSwift row exercises.
    public var decodeMode: J2KSwiftDecodeMode
    /// Untimed warmups before timing (cross-host bench default: 2).
    public var warmups: Int
    /// Timed runs; the median is reported (cross-host bench default: 7).
    public var timedRuns: Int
    /// Minimum PSNR (dB) for a lossy cell to pass.
    public var lossyPSNRThresholdDb: Double

    public init(selectedSyntaxUIDs: Set<String> = ["1.2.840.10008.1.2.4.90",
                                                   "1.2.840.10008.1.2.4.201"],
                includeOpenJPEG: Bool = true,
                includeKakadu: Bool = true,
                includeGrok: Bool = true,
                encodeMode: J2KSwiftEncodeMode = .cpu,
                decodeMode: J2KSwiftDecodeMode = .cpu,
                warmups: Int = 2,
                timedRuns: Int = 7,
                lossyPSNRThresholdDb: Double = 40.0) {
        self.selectedSyntaxUIDs = selectedSyntaxUIDs
        self.includeOpenJPEG = includeOpenJPEG
        self.includeKakadu = includeKakadu
        self.includeGrok = includeGrok
        self.encodeMode = encodeMode
        self.decodeMode = decodeMode
        self.warmups = warmups
        self.timedRuns = timedRuns
        self.lossyPSNRThresholdDb = lossyPSNRThresholdDb
    }

    /// Selected syntaxes in canonical order.
    public var syntaxes: [J2KBenchSyntax] {
        J2KBenchSyntax.all.filter { selectedSyntaxUIDs.contains($0.uid) }
    }
}
