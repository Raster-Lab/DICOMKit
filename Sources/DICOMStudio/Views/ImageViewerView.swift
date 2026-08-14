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

    /// The pointer's bearing around the picture's centre at the previous step of a
    /// rotate-tool drag, or `nil` before the drag has left the dead zone at the
    /// centre. Held so each step turns the image by the arc just swept.
    @State private var rotateDragBearing: Double?

    /// Size of the view the drag tools are attached to — the whole reading area at
    /// 1×1, one tile in a grid. Its centre is the pivot a rotate drag turns about,
    /// which is why this is measured separately from ``viewSize``.
    @State private var toolSpaceSize: CGSize = .zero

    /// Where the pointer is over the image area, or `nil` when it has left.
    @State private var hoverPoint: CGPoint?

    /// The click-and-drag tool currently armed. Pan is the resting state.
    ///
    /// The tools are mutually exclusive: picking one arms it and disarms the
    /// others, and the toolbar highlights whichever is active. Pressing an armed
    /// tool's own button or key again drops back to pan, as does escape.
    @State private var activeTool: ImageViewerDragTool = .pan

    /// True while a pan drag is actually in progress, so the pointer can show
    /// the closed hand for exactly as long as the image is being carried.
    @State private var isPanDragging = false

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
    /// Three columns on three planes, not three panels of equal weight. The panes
    /// are the lightest surface and each is titled; the gutter between them is
    /// the darkest chrome; and the reading area is pure black, framed, titled and
    /// lifted off its mount by a shadow. That is the habit a reporting station
    /// trains — the darkest, quietest rectangle is the one being read, and here
    /// it is also the one whose title strip says how much of it prints.
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
        // No dividers of their own: each pane carries a seam on the side facing
        // the picture, which is one edge rather than the two a shared hairline
        // and a framed light box would put next to each other.
        .background(StudioColors.viewerChrome)
    }

    /// The image, titled, framed and inset into the chrome.
    ///
    /// The title strip is what makes this column the reading area rather than a
    /// third panel of the same weight: it names the surface, says how it is laid
    /// out, and reports how much of what is on it is going to print — the one
    /// question the three identical dark columns could not answer between them.
    private var readingArea: some View {
        VStack(spacing: 0) {
            readingAreaHeader

            imageArea
                .background(Color.black)
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.readingAreaCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Self.readingAreaCornerRadius)
                .strokeBorder(readingAreaBorderColor, lineWidth: Self.readingAreaBorderWidth)
        }
        // A cast shadow lifts the reading area off its mount, so the middle
        // column reads as the thing in front and the panes as what flanks it.
        .shadow(color: .black.opacity(0.55), radius: 6, y: 1)
        .padding(Self.readingAreaGutter)
    }

    /// Names the reading area and reports what of it is on the film.
    private var readingAreaHeader: some View {
        let marked = viewModel.layoutMarkedForPrintCount
        let total = viewModel.layoutImageCount
        return HStack(spacing: 8) {
            Image(systemName: "viewfinder")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))

            Text("READING AREA")
                .font(.caption2.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.85))

            if viewModel.hasImage {
                Text(viewModel.layout.displayName)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 4)

            // The count is the point of the strip, so it is a lit chip rather
            // than another line of grey: at a glance, this column prints.
            if viewModel.hasImage {
                HStack(spacing: 4) {
                    Image(systemName: marked > 0 ? "printer.fill" : "printer")
                        .font(.caption2)
                    Text(marked > 0 ? "\(marked) of \(total) on film" : "none on film")
                        .font(.caption2.monospacedDigit().weight(.medium))
                }
                .foregroundStyle(marked > 0 ? Color.accentColor : .white.opacity(0.5))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    marked > 0 ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.06),
                    in: Capsule())
                .accessibilityLabel(marked > 0
                                    ? "\(marked) of \(total) images on screen are marked for print"
                                    : "No images on screen are marked for print")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: ViewerPaneMetrics.headerHeight)
        .background(readingAreaHeaderFill)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(height: 1)
        }
    }

    /// The strip's own surface — accent-washed while the keyboard is here, so
    /// the column that the arrow keys and the tools will act on is lit at the
    /// top as well as ringed at the edge.
    private var readingAreaHeaderFill: Color {
        isImageAreaFocused && viewModel.hasImage
            ? Color.accentColor.opacity(0.28)
            : StudioColors.viewerPanelHeader
    }

    /// The frame around the reading area.
    ///
    /// Neutral while the viewer is idle; picking up the accent once the image
    /// area holds the keyboard, which is what says the arrow keys will walk this
    /// stack. It stays on in a grid too — the ring says which *column* is live,
    /// the tile's own ring says which tile inside it is, and losing the outer one
    /// was what left the three columns looking alike.
    private var readingAreaBorderColor: Color {
        guard isImageAreaFocused, viewModel.hasImage else {
            return StudioColors.readingAreaBorder
        }
        return Color.accentColor.opacity(0.55)
    }

    /// Thicker than a hairline: this is the edge of the working surface, and at
    /// one point it disappeared against the mount from a normal seating distance.
    private static let readingAreaBorderWidth: CGFloat = 1.5

    /// Width of the selection tray — a legible thumbnail and two lines of label.
    private static let printTrayWidth: CGFloat = 180

    /// Width of the series pane — enough for a legible thumbnail and two lines
    /// of series description.
    private static let seriesPaneWidth: CGFloat = 190

    /// Room the print checkbox takes in the top-right corner, which the
    /// identification block starts below.
    private static let printCheckboxInset: CGFloat = 34

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
                        Button(viewModel.showImageAnnotations
                               ? "Hide Image Annotations" : "Show Image Annotations") {
                            viewModel.showImageAnnotations.toggle()
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
                        // "Unselect all" takes every mark off, not only the ones
                        // the layout happens to be showing: marks are made while
                        // scrolling a series, so a screen-scoped unselect leaves
                        // most of the film behind and reads as doing nothing.
                        Button("Unselect All for Print") {
                            viewModel.clearAllPrintMarks()
                        }
                        .disabled(viewModel.printSelection.isEmpty)
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
        .background(toolShortcuts)
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
        // Reading annotations in the four corners, over the picture. In a grid
        // each tile draws its own, so this one is the 1×1 case only.
        .overlay {
            // Images only: a report or a document is not a picture, and a block
            // of corner annotation over a page of text obscures the text.
            if viewModel.showImageAnnotations && viewModel.hasImage
                && !viewModel.isWaveform && !viewModel.isNonImageContent
                && !viewModel.isMultiCellLayout {
                ViewerAnnotationOverlayView(
                    text: viewModel.annotationText,
                    state: viewModel.annotationViewportState(
                        viewSize: viewSize, cursor: cursorReadout),
                    cellSize: viewSize,
                    // Clears the print checkbox in the same corner.
                    topTrailingInset: Self.printCheckboxInset
                )
            }
        }
        // The pointer's position over the picture, for the pixel and patient
        // coordinates in the top-left block. Tracked on the image area rather
        // than on the image itself: the image is transformed by zoom, pan and
        // rotation, so a point in *its* space is already past the mapping the
        // readout exists to perform, whereas the image area is the viewport the
        // transforms are defined against.
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active(let point): hoverPoint = point
            case .ended: hoverPoint = nil
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
        // The pointer, last of all — and this position is the whole trick.
        //
        // A cursor rect belongs to the topmost view under the pointer, and the
        // reading area is covered by things that sit above the picture: the
        // `contentShape(Rectangle())` that carries the context menu, the
        // continuous-hover reader behind the coordinate readout, the annotation
        // and cine overlays. Attached to the image itself this layer is under
        // all of them, so AppKit asks one of *them* what shape to use and gets
        // the arrow. Attached here it is above them, over the whole area every
        // one of those covers, and the tool's shape is the one that shows.
        //
        // Deaf to the mouse, so none of what it covers stops working.
        .overlay(toolCursorLayer)
        .toolbar {
            viewerToolbar
        }
        // On macOS this opens the print window; elsewhere it raises the sheet.
        // Either way `isPrintSheetPresented` is the request, and the preparation
        // below runs first — the request also arrives from the library
        // ("Print…"), which fires before this view has ever appeared.
        .modifier(
            PrintScreenPresenter(isRequested: $viewModel.isPrintSheetPresented,
                                 prepare: preparePrintScreen) {
                // Hosted rather than inlined: the print state has to be created
                // by the sheet itself when the request came from the library.
                PrintSheetHost(
                    selection: viewModel.printSelection,
                    printViewModel: $printViewModel,
                    parentSize: parentWindowSize
                )
            })
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

    /// Asks for the print screen. What that raises — a window on macOS, a sheet
    /// elsewhere — is `PrintScreenPresenter`'s business, and so is preparing the
    /// print state, since the same request also comes from the library.
    private func openPrintSheet() {
        viewModel.isPrintSheetPresented = true
    }

    /// Brings the print state in line with the viewer, just before the print
    /// screen reads it. Idempotent: the request can arrive more than once.
    private func preparePrintScreen() {
        // The screen is about to read the marks, so bring them up to date with
        // what is actually on screen — the user has usually kept arranging since
        // ticking the boxes.
        viewModel.refreshMarksFromViewer()

        // Film order follows the grid, so the preview reads like the screen.
        viewModel.syncPrintOrderToViewer()

        // Captured before the sheet exists, while the key window is still the
        // viewer's: the sheet opens at the size of the screen it came from. The
        // window sizes itself, so this only matters off macOS.
        #if canImport(AppKit)
        parentWindowSize = NSApplication.shared.keyWindow?.frame.size
        #endif

        if printViewModel == nil {
            printViewModel = PrintViewModel(selection: viewModel.printSelection)
        } else {
            // The screen is kept alive so reopening it is instant, but the film
            // it is holding describes the last set of marks. Opening it again is
            // opening it on what is ticked *now* — so the range, the drawn
            // annotations and the picked cells go, while the printer and the
            // film settings stay.
            printViewModel?.resetForNewFilm()
            // Printers may have been added since it was last open.
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
        // The console is cleared by the reset above, so the preview reads like a
        // fresh log each time it is opened rather than a running transcript.
    }

    // MARK: - Cursor readout

    /// The pixel under the pointer, with the in-flight gesture folded in.
    ///
    /// A pan drag moves the picture continuously and only commits on release, so
    /// the readout has to be mapped through the arrangement *on screen* — the
    /// committed one would name the pixel that was under the cursor before the
    /// drag began, which is the one place a stale number would look plausible.
    private var cursorReadout: ViewerCursorReadout? {
        guard let hoverPoint else { return nil }
        return viewModel.cursorReadout(
            atViewPoint: hoverPoint,
            viewSize: viewSize,
            zoom: viewModel.zoomLevel * Double(magnifyBy),
            panX: viewModel.panOffsetX + Double(dragOffset.width),
            panY: viewModel.panOffsetY + Double(dragOffset.height))
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
                .background(toolSpaceReader)
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
                .background(toolSpaceReader)
                .gesture(panGesture)
                .gesture(magnificationGesture)
                .accessibilityLabel("DICOM Image")
                .accessibilityValue(viewModel.dimensionsText)
                .accessibilityHint(imageAccessibilityHint)
                #if os(macOS)
                .background(ScrollWheelHandler { scrollImages($0) })
                #endif
        } else if let cgImage = viewModel.currentImage {
            // CPU fallback path. The transforms go on the picture and the gestures
            // on the container around it — a `DragGesture` reports its locations in
            // the space of the view it is attached to, so hanging it off the rotated,
            // flipped image would have the rotate tool measuring the pointer in a
            // frame that turns with the drag (half speed, and backwards under a flip).
            // The container never moves, so its space is the screen's.
            ZStack {
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
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Keeps the whole viewport draggable, letterbox included, as the
                // image's own frame did before it was wrapped.
                .contentShape(Rectangle())
                .background(toolSpaceReader)
                .gesture(panGesture)
                .gesture(magnificationGesture)
                .accessibilityLabel("DICOM Image")
                .accessibilityValue(viewModel.dimensionsText)
                .accessibilityHint(imageAccessibilityHint)
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
                case .rotate:
                    rotateByDrag(to: value.location)
                case .pan:
                    isPanDragging = true
                    dragOffset = value.translation
                }
            }
            .onEnded { value in
                switch activeTool {
                case .windowing:
                    wlDragStart = .zero
                case .zoom:
                    zoomDragStart = .zero
                case .rotate:
                    rotateByDrag(to: value.location)
                    rotateDragBearing = nil
                case .pan:
                    viewModel.panOffsetX += value.translation.width
                    viewModel.panOffsetY += value.translation.height
                    dragOffset = .zero
                    isPanDragging = false
                }
            }
    }

    /// Zoom fraction per point dragged.
    private static let dragZoomSensitivity: Double = 0.005

    /// What a drag will do right now, spoken.
    ///
    /// The pointer's shape carries this for a sighted reader; the hint is the
    /// same fact for one using VoiceOver, which is why it names the armed tool
    /// rather than listing every tool that could be armed.
    private var imageAccessibilityHint: String {
        "\(activeTool.displayName) tool armed. \(activeTool.guidance) "
        + "Press W, Z, E or H to change tool; scroll to step through images."
    }

    /// Sets the pointer's shape over the reading area to match the armed tool.
    ///
    /// Only once there is a picture: over an empty viewer none of the tools has
    /// anything to act on, and a magnifier over it promises otherwise.
    ///
    /// The pointer's shape for the armed tool.
    ///
    /// Applied as the outermost overlay of the whole image area rather than on
    /// the picture — see the call site for why that position is load-bearing.
    /// `allowsHitTesting(false)` is what stops it swallowing the drags, clicks
    /// and right-clicks of everything it now covers.
    @ViewBuilder
    private var toolCursorLayer: some View {
        #if os(macOS)
        // The closed hand for as long as the image is being carried, the tool's
        // own shape the rest of the time — the same before/during distinction
        // the film preview makes.
        ToolCursor(cursor: viewModel.hasImage
                   ? (isPanDragging ? NSCursor.closedHand : activeTool.cursor)
                   : nil)
            .allowsHitTesting(false)
        #else
        Color.clear
        #endif
    }

    /// The keys that arm each tool, and the one-shot actions beside them.
    ///
    /// Zero-sized buttons behind the image: the toolbar's own buttons could
    /// carry these, but the flip and invert icons come and go with the image's
    /// photometric interpretation, and a key that disappears with its button is
    /// worse than no key. Delivered wherever the viewer is, like the film's.
    private var toolShortcuts: some View {
        ZStack {
            ForEach(ImageViewerDragTool.allCases) { tool in
                Button("") { arm(tool) }
                    .keyboardShortcut(KeyEquivalent(tool.shortcut), modifiers: [])
            }

            // No escape key here. Escape is how the inspector sheet, the print
            // sheet and the ⌘/ popover are dismissed, and a second always-live
            // claim on it risks the reader's way out of a modal to save them
            // pressing H. H is the way back to pan.

            // Guarded in the action rather than by `.disabled`: inversion is
            // meaningless on a colour image, and doing the check here means the
            // key is simply inert there instead of depending on whether a
            // disabled button forgoes its shortcut or swallows it.
            Button("") {
                guard viewModel.isMonochrome else { return }
                viewModel.toggleInversion()
            }
            .keyboardShortcut("v", modifiers: [])

            // The bracket pair reads as the two mirror axes: [ lays the image
            // over left-to-right, ] over top-to-bottom.
            Button("") { viewModel.flipHorizontal() }
                .keyboardShortcut("[", modifiers: [])
            Button("") { viewModel.flipVertical() }
                .keyboardShortcut("]", modifiers: [])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    /// Arms a tool, or drops back to pan if it was already armed.
    ///
    /// Pan itself is the resting state, so pressing it twice cannot leave the
    /// viewer with nothing armed.
    private func arm(_ tool: ImageViewerDragTool) {
        activeTool = (activeTool == tool) ? .pan : tool
    }

    /// Measures the space a drag reports its locations in, so the rotate tool knows
    /// where the centre of the picture it is turning actually is.
    private var toolSpaceReader: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { toolSpaceSize = geo.size }
                .onChange(of: geo.size) { _, newSize in toolSpaceSize = newSize }
        }
    }

    /// Turns the image by the arc the pointer just swept around the picture's centre.
    ///
    /// The pointer is a handle on the picture: drag round clockwise and it follows
    /// clockwise, drag back and it unwinds, all the way through the full circle in
    /// either direction with no quarter-turn snapping. Deltas rather than absolutes,
    /// so the picture keeps whatever angle it already had and the drag can start
    /// anywhere on the image.
    ///
    /// Near the centre the bearing is noise — a pixel of jitter there swings it
    /// wildly — so ``GestureHelpers/dragBearing(x:y:pivotX:pivotY:minimumRadius:)``
    /// stays silent until the pointer is far enough out, and the first bearing after
    /// that only anchors the drag.
    private func rotateByDrag(to location: CGPoint) {
        let space = toolSpaceSize == .zero ? viewSize : toolSpaceSize
        guard space.width > 0, space.height > 0 else { return }
        guard let bearing = GestureHelpers.dragBearing(
            x: Double(location.x),
            y: Double(location.y),
            pivotX: Double(space.width) / 2,
            pivotY: Double(space.height) / 2
        ) else { return }
        defer { rotateDragBearing = bearing }
        guard let previous = rotateDragBearing else { return }
        viewModel.rotate(byDegrees: GestureHelpers.shortestAngleDelta(
            from: previous, to: bearing))
    }

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

    /// Everything the print menu's items read, rolled into one identity.
    ///
    /// The two flags are the ones that grey an item out; the other two decide
    /// whether an item is in the menu at all. Any of them changing has to give
    /// the toolbar a menu it has not built before — see the `.id` that uses it.
    private var printMenuIdentity: String {
        let marked = viewModel.printSelection.count
        let full = viewModel.isLayoutFullyMarkedForPrint
        return "\(marked)|\(full)|\(viewModel.isInSeries)|\(viewModel.isMultiFrame)"
    }

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
                .help("Series pane (S) — every series in the study; drag one onto a tile to load it")
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
            .help("Tile layout (⌘1–⌘4 for 1×1 to 4×4) — splits the reading area into tiles; "
                  + "they map to film cells in the same order")
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
                // Every mark comes off, wherever it was made — see the same item
                // in the image's context menu.
                Button("Unselect All for Print") {
                    viewModel.clearAllPrintMarks()
                }
                .disabled(viewModel.printSelection.isEmpty)
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
            } label: {
                Image(systemName: viewModel.isCurrentFrameMarkedForPrint
                      ? "checkmark.rectangle.stack.fill"
                      : "checkmark.rectangle.stack")
            } primaryAction: {
                viewModel.togglePrintMarkForCurrentFrame()
            }
            // A new menu whenever anything the items above read has changed.
            //
            // Not decoration: a toolbar `Menu` with a `primaryAction` is bridged
            // to an AppKit menu that is built once and then re-used, so the
            // items keep the enabled state they were *born* with. The menu is
            // first built with an empty film, and "Unselect All for Print" then
            // stayed greyed out with four images on the film — while the printer
            // button beside it, reading the same `printSelection.isEmpty` from
            // the same body, was correctly live. Changing the identity is what
            // makes SwiftUI build a fresh menu rather than hand back the stale
            // one; it also covers the two items that come and go below.
            .id(printMenuIdentity)
            .disabled(!viewModel.hasImage)
            .accessibilityLabel(viewModel.isCurrentFrameMarkedForPrint
                                ? "Unmark image for print" : "Mark image for print")
            .help("Mark this image for print (M) — click to mark the image on screen; "
                  + "the menu marks a whole series or every frame at once")
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
            .help("Selected-images tray (T) — the images marked for print, in film order")

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
            .help("Print marked images (⌘P) — opens the print sheet with everything marked, "
                  + "laid onto film")
            .keyboardShortcut("p", modifiers: .command)
        }

        // Tools — pan, windowing, zoom and rotate are click-and-drag tools,
        // exclusive of each other and highlighted while armed; invert, flip, fit
        // and reset are one-shot actions. Quarter turns stay in the Image menu
        // and the image's context menu, for when an exact 90° is what's wanted —
        // the toolbar icon arms the free-turn drag. No dropdown: every tool is a
        // single visible icon, and every one of them has a key.
        ToolbarItemGroup(placement: .automatic) {
            // The drag tools, in the order pan, windowing, zoom, rotate. Built
            // from the enum so the icon, the tooltip and the key can only ever
            // describe the tool the button actually arms.
            ForEach(ImageViewerDragTool.allCases) { tool in
                toolButton(
                    systemImage: tool.symbolName,
                    isActive: activeTool == tool,
                    label: "\(tool.displayName) tool",
                    help: tool.help
                ) {
                    arm(tool)
                }
            }

            if viewModel.isMonochrome {
                // The square of the half-filled pair the windowing circle comes
                // from, so the two never read alike.
                Button {
                    viewModel.toggleInversion()
                } label: {
                    Image(systemName: viewModel.isInverted
                          ? "square.lefthalf.filled" : "square.righthalf.filled")
                }
                .accessibilityLabel(viewModel.isInverted ? "Remove inversion" : "Invert grayscale")
                // The key lives on the hidden button in `toolShortcuts`, not
                // here: this button is only on the toolbar for monochrome
                // images, and a key that vanishes with its button is worse than
                // one that is always delivered. Same for the two flips below.
                .help(viewModel.isInverted
                      ? "Remove grayscale inversion (V) — back to black-on-white as stored"
                      : "Invert grayscale (V) — swaps black and white, as on a lightbox")
            }

            Button { viewModel.flipHorizontal() } label: {
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
            }
            .accessibilityLabel("Flip horizontal")
            .help("Flip horizontally ([) — mirrors left to right; laterality markers move with it")

            Button { viewModel.flipVertical() } label: {
                Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down")
            }
            .accessibilityLabel("Flip vertical")
            .help("Flip vertically (]) — mirrors top to bottom")

            Button {
                viewModel.fitToView(viewWidth: viewSize.width, viewHeight: viewSize.height)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .accessibilityLabel("Fit image to view")
            .help("Fit image to view (F) — sizes it so the whole picture is on screen, and re-centres it")
            .keyboardShortcut("f", modifiers: [])

            Button { viewModel.resetView() } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .accessibilityLabel("Reset to original image")
            .help("Reset to original image (R) — undoes zoom, pan, rotation, flip, and windowing")
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
            .help("Overlays and panels — patient and study text over the picture, "
                  + "render timings, and the DICOM tag inspector")
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

/// A click-and-drag tool armed from the toolbar.
///
/// `.pan` is the resting state — a drag with nothing else armed moves the
/// picture — so it is a case here rather than the `nil` it used to be. Making
/// it a case is what lets it carry a key, an icon and a pointer shape like the
/// rest, and lets the toolbar show that *something* is always armed.
///
/// Each case carries its own name, icon, key and one-line guide. Tooltips, the
/// hidden shortcut buttons and the ⌘/ legend are all built from these, so the
/// three cannot drift apart the way a hand-copied list does.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
enum ImageViewerDragTool: String, CaseIterable, Identifiable {
    case pan
    case windowing
    case zoom
    case rotate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pan:       return "Pan"
        case .windowing: return "Window/Level"
        case .zoom:      return "Zoom"
        case .rotate:    return "Rotate"
        }
    }

    var symbolName: String {
        switch self {
        case .pan:       return "hand.draw"
        case .windowing: return "circle.lefthalf.filled"
        case .zoom:      return "magnifyingglass"
        // A closed circle of arrows, not a quarter-turn glyph: this tool turns
        // the picture the whole way round, either way, and a "90°" icon
        // promises the quarter turns that live in the Image menu.
        case .rotate:    return "arrow.triangle.2.circlepath"
        }
    }

    /// The key that arms it, with no modifier.
    ///
    /// R is the viewer's reset and T its print tray, so rotate takes E — the
    /// letter is arbitrary either way, and a key that already does something
    /// else is worse than one that has to be learnt.
    var shortcut: Character {
        switch self {
        case .pan:       return "h"
        case .windowing: return "w"
        case .zoom:      return "z"
        case .rotate:    return "e"
        }
    }

    /// What a drag does with this armed — the tooltip's second line, and the
    /// whole of the tool's entry in the shortcut legend.
    var guidance: String {
        switch self {
        case .pan:
            return "Drag to move the image inside the tile."
        case .windowing:
            return "Drag across for window width, up and down for level — "
                 + "left/right widens or narrows the greys, up/down brightens or darkens."
        case .zoom:
            return "Drag up to enlarge, down to shrink. Pinch or scroll-with-⌘ does the same."
        case .rotate:
            return "Drag around the centre of the picture and it follows the pointer, "
                 + "either way, through the full circle."
        }
    }

    /// Tooltip text: what it is, what the key is, and how to use it.
    var help: String {
        "\(displayName) (\(String(shortcut).uppercased())) — \(guidance)"
    }

    #if os(macOS)
    /// The pointer's shape while this tool is armed.
    ///
    /// The toolbar says which tool is armed, but the toolbar is at the top of
    /// the window and the hand is on the picture — and the cost of being wrong
    /// is a drag that has already windowed an image you meant to pan. The
    /// pointer is the one part of the screen guaranteed to be where the reader
    /// is looking when the drag starts, which is what makes it worth changing.
    var cursor: NSCursor {
        switch self {
        case .pan:
            // The open hand, not the closed one: closed says "you are dragging
            // now", and this is the shape shown before the drag begins.
            return .openHand
        case .windowing:
            // No system cursor means "windowing", so this borrows the one the
            // gesture actually is — the drag runs in both axes.
            return .crosshair
        case .zoom:
            return .zoomIn
        case .rotate:
            return .crosshair
        }
    }
    #endif
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

// MARK: - Print Screen Presenter

/// Raises the print screen when the viewer asks for it.
///
/// On macOS that is a window of its own (`StudioWindowID.printPreview`), so the
/// film can be held up against the images it was made from — a sheet covers
/// exactly the thing being compared, and only one screen can be looked at at a
/// time. Everywhere else there are no windows to open, so it stays a sheet.
///
/// The request is a flag rather than a call because it also arrives from the
/// library's "Print…", which fires while the viewer is still being built —
/// hence `onAppear` as well as `onChange`.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
private struct PrintScreenPresenter<SheetContent: View>: ViewModifier {
    @Binding var isRequested: Bool
    let prepare: () -> Void
    @ViewBuilder let sheetContent: () -> SheetContent

    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .onAppear { if isRequested { present() } }
            .onChange(of: isRequested) { _, requested in
                if requested { present() }
            }
        #else
        content
            .onChange(of: isRequested) { _, requested in
                if requested { prepare() }
            }
            .sheet(isPresented: $isRequested) { sheetContent() }
        #endif
    }

    #if os(macOS)
    /// Prepares the print state, then raises the window — and lowers the flag,
    /// which is a request, not the window's state. Leaving it raised would make
    /// the next request no change at all, and nothing would happen.
    private func present() {
        prepare()
        openWindow(id: StudioWindowID.printPreview)
        isRequested = false
    }
    #endif
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
                // A different set of marks than the one the held film was built
                // from — the range, the drawn annotations and the picked cells
                // all describe images that are no longer on it.
                printViewModel?.selection = selection
                printViewModel?.resetForNewFilm()
                printViewModel?.loadPrinters()
            }
        }
    }
}

#endif
