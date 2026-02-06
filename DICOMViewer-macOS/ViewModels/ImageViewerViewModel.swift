//
//  ImageViewerViewModel.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import Foundation
import SwiftUI
import AppKit
import DICOMKit
import DICOMCore

/// ViewModel for the image viewer
@MainActor
@Observable
final class ImageViewerViewModel {
    // MARK: - Properties
    
    /// Currently loaded series
    private(set) var series: DicomSeries?
    
    /// All instances in the series
    private(set) var instances: [DicomInstance] = []
    
    /// Current instance index
    var currentIndex: Int = 0 {
        didSet {
            guard currentIndex != oldValue else { return }
            Task { await loadCurrentImage() }
        }
    }
    
    /// Current image
    private(set) var currentImage: NSImage?
    
    /// Current DICOM dataset
    private(set) var currentDataset: DataSet?
    
    /// Window center
    var windowCenter: Double = 128.0
    
    /// Window width
    var windowWidth: Double = 256.0
    
    /// Zoom level (1.0 = fit to viewport)
    var zoomLevel: Double = 1.0
    
    /// Pan offset
    var panOffset: CGSize = .zero
    
    /// Loading state
    private(set) var isLoading = false
    
    /// Error message
    var errorMessage: String?
    
    /// Whether to invert grayscale
    var invertGrayscale = false
    
    /// Rotation angle in degrees (0, 90, 180, 270)
    var rotationAngle: Double = 0
    
    // MARK: - Services
    
    private let databaseService = DatabaseService.shared
    
    // MARK: - Public Methods
    
    /// Load a series for viewing
    func loadSeries(_ series: DicomSeries) async {
        self.series = series
        isLoading = true
        errorMessage = nil
        
        do {
            instances = try databaseService.fetchInstances(forSeries: series.seriesInstanceUID)
            currentIndex = 0
            await loadCurrentImage()
        } catch {
            errorMessage = "Failed to load series: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Load the current image
    func loadCurrentImage() async {
        guard currentIndex >= 0 && currentIndex < instances.count else {
            currentImage = nil
            return
        }
        
        let instance = instances[currentIndex]
        
        do {
            // Read DICOM file
            let fileURL = URL(fileURLWithPath: instance.filePath)
            let fileData = try Data(contentsOf: fileURL)
            let dicomFile = try DICOMFile.read(from: fileData)
            
            currentDataset = dicomFile.dataset
            
            // Generate image
            if let pixelData = try? dicomFile.pixelData() {
                currentImage = try createImage(from: pixelData, dataset: dicomFile.dataset)
                
                // Set initial window/level from dataset
                if let wc = dicomFile.dataset.double(for: .windowCenter) {
                    windowCenter = wc
                }
                if let ww = dicomFile.dataset.double(for: .windowWidth) {
                    windowWidth = ww
                }
            } else {
                currentImage = nil
                errorMessage = "No pixel data available"
            }
        } catch {
            errorMessage = "Failed to load image: \(error.localizedDescription)"
            currentImage = nil
        }
    }
    
    /// Navigate to next image
    func nextImage() {
        if currentIndex < instances.count - 1 {
            currentIndex += 1
        }
    }
    
    /// Navigate to previous image
    func previousImage() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }
    
    /// Reset view to default
    func resetView() {
        zoomLevel = 1.0
        panOffset = .zero
        rotationAngle = 0
        invertGrayscale = false
        
        // Reset window/level to dataset defaults
        if let dataset = currentDataset {
            windowCenter = dataset.double(for: .windowCenter) ?? 128.0
            windowWidth = dataset.double(for: .windowWidth) ?? 256.0
        }
    }
    
    /// Apply window/level preset
    func applyPreset(_ preset: WindowLevelPreset) {
        windowCenter = preset.center
        windowWidth = preset.width
    }
    
    /// Rotate image
    func rotate(by degrees: Double) {
        rotationAngle = (rotationAngle + degrees).truncatingRemainder(dividingBy: 360)
    }
    
    // MARK: - Private Methods
    
    private func createImage(from pixelData: PixelData, dataset: DataSet) throws -> NSImage {
        // Get image dimensions
        let width = pixelData.width
        let height = pixelData.height
        
        // Create CGImage from pixel data
        guard let cgImage = try pixelData.cgImage(frame: 0, windowCenter: windowCenter, windowWidth: windowWidth) else {
            throw ViewerError.imageCreationFailed
        }
        
        // Create NSImage
        let size = NSSize(width: width, height: height)
        let image = NSImage(cgImage: cgImage, size: size)
        
        return image
    }
    
    // MARK: - Types
    
    struct WindowLevelPreset {
        let name: String
        let center: Double
        let width: Double
        
        static let lung = WindowLevelPreset(name: "Lung", center: -500, width: 1500)
        static let bone = WindowLevelPreset(name: "Bone", center: 300, width: 1500)
        static let softTissue = WindowLevelPreset(name: "Soft Tissue", center: 50, width: 350)
        static let brain = WindowLevelPreset(name: "Brain", center: 40, width: 80)
        static let liver = WindowLevelPreset(name: "Liver", center: 80, width: 150)
        static let mediastinum = WindowLevelPreset(name: "Mediastinum", center: 50, width: 350)
        
        static let allPresets: [WindowLevelPreset] = [
            .lung, .bone, .softTissue, .brain, .liver, .mediastinum
        ]
    }
}

// MARK: - Errors

enum ViewerError: LocalizedError {
    case imageCreationFailed
    case noPixelData
    
    var errorDescription: String? {
        switch self {
        case .imageCreationFailed:
            return "Failed to create image from pixel data"
        case .noPixelData:
            return "No pixel data available in DICOM file"
        }
    }
}
