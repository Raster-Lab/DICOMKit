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
            StudyBrowserView(viewModel: viewModel.studyBrowserViewModel)
                .id(NavigationDestination.library)
        case .viewer:
            ImageViewerView(viewModel: viewModel.imageViewerViewModel)
        case .networking:
            NetworkingView(viewModel: viewModel.networkingViewModel)
        case .dicomWeb:
            DICOMwebView(viewModel: viewModel.dicomWebViewModel)
        case .reporting:
            StructuredReportView(viewModel: StructuredReportViewModel())
        case .tools:
            DataExchangeView(viewModel: DataExchangeViewModel())
        case .cliWorkshop:
            CLIWorkshopView(viewModel: viewModel.cliWorkshopViewModel)
                .onAppear {
                    viewModel.cliWorkshopViewModel.savedServerProfiles = viewModel.networkingViewModel.serverProfiles
                }
        case .security:
            SecurityView(viewModel: SecurityViewModel())
        case .performanceTools:
            PerformanceToolsView(viewModel: PerformanceToolsViewModel())
        case .macOSEnhancements:
            MacOSEnhancementsView(viewModel: MacOSEnhancementsViewModel())
        case .polishRelease:
            PolishReleaseView(viewModel: PolishReleaseViewModel())
        case .fileOperations:
            FileOperationsView(viewModel: FileOperationsViewModel())
        case .integrationTesting:
            IntegrationTestingView(viewModel: IntegrationTestingViewModel())
        case .settings:
            SettingsView(viewModel: SettingsViewModel(settingsService: viewModel.settingsService))
        }
    }
}
#endif
