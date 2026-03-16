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

    // MARK: - Image Content

    @ViewBuilder
    private var imageContent: some View {
        #if canImport(CoreGraphics)
        if let cgImage = viewModel.currentImage {
            Image(decorative: cgImage, scale: 1.0)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(viewModel.zoomLevel * magnifyBy)
                .offset(
                    x: viewModel.panOffsetX + dragOffset.width,
                    y: viewModel.panOffsetY + dragOffset.height
                )
                .rotationEffect(.degrees(viewModel.rotationAngle))
                .gesture(panGesture)
                .gesture(magnificationGesture)
                .accessibilityLabel("DICOM Image")
                .accessibilityValue(viewModel.dimensionsText)
                .accessibilityHint("Use pinch to zoom, drag to pan")
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
                dragOffset = value.translation
            }
            .onEnded { value in
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
        ToolbarItemGroup {
            Button {
                viewModel.isFileImporterPresented = true
            } label: {
                Image(systemName: "folder")
            }
            .accessibilityLabel("Open DICOM file")
            .help("Open a DICOM file (O)")

            Divider()

            // Series navigation — only visible when viewing a multi-file series
            if viewModel.isInSeries {
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

                Divider()
            }

            Button {
                viewModel.zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .accessibilityLabel("Zoom in")
            .help("Zoom in (+)")

            Button {
                viewModel.zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .accessibilityLabel("Zoom out")
            .help("Zoom out (-)")

            Button {
                viewModel.resetView()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .accessibilityLabel("Reset view")
            .help("Reset zoom, pan, and rotation (R)")

            Divider()

            if viewModel.isMonochrome {
                Button {
                    viewModel.toggleInversion()
                } label: {
                    Image(systemName: viewModel.isInverted ? "circle.lefthalf.filled" : "circle.righthalf.filled")
                }
                .accessibilityLabel("Invert grayscale")
                .help("Toggle grayscale inversion (I)")
            }

            Button {
                viewModel.rotateClockwise()
            } label: {
                Image(systemName: "rotate.right")
            }
            .accessibilityLabel("Rotate clockwise")
            .help("Rotate 90° clockwise")

            Divider()

            Toggle(isOn: Bindable(viewModel).showMetadataOverlay) {
                Image(systemName: "info.circle")
            }
            .accessibilityLabel("Toggle metadata overlay")
            .help("Show/hide pixel data metadata")

            Toggle(isOn: Bindable(viewModel).showPerformanceOverlay) {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
            }
            .accessibilityLabel("Toggle performance overlay")
            .help("Show/hide performance metrics")

            Toggle(isOn: Bindable(viewModel).showDICOMInspector) {
                Image(systemName: "list.bullet.rectangle")
            }
            .disabled(viewModel.dicomFile == nil)
            .accessibilityLabel("Toggle DICOM tag inspector")
            .help("Show/hide DICOM tag inspector")
        }
    }
}
#endif
