//
//  VolumeRenderingViewModel.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import SwiftUI
import AppKit

/// ViewModel for 3D volume rendering with projection modes
@MainActor
@Observable
final class VolumeRenderingViewModel {

    // MARK: - Volume

    /// The loaded 3D volume
    private(set) var volume: Volume?

    /// The rendered output image
    private(set) var renderedImage: NSImage?

    // MARK: - Rendering Settings

    /// Current rendering mode
    var renderingMode: RenderingMode = .mip {
        didSet {
            guard renderingMode != oldValue else { return }
            render()
        }
    }

    /// Current transfer function (used for volume rendering mode)
    var transferFunction: TransferFunction = .bone {
        didSet {
            guard transferFunction != oldValue else { return }
            if renderingMode == .volumeRendering {
                render()
            }
        }
    }

    // MARK: - Camera

    /// Elevation angle in degrees
    var rotationX: Double = 0 {
        didSet {
            guard rotationX != oldValue else { return }
            render()
        }
    }

    /// Azimuth angle in degrees
    var rotationY: Double = 0 {
        didSet {
            guard rotationY != oldValue else { return }
            render()
        }
    }

    /// Zoom factor (1.0 = default)
    var zoom: Double = 1.0 {
        didSet {
            guard zoom != oldValue else { return }
            zoom = max(0.1, min(zoom, 10.0))
            render()
        }
    }

    // MARK: - Slab

    /// Slab thickness for thick-slab MIP. 0 means full volume.
    var slabThickness: Int = 0 {
        didSet {
            guard slabThickness != oldValue else { return }
            render()
        }
    }

    // MARK: - State

    /// Whether rendering is in progress
    private(set) var isLoading = false

    /// Error message
    var errorMessage: String?

    // MARK: - Engine

    private let engine = MPREngine()

    // MARK: - Public Methods

    /// Load a volume for rendering
    func loadVolume(_ volume: Volume) {
        self.volume = volume
        errorMessage = nil
        render()
    }

    /// Render the current view based on rendering mode and camera settings
    func render() {
        guard let volume = volume else { return }

        isLoading = true
        errorMessage = nil

        let plane = planeForRotation()
        let slab = slabThickness > 0 ? slabThickness : nil

        let slice: MPRSlice?
        switch renderingMode {
        case .mip:
            slice = engine.generateMIP(from: volume, along: plane, slabThickness: slab)
        case .minIP:
            slice = engine.generateMinIP(from: volume, along: plane)
        case .averageIP:
            slice = engine.generateAverageIP(from: volume, along: plane)
        case .volumeRendering:
            slice = engine.generateMIP(from: volume, along: plane, slabThickness: slab)
        }

        if let slice = slice {
            renderedImage = engine.renderSlice(
                slice,
                windowCenter: volume.windowCenter,
                windowWidth: volume.windowWidth
            )
        } else {
            renderedImage = nil
            errorMessage = "Failed to generate projection"
        }

        isLoading = false
    }

    /// Rotate the view by a delta amount
    func rotateBy(dx: Double, dy: Double) {
        rotationX = (rotationX + dy).truncatingRemainder(dividingBy: 360)
        rotationY = (rotationY + dx).truncatingRemainder(dividingBy: 360)
    }

    /// Reset the view to default settings
    func resetView() {
        rotationX = 0
        rotationY = 0
        zoom = 1.0
        slabThickness = 0
        render()
    }

    // MARK: - Private Helpers

    /// Determine the primary viewing plane based on rotation angles
    private func planeForRotation() -> MPRPlane {
        let normalizedX = abs(rotationX.truncatingRemainder(dividingBy: 360))
        let normalizedY = abs(rotationY.truncatingRemainder(dividingBy: 360))

        // If rotated mostly around X axis → coronal view
        if normalizedX > 45 && normalizedX < 135 {
            return .coronal
        }
        // If rotated mostly around Y axis → sagittal view
        if normalizedY > 45 && normalizedY < 135 {
            return .sagittal
        }
        // Default → axial view (looking down Z axis)
        return .axial
    }
}
