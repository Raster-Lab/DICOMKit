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

    /// Returns the thumbnail URL for a given SOP Instance UID and frame number.
    ///
    /// - Parameters:
    ///   - sopInstanceUID: The SOP Instance UID.
    ///   - frameNumber: The frame number (0-based, default 0).
    /// - Returns: The file URL for the cached thumbnail.
    public func thumbnailURL(for sopInstanceUID: String, frameNumber: Int) -> URL {
        let key = ThumbnailHelpers.cacheKey(sopInstanceUID: sopInstanceUID, frameNumber: frameNumber)
        return storageService.thumbnailDirectory
            .appendingPathComponent("\(key).png")
    }

    /// Determines whether a thumbnail should be generated for an instance.
    ///
    /// - Parameter instance: The DICOM instance model.
    /// - Returns: `true` if the instance contains renderable pixel data.
    public func shouldGenerateThumbnail(for instance: InstanceModel) -> Bool {
        ThumbnailHelpers.shouldGenerateThumbnail(
            rows: instance.rows,
            columns: instance.columns,
            photometricInterpretation: instance.photometricInterpretation
        )
    }

    /// Returns the scaled thumbnail dimensions for an instance.
    ///
    /// - Parameter instance: The DICOM instance model.
    /// - Returns: A tuple of (width, height) or nil if dimensions are unavailable.
    public func thumbnailDimensions(for instance: InstanceModel) -> (width: Int, height: Int)? {
        guard let rows = instance.rows, let columns = instance.columns else { return nil }
        return ThumbnailHelpers.thumbnailDimensions(
            imageWidth: columns,
            imageHeight: rows,
            maxSize: maxThumbnailSize
        )
    }
}
