// SidebarView.swift
// DICOMStudio
//
// DICOM Studio — Sidebar navigation view

#if canImport(SwiftUI)
import SwiftUI

/// Sidebar navigation listing all feature areas.
@available(macOS 14.0, iOS 17.0, *)
struct SidebarView: View {
    @Bindable var viewModel: MainViewModel

    var body: some View {
        List(selection: $viewModel.selectedDestination) {
            Section("Features") {
                ForEach(viewModel.filteredDestinations) { destination in
                    NavigationLink(value: destination) {
                        Label(destination.rawValue, systemImage: destination.systemImage)
                    }
                    .accessibilityLabel(destination.accessibilityLabel)
                }
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
}
#endif
