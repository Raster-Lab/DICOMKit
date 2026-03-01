// ImageMetadataOverlayView.swift
// DICOMStudio
//
// DICOM Studio — Image metadata overlay

#if canImport(SwiftUI)
import SwiftUI

/// Overlay displaying pixel data metadata on top of the image.
///
/// Shows dimensions, bit depth, pixel representation, photometric interpretation,
/// and samples per pixel.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct ImageMetadataOverlayView: View {
    let viewModel: ImageViewerViewModel

    public init(viewModel: ImageViewerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            metadataRow(label: "Dimensions", value: viewModel.dimensionsText)
            metadataRow(
                label: "Bits (Alloc/Stored/High)",
                value: viewModel.bitDepthText
            )
            metadataRow(
                label: "Pixel Repr.",
                value: viewModel.pixelRepresentationText
            )
            metadataRow(
                label: "Photometric",
                value: viewModel.photometricLabel
            )
            metadataRow(
                label: "Samples/Pixel",
                value: ImageMetadataHelpers.samplesText(
                    samplesPerPixel: viewModel.samplesPerPixel,
                    planarConfiguration: viewModel.planarConfiguration
                )
            )
            if viewModel.isMultiFrame {
                metadataRow(
                    label: "Frame",
                    value: viewModel.frameText
                )
            }
            metadataRow(
                label: "W/L",
                value: viewModel.windowLevelText
            )
        }
        .font(.system(size: StudioTypography.captionSize, design: .monospaced))
        .foregroundStyle(.white)
        .padding(8)
        .background(.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Image metadata overlay")
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label + ":")
                .foregroundStyle(.gray)
                .frame(minWidth: 120, alignment: .trailing)
            Text(value)
        }
    }
}
#endif
