//
//  MPRView.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import SwiftUI

/// Multi-Planar Reconstruction view displaying axial, sagittal, and coronal planes
struct MPRView: View {
    @State var viewModel: MPRViewModel
    let series: DicomSeries

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            mprToolbar

            Divider()

            // 2x2 grid layout
            if viewModel.isLoading {
                ProgressView("Building volume...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.volume != nil {
                GeometryReader { geometry in
                    let halfWidth = geometry.size.width / 2
                    let halfHeight = geometry.size.height / 2

                    VStack(spacing: 1) {
                        HStack(spacing: 1) {
                            // Top-left: Axial
                            MPRSliceView(
                                image: viewModel.axialImage,
                                title: "Axial",
                                sliceIndex: $viewModel.axialIndex,
                                maxIndex: viewModel.maxAxialIndex,
                                referenceH: viewModel.axialReferenceH,
                                referenceV: viewModel.axialReferenceV
                            )
                            .frame(width: halfWidth, height: halfHeight)

                            // Top-right: Sagittal
                            MPRSliceView(
                                image: viewModel.sagittalImage,
                                title: "Sagittal",
                                sliceIndex: $viewModel.sagittalIndex,
                                maxIndex: viewModel.maxSagittalIndex,
                                referenceH: viewModel.sagittalReferenceH,
                                referenceV: viewModel.sagittalReferenceV
                            )
                            .frame(width: halfWidth, height: halfHeight)
                        }

                        HStack(spacing: 1) {
                            // Bottom-left: Coronal
                            MPRSliceView(
                                image: viewModel.coronalImage,
                                title: "Coronal",
                                sliceIndex: $viewModel.coronalIndex,
                                maxIndex: viewModel.maxCoronalIndex,
                                referenceH: viewModel.coronalReferenceH,
                                referenceV: viewModel.coronalReferenceV
                            )
                            .frame(width: halfWidth, height: halfHeight)

                            // Bottom-right: Info panel
                            volumeInfoPanel
                                .frame(width: halfWidth, height: halfHeight)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Volume",
                    systemImage: "cube.transparent",
                    description: Text("Unable to build 3D volume from this series")
                )
            }
        }
        .background(Color.black)
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

    // MARK: - Toolbar

    private var mprToolbar: some View {
        HStack {
            Text("MPR")
                .font(.headline)

            Divider()

            // Window/Level controls
            HStack(spacing: 4) {
                Text("WC:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", value: $viewModel.windowCenter, format: .number)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)

                Text("WW:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", value: $viewModel.windowWidth, format: .number)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            // Reset button
            Button {
                viewModel.resetToCenter()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }

            Spacer()

            // Slice position info
            if viewModel.volume != nil {
                Text("A:\(viewModel.axialIndex) S:\(viewModel.sagittalIndex) C:\(viewModel.coronalIndex)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
    }

    // MARK: - Info Panel

    private var volumeInfoPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Volume Info")
                .font(.headline)
                .foregroundStyle(.white)

            if let volume = viewModel.volume {
                Group {
                    infoRow("Dimensions", "\(volume.width) × \(volume.height) × \(volume.depth)")
                    infoRow("Voxels", "\(volume.voxelCount)")
                    infoRow("Spacing (mm)", String(format: "%.2f × %.2f × %.2f", volume.spacingX, volume.spacingY, volume.spacingZ))
                    infoRow("Physical Size", String(format: "%.1f × %.1f × %.1f mm", volume.physicalSize.x, volume.physicalSize.y, volume.physicalSize.z))
                    infoRow("Rescale Slope", String(format: "%.4f", volume.rescaleSlope))
                    infoRow("Rescale Intercept", String(format: "%.1f", volume.rescaleIntercept))
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.white)
        }
    }
}

// MARK: - MPRSliceView

/// Displays a single MPR plane with reference line overlay and slice slider
struct MPRSliceView: View {
    let image: NSImage?
    let title: String
    let sliceIndex: Binding<Int>
    let maxIndex: Int
    let referenceH: Double
    let referenceV: Double

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                Spacer()
                Text("\(sliceIndex.wrappedValue)/\(maxIndex)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.6))

            // Slice image with reference lines
            ZStack {
                if let image = image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Color.black
                }

                // Reference lines overlay
                referenceLines
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .clipped()

            // Slice slider
            if maxIndex > 0 {
                Slider(
                    value: Binding(
                        get: { Double(sliceIndex.wrappedValue) },
                        set: { sliceIndex.wrappedValue = Int($0) }
                    ),
                    in: 0...Double(maxIndex),
                    step: 1
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
        .background(Color.black)
        .border(Color.gray.opacity(0.3), width: 1)
    }

    private var referenceLines: some View {
        GeometryReader { geometry in
            // Horizontal reference line
            Path { path in
                let y = referenceH * geometry.size.height
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: geometry.size.width, y: y))
            }
            .stroke(Color.yellow, lineWidth: 1)

            // Vertical reference line
            Path { path in
                let x = referenceV * geometry.size.width
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: geometry.size.height))
            }
            .stroke(Color.yellow, lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
