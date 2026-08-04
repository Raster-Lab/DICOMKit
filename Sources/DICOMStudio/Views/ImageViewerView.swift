// ImageViewerView.swift
// DICOMStudio
//
// DICOM Studio — Main image viewer view

#if canImport(SwiftUI)
import SwiftUI
import UniformTypeIdentifiers
import DICOMNetwork
import DICOMPrintKit
import DICOMRenderKit

/// Main DICOM image viewer view.
///
/// Displays the rendered DICOM image with zoom/pan gestures,
/// window/level controls, cine playback, and metadata overlay.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct ImageViewerView: View {
    @Bindable var viewModel: ImageViewerViewModel

    @State private var magnifyBy: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var viewSize: CGSize = .zero
    @State private var wlDragStart: CGSize = .zero

    /// Anchor for a zoom-tool drag, so the gesture applies deltas not absolutes.
    @State private var zoomDragStart: CGSize = .zero

    /// The click-and-drag tool currently armed, or `nil` for plain pan.
    ///
    /// Windowing and zoom are mutually exclusive: picking one arms it and
    /// disarms the other, and the toolbar highlights whichever is active.
    @State private var activeTool: ImageViewerDragTool?

    /// Turns scroll events into whole image steps — one per wheel notch.
    @State private var scrollSteps = ScrollStepAccumulator()

    /// Keyboard focus for the image area, so the arrow keys reach `onKeyPress`.
    @FocusState private var isImageAreaFocused: Bool

    /// Print state. Injected by the shell so the print sheet, the standalone
    /// Print screen, and job history are one shared state; created locally only
    /// when this view is used stand-alone.
    @State private var printViewModel: PrintViewModel?

    /// Size of the window the print sheet was raised from, so the sheet opens at
    /// the same size as the screen behind it.
    @State private var parentWindowSize: CGSize?

    public init(viewModel: ImageViewerViewModel, printViewModel: PrintViewModel? = nil) {
        self.viewModel = viewModel
        _printViewModel = State(initialValue: printViewModel)
    }

    /// Series pane, reading area, selection tray.
    ///
    /// The reading area is the only pure black on screen and the only thing that
    /// is framed: the panes and the gutter between them are chrome grey, so the
    /// image reads as a light box set into the station rather than as a third
    /// panel of equal weight. That is the habit a reporting station trains — the
    /// darkest, quietest rectangle is the one being read.
    public var body: some View {
        HStack(spacing: 0) {
            // The study's series, when the viewer was opened from a study. Loose
            // files have no series to list, so the pane stays out of the way.
            if viewModel.isSeriesPaneVisible && !viewModel.studySeries.isEmpty {
                ViewerSeriesPaneView(viewModel: viewModel)
                    .frame(width: Self.seriesPaneWidth)
            }

            readingArea

            // The selection, on the right: what has been picked, in film order.
            if viewModel.isPrintTrayVisible {
                ViewerPrintTrayView(viewModel: viewModel)
                    .frame(width: Self.printTrayWidth)
            }
        }
        // No dividers: the gutter and the change in tone already separate the
        // panes from the image, and a hairline beside a framed light box only
        // adds a second edge to read.
        .background(StudioColors.viewerChrome)
    }

    /// The image, framed and inset into the chrome.
    private var readingArea: some View {
        imageArea
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: Self.readingAreaCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Self.readingAreaCornerRadius)
                    .strokeBorder(readingAreaBorderColor, lineWidth: 1)
            }
            .padding(Self.readingAreaGutter)
    }

    /// The frame around the image.
    ///
    /// Neutral while the viewer is idle; picking up the accent once the image
    /// area holds the keyboard, which is what says the arrow keys will walk this
    /// stack. In a grid the focused tile carries its own ring, so the outer frame
    /// stays neutral there rather than drawing a second one around it.
    private var readingAreaBorderColor: Color {
        guard isImageAreaFocused, viewModel.hasImage, !viewModel.isMultiCellLayout else {
            return StudioColors.readingAreaBorder
        }
        return Color.accentColor.opacity(0.45)
    }

    /// Width of the selection tray — a legible thumbnail and two lines of label.
    private static let printTrayWidth: CGFloat = 180

    /// Width of the series pane — enough for a legible thumbnail and two lines
    /// of series description.
    private static let seriesPaneWidth: CGFloat = 190

    /// Chrome left visible around the image. Small on purpose: enough to read as
    /// a separate surface, not enough to cost the picture real room.
    private static let readingAreaGutter: CGFloat = 6

    private static let readingAreaCornerRadius: CGFloat = 5

    private var imageArea: some View {
        ZStack {
            // The light box. Painted by the reading area around it too, so this
            // one only has to cover the content — it must not spill past the
            // frame, which is what `ignoresSafeArea` here used to do.
            Color.black

            if viewModel.isLoading {
                ProgressView("Loading…")
                    .foregroundStyle(.white)
            } else if let waveform = viewModel.waveform {
                WaveformChartView(waveform: waveform)
            } else if let content = viewModel.nonImageContent {
                // Reports, encapsulated documents and the rest are read, not
                // rendered. This branch sits ahead of the error branch because
                // such an object is not a picture that failed — it never was one.
                ViewerNonImageContentView(content: content)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.yellow)
                    Text(errorMessage)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if viewModel.hasImage {
                // At 1×1 the viewer is the image; beyond that it is one tile of
                // a grid, and the grid decides where the live viewer sits.
                Group {
                    if viewModel.isMultiCellLayout {
                        ViewerTileGridView(viewModel: viewModel) { imageContent }
                    } else {
                        imageContent
                    }
                }
                    // Zoom and pan are drawn with `scaleEffect`/`offset`, which
                    // do not affect layout: without clipping, a zoomed image
                    // paints straight over the series pane and the selection
                    // tray beside it. The viewer is its own viewport.
                    .clipped()
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button("Fit to View") {
                            viewModel.fitToView(viewWidth: viewSize.width, viewHeight: viewSize.height)
                        }
                        Button("Reset View") {
                            viewModel.resetTransformations()
                        }
                        Divider()
                        Button("Rotate Clockwise") { viewModel.rotateClockwise() }
                        Button("Rotate Counter-Clockwise") { viewModel.rotateCounterClockwise() }
                        Button("Flip Horizontal") { viewModel.flipHorizontal() }
                        Button("Flip Vertical") { viewModel.flipVertical() }
                        Divider()
                        Button(viewModel.showPatientOverlay
                               ? "Hide Patient Overlay" : "Show Patient Overlay") {
                            viewModel.showPatientOverlay.toggle()
                        }
                        if viewModel.isMonochrome {
                            Divider()
                            Button(viewModel.isInverted ? "Remove Inversion" : "Invert Grayscale") {
                                viewModel.toggleInversion()
                            }
                        }
                        Divider()
                        Button(viewModel.isCurrentFrameMarkedForPrint
                               ? "Unmark for Print" : "Mark for Print") {
                            viewModel.togglePrintMarkForCurrentFrame()
                        }
                        // "All" is what is on screen — the images the current
                        // layout is showing, not the study behind them.
                        Button("Select All for Print") {
                            viewModel.markLayoutForPrint()
                        }
                        .disabled(viewModel.isLayoutFullyMarkedForPrint)
                        Button("Unselect All for Print") {
                            viewModel.unmarkLayoutForPrint()
                        }
                        .disabled(!viewModel.isAnyLayoutImageMarkedForPrint)
                        if viewModel.isMultiFrame {
                            Button("Mark All Frames for Print") {
                                viewModel.markAllFramesOfCurrentFileForPrint()
                            }
                        }
                        if viewModel.isInSeries {
                            Button("Mark Whole Series for Print") {
                                viewModel.markWholeSeriesForPrint()
                            }
                        }
                        if !viewModel.printSelection.isEmpty {
                            Button("Clear Print Marks", role: .destructive) {
                                viewModel.clearAllPrintMarks()
                            }
                        }
                    }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundStyle(.gray)
                    Text("No image loaded")
                        .foregroundStyle(.gray)
                }
            }
        }
        // Arrow-key image navigation. The image area takes focus so the keys are
        // delivered here; `.focusEffectDisabled()` keeps the focus ring off the
        // film. Left/Right walk images (frames, then files); Up/Down jump whole
        // files, which is how one skims a series past a long cine loop.
        // At 1×1 the whole image area is the drop target; in a grid each tile
        // has its own, so this one would swallow the drop first.
        .dropDestination(for: String.self) { seriesUIDs, _ in
            guard !viewModel.isMultiCellLayout, let uid = seriesUIDs.first else { return false }
            return viewModel.assignSeries(uid, toCell: 0)
        }
        .focusable(viewModel.hasImage)
        .focusEffectDisabled()
        .focused($isImageAreaFocused)
        .onAppear { isImageAreaFocused = true }
        .onChange(of: viewModel.filePath) { _, _ in isImageAreaFocused = true }
        .onKeyPress(.leftArrow) {
            viewModel.navigateToPreviousImage() ? .handled : .ignored
        }
        .onKeyPress(.rightArrow) {
            viewModel.navigateToNextImage() ? .handled : .ignored
        }
        .onKeyPress(.upArrow) {
            guard viewModel.canGoPreviousFile else { return .ignored }
            viewModel.navigateToPreviousFile()
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard viewModel.canGoNextFile else { return .ignored }
            viewModel.navigateToNextFile()
            return .handled
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        viewSize = geo.size
                        updateViewportSize(geo.size)
                    }
                    .onChange(of: geo.size) { _, newSize in
                        viewSize = newSize
                        updateViewportSize(newSize)
                    }
            }
        )
        .focusedValue(\.imageViewerViewModel, viewModel)
        .overlay(alignment: .bottomLeading) {
            if viewModel.showMetadataOverlay && viewModel.hasImage && !viewModel.isWaveform {
                ImageMetadataOverlayView(viewModel: viewModel)
                    .padding(8)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel.showPerformanceOverlay && viewModel.hasImage && !viewModel.isWaveform {
                performanceOverlay
                    .padding(8)
            }
        }
        // Patient identification in a reserved band under the picture, so text
        // and anatomy never share pixels. `safeAreaInset` takes the height from
        // the image area rather than covering it. In a grid each tile reserves
        // its own band, so this one is the 1×1 case only.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Images only: a report or a document is not a picture with a
            // caption, and the band would sit under a page of text.
            if viewModel.showPatientOverlay && viewModel.hasImage
                && !viewModel.isWaveform && !viewModel.isNonImageContent
                && !viewModel.isMultiCellLayout
                && viewModel.hasPatientOverlayText {
                PatientIdentificationOverlayView(
                    primaryLine: viewModel.patientOverlayPrimaryLine,
                    secondaryLine: viewModel.patientOverlaySecondaryLine,
                    cellSize: viewSize,
                    style: .band
                )
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isMultiFrame && viewModel.hasImage && !viewModel.isWaveform {
                CineControlsView(viewModel: viewModel)
                    .padding(.bottom, 40)
            }
        }
        .overlay(alignment: .topTrailing) {
            // Print mark: an explicit checkbox on the image, unchecked until the
            // user ticks it. Only ticked frames reach the print sheet.
            // In a grid each tile carries its own checkbox, so this one would be
            // ambiguous about which image it marks.
            if viewModel.hasImage && !viewModel.isWaveform && !viewModel.isMultiCellLayout {
                printMarkCheckbox
                    .padding(8)
            }
        }
        .toolbar {
            viewerToolbar
        }
        .sheet(isPresented: $viewModel.isPrintSheetPresented) {
            // Hosted rather than inlined: the sheet can also be raised from the
            // library ("Print…"), which may happen before this view has ever
            // appeared, so the print state must be created by the sheet itself.
            PrintSheetHost(
                selection: viewModel.printSelection,
                printViewModel: $printViewModel,
                parentSize: parentWindowSize
            )
        }
        .sheet(isPresented: $viewModel.showDICOMInspector) {
            if let file = viewModel.dicomFile {
                DICOMInspectorView(dicomFile: file)
            }
        }
    }

    // MARK: - Print

    /// On-image checkbox that marks the displayed frame for print.
    ///
    /// Unchecked by default — nothing is printed unless the user ticks it. When
    /// ticked it also shows the frame's 1-based film position.
    private var printMarkCheckbox: some View {
        let isMarked = viewModel.isCurrentFrameMarkedForPrint
        return Button {
            viewModel.togglePrintMarkForCurrentFrame()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isMarked ? "checkmark.square.fill" : "square")
                    .font(.body)
                    .foregroundStyle(isMarked ? Color.accentColor : .secondary)
                if let position = viewModel.currentFramePrintPosition {
                    Text("Print \(position)")
                        .font(.caption.monospacedDigit())
                } else {
                    Text("Print")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMarked ? "Unmark image for print" : "Mark image for print")
        .accessibilityAddTraits(isMarked ? [.isSelected] : [])
        .help(isMarked ? "Marked for print — click to unmark (M)"
                       : "Mark this image for print (M)")
    }

    /// Records the size the focused image is displayed at.
    ///
    /// In a grid the tiles report their own sizes, and the focused tile's is far
    /// smaller than the whole viewer — taking the outer size there would resolve
    /// zoom and pan against the wrong viewport and crop the wrong region.
    private func updateViewportSize(_ size: CGSize) {
        guard !viewModel.isMultiCellLayout else { return }
        viewModel.viewContentWidth = size.width
        viewModel.viewContentHeight = size.height
    }

    /// Opens the print sheet, creating its state on first use.
    private func openPrintSheet() {
        // The sheet is about to read the marks, so bring them up to date with
        // what is actually on screen — the user has usually kept arranging since
        // ticking the boxes.
        viewModel.refreshMarksFromViewer()

        // Film order follows the grid, so the preview reads like the screen.
        viewModel.syncPrintOrderToViewer()

        // Captured before the sheet exists, while the key window is still the
        // viewer's: the sheet opens at the size of the screen it came from.
        #if canImport(AppKit)
        parentWindowSize = NSApplication.shared.keyWindow?.frame.size
        #endif

        if printViewModel == nil {
            printViewModel = PrintViewModel(selection: viewModel.printSelection)
        } else {
            // Printers may have been added since the sheet was last open.
            printViewModel?.loadPrinters()
        }

        // Mirror the viewer's grid on film, so the preview matches the screen.
        if viewModel.isMultiCellLayout {
            printViewModel?.viewerLayout = PrintLayout(
                rows: viewModel.layout.rows, columns: viewModel.layout.columns)
            printViewModel?.layoutMode = .matchViewer
        } else {
            printViewModel?.viewerLayout = nil
            if printViewModel?.layoutMode == .matchViewer {
                printViewModel?.layoutMode = .automatic
            }
        }

        // The console reads like a fresh log each time the preview is opened,
        // not a running transcript of every past visit to this sheet.
        printViewModel?.resetConsole()

        viewModel.isPrintSheetPresented = true
    }

    // MARK: - Image Content

    #if canImport(Metal)
    /// The GPU-resident frame, when the display path is in use.
    private var metalDisplayFrame: DisplayFrameTexture? { viewModel.displayTexture }

    /// The view model's tool state plus whatever the in-flight gesture is adding.
    ///
    /// Gestures are folded in here rather than applied as view modifiers, because on
    /// this path the transform *is* the arrangement — a `.scaleEffect` on top would
    /// scale the already-transformed quad and compound the zoom.
    private var livePresentation: DisplayPresentation {
        var presentation = viewModel.displayPresentation
        presentation.zoom *= magnifyBy
        presentation.panX += dragOffset.width
        presentation.panY += dragOffset.height
        return presentation
    }
    #else
    private var metalDisplayFrame: Never? { nil }
    private var livePresentation: Int { 0 }
    #endif

    @ViewBuilder
    private var imageContent: some View {
        #if canImport(CoreGraphics)
        // Use the Canvas-based ProgressiveImageView for J2K/HTJ2K files that are
        // actively being decoded progressively (Phase 8).
        if viewModel.progressiveDecodeState != .unavailable &&
           viewModel.progressiveDecodeState != .idle,
           viewModel.progressiveImage != nil || viewModel.currentImage != nil {
            ProgressiveImageView(viewModel: viewModel)
                .gesture(panGesture)
                .gesture(magnificationGesture)
                #if os(macOS)
                .background(ScrollWheelHandler { scrollImages($0) })
                #endif
        } else if let texture = metalDisplayFrame {
            // GPU display path (GPU_RENDERING_PLAN.md M5). Zoom, pan, rotation, flip
            // and inversion are in the shader's transform, so none of the modifiers
            // below this branch apply — and none of them re-render anything. A tool
            // action costs one redraw of a textured quad.
            MetalImageView(frame: texture, presentation: livePresentation)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(panGesture)
                .gesture(magnificationGesture)
                .accessibilityLabel("DICOM Image")
                .accessibilityValue(viewModel.dimensionsText)
                .accessibilityHint("Drag to pan, or use the windowing/zoom tools to drag-adjust; scroll to step through images")
                #if os(macOS)
                .background(ScrollWheelHandler { scrollImages($0) })
                #endif
        } else if let cgImage = viewModel.currentImage {
            Image(decorative: cgImage, scale: 1.0)
                .resizable()
                // Uses the whole viewport, aspect ratio intact: `.fit` grows the
                // image until one edge meets the cell, so nothing is stretched
                // and nothing is left unnecessarily small.
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(viewModel.zoomLevel * magnifyBy)
                .offset(
                    x: viewModel.panOffsetX + dragOffset.width,
                    y: viewModel.panOffsetY + dragOffset.height
                )
                .rotationEffect(.degrees(viewModel.rotationAngle))
                .scaleEffect(
                    x: viewModel.isFlippedHorizontal ? -1 : 1,
                    y: viewModel.isFlippedVertical   ? -1 : 1
                )
                .gesture(panGesture)
                .gesture(magnificationGesture)
                .accessibilityLabel("DICOM Image")
                .accessibilityValue(viewModel.dimensionsText)
                .accessibilityHint("Drag to pan, or use the windowing/zoom tools to drag-adjust; scroll to step through images")
                #if os(macOS)
                .background(ScrollWheelHandler { scrollImages($0) })
                #endif
        } else {
            Text("Unable to render image")
                .foregroundStyle(.gray)
        }
        #endif
    }

    // MARK: - Gestures

    /// Steps through the series with the scroll wheel.
    ///
    /// Scrolling pages images rather than zooming: on a wheel that is the
    /// reading gesture — walk the stack — and zoom is on the mouse button
    /// (⌘-drag), where it can be held steady. One notch is one image, however
    /// hard the wheel is spun; see ``ScrollStepAccumulator``.
    private func scrollImages(_ delta: ScrollWheelDelta) {
        let steps = scrollSteps.steps(for: delta)
        guard steps != 0 else { return }
        for _ in 0..<abs(steps) {
            // Scrolling up walks back through the stack, as it does in a list.
            if steps > 0 {
                viewModel.navigateToPreviousImage()
            } else {
                viewModel.navigateToNextImage()
            }
        }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                magnifyBy = value.magnification
            }
            .onEnded { value in
                viewModel.zoomLevel = GestureHelpers.clampZoom(
                    viewModel.zoomLevel * value.magnification
                )
                magnifyBy = 1.0
            }
    }

    /// Drag: pans by default, or applies whichever tool is armed.
    ///
    /// A single click still reaches tile focus/selection unaffected — this is
    /// a `DragGesture`, so a tap that never moves resolves as a tap on the
    /// container instead. Dragging up enlarges, as pushing a zoom slider away
    /// from you does.
    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                switch activeTool {
                case .windowing:
                    let dx = Double(value.translation.width - wlDragStart.width)
                    let dy = Double(value.translation.height - wlDragStart.height)
                    viewModel.adjustWindowLevel(deltaX: dx, deltaY: dy)
                    wlDragStart = value.translation
                case .zoom:
                    let dy = Double(value.translation.height - zoomDragStart.height)
                    viewModel.zoomLevel = GestureHelpers.clampZoom(
                        viewModel.zoomLevel * (1.0 - dy * Self.dragZoomSensitivity))
                    zoomDragStart = value.translation
                case nil:
                    dragOffset = value.translation
                }
            }
            .onEnded { value in
                switch activeTool {
                case .windowing:
                    wlDragStart = .zero
                case .zoom:
                    zoomDragStart = .zero
                case nil:
                    viewModel.panOffsetX += value.translation.width
                    viewModel.panOffsetY += value.translation.height
                    dragOffset = .zero
                }
            }
    }

    /// Zoom fraction per point dragged.
    private static let dragZoomSensitivity: Double = 0.005

    // MARK: - Toolbar tool buttons

    /// A toolbar icon for an armable tool (windowing, zoom): tinted while
    /// active, so it's clear at a glance which one a drag will apply.
    @ViewBuilder
    private func toolButton(
        systemImage: String,
        isActive: Bool,
        label: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .help(help)
        .background(
            isActive ? Color.accentColor.opacity(0.25) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .foregroundStyle(isActive ? Color.accentColor : Color.primary)
    }

    // MARK: - Performance Overlay

    private var performanceOverlay: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Render: \(viewModel.renderTimeText)")
            Text("Zoom: \(String(format: "%.0f%%", viewModel.zoomLevel * 100))")
            Text(viewModel.windowLevelText)
        }
        .font(.system(size: StudioTypography.captionSize, design: .monospaced))
        .foregroundStyle(.green)
        .padding(6)
        .background(.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var viewerToolbar: some ToolbarContent {
        // Series navigation — grouped in one item so it doesn't fragment the toolbar
        if viewModel.isInSeries {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 4) {
                    Button {
                        viewModel.navigateToPreviousFile()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!viewModel.canGoPreviousFile)
                    .accessibilityLabel("Previous file in series")
                    .help("Previous file in series (↑)")

                    Text(viewModel.seriesPositionText)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("File \(viewModel.currentFileIndex + 1) of \(viewModel.seriesFiles.count)")

                    Button {
                        viewModel.navigateToNextFile()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!viewModel.canGoNextFile)
                    .accessibilityLabel("Next file in series")
                    .help("Next file in series (↓)")
                }
            }
        }

        // Series pane
        if !viewModel.studySeries.isEmpty {
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.isSeriesPaneVisible.toggle()
                } label: {
                    Image(systemName: viewModel.isSeriesPaneVisible
                          ? "sidebar.left" : "sidebar.leading")
                }
                .keyboardShortcut("s", modifiers: [])
                .accessibilityLabel(viewModel.isSeriesPaneVisible
                                    ? "Hide series list" : "Show series list")
                .help("Show or hide the study's series (S)")
            }
        }

        // Tile layout — the viewer grid, which is also the film grid
        ToolbarItem(placement: .automatic) {
            Menu {
                ForEach(ViewerTileLayout.allCases) { option in
                    Button {
                        viewModel.applyLayout(option)
                    } label: {
                        if option == viewModel.layout {
                            Label(option.displayName, systemImage: "checkmark")
                        } else {
                            Text(option.displayName)
                        }
                    }
                    // The square grids get a digit each — the digit is the side,
                    // so ⌘3 is 3×3. The oblong layouts stay menu-only rather than
                    // taking digits whose number means nothing.
                    .modifier(SquareLayoutShortcut(layout: option))
                }
            } label: {
                Label(viewModel.layout.displayName, systemImage: "square.grid.2x2")
            }
            .disabled(!viewModel.hasImage)
            .accessibilityLabel("Tile layout, currently \(viewModel.layout.displayName)")
            .help("Viewer tile layout — tiles map to film cells in the same order")
        }

        // DICOM print — mark the current frame, then open the print sheet
        ToolbarItemGroup(placement: .automatic) {
            // Clicking marks the image on screen; the menu offers the bulk
            // selections, so "select all" is one click from where marking lives.
            Menu {
                Button("Select All for Print") {
                    viewModel.markLayoutForPrint()
                }
                .disabled(viewModel.isLayoutFullyMarkedForPrint)
                Button("Unselect All for Print") {
                    viewModel.unmarkLayoutForPrint()
                }
                .disabled(!viewModel.isAnyLayoutImageMarkedForPrint)
                if viewModel.isInSeries {
                    Button("Mark Whole Series for Print") {
                        viewModel.markWholeSeriesForPrint()
                    }
                }
                if viewModel.isMultiFrame {
                    Button("Mark All Frames for Print") {
                        viewModel.markAllFramesOfCurrentFileForPrint()
                    }
                }
                if !viewModel.printSelection.isEmpty {
                    Divider()
                    Button("Clear Print Marks", role: .destructive) {
                        viewModel.clearAllPrintMarks()
                    }
                }
            } label: {
                Image(systemName: viewModel.isCurrentFrameMarkedForPrint
                      ? "checkmark.rectangle.stack.fill"
                      : "checkmark.rectangle.stack")
            } primaryAction: {
                viewModel.togglePrintMarkForCurrentFrame()
            }
            .disabled(!viewModel.hasImage)
            .accessibilityLabel(viewModel.isCurrentFrameMarkedForPrint
                                ? "Unmark image for print" : "Mark image for print")
            .help("Mark this image for print (M)")
            .keyboardShortcut("m", modifiers: [])

            Button {
                viewModel.isPrintTrayVisible.toggle()
            } label: {
                Image(systemName: viewModel.isPrintTrayVisible
                      ? "sidebar.trailing" : "sidebar.right")
            }
            .keyboardShortcut("t", modifiers: [])
            .accessibilityLabel(viewModel.isPrintTrayVisible
                                ? "Hide selected images" : "Show selected images")
            .help("Show the images selected for print (T)")

            Button {
                openPrintSheet()
            } label: {
                Image(systemName: "printer")
                    .overlay(alignment: .topTrailing) {
                        if viewModel.printSelection.count > 0 {
                            Text("\(viewModel.printSelection.count)")
                                .font(.system(size: 9).monospacedDigit())
                                .padding(3)
                                .background(.tint, in: Circle())
                                .foregroundStyle(.white)
                                .offset(x: 8, y: -8)
                        }
                    }
            }
            .disabled(viewModel.printSelection.isEmpty)
            .accessibilityLabel("Print marked images")
            .help("Print marked images (⌘P)")
            .keyboardShortcut("p", modifiers: .command)
        }

        // Tools — windowing and zoom are click-and-drag tools, exclusive of
        // each other and highlighted while armed; invert, rotate, flip, fit
        // and reset are one-shot actions. No dropdown: every tool is a single
        // visible icon, in the order windowing, invert, zoom, rotate, flip,
        // fit to view, reset.
        ToolbarItemGroup(placement: .automatic) {
            toolButton(
                systemImage: "slider.horizontal.below.rectangle",
                isActive: activeTool == .windowing,
                label: "Windowing tool",
                help: "Windowing tool — drag on the image to adjust window/level"
            ) {
                activeTool = activeTool == .windowing ? nil : .windowing
            }

            if viewModel.isMonochrome {
                Button {
                    viewModel.toggleInversion()
                } label: {
                    Image(systemName: viewModel.isInverted ? "circle.lefthalf.filled" : "circle.righthalf.filled")
                }
                .accessibilityLabel(viewModel.isInverted ? "Remove inversion" : "Invert grayscale")
                .help(viewModel.isInverted ? "Remove grayscale inversion" : "Invert grayscale")
            }

            toolButton(
                systemImage: "magnifyingglass",
                isActive: activeTool == .zoom,
                label: "Zoom tool",
                help: "Zoom tool — drag on the image to zoom in or out"
            ) {
                activeTool = activeTool == .zoom ? nil : .zoom
            }

            Button { viewModel.rotateClockwise() } label: {
                Image(systemName: "rotate.right")
            }
            .accessibilityLabel("Rotate")
            .help("Rotate 90° clockwise")

            Button { viewModel.flipHorizontal() } label: {
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
            }
            .accessibilityLabel("Flip horizontal")
            .help("Flip horizontally")

            Button { viewModel.flipVertical() } label: {
                Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down")
            }
            .accessibilityLabel("Flip vertical")
            .help("Flip vertically")

            Button {
                viewModel.fitToView(viewWidth: viewSize.width, viewHeight: viewSize.height)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .accessibilityLabel("Fit image to view")
            .help("Fit image to view (F)")
            .keyboardShortcut("f", modifiers: [])

            Button { viewModel.resetView() } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .accessibilityLabel("Reset to original image")
            .help("Reset to original image — undoes zoom, pan, rotation, flip, and windowing (R)")
            .keyboardShortcut("r", modifiers: [])
        }

        // Overlays & Panels menu — collapses toggles and panels into one button
        ToolbarItem(placement: .automatic) {
            Menu {
                Toggle(isOn: Bindable(viewModel).showMetadataOverlay) {
                    Label("Metadata Overlay", systemImage: "info.circle")
                }
                Toggle(isOn: Bindable(viewModel).showPerformanceOverlay) {
                    Label("Performance Overlay", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }
                Divider()
                Toggle(isOn: Bindable(viewModel).showDICOMInspector) {
                    Label("DICOM Tag Inspector", systemImage: "list.bullet.rectangle")
                }
                .disabled(viewModel.dicomFile == nil)
            } label: {
                Image(systemName: "square.stack.3d.up")
            }
            .help("Overlays and panels")
        }

        // The keys, where they can be found.
        ToolbarItem(placement: .automatic) {
            KeyboardShortcutsButton(
                title: "Viewer Shortcuts",
                groups: KeyboardShortcutsLegendView.viewerGroups)
        }
    }
}

// MARK: - Tools

/// A click-and-drag tool armed from the toolbar. `nil` (no case selected)
/// means a plain drag pans; picking one of these has the drag do that instead.
private enum ImageViewerDragTool {
    case windowing
    case zoom
}

// MARK: - Layout shortcuts

/// Gives the square tile grids a digit each: ⌘1 is 1×1, ⌘4 is 4×4.
///
/// A modifier rather than an inline `if`, because `keyboardShortcut` has to be
/// absent — not merely unreachable — on the layouts that get no digit.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
private struct SquareLayoutShortcut: ViewModifier {
    let layout: ViewerTileLayout

    func body(content: Content) -> some View {
        if layout.rows == layout.columns, (1...4).contains(layout.rows),
           let key = KeyEquivalent(exactly: layout.rows) {
            content.keyboardShortcut(key, modifiers: .command)
        } else {
            content
        }
    }
}

private extension KeyEquivalent {
    /// The digit key for a small number, or `nil` if there isn't one.
    init?(exactly number: Int) {
        guard let character = String(number).first else { return nil }
        self.init(character)
    }
}

// MARK: - Print Sheet Host

/// Creates the print state on demand so the sheet works no matter who opened it
/// — the toolbar button, or "Print…" in the library before this view appeared.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
private struct PrintSheetHost: View {
    let selection: PrintSelectionModel
    @Binding var printViewModel: PrintViewModel?
    /// Size of the window the sheet was raised from, when it is known.
    var parentSize: CGSize?

    var body: some View {
        Group {
            if let printViewModel {
                PrintSettingsView(viewModel: printViewModel, parentSize: parentSize)
            } else {
                ProgressView()
                    .frame(minWidth: 480, minHeight: 300)
            }
        }
        .task {
            if printViewModel == nil {
                printViewModel = PrintViewModel(selection: selection)
            } else {
                printViewModel?.selection = selection
                printViewModel?.loadPrinters()
            }
        }
    }
}

#endif
