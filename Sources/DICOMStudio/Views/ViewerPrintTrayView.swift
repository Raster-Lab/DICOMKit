// ViewerPrintTrayView.swift
// DICOMStudio
//
// DICOM Studio — the viewer's tray of selected images.
//
// Marking is scattered across a reading session: a tile here, a frame there, a
// whole series at once. The tray is the answer to "what have I actually picked?"
// — the selection in film order, one image per row, without opening the print
// sheet. The tray only *reports*: clicking a row changes nothing in the reading
// area — re-hanging the viewer under a reader who only meant to glance at the
// film order is how a carefully arranged screen gets torn down by accident. The
// cross takes an image off the film, and that is the tray's one verb.

#if canImport(SwiftUI)
import SwiftUI

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct ViewerPrintTrayView: View {
    @Bindable var viewModel: ImageViewerViewModel

    #if canImport(CoreGraphics)
    /// One thumbnail per mark, rendered as the image was marked.
    @State private var thumbnails = PrintThumbnailCache()
    #endif

    /// The marks as the tray shows them: the images as they were picked.
    ///
    /// Work done on the film is the film's. The print screen writes its tool
    /// edits into the marks themselves (that is what the printer reads), and the
    /// tray sits beside that screen on macOS — so windowing a cell there used to
    /// re-render its row here, one flicker per mouse event, reporting an
    /// arrangement the reader made somewhere else entirely. The tray answers
    /// "what have I picked?", and the answer does not change because a cell was
    /// zoomed on the film. Adjustments are dropped for display only; the marks
    /// keep them, and the film keeps printing them.
    private var trayItems: [PrintSelectionItem] {
        viewModel.printSelection.itemsAsMarked
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if viewModel.printSelection.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(trayItems.enumerated()),
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
        .onAppear { thumbnails.refresh(for: trayItems) }
        // Keyed on the as-marked images, so a film-screen tool edit — which
        // changes the live mark but not how it was marked — does not queue a
        // re-render here.
        .onChange(of: trayItems) { _, items in
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Selected image \(position + 1): \(item.displayLabel)"
                            + (isOnScreen ? ", on screen" : ""))
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
