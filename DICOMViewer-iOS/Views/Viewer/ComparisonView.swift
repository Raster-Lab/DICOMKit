// ComparisonView.swift
// DICOMViewer iOS - Side-by-Side Comparison View
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import SwiftUI
import SwiftData

/// Side-by-side comparison view for comparing two DICOM images
struct ComparisonView: View {
    let study: DICOMStudy
    let initialSeries: DICOMSeries?
    
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ComparisonViewModel()
    
    @State private var leftSeries: DICOMSeries?
    @State private var rightSeries: DICOMSeries?
    @State private var showingLeftSeriesPicker = false
    @State private var showingRightSeriesPicker = false
    @State private var showingSyncSettings = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Two-pane viewer
                HStack(spacing: 1) {
                    // Left pane
                    ComparisonPaneView(
                        viewModel: viewModel.leftViewModel,
                        title: "Left",
                        series: leftSeries,
                        isSynchronized: viewModel.isSynchronized,
                        onSeriesPickerTap: { showingLeftSeriesPicker = true },
                        onInteraction: {
                            if viewModel.isSynchronized {
                                viewModel.syncRightToLeft()
                            }
                        }
                    )
                    
                    // Divider
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1)
                    
                    // Right pane
                    ComparisonPaneView(
                        viewModel: viewModel.rightViewModel,
                        title: "Right",
                        series: rightSeries,
                        isSynchronized: viewModel.isSynchronized,
                        onSeriesPickerTap: { showingRightSeriesPicker = true },
                        onInteraction: {
                            if viewModel.isSynchronized {
                                viewModel.syncLeftToRight()
                            }
                        }
                    )
                }
                
                // Bottom control bar
                ComparisonControlBar(
                    viewModel: viewModel,
                    onSwap: {
                        withAnimation {
                            viewModel.swapViewers()
                            // Swap series references too
                            let temp = leftSeries
                            leftSeries = rightSeries
                            rightSeries = temp
                        }
                    },
                    onSyncSettings: { showingSyncSettings = true }
                )
            }
            .navigationTitle("Compare Images")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingLeftSeriesPicker) {
                SeriesPickerView(
                    study: study,
                    selectedSeries: $leftSeries,
                    onSelect: { series in
                        leftSeries = series
                        showingLeftSeriesPicker = false
                        Task {
                            await viewModel.leftViewModel.loadSeries(series)
                            if viewModel.isSynchronized {
                                viewModel.syncRightToLeft()
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $showingRightSeriesPicker) {
                SeriesPickerView(
                    study: study,
                    selectedSeries: $rightSeries,
                    onSelect: { series in
                        rightSeries = series
                        showingRightSeriesPicker = false
                        Task {
                            await viewModel.rightViewModel.loadSeries(series)
                            if viewModel.isSynchronized {
                                viewModel.syncLeftToRight()
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $showingSyncSettings) {
                SyncSettingsView(viewModel: viewModel)
            }
            .task {
                // Load initial series in both viewers
                if let initialSeries = initialSeries ?? study.series?.first {
                    leftSeries = initialSeries
                    await viewModel.leftViewModel.loadSeries(initialSeries)
                    
                    // Load second series in right viewer if available
                    if let seriesArray = study.series, seriesArray.count > 1 {
                        let secondSeries = seriesArray[1]
                        rightSeries = secondSeries
                        await viewModel.rightViewModel.loadSeries(secondSeries)
                    } else {
                        // Use same series for both if only one available
                        rightSeries = initialSeries
                        await viewModel.rightViewModel.loadSeries(initialSeries)
                    }
                    
                    // Sync initial state
                    viewModel.syncRightToLeft()
                }
            }
        }
    }
}

/// Single pane in the comparison view
struct ComparisonPaneView: View {
    @Bindable var viewModel: ViewerViewModel
    let title: String
    let series: DICOMSeries?
    let isSynchronized: Bool
    let onSeriesPickerTap: () -> Void
    let onInteraction: () -> Void
    
    // Gesture states
    @State private var lastScale: CGFloat = 1.0
    @GestureState private var magnifyState: CGFloat = 1.0
    @GestureState private var dragState: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let series = series {
                    Text("• \(series.modality)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Button(action: onSeriesPickerTap) {
                    Image(systemName: "rectangle.stack")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                
                if isSynchronized {
                    Image(systemName: "link")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            
            // Image viewer
            GeometryReader { geometry in
                ZStack {
                    Color.black
                    
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
                            .tint(.white)
                    } else {
                        Text("No Image")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    
                    // Frame counter
                    if viewModel.isMultiFrame {
                        VStack {
                            Spacer()
                            HStack {
                                Text(viewModel.frameCounterString)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(3)
                                Spacer()
                            }
                            .padding(6)
                        }
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
                    onInteraction()
                },
            
            // Drag (pan)
            DragGesture()
                .updating($dragState) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    viewModel.panOffset.width += value.translation.width
                    viewModel.panOffset.height += value.translation.height
                    onInteraction()
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
                    onInteraction()
                }
        )
    }
}

/// Control bar for comparison view
struct ComparisonControlBar: View {
    @Bindable var viewModel: ComparisonViewModel
    let onSwap: () -> Void
    let onSyncSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Sync toggle
            Button {
                withAnimation {
                    viewModel.isSynchronized.toggle()
                }
            } label: {
                Image(systemName: viewModel.isSynchronized ? "link" : "link.slash")
                    .foregroundStyle(viewModel.isSynchronized ? .blue : .secondary)
            }
            .buttonStyle(.borderless)
            
            // Sync settings
            Button(action: onSyncSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .disabled(!viewModel.isSynchronized)
            
            Spacer()
            
            // Swap button
            Button(action: onSwap) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Swap")
                        .font(.caption)
                }
            }
            .buttonStyle(.borderless)
            
            Spacer()
            
            // Frame controls (for synchronized navigation)
            if viewModel.isSynchronized && viewModel.syncFrames {
                HStack(spacing: 12) {
                    Button {
                        viewModel.leftViewModel.previousFrame()
                        viewModel.syncRightToLeft()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(viewModel.leftViewModel.currentFrame == 0)
                    
                    Text("\(viewModel.leftViewModel.currentFrame + 1)/\(viewModel.leftViewModel.frameCount)")
                        .font(.caption)
                        .monospacedDigit()
                        .frame(minWidth: 50)
                    
                    Button {
                        viewModel.leftViewModel.nextFrame()
                        viewModel.syncRightToLeft()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(viewModel.leftViewModel.currentFrame >= viewModel.leftViewModel.frameCount - 1)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

/// Sync settings sheet
struct SyncSettingsView: View {
    @Bindable var viewModel: ComparisonViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Synchronization Options") {
                    Toggle("Sync Frame Navigation", isOn: $viewModel.syncFrames)
                    Toggle("Sync Window/Level", isOn: $viewModel.syncWindowLevel)
                    Toggle("Sync Zoom & Pan", isOn: $viewModel.syncZoomPan)
                    Toggle("Sync Rotation & Flip", isOn: $viewModel.syncTransforms)
                }
                
                Section {
                    Text("When enabled, these settings will be synchronized between the left and right viewers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Sync Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    // Preview requires mock data
    Text("Comparison View Preview")
}
