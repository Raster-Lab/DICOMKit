// ThumbnailService.swift
// DICOMStudio
//
// DICOM Studio — Thumbnail generation and caching

import Foundation

/// Provides thumbnail generation and caching for DICOM images.
///
/// Thumbnails are stored on disk in the storage service's thumbnail
/// directory, keyed by SOP Instance UID.
public final class ThumbnailService: Sendable {
    private let storageService: StorageService
    private let maxThumbnailSize: Int

    /// Creates a thumbnail service backed by the given storage service.
    ///
    /// - Parameters:
    ///   - storageService: Storage service for thumbnail file management.
    ///   - maxThumbnailSize: Maximum width/height in pixels (default: 128).
    public init(storageService: StorageService, maxThumbnailSize: Int = 128) {
        self.storageService = storageService
        self.maxThumbnailSize = maxThumbnailSize
    }

    /// Returns the file URL where a thumbnail for the given SOP Instance UID would be stored.
    public func thumbnailURL(for sopInstanceUID: String) -> URL {
        let sanitized = sopInstanceUID.replacingOccurrences(of: ".", with: "_")
        return storageService.thumbnailDirectory
            .appendingPathComponent("\(sanitized).png")
    }

    /// Checks whether a cached thumbnail exists for the given SOP Instance UID.
    public func hasCachedThumbnail(for sopInstanceUID: String) -> Bool {
        let url = thumbnailURL(for: sopInstanceUID)
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Removes all cached thumbnails.
    public func clearCache() throws {
        try storageService.clearThumbnailCache()
    }

    /// Maximum thumbnail dimension.
    public var maxSize: Int { maxThumbnailSize }
}
