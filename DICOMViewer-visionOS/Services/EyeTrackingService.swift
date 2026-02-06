// EyeTrackingService.swift
// DICOMViewer visionOS - Eye Tracking Service
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import ARKit
import simd

/// Service for eye tracking and gaze-based interaction
@MainActor
final class EyeTrackingService {
    var gazeDirection: simd_float3?
    var gazeTarget: simd_float3?
    
    /// Process eye tracking data from ARKit
    func processEyeTracking(eyeAnchor: EyeAnchor?) {
        guard let eyeAnchor = eyeAnchor else { return }
        
        // Update gaze direction and target
        // Placeholder for actual eye tracking processing
    }
    
    /// Check if user is gazing at position
    func isGazing(at position: simd_float3, threshold: Float = 0.1) -> Bool {
        guard let target = gazeTarget else { return false }
        return simd_distance(target, position) < threshold
    }
}

// Placeholder for EyeAnchor (would come from ARKit)
struct EyeAnchor {
    var gazeDirection: simd_float3
}
