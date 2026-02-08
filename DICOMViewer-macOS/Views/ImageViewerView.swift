//
//  ImageViewerView.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import SwiftUI

/// Image viewer view
struct ImageViewerView: View {
    let series: DicomSeries
    @State private var viewModel = ImageViewerViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbarView
            
            Divider()
            
            // Image display area
            imageView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            
            Divider()
            
            // Controls
            controlsView
        }
        .task {
            await viewModel.loadSeries(series)
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
    }
    
    private var toolbarView: some View {
        HStack {
            // Window/Level presets
            Menu {
                ForEach(ImageViewerViewModel.WindowLevelPreset.allPresets, id: \.name) { preset in
                    Button(preset.name) {
                        viewModel.applyPreset(preset)
                    }
                }
            } label: {
                Label("W/L Presets", systemImage: "slider.horizontal.3")
            }
            .help("Select window/level preset (Lung, Bone, Soft Tissue, Brain, etc.)")
            .accessibilityLabel("Window/Level presets")
            
            Divider()
            
            // Zoom controls
            Button {
                viewModel.zoomLevel = max(0.1, viewModel.zoomLevel - 0.1)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom out (⌘-)")
            .accessibilityLabel("Zoom out")
            
            Text("\(Int(viewModel.zoomLevel * 100))%")
                .frame(width: 50)
                .font(.caption)
                .accessibilityLabel("Current zoom level: \(Int(viewModel.zoomLevel * 100)) percent")
            
            Button {
                viewModel.zoomLevel += 0.1
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom in (⌘+)")
            .accessibilityLabel("Zoom in")
            
            Button {
                viewModel.zoomLevel = 1.0
            } label: {
                Image(systemName: "1.magnifyingglass")
            }
            .help("Reset to actual size (⌘0)")
            .accessibilityLabel("Reset to actual size")
            
            Divider()
            
            // Rotation
            Button {
                viewModel.rotate(by: -90)
            } label: {
                Image(systemName: "rotate.left")
            }
            .help("Rotate counter-clockwise 90°")
            .accessibilityLabel("Rotate counter-clockwise")
            
            Button {
                viewModel.rotate(by: 90)
            } label: {
                Image(systemName: "rotate.right")
            }
            .help("Rotate clockwise 90°")
            .accessibilityLabel("Rotate clockwise")
            
            Divider()
            
            // Invert
            Toggle(isOn: $viewModel.invertGrayscale) {
                Image(systemName: "circle.lefthalf.filled")
            }
            .toggleStyle(.button)
            .help("Invert grayscale (useful for MONOCHROME1)")
            .accessibilityLabel("Invert grayscale")
            
            Divider()
            
            // Reset
            Button {
                viewModel.resetView()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            
            Spacer()
            
            // Image info
            if !viewModel.instances.isEmpty {
                Text("Image \(viewModel.currentIndex + 1) of \(viewModel.instances.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
    }
    
    private var imageView: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("Loading image...")
            } else if let image = viewModel.currentImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(viewModel.zoomLevel)
                    .rotationEffect(.degrees(viewModel.rotationAngle))
                    .offset(viewModel.panOffset)
            } else {
                ContentUnavailableView(
                    "No Image",
                    systemImage: "photo",
                    description: Text("Unable to load image")
                )
            }
        }
    }
    
    private var controlsView: some View {
        HStack {
            // Navigation
            Button {
                viewModel.previousImage()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(viewModel.currentIndex == 0)
            
            Spacer()
            
            // Slider for quick navigation
            if viewModel.instances.count > 1 {
                Slider(
                    value: Binding(
                        get: { Double(viewModel.currentIndex) },
                        set: { viewModel.currentIndex = Int($0) }
                    ),
                    in: 0...Double(viewModel.instances.count - 1),
                    step: 1
                )
                .frame(maxWidth: 400)
            }
            
            Spacer()
            
            Button {
                viewModel.nextImage()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(viewModel.currentIndex >= viewModel.instances.count - 1)
        }
        .padding()
    }
}
