// DICOMwebServerProfileStorageService.swift
// DICOMStudio
//
// DICOM Studio — Persistence service for DICOMweb server profiles

import Foundation

/// Service for persisting DICOMweb server profiles to disk.
///
/// Uses JSON-based storage alongside the PACS server profiles index.
public final class DICOMwebServerProfileStorageService: Sendable {

    /// The storage service providing directory paths.
    public let storageService: StorageService

    /// The filename for the DICOMweb server profiles index.
    public static let filename = "dicomweb-server-profiles.json"

    /// Creates a DICOMweb server profile storage service.
    ///
    /// - Parameter storageService: The storage service.
    public init(storageService: StorageService = StorageService()) {
        self.storageService = storageService
    }

    /// URL for the DICOMweb server profiles file.
    public var fileURL: URL {
        storageService.baseDirectory.appendingPathComponent(Self.filename)
    }

    /// Saves the DICOMweb server profiles to disk.
    ///
    /// - Parameter profiles: The profiles to persist.
    /// - Throws: If the file cannot be written.
    public func save(_ profiles: [DICOMwebServerProfile]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profiles)
        try storageService.createDirectories()
        try data.write(to: fileURL, options: .atomic)
    }

    /// Loads the DICOMweb server profiles from disk.
    ///
    /// - Returns: The loaded profiles, or an empty array if no file exists.
    public func load() -> [DICOMwebServerProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([DICOMwebServerProfile].self, from: data)
        } catch {
            return []
        }
    }
}
