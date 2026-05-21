// J2KTestBenchStore.swift
// DICOMStudio
//
// DICOM Studio — J2K Test Bench persistence.
//
// Persists the test corpus and the run history (with the user-designated
// regression baseline) as JSON alongside the rest of DICOM Studio's
// application-support storage.

import Foundation

/// Persisted run history plus the user-designated regression baseline.
public struct J2KRunHistory: Codable, Sendable {
    public var runs: [J2KTestRun]
    public var baselineRunID: UUID?

    public init(runs: [J2KTestRun] = [], baselineRunID: UUID? = nil) {
        self.runs = runs
        self.baselineRunID = baselineRunID
    }

    /// The run marked as the regression baseline, if it still exists.
    public var baseline: J2KTestRun? {
        guard let id = baselineRunID else { return nil }
        return runs.first { $0.id == id }
    }

    /// Runs newest-first for display.
    public var runsNewestFirst: [J2KTestRun] {
        runs.sorted { $0.timestamp > $1.timestamp }
    }
}

/// Persists the J2K Test Bench corpus and run history as JSON.
public final class J2KTestBenchStore: Sendable {

    public let storageService: StorageService

    /// Most-recent runs kept on disk; older runs are dropped on save.
    public static let maxRuns = 30

    private static let corpusFilename = "j2k-bench-corpus.json"
    private static let historyFilename = "j2k-bench-history.json"

    public init(storageService: StorageService = StorageService()) {
        self.storageService = storageService
    }

    private var corpusURL: URL {
        storageService.baseDirectory.appendingPathComponent(Self.corpusFilename)
    }

    private var historyURL: URL {
        storageService.baseDirectory.appendingPathComponent(Self.historyFilename)
    }

    // MARK: - Corpus

    public func loadCorpus() -> [J2KTestFixture] {
        decode([J2KTestFixture].self, from: corpusURL) ?? []
    }

    public func saveCorpus(_ fixtures: [J2KTestFixture]) {
        encode(fixtures, to: corpusURL)
    }

    // MARK: - History

    public func loadHistory() -> J2KRunHistory {
        decode(J2KRunHistory.self, from: historyURL) ?? J2KRunHistory()
    }

    public func saveHistory(_ history: J2KRunHistory) {
        var trimmed = history
        if trimmed.runs.count > Self.maxRuns {
            // Keep the most recent runs; never silently drop the baseline.
            let recent = Array(trimmed.runs.sorted { $0.timestamp > $1.timestamp }.prefix(Self.maxRuns))
            var kept = recent
            if let baselineID = trimmed.baselineRunID,
               !kept.contains(where: { $0.id == baselineID }),
               let baseline = trimmed.runs.first(where: { $0.id == baselineID }) {
                kept.append(baseline)
            }
            trimmed.runs = kept
        }
        encode(trimmed, to: historyURL)
    }

    // MARK: - JSON

    private func encode<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            try storageService.createDirectories()
            try encoder.encode(value).write(to: url, options: .atomic)
        } catch {
            // Persistence is best-effort — a failed write must not break the bench.
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: Data(contentsOf: url))
        } catch {
            return nil
        }
    }
}
