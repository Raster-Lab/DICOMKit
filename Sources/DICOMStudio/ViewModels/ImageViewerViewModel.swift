// ImageViewerViewModel.swift
// DICOMStudio
//
// DICOM Studio — Image viewer ViewModel

import Foundation
import Observation
import DICOMKit
import DICOMCore
import DICOMRenderKit

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

    #if canImport(Metal)
    /// The current frame as a GPU texture, when the display path can use one.
    ///
    /// Non-nil means zoom, pan, rotation, flip and inversion are applied by the
    /// display shader instead of by CPU passes and SwiftUI modifiers — so changing
    /// any of them redraws a textured quad and re-renders nothing. Nil means the
    /// viewport falls back to `Image(decorative:)` over ``currentImage``, which is
    /// what happens on a CPU-only machine and whenever a frame needs work the
    /// display path does not do (see ``canUseDisplayTexture``).
    ///
    /// Produced by the same dispatch that produces ``currentImage``, over the same
    /// output memory — having both costs nothing extra.
    public var displayTexture: DisplayFrameTexture?
    #endif

    /// File path of the currently loaded DICOM file.
    public var filePath: String?

    /// Parsed DICOM file for rendering.
    public var dicomFile: DICOMFile?

    /// SOP Instance UID of the loaded file.
    public var sopInstanceUID: String?

    /// Parsed waveform when the loaded file is a Waveform IOD (ECG, hemodynamic,
    /// etc.) rather than an image. Non-nil disables the pixel-rendering path and
    /// drives the waveform display instead.
    public var waveform: Waveform?

    /// Whether the currently loaded file is a waveform (ECG/hemodynamic/…) object
    /// with no displayable pixel data.
    public var isWaveform: Bool { waveform != nil }

    /// Parsed content when the loaded file is not a picture: a structured
    /// report, an encapsulated document, a key object selection, a presentation
    /// state. Non-nil disables the pixel path and drives the document display.
    public var nonImageContent: ViewerNonImageContent?

    /// Whether the loaded file holds something other than pixels or a waveform.
    public var isNonImageContent: Bool { nonImageContent != nil }

    /// What kind of content the viewer is currently showing.
    public var contentKind: ViewerContentKind {
        if let nonImageContent { return nonImageContent.kind }
        return isWaveform ? .waveform : .image
    }

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
    public var windowCenter: Double = 128.0 { didSet { printMarksFollowScreen() } }

    /// Current window width value.
    public var windowWidth: Double = 256.0 { didSet { printMarksFollowScreen() } }

    /// Whether grayscale is inverted.
    public var isInverted: Bool = false { didSet { printMarksFollowScreen() } }

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
    public var zoomLevel: Double = 1.0 { didSet { printMarksFollowScreen() } }

    /// Pan offset X in points.
    public var panOffsetX: Double = 0.0 { didSet { printMarksFollowScreen() } }

    /// Pan offset Y in points.
    public var panOffsetY: Double = 0.0 { didSet { printMarksFollowScreen() } }

    /// Rotation angle in degrees.
    public var rotationAngle: Double = 0.0 { didSet { printMarksFollowScreen() } }

    /// Whether the image is flipped horizontally.
    public var isFlippedHorizontal: Bool = false { didSet { printMarksFollowScreen() } }

    /// Whether the image is flipped vertically.
    public var isFlippedVertical: Bool = false { didSet { printMarksFollowScreen() } }

    /// Whether the metadata overlay is visible.
    public var showMetadataOverlay: Bool = false

    /// Whether the performance overlay is visible.
    public var showPerformanceOverlay: Bool = false

    /// What the open file says, for the corner annotations.
    ///
    /// Read once when the file loads rather than on every draw: the values are a
    /// header's worth of strings and none of them changes while the file is
    /// open, whereas the viewport redraws on every mouse delta of a window drag.
    /// See `ImageViewerViewModel+Annotations.swift`.
    public internal(set) var annotationText = ViewerAnnotationText()

    /// Whether the reading annotations are drawn in the viewport's corners.
    ///
    /// On by default: a workstation that does not say who the patient is, what
    /// window the picture is under and where in the series it sits is not a
    /// workstation. Film is a separate decision — it carries the identification
    /// strip below the picture instead, and has its own switch.
    /// See `ImageViewerViewModel+Annotations.swift`.
    public var showImageAnnotations: Bool = true

    /// Whether the DICOM tag inspector sheet is visible.
    public var showDICOMInspector: Bool = false

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

    // MARK: - DICOM Print

    /// Frames marked for printing, in film-cell order.
    ///
    /// Marking happens here in the viewer; the print sheet consumes this list.
    /// See `ImageViewerViewModel+Print.swift` for the marking API.
    public var printSelection = PrintSelectionModel()

    /// A request for the print screen — the sheet off macOS, the print preview
    /// window on it. Raised by ⌘P and by the library's "Print…"; on macOS the
    /// presenter lowers it again once the window is up, since a window's own
    /// state is the window's, not this flag's.
    public var isPrintSheetPresented: Bool = false

    /// Bumped when the print screen has to come down with the study it belongs
    /// to. A counter rather than a flag: a window is dismissed by an event, and
    /// two studies opened in a row must send two of them.
    ///
    /// Off macOS ``isPrintSheetPresented`` going false closes the sheet on its
    /// own; this is what reaches the separate window.
    public private(set) var printScreenDismissRequests: Int = 0

    /// Asks for the print screen to be closed.
    public func requestPrintScreenDismissal() {
        isPrintSheetPresented = false
        printScreenDismissRequests += 1
    }

    /// Whether the tray of selected images is showing on the right.
    ///
    /// Out of the way until there is something in it. A reader opens the viewer
    /// to read, and an empty column headed "On film" is a third of the chrome
    /// spent saying "nothing yet"; the moment an image is marked the tray comes
    /// up on its own — see ``revealPrintTray()``.
    public var isPrintTrayVisible: Bool = false

    // MARK: - Tile Layout

    /// The viewer's tile grid. 1×1 by default — one image, as before.
    ///
    /// The grid mirrors the film: tile order is film-cell order. See
    /// `ImageViewerViewModel+Layout.swift`.
    public internal(set) var layout: ViewerTileLayout = .single

    /// Per-tile state. Empty at 1×1, where the view model itself is the tile.
    public internal(set) var cells: [ViewerCellState] = []

    /// The tile currently receiving gestures and window/level.
    public internal(set) var focusedCellIndex: Int = 0

    // MARK: - Study Series

    /// Every series of the open study, for the viewer's series pane.
    ///
    /// Populated by the shell from the library. Empty when the viewer was given
    /// loose files rather than a study, in which case the pane stays hidden.
    /// See `ImageViewerViewModel+Series.swift`.
    public internal(set) var studySeries: [ViewerSeriesEntry] = []

    /// Study Instance UID of the series in ``studySeries``.
    public internal(set) var studyInstanceUID: String?

    /// Series the focused tile is showing, for the pane's "Current series" mark.
    public internal(set) var currentSeriesUID: String?

    /// Series shown in a tile at some point this session.
    ///
    /// Tracked so the pane can distinguish what has been looked at from what has
    /// not — the reading-completeness cue a "Not yet visited" card carries.
    public internal(set) var visitedSeriesUIDs: Set<String> = []

    /// Whether the series pane is showing.
    public var isSeriesPaneVisible: Bool = true

    /// Whether stepping past either end of the series wraps round to the other.
    ///
    /// On by default: a tile is scrolled through with the wheel, and stopping
    /// dead at the last image reads as a stuck viewer rather than as the end of
    /// the series. See `ImageViewerViewModel+ImageNavigation.swift`.
    public var isRepeatNavigationEnabled: Bool = true

    // MARK: - Codec Inspector (Phase 8)

    /// Codec inspector state — populated after each successful decode.
    public var codecInspector = CodecInspectorViewModel()

    // MARK: - J2KSwift Testing Panel

    /// J2KSwift implementation testing state (benchmark, round-trip, platform probe).
    public var j2kTesting = J2KTestingViewModel()

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
    /// Loads a file *without* touching series state.
    ///
    /// Internal rather than private so tile focus can move between files of the
    /// loaded series: `loadFile(at:)` clears the series, which would throw away
    /// navigation the moment the user clicked a second tile.
    func loadFileInternal(at path: String, securityScopedParent: URL?) {
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

    /// Returns whether the data set represents a Waveform IOD.
    ///
    /// Detects by SOP Class UID (the `1.2.840.10008.5.1.4.1.1.9.*` family) or by the
    /// presence of a Waveform Sequence, so legacy files with a missing/other SOP
    /// Class UID but valid waveform data are still recognized.
    private static func isWaveformFile(_ ds: DataSet) -> Bool {
        if let sopClass = ds.string(for: .sopClassUID)?.trimmingCharacters(in: .whitespaces),
           sopClass.hasPrefix("1.2.840.10008.5.1.4.1.1.9") {
            return true
        }
        return ds.sequence(for: .waveformSequence)?.isEmpty == false
    }

    /// Shared implementation for loading parsed DICOM data.
    private func loadDICOMData(_ data: Data, path: String) throws {
        // Clear any prior waveform so a failed/non-waveform load can't leave a stale
        // tracing on screen. The same holds for a report or document.
        self.waveform = nil
        self.nonImageContent = nil

        let file: DICOMFile
        do {
            file = try DICOMFile.read(from: data)
        } catch {
            // Retry with force=true for legacy DICOM files without Part 10 header
            file = try DICOMFile.read(from: data, force: true)
        }

        self.dicomFile = file
        // The decoded pixels belong to the *previous* file. Anything that assigns
        // `dicomFile` must clear them, or the viewport shows the last image's pixels
        // under the new one's window. This is the only assignment site; keep it that
        // way, or move the call next to the new one.
        invalidateDecodedPixels()
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
        self.annotationText = ViewerAnnotationText.make(from: ds, transferSyntaxUID: tsUID)

        // Waveform IODs (ECG, hemodynamic, EP, audio, …) carry a Waveform Sequence
        // instead of Pixel Data. Detect and parse them here so the viewer can render
        // a waveform tracing rather than failing the pixel-rendering path with an
        // "unable to render pixel data" error.
        if Self.isWaveformFile(ds),
           let parsed = try? WaveformParser.parse(from: ds),
           !parsed.multiplexGroups.isEmpty {
            self.waveform = parsed
            self.currentImage = nil
            self.numberOfFrames = 1
            self.currentFrameIndex = 0
            self.errorMessage = nil
            self.isLoading = false
            return
        }

        // Reports, encapsulated documents, key object selections and
        // presentation states carry no Pixel Data. They are classified by SOP
        // Class before the pixel path runs: falling through would report a
        // perfectly valid SR as an image that failed to decode.
        if let content = ViewerNonImageContentReader.content(
            of: ds, sopClassUID: ds.string(for: .sopClassUID)) {
            self.nonImageContent = content
            self.currentImage = nil
            self.numberOfFrames = 1
            self.currentFrameIndex = 0
            self.errorMessage = nil
            self.isLoading = false
            return
        }

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
        applyDefaultWindow(for: file, slope: slope, intercept: intercept)

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

    // MARK: - Decoded pixel cache

    /// The decoded pixels behind the focused viewport, held across re-windows.
    ///
    /// ``renderCurrentFrame()`` runs on **every** window/level delta, and it used to
    /// reach the pixels through `DICOMFile.tryRenderFrame` → `tryPixelData()`, which
    /// decodes from scratch each call. So a drag re-ran the codec once per mouse
    /// event. Measured on a 2048×2500 CR (Apple M4, release), per drag step:
    ///
    /// | Transfer syntax | decoding each step | cached |
    /// |---|---|---|
    /// | Uncompressed | 2.319 ms | 0.570 ms |
    /// | JPEG 2000 lossless | 16.161 ms | 0.558 ms |
    /// | JPEG-LS lossless | 74.120 ms | 0.589 ms |
    /// | RLE lossless | 354.986 ms | 0.526 ms |
    ///
    /// RLE was under three frames a second. Note the uncompressed row: its decode is
    /// 0.001 ms, so the 1.7 ms it still saves is `PixelData.frameData(at:)` copying
    /// the frame out on every call. That is why this caches **both** compressed and
    /// uncompressed sources rather than only the expensive-looking case.
    ///
    /// The tile and film path has done this since `FrameSourceCache` was written;
    /// the focused viewport simply never got the same treatment.
    @ObservationIgnored private var decodedPixels: PixelData?
    @ObservationIgnored private var decodedPalette: PaletteColorLUT?
    @ObservationIgnored private var decodeFailure: (any Error)?
    @ObservationIgnored private var decodeAttempted = false

    /// Whether to page-align cached pixels so the GPU can read them in place.
    /// Resolved once — the backend cannot change during a run.
    @ObservationIgnored
    private static let alignsForGPU = FrameRenderService.shared.prefersAlignedPixelData

    /// Forgets the decoded pixels. **Must** be called whenever `dicomFile` changes,
    /// or the viewport would keep showing the previous image's pixels.
    private func invalidateDecodedPixels() {
        decodedPixels = nil
        decodedPalette = nil
        decodeFailure = nil
        decodeAttempted = false
    }

    /// The decoded pixels for the loaded file, decoding on first use.
    ///
    /// A failed decode is cached too: without that, a file with no usable pixel data
    /// would re-attempt — and re-fail — the full decode on every render, which is the
    /// same per-event cost this cache exists to remove.
    private func decodedPixelSource(for file: DICOMFile) throws -> (PixelData, PaletteColorLUT?) {
        if let decodedPixels { return (decodedPixels, decodedPalette) }
        if decodeAttempted, let decodeFailure { throw decodeFailure }

        decodeAttempted = true
        do {
            let decoded = try file.tryPixelData()
            // Aligned once, here — never per render.
            let prepared = Self.alignsForGPU ? decoded.pageAligned() : decoded
            decodedPixels = prepared
            decodedPalette = file.dataSet.paletteColorLUT()
            return (prepared, decodedPalette)
        } catch {
            decodeFailure = error
            throw error
        }
    }

    /// The stored value of one pixel of the current frame, or `nil` when the
    /// pixels cannot be read.
    ///
    /// Reads the same decoded pixels the viewport is drawn from — the ones
    /// already held above — so a cursor moving across the image costs a lookup
    /// rather than a decode. Colour images answer their three samples instead.
    func storedPixelValue(column: Int, row: Int) -> (gray: Int?, rgb: (Int, Int, Int)?) {
        guard let file = dicomFile,
              let source = try? decodedPixelSource(for: file) else { return (nil, nil) }
        let pixels = source.0
        if samplesPerPixel >= 3 {
            let colour = pixels.colorValue(row: row, column: column, frame: currentFrameIndex)
            return (nil, colour)
        }
        return (pixels.pixelValue(row: row, column: column, frame: currentFrameIndex), nil)
    }

    // MARK: - GPU display path

    #if canImport(Metal)
    /// Whether this frame can be shown straight from a GPU texture.
    ///
    /// The one thing the display path does not do is burn overlay planes. Those are
    /// drawn *over* the image rather than into it, and some Secondary Captures —
    /// Siemens' Patient Protocol is the standing example — carry all-zero pixel data
    /// with their entire content in a 1-bit overlay. Showing the texture for one of
    /// those would present a black square where a page of text belongs, so frames
    /// with drawable overlays keep the CPU-burned `CGImage`.
    private func canUseDisplayTexture(for file: DICOMFile) -> Bool {
        !OverlayPlaneRenderer.hasOverlay(file.dataSet, forFrame: currentFrameIndex)
    }

    /// The tool state, as the display shader's geometry.
    ///
    /// Reading this rather than re-rendering is what makes zoom, pan, rotation, flip
    /// and inversion cost a redraw instead of a pass over every pixel.
    public var displayPresentation: DisplayPresentation {
        DisplayPresentation(
            zoom: zoomLevel,
            panX: panOffsetX,
            panY: panOffsetY,
            rotationDegrees: rotationAngle,
            flipHorizontal: isFlippedHorizontal,
            flipVertical: isFlippedVertical,
            invert: isInverted
        )
    }
    #endif

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
        var source: (pixelData: PixelData, palette: PaletteColorLUT?)?

        #if canImport(Metal)
        displayTexture = nil
        #endif

        do {
            let decoded = try decodedPixelSource(for: file)
            source = (decoded.0, decoded.1)
            let window = WindowSettings(center: windowCenter, width: windowWidth)
            let request = FrameRenderRequest(
                pixelData: decoded.0, frameIndex: currentFrameIndex,
                window: window, paletteLUT: decoded.1)

            #if canImport(Metal)
            // The GPU display path, when this frame qualifies: one dispatch yields
            // both the texture the viewport draws and the image everything else
            // expects, over the same output memory.
            if canUseDisplayTexture(for: file),
               let metal = FrameRenderService.shared.displayRenderer,
               let rendered = metal.renderForDisplay(request) {
                displayTexture = rendered.texture
                image = rendered.image
            } else {
                image = FrameRenderService.shared.renderFrame(request)
            }
            #else
            image = FrameRenderService.shared.renderFrame(request)
            #endif
        } catch let e as PixelDataError {
            detailedError = e.description
        } catch {
            detailedError = error.localizedDescription
        }

        // Fallback 1: automatic windowing from the frame's actual pixel range.
        // This recovers from a degenerate explicit window far more usefully than the
        // raw stored window, which — for modalities with a large Rescale Intercept
        // (e.g. CT) — clips almost everything to black and looks like a blank image.
        //
        // A nil window means "auto-window", which the CPU renderer resolves from the
        // frame's pixel range — the same thing `tryRenderFrame(_:)` did here before.
        if image == nil, let source,
           let auto = FrameRenderService.shared.renderFrame(FrameRenderRequest(
               pixelData: source.pixelData, frameIndex: currentFrameIndex,
               window: nil, paletteLUT: source.palette)) {
            image = auto
            detailedError = nil
        }

        // Fallback 2: the header's stored window, as a last resort.
        if image == nil, let source {
            if let stored = FrameRenderService.shared.renderFrame(FrameRenderRequest(
                pixelData: source.pixelData, frameIndex: currentFrameIndex,
                window: file.windowSettings(), paletteLUT: source.palette)) {
                image = stored
                detailedError = nil
            }
        }

        // Anything the modality drew *over* the image rather than into it.
        // Some Secondary Captures — Siemens' Patient Protocol is the standing
        // example — carry pixel data that is entirely zero and put their whole
        // content in a 1-bit overlay plane, so a viewer that renders only Pixel
        // Data shows a black square where a page of text should be.
        if let rendered = image {
            image = OverlayPlaneRenderer.burningOverlays(
                of: file.dataSet, onto: rendered, frameIndex: currentFrameIndex)
        }

        // Inversion is applied to the rendered frame rather than the window: the
        // renderer has no invert option, and negating the window would clip
        // differently for signed and rescaled modalities.
        //
        // On the GPU display path this is skipped: inversion is a fragment-stage
        // `1 - x` in the display shader, which is exact on 8-bit and free, and the
        // texture is what the viewport actually draws. Toggling it then costs a
        // redraw rather than a full-frame CPU pass.
        #if canImport(Metal)
        let invertOnGPU = displayTexture != nil
        #else
        let invertOnGPU = false
        #endif
        if isInverted, !invertOnGPU, let rendered = image {
            image = ImageInversion.inverted(rendered) ?? rendered
        }

        lastRenderTime = Date().timeIntervalSince(start)
        currentImage = image

        if image == nil {
            // Never fail to a silent blank: name the exact reason. A missing codec
            // for an encapsulated transfer syntax is the signature of a build whose
            // linked codec registry is stale (e.g. predating Part 2 / HTJ2K support)
            // — surface that explicitly so it's actionable instead of mysterious.
            let tsUID = file.transferSyntaxUID ?? ""
            let isEncapsulated = TransferSyntax.from(uid: tsUID)?.isEncapsulated ?? false
            if isEncapsulated && !CodecRegistry.shared.hasCodec(for: tsUID) {
                let name = transferSyntaxName.isEmpty ? tsUID : transferSyntaxName
                errorMessage = "No decoder registered for \(name) (\(tsUID)) in this build. "
                    + "Rebuild the app so the current codec registry is linked."
            } else if errorMessage == nil {
                let tsInfo = transferSyntaxName.isEmpty ? "" : " Transfer Syntax: \(transferSyntaxName)."
                errorMessage = detailedError
                    ?? "Unable to render pixel data.\(tsInfo) The file may use an unsupported transfer syntax or contain no displayable image data."
            }
        } else {
            // Clear any previous rendering error upon success
            errorMessage = nil
        }
        #endif
    }

    // MARK: - Window/Level

    /// Adopts a file's own presentation: its header VOI, or the pixel range when
    /// it declares none.
    ///
    /// The renderer works in stored-value space, so header values (which are in
    /// output units) are converted through the rescale pair.
    /// The numbers come from ``DICOMImageExporter/determineWindowSettings`` — the
    /// one window-resolution policy shared with export, the tile cache and the
    /// film — so a tile and the viewport showing the same image cannot disagree.
    func applyDefaultWindow(for file: DICOMFile, slope: Double, intercept: Double) {
        headerWindowSettings = file.allWindowSettings()
        if let firstWindow = headerWindowSettings.first {
            voiLUTFunction = firstWindow.function.rawValue
        }
        guard let pixData = file.pixelData() else {
            // No pixels to measure: the header VOI is all there is to go on.
            guard let firstWindow = headerWindowSettings.first else { return }
            if slope != 0 {
                windowCenter = (firstWindow.center - intercept) / slope
                windowWidth = firstWindow.width / abs(slope)
            } else {
                windowCenter = firstWindow.center
                windowWidth = firstWindow.width
            }
            return
        }
        let window = DICOMImageExporter.determineWindowSettings(
            from: file, pixelData: pixData, frameIndex: 0,
            windowCenter: nil, windowWidth: nil)
        windowCenter = window.center
        windowWidth = window.width
    }

    /// Re-adopts the loaded file's default window, discarding any adjustment.
    ///
    /// Used when a tile has no window of its own — a freshly hung series must
    /// read at its own VOI, not at whatever the previous image was set to.
    func resetWindowToFileDefault() {
        guard let file = dicomFile else { return }
        applyDefaultWindow(for: file, slope: rescaleSlope, intercept: rescaleIntercept)
    }

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
        #if canImport(Metal)
        // On the GPU display path inversion is part of the presentation, so the
        // view redraws with a different flag and nothing is re-rendered. The CPU
        // path has no such option and must run its full-frame pass.
        if displayTexture != nil { return }
        #endif
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

    /// Resets the image back to how it looked when it was first opened: zoom,
    /// pan, rotation, flip, window/level, and inversion all undone.
    public func resetView() {
        resetTransformations()
        autoWindowLevel()
        isInverted = false
        renderCurrentFrame()
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

    /// Turns the image by an arbitrary angle, clockwise for a positive delta.
    ///
    /// This is the rotate *tool*'s path: a drag turns the picture continuously
    /// through the full circle either way, where the toolbar's quarter-turn
    /// actions above snap back to the orthogonal angles.
    ///
    /// - Parameter degrees: Signed rotation to add, in degrees.
    public func rotate(byDegrees degrees: Double) {
        rotationAngle = GestureHelpers.normalizeRotation(rotationAngle + degrees)
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

        // JPIP retrieval is unavailable: DICOMJPIPClient's fetch methods are marked
        // @available(*, unavailable) because every request path in the pinned upstream
        // J2KSwift JPIP module (11.0.2) throws notImplemented. The two-phase
        // preview-then-refine flow (and its applyJPIPImage calls) is recoverable from git
        // history at de67c39 and should be restored when upstream lands. Surfacing the
        // real reason beats a spinner that never resolves.
        // Tracked as F1 in RESEARCH_ADOPTION_PLAN.md.
        _ = serverURL
        _ = jpipURI
        jpipLoadingState = .failed(
            reason: DICOMJPIPError.retrievalUnavailable.description
        )
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

