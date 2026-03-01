// WindowLevelPanel.swift
// DICOMStudio
//
// DICOM Studio — Window/level controls panel

#if canImport(SwiftUI)
import SwiftUI

/// Panel for adjusting window center/width (window/level) settings.
///
/// Provides numeric inputs, preset buttons, and header-based auto settings.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct WindowLevelPanel: View {
    @Bindable var viewModel: ImageViewerViewModel

    public init(viewModel: ImageViewerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Label("Window / Level", systemImage: "slider.horizontal.3")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            // Numeric inputs
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Center")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(
                        "Center",
                        value: Bindable(viewModel).windowCenter,
                        format: .number
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .accessibilityLabel("Window center value")
                    .onSubmit { viewModel.renderCurrentFrame() }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Width")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(
                        "Width",
                        value: Bindable(viewModel).windowWidth,
                        format: .number
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .accessibilityLabel("Window width value")
                    .onSubmit { viewModel.renderCurrentFrame() }
                }
            }

            // Current W/L display
            Text(viewModel.windowLevelText)
                .font(.system(size: StudioTypography.monoSize, design: .monospaced))
                .foregroundStyle(.secondary)

            // Auto button from header
            if !viewModel.headerWindowSettings.isEmpty {
                Button("Auto (from header)") {
                    viewModel.autoWindowLevel()
                }
                .accessibilityLabel("Auto-adjust window/level from DICOM header")
            }

            // Presets
            if !viewModel.availablePresets.isEmpty {
                Divider()
                Text("Presets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)

                FlowLayout(spacing: 6) {
                    ForEach(viewModel.availablePresets) { preset in
                        Button(preset.name) {
                            viewModel.applyPreset(preset)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityLabel("\(preset.name) preset")
                        .accessibilityHint("Sets window center to \(Int(preset.center)) and width to \(Int(preset.width))")
                    }
                }
            }

            // Header window settings
            if viewModel.headerWindowSettings.count > 1 {
                Divider()
                Text("Header Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)

                ForEach(Array(viewModel.headerWindowSettings.enumerated()), id: \.offset) { index, settings in
                    Button {
                        viewModel.applyWindowSettings(settings)
                    } label: {
                        HStack {
                            Text(settings.explanation ?? "Window \(index + 1)")
                            Spacer()
                            Text("C:\(Int(settings.center)) W:\(Int(settings.width))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(settings.explanation ?? "Window setting \(index + 1)")
                }
            }

            // Inversion toggle
            if viewModel.isMonochrome {
                Divider()
                Toggle("Invert Grayscale", isOn: Binding(
                    get: { viewModel.isInverted },
                    set: { _ in viewModel.toggleInversion() }
                ))
                .accessibilityLabel("Invert grayscale")
            }
        }
        .padding()
    }
}

/// Simple flow layout for preset buttons.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, offset) in result.offsets.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, offsets: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            offsets.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), offsets)
    }
}
#endif
