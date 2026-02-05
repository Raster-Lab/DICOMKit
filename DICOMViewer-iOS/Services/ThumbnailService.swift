// ThumbnailService.swift
// DICOMViewer iOS - Thumbnail Generation Service
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import DICOMKit
import DICOMCore
#if canImport(UIKit)
import UIKit
#endif

/// Service for generating and caching DICOM thumbnails
actor ThumbnailService {
    /// Shared instance
    static let shared = ThumbnailService()
    
    /// Thumbnail cache
    private var cache: [String: Data] = [:]
    
    /// Maximum cache size (in bytes)
    private let maxCacheSize: Int = 50 * 1024 * 1024 // 50 MB
    
    /// Current cache size
    private var currentCacheSize: Int = 0
    
    /// Thumbnail size
    let thumbnailSize: CGSize = CGSize(width: 128, height: 128)
    
    /// File manager
    private let fileManager = FileManager.default
    
    /// Thumbnails directory
    var thumbnailsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Thumbnails", isDirectory: true)
    }
    
    // MARK: - Initialization
    
    private init() {
        try? fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Thumbnail Generation
    
    /// Generates a thumbnail for a DICOM file
    /// - Parameters:
    ///   - url: URL of the DICOM file
    ///   - frameIndex: Frame index to use (default 0)
    /// - Returns: Thumbnail image data (JPEG)
    func generateThumbnail(for url: URL, frameIndex: Int = 0) async throws -> Data? {
        #if canImport(UIKit)
        // Check cache first
        let cacheKey = "\(url.path)_\(frameIndex)"
        if let cachedData = cache[cacheKey] {
            return cachedData
        }
        
        // Check disk cache
        let diskCachePath = thumbnailPath(for: cacheKey)
        if fileManager.fileExists(atPath: diskCachePath.path) {
            let data = try Data(contentsOf: diskCachePath)
            await addToCache(key: cacheKey, data: data)
            return data
        }
        
        // Generate thumbnail
        let data = try Data(contentsOf: url)
        let dicomFile = try DICOMFile.read(from: data, force: true)
        
        guard let cgImage = try renderThumbnail(from: dicomFile, frameIndex: frameIndex) else {
            return nil
        }
        
        // Convert to JPEG data
        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.7) else {
            return nil
        }
        
        // Save to disk cache
        try jpegData.write(to: diskCachePath)
        
        // Add to memory cache
        await addToCache(key: cacheKey, data: jpegData)
        
        return jpegData
        #else
        return nil
        #endif
    }
    
    /// Generates thumbnail from a DICOM file in memory
    private func renderThumbnail(from dicomFile: DICOMFile, frameIndex: Int) throws -> CGImage? {
        // Get pixel data
        guard let pixelData = dicomFile.dataSet.pixelData() else {
            return nil
        }
        
        // Create renderer
        let paletteColorLUT = dicomFile.dataSet.paletteColorLUT()
        let renderer = PixelDataRenderer(pixelData: pixelData, paletteColorLUT: paletteColorLUT)
        
        // Render frame
        guard let cgImage = renderer.renderFrame(frameIndex) else {
            return nil
        }
        
        #if canImport(UIKit)
        // Scale down to thumbnail size
        let scaledImage = scaleThumbnail(cgImage)
        return scaledImage
        #else
        return cgImage
        #endif
    }
    
    #if canImport(UIKit)
    /// Scales an image to thumbnail size
    private func scaleThumbnail(_ image: CGImage) -> CGImage? {
        let aspectWidth = thumbnailSize.width / CGFloat(image.width)
        let aspectHeight = thumbnailSize.height / CGFloat(image.height)
        let aspectRatio = min(aspectWidth, aspectHeight)
        
        let newWidth = CGFloat(image.width) * aspectRatio
        let newHeight = CGFloat(image.height) * aspectRatio
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: newWidth, height: newHeight), format: format)
        let uiImage = renderer.image { context in
            UIImage(cgImage: image).draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        }
        
        return uiImage.cgImage
    }
    #endif
    
    /// Gets the path for a cached thumbnail
    private func thumbnailPath(for key: String) -> URL {
        let sanitizedKey = key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let hash = sanitizedKey.hashValue
        return thumbnailsDirectory.appendingPathComponent("\(hash).jpg")
    }
    
    /// Adds data to the memory cache
    private func addToCache(key: String, data: Data) {
        // Evict old entries if needed
        while currentCacheSize + data.count > maxCacheSize && !cache.isEmpty {
            if let firstKey = cache.keys.first {
                if let removedData = cache.removeValue(forKey: firstKey) {
                    currentCacheSize -= removedData.count
                }
            }
        }
        
        cache[key] = data
        currentCacheSize += data.count
    }
    
    /// Clears the thumbnail cache
    func clearCache() {
        cache.removeAll()
        currentCacheSize = 0
    }
    
    /// Clears the disk cache
    func clearDiskCache() throws {
        let contents = try fileManager.contentsOfDirectory(at: thumbnailsDirectory, includingPropertiesForKeys: nil)
        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }
}
