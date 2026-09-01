// SavedViewPromptView.swift
// DICOMStudio
//
// DICOM Studio — asking, on open, which reading of an image to show.
//
// A saved view is work: a reader set a window, framed the anatomy, maybe drew
// on it, and named the result. The picker in the toolbar lets them get back to
// it — but only if they remember it exists. An image opened a week later shows
// the file's own view and says nothing, and the saved reading is lost to the
// reader who saved it.
//
// So an image that has saved views asks, at the moment the answer is free:
// straight after the load, before anything has been adjusted. The list is the
// same one the picker shows — the views covering *this* image — with the
// default view as an equal choice rather than a cancel button, because "show me
// the file's own view" is a real answer and not a refusal to answer.
//
// One click on a row is the whole interaction: the row is the action, so there
// is no Apply to press afterwards and no Show Default View, which was only ever
// the first row said a second way.
//
// Asked on every arrival at the image, however the reader gets there — scrolling
// the series, stepping a frame, opening it from the library. Which reading a
// reader wants is a question about this visit, not a preference set once; see
// `offerSavedViewsIfNeeded`.
//
// CURRENTLY HELD — nothing presents this sheet. Opening an image with saved
// views now applies the best one directly (`offerSavedViewsIfNeeded` applies
// the series-wide view when the series has one, else the image's first) and
// the on-image badge steps through the others and the default view, so no
// dialog stands between the reader and the picture. Kept, not deleted, in
// case an explicit prompt is wanted again.

#if canImport(SwiftUI)
import SwiftUI
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct SavedViewPromptView: View {
    @Bindable var viewModel: ImageViewerViewModel

    /// The question being asked. The sheet is only built when this is non-nil.
    let prompt: ImageViewerViewModel.SavedViewPrompt

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            list
        }
        .padding(20)
        .frame(minWidth: 380, maxWidth: 460)
    }

    // MARK: - Parts

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(prompt.views.count == 1
                 ? "A saved view exists for this image"
                 : "\(prompt.views.count) saved views exist for this image")
                .font(.headline)
            Text("Click one to open it. The default view is the image as the "
                 + "file describes it; a saved view restores the window, zoom, "
                 + "orientation and anything drawn on it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var list: some View {
        // A List of actions rather than a selectable list: one click on a row
        // opens that reading, so there is nothing to hold a selection for.
        List {
            row(label: ImageViewerViewModel.defaultViewLabel,
                detail: "The image as stored",
                symbol: "photo",
                tag: nil)
            ForEach(prompt.views) { view in
                row(label: view.label,
                    detail: Self.detail(for: view),
                    symbol: "slider.horizontal.below.rectangle",
                    tag: view.label)
            }
        }
        .listStyle(.plain)
        .frame(height: rowsHeight)
    }

    private func row(
        label: String, detail: String?, symbol: String, tag: String?
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        // The row is selectable across its whole width, not just under the
        // text: an HStack is only as wide as what is in it, so without this the
        // hit area stopped at the end of the label and a click in the empty
        // space to its right fell through to the List and selected nothing.
        .frame(maxWidth: .infinity, alignment: .leading)
        // Padding moved off the List and onto the row, so the shape below spans
        // the whole row rect rather than stopping inside the default insets.
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .listRowInsets(EdgeInsets())
        // The row *is* the action: one click opens that reading and the sheet
        // goes. There is no second step to confirm, so there is no selected
        // state to show — the hover fill is what says a row is live.
        .interactiveRow(cornerRadius: 5)
        .onTapGesture { apply(tag: tag) }
    }

    // MARK: - Behaviour

    /// Opens the clicked row's reading and closes the sheet.
    private func apply(tag: String?) {
        guard let tag,
              let view = prompt.views.first(where: { $0.label == tag })
        else {
            // The default row: the same answer the escape route gave — leave
            // the image as it loaded, and record that it was answered.
            viewModel.dismissSavedViewPrompt()
            return
        }
        viewModel.acceptSavedViewPrompt(view)
    }

    /// Height for the list: every row visible up to a point, then it scrolls.
    ///
    /// A study read a dozen ways would otherwise grow the sheet past the window.
    private var rowsHeight: CGFloat {
        let rows = min(prompt.views.count + 1, 6)
        return CGFloat(rows) * 38 + 8
    }

    /// The line under a saved view's name: when it was saved, and whether it
    /// carries drawings — the two things that distinguish two windows of the
    /// same slice from one another in a list of names the reader chose.
    private static func detail(for view: SavedView) -> String? {
        var parts: [String] = []
        if let created = view.created {
            parts.append(created.formatted(date: .abbreviated, time: .shortened))
        }
        let drawn = view.states.reduce(0) { $0 + $1.annotations.count }
        if drawn > 0 {
            parts.append(drawn == 1 ? "1 annotation" : "\(drawn) annotations")
        }
        // A view saved over a series reads the same as one saved on this image
        // alone; its reach is the difference worth stating.
        if view.coveredImageCount > 1 {
            parts.append("covers \(view.coveredImageCount) images")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
#endif
