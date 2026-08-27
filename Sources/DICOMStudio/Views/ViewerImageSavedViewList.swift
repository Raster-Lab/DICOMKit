// ViewerImageSavedViewList.swift
// DICOMStudio
//
// DICOM Studio — the saved-views list that opens from the badge on the picture.
//
// The badge is where the reading is *changed*; arriving at the image needs no
// popup at all, because `offerSavedViewsIfNeeded` applies the image's first PR
// automatically (series-wide first). This list is for choosing a different
// view, or the default, by name — one click per row.
//
// Deliberately its own view, and deliberately plain.
//
// The badge over the centre panel used to open `SavedViewListPopover`, the same
// list the toolbar picker's popover shows. Sharing it looked like the tidy
// choice and was not: that view is presented three different ways, wears the
// app's shared hover modifier, and closes itself through the environment — and
// every one of those was a way for a change made elsewhere to stop this list
// working. Clicks stopped applying views more than once, from more than one
// cause, and each fix in the shared code traded the bug for another.
//
// So this list owns everything it needs and borrows nothing:
//
//  - Rows are plain `Button`s with their own `contentShape`. No
//    `.interactiveControl` / `.interactiveRow`: those carry a press-tracking
//    drag gesture and a stamped hit shape whose defaults are tuned for thirty
//    other controls, and a change made for any of them lands here.
//  - Hover is a local `@State` per row. Twelve lines, and it cannot be altered
//    from another screen.
//  - Closing goes through the binding the presenter owns, passed in. Nothing
//    here calls `dismiss()`, which does not clear a caller's `isPresented`
//    and so left the list standing open over an image it had already changed —
//    indistinguishable, on screen, from a click that never registered.
//
// The actions themselves are the view model's, unchanged: `applyDefaultView`,
// `applyDefaultViewForSeries` and `applySavedView(_:byHand:)` are the same
// calls the toolbar picker makes, so a view applied from here and one applied
// from there are the same act.

#if canImport(SwiftUI)
import SwiftUI
import DICOMPrintKit

/// The list the on-image badge opens: the default view, then every saved view
/// for this image, each applied by a single click.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct ViewerImageSavedViewList: View {

    @Bindable var viewModel: ImageViewerViewModel

    /// Closes the popover. Owned by whoever presented it — see the file note.
    let close: () -> Void

    /// The view awaiting delete confirmation, named in the alert so the reader
    /// can see which row they are about to lose.
    @State private var pendingDeletion: SavedView?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            header

            defaultViewRow

            if viewModel.canApplyDefaultViewForSeries && seriesHasSavedViews {
                seriesDefaultRow
            }

            if !savedViews.isEmpty {
                Divider().padding(.vertical, 4)

                ForEach(savedViews) { view in
                    savedViewRow(view)
                }
            }
        }
        .padding(8)
        .frame(minWidth: 260, alignment: .leading)
        .alert(
            "Delete “\(pendingDeletion?.label ?? "")”?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } })
        ) {
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let doomed = pendingDeletion {
                    viewModel.deleteSavedView(label: doomed.label)
                }
                pendingDeletion = nil
            }
        } message: {
            Text("The saved view is removed from every image it covers, along "
                 + "with its presentation states in the study's series. The "
                 + "images themselves are not changed.")
        }
    }

    // MARK: - Rows

    private var header: some View {
        Text("Saved views")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.bottom, 2)
    }

    /// Back to the image as the file describes it — this image alone.
    private var defaultViewRow: some View {
        SavedViewRow(
            label: viewModel.canApplyDefaultViewForSeries
                ? "\(ImageViewerViewModel.defaultViewLabel) — this image"
                : ImageViewerViewModel.defaultViewLabel,
            detail: nil,
            isSelected: viewModel.selectedPresentationStateLabel == nil,
            onDelete: nil
        ) {
            viewModel.applyDefaultView()
            close()
        }
    }

    /// The same statement about every image of the series.
    ///
    /// Offered only where it reaches further than the row above and where the
    /// series actually holds views to back out of — otherwise it is a no-op
    /// wearing the look of an action.
    private var seriesDefaultRow: some View {
        SavedViewRow(
            label: "\(ImageViewerViewModel.defaultViewLabel) — whole series",
            detail: nil,
            isSelected: false,
            onDelete: nil
        ) {
            Task { await viewModel.applyDefaultViewForSeries() }
            close()
        }
    }

    private func savedViewRow(_ view: SavedView) -> some View {
        SavedViewRow(
            label: view.label,
            detail: view.coveredImageCount > 1
                ? "\(view.coveredImageCount) images" : nil,
            isSelected: viewModel.selectedPresentationStateLabel == view.label,
            onDelete: { pendingDeletion = view }
        ) {
            // By hand: the reader picked this view, so it is an instruction
            // about every image the view covers, not just the slice on screen.
            // That is what makes a series view hold while stepping through it.
            viewModel.applySavedView(view, byHand: true)
            close()
        }
    }

    // MARK: - Reading the model

    private var savedViews: [SavedView] { viewModel.savedViewsForCurrentImage }

    /// Whether the series on screen has any saved views at all.
    ///
    /// Gates the series-wide revert: this list answers for the *image*, and an
    /// image can carry a view on a series that holds no others.
    private var seriesHasSavedViews: Bool {
        guard let uid = viewModel.currentSeriesUID else { return false }
        return viewModel.seriesHasSavedViews(uid)
    }
}

// MARK: - One row

/// A single clickable row: a checkmark slot, a name, an optional reach, and an
/// optional delete button.
///
/// Its own small view so the hover state is per row without the parent tracking
/// which row the pointer is on, and so the hit area is stated once, here, where
/// it can be read alongside the action it belongs to.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
private struct SavedViewRow: View {

    let label: String
    /// How far the view reaches, when that is worth saying ("4 images").
    let detail: String?
    let isSelected: Bool
    /// `nil` for the rows that are not deletable — the two default-view rows.
    let onDelete: (() -> Void)?
    let apply: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            // The row itself: everything but the trash can, so a click
            // anywhere along the name applies the view.
            Button(action: apply) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .opacity(isSelected ? 1 : 0)
                    Text(label)
                        .lineLimit(1)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                }
                // On the label, inside the button: an `HStack` is only as wide
                // as its content, so without this a click in the empty space
                // right of a short name falls through and does nothing. The
                // `Spacer` above gives it that space to cover.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(isHovering ? 1 : 0.35)
                .accessibilityLabel("Delete \(label)")
                .help("Delete this saved view")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        // The hover wash, drawn behind the row rather than by the shared
        // modifier — see the file note. `contentShape` before it so the whole
        // row reports hover, not just the text.
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isHovering ? Color.primary.opacity(0.12) : .clear))
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
#endif
