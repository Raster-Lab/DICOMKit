// ViewerPrintTrayView.swift
// DICOMStudio
//
// DICOM Studio — the viewer's tray of selected images.
//
// Marking is scattered across a reading session: a tile here, a frame there, a
// whole series at once. The tray is the answer to "what have I actually picked?"
// — the selection in film order, one image per row, without opening the print
// sheet. Clicking a row brings that image back on screen; the cross takes it off
// the film.

#if canImport(SwiftUI)
import SwiftUI

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct ViewerPrintTrayView: View {
    @Bindable var viewModel: ImageViewerViewModel

    #if canImport(CoreGraphics)
    /// One thumbnail per mark, rendered with that mark's own window and
    /// arrangement — the tray shows what will print, not the untouched frame.
    @State private var thumbnails = PrintThumbnailCache()
    #endif

    var body: some View {
        VStack(spacing: 0) {
            header

            if viewModel.printSelection.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(viewModel.printSelection.items.enumerated()),
                                id: \.element.id) { position, item in
                            row(item, position: position)
                        }
                    }
                    .padding(8)
                }
            }
        }
        // The pane surface, matching the series pane and seamed against the
        // gutter on the left: the framed images between the two panes are the
        // only pure black, so the eye lands there and not on the tray.
        .viewerPaneSurface(imageEdge: .leading)
        #if canImport(CoreGraphics)
        .onAppear { thumbnails.refresh(for: viewModel.printSelection.items) }
        .onChange(of: viewModel.printSelection.items) { _, items in
            thumbnails.refresh(for: items)
        }
        #endif
    }

    // MARK: - Chrome

    /// "On film", not "Selected": the tray is the film's running order, and the
    /// word says what the count means without the reader having to ask what a
    /// selection in this particular column selects.
    private var header: some View {
        ViewerPaneHeader("On film",
                         systemImage: "printer",
                         count: viewModel.printSelection.count) {
            if !viewModel.printSelection.isEmpty {
                Button("Clear") { viewModel.clearAllPrintMarks() }
                    .controlSize(.mini)
                    .help("Unmark every image")
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.rectangle.stack")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.25))
            Text("No images selected")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            Text("Tick an image to add it here")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - One selected image

    @ViewBuilder
    private func row(_ item: PrintSelectionItem, position: Int) -> some View {
        let isOnScreen = item.filePath == viewModel.filePath
            && item.frameIndex == viewModel.currentFrameIndex

        VStack(spacing: 4) {
            thumbnail(item)
                .frame(height: 92)
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(alignment: .topLeading) {
                    // Film position: the tray is in the order the images print.
                    Text("\(position + 1)")
                        .font(.caption2.monospacedDigit().bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.6), in: Capsule())
                        .padding(4)
                }
                .overlay(alignment: .topTrailing) {
                    Button {
                        viewModel.printSelection.remove(
                            filePath: item.filePath, frameIndex: item.frameIndex)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                    .help("Remove this image from the selection")
                    .accessibilityLabel("Remove image \(position + 1) from the selection")
                }

            Text(item.displayLabel)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(6)
        .background(isOnScreen ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isOnScreen ? Color.accentColor : .clear, lineWidth: 2)
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.showMarkedImage(item) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Selected image \(position + 1): \(item.displayLabel)"
                            + (isOnScreen ? ", on screen" : ""))
        .accessibilityHint("Click to show this image in the viewer")
    }

    @ViewBuilder
    private func thumbnail(_ item: PrintSelectionItem) -> some View {
        #if canImport(CoreGraphics)
        if let image = thumbnails.image(for: item) {
            Image(decorative: image, scale: 1.0, orientation: .up)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if thumbnails.didFail(item) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        } else {
            ProgressView().controlSize(.small)
        }
        #else
        Color.black
        #endif
    }
}
#endif
