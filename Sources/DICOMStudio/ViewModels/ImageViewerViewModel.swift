// ImageViewerViewModel.swift
// DICOMStudio
//
// DICOM Studio — Image viewer ViewModel

import Foundation
import Observation
import DICOMKit
import DICOMCore

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// ViewModel for the DICOM image viewer, managing rendering state,
/// window/level controls, cine playback, and zoom/pan gestures.
///
/// Requires macOS 14+ / iOS 17+ for the `@Observable` macro.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
public final class ImageViewerViewModel {

    // MARK: - Image State

    #if canImport(CoreGraphics)
    /// The currently rendered CGImage.
    public var currentImage: CGImage?
    #endif

    /// File path of the currently loaded DICOM file.
    public var filePath: String?

    /// Parsed DICOM file for rendering.
    public var dicomFile: DICOMFile?

    /// SOP Instance UID of the loaded file.
    public var sopInstanceUID: String?

    /// Whether an image is currently loading.
    public var isLoading: Bool = false

    /// Error message if loading or rendering fails.
    public var errorMessage: String?

    // MARK: - Pixel Data Metadata

    /// Image rows (height).
    public var imageRows: Int = 0

    /// Image columns (width).
    public var imageColumns: Int = 0

    /// Bits allocated per sample.
    public var bitsAllocated: Int = 0

    /// Bits stored per sample.
    public var bitsStored: Int = 0

    /// High bit position.
    public var highBit: Int = 0

    /// Whether pixel values are signed.
    public var isSigned: Bool = false

    /// Samples per pixel.
    public var samplesPerPixel: Int = 1

    /// Planar configuration.
    public var planarConfiguration: Int = 0

    /// Photometric interpretation string.
    public var photometricInterpretation: String = ""

    /// Total number of frames.
    public var numberOfFrames: Int = 1

    // MARK: - Window/Level State

    /// Current window center value.
    public var windowCenter: Double = 128.0

    /// Current window width value.
    public var windowWidth: Double = 256.0

    /// Whether grayscale is inverted.
    public var isInverted: Bool = false

    /// Available window presets for the current modality.
    public var availablePresets: [WindowLevelPreset] = []

    /// Window settings from the DICOM header.
    public var headerWindowSettings: [WindowSettings] = []

    /// Currently selected VOI LUT function.
    public var voiLUTFunction: String = "LINEAR"

    // MARK: - Multi-Frame / Cine State

    /// Current frame index (0-based).
    public var currentFrameIndex: Int = 0

    /// Cine playback state.
    public var playbackState: PlaybackState = .stopped

    /// Cine playback mode.
    public var playbackMode: PlaybackMode = .loop

    /// Cine playback direction (for bounce mode).
    public var playbackDirection: PlaybackDirection = .forward

    /// Cine playback frames per second.
    public var playbackFPS: Double = CinePlaybackHelpers.defaultFPS

    // MARK: - Zoom / Pan / Rotation

    /// Current zoom level (1.0 = 100%).
    public var zoomLevel: Double = 1.0

    /// Pan offset X in points.
    public var panOffsetX: Double = 0.0

    /// Pan offset Y in points.
    public var panOffsetY: Double = 0.0

    /// Rotation angle in degrees.
    public var rotationAngle: Double = 0.0

    /// Whether the metadata overlay is visible.
    public var showMetadataOverlay: Bool = false

    /// Whether the performance overlay is visible.
    public var showPerformanceOverlay: Bool = false

    // MARK: - Services

    /// Image rendering service.
    public let renderingService: ImageRenderingService

    /// Image cache service.
    public let cacheService: ImageCacheService

    // MARK: - Performance

    /// Last render time in seconds.
    public var lastRenderTime: Double = 0.0

    // MARK: - Initialization

    /// Creates an image viewer ViewModel with dependency-injected services.
    public init(
        renderingService: ImageRenderingService = ImageRenderingService(),
        cacheService: ImageCacheService = ImageCacheService()
    ) {
        self.renderingService = renderingService
        self.cacheService = cacheService
    }

    // MARK: - File Loading

    /// Loads a DICOM file for viewing.
    ///
    /// - Parameter path: File path to load.
    public func loadFile(at path: String) {
        isLoading = true
        errorMessage = nil

        do {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            let file = try DICOMFile.read(from: data)

            self.dicomFile = file
            self.filePath = path
            self.sopInstanceUID = file.dataSet.string(for: .sopInstanceUID)

            // Extract pixel data descriptor
            if let descriptor = file.pixelDataDescriptor() {
                imageRows = descriptor.rows
                imageColumns = descriptor.columns
                bitsAllocated = descriptor.bitsAllocated
                bitsStored = descriptor.bitsStored
                highBit = descriptor.highBit
                isSigned = descriptor.isSigned
                samplesPerPixel = descriptor.samplesPerPixel
                planarConfiguration = descriptor.planarConfiguration
                photometricInterpretation = descriptor.photometricInterpretation.rawValue
                numberOfFrames = descriptor.numberOfFrames
            }

            // Extract window settings from header
            headerWindowSettings = file.allWindowSettings()
            if let firstWindow = headerWindowSettings.first {
                windowCenter = firstWindow.center
                windowWidth = firstWindow.width
                voiLUTFunction = firstWindow.function.rawValue
            }

            // Load modality presets
            let modality = file.dataSet.string(for: .modality) ?? ""
            availablePresets = WindowLevelPresets.presets(for: modality)

            // Reset viewer state
            currentFrameIndex = 0
            playbackState = .stopped
            zoomLevel = 1.0
            panOffsetX = 0.0
            panOffsetY = 0.0
            rotationAngle = 0.0
            isInverted = false

            // Render first frame
            renderCurrentFrame()

            isLoading = false
        } catch {
            errorMessage = "Failed to load file: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Rendering

    /// Renders the current frame with the current window/level settings.
    public func renderCurrentFrame() {
        #if canImport(CoreGraphics)
        guard let file = dicomFile else { return }

        let start = Date()

        let image = renderingService.renderFrame(
            from: file,
            frameIndex: currentFrameIndex,
            windowCenter: windowCenter,
            windowWidth: windowWidth
        )

        lastRenderTime = Date().timeIntervalSince(start)
        currentImage = image
        #endif
    }

    // MARK: - Window/Level

    /// Applies a window/level preset.
    ///
    /// - Parameter preset: The preset to apply.
    public func applyPreset(_ preset: WindowLevelPreset) {
        windowCenter = preset.center
        windowWidth = preset.width
        renderCurrentFrame()
    }

    /// Applies window settings from the DICOM header.
    ///
    /// - Parameter settings: The window settings to apply.
    public func applyWindowSettings(_ settings: WindowSettings) {
        windowCenter = settings.center
        windowWidth = settings.width
        voiLUTFunction = settings.function.rawValue
        renderCurrentFrame()
    }

    /// Auto-adjusts window/level from the DICOM header.
    public func autoWindowLevel() {
        if let firstWindow = headerWindowSettings.first {
            applyWindowSettings(firstWindow)
        }
    }

    /// Adjusts window/level from a drag gesture.
    ///
    /// - Parameters:
    ///   - deltaX: Horizontal drag distance.
    ///   - deltaY: Vertical drag distance.
    public func adjustWindowLevel(deltaX: Double, deltaY: Double) {
        let result = GestureHelpers.windowLevelFromDrag(
            currentCenter: windowCenter,
            currentWidth: windowWidth,
            deltaX: deltaX,
            deltaY: deltaY
        )
        windowCenter = result.center
        windowWidth = result.width
        renderCurrentFrame()
    }

    /// Toggles grayscale inversion.
    public func toggleInversion() {
        isInverted.toggle()
        renderCurrentFrame()
    }

    // MARK: - Frame Navigation

    /// Navigates to a specific frame.
    ///
    /// - Parameter index: Frame index (0-based).
    public func goToFrame(_ index: Int) {
        guard index >= 0, index < numberOfFrames else { return }
        currentFrameIndex = index
        renderCurrentFrame()
    }

    /// Steps to the next frame.
    public func nextFrame() {
        currentFrameIndex = CinePlaybackHelpers.nextFrameStep(
            current: currentFrameIndex,
            total: numberOfFrames
        )
        renderCurrentFrame()
    }

    /// Steps to the previous frame.
    public func previousFrame() {
        currentFrameIndex = CinePlaybackHelpers.previousFrame(
            current: currentFrameIndex,
            total: numberOfFrames
        )
        renderCurrentFrame()
    }

    // MARK: - Cine Playback

    /// Toggles play/pause.
    public func togglePlayback() {
        switch playbackState {
        case .stopped, .paused:
            playbackState = .playing
        case .playing:
            playbackState = .paused
        }
    }

    /// Stops playback and resets to first frame.
    public func stopPlayback() {
        playbackState = .stopped
        currentFrameIndex = 0
        playbackDirection = .forward
        renderCurrentFrame()
    }

    /// Advances one cine frame (called by the timer).
    public func advanceCineFrame() {
        let result = CinePlaybackHelpers.nextFrame(
            current: currentFrameIndex,
            total: numberOfFrames,
            mode: playbackMode,
            direction: playbackDirection
        )

        currentFrameIndex = result.frame
        playbackDirection = result.direction

        if result.shouldStop {
            playbackState = .stopped
        }

        renderCurrentFrame()
    }

    // MARK: - Zoom / Pan / Rotation

    /// Zooms in by a step.
    public func zoomIn() {
        zoomLevel = GestureHelpers.clampZoom(zoomLevel * 1.25)
    }

    /// Zooms out by a step.
    public func zoomOut() {
        zoomLevel = GestureHelpers.clampZoom(zoomLevel / 1.25)
    }

    /// Resets zoom, pan, and rotation to defaults.
    public func resetView() {
        zoomLevel = 1.0
        panOffsetX = 0.0
        panOffsetY = 0.0
        rotationAngle = 0.0
    }

    /// Fits the image to the view.
    ///
    /// - Parameters:
    ///   - viewWidth: Available view width.
    ///   - viewHeight: Available view height.
    public func fitToView(viewWidth: Double, viewHeight: Double) {
        zoomLevel = GestureHelpers.fitZoom(
            imageWidth: Double(imageColumns),
            imageHeight: Double(imageRows),
            viewWidth: viewWidth,
            viewHeight: viewHeight
        )
        panOffsetX = 0.0
        panOffsetY = 0.0
    }

    /// Rotates the image 90° clockwise.
    public func rotateClockwise() {
        rotationAngle = GestureHelpers.rotateClockwise(from: rotationAngle)
    }

    /// Rotates the image 90° counter-clockwise.
    public func rotateCounterClockwise() {
        rotationAngle = GestureHelpers.rotateCounterClockwise(from: rotationAngle)
    }

    // MARK: - Display Text Helpers

    /// Formatted window/level text.
    public var windowLevelText: String {
        ImageMetadataHelpers.windowLevelText(center: windowCenter, width: windowWidth)
    }

    /// Formatted frame info text.
    public var frameText: String {
        ImageMetadataHelpers.frameText(current: currentFrameIndex + 1, total: numberOfFrames)
    }

    /// Formatted dimensions text.
    public var dimensionsText: String {
        ImageMetadataHelpers.dimensionsText(columns: imageColumns, rows: imageRows)
    }

    /// Formatted bit depth text.
    public var bitDepthText: String {
        ImageMetadataHelpers.bitDepthText(
            bitsAllocated: bitsAllocated,
            bitsStored: bitsStored,
            highBit: highBit
        )
    }

    /// Formatted pixel representation text.
    public var pixelRepresentationText: String {
        ImageMetadataHelpers.pixelRepresentationText(isSigned: isSigned)
    }

    /// Formatted photometric interpretation label.
    public var photometricLabel: String {
        ImageMetadataHelpers.photometricLabel(for: photometricInterpretation)
    }

    /// Formatted render time text.
    public var renderTimeText: String {
        ImageCacheHelpers.renderTimeText(lastRenderTime)
    }

    /// Whether the loaded image is a multi-frame image.
    public var isMultiFrame: Bool {
        numberOfFrames > 1
    }

    /// Whether an image is loaded and ready for viewing.
    public var hasImage: Bool {
        dicomFile != nil
    }

    /// Whether the photometric interpretation is monochrome.
    public var isMonochrome: Bool {
        let pi = photometricInterpretation.uppercased()
        return pi == "MONOCHROME1" || pi == "MONOCHROME2"
    }
}
