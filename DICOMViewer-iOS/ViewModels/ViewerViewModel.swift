// ViewerViewModel.swift
// DICOMViewer iOS - Viewer View Model
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftUI
import DICOMKit
import DICOMCore
import CoreGraphics

/// View model for the DICOM image viewer
///
/// Manages image display, frame navigation, window/level, and playback.
@MainActor
@Observable
final class ViewerViewModel {
    // MARK: - Image State
    
    /// Currently displayed image
    var currentImage: CGImage?
    
    /// Current frame index (0-based)
    var currentFrame: Int = 0 {
        didSet {
            if currentFrame != oldValue {
                Task { await loadCurrentFrame() }
            }
        }
    }
    
    /// Total number of frames
    var frameCount: Int = 1
    
    /// Whether the viewer is loading
    var isLoading: Bool = false
    
    /// Error message (if any)
    var errorMessage: String?
    
    // MARK: - Window/Level
    
    /// Current window center
    var windowCenter: Double = 128.0 {
        didSet { Task { await loadCurrentFrame() } }
    }
    
    /// Current window width
    var windowWidth: Double = 256.0 {
        didSet { Task { await loadCurrentFrame() } }
    }
    
    /// Whether grayscale is inverted
    var isInverted: Bool = false {
        didSet { Task { await loadCurrentFrame() } }
    }
    
    /// Default window settings from DICOM
    var defaultWindowSettings: WindowSettings?
    
    /// All available window presets
    var windowPresets: [WindowSettings] = []
    
    // MARK: - Transform State
    
    /// Current zoom scale
    var zoomScale: CGFloat = 1.0
    
    /// Current pan offset
    var panOffset: CGSize = .zero
    
    /// Current rotation angle (in degrees, multiples of 90)
    var rotationAngle: Double = 0.0
    
    /// Whether image is flipped horizontally
    var isFlippedHorizontal: Bool = false
    
    /// Whether image is flipped vertically
    var isFlippedVertical: Bool = false
    
    // MARK: - Playback State
    
    /// Whether cine playback is active
    var isPlaying: Bool = false
    
    /// Playback frame rate (frames per second)
    var frameRate: Double = 10.0
    
    /// Playback direction (true = forward, false = reverse)
    var playbackForward: Bool = true
    
    /// Playback timer
    private var playbackTimer: Timer?
    
    // MARK: - Image Info
    
    /// Image dimensions (columns x rows)
    var imageDimensions: (columns: Int, rows: Int)?
    
    /// Pixel spacing in mm
    var pixelSpacing: (row: Double, column: Double)?
    
    /// Current modality
    var modality: String?
    
    /// Patient name
    var patientName: String?
    
    // MARK: - Presentation State
    
    /// Currently applied presentation state
    var presentationState: GrayscalePresentationState?
    
    /// Available presentation states for current image
    var availablePresentationStates: [PresentationStateInfo] = []
    
    /// Whether presentation state is being applied
    var isPresentationStateEnabled: Bool = false
    
    /// Original window settings (before GSPS applied)
    private var originalWindowSettings: WindowSettings?
    
    // MARK: - Dependencies
    
    private let renderingService = ImageRenderingService.shared
    private let presentationStateService = PresentationStateService.shared
    
    /// Currently loaded DICOM file
    private var dicomFile: DICOMFile?
    
    /// Current series being viewed
    private var currentSeries: DICOMSeries?
    
    /// Current instance being viewed
    private var currentInstance: DICOMInstance?
    
    /// Current pixel data for presentation state rendering
    private var currentPixelData: PixelData?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Loading
    
    /// Loads a series for viewing
    func loadSeries(_ series: DICOMSeries) async {
        currentSeries = series
        
        // Get the first instance
        guard let instances = series.instances, !instances.isEmpty else {
            errorMessage = "No images in series"
            return
        }
        
        // Sort by instance number
        let sortedInstances = instances.sorted { 
            ($0.instanceNumber ?? 0) < ($1.instanceNumber ?? 0) 
        }
        
        await loadInstance(sortedInstances[0])
    }
    
    /// Loads a specific instance
    func loadInstance(_ instance: DICOMInstance) async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let fileURL = URL(fileURLWithPath: instance.filePath)
            let data = try Data(contentsOf: fileURL)
            let file = try DICOMFile.read(from: data, force: true)
            
            dicomFile = file
            currentInstance = instance
            
            // Update frame count
            frameCount = instance.numberOfFrames
            currentFrame = 0
            
            // Get default window settings
            defaultWindowSettings = await renderingService.defaultWindowSettings(for: file)
            windowPresets = await renderingService.allWindowPresets(for: file)
            
            if let defaults = defaultWindowSettings {
                windowCenter = defaults.center
                windowWidth = defaults.width
            } else {
                // Auto-calculate from first frame
                windowCenter = 128.0
                windowWidth = 256.0
            }
            
            // Get image info
            imageDimensions = await renderingService.imageDimensions(for: file)
            pixelSpacing = await renderingService.pixelSpacing(for: file)
            modality = file.dataSet.string(for: .modality)
            patientName = file.dataSet.string(for: .patientName)
            
            // Reset transforms
            resetView()
            
            // Load first frame
            await loadCurrentFrame()
            
        } catch {
            errorMessage = "Failed to load image: \(error.localizedDescription)"
        }
    }
    
    /// Loads a DICOM file directly from URL
    func loadFile(at url: URL) async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let data = try Data(contentsOf: url)
            let file = try DICOMFile.read(from: data, force: true)
            
            dicomFile = file
            currentInstance = nil
            currentSeries = nil
            
            // Update frame count
            frameCount = await renderingService.frameCount(for: file)
            currentFrame = 0
            
            // Get default window settings
            defaultWindowSettings = await renderingService.defaultWindowSettings(for: file)
            windowPresets = await renderingService.allWindowPresets(for: file)
            
            if let defaults = defaultWindowSettings {
                windowCenter = defaults.center
                windowWidth = defaults.width
            }
            
            // Get image info
            imageDimensions = await renderingService.imageDimensions(for: file)
            pixelSpacing = await renderingService.pixelSpacing(for: file)
            modality = file.dataSet.string(for: .modality)
            patientName = file.dataSet.string(for: .patientName)
            
            // Reset transforms
            resetView()
            
            // Load first frame
            await loadCurrentFrame()
            
        } catch {
            errorMessage = "Failed to load file: \(error.localizedDescription)"
        }
    }
    
    /// Loads and renders the current frame
    private func loadCurrentFrame() async {
        guard let file = dicomFile else { return }
        
        do {
            currentImage = try await renderingService.renderFrame(
                from: file,
                frameIndex: currentFrame,
                windowCenter: windowCenter,
                windowWidth: windowWidth,
                invert: isInverted
            )
        } catch {
            errorMessage = "Failed to render frame: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Frame Navigation
    
    /// Goes to the next frame
    func nextFrame() {
        if currentFrame < frameCount - 1 {
            currentFrame += 1
        }
    }
    
    /// Goes to the previous frame
    func previousFrame() {
        if currentFrame > 0 {
            currentFrame -= 1
        }
    }
    
    /// Goes to a specific frame
    func goToFrame(_ index: Int) {
        currentFrame = max(0, min(index, frameCount - 1))
    }
    
    /// Goes to the first frame
    func firstFrame() {
        currentFrame = 0
    }
    
    /// Goes to the last frame
    func lastFrame() {
        currentFrame = frameCount - 1
    }
    
    // MARK: - Playback
    
    /// Toggles cine playback
    func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    /// Starts cine playback
    func startPlayback() {
        guard frameCount > 1 else { return }
        
        isPlaying = true
        
        let interval = 1.0 / frameRate
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advancePlayback()
            }
        }
    }
    
    /// Stops cine playback
    func stopPlayback() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    /// Advances playback by one frame
    private func advancePlayback() {
        if playbackForward {
            if currentFrame >= frameCount - 1 {
                currentFrame = 0
            } else {
                currentFrame += 1
            }
        } else {
            if currentFrame <= 0 {
                currentFrame = frameCount - 1
            } else {
                currentFrame -= 1
            }
        }
    }
    
    /// Updates playback frame rate
    func setFrameRate(_ rate: Double) {
        frameRate = max(1.0, min(30.0, rate))
        
        if isPlaying {
            stopPlayback()
            startPlayback()
        }
    }
    
    // MARK: - Window/Level
    
    /// Applies a window/level preset
    func applyPreset(_ preset: WindowSettings) {
        windowCenter = preset.center
        windowWidth = preset.width
    }
    
    /// Resets window/level to defaults
    func resetWindowLevel() {
        if let defaults = defaultWindowSettings {
            windowCenter = defaults.center
            windowWidth = defaults.width
        }
        isInverted = false
    }
    
    /// Toggles grayscale inversion
    func toggleInvert() {
        isInverted.toggle()
    }
    
    // MARK: - Transforms
    
    /// Resets all view transforms
    func resetView() {
        zoomScale = 1.0
        panOffset = .zero
        rotationAngle = 0.0
        isFlippedHorizontal = false
        isFlippedVertical = false
    }
    
    /// Rotates the image 90 degrees clockwise
    func rotateClockwise() {
        rotationAngle = rotationAngle + 90.0
        if rotationAngle >= 360 {
            rotationAngle -= 360
        }
    }
    
    /// Rotates the image 90 degrees counter-clockwise
    func rotateCounterClockwise() {
        rotationAngle = rotationAngle - 90.0
        if rotationAngle < 0 {
            rotationAngle += 360
        }
    }
    
    /// Toggles horizontal flip
    func toggleFlipHorizontal() {
        isFlippedHorizontal.toggle()
    }
    
    /// Toggles vertical flip
    func toggleFlipVertical() {
        isFlippedVertical.toggle()
    }
    
    /// Sets zoom to fit the screen
    func fitToScreen() {
        zoomScale = 1.0
        panOffset = .zero
    }
    
    /// Sets zoom to actual size (1:1 pixels)
    func actualSize() {
        zoomScale = 1.0
    }
    
    // MARK: - Frame Info
    
    /// Formatted frame counter string
    var frameCounterString: String {
        "\(currentFrame + 1) / \(frameCount)"
    }
    
    /// Whether this is a multi-frame image
    var isMultiFrame: Bool {
        frameCount > 1
    }
    
    // MARK: - Presentation State
    
    /// Loads available presentation states from a directory
    /// - Parameter directoryURL: Directory containing GSPS files
    func loadPresentationStates(from directoryURL: URL) async {
        guard let sopInstanceUID = currentInstance?.sopInstanceUID ?? dicomFile?.dataSet.string(for: .sopInstanceUID),
              let seriesInstanceUID = currentSeries?.seriesInstanceUID ?? dicomFile?.dataSet.string(for: .seriesInstanceUID) else {
            return
        }
        
        var loadedStates: [GrayscalePresentationState] = []
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            
            for fileURL in fileURLs {
                guard fileURL.pathExtension.lowercased() == "dcm" || fileURL.pathExtension.isEmpty else {
                    continue
                }
                
                if let gsps = try? await presentationStateService.loadGSPS(from: fileURL) {
                    loadedStates.append(gsps)
                }
            }
        } catch {
            // Directory may not exist or be empty
        }
        
        // Filter to applicable presentation states
        let applicable = await presentationStateService.findApplicablePresentationStates(
            for: sopInstanceUID,
            seriesInstanceUID: seriesInstanceUID,
            from: loadedStates
        )
        
        availablePresentationStates = applicable.map { PresentationStateInfo(from: $0) }
    }
    
    /// Adds a presentation state to the available list
    /// - Parameter gsps: The presentation state to add
    func addPresentationState(_ gsps: GrayscalePresentationState) {
        let info = PresentationStateInfo(from: gsps)
        if !availablePresentationStates.contains(where: { $0.id == info.id }) {
            availablePresentationStates.append(info)
        }
    }
    
    /// Applies a presentation state to the current image
    /// - Parameter gsps: The presentation state to apply (nil to remove)
    func applyPresentationState(_ gsps: GrayscalePresentationState?) async {
        // Store original window settings before first GSPS application
        // Only save if we haven't saved before and we're applying a new presentation state
        let shouldSaveOriginal = originalWindowSettings == nil && presentationState == nil && gsps != nil
        if shouldSaveOriginal {
            originalWindowSettings = WindowSettings(center: windowCenter, width: windowWidth)
        }
        
        presentationState = gsps
        isPresentationStateEnabled = (gsps != nil)
        
        if let gsps = gsps {
            // Apply VOI LUT settings from presentation state
            if let voiLUT = gsps.voiLUT {
                switch voiLUT {
                case .window(let center, let width, _, _):
                    windowCenter = center
                    windowWidth = width
                case .lut:
                    // LUT-based VOI is applied during rendering
                    break
                }
            }
            
            // Apply Presentation LUT settings
            if let presLUT = gsps.presentationLUT {
                switch presLUT {
                case .inverse:
                    isInverted = true
                case .identity:
                    isInverted = false
                case .lut:
                    // LUT-based presentation is applied during rendering
                    break
                }
            }
            
            // Apply spatial transformation
            if let spatial = gsps.spatialTransformation {
                rotationAngle = Double(spatial.rotation)
                isFlippedHorizontal = spatial.isFlipped
            }
            
            // Apply displayed area
            if let displayedArea = gsps.displayedArea {
                // Calculate zoom based on displayed area
                if let dims = imageDimensions {
                    let areaWidth = displayedArea.bottomRight.column - displayedArea.topLeft.column
                    let areaHeight = displayedArea.bottomRight.row - displayedArea.topLeft.row
                    
                    if areaWidth > 0 && areaHeight > 0 {
                        let zoomX = CGFloat(dims.columns) / CGFloat(areaWidth)
                        let zoomY = CGFloat(dims.rows) / CGFloat(areaHeight)
                        zoomScale = min(zoomX, zoomY)
                        
                        // Calculate pan offset to center the displayed area
                        let centerX = CGFloat(displayedArea.topLeft.column + areaWidth / 2)
                        let centerY = CGFloat(displayedArea.topLeft.row + areaHeight / 2)
                        let imageCenterX = CGFloat(dims.columns) / 2
                        let imageCenterY = CGFloat(dims.rows) / 2
                        
                        panOffset = CGSize(
                            width: (imageCenterX - centerX) * zoomScale,
                            height: (imageCenterY - centerY) * zoomScale
                        )
                    }
                }
            }
        } else {
            // Restore original settings
            if let original = originalWindowSettings {
                windowCenter = original.center
                windowWidth = original.width
            }
            isInverted = false
            resetView()
        }
        
        // Render with presentation state
        await loadCurrentFrameWithPresentationState()
    }
    
    /// Renders the current frame with presentation state applied
    private func loadCurrentFrameWithPresentationState() async {
        guard let file = dicomFile else { return }
        
        do {
            if let gsps = presentationState, isPresentationStateEnabled {
                // Get pixel data for GSPS rendering
                guard let pixelData = file.dataSet.pixelData() else {
                    throw ImageRenderingError.noPixelData
                }
                
                currentPixelData = pixelData
                
                // Apply presentation state through the applicator
                currentImage = await presentationStateService.applyPresentationState(
                    gsps,
                    to: pixelData,
                    frameIndex: currentFrame
                )
            } else {
                // Standard rendering without GSPS
                currentImage = try await renderingService.renderFrame(
                    from: file,
                    frameIndex: currentFrame,
                    windowCenter: windowCenter,
                    windowWidth: windowWidth,
                    invert: isInverted
                )
            }
        } catch {
            errorMessage = "Failed to render frame: \(error.localizedDescription)"
        }
    }
    
    /// Toggles presentation state on/off
    func togglePresentationState() async {
        if isPresentationStateEnabled {
            // Disable but keep the selected state
            isPresentationStateEnabled = false
            await loadCurrentFrame()
        } else if presentationState != nil {
            // Re-enable the selected state
            isPresentationStateEnabled = true
            await loadCurrentFrameWithPresentationState()
        }
    }
    
    /// Clears all presentation state settings
    func clearPresentationState() async {
        presentationState = nil
        isPresentationStateEnabled = false
        originalWindowSettings = nil
        await loadCurrentFrame()
    }
    
    /// Gets the image size for overlay calculations
    var imageSize: CGSize {
        if let dims = imageDimensions {
            return CGSize(width: dims.columns, height: dims.rows)
        }
        return CGSize(width: 512, height: 512)
    }
}
