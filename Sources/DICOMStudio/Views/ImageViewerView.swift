// ImageViewerView.swift
// DICOMStudio
//
// DICOM Studio — Main image viewer view

#if canImport(SwiftUI)
import SwiftUI
import UniformTypeIdentifiers

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

    public init(viewModel: ImageViewerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("Loading…")
                    .foregroundStyle(.white)
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
                imageContent
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
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        viewSize = geo.size
                        viewModel.viewContentWidth = geo.size.width
                        viewModel.viewContentHeight = geo.size.height
                    }
                    .onChange(of: geo.size) { _, newSize in
                        viewSize = newSize
                        viewModel.viewContentWidth = newSize.width
                        viewModel.viewContentHeight = newSize.height
                    }
            }
        )
        .focusedValue(\.imageViewerViewModel, viewModel)
        .overlay(alignment: .bottomLeading) {
            if viewModel.showMetadataOverlay && viewModel.hasImage {
                ImageMetadataOverlayView(viewModel: viewModel)
                    .padding(8)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel.showPerformanceOverlay && viewModel.hasImage {
                performanceOverlay
                    .padding(8)
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isMultiFrame && viewModel.hasImage {
                CineControlsView(viewModel: viewModel)
                    .padding(.bottom, 40)
            }
        }
        .toolbar {
            viewerToolbar
        }
        .sheet(isPresented: $viewModel.showDICOMInspector) {
            DICOMInspectorView(viewModel: viewModel)
        }
        .sheet(isPresented: Bindable(viewModel).showJ2KTesting) {
            J2KTestingView(viewModel: viewModel)
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
                    .help("Previous file in series")

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
                    .help("Next file in series")
                }
            }
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
                Divider()
                Button {
                    viewModel.showJ2KTesting = true
                } label: {
                    Label("J2KSwift Testing…", systemImage: "staroflife.circle")
                }
            } label: {
                Image(systemName: "square.stack.3d.up")
            }
            .help("Overlays and panels")
        }
    }
}

// MARK: - Scroll Wheel Zoom (macOS)

#if os(macOS)
/// Zero-size NSView that installs a local NSEvent monitor for scroll-wheel events.
///
/// The monitor only forwards events whose hit-test location is inside this
/// view's own bounds *and* whose target window matches. This prevents scroll
/// gestures over modal sheets (e.g. the DICOM Inspector) from being
/// interpreted as image-zoom events.
private struct ScrollWheelHandler: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.targetView = view
        context.coordinator.onScroll = onScroll
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak coordinator = context.coordinator] event in
            guard let coordinator else { return event }
            guard let target = coordinator.targetView,
                  let window = target.window,
                  event.window === window
            else {
                return event
            }
            // Reject events when a sheet/modal is in front of our window.
            if window.attachedSheet != nil { return event }
            // Convert to the target view's local coordinates and ignore events
            // that are not directly over the image area.
            let pointInWindow = event.locationInWindow
            let pointInView = target.convert(pointInWindow, from: nil)
            guard target.bounds.contains(pointInView) else { return event }
            // Also confirm the actual hit-tested view belongs to our subtree;
            // this rejects scrolls that land on overlapping siblings (lists,
            // popovers attached to the same window, etc.).
            if let hit = window.contentView?.hitTest(pointInWindow),
               hit !== target,
               !hit.isDescendant(of: target),
               !target.isDescendant(of: hit) {
                return event
            }
            coordinator.onScroll?(event.deltaY)
            return event
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onScroll = onScroll
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var monitor: Any?
        weak var targetView: NSView?
        var onScroll: ((CGFloat) -> Void)?
        deinit {
            if let m = monitor { NSEvent.removeMonitor(m) }
        }
    }
}
#endif

#endif
