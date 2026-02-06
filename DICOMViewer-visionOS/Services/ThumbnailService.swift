// ThumbnailService.swift
// DICOMViewer visionOS - Thumbnail Generation Service
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftUI

/// Service for generating study/series thumbnails
actor ThumbnailService {
    private var cache: [UUID: Image] = [:]
    
    func thumbnail(for series: DICOMSeries, size: CGSize = CGSize(width: 200, height: 200)) async -> Image? {
        // Check cache
        if let cached = cache[series.id] {
            return cached
        }
        
        // Generate thumbnail
        // Placeholder: Would render first instance as thumbnail
        let thumbnail = Image(systemName: "photo")
        cache[series.id] = thumbnail
        
        return thumbnail
    }
    
    func clearCache() {
        cache.removeAll()
    }
}
