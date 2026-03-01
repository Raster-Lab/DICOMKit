// ImageCacheService.swift
// DICOMStudio
//
// DICOM Studio — Image cache management service

import Foundation
import DICOMKit

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Wraps the DICOMKit `ImageCache` actor for use by ViewModels.
///
/// Provides convenient methods for caching and retrieving rendered DICOM images,
/// with statistics reporting for the performance overlay.
public final class ImageCacheService: Sendable {

    #if canImport(CoreGraphics)
    /// The underlying image cache.
    private let cache: ImageCache

    /// Creates an image cache service with the given configuration.
    ///
    /// - Parameter maxMemoryMB: Maximum memory usage in megabytes (default: 500).
    public init(maxMemoryMB: Int = 500) {
        let config = ImageCache.Configuration(
            maxImages: 200,
            maxMemoryBytes: maxMemoryMB * 1024 * 1024
        )
        self.cache = ImageCache(configuration: config)
    }

    /// Retrieves a cached image.
    ///
    /// - Parameters:
    ///   - sopInstanceUID: SOP Instance UID.
    ///   - frameNumber: Frame number (0-based).
    ///   - windowCenter: Window center used for rendering.
    ///   - windowWidth: Window width used for rendering.
    /// - Returns: Cached CGImage, or nil if not found.
    public func get(
        sopInstanceUID: String,
        frameNumber: Int,
        windowCenter: Double?,
        windowWidth: Double?
    ) async -> CGImage? {
        let key = ImageCacheKey(
            sopInstanceUID: sopInstanceUID,
            frameNumber: frameNumber,
            windowCenter: windowCenter,
            windowWidth: windowWidth
        )
        return await cache.get(key)
    }

    /// Stores a rendered image in the cache.
    ///
    /// - Parameters:
    ///   - image: The rendered CGImage.
    ///   - sopInstanceUID: SOP Instance UID.
    ///   - frameNumber: Frame number (0-based).
    ///   - windowCenter: Window center used for rendering.
    ///   - windowWidth: Window width used for rendering.
    public func store(
        _ image: CGImage,
        sopInstanceUID: String,
        frameNumber: Int,
        windowCenter: Double?,
        windowWidth: Double?
    ) async {
        let key = ImageCacheKey(
            sopInstanceUID: sopInstanceUID,
            frameNumber: frameNumber,
            windowCenter: windowCenter,
            windowWidth: windowWidth
        )
        await cache.set(image, forKey: key)
    }

    /// Clears all cached images.
    public func clearCache() async {
        await cache.clear()
    }

    /// Returns current cache statistics.
    ///
    /// - Returns: Tuple of (imageCount, memoryBytes, hitRate).
    public func statistics() async -> (imageCount: Int, memoryBytes: Int, hitRate: Double) {
        let stats = await cache.statistics()
        return (stats.imageCount, stats.memoryUsageBytes, stats.hitRate)
    }
    #else
    public init(maxMemoryMB: Int = 500) {}
    #endif
}
