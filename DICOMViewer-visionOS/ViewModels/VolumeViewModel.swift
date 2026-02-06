// VolumeViewModel.swift
// DICOMViewer visionOS - Volume Rendering ViewModel
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import Observation
import simd

/// ViewModel for 3D volume rendering and interaction
@Observable
@MainActor
final class VolumeViewModel {
    // MARK: - State
    
    var volume: Volume3D?
    var transferFunction: TransferFunction = .bone
    var renderQuality: RenderQuality = .high
    var isRendering = false
    var renderProgress: Double = 0.0
    
    // MARK: - Transform
    
    var volumePosition: simd_float3 = .zero
    var volumeRotation: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0])
    var volumeScale: Float = 1.0
    
    // MARK: - Rendering Settings
    
    var showClippingPlanes = false
    var clippingPlanes: [ClippingPlane] = []
    var renderMode: RenderMode = .directVolumeRendering
    
    enum RenderQuality {
        case low, medium, high
        
        var samplingRate: Int {
            switch self {
            case .low: return 128
            case .medium: return 256
            case .high: return 512
            }
        }
    }
    
    enum RenderMode {
        case mip                      // Maximum Intensity Projection
        case directVolumeRendering    // DVR with transfer function
        case isosurface               // Surface rendering
    }
    
    struct ClippingPlane {
        var position: simd_float3
        var normal: simd_float3
        var isActive: Bool
    }
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Volume Loading
    
    func loadVolume(from series: DICOMSeries) async {
        isRendering = true
        renderProgress = 0.0
        
        do {
            volume = try await Volume3D.from(series: series)
            renderProgress = 1.0
        } catch {
            print("Failed to load volume: \(error)")
        }
        
        isRendering = false
    }
    
    // MARK: - Transform Updates
    
    func updatePosition(_ position: simd_float3) {
        volumePosition = position
    }
    
    func updateRotation(_ rotation: simd_quatf) {
        volumeRotation = rotation
    }
    
    func updateScale(_ scale: Float) {
        volumeScale = max(0.1, min(5.0, scale))
    }
    
    func resetTransform() {
        volumePosition = .zero
        volumeRotation = simd_quatf(angle: 0, axis: [0, 1, 0])
        volumeScale = 1.0
    }
    
    // MARK: - Transfer Function
    
    func setTransferFunction(_ function: TransferFunction) {
        transferFunction = function
    }
    
    func applyPreset(_ preset: TransferFunction) {
        transferFunction = preset
    }
    
    // MARK: - Clipping Planes
    
    func addClippingPlane(at position: simd_float3, normal: simd_float3) {
        let plane = ClippingPlane(position: position, normal: normal, isActive: true)
        clippingPlanes.append(plane)
    }
    
    func removeClippingPlane(at index: Int) {
        guard index >= 0 && index < clippingPlanes.count else { return }
        clippingPlanes.remove(at: index)
    }
    
    func clearClippingPlanes() {
        clippingPlanes.removeAll()
    }
}
