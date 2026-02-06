// MeasurementViewModel.swift
// DICOMViewer visionOS - Measurement Tools ViewModel
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import Observation
import simd

/// ViewModel for 3D measurement tools
@Observable
@MainActor
final class MeasurementViewModel {
    // MARK: - State
    
    var measurements: [SpatialMeasurement] = []
    var annotations: [Annotation3D] = []
    var activeTool: Tool? = nil
    var pendingPoints: [simd_float3] = []
    
    enum Tool {
        case length
        case angle
        case volumeROI
        case annotation
    }
    
    // MARK: - Measurement Creation
    
    func beginMeasurement(tool: Tool) {
        activeTool = tool
        pendingPoints.removeAll()
    }
    
    func addPoint(_ point: simd_float3) {
        pendingPoints.append(point)
        
        // Complete measurement when enough points
        switch activeTool {
        case .length where pendingPoints.count == 2:
            completeLengthMeasurement()
        case .angle where pendingPoints.count == 3:
            completeAngleMeasurement()
        default:
            break
        }
    }
    
    private func completeLengthMeasurement() {
        guard pendingPoints.count == 2 else { return }
        let measurement = SpatialMeasurement.length(
            from: pendingPoints[0],
            to: pendingPoints[1]
        )
        measurements.append(measurement)
        pendingPoints.removeAll()
        activeTool = nil
    }
    
    private func completeAngleMeasurement() {
        guard pendingPoints.count == 3 else { return }
        let measurement = SpatialMeasurement.angle(
            point1: pendingPoints[0],
            vertex: pendingPoints[1],
            point2: pendingPoints[2]
        )
        measurements.append(measurement)
        pendingPoints.removeAll()
        activeTool = nil
    }
    
    // MARK: - Measurement Management
    
    func deleteMeasurement(_ measurement: SpatialMeasurement) {
        measurements.removeAll { $0.id == measurement.id }
    }
    
    func toggleVisibility(_ measurement: SpatialMeasurement) {
        if let index = measurements.firstIndex(where: { $0.id == measurement.id }) {
            measurements[index].isVisible.toggle()
        }
    }
    
    func clearAllMeasurements() {
        measurements.removeAll()
        annotations.removeAll()
        pendingPoints.removeAll()
        activeTool = nil
    }
    
    // MARK: - Annotations
    
    func addTextAnnotation(at position: simd_float3, text: String) {
        let annotation = Annotation3D(
            type: .text,
            position: position,
            text: text
        )
        annotations.append(annotation)
    }
    
    func deleteAnnotation(_ annotation: Annotation3D) {
        annotations.removeAll { $0.id == annotation.id }
    }
}
