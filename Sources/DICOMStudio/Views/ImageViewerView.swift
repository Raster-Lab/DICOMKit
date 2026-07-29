// ImageViewerView.swift
// DICOMStudio
//
// DICOM Studio — Main image viewer view

#if canImport(SwiftUI)
import SwiftUI
import UniformTypeIdentifiers
import DICOMNetwork
import DICOMPrintKit

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

    public var body: some View {
        HStack(spacing: 0) {
            // The study's series, when the viewer was opened from a study. Loose
            // files have no series to list, so the pane stays out of the way.
            if viewModel.isSeriesPaneVisible && !viewModel.studySeries.isEmpty {
                ViewerSeriesPaneView(viewModel: viewModel)
                    .frame(width: Self.seriesPaneWidth)
                Divider()
            }
            imageArea
        }
    }

    /// Width of the series pane — enough for a legible thumbnail and two lines
    /// of series description.
    private static let seriesPaneWidth: CGFloat = 190

    private var imageArea: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("Loading…")
                    .foregroundStyle(.white)
            } else if let waveform = viewModel.waveform {
                WaveformChartView(waveform: waveform)
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
                        if viewModel.isMultiCellLayout {
                            Button("Mark All Tiles for Print") {
                                viewModel.markLayoutForPrint()
                            }
                        }
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
                    Text("Open a DICOM file to view it here")
                        .font(.caption)
                        .foregroundStyle(.gray.opacity(0.7))
                    Button {
                        viewModel.isFileImporterPresented = true
                    } label: {
                        Label("Open DICOM File", systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                    .accessibilityHint("Opens a file picker to select a DICOM file")
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
        .fileImporter(
            isPresented: $viewModel.isFileImporterPresented,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.loadFile(from: url)
                }
            case .failure(let error):
                viewModel.errorMessage = "Failed to open file: \(error.localizedDescription)"
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

        viewModel.isPrintSheetPresented = true
    }

    // MARK: - Image Content

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
                .background(ScrollWheelHandler { delta in
                    viewModel.zoomLevel = GestureHelpers.zoomFromScrollDelta(
                        currentZoom: viewModel.zoomLevel,
                        scrollDelta: delta
                    )
                })
                #endif
        } else if let cgImage = viewModel.currentImage {
            Image(decorative: cgImage, scale: 1.0)
                .resizable()
                .aspectRatio(contentMode: .fit)
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
                .accessibilityHint("Use pinch to zoom, drag to pan")
                #if os(macOS)
                .background(ScrollWheelHandler { delta in
                    viewModel.zoomLevel = GestureHelpers.zoomFromScrollDelta(
                        currentZoom: viewModel.zoomLevel,
                        scrollDelta: delta
                    )
                })
                #endif
        } else {
            Text("Unable to render image")
                .foregroundStyle(.gray)
        }
        #endif
    }

    // MARK: - Gestures

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

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                #if os(macOS)
                if NSEvent.modifierFlags.contains(.option) {
                    let dx = Double(value.translation.width - wlDragStart.width)
                    let dy = Double(value.translation.height - wlDragStart.height)
                    viewModel.adjustWindowLevel(deltaX: dx, deltaY: dy)
                    wlDragStart = value.translation
                    return
                }
                #endif
                dragOffset = value.translation
            }
            .onEnded { value in
                #if os(macOS)
                if NSEvent.modifierFlags.contains(.option) {
                    wlDragStart = .zero
                    return
                }
                #endif
                viewModel.panOffsetX += value.translation.width
                viewModel.panOffsetY += value.translation.height
                dragOffset = .zero
            }
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
        // Open file
        ToolbarItem(placement: .automatic) {
            Button {
                viewModel.isFileImporterPresented = true
            } label: {
                Image(systemName: "folder")
            }
            .accessibilityLabel("Open DICOM file")
            .help("Open a DICOM file (⌘O)")
            .keyboardShortcut("o", modifiers: .command)
        }

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
                .accessibilityLabel(viewModel.isSeriesPaneVisible
                                    ? "Hide series list" : "Show series list")
                .help("Show or hide the study's series")
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
            Button {
                viewModel.togglePrintMarkForCurrentFrame()
            } label: {
                Image(systemName: viewModel.isCurrentFrameMarkedForPrint
                      ? "checkmark.rectangle.stack.fill"
                      : "checkmark.rectangle.stack")
            }
            .disabled(!viewModel.hasImage)
            .accessibilityLabel(viewModel.isCurrentFrameMarkedForPrint
                                ? "Unmark image for print" : "Mark image for print")
            .help("Mark this image for print (M)")
            .keyboardShortcut("m", modifiers: [])

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

        // Zoom / view controls — kept as a group so they stay together if overflow occurs
        ToolbarItemGroup(placement: .automatic) {
            Button { viewModel.zoomIn() } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .accessibilityLabel("Zoom in")
            .help("Zoom in (=)")
            .keyboardShortcut("=", modifiers: [])

            Button { viewModel.zoomOut() } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .accessibilityLabel("Zoom out")
            .help("Zoom out (-)")
            .keyboardShortcut("-", modifiers: [])

            Button { viewModel.resetView() } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .accessibilityLabel("Reset view")
            .help("Reset view (R)")
            .keyboardShortcut("r", modifiers: [])

            Button {
                viewModel.fitToView(viewWidth: viewSize.width, viewHeight: viewSize.height)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .accessibilityLabel("Fit image to view")
            .help("Fit image to view (F)")
            .keyboardShortcut("f", modifiers: [])
        }

        // Transform menu — collapses rotate, flip, and invert into one button
        ToolbarItem(placement: .automatic) {
            Menu {
                if viewModel.isMonochrome {
                    Button {
                        viewModel.toggleInversion()
                    } label: {
                        Label(
                            viewModel.isInverted ? "Remove Inversion" : "Invert Grayscale",
                            systemImage: viewModel.isInverted ? "circle.lefthalf.filled" : "circle.righthalf.filled"
                        )
                    }
                    Divider()
                }
                Button { viewModel.rotateCounterClockwise() } label: {
                    Label("Rotate Counter-Clockwise", systemImage: "rotate.left")
                }
                Button { viewModel.rotateClockwise() } label: {
                    Label("Rotate Clockwise", systemImage: "rotate.right")
                }
                Divider()
                Button { viewModel.flipHorizontal() } label: {
                    Label("Flip Horizontal", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                }
                Button { viewModel.flipVertical() } label: {
                    Label("Flip Vertical", systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                }
                Divider()
                Button { viewModel.resetTransformations() } label: {
                    Label("Reset All Transforms", systemImage: "arrow.counterclockwise.circle")
                }
            } label: {
                Image(systemName: "wand.and.stars")
            }
            .help("Transform — rotate, flip, invert")
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

// MARK: - Scroll Wheel Zoom (macOS)

#if os(macOS)
/// Zero-size NSView that installs a local NSEvent monitor for scroll-wheel events.
///
/// The monitor is application-wide, so it must self-scope: a scroll only zooms the
/// image when the cursor is actually over this view *in the viewer's own window*.
/// Sheets, popovers and other popups are presented in separate windows, so scrolling
/// inside them no longer leaks through and zooms the image behind them.
private struct ScrollWheelHandler: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak view] event in
            guard let view, let window = view.window else { return event }
            // Reject scrolls aimed at a different window (sheet / popover / popup).
            guard let eventWindow = event.window, eventWindow === window else { return event }
            // Only zoom when the cursor is over the image view itself.
            let pointInView = view.convert(event.locationInWindow, from: nil)
            guard view.bounds.contains(pointInView) else { return event }
            onScroll(event.deltaY)
            return event
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var monitor: Any?
        deinit {
            if let m = monitor { NSEvent.removeMonitor(m) }
        }
    }
}
#endif

#endif
