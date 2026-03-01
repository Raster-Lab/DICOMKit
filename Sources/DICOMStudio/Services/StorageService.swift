// StorageService.swift
// DICOMStudio
//
// DICOM Studio — Local storage management

import Foundation

/// Manages local file storage for DICOM Studio.
///
/// Provides organized directories for imported files, thumbnails,
/// cache data, and application support files.
public final class StorageService: Sendable {
    /// The base directory for DICOM Studio storage.
    public let baseDirectory: URL

    /// Directory for imported DICOM files.
    public var importDirectory: URL {
        baseDirectory.appendingPathComponent("Imports", isDirectory: true)
    }

    /// Directory for generated thumbnails.
    public var thumbnailDirectory: URL {
        baseDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    /// Directory for cached data.
    public var cacheDirectory: URL {
        baseDirectory.appendingPathComponent("Cache", isDirectory: true)
    }

    /// Directory for exported files.
    public var exportDirectory: URL {
        baseDirectory.appendingPathComponent("Exports", isDirectory: true)
    }

    /// Creates a storage service with the given base directory.
    ///
    /// - Parameter baseDirectory: Root directory for all storage. If nil,
    ///   uses the Application Support directory.
    public init(baseDirectory: URL? = nil) {
        if let dir = baseDirectory {
            self.baseDirectory = dir
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.baseDirectory = appSupport.appendingPathComponent("DICOMStudio", isDirectory: true)
        }
    }

    /// Ensures all required directories exist.
    public func createDirectories() throws {
        let directories = [baseDirectory, importDirectory, thumbnailDirectory, cacheDirectory, exportDirectory]
        let fm = FileManager.default
        for dir in directories {
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    /// Returns the total size of the cache directory in bytes.
    public func cacheSize() -> Int64 {
        directorySize(at: cacheDirectory)
    }

    /// Returns the total size of the thumbnail directory in bytes.
    public func thumbnailCacheSize() -> Int64 {
        directorySize(at: thumbnailDirectory)
    }

    /// Clears the cache directory.
    public func clearCache() throws {
        try clearDirectory(at: cacheDirectory)
    }

    /// Clears the thumbnail cache directory.
    public func clearThumbnailCache() throws {
        try clearDirectory(at: thumbnailDirectory)
    }

    // MARK: - Private Helpers

    private func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = resourceValues.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    private func clearDirectory(at url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        for item in contents {
            try fm.removeItem(at: item)
        }
    }
}
