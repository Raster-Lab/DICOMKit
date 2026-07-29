// PrinterProfileStorageService.swift
// DICOMStudio
//
// DICOM Studio — Persistence service for DICOM printer profiles.
//
// Mirrors ServerProfileStorageService one-for-one: same directory, same JSON
// conventions, same failure behavior. Printers are managed like PACS servers.

import Foundation

/// Service for persisting DICOM printer profiles to disk.
///
/// Uses JSON-based storage alongside the library index.
public final class PrinterProfileStorageService: Sendable {

    /// The storage service providing directory paths.
    public let storageService: StorageService

    /// The filename for the printer profiles index.
    public static let filename = "printer-profiles.json"

    /// Creates a printer profile storage service.
    ///
    /// - Parameter storageService: The storage service.
    public init(storageService: StorageService = StorageService()) {
        self.storageService = storageService
    }

    /// URL for the printer profiles file.
    public var fileURL: URL {
        storageService.baseDirectory.appendingPathComponent(Self.filename)
    }

    /// Saves the printer profiles to disk.
    ///
    /// - Parameter profiles: The profiles to persist.
    /// - Throws: If the file cannot be written.
    public func save(_ profiles: [PrinterProfile]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profiles)
        try storageService.createDirectories()
        try data.write(to: fileURL, options: .atomic)
    }

    /// Loads the printer profiles from disk.
    ///
    /// - Returns: The loaded profiles, or an empty array if no file exists.
    public func load() -> [PrinterProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([PrinterProfile].self, from: data)
        } catch {
            return []
        }
    }
}
