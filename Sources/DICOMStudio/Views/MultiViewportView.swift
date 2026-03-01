// MultiViewportView.swift
// DICOMStudio
//
// DICOM Studio — SwiftUI multi-viewport grid display

import Foundation

#if canImport(SwiftUI)
import SwiftUI

/// Multi-viewport grid display for hanging protocol-driven layouts.
///
/// Arranges multiple viewport cells in a configurable grid with
/// active viewport highlighting and viewport-specific controls.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct MultiViewportView: View {

    /// The multi-viewport ViewModel.
    @Bindable public var viewModel: MultiViewportViewModel

    /// Number of grid columns.
    public let columns: Int

    /// Number of grid rows.
    public let rows: Int

    /// Creates a multi-viewport view.
    public init(viewModel: MultiViewportViewModel, columns: Int, rows: Int) {
        self.viewModel = viewModel
        self.columns = columns
        self.rows = rows
    }

    public var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 2
            let cellWidth = (geometry.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            let cellHeight = (geometry.size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)

            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = row * columns + col
                            viewportCell(index: index, width: cellWidth, height: cellHeight)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func viewportCell(index: Int, width: CGFloat, height: CGFloat) -> some View {
        let isActive = index == viewModel.activeViewportIndex
        let viewport = index < viewModel.viewports.count ? viewModel.viewports[index] : nil

        ZStack {
            // Background
            Color.black

            // Viewport content
            if let vp = viewport, vp.hasImage {
                VStack {
                    Spacer()
                    Text(viewModel.viewportInfoText(for: index))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(4)
                }
            } else {
                Text("Empty")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: width, height: height)
        .border(isActive ? Color.accentColor : Color.gray.opacity(0.3), width: isActive ? 2 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.setActiveViewport(index)
        }
        .accessibilityLabel("Viewport \(index + 1)")
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityValue(viewport?.hasImage == true ? "Image loaded" : "Empty")
    }
}

/// Toolbar for multi-viewport controls.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct MultiViewportToolbar: View {

    @Bindable public var viewModel: MultiViewportViewModel

    public init(viewModel: MultiViewportViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Sync mode picker
            Picker("Sync", selection: $viewModel.syncMode) {
                Text("None").tag(ViewportSyncMode.none)
                Text("Scroll").tag(ViewportSyncMode.scroll)
                Text("W/L").tag(ViewportSyncMode.windowLevel)
                Text("All").tag(ViewportSyncMode.all)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            .accessibilityLabel("Viewport synchronization mode")

            Divider()
                .frame(height: 20)

            // Tool mode picker
            Picker("Tool", selection: $viewModel.toolMode) {
                Text("Scroll").tag(ViewportToolMode.scroll)
                Text("W/L").tag(ViewportToolMode.windowLevel)
                Text("Zoom").tag(ViewportToolMode.zoom)
                Text("Pan").tag(ViewportToolMode.pan)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            .accessibilityLabel("Viewport tool mode")

            Spacer()

            // Cross-reference toggle
            Toggle(isOn: $viewModel.showCrossReferenceLines) {
                Image(systemName: "line.diagonal")
            }
            .toggleStyle(.button)
            .accessibilityLabel("Show cross-reference lines")

            // Viewport info
            Text("\(viewModel.loadedViewportCount)/\(viewModel.viewports.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
}
#endif
