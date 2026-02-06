//
//  VolumeRenderingView.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import SwiftUI

/// 3D volume rendering view with projection modes and transfer function controls
struct VolumeRenderingView: View {
    @State var viewModel: VolumeRenderingViewModel

    var body: some View {
        HSplitView {
            // Main rendering area
            renderingArea
                .frame(minWidth: 400)

            // Sidebar controls
            controlsSidebar
                .frame(width: 250)
        }
        .background(Color.black)
    }

    // MARK: - Rendering Area

    private var renderingArea: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("Rendering...")
            } else if let image = viewModel.renderedImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(viewModel.zoom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gesture(dragGesture)
                    .gesture(scrollGesture)
            } else {
                ContentUnavailableView(
                    "No Volume",
                    systemImage: "cube.transparent",
                    description: Text("Load a volume to begin rendering")
                )
            }
        }
        .background(Color.black)
    }

    // MARK: - Controls Sidebar

    private var controlsSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Rendering mode
                renderingModeSection

                Divider()

                // Transfer function
                transferFunctionSection

                Divider()

                // Slab controls
                slabSection

                Divider()

                // Camera controls
                cameraSection

                Spacer()
            }
            .padding()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Sections

    private var renderingModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rendering Mode")
                .font(.headline)

            Picker("Mode", selection: $viewModel.renderingMode) {
                ForEach(RenderingMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        }
    }

    private var transferFunctionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transfer Function")
                .font(.headline)

            ForEach(TransferFunction.allPresets) { preset in
                Button {
                    viewModel.transferFunction = preset
                } label: {
                    HStack {
                        Text(preset.name)
                        Spacer()
                        if viewModel.transferFunction.id == preset.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(viewModel.renderingMode == .volumeRendering ? 1.0 : 0.5)
        .disabled(viewModel.renderingMode != .volumeRendering)
    }

    private var slabSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Slab Thickness")
                .font(.headline)

            HStack {
                Slider(
                    value: Binding(
                        get: { Double(viewModel.slabThickness) },
                        set: { viewModel.slabThickness = Int($0) }
                    ),
                    in: 0...Double(viewModel.volume?.depth ?? 100),
                    step: 1
                )

                Text(viewModel.slabThickness == 0 ? "Full" : "\(viewModel.slabThickness)")
                    .font(.caption.monospaced())
                    .frame(width: 40)
            }
        }
    }

    private var cameraSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Camera")
                .font(.headline)

            HStack {
                Text("Zoom")
                    .font(.caption)
                Slider(value: $viewModel.zoom, in: 0.1...5.0)
                Text(String(format: "%.1f×", viewModel.zoom))
                    .font(.caption.monospaced())
                    .frame(width: 36)
            }

            HStack {
                Text("Rotation X")
                    .font(.caption)
                Slider(value: $viewModel.rotationX, in: -180...180)
                Text(String(format: "%.0f°", viewModel.rotationX))
                    .font(.caption.monospaced())
                    .frame(width: 36)
            }

            HStack {
                Text("Rotation Y")
                    .font(.caption)
                Slider(value: $viewModel.rotationY, in: -180...180)
                Text(String(format: "%.0f°", viewModel.rotationY))
                    .font(.caption.monospaced())
                    .frame(width: 36)
            }

            Button {
                viewModel.resetView()
            } label: {
                Label("Reset Camera", systemImage: "arrow.counterclockwise")
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                viewModel.rotateBy(
                    dx: value.translation.width * 0.5,
                    dy: value.translation.height * 0.5
                )
            }
    }

    private var scrollGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                viewModel.zoom = max(0.1, min(viewModel.zoom * value.magnification, 10.0))
            }
    }
}
