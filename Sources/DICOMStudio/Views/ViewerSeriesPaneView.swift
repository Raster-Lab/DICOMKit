// ViewerSeriesPaneView.swift
// DICOMStudio
//
// DICOM Studio — the viewer's series pane.
//
// Who the patient is at the top, then every series of the open study as a card:
// a thumbnail, what it is, how much of it there is, and whether it has been
// looked at yet. Clicking a card shows that series; dragging it onto a tile
// hangs it there.
//
// Not every series is pictures. Reports, encapsulated documents and presentation
// states are listed too, with the symbol for what they hold in place of a
// thumbnail that could never be rendered.

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
        VStack(spacing: 0) {
            patientBanner

            Divider().overlay(Color.white.opacity(0.15))

            seriesList
        }
        // Chrome grey, not near-black: the image beside it is the pure black on
        // screen, and a pane at the same tone would read as a third viewport.
        .background(StudioColors.viewerChrome)
    }

    // MARK: - Who this is

    /// Patient and study identification, above the series.
    ///
    /// The pane is the one part of the viewer that is always on screen while
    /// reading, so it is where "whose study am I in?" belongs — the image
    /// overlay answers it per picture, this answers it for the session.
    @ViewBuilder
    private var patientBanner: some View {
        let text = viewModel.patientOverlayText
        if text.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 3) {
                // Who this is and what made the pictures, in the largest type in
                // the pane: it is the one thing a reader must never have to
                // squint at, and it is checked far more often than any series
                // description.
                if !viewModel.patientIdentityLine.isEmpty {
                    Text(viewModel.patientIdentityLine)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                }
                // Description then date, each on its own line and each in the
                // same lit type as the name: run together on one line they read
                // as a caption, which is not what identification is for.
                if let description = viewModel.studyDescriptionSanitizedForOverlay {
                    Text(description)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                if let date = viewModel.studyDateForOverlay {
                    Text(date)
                        .font(.callout.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                if let protocolLine = viewModel.protocolLineForOverlay {
                    Text(protocolLine)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            // The identification is lit, not just written: a tinted plate under
            // it separates whose study this is from the list of series below it
            // at a glance, without a rule that would read as another divider.
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1)
                    )
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            )
            .textSelection(.enabled)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Patient: \(viewModel.patientIdentityLine). "
                + [viewModel.studyDescriptionSanitizedForOverlay, viewModel.studyDateForOverlay]
                    .compactMap { $0 }.joined(separator: ". "))
        }
    }

    private var seriesList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.studySeries) { entry in
                    card(entry)
                }
            }
            .padding(8)
        }
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
                .overlay(alignment: .topLeading) {
                    // The series number, which is how the pane is ordered and how
                    // a reader refers to a series aloud.
                    if let number = entry.seriesNumberLabel {
                        Text(number)
                            .font(.caption2.monospacedDigit().bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.6), in: Capsule())
                            .padding(4)
                    }
                }

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
        // A click shows the series, from its first image. Reading is a matter of
        // moving between series constantly, so it is one click, not two; the
        // double-click and the drag still work for anyone expecting them.
        .onTapGesture {
            viewModel.selectSeries(entry.seriesInstanceUID)
        }
        .onTapGesture(count: 2) {
            viewModel.selectSeries(entry.seriesInstanceUID)
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
            "\(entry.spokenLabel), \(entry.countsLabel), \(entry.orientationLabel)"
            + (isCurrent ? ", current series" : ""))
        .accessibilityHint("Click to show this series in the selected tile")
    }

    @ViewBuilder
    private func thumbnail(_ entry: ViewerSeriesEntry) -> some View {
        // A report or a document has no frame to render, so the card shows what
        // it holds instead of spinning forever on a thumbnail that cannot exist.
        if !entry.isImageSeries {
            VStack(spacing: 4) {
                Image(systemName: entry.contentKind.symbolName)
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.75))
                Text(entry.contentKind.displayName)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
        } else {
            imageThumbnail(entry)
        }
    }

    @ViewBuilder
    private func imageThumbnail(_ entry: ViewerSeriesEntry) -> some View {
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
            guard entry.isImageSeries else { return nil }
            return entry.firstFilePath.map { FrameImageStore.Request(path: $0) }
        })
    }
    #endif
}
#endif
