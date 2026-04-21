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
@MainActor
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

    /// Transfer syntax UID of the loaded file.
    public var transferSyntaxUID: String = ""

    /// Human-readable name for the current transfer syntax.
    public var transferSyntaxName: String = ""

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

    /// Rescale slope from the DICOM header (default 1.0).
    public var rescaleSlope: Double = 1.0

    /// Rescale intercept from the DICOM header (default 0.0).
    public var rescaleIntercept: Double = 0.0

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

    /// Whether the image is flipped horizontally.
    public var isFlippedHorizontal: Bool = false

    /// Whether the image is flipped vertically.
    public var isFlippedVertical: Bool = false

    /// Whether the metadata overlay is visible.
    public var showMetadataOverlay: Bool = false

    /// Whether the performance overlay is visible.
    public var showPerformanceOverlay: Bool = false

    /// Whether the DICOM tag inspector sheet is visible.
    public var showDICOMInspector: Bool = false

    /// Whether the file importer dialog is presented.
    public var isFileImporterPresented: Bool = false

    // MARK: - Series / Multi-File Navigation

    /// All file paths in the current series (empty when viewing a standalone file).
    public var seriesFiles: [String] = []

    /// Index of the currently displayed file within `seriesFiles`.
    public var currentFileIndex: Int = 0

    /// Security-scoped parent URL shared by all files in the current series.
    public var seriesSecurityScopedParent: URL? = nil

    /// Whether the viewer is navigating a multi-file series.
    public var isInSeries: Bool { seriesFiles.count > 1 }

    /// Whether there is a previous file to navigate to.
    public var canGoPreviousFile: Bool { currentFileIndex > 0 }

    /// Whether there is a next file to navigate to.
    public var canGoNextFile: Bool { currentFileIndex < seriesFiles.count - 1 }

    // MARK: - Services

    /// Image rendering service.
    public let renderingService: ImageRenderingService

    /// Image cache service.
    public let cacheService: ImageCacheService

    /// Codec-aware image decoding service (Phase 8).
    public let decodingService: ImageDecodingService

    // MARK: - Performance

    /// Last render time in seconds.
    public var lastRenderTime: Double = 0.0

    // MARK: - Codec Inspector (Phase 8)

    /// Codec inspector state — populated after each successful decode.
    public var codecInspector = CodecInspectorViewModel()

    // MARK: - J2KSwift Testing Panel

    /// J2KSwift implementation testing state (benchmark, round-trip, platform probe).
    public var j2kTesting = J2KTestingViewModel()

    /// Whether the J2KSwift testing sheet is presented.
    public var showJ2KTesting: Bool = false

    // MARK: - JPIP Streaming (Phase 8)

    /// JPIP server URL string for remote streaming.
    /// Set this before calling ``loadFromJPIP()``.
    public var jpipURLString: String = ""

    /// Current JPIP loading state.
    public var jpipLoadingState: JPIPLoadingState = .idle

    /// Whether ROI-based decoding should be active at the current zoom level.
    ///
    /// Set to `true` automatically when zoom exceeds 2× and a JPIP URL is configured.
    public var isROIActiveOnZoom: Bool = false

    // MARK: - Progressive Decode (Phase 8)

    /// The current state of the progressive JPEG 2000 decode pipeline.
    ///
    /// Observe this property to update the quality-level badge in the viewer.
    public var progressiveDecodeState: ProgressiveDecodeState = .idle

    #if canImport(CoreGraphics)
    /// The most recently received progressive CGImage (quarter, half, or full resolution).
    ///
    /// This image replaces `currentImage` during the progressive decode sequence
    /// and is identical to it once the final full-resolution level is delivered.
    public var progressiveImage: CGImage?
    #endif

    /// Internal task handle for the active progressive decode. Cancelled when a new file loads.
    private var progressiveDecodeTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates an image viewer ViewModel with dependency-injected services.
    public init(
        renderingService: ImageRenderingService = ImageRenderingService(),
        cacheService: ImageCacheService = ImageCacheService(),
        decodingService: ImageDecodingService = ImageDecodingService()
    ) {
        self.renderingService = renderingService
        self.cacheService = cacheService
        self.decodingService = decodingService
    }

    // MARK: - File Loading

    /// Loads a DICOM file from a security-scoped URL.
    ///
    /// Use this overload when opening files from a file importer or drag-and-drop,
    /// where the URL carries sandbox access rights.
    ///
    /// - Parameter url: A security-scoped URL to the DICOM file.
    public func loadFile(from url: URL) {
        clearSeriesState()
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        isLoading = true
        errorMessage = nil

        do {
            let data = try Data(contentsOf: url)
            try loadDICOMData(data, path: url.path)
        } catch {
            errorMessage = "Failed to load file: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Loads a DICOM file for viewing.
    ///
    /// - Parameter path: File path to load.
    public func loadFile(at path: String) {
        clearSeriesState()
        loadFileInternal(at: path, securityScopedParent: nil)
    }

    /// Loads a DICOM file for viewing, using a security-scoped parent URL
    /// for sandbox access if needed.
    ///
    /// - Parameters:
    ///   - path: File path to load.
    ///   - securityScopedParent: Optional parent URL with security-scoped access rights.
    public func loadFile(at path: String, securityScopedParent: URL?) {
        clearSeriesState()
        loadFileInternal(at: path, securityScopedParent: securityScopedParent)
    }

    // MARK: - Series Navigation

    /// Loads a set of DICOM files as a navigable series and displays the file at `startIndex`.
    ///
    /// - Parameters:
    ///   - files: Ordered list of file paths belonging to the series.
    ///   - startIndex: Index of the file to display first (clamped to valid range).
    ///   - securityScopedParent: Optional security-scoped parent URL covering all files.
    public func loadSeries(files: [String], startIndex: Int = 0, securityScopedParent: URL? = nil) {
        guard !files.isEmpty else { return }
        let idx = max(0, min(startIndex, files.count - 1))
        seriesFiles = files
        currentFileIndex = idx
        seriesSecurityScopedParent = securityScopedParent
        loadFileInternal(at: files[idx], securityScopedParent: securityScopedParent)
    }

    /// Navigates to the previous file in the series.
    public func navigateToPreviousFile() {
        guard canGoPreviousFile else { return }
        currentFileIndex -= 1
        loadFileInternal(at: seriesFiles[currentFileIndex], securityScopedParent: seriesSecurityScopedParent)
    }

    /// Navigates to the next file in the series.
    public func navigateToNextFile() {
        guard canGoNextFile else { return }
        currentFileIndex += 1
        loadFileInternal(at: seriesFiles[currentFileIndex], securityScopedParent: seriesSecurityScopedParent)
    }

    // MARK: - Internal Helpers

    /// Clears series navigation state. Called when a standalone file is opened directly.
    private func clearSeriesState() {
        seriesFiles = []
        currentFileIndex = 0
        seriesSecurityScopedParent = nil
        cancelProgressiveDecode()
    }

    /// Internal file loader that does NOT reset series state.
    /// Used by both the public loadFile methods (after they clear series state)
    /// and by series navigation methods.
    private func loadFileInternal(at path: String, securityScopedParent: URL?) {
        if let scopedURL = securityScopedParent {
            isLoading = true
            errorMessage = nil
            let accessing = scopedURL.startAccessingSecurityScopedResource()
            defer { if accessing { scopedURL.stopAccessingSecurityScopedResource() } }
            do {
                let url = URL(fileURLWithPath: path)
                let data = try Data(contentsOf: url)
                try loadDICOMData(data, path: path)
            } catch {
                errorMessage = "Failed to load file: \(error.localizedDescription)"
                isLoading = false
            }
        } else {
            isLoading = true
            errorMessage = nil
            do {
                let url = URL(fileURLWithPath: path)
                let data = try Data(contentsOf: url)
                try loadDICOMData(data, path: path)
            } catch {
                errorMessage = "Failed to load file: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    /// Shared implementation for loading parsed DICOM data.
    private func loadDICOMData(_ data: Data, path: String) throws {
        let file: DICOMFile
        do {
            file = try DICOMFile.read(from: data)
        } catch {
            // Retry with force=true for legacy DICOM files without Part 10 header
            file = try DICOMFile.read(from: data, force: true)
        }

        self.dicomFile = file
        self.filePath = path
        self.sopInstanceUID = file.dataSet.string(for: .sopInstanceUID)

        let ds = file.dataSet
        let fmi = file.fileMetaInformation

        // Extract transfer syntax information
        let tsUID = fmi.string(for: .transferSyntaxUID)
            ?? ds.string(for: .transferSyntaxUID)
            ?? file.transferSyntaxUID
            ?? ""
        self.transferSyntaxUID = tsUID
        self.transferSyntaxName = ImageMetadataHelpers.transferSyntaxLabel(for: tsUID)

        // Read metadata directly from current file tags first.
        // This ensures overlay values match what is actually stored in the
        // currently loaded DICOM file (including transcoded outputs).
        imageRows = ds.uint16(for: .rows).map(Int.init) ?? 0
        imageColumns = ds.uint16(for: .columns).map(Int.init) ?? 0
        bitsAllocated = ds.uint16(for: .bitsAllocated).map(Int.init) ?? 0
        bitsStored = ds.uint16(for: .bitsStored).map(Int.init) ?? 0
        highBit = ds.uint16(for: .highBit).map(Int.init) ?? 0
        isSigned = (ds.uint16(for: .pixelRepresentation) ?? 0) == 1
        samplesPerPixel = ds.uint16(for: .samplesPerPixel).map(Int.init) ?? 1
        planarConfiguration = ds.uint16(for: .planarConfiguration).map(Int.init) ?? 0
        photometricInterpretation = ds.string(for: .photometricInterpretation) ?? ""
        numberOfFrames = ds.string(for: .numberOfFrames)
            .flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            ?? 1

        // Fallback to pixel descriptor for missing tags only.
        if let descriptor = file.pixelDataDescriptor() {
            if imageRows == 0 { imageRows = descriptor.rows }
            if imageColumns == 0 { imageColumns = descriptor.columns }
            if bitsAllocated == 0 { bitsAllocated = descriptor.bitsAllocated }
            if bitsStored == 0 { bitsStored = descriptor.bitsStored }
            if highBit == 0 && descriptor.highBit != 0 { highBit = descriptor.highBit }
            if samplesPerPixel == 0 { samplesPerPixel = descriptor.samplesPerPixel }
            if planarConfiguration == 0 && descriptor.samplesPerPixel > 1 {
                planarConfiguration = descriptor.planarConfiguration
            }
            if photometricInterpretation.isEmpty {
                photometricInterpretation = descriptor.photometricInterpretation.rawValue
            }
            if numberOfFrames <= 0 { numberOfFrames = descriptor.numberOfFrames }
            if ds.uint16(for: .pixelRepresentation) == nil {
                isSigned = descriptor.isSigned
            }
        }

        // Extract rescale parameters for window correction
        let slope = file.rescaleSlope()
        let intercept = file.rescaleIntercept()
        self.rescaleSlope = slope
        self.rescaleIntercept = intercept

        // Extract window settings from header
        headerWindowSettings = file.allWindowSettings()
        if let firstWindow = headerWindowSettings.first {
            // Header window settings are in output units (post-rescale).
            // Convert to stored-value space since the renderer operates on raw stored values.
            if slope != 0 {
                windowCenter = (firstWindow.center - intercept) / slope
                windowWidth = firstWindow.width / abs(slope)
            } else {
                windowCenter = firstWindow.center
                windowWidth = firstWindow.width
            }
            voiLUTFunction = firstWindow.function.rawValue
        } else {
            // No header window settings — auto-calculate from actual pixel data range
            if let pixData = file.pixelData(),
               let range = pixData.pixelRange(forFrame: 0) {
                windowCenter = Double(range.min + range.max) / 2.0
                windowWidth = max(1.0, Double(range.max - range.min))
            }
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

        // Populate the codec inspector with metadata for this file (Phase 8)
        let inspectorStatus = decodingService.inspectorStatus(for: file)
        switch inspectorStatus {
        case .uncompressed:
            codecInspector.status = inspectorStatus
        default:
            // For compressed files, do a timed decode to populate timing info
            if let result = decodingService.decode(file: file) {
                codecInspector.update(from: result, frameCount: numberOfFrames)
            } else {
                codecInspector.status = inspectorStatus
            }
        }

        isLoading = false

        // Start progressive decode for J2K/HTJ2K files (Phase 8).
        startProgressiveDecode()
    }

    // MARK: - Rendering

    /// Renders the current frame with the current window/level settings.
    /// Uses throwing rendering variants so detailed PixelDataError descriptions are
    /// surfaced in the UI instead of a generic fallback message.
    public func renderCurrentFrame() {
        #if canImport(CoreGraphics)
        guard let file = dicomFile else { return }

        let start = Date()
        var image: CGImage?
        var detailedError: String?

        do {
            let window = WindowSettings(center: windowCenter, width: windowWidth)
            image = try file.tryRenderFrame(currentFrameIndex, window: window)
        } catch let e as PixelDataError {
            detailedError = e.description
        } catch {
            detailedError = error.localizedDescription
        }

        // Fall back to auto-windowing if explicit windowing fails
        if image == nil {
            do {
                image = try file.tryRenderFrameWithStoredWindow(currentFrameIndex)
                detailedError = nil   // auto-windowing succeeded – clear any earlier error
            } catch let e as PixelDataError {
                if detailedError == nil { detailedError = e.description }
            } catch {
                if detailedError == nil { detailedError = error.localizedDescription }
            }
        }

        lastRenderTime = Date().timeIntervalSince(start)
        currentImage = image

        if image == nil && errorMessage == nil {
            let tsInfo = transferSyntaxName.isEmpty ? "" : " Transfer Syntax: \(transferSyntaxName)."
            errorMessage = detailedError
                ?? "Unable to render pixel data.\(tsInfo) The file may use an unsupported transfer syntax or contain no displayable image data."
        } else if image != nil {
            // Clear any previous rendering error upon success
            errorMessage = nil
        }
        #endif
    }

    // MARK: - Window/Level

    /// Applies a window/level preset.
    ///
    /// Preset values are in output units; they are converted to stored-value space.
    /// - Parameter preset: The preset to apply.
    public func applyPreset(_ preset: WindowLevelPreset) {
        if rescaleSlope != 0 {
            windowCenter = (preset.center - rescaleIntercept) / rescaleSlope
            windowWidth = preset.width / abs(rescaleSlope)
        } else {
            windowCenter = preset.center
            windowWidth = preset.width
        }
        renderCurrentFrame()
    }

    /// Applies window settings from the DICOM header.
    ///
    /// Header values are in output units; they are converted to stored-value space.
    /// - Parameter settings: The window settings to apply.
    public func applyWindowSettings(_ settings: WindowSettings) {
        if rescaleSlope != 0 {
            windowCenter = (settings.center - rescaleIntercept) / rescaleSlope
            windowWidth = settings.width / abs(rescaleSlope)
        } else {
            windowCenter = settings.center
            windowWidth = settings.width
        }
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
    ///
    /// Automatically enables ROI decode when zoom exceeds 2× and a JPIP URL is configured.
    public func zoomIn() {
        zoomLevel = GestureHelpers.clampZoom(zoomLevel * 1.25)
        updateROIOnZoom()
    }

    /// Zooms out by a step.
    public func zoomOut() {
        zoomLevel = GestureHelpers.clampZoom(zoomLevel / 1.25)
        updateROIOnZoom()
    }

    /// Resets zoom, pan, and rotation to defaults.
    public func resetView() {
        resetTransformations()
    }

    /// Resets all image transforms: zoom, pan, rotation, and flip.
    public func resetTransformations() {
        zoomLevel = 1.0
        panOffsetX = 0.0
        panOffsetY = 0.0
        rotationAngle = 0.0
        isFlippedHorizontal = false
        isFlippedVertical = false
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

    /// Stored view dimensions — updated by the view layer when the container resizes.
    public var viewContentWidth: Double = 0
    public var viewContentHeight: Double = 0

    /// Fits the image using the last-known view dimensions. Used by Commands (no access to view state).
    public func fitToView() {
        fitToView(viewWidth: viewContentWidth, viewHeight: viewContentHeight)
    }

    /// Rotates the image 90° clockwise.
    public func rotateClockwise() {
        rotationAngle = GestureHelpers.rotateClockwise(from: rotationAngle)
    }

    /// Rotates the image 90° counter-clockwise.
    public func rotateCounterClockwise() {
        rotationAngle = GestureHelpers.rotateCounterClockwise(from: rotationAngle)
    }

    /// Flips the image horizontally.
    public func flipHorizontal() {
        isFlippedHorizontal.toggle()
    }

    /// Flips the image vertically.
    public func flipVertical() {
        isFlippedVertical.toggle()
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

    /// Formatted transfer syntax label for the currently loaded file.
    public var transferSyntaxLabel: String {
        transferSyntaxName.isEmpty ? "N/A" : transferSyntaxName
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

    /// Human-readable series position text, e.g. "3 / 12".
    public var seriesPositionText: String {
        guard isInSeries else { return "" }
        return "\(currentFileIndex + 1) / \(seriesFiles.count)"
    }

    // MARK: - JPIP Loading (Phase 8)

    /// Loads and renders a DICOM image from a JPIP server.
    ///
    /// Fetches an initial low-quality preview (1 quality layer) first, then
    /// progressively refines to full quality. The ``jpipLoadingState`` property
    /// tracks progress.
    ///
    /// - Note: Requires a valid URL in ``jpipURLString`` and an active network connection.
    public func loadFromJPIP() async {
        guard !jpipURLString.isEmpty else {
            jpipLoadingState = .failed(reason: "No JPIP URL provided")
            return
        }
        guard let serverURL = extractJPIPServerURL(from: jpipURLString),
              let jpipURI   = URL(string: jpipURLString) else {
            jpipLoadingState = .failed(reason: "Invalid JPIP URL: \(jpipURLString)")
            return
        }

        // Phase 1: fetch low-quality preview
        jpipLoadingState = .fetchingPreview
        let client = DICOMJPIPClient(serverURL: serverURL)
        do {
            let preview = try await client.fetchProgressiveQuality(jpipURI: jpipURI, layers: 1)
            applyJPIPImage(preview, layers: 1)
            jpipLoadingState = .refining(layers: 4)

            // Phase 2: refine to full quality
            let full = try await client.fetchImage(jpipURI: jpipURI)
            applyJPIPImage(full, layers: 0)
            jpipLoadingState = .loaded(layers: 0)
        } catch {
            jpipLoadingState = .failed(reason: error.localizedDescription)
        }
    }

    // MARK: - Private Phase 8 Helpers

    /// Updates ``isROIActiveOnZoom`` based on the current zoom level and JPIP URL.
    private func updateROIOnZoom() {
        isROIActiveOnZoom = zoomLevel > 2.0 && !jpipURLString.isEmpty
    }

    /// Applies a received `DICOMJPIPImage` to the viewer state.
    ///
    /// Updates dimension and bit-depth metadata. Rendering from raw JPIP pixel
    /// data requires a `DICOMFile` wrapper; consumers should call
    /// `renderCurrentFrame()` once the file has been created from the JPIP bytes.
    private func applyJPIPImage(_ jpipImage: DICOMJPIPImage, layers: Int) {
        imageRows         = jpipImage.height
        imageColumns      = jpipImage.width
        bitsAllocated     = jpipImage.bitDepth
        bitsStored        = jpipImage.bitDepth
        samplesPerPixel   = jpipImage.components
        numberOfFrames    = 1
        photometricInterpretation = jpipImage.components == 1 ? "MONOCHROME2" : "RGB"
        // Note: currentImage is populated by renderCurrentFrame() once the caller
        // wraps jpipImage.pixelData in a DICOMFile and calls loadFile(_:).
    }

    /// Extracts the JPIP server base URL from a full JPIP URI.
    ///
    ///     "jpip://pacs.example.com:8080/dcm4chee-arc/wado?..." → "http://pacs.example.com:8080"
    private func extractJPIPServerURL(from jpipURIString: String) -> URL? {
        var s = jpipURIString
        if s.hasPrefix("jpips://") { s = "https://" + s.dropFirst(8) }
        else if s.hasPrefix("jpip://") { s = "http://" + s.dropFirst(7) }
        guard let url = URL(string: s),
              let scheme = url.scheme,
              let host   = url.host else { return nil }
        let port = url.port.map { ":\($0)" } ?? ""
        return URL(string: "\(scheme)://\(host)\(port)")
    }

    // MARK: - Progressive Decode (Phase 8)

    /// Starts the progressive decode pipeline for the currently loaded J2K/HTJ2K file.
    ///
    /// Cancels any previous progressive decode task, then launches a new unstructured
    /// `Task` that iterates the `AsyncStream` from
    /// ``ImageDecodingService/decodeProgressively(file:windowCenter:windowWidth:)``.
    ///
    /// State machine:
    /// - `.unavailable` is set synchronously when the file is not J2K/HTJ2K.
    /// - `.decoding(.quarter)` after the first yielded frame.
    /// - `.decoding(.half)` after the second frame.
    /// - `.complete(_:)` after the third (full-resolution) frame.
    ///
    /// Each frame is reflected into `progressiveImage` (and `currentImage`) for the
    /// SwiftUI `Canvas` in `ProgressiveImageView` to pick up automatically.
    func startProgressiveDecode() {
        #if canImport(CoreGraphics)
        guard let file = dicomFile else { return }

        // Cancel any in-flight task from a previous file load.
        progressiveDecodeTask?.cancel()

        let tsUID = file.transferSyntaxUID ?? ""
        guard ProgressiveDecodeHelpers.isJ2KTransferSyntax(tsUID) else {
            progressiveDecodeState = .unavailable
            return
        }

        let svc = decodingService
        let wc = windowCenter
        let ww = windowWidth

        progressiveDecodeState = .decoding(level: .quarter)

        progressiveDecodeTask = Task { [weak self] in
            guard let self else { return }
            let stream = svc.decodeProgressively(file: file, windowCenter: wc, windowWidth: ww)
            for await (level, image, decodeMs) in stream {
                guard !Task.isCancelled else { break }
                // Property mutations inherit @MainActor isolation from the class.
                self.progressiveImage = image
                self.currentImage = image
                if level.isFinal {
                    self.progressiveDecodeState = .complete(totalDecodeMs: decodeMs)
                } else {
                    self.progressiveDecodeState = .decoding(level: level)
                }
            }
        }
        #endif
    }

    /// Cancels the active progressive decode task and resets the state to `.idle`.
    ///
    /// Called automatically when `clearSeriesState()` runs, ensuring no stale frames
    /// are applied after a new file is opened.
    private func cancelProgressiveDecode() {
        progressiveDecodeTask?.cancel()
        progressiveDecodeTask = nil
        progressiveDecodeState = .idle
        #if canImport(CoreGraphics)
        progressiveImage = nil
        #endif
    }
}

