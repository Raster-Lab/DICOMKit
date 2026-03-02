// DICOMStudioApp.swift
// DICOMStudioApp
//
// DICOM Studio — macOS application entry point

#if canImport(SwiftUI) && os(macOS)
import SwiftUI
import DICOMStudio

/// DICOM Studio macOS application entry point.
///
/// Provides the `@main` entry for the macOS SwiftUI app,
/// referencing views and view-models from the DICOMStudio library.
@main
@available(macOS 14.0, *)
struct DICOMStudioApp: App {
    @State private var viewModel = MainViewModel()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
        }
        .defaultSize(width: 1200, height: 800)

        Settings {
            SettingsView(viewModel: SettingsViewModel(settingsService: viewModel.settingsService))
        }
    }
}
#else
@main
struct DICOMStudioAppLauncher {
    static func main() {
        print("DICOM Studio requires macOS 14.0 or later with SwiftUI support.")
    }
}
#endif
