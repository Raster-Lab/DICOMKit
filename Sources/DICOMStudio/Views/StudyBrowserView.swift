// StudyBrowserView.swift
// DICOMStudio
//
// DICOM Studio — Study browser SwiftUI view

#if canImport(SwiftUI)
import SwiftUI
import UniformTypeIdentifiers

/// Study browser view displaying the Patient → Study → Series → Instance hierarchy.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct StudyBrowserView: View {
    @Bindable var viewModel: StudyBrowserViewModel

    /// Whether the "delete all studies" confirmation is showing.
    @State private var isConfirmingDeleteAll = false

    public init(viewModel: StudyBrowserViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            browserToolbar

            Divider()

            // Content
            if viewModel.library.studyCount == 0 && !viewModel.isImporting {
                emptyLibraryView
            } else if viewModel.displayStudies.isEmpty && !viewModel.isImporting {
                noResultsView
            } else {
                // The toggle in the toolbar chooses between them; until now it
                // changed only its own icon, because no grid existed to switch to.
                switch viewModel.displayMode {
                case .list: studyList
                case .grid: studyGrid
                }
            }

            // Import progress
            if viewModel.isImporting, let progress = viewModel.importProgress {
                importProgressBar(progress: progress)
            }

            // Error banner — shown when the last operation failed.
            if let error = viewModel.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.lastError = nil
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                .padding(8)
                .background(.red.opacity(0.1))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Import error: \(error)")
            }
        }
        .fileImporter(
            isPresented: $viewModel.isFileImporterPresented,
            allowedContentTypes: [.data, .folder],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.handleImportedURLs(urls)
            case .failure(let error):
                viewModel.lastError = "File import failed: \(error.localizedDescription)"
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            viewModel.handleImportedURLs(urls)
            return true
        }
        .confirmationDialog(
            "Delete all \(viewModel.library.studyCount) imported studies?",
            isPresented: $isConfirmingDeleteAll,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) {
                viewModel.removeAllStudies()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes them from the library only — the DICOM files stay on disk.")
        }
    }

    private var browserToolbar: some View {
        HStack {
            // Import button
            Button {
                viewModel.showFileImporter()
            } label: {
                Image(systemName: "plus")
                    .accessibilityLabel("Import DICOM files")
            }

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search studies...", text: $viewModel.filter.searchText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search studies")
                if !viewModel.filter.searchText.isEmpty {
                    Button {
                        viewModel.filter.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(6)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Spacer()

            // Sort menu
            Menu {
                ForEach(StudySortField.allCases, id: \.self) { field in
                    Button {
                        if viewModel.sortField == field {
                            viewModel.toggleSortDirection()
                        } else {
                            viewModel.sortField = field
                        }
                    } label: {
                        HStack {
                            Text(field.displayName)
                            if viewModel.sortField == field {
                                Image(systemName: viewModel.sortDirection == .ascending
                                    ? "chevron.up" : "chevron.down")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .accessibilityLabel("Sort options")
            }

            // Display mode toggle
            Button {
                viewModel.toggleDisplayMode()
            } label: {
                Image(systemName: viewModel.displayMode.systemImage)
                    .accessibilityLabel(viewModel.displayMode.accessibilityLabel)
            }

            // Delete all imported studies
            Button {
                isConfirmingDeleteAll = true
            } label: {
                Image(systemName: "trash")
                    .accessibilityLabel("Delete all imported studies")
            }
            .disabled(viewModel.library.studyCount == 0 || viewModel.isImporting)
            .help("Delete all imported studies from the library")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyLibraryView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No DICOM Files")
                .font(.title2)
            Text("Import DICOM files to get started")
                .foregroundStyle(.secondary)
            Button("Import Files...") {
                viewModel.showFileImporter()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Import DICOM files")
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Empty library. Import DICOM files to get started.")
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No matching studies")
                .font(.headline)
            Button("Clear Filters") {
                viewModel.clearFilters()
            }
            .accessibilityLabel("Clear all filters")
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var studyList: some View {
        List(viewModel.displayStudies, selection: $viewModel.selectedStudyUID) { study in
            // Everything the row says is derived from the study *and* the series
            // and instances under it, so a study whose own header is bare still
            // shows what it is. Instances are counted across the whole study;
            // this used to ask for the instances of a *series* with a study UID,
            // which matches nothing — so every row read "0 images".
            StudyRowView(
                study: study,
                summary: StudyRowSummary.make(study: study, library: viewModel.library),
                isSelected: viewModel.selectedStudyUID == study.studyInstanceUID
            )
            .tag(study.studyInstanceUID)
            .contentShape(Rectangle())
            // Double-click opens the study, which is what a list of studies is
            // for. Single click selects it — and must be handled here: the
            // double-click gesture on the row swallows the click the List would
            // otherwise have used to move its selection, which left clicking a
            // study doing nothing visible at all.
            .onTapGesture {
                viewModel.selectedStudyUID = study.studyInstanceUID
            }
            .onTapGesture(count: 2) {
                viewModel.openStudyInViewer(study.studyInstanceUID)
            }
            .contextMenu { studyActions(study) }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    viewModel.removeStudy(study.studyInstanceUID)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    viewModel.toggleFavorite(study.studyInstanceUID)
                } label: {
                    Label(
                        study.isFavorite ? "Unfavorite" : "Favorite",
                        systemImage: study.isFavorite ? "star.slash" : "star.fill"
                    )
                }
                .tint(.yellow)
            }
        }
    }

    /// The same studies as cards, for scanning a library by eye rather than by
    /// reading rows.
    private var studyGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(viewModel.displayStudies) { study in
                    StudyCardView(
                        study: study,
                        summary: StudyRowSummary.make(study: study,
                                                      library: viewModel.library),
                        isSelected: viewModel.selectedStudyUID == study.studyInstanceUID
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.selectedStudyUID = study.studyInstanceUID }
                    .onTapGesture(count: 2) {
                        viewModel.openStudyInViewer(study.studyInstanceUID)
                    }
                    .contextMenu { studyActions(study) }
                }
            }
            .padding(12)
        }
    }

    /// The actions a study offers, shared by the row and the card so the two
    /// modes cannot drift into offering different things.
    @ViewBuilder
    private func studyActions(_ study: StudyModel) -> some View {
        Button {
            viewModel.openStudyInViewer(study.studyInstanceUID)
        } label: {
            Label("Open in Viewer", systemImage: "photo")
        }
        Button {
            viewModel.printStudy(study.studyInstanceUID)
        } label: {
            Label("Print…", systemImage: "printer")
        }
        Divider()
        Button {
            viewModel.toggleFavorite(study.studyInstanceUID)
        } label: {
            Label(study.isFavorite ? "Unfavorite" : "Favorite",
                  systemImage: study.isFavorite ? "star.slash" : "star.fill")
        }
        Button(role: .destructive) {
            viewModel.removeStudy(study.studyInstanceUID)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func importProgressBar(progress: ImportProgress) -> some View {
        VStack(spacing: 4) {
            ProgressView(value: progress.fractionComplete)
                .accessibilityLabel("Import progress")
                .accessibilityValue("\(Int(progress.fractionComplete * 100)) percent")
            Text(progress.statusDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
    }
}

/// Row view for a single study in the browser.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct StudyRowView: View {
    let study: StudyModel
    let summary: StudyRowSummary

    /// Whether this is the study the browser is pointed at.
    ///
    /// Drawn by the row itself rather than left to the List's own selection
    /// highlight: the row handles its own clicks (single to select, double to
    /// open), so the List never sees the click that would have highlighted it.
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(summary.patientName)
                    .font(.headline)
                Spacer()
                Text(summary.studyDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Always present, even when nothing describes the study: a row that
            // silently drops a line reads as a study whose data failed to
            // import, and "No description" is itself information.
            Text(summary.description ?? "No description")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack {
                Text(summary.modalities)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())

                Spacer()

                Text(summary.counts)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(isSelected ? StudioColors.selectionFill : .clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? StudioColors.selectionBorder : .clear,
                              lineWidth: 1.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(summary.patientName), \(summary.studyDate), \(summary.modalities), "
            + summary.counts)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Card view for a single study, used by the grid display mode.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
struct StudyCardView: View {
    let study: StudyModel
    let summary: StudyRowSummary
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(systemName: "square.stack.3d.up")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
                if study.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }

            Text(summary.patientName)
                .font(.headline)
                .lineLimit(1)

            // A grid of cards of different heights is hard to scan, so the line
            // is kept even when nothing describes the study.
            Text(summary.description ?? "No description")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(summary.studyDate)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text(summary.modalities)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
                Spacer()
                Text(summary.counts)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Same selection colours as the list row: the two modes show the same
        // library, so selection must not look like a different thing in each.
        .background(isSelected ? StudioColors.selectionFill : Color.gray.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? StudioColors.selectionBorder : .clear,
                              lineWidth: 1.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(summary.patientName), \(summary.studyDate), "
                            + "\(summary.modalities), \(summary.counts)")
        .accessibilityHint("Double-click to open in the viewer")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#endif
