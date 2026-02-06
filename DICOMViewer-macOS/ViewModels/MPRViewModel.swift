//
//  MPRViewModel.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import SwiftUI
import AppKit

/// ViewModel coordinating Multi-Planar Reconstruction views
@MainActor
@Observable
final class MPRViewModel {

    // MARK: - Volume

    /// The loaded 3D volume
    private(set) var volume: Volume?

    // MARK: - Current Slice Indices

    /// Current axial (z) slice index
    var axialIndex: Int = 0 {
        didSet {
            guard axialIndex != oldValue else { return }
            axialIndex = clamp(axialIndex, max: maxAxialIndex)
            updateAxialSlice()
        }
    }

    /// Current sagittal (x) slice index
    var sagittalIndex: Int = 0 {
        didSet {
            guard sagittalIndex != oldValue else { return }
            sagittalIndex = clamp(sagittalIndex, max: maxSagittalIndex)
            updateSagittalSlice()
        }
    }

    /// Current coronal (y) slice index
    var coronalIndex: Int = 0 {
        didSet {
            guard coronalIndex != oldValue else { return }
            coronalIndex = clamp(coronalIndex, max: maxCoronalIndex)
            updateCoronalSlice()
        }
    }

    // MARK: - Rendered Images

    /// Current axial slice image
    private(set) var axialImage: NSImage?

    /// Current sagittal slice image
    private(set) var sagittalImage: NSImage?

    /// Current coronal slice image
    private(set) var coronalImage: NSImage?

    // MARK: - Window/Level

    /// Window center (HU)
    var windowCenter: Double = 40.0 {
        didSet {
            guard windowCenter != oldValue else { return }
            updateAllSlices()
        }
    }

    /// Window width (HU)
    var windowWidth: Double = 400.0 {
        didSet {
            guard windowWidth != oldValue else { return }
            updateAllSlices()
        }
    }

    // MARK: - Loading State

    /// Whether the volume is being loaded
    private(set) var isLoading = false

    /// Error message to display
    var errorMessage: String?

    // MARK: - Max Indices

    /// Maximum axial slice index
    private(set) var maxAxialIndex: Int = 0

    /// Maximum sagittal slice index
    private(set) var maxSagittalIndex: Int = 0

    /// Maximum coronal slice index
    private(set) var maxCoronalIndex: Int = 0

    // MARK: - Engine

    private let engine = MPREngine()

    // MARK: - Reference Line Positions

    /// Horizontal reference line position in axial view (normalized 0-1, represents sagittal index)
    var axialReferenceH: Double {
        guard maxCoronalIndex > 0 else { return 0.5 }
        return Double(coronalIndex) / Double(maxCoronalIndex)
    }

    /// Vertical reference line position in axial view (normalized 0-1, represents coronal index)
    var axialReferenceV: Double {
        guard maxSagittalIndex > 0 else { return 0.5 }
        return Double(sagittalIndex) / Double(maxSagittalIndex)
    }

    /// Horizontal reference line position in sagittal view (represents axial index)
    var sagittalReferenceH: Double {
        guard maxAxialIndex > 0 else { return 0.5 }
        return Double(axialIndex) / Double(maxAxialIndex)
    }

    /// Vertical reference line position in sagittal view (represents coronal index)
    var sagittalReferenceV: Double {
        guard maxCoronalIndex > 0 else { return 0.5 }
        return Double(coronalIndex) / Double(maxCoronalIndex)
    }

    /// Horizontal reference line position in coronal view (represents axial index)
    var coronalReferenceH: Double {
        guard maxAxialIndex > 0 else { return 0.5 }
        return Double(axialIndex) / Double(maxAxialIndex)
    }

    /// Vertical reference line position in coronal view (represents sagittal index)
    var coronalReferenceV: Double {
        guard maxSagittalIndex > 0 else { return 0.5 }
        return Double(sagittalIndex) / Double(maxSagittalIndex)
    }

    // MARK: - Public Methods

    /// Load a DICOM series and build the 3D volume
    func loadSeries(_ series: DicomSeries) async {
        isLoading = true
        errorMessage = nil

        do {
            let instances = series.instances
            guard !instances.isEmpty else {
                errorMessage = "Series contains no instances"
                isLoading = false
                return
            }

            let builtVolume = try await engine.buildVolume(from: instances)
            self.volume = builtVolume

            maxAxialIndex = engine.maxSliceIndex(for: .axial, in: builtVolume)
            maxSagittalIndex = engine.maxSliceIndex(for: .sagittal, in: builtVolume)
            maxCoronalIndex = engine.maxSliceIndex(for: .coronal, in: builtVolume)

            windowCenter = builtVolume.windowCenter
            windowWidth = builtVolume.windowWidth

            resetToCenter()
        } catch {
            errorMessage = "Failed to build volume: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Update the axial slice image
    func updateAxialSlice() {
        guard let volume = volume else { return }
        guard let slice = engine.extractAxialSlice(from: volume, at: axialIndex) else { return }
        axialImage = engine.renderSlice(slice, windowCenter: windowCenter, windowWidth: windowWidth)
    }

    /// Update the sagittal slice image
    func updateSagittalSlice() {
        guard let volume = volume else { return }
        guard let slice = engine.extractSagittalSlice(from: volume, at: sagittalIndex) else { return }
        sagittalImage = engine.renderSlice(slice, windowCenter: windowCenter, windowWidth: windowWidth)
    }

    /// Update the coronal slice image
    func updateCoronalSlice() {
        guard let volume = volume else { return }
        guard let slice = engine.extractCoronalSlice(from: volume, at: coronalIndex) else { return }
        coronalImage = engine.renderSlice(slice, windowCenter: windowCenter, windowWidth: windowWidth)
    }

    /// Update all three slice images
    func updateAllSlices() {
        updateAxialSlice()
        updateSagittalSlice()
        updateCoronalSlice()
    }

    /// Reset all slice indices to the center of the volume
    func resetToCenter() {
        guard volume != nil else { return }
        axialIndex = maxAxialIndex / 2
        sagittalIndex = maxSagittalIndex / 2
        coronalIndex = maxCoronalIndex / 2
        updateAllSlices()
    }

    // MARK: - Private Helpers

    private func clamp(_ value: Int, max: Int) -> Int {
        Swift.min(Swift.max(value, 0), Swift.max(max, 0))
    }
}
