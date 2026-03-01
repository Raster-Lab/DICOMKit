// StudyBrowserView.swift
// DICOMStudio
//
// DICOM Studio — Study browser SwiftUI view

#if canImport(SwiftUI)
import SwiftUI

/// Study browser view displaying the Patient → Study → Series → Instance hierarchy.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
public struct StudyBrowserView: View {
    @Bindable var viewModel: StudyBrowserViewModel

    public init(viewModel: StudyBrowserViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            browserToolbar

            Divider()

            // Content
            if viewModel.library.studyCount == 0 {
                emptyLibraryView
            } else if viewModel.displayStudies.isEmpty {
                noResultsView
            } else {
                studyList
            }

            // Import progress
            if viewModel.isImporting, let progress = viewModel.importProgress {
                importProgressBar(progress: progress)
            }
        }
    }

    private var browserToolbar: some View {
        HStack {
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
            StudyRowView(
                study: study,
                seriesCount: viewModel.library.seriesForStudy(study.studyInstanceUID).count,
                instanceCount: viewModel.library.instancesForSeries(study.studyInstanceUID).count
            )
            .tag(study.studyInstanceUID)
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
    let seriesCount: Int
    let instanceCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(study.displayPatientName)
                    .font(.headline)
                Spacer()
                Text(study.displayStudyDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let desc = study.studyDescription, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack {
                Text(study.displayModalities)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())

                Spacer()

                Text(StudyBrowserHelpers.countBadge(
                    series: seriesCount,
                    instances: instanceCount
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(study.displayPatientName), \(study.displayStudyDate), \(study.displayModalities)")
    }
}
#endif
