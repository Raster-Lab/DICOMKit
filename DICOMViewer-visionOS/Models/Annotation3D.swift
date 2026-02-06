// Annotation3D.swift
// DICOMViewer visionOS - 3D Spatial Annotations
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import simd

/// Type of 3D annotation
enum AnnotationType: String, Codable, Sendable {
    case text      // Text note
    case voice     // Voice recording
    case arrow     // Arrow pointer
}

/// 3D annotation in volume space
@Observable
final class Annotation3D: Identifiable, Sendable {
    let id: UUID
    let type: AnnotationType
    let position: simd_float3  // Position in 3D space (mm)
    var text: String?          // Text content
    var voiceURL: URL?         // Voice recording URL
    let color: String          // Color hex code
    let author: String         // Who created it
    let createdAt: Date
    var isVisible: Bool
    
    init(
        id: UUID = UUID(),
        type: AnnotationType,
        position: simd_float3,
        text: String? = nil,
        voiceURL: URL? = nil,
        color: String = "#FF0000",
        author: String = "User",
        createdAt: Date = Date(),
        isVisible: Bool = true
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.text = text
        self.voiceURL = voiceURL
        self.color = color
        self.author = author
        self.createdAt = createdAt
        self.isVisible = isVisible
    }
}
