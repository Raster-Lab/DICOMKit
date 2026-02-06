// GestureViewModel.swift
// DICOMViewer visionOS - Gesture Recognition ViewModel
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import Observation
import simd

/// ViewModel for hand gesture recognition
@Observable
@MainActor
final class GestureViewModel {
    var recognizedGesture: GestureType?
    var gestureProgress: Double = 0.0
    var isProcessing = false
    
    enum GestureType {
        case pinch
        case drag
        case rotate
        case scale
        case swipe(direction: Direction)
        case windowLevel(delta: Float)
        
        enum Direction {
            case left, right, up, down
        }
    }
    
    func processHandTracking(leftHand: HandData?, rightHand: HandData?) {
        // Placeholder for hand tracking processing
        isProcessing = true
        
        // Detect gestures based on hand positions
        // This would integrate with ARKit hand tracking
        
        isProcessing = false
    }
    
    struct HandData {
        var position: simd_float3
        var orientation: simd_quatf
        var isPinching: Bool
        var joints: [simd_float3]  // 26 hand joints
    }
}
