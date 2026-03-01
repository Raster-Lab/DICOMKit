// MainView.swift
// DICOMStudio
//
// DICOM Studio — Main application shell with NavigationSplitView

#if canImport(SwiftUI)
import SwiftUI

/// The main application view providing sidebar navigation and detail content.
///
/// Uses `NavigationSplitView` with three columns:
/// - Sidebar: Feature area list with icons
/// - Detail: Content for the selected feature area
@available(macOS 14.0, iOS 17.0, *)
public struct MainView: View {
    @Bindable var viewModel: MainViewModel

    public init(viewModel: MainViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            if let destination = viewModel.selectedDestination {
                detailView(for: destination)
            } else {
                ContentUnavailableView(
                    "Select a Feature",
                    systemImage: "sidebar.left",
                    description: Text("Choose a feature area from the sidebar to get started.")
                )
            }
        }
        .navigationTitle("DICOM Studio")
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.toggleInspector()
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .accessibilityLabel("Toggle Inspector")
                .help("Toggle Inspector Panel")
            }
        }
        #endif
    }

    @ViewBuilder
    private func detailView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .library:
            PlaceholderFeatureView(
                title: "DICOM Library",
                systemImage: "folder",
                description: "Import, browse, and search DICOM files organized by study, series, and instance."
            )
        case .viewer:
            PlaceholderFeatureView(
                title: "Image Viewer",
                systemImage: "photo",
                description: "View DICOM images with window/level controls, measurements, and multi-frame playback."
            )
        case .networking:
            PlaceholderFeatureView(
                title: "Networking Hub",
                systemImage: "network",
                description: "Connect to DICOM servers for C-ECHO, C-FIND, C-MOVE, C-GET, C-STORE, and DICOMweb operations."
            )
        case .reporting:
            PlaceholderFeatureView(
                title: "Structured Reporting",
                systemImage: "doc.text",
                description: "View, create, and edit DICOM Structured Reports with coded terminology."
            )
        case .tools:
            PlaceholderFeatureView(
                title: "Tools",
                systemImage: "wrench.and.screwdriver",
                description: "Data exchange, export, conversion, and developer tools for DICOM files."
            )
        case .cliWorkshop:
            PlaceholderFeatureView(
                title: "CLI Workshop",
                systemImage: "terminal",
                description: "Interactive GUI for all DICOMKit command-line tools with command builder and console."
            )
        case .settings:
            SettingsView(viewModel: SettingsViewModel(settingsService: viewModel.settingsService))
        }
    }
}

/// Placeholder view for feature areas not yet implemented.
@available(macOS 14.0, iOS 17.0, *)
struct PlaceholderFeatureView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(description)
        } actions: {
            Text("Coming in a future milestone")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
#endif
