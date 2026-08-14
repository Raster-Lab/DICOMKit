// SidebarView.swift
// DICOMStudio
//
// DICOM Studio — Sidebar navigation view

#if canImport(SwiftUI)
import SwiftUI

/// Sidebar navigation listing feature areas grouped into collapsible
/// categories.
///
/// DICOM Studio is imaging-first: the Imaging group is expanded on launch
/// while Network, Data & Tools, and System start collapsed — so the sidebar
/// reads as a viewer with supporting tools rather than a flat list of
/// sixteen equal features. Running a search forces every group open so
/// matches are never hidden behind a collapsed section.
@available(macOS 14.0, iOS 17.0, *)
struct SidebarView: View {
    @Bindable var viewModel: MainViewModel

    var body: some View {
        List(selection: $viewModel.selectedDestination) {
            ForEach(NavigationCategory.allCases) { category in
                let items = viewModel.filteredDestinations(in: category)
                if !items.isEmpty {
                    Section(category.rawValue, isExpanded: expanded(category)) {
                        ForEach(items) { destination in
                            NavigationLink(value: destination) {
                                Label(label(for: destination),
                                      systemImage: destination.systemImage)
                            }
                            .accessibilityLabel(accessibilityLabel(for: destination))
                        }
                    }
                }
            }

            // Network Utility stands outside the category groups — it is a
            // general (non-DICOM) diagnostics tool, so it gets its own
            // top-level entry rather than living under "Data & Tools".
            Section {
                NavigationLink(value: NavigationDestination.networkUtility) {
                    Label(NavigationDestination.networkUtility.rawValue,
                          systemImage: NavigationDestination.networkUtility.systemImage)
                }
                .accessibilityLabel(NavigationDestination.networkUtility.accessibilityLabel)
            }

            Section {
                NavigationLink(value: NavigationDestination.settings) {
                    Label("Settings", systemImage: "gear")
                }
                .accessibilityLabel(NavigationDestination.settings.accessibilityLabel)
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search features")
        .navigationTitle("DICOM Studio")
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        #endif
    }

    /// The row's text. Most destinations are simply their own name; Print also
    /// says what its queue is doing, since a job runs on regardless of which
    /// screen is open and a stalled or failed queue is otherwise invisible from
    /// here.
    private func label(for destination: NavigationDestination) -> String {
        guard destination == .printing,
              let state = printQueueState else { return destination.displayName }
        return "\(destination.displayName) — \(state)"
    }

    /// Spells the row out for VoiceOver: the destination's full description,
    /// plus the queue state when there is one.
    private func accessibilityLabel(for destination: NavigationDestination) -> String {
        guard destination == .printing,
              let state = printQueueState else { return destination.accessibilityLabel }
        return "\(destination.accessibilityLabel) — \(state)"
    }

    private var printQueueState: String? {
        viewModel.printViewModel.queue.activitySummary
    }

    /// Disclosure binding for one category. While a search is active the
    /// getter reports `true` for every category so no match stays hidden
    /// behind a collapsed section.
    private func expanded(_ category: NavigationCategory) -> Binding<Bool> {
        Binding(
            get: {
                guard viewModel.searchText.isEmpty else { return true }
                return viewModel.expandedCategories.contains(category)
            },
            set: { isOpen in
                if isOpen {
                    viewModel.expandedCategories.insert(category)
                } else {
                    viewModel.expandedCategories.remove(category)
                }
            }
        )
    }
}
#endif
