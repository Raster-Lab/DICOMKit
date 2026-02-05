// ViewerContainerView.swift
// DICOMViewer iOS - Viewer Container View
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import SwiftUI
import SwiftData

/// Container view for the DICOM image viewer
struct ViewerContainerView: View {
    let study: DICOMStudy
    @State private var viewModel = ViewerViewModel()
    @State private var selectedSeries: DICOMSeries?
    @State private var showingSeriesPicker = false
    @State private var showingMetadata = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main image viewer
            ImageViewerView(viewModel: viewModel)
            
            // Bottom controls
            ViewerControlBar(viewModel: viewModel)
        }
        .navigationTitle(viewModel.patientName ?? study.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Series picker
                Button {
                    showingSeriesPicker = true
                } label: {
                    Label("Series", systemImage: "rectangle.stack")
                }
                
                // Metadata
                Button {
                    showingMetadata = true
                } label: {
                    Label("Info", systemImage: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showingSeriesPicker) {
            SeriesPickerView(
                study: study,
                selectedSeries: $selectedSeries,
                onSelect: { series in
                    selectedSeries = series
                    showingSeriesPicker = false
                    Task { await viewModel.loadSeries(series) }
                }
            )
        }
        .sheet(isPresented: $showingMetadata) {
            MetadataView(study: study, series: selectedSeries)
        }
        .task {
            // Load first series
            if let series = study.series?.first {
                selectedSeries = series
                await viewModel.loadSeries(series)
            }
        }
    }
}

/// Main image viewer view
struct ImageViewerView: View {
    @Bindable var viewModel: ViewerViewModel
    
    // Gesture states
    @State private var lastScale: CGFloat = 1.0
    @State private var lastPanOffset: CGSize = .zero
    @GestureState private var magnifyState: CGFloat = 1.0
    @GestureState private var dragState: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // Image
                if let cgImage = viewModel.currentImage {
                    #if canImport(UIKit)
                    Image(uiImage: UIImage(cgImage: cgImage))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(viewModel.zoomScale * magnifyState)
                        .offset(
                            x: viewModel.panOffset.width + dragState.width,
                            y: viewModel.panOffset.height + dragState.height
                        )
                        .rotationEffect(.degrees(viewModel.rotationAngle))
                        .scaleEffect(x: viewModel.isFlippedHorizontal ? -1 : 1, y: viewModel.isFlippedVertical ? -1 : 1)
                        .gesture(combinedGesture)
                    #endif
                } else if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                } else {
                    Text("No Image")
                        .foregroundStyle(.secondary)
                }
                
                // Frame counter overlay
                if viewModel.isMultiFrame {
                    VStack {
                        Spacer()
                        HStack {
                            Text(viewModel.frameCounterString)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(4)
                            Spacer()
                        }
                        .padding()
                    }
                }
                
                // Error message
                if let error = viewModel.errorMessage {
                    VStack {
                        Spacer()
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        Spacer()
                    }
                }
            }
        }
    }
    
    /// Combined gesture for pan and zoom
    private var combinedGesture: some Gesture {
        SimultaneousGesture(
            // Magnification (pinch to zoom)
            MagnificationGesture()
                .updating($magnifyState) { value, state, _ in
                    state = value
                }
                .onEnded { value in
                    viewModel.zoomScale *= value
                    viewModel.zoomScale = max(0.5, min(10.0, viewModel.zoomScale))
                },
            
            // Drag (pan)
            DragGesture()
                .updating($dragState) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    viewModel.panOffset.width += value.translation.width
                    viewModel.panOffset.height += value.translation.height
                }
        )
        .simultaneously(with:
            // Double tap to fit/reset
            TapGesture(count: 2)
                .onEnded {
                    withAnimation(.spring()) {
                        if viewModel.zoomScale != 1.0 || viewModel.panOffset != .zero {
                            viewModel.fitToScreen()
                        } else {
                            viewModel.zoomScale = 2.0
                        }
                    }
                }
        )
    }
}

/// Viewer control bar
struct ViewerControlBar: View {
    @Bindable var viewModel: ViewerViewModel
    @State private var showingWindowLevel = false
    @State private var showingTools = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Frame scrubber for multi-frame images
            if viewModel.isMultiFrame {
                FrameScrubber(
                    currentFrame: $viewModel.currentFrame,
                    frameCount: viewModel.frameCount
                )
            }
            
            // Control buttons
            HStack(spacing: 24) {
                // Window/Level
                Button {
                    showingWindowLevel.toggle()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "sun.max")
                            .font(.title2)
                        Text("W/L")
                            .font(.caption2)
                    }
                }
                
                // Playback (for multi-frame)
                if viewModel.isMultiFrame {
                    Button {
                        viewModel.togglePlayback()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                            Text(viewModel.isPlaying ? "Pause" : "Play")
                                .font(.caption2)
                        }
                    }
                }
                
                // Invert
                Button {
                    viewModel.toggleInvert()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.title2)
                        Text("Invert")
                            .font(.caption2)
                    }
                }
                
                // Rotate
                Button {
                    viewModel.rotateClockwise()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "rotate.right")
                            .font(.title2)
                        Text("Rotate")
                            .font(.caption2)
                    }
                }
                
                // Reset
                Button {
                    viewModel.resetView()
                    viewModel.resetWindowLevel()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                        Text("Reset")
                            .font(.caption2)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .sheet(isPresented: $showingWindowLevel) {
            WindowLevelSheet(viewModel: viewModel)
        }
    }
}

/// Frame scrubber for multi-frame images
struct FrameScrubber: View {
    @Binding var currentFrame: Int
    let frameCount: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { Double(currentFrame) },
                    set: { currentFrame = Int($0) }
                ),
                in: 0...Double(frameCount - 1),
                step: 1
            )
            .tint(.white)
            
            HStack {
                Button {
                    currentFrame = max(0, currentFrame - 1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentFrame == 0)
                
                Spacer()
                
                Text("\(currentFrame + 1) / \(frameCount)")
                    .font(.caption)
                    .monospacedDigit()
                
                Spacer()
                
                Button {
                    currentFrame = min(frameCount - 1, currentFrame + 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentFrame == frameCount - 1)
            }
            .font(.footnote)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

/// Window/Level adjustment sheet
struct WindowLevelSheet: View {
    @Bindable var viewModel: ViewerViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Current Settings") {
                    LabeledContent("Window Center") {
                        Text(String(format: "%.0f", viewModel.windowCenter))
                    }
                    
                    Slider(
                        value: $viewModel.windowCenter,
                        in: -1000...3000
                    )
                    
                    LabeledContent("Window Width") {
                        Text(String(format: "%.0f", viewModel.windowWidth))
                    }
                    
                    Slider(
                        value: $viewModel.windowWidth,
                        in: 1...4000
                    )
                }
                
                if !viewModel.windowPresets.isEmpty {
                    Section("Presets") {
                        ForEach(viewModel.windowPresets, id: \.center) { preset in
                            Button {
                                viewModel.applyPreset(preset)
                            } label: {
                                HStack {
                                    Text(preset.explanation ?? "Preset")
                                    Spacer()
                                    Text("C:\(Int(preset.center)) W:\(Int(preset.width))")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Section("CT Presets") {
                    ForEach(CTPreset.allCases) { preset in
                        Button {
                            viewModel.windowCenter = preset.center
                            viewModel.windowWidth = preset.width
                        } label: {
                            HStack {
                                Text(preset.name)
                                Spacer()
                                Text("C:\(Int(preset.center)) W:\(Int(preset.width))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    Button("Reset to Default") {
                        viewModel.resetWindowLevel()
                    }
                }
            }
            .navigationTitle("Window/Level")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// CT window/level presets
enum CTPreset: String, CaseIterable, Identifiable {
    case lung = "Lung"
    case bone = "Bone"
    case softTissue = "Soft Tissue"
    case brain = "Brain"
    case liver = "Liver"
    case abdomen = "Abdomen"
    
    var id: String { rawValue }
    
    var name: String { rawValue }
    
    var center: Double {
        switch self {
        case .lung: return -600
        case .bone: return 300
        case .softTissue: return 40
        case .brain: return 40
        case .liver: return 30
        case .abdomen: return 40
        }
    }
    
    var width: Double {
        switch self {
        case .lung: return 1500
        case .bone: return 2000
        case .softTissue: return 400
        case .brain: return 80
        case .liver: return 150
        case .abdomen: return 350
        }
    }
}

#Preview {
    let study = DICOMStudy(
        studyInstanceUID: "1.2.3",
        patientName: "Test Patient",
        storagePath: "/tmp"
    )
    return NavigationStack {
        ViewerContainerView(study: study)
    }
}
