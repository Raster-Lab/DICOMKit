// ViewerSeriesPaneView.swift
// DICOMStudio
//
// DICOM Studio — the viewer's series pane.
//
// Lists every series of the open study as a card: a thumbnail, what it is, how
// much of it there is, and whether it has been looked at yet. A series is hung
// in a tile by dragging its card onto the tile, or by selecting a tile and
// double-clicking the card.

#if canImport(SwiftUI)
import SwiftUI
import UniformTypeIdentifiers

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct ViewerSeriesPaneView: View {
    @Bindable var viewModel: ImageViewerViewModel

    #if canImport(CoreGraphics)
    /// One thumbnail per series — the series' first instance, unarranged.
    @State private var thumbnails = FrameImageStore(maxDimension: 256)
    #endif

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.studySeries) { entry in
                    card(entry)
                }
            }
            .padding(8)
        }
        .background(.black.opacity(0.35))
        #if canImport(CoreGraphics)
        .onAppear { refreshThumbnails() }
        .onChange(of: viewModel.studySeries) { _, _ in refreshThumbnails() }
        #endif
    }

    // MARK: - One series

    @ViewBuilder
    private func card(_ entry: ViewerSeriesEntry) -> some View {
        let isCurrent = viewModel.isCurrentSeries(entry.seriesInstanceUID)

        VStack(spacing: 6) {
            thumbnail(entry)
                .frame(height: 110)
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            if isCurrent {
                Label("Current series", systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }

            Text(entry.title)
                .font(.callout.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(entry.countsLabel)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Text(entry.orientationLabel)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))

            if !viewModel.isSeriesVisited(entry.seriesInstanceUID) {
                Label("Not yet visited", systemImage: "circle")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(isCurrent ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isCurrent ? Color.accentColor : .clear, lineWidth: 2)
        }
        .contentShape(Rectangle())
        // Double-click hangs the series in whichever tile is selected — the
        // keyboard-and-mouse alternative to dragging.
        .onTapGesture(count: 2) {
            viewModel.assignSeriesToFocusedCell(entry.seriesInstanceUID)
        }
        // The drag payload is the Series Instance UID, which is all a tile needs
        // to look the series up again.
        .draggable(entry.seriesInstanceUID) {
            Text(entry.title)
                .font(.caption)
                .padding(6)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
        }
        .contextMenu {
            Button("Open in Selected Tile") {
                viewModel.assignSeriesToFocusedCell(entry.seriesInstanceUID)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(entry.title), \(entry.countsLabel), \(entry.orientationLabel)"
            + (isCurrent ? ", current series" : "")
            + (viewModel.isSeriesVisited(entry.seriesInstanceUID) ? "" : ", not yet visited"))
        .accessibilityHint("Double-click to show in the selected tile")
    }

    @ViewBuilder
    private func thumbnail(_ entry: ViewerSeriesEntry) -> some View {
        #if canImport(CoreGraphics)
        if let path = entry.firstFilePath {
            let key = FrameImageStore.Request(path: path).key
            if let image = thumbnails.image(forKey: key) {
                Image(decorative: image, scale: 1.0, orientation: .up)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if thumbnails.didFail(key) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else {
                ProgressView().controlSize(.small)
            }
        } else {
            Image(systemName: "square.dashed")
                .foregroundStyle(.white.opacity(0.2))
        }
        #else
        Color.black
        #endif
    }

    #if canImport(CoreGraphics)
    private func refreshThumbnails() {
        thumbnails.refresh(viewModel.studySeries.compactMap { entry in
            entry.firstFilePath.map { FrameImageStore.Request(path: $0) }
        })
    }
    #endif
}
#endif
