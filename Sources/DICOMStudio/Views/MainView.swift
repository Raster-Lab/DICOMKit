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

    /// The shell owns the split's column visibility so the sidebar is ALWAYS shown
    /// on launch. Without this, NavigationSplitView is free to drop to `.detailOnly`
    /// whenever a detail view (e.g. the wide CLI Parity / network forms) demands more
    /// width than the window can spare — and macOS then persists that collapsed state,
    /// so the navigation sidebar goes missing on the landing page across launches.
    /// Defaulting to `.all` (and pinning the sidebar's column width in SidebarView)
    /// keeps it visible while leaving the toolbar toggle free to collapse it on demand.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public init(viewModel: MainViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
        case .volumeViewer:
            DICOMVolumeViewerView(viewModel: viewModel.volumeViewerViewModel)
        case .jp3dComparison:
            JP3DComparisonView(viewModel: viewModel.jp3dComparisonViewModel)
        case .aiAnalysis:
            AIAnalysisView(viewModel: viewModel.aiAnalysisViewModel)
        case .networking:
            NetworkingView(viewModel: viewModel.networkingViewModel)
        case .dicomWeb:
            DICOMwebView(viewModel: viewModel.dicomWebViewModel)
        case .cloudIntegration:
            CloudIntegrationView(viewModel: viewModel.cloudIntegrationViewModel)
        case .gateway:
            GatewayView(viewModel: viewModel.gatewayViewModel)
        case .reporting:
            StructuredReportView(viewModel: StructuredReportViewModel())
        case .tools:
            DataExchangeView(viewModel: DataExchangeViewModel())
        case .validation:
            ValidationView(viewModel: viewModel.validationViewModel)
        case .archiveManagement:
            ArchiveManagementView(viewModel: viewModel.archiveManagementViewModel)
        case .cliWorkshop:
            CLIWorkshopView(viewModel: viewModel.cliWorkshopViewModel)
                .onAppear {
                    viewModel.cliWorkshopViewModel.savedServerProfiles = viewModel.networkingViewModel.serverProfiles
                }
        case .cliParity:
            CLIParityRunnerView(viewModel: viewModel.cliParityRunnerViewModel)
        case .security:
            SecurityView(viewModel: SecurityViewModel())
        case .performanceTools:
            PerformanceToolsView(viewModel: PerformanceToolsViewModel())
        case .macOSEnhancements:
            MacOSEnhancementsView(viewModel: MacOSEnhancementsViewModel())
        case .polishRelease:
            PolishReleaseView(viewModel: PolishReleaseViewModel())
        case .integrationTesting:
            IntegrationTestingView(viewModel: IntegrationTestingViewModel())
        case .j2kTestBench:
            J2KTestBenchView(viewModel: viewModel.j2kTestBenchViewModel)
        case .settings:
            SettingsView(viewModel: SettingsViewModel(settingsService: viewModel.settingsService))
        }
    }
}
#endif
