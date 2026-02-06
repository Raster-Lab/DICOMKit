//
//  HangingProtocol.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation

/// Hanging protocol defines how series should be arranged in viewports
struct HangingProtocol: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let description: String
    let modality: String?
    let bodyPart: String?
    let layout: ViewportLayout
    let rules: [SeriesAssignmentRule]
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        modality: String? = nil,
        bodyPart: String? = nil,
        layout: ViewportLayout,
        rules: [SeriesAssignmentRule] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.modality = modality
        self.bodyPart = bodyPart
        self.layout = layout
        self.rules = rules
    }
    
    // MARK: - Standard Protocols
    
    static let ctChest = HangingProtocol(
        name: "CT Chest",
        description: "Standard CT chest protocol",
        modality: "CT",
        bodyPart: "CHEST",
        layout: .twoByTwo,
        rules: [
            SeriesAssignmentRule(viewportIndex: 0, seriesDescription: "Axial", priority: 1),
            SeriesAssignmentRule(viewportIndex: 1, seriesDescription: "Coronal", priority: 2),
            SeriesAssignmentRule(viewportIndex: 2, seriesDescription: "Sagittal", priority: 3)
        ]
    )
    
    static let ctAbdomen = HangingProtocol(
        name: "CT Abdomen",
        description: "Standard CT abdomen/pelvis protocol",
        modality: "CT",
        bodyPart: "ABDOMEN",
        layout: .twoByTwo,
        rules: [
            SeriesAssignmentRule(viewportIndex: 0, seriesDescription: "Arterial", priority: 1),
            SeriesAssignmentRule(viewportIndex: 1, seriesDescription: "Venous", priority: 2),
            SeriesAssignmentRule(viewportIndex: 2, seriesDescription: "Delayed", priority: 3)
        ]
    )
    
    static let mrBrain = HangingProtocol(
        name: "MR Brain",
        description: "Standard MR brain protocol",
        modality: "MR",
        bodyPart: "BRAIN",
        layout: .threeByThree,
        rules: [
            SeriesAssignmentRule(viewportIndex: 0, seriesDescription: "T1", priority: 1),
            SeriesAssignmentRule(viewportIndex: 1, seriesDescription: "T2", priority: 2),
            SeriesAssignmentRule(viewportIndex: 2, seriesDescription: "FLAIR", priority: 3),
            SeriesAssignmentRule(viewportIndex: 3, seriesDescription: "DWI", priority: 4),
            SeriesAssignmentRule(viewportIndex: 4, seriesDescription: "ADC", priority: 5)
        ]
    )
    
    static let xray = HangingProtocol(
        name: "X-Ray",
        description: "Standard X-ray protocol",
        modality: "CR",
        bodyPart: nil,
        layout: .single,
        rules: []
    )
    
    static let standard: [HangingProtocol] = [
        .ctChest, .ctAbdomen, .mrBrain, .xray
    ]
}

/// Rule for assigning a series to a specific viewport
struct SeriesAssignmentRule: Codable, Equatable {
    let viewportIndex: Int
    let seriesDescription: String?
    let seriesNumber: Int?
    let priority: Int
    
    init(
        viewportIndex: Int,
        seriesDescription: String? = nil,
        seriesNumber: Int? = nil,
        priority: Int = 0
    ) {
        self.viewportIndex = viewportIndex
        self.seriesDescription = seriesDescription
        self.seriesNumber = seriesNumber
        self.priority = priority
    }
    
    /// Check if a series matches this rule
    func matches(_ series: DicomSeries) -> Bool {
        if let desc = seriesDescription {
            guard series.seriesDescription?.localizedCaseInsensitiveContains(desc) == true else {
                return false
            }
        }
        
        if let num = seriesNumber {
            guard series.seriesNumber == num else {
                return false
            }
        }
        
        return true
    }
}
