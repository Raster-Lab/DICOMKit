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
struct DICOMStudioApp: App {
    @State private var viewModel = MainViewModel()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
        }
        .defaultSize(width: 1200, height: 800)

        // The printer emulator is watched while a print is being sent from the
        // main window, so it is a window rather than a detail pane. A single
        // `Window`, not a `WindowGroup`: there is one emulator, and choosing the
        // sidebar entry again raises the window that exists instead of opening a
        // second view onto the same server.
        Window("Printer Emulator", id: StudioWindowID.printerEmulator) {
            PrintSCPView(viewModel: viewModel.printSCPViewModel)
                .frame(minWidth: 900, minHeight: 620)
        }
        .defaultSize(width: 1320, height: 880)
        .windowResizability(.contentMinSize)

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
