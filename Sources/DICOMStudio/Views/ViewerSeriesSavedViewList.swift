// ViewerSeriesSavedViewList.swift
// DICOMStudio
//
// DICOM Studio — the presentation states a series' images carry, listed from
// the series pane's PR badge.
//
// The badge already said *that* a series has saved views. This says which
// images they are on and which objects they are: the reader asked to see, per
// image, the PR files available with their series and instance numbers.
//
// Grouped by *view*, not by image. A saved view written for a whole series is
// one decision the reader made once, stored as one PR object per slice — and
// listing it per slice turned that one decision into thirty-three identical
// rows, with the two views that are actually on a single image buried among
// them. So a view that covers the series is one line saying so, and only a view
// that covers part of it spends rows naming the images it is on. What a reader
// wants from this list is "which readings does this series carry, and where" —
// and the series-wide case answers "where" with a single word.
//
// Read-only on purpose. Applying a view is a decision about the image on
// screen, and this list is opened from a card that may not be the series being
// read — offering "apply" here would mean applying a view to an image the
// reader cannot see. Choosing a view stays where it already is: the badge on
// the picture (`ViewerImageSavedViewList`) and the toolbar picker.
//
// Self-contained for the same reason that list is — see its file note. Rows
// here are not even buttons, so there is nothing to share.

#if canImport(SwiftUI)
import SwiftUI

/// Lists one series' presentation states, grouped by the view they belong to.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct ViewerSeriesSavedViewList: View {

    /// The series being described, for the heading.
    let entry: ViewerSeriesEntry

    /// Its states, already ordered by image then view name.
    let references: [SavedViewReference]

    // MARK: - Grouping

    /// One group per view name, in the order its first state arrived.
    ///
    /// The grouping and the collapse rule live on ``SavedViewGroup`` rather
    /// than here — see its note. This view only decides how to draw them.
    private var groups: [SavedViewGroup] { SavedViewGroup.grouped(references) }

    /// Whether a group covers every image the series holds.
    private func coversWholeSeries(_ group: SavedViewGroup) -> Bool {
        group.coversWholeSeries(ofImageCount: entry.objectCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            if references.isEmpty {
                Text("No presentation states")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(groups) { group in
                            viewGroup(group)
                        }
                    }
                    .padding(12)
                }
                // Capped rather than sized to fit: a series carrying a
                // different view on every slice would otherwise open a popover
                // taller than the screen. The series-wide case now needs a
                // fraction of this, and the popover shrinks to it.
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 320)
    }

    // MARK: - Parts

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.spokenLabel)
                .font(.callout.bold())
                .lineLimit(2)
            Text(countLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    /// "2 saved views · 35 presentation states" — both counts, because the
    /// two are now plainly different things in this list: the views are the
    /// rows, and the states are the objects behind them.
    private var countLabel: String {
        let views = groups.count
        let states = references.count
        let viewWord = "saved view\(views == 1 ? "" : "s")"
        let stateWord = "presentation state\(states == 1 ? "" : "s")"
        return "\(views) \(viewWord) · \(states) \(stateWord)"
    }

    // MARK: - One view

    @ViewBuilder
    private func viewGroup(_ group: SavedViewGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            viewHeading(group)

            // A view spanning the series says so on its heading line and stops
            // there: thirty-three rows saying "this slice too" is the noise
            // this list was opened to avoid. The objects are still described —
            // their PR series number is on the heading — and the reader who
            // wants a particular slice's object has the on-image badge for it.
            if !coversWholeSeries(group) {
                ForEach(group.references) { reference in
                    row(reference)
                }
            }
        }
    }

    /// The view's name, its palette glyph, and where it reaches.
    private func viewHeading(_ group: SavedViewGroup) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: group.isColour
                  ? "paintpalette" : "slider.horizontal.below.rectangle")
                .font(.caption2)
                .foregroundStyle(Color.purple)
                .frame(width: 14)

            Text(group.label)
                .font(.caption.bold())
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(reachLabel(group))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.label), \(reachLabel(group))")
    }

    /// "Whole series · PR 9001" or "3 images" — how far the view reaches, and
    /// for the series-wide case which PR series its objects live in.
    ///
    /// The PR series number is worth stating only where the per-image rows are
    /// not: those rows carry it themselves. Stated only when every object of
    /// the group shares one, which a view saved in a single pass does — a view
    /// re-saved later has objects in two series and gets no number rather than
    /// a misleading one.
    private func reachLabel(_ group: SavedViewGroup) -> String {
        guard coversWholeSeries(group) else {
            let count = group.imageCount
            return "\(count) image\(count == 1 ? "" : "s")"
        }
        if let number = group.commonStateSeriesNumber {
            return "Whole series · PR \(number)"
        }
        return "Whole series"
    }

    /// One image the view is on, when the view covers only part of the series.
    private func row(_ reference: SavedViewReference) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "photo")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(reference.imageLocationLabel)
                .font(.caption)
                .lineLimit(1)

            Spacer(minLength: 4)

            // The object's own series and instance number — a presentation
            // state is its own series, so this is never the image's number and
            // the list states both rather than letting one stand for the other.
            Text(reference.stateLocationLabel)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(reference.imageLocationLabel), \(reference.stateLocationLabel)")
    }
}

#endif
