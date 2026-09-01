// ImageMetadataPanelView.swift
// DICOMStudio
//
// DICOM Studio — what the open image is made of, as a panel.
//
// This is the metadata block that used to be drawn into the picture's
// bottom-left corner. That corner is not free: the reading annotations put the
// zoom, the image number, the compression and the slice geometry there, so
// switching metadata on covered the lines a reader reads the image by with a
// second block saying something else. The two were never meant to share a
// corner — one is how the image is being *read*, the other is how the file is
// *built* — and the second belongs in the same kind of panel the tag inspector
// already uses.
//
// So the block is unchanged in what it says and where it says it: same rows, in
// the same order, in the same monospaced type a reader compares two files by.
// Only the surface it is drawn on is different.

#if canImport(SwiftUI)
import SwiftUI

/// The open image's pixel metadata, in a panel over the viewer.
///
/// Dimensions, bit depth, pixel representation, photometric interpretation,
/// transfer syntax, samples per pixel, frame and window — the facts about how
/// the pixels are stored, as opposed to what they show.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct ImageMetadataPanelView: View {
    let viewModel: ImageViewerViewModel

    @Environment(\.dismiss) private var dismiss

    public init(viewModel: ImageViewerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // The tag inspector's header, to the point: two panels that answer
            // "what is this file" should be dismissed by the same button in the
            // same place.
            HStack {
                Text("Image Metadata")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if let path = viewModel.filePath {
                        filePathRow(path: path)
                    }
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
                        label: "Transfer Syntax",
                        value: viewModel.transferSyntaxLabel
                    )
                    metadataRow(
                        label: "Samples/Pixel",
                        value: ImageMetadataHelpers.samplesText(
                            samplesPerPixel: viewModel.samplesPerPixel,
                            planarConfiguration: viewModel.planarConfiguration
                        )
                    )
                    if viewModel.isMultiFrame {
                        metadataRow(label: "Frame", value: viewModel.frameText)
                    }
                    metadataRow(label: "W/L", value: viewModel.windowLevelText)
                }
                .font(.system(size: StudioTypography.captionSize, design: .monospaced))
                // Selectable throughout, which the corner block could not
                // usefully be: a transfer syntax UID or a file path is copied
                // into a bug report far more often than it is read aloud.
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        }
        .frame(minWidth: 460, minHeight: 300)
        .accessibilityLabel("Image metadata")
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label + ":")
                .foregroundStyle(.secondary)
                .frame(minWidth: 170, alignment: .trailing)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func filePathRow(path: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("File:")
                .foregroundStyle(.secondary)
                .frame(minWidth: 170, alignment: .trailing)
            // Wrapped rather than middle-truncated. The corner block truncated
            // because it had one line's width to spend; a panel has room for
            // the whole path, and a path that is half-shown is a path that has
            // to be opened somewhere else to be read.
            Text(path)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(path)
        }
    }
}
#endif
