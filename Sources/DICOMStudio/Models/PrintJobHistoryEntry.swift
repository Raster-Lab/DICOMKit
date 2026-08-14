// PrintJobHistoryEntry.swift
// DICOMStudio
//
// DICOM Studio — a record of a submitted print job, so "did that print?" is
// answerable after the sheet is dismissed.

import Foundation

/// One submitted print job.
public struct PrintJobHistoryEntry: Sendable, Identifiable, Equatable, Codable {
    public let id: UUID
    /// When the job was submitted.
    public let date: Date
    /// Printer name at submission time.
    public let printerName: String
    /// Number of images sent.
    public let imageCount: Int
    /// Number of films produced.
    public let filmCount: Int
    /// Copies of each film.
    public let copies: Int
    /// Layout used, e.g. "2×2".
    public let layout: String
    /// Whether the SCP accepted the job.
    public let success: Bool
    /// Every Print Job SOP Instance UID returned (one per film).
    public let printJobUIDs: [String]
    /// Film Session UID, when reported.
    public let filmSessionUID: String?
    /// Error text when the job failed.
    public let errorMessage: String?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        printerName: String,
        imageCount: Int,
        filmCount: Int,
        copies: Int,
        layout: String,
        success: Bool,
        printJobUIDs: [String] = [],
        filmSessionUID: String? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.date = date
        self.printerName = printerName
        self.imageCount = imageCount
        self.filmCount = filmCount
        self.copies = copies
        self.layout = layout
        self.success = success
        self.printJobUIDs = printJobUIDs
        self.filmSessionUID = filmSessionUID
        self.errorMessage = errorMessage
    }

    /// One-line summary for the history list.
    public var summary: String {
        let films = filmCount == 1 ? "1 film" : "\(filmCount) films"
        let copiesText = copies > 1 ? " × \(copies)" : ""
        return "\(printerName) — \(imageCount) image(s), \(films)\(copiesText), \(layout)"
    }
}

/// Persists submitted print jobs, alongside the other Studio indexes.
public final class PrintJobHistoryStorageService: Sendable {

    /// The storage service providing directory paths.
    public let storageService: StorageService

    /// The filename for the print job history.
    public static let filename = "print-job-history.json"

    /// The most recent jobs retained.
    public static let retentionLimit = 100

    public init(storageService: StorageService = StorageService()) {
        self.storageService = storageService
    }

    /// URL for the history file.
    public var fileURL: URL {
        storageService.baseDirectory.appendingPathComponent(Self.filename)
    }

    /// Saves the history, newest first, truncated to the retention limit.
    public func save(_ entries: [PrintJobHistoryEntry]) throws {
        let data = try Self.exportData(Array(entries.prefix(Self.retentionLimit)))
        try storageService.createDirectories()
        try data.write(to: fileURL, options: .atomic)
    }

    /// Encodes entries in the on-disk format — also what "Export…" writes, so
    /// an exported file and the live history file are interchangeable.
    public static func exportData(_ entries: [PrintJobHistoryEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(entries)
    }

    /// Loads the history, or an empty array if there is none.
    public func load() -> [PrintJobHistoryEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([PrintJobHistoryEntry].self, from: data)
        } catch {
            return []
        }
    }
}
