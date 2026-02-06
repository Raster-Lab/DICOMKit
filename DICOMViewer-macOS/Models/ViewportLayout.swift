//
//  ViewportLayout.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation

/// Represents a viewport layout configuration
struct ViewportLayout: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let rows: Int
    let columns: Int
    var description: String
    
    /// Total number of viewports
    var viewportCount: Int {
        rows * columns
    }
    
    init(id: UUID = UUID(), name: String, rows: Int, columns: Int, description: String = "") {
        self.id = id
        self.name = name
        self.rows = rows
        self.columns = columns
        self.description = description
    }
    
    // MARK: - Standard Layouts
    
    static let single = ViewportLayout(
        name: "1×1",
        rows: 1,
        columns: 1,
        description: "Single viewport"
    )
    
    static let twoByTwo = ViewportLayout(
        name: "2×2",
        rows: 2,
        columns: 2,
        description: "Four viewports"
    )
    
    static let threeByThree = ViewportLayout(
        name: "3×3",
        rows: 3,
        columns: 3,
        description: "Nine viewports"
    )
    
    static let fourByFour = ViewportLayout(
        name: "4×4",
        rows: 4,
        columns: 4,
        description: "Sixteen viewports"
    )
    
    static let standard: [ViewportLayout] = [
        .single, .twoByTwo, .threeByThree, .fourByFour
    ]
}

/// Viewport linking options
struct ViewportLinking: Equatable {
    var scrollEnabled: Bool = false
    var windowLevelEnabled: Bool = false
    var zoomEnabled: Bool = false
    var panEnabled: Bool = false
    
    /// No linking enabled
    static let none = ViewportLinking()
    
    /// All linking enabled
    static let all = ViewportLinking(
        scrollEnabled: true,
        windowLevelEnabled: true,
        zoomEnabled: true,
        panEnabled: true
    )
}

/// Represents a single viewport in a grid
struct Viewport: Identifiable, Equatable {
    let id: UUID
    var series: DicomSeries?
    var currentInstanceIndex: Int
    
    init(id: UUID = UUID(), series: DicomSeries? = nil, currentInstanceIndex: Int = 0) {
        self.id = id
        self.series = series
        self.currentInstanceIndex = currentInstanceIndex
    }
}
