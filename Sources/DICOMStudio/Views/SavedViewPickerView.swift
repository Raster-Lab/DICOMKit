// SavedViewPickerView.swift
// DICOMStudio
//
// DICOM Studio — choosing between the default view and the reader's saved ones.
//
// A picture can be read more than one way: a chest CT at a lung window, then a
// bone window, then soft tissue. Those are not revisions of one another — they
// are three legitimate ways of looking at the same slice, and a reader wants to
// move between them without setting each up again.
//
// The picker is therefore a *list*, not a toggle. "Default view" is always the
// first entry and always available: it is the image as the file describes it,
// and a reader must never be unable to get back to it. Saved views follow,
// newest first, and only those covering the image on screen are shown — a view
// saved on other images has nothing to say about this one, and offering it
// would be offering a no-op.
//
// The control hides itself when the study has nothing saved and the current
// view is untouched: there is then only one thing to look at, and a picker
// naming it is furniture.

#if canImport(SwiftUI)
import SwiftUI
import DICOMPrintKit

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct SavedViewPickerView: View {
    @Bindable var viewModel: ImageViewerViewModel

    /// Shown while the reader names a view.
    @State private var isNaming = false
    @State private var draftLabel = ""

    /// The view the reader has asked to delete, held for confirmation.
    ///
    /// Deleting a saved view throws away work that took setting up, so it asks
    /// first — and names what it is about to remove, because the picker is a
    /// list and "are you sure?" alone does not say which row.
    @State private var pendingDeletion: SavedView?

    private var savedViews: [SavedView] { viewModel.savedViewsForCurrentImage }

    var body: some View {
        // Nothing saved and nothing worth saving: no control at all.
        if !savedViews.isEmpty || viewModel.canSaveCurrentView {
            HStack(spacing: 6) {
                picker
                saveButton
            }
            .alert("Name this view", isPresented: $isNaming) {
                TextField("View name", text: $draftLabel)
                Button("Cancel", role: .cancel) { draftLabel = "" }
                Button("Save") { commitSave() }
                    .disabled(trimmedDraft.isEmpty)
            } message: {
                Text("Saved views keep the window, zoom, pan and orientation "
                     + "of the image on screen. Saving over a name replaces it.")
            }
            .alert(
                "Delete “\(pendingDeletion?.label ?? "")”?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } })
            ) {
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
                Button("Delete", role: .destructive) {
                    if let pendingDeletion {
                        viewModel.deleteSavedView(label: pendingDeletion.label)
                    }
                    pendingDeletion = nil
                }
            } message: {
                Text("The saved view is removed from this study. The images "
                     + "themselves are not changed.")
            }
        }
    }

    // MARK: - Picker

    private var picker: some View {
        Menu {
            Button {
                viewModel.applyDefaultView()
            } label: {
                Label(
                    ImageViewerViewModel.defaultViewLabel,
                    systemImage: viewModel.selectedPresentationStateLabel == nil
                        ? "checkmark" : "")
            }

            if !savedViews.isEmpty {
                Divider()
                ForEach(savedViews) { view in
                    Button {
                        viewModel.applySavedView(view)
                    } label: {
                        Label(
                            view.label,
                            systemImage: viewModel.selectedPresentationStateLabel == view.label
                                ? "checkmark" : "")
                    }
                }

                Divider()
                Menu("Delete Saved View") {
                    ForEach(savedViews) { view in
                        Button(view.label, role: .destructive) {
                            pendingDeletion = view
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "rectangle.on.rectangle")
                Text(viewModel.selectedViewLabel)
                    .lineLimit(1)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Choose how this image is displayed")
    }

    // MARK: - Saving

    private var saveButton: some View {
        Button {
            // Offer the selected view's name, so adjusting a saved view and
            // saving again updates it rather than quietly making a second one.
            draftLabel = viewModel.selectedPresentationStateLabel ?? ""
            isNaming = true
        } label: {
            Image(systemName: "square.and.arrow.down")
        }
        .buttonStyle(.borderless)
        .disabled(!viewModel.canSaveCurrentView)
        .help(viewModel.canSaveCurrentView
              ? "Save the current window, zoom and orientation as a named view"
              : "Adjust the image before saving a view")
    }

    private var trimmedDraft: String {
        draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commitSave() {
        let label = trimmedDraft
        guard !label.isEmpty else { return }
        viewModel.saveCurrentView(label: label)
        draftLabel = ""
    }
}
#endif
