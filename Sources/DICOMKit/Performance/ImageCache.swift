import Foundation

#if canImport(CoreGraphics)
import CoreGraphics

/// Cache for rendered DICOM images to improve performance
///
/// Provides LRU-based caching for CGImage objects generated from DICOM pixel data.
/// This significantly improves performance when repeatedly accessing the same images.
///
/// ## Usage
///
/// ```swift
/// let cache = ImageCache(configuration: .default)
///
/// // Check cache before rendering
/// let key = ImageCacheKey(
///     sopInstanceUID: "1.2.3.4.5",
///     frameNumber: 0,
///     windowCenter: 40,
///     windowWidth: 400
/// )
///
/// if let cachedImage = await cache.get(key) {
///     // Use cached image
/// } else {
///     // Render image and cache it
///     let image = renderImage() // Your rendering logic
///     await cache.set(image, forKey: key)
/// }
/// ```
public actor ImageCache {
    
    // MARK: - Types
    
    /// Configuration for image cache
    public struct Configuration: Sendable {
        /// Maximum number of images to cache
        public let maxImages: Int
        
        /// Maximum total memory usage in bytes (approximate)
        public let maxMemoryBytes: Int
        
        /// Whether cache is enabled
        public let enabled: Bool
        
        /// Creates an image cache configuration
        /// - Parameters:
        ///   - maxImages: Maximum number of cached images (default: 100)
        ///   - maxMemoryBytes: Maximum memory in bytes (default: 500MB)
        ///   - enabled: Whether caching is enabled (default: true)
        public init(
            maxImages: Int = 100,
            maxMemoryBytes: Int = 500 * 1024 * 1024, // 500 MB
            enabled: Bool = true
        ) {
            self.maxImages = max(1, maxImages)
            self.maxMemoryBytes = max(1024 * 1024, maxMemoryBytes) // Minimum 1MB
            self.enabled = enabled
        }
        
        /// Default configuration (100 images, 500MB)
        public static let `default` = Configuration()
        
        /// High memory configuration (500 images, 2GB)
        public static let highMemory = Configuration(
            maxImages: 500,
            maxMemoryBytes: 2 * 1024 * 1024 * 1024
        )
        
        /// Low memory configuration (20 images, 100MB)
        public static let lowMemory = Configuration(
            maxImages: 20,
            maxMemoryBytes: 100 * 1024 * 1024
        )
        
        /// Disabled configuration
        public static let disabled = Configuration(enabled: false)
    }
    
    /// Statistics about cache performance
    public struct Statistics: Sendable {
        /// Number of cache hits
        public let hits: Int
        
        /// Number of cache misses
        public let misses: Int
        
        /// Number of images currently cached
        public let imageCount: Int
        
        /// Approximate total memory usage in bytes
        public let memoryUsageBytes: Int
        
        /// Hit rate (0.0 to 1.0)
        public var hitRate: Double {
            let total = hits + misses
            return total > 0 ? Double(hits) / Double(total) : 0.0
        }
        
        /// Memory usage in megabytes
        public var memoryUsageMB: Double {
            return Double(memoryUsageBytes) / (1024.0 * 1024.0)
        }
    }
    
    private struct CacheEntry {
        let image: CGImage
        let estimatedSize: Int
        var lastAccessed: Date
    }
    
    // MARK: - Properties
    
    private let configuration: Configuration
    private var entries: [ImageCacheKey: CacheEntry] = [:]
    private var accessOrder: [ImageCacheKey] = []
    private var currentMemoryUsage: Int = 0
    private var hits: Int = 0
    private var misses: Int = 0
    
    // MARK: - Initialization
    
    /// Creates an image cache with the given configuration
    /// - Parameter configuration: Cache configuration
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Cache Operations
    
    /// Retrieves a cached image if available
    /// - Parameter key: The cache key
    /// - Returns: The cached image, or nil if not found
    public func get(_ key: ImageCacheKey) -> CGImage? {
        guard configuration.enabled else {
            misses += 1
            return nil
        }
        
        guard var entry = entries[key] else {
            misses += 1
            return nil
        }
        
        // Update access time and order
        entry.lastAccessed = Date()
        entries[key] = entry
        updateAccessOrder(key)
        
        hits += 1
        return entry.image
    }
    
    /// Stores an image in the cache
    /// - Parameters:
    ///   - image: The image to cache
    ///   - key: The cache key
    public func set(_ image: CGImage, forKey key: ImageCacheKey) {
        guard configuration.enabled else { return }
        
        // Remove existing entry if present
        if entries[key] != nil {
            remove(key)
        }
        
        // Estimate image size
        let estimatedSize = estimateImageSize(image)
        
        // Check if image fits in cache
        if estimatedSize > configuration.maxMemoryBytes {
            // Image too large for cache
            return
        }
        
        // Evict entries if necessary
        while currentMemoryUsage + estimatedSize > configuration.maxMemoryBytes && !entries.isEmpty {
            evictLeastRecentlyUsed()
        }
        
        while entries.count >= configuration.maxImages && !entries.isEmpty {
            evictLeastRecentlyUsed()
        }
        
        // Store entry
        let entry = CacheEntry(
            image: image,
            estimatedSize: estimatedSize,
            lastAccessed: Date()
        )
        entries[key] = entry
        accessOrder.append(key)
        currentMemoryUsage += estimatedSize
    }
    
    /// Removes a specific image from the cache
    /// - Parameter key: The cache key
    public func remove(_ key: ImageCacheKey) {
        guard let entry = entries.removeValue(forKey: key) else { return }
        currentMemoryUsage -= entry.estimatedSize
        accessOrder.removeAll { $0 == key }
    }
    
    /// Removes all images from the cache
    public func clear() {
        entries.removeAll()
        accessOrder.removeAll()
        currentMemoryUsage = 0
        // Preserve hit/miss stats
    }
    
    /// Gets cache statistics
    /// - Returns: Current cache statistics
    public func statistics() -> Statistics {
        return Statistics(
            hits: hits,
            misses: misses,
            imageCount: entries.count,
            memoryUsageBytes: currentMemoryUsage
        )
    }
    
    /// Resets cache statistics
    public func resetStatistics() {
        hits = 0
        misses = 0
    }
    
    // MARK: - Private Methods
    
    private func updateAccessOrder(_ key: ImageCacheKey) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }
    
    private func evictLeastRecentlyUsed() {
        guard !accessOrder.isEmpty else { return }
        let key = accessOrder.removeFirst()
        if let entry = entries.removeValue(forKey: key) {
            currentMemoryUsage -= entry.estimatedSize
        }
    }
    
    /// Estimates the memory size of a CGImage
    /// - Parameter image: The image to estimate
    /// - Returns: Estimated size in bytes
    private func estimateImageSize(_ image: CGImage) -> Int {
        let width = image.width
        let height = image.height
        let bitsPerPixel = image.bitsPerPixel
        
        // Estimate: width × height × bytes per pixel
        let bytesPerPixel = (bitsPerPixel + 7) / 8
        return width * height * bytesPerPixel
    }
}

/// Key for image cache lookups
///
/// Uniquely identifies a rendered image based on its source and rendering parameters.
public struct ImageCacheKey: Hashable, Sendable {
    /// SOP Instance UID of the source image
    public let sopInstanceUID: String
    
    /// Frame number for multi-frame images (0-based)
    public let frameNumber: Int
    
    /// Window center value used for rendering
    public let windowCenter: Double?
    
    /// Window width value used for rendering
    public let windowWidth: Double?
    
    /// Photometric interpretation
    public let photometricInterpretation: String?
    
    /// Presentation state UID if applied
    public let presentationStateUID: String?
    
    /// Creates a cache key for an image
    /// - Parameters:
    ///   - sopInstanceUID: SOP Instance UID
    ///   - frameNumber: Frame number (default: 0)
    ///   - windowCenter: Window center value (default: nil)
    ///   - windowWidth: Window width value (default: nil)
    ///   - photometricInterpretation: Photometric interpretation (default: nil)
    ///   - presentationStateUID: Presentation state UID (default: nil)
    public init(
        sopInstanceUID: String,
        frameNumber: Int = 0,
        windowCenter: Double? = nil,
        windowWidth: Double? = nil,
        photometricInterpretation: String? = nil,
        presentationStateUID: String? = nil
    ) {
        self.sopInstanceUID = sopInstanceUID
        self.frameNumber = frameNumber
        self.windowCenter = windowCenter
        self.windowWidth = windowWidth
        self.photometricInterpretation = photometricInterpretation
        self.presentationStateUID = presentationStateUID
    }
}

#endif
