// ImageCacheHelpers.swift
// DICOMStudio
//
// DICOM Studio — Platform-independent image cache formatting helpers

import Foundation

/// Platform-independent helpers for image cache statistics formatting.
///
/// Provides display formatting for cache hit rate, memory usage, and
/// performance metrics.
public enum ImageCacheHelpers: Sendable {

    /// Formats a hit rate (0.0-1.0) as a percentage string.
    ///
    /// - Parameter hitRate: Cache hit rate (0.0 to 1.0).
    /// - Returns: Formatted percentage, e.g., "95.2%".
    public static func hitRateText(_ hitRate: Double) -> String {
        String(format: "%.1f%%", hitRate * 100)
    }

    /// Formats memory usage in bytes as a human-readable string.
    ///
    /// - Parameter bytes: Memory usage in bytes.
    /// - Returns: Formatted string, e.g., "125.4 MB".
    public static func memoryUsageText(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }

    /// Formats cache statistics as a summary string.
    ///
    /// - Parameters:
    ///   - imageCount: Number of cached images.
    ///   - memoryBytes: Memory usage in bytes.
    ///   - hitRate: Cache hit rate (0.0 to 1.0).
    /// - Returns: Formatted summary, e.g., "42 images · 125.4 MB · 95.2% hit rate".
    public static func statisticsSummary(
        imageCount: Int,
        memoryBytes: Int,
        hitRate: Double
    ) -> String {
        let memory = memoryUsageText(memoryBytes)
        let rate = hitRateText(hitRate)
        return "\(imageCount) images · \(memory) · \(rate) hit rate"
    }

    /// Formats render time in milliseconds.
    ///
    /// - Parameter seconds: Render time in seconds.
    /// - Returns: Formatted string, e.g., "12.5 ms".
    public static func renderTimeText(_ seconds: Double) -> String {
        String(format: "%.1f ms", seconds * 1000)
    }

    /// Returns a color intensity label based on cache hit rate.
    ///
    /// - Parameter hitRate: Cache hit rate (0.0 to 1.0).
    /// - Returns: "good" (>0.8), "fair" (>0.5), or "poor".
    public static func hitRateQuality(_ hitRate: Double) -> String {
        if hitRate > 0.8 { return "good" }
        if hitRate > 0.5 { return "fair" }
        return "poor"
    }
}
