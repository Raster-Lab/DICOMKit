//
//  MultiViewportView.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import SwiftUI

/// Multi-viewport image viewer
struct MultiViewportView: View {
    let study: DicomStudy
    @State private var viewModel = MultiViewportViewModel()
    @State private var showingLayoutPicker = false
    @State private var showingProtocolPicker = false
    @State private var showingCineControls = false
    @State private var showingMeasurements = false
    @State private var measurementViewModel = MeasurementViewModel()
    
    var body: some View {
        HStack(spacing: 0) {
            // Main content
            VStack(spacing: 0) {
                // Toolbar
                toolbarView
                
                Divider()
                
                // Measurement toolbar (if enabled)
                if showingMeasurements {
                    MeasurementToolbar(
                        selectedTool: $measurementViewModel.selectedTool,
                        showLabels: $measurementViewModel.showLabels,
                        showValues: $measurementViewModel.showValues,
                        onClearAll: {
                            confirmClearAll()
                        },
                        onExport: {
                            exportMeasurements()
                        },
                        onImport: {
                            importMeasurements()
                        }
                    )
                    
                    Divider()
                }
                
                // Viewport grid
                viewportGridView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                
                // Cine controls (if enabled)
                if showingCineControls {
                    Divider()
                    cineControlsView
                }
            }
            
            // Measurement list sidebar (if enabled)
            if showingMeasurements {
                Divider()
                
                MeasurementListView(
                    measurements: measurementViewModel.currentMeasurements,
                    selectedIDs: measurementViewModel.selectedMeasurementIDs,
                    onToggleVisibility: { id in
                        measurementViewModel.toggleVisibility(id: id)
                    },
                    onDelete: { id in
                        measurementViewModel.deleteMeasurement(id: id)
                    },
                    onSelect: { id, addToSelection in
                        measurementViewModel.selectMeasurement(id: id, addToSelection: addToSelection)
                    },
                    onUpdateLabel: { id, label in
                        measurementViewModel.updateLabel(id: id, label: label)
                    }
                )
            }
        }
        .task {
            await viewModel.loadStudy(study)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .alert("Clear All Measurements", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                measurementViewModel.clearAllMeasurements()
            }
        } message: {
            Text("Are you sure you want to clear all measurements? This action cannot be undone.")
        }
    }
    
    @State private var showingClearConfirmation = false
    
    private func confirmClearAll() {
        showingClearConfirmation = true
    }
    
    private func exportMeasurements() {
        do {
            let data = try measurementViewModel.exportMeasurements()
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "measurements.json"
            
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    try? data.write(to: url)
                }
            }
        } catch {
            viewModel.errorMessage = "Failed to export measurements: \(error.localizedDescription)"
        }
    }
    
    private func importMeasurements() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try Data(contentsOf: url)
                    try measurementViewModel.importMeasurements(from: data)
                } catch {
                    viewModel.errorMessage = "Failed to import measurements: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Toolbar
    
    private var toolbarView: some View {
        HStack {
            // Layout selector
            Menu {
                ForEach(ViewportLayout.standard, id: \.name) { layout in
                    Button(layout.name) {
                        viewModel.setLayout(layout)
                    }
                }
            } label: {
                Label("Layout: \(viewModel.layoutService.currentLayout.name)", systemImage: "square.grid.2x2")
            }
            .help("Select viewport layout (1×1, 2×2, 3×3, 4×4)")
            .accessibilityLabel("Viewport layout selector")
            
            Divider()
            
            // Hanging protocol selector
            Menu {
                Button("Manual") {
                    viewModel.protocolService.selectProtocol(nil)
                }
                
                Divider()
                
                ForEach(viewModel.protocolService.protocols, id: \.id) { protocol in
                    Button(`protocol`.name) {
                        viewModel.applyHangingProtocol(`protocol`)
                    }
                }
            } label: {
                Label("Protocol", systemImage: "list.bullet.rectangle")
            }
            .help("Select hanging protocol for automatic series arrangement")
            .accessibilityLabel("Hanging protocol selector")
            
            Divider()
            
            // Viewport linking
            Menu {
                Toggle("Link Scroll", isOn: Binding(
                    get: { viewModel.layoutService.linking.scrollEnabled },
                    set: { viewModel.layoutService.setScrollLinking($0) }
                ))
                
                Toggle("Link W/L", isOn: Binding(
                    get: { viewModel.layoutService.linking.windowLevelEnabled },
                    set: { viewModel.layoutService.setWindowLevelLinking($0) }
                ))
                
                Toggle("Link Zoom", isOn: Binding(
                    get: { viewModel.layoutService.linking.zoomEnabled },
                    set: { viewModel.layoutService.setZoomLinking($0) }
                ))
                
                Toggle("Link Pan", isOn: Binding(
                    get: { viewModel.layoutService.linking.panEnabled },
                    set: { viewModel.layoutService.setPanLinking($0) }
                ))
                
                Divider()
                
                Button("Link All") {
                    viewModel.layoutService.setLinking(.all)
                }
                
                Button("Unlink All") {
                    viewModel.layoutService.setLinking(.none)
                }
            } label: {
                Label("Linking", systemImage: "link")
            }
            .help("Configure viewport linking (scroll, window/level, zoom, pan)")
            .accessibilityLabel("Viewport linking options")
            
            Divider()
            
            // Cine controls toggle
            Button {
                showingCineControls.toggle()
            } label: {
                Label("Cine", systemImage: "play.circle")
            }
            .help("Toggle cine playback controls")
            .accessibilityLabel("Cine playback controls")
            
            Divider()
            
            // Measurements toggle
            Toggle(isOn: $showingMeasurements) {
                Label("Measurements", systemImage: "ruler")
            }
            .toggleStyle(.button)
            .help("Show measurement tools")
            
            Spacer()
        }
        .padding(8)
    }
    
    // MARK: - Viewport Grid
    
    private var viewportGridView: some View {
        let layout = viewModel.layoutService.currentLayout
        
        return GeometryReader { geometry in
            let columns = layout.columns
            let rows = layout.rows
            let spacing: CGFloat = 2
            
            let totalSpacing = spacing * CGFloat(columns - 1)
            let availableWidth = geometry.size.width - totalSpacing
            let cellWidth = availableWidth / CGFloat(columns)
            
            let totalVerticalSpacing = spacing * CGFloat(rows - 1)
            let availableHeight = geometry.size.height - totalVerticalSpacing
            let cellHeight = availableHeight / CGFloat(rows)
            
            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = row * columns + col
                            if index < viewModel.layoutService.viewports.count {
                                let viewport = viewModel.layoutService.viewports[index]
                                viewportCellView(for: viewport)
                                    .frame(width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func viewportCellView(for viewport: Viewport) -> some View {
        let isSelected = viewModel.layoutService.selectedViewportId == viewport.id
        
        return Group {
            if let series = viewport.series,
               let viewModelForViewport = viewModel.viewModel(for: viewport.id) {
                ViewportContentView(
                    series: series,
                    viewModel: viewModelForViewport,
                    isSelected: isSelected,
                    onSelect: {
                        viewModel.layoutService.selectViewport(viewport.id)
                        // Update measurement context when viewport is selected
                        if showingMeasurements, 
                           viewModelForViewport.currentIndex < viewModelForViewport.instances.count {
                            let instance = viewModelForViewport.instances[viewModelForViewport.currentIndex]
                            measurementViewModel.updateContext(
                                instanceUID: instance.sopInstanceUID,
                                frameIndex: viewModelForViewport.currentIndex,
                                pixelSpacing: nil // TODO: Extract from DICOM file if available
                            )
                        }
                    },
                    measurements: showingMeasurements ? measurementViewModel.currentMeasurements : [],
                    selectedMeasurementIDs: measurementViewModel.selectedMeasurementIDs,
                    showMeasurements: showingMeasurements,
                    showLabels: measurementViewModel.showLabels,
                    showValues: measurementViewModel.showValues,
                    selectedTool: $measurementViewModel.selectedTool,
                    onAddPoint: { point in
                        measurementViewModel.addPoint(at: point)
                    },
                    onCompleteMeasurement: {
                        measurementViewModel.completeMeasurement()
                    }
                )
            } else {
                EmptyViewportView(isSelected: isSelected) {
                    viewModel.layoutService.selectViewport(viewport.id)
                }
            }
        }
        .border(isSelected ? Color.blue : Color.gray.opacity(0.3), width: isSelected ? 2 : 1)
    }
    
    // MARK: - Cine Controls
    
    private var cineControlsView: some View {
        HStack {
            // Playback controls
            Button {
                viewModel.cineController.goToFirstFrame()
            } label: {
                Image(systemName: "backward.end")
            }
            
            Button {
                viewModel.cineController.previousFrame()
            } label: {
                Image(systemName: "backward.frame")
            }
            
            Button {
                viewModel.cineController.togglePlayPause()
            } label: {
                Image(systemName: viewModel.cineController.state == .playing ? "pause.circle" : "play.circle")
            }
            
            Button {
                viewModel.cineController.nextFrame()
            } label: {
                Image(systemName: "forward.frame")
            }
            
            Button {
                viewModel.cineController.goToLastFrame()
            } label: {
                Image(systemName: "forward.end")
            }
            
            Divider()
            
            // Frame counter
            Text("Frame \(viewModel.cineController.currentFrame + 1) of \(viewModel.cineController.totalFrames)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120)
            
            Divider()
            
            // FPS selector
            Text("FPS:")
                .font(.caption)
            
            Picker("", selection: Binding(
                get: { viewModel.cineController.framesPerSecond },
                set: { viewModel.cineController.setFramesPerSecond($0) }
            )) {
                Text("5").tag(5.0)
                Text("10").tag(10.0)
                Text("15").tag(15.0)
                Text("20").tag(20.0)
                Text("30").tag(30.0)
                Text("60").tag(60.0)
            }
            .frame(width: 80)
            
            Divider()
            
            // Loop toggle
            Toggle("Loop", isOn: $viewModel.cineController.loopEnabled)
                .toggleStyle(.checkbox)
            
            // Reverse toggle
            Toggle("Reverse", isOn: $viewModel.cineController.reversePlayback)
                .toggleStyle(.checkbox)
        }
        .padding(8)
    }
}

// MARK: - Viewport Content View

private struct ViewportContentView: View {
    let series: DicomSeries
    @Bindable var viewModel: ImageViewerViewModel
    let isSelected: Bool
    let onSelect: () -> Void
    let measurements: [Measurement]
    let selectedMeasurementIDs: Set<UUID>
    let showMeasurements: Bool
    let showLabels: Bool
    let showValues: Bool
    @Binding var selectedTool: MeasurementType?
    let onAddPoint: (ImagePoint) -> Void
    let onCompleteMeasurement: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if let image = viewModel.currentImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(viewModel.zoomLevel)
                        .rotationEffect(.degrees(viewModel.rotationAngle))
                        .offset(viewModel.panOffset)
                    
                    // Measurement overlay (if enabled)
                    if showMeasurements && !measurements.isEmpty {
                        MeasurementOverlayView(
                            measurements: measurements,
                            selectedIDs: selectedMeasurementIDs,
                            showLabels: showLabels,
                            showValues: showValues,
                            imageSize: CGSize(width: image.size.width, height: image.size.height),
                            viewSize: geometry.size,
                            zoom: viewModel.zoomLevel,
                            offset: viewModel.panOffset
                        )
                    }
                    
                    // Measurement interaction layer (if tool is selected)
                    if showMeasurements && selectedTool != nil {
                        MeasurementInteractionView(
                            selectedTool: $selectedTool,
                            imageSize: CGSize(width: image.size.width, height: image.size.height),
                            zoom: viewModel.zoomLevel,
                            offset: viewModel.panOffset,
                            onAddPoint: onAddPoint,
                            onComplete: onCompleteMeasurement
                        )
                    }
                } else {
                    Text("No image")
                        .foregroundStyle(.secondary)
                }
                
                // Series info overlay
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(series.seriesDescription ?? "Unknown")
                                .font(.caption)
                                .foregroundStyle(.white)
                            Text("Series \(series.seriesNumber)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                    }
                    .padding(4)
                    .background(Color.black.opacity(0.6))
                    
                    Spacer()
                }
            }
            .onTapGesture {
                onSelect()
            }
        }
    }
}

// MARK: - Empty Viewport View

private struct EmptyViewportView: View {
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        ZStack {
            Color.black
            
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Empty Viewport")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onTapGesture {
            onSelect()
        }
    }
}
