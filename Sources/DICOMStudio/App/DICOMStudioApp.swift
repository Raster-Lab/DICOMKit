// DICOMStudioApp.swift
// DICOMStudio
//
// DICOM Studio — macOS application entry point

#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// DICOM Studio macOS application entry point.
///
/// This file serves as the `@main` entry point when building the macOS app.
/// It is excluded from the library target and used only in the app target.
@available(macOS 14.0, *)
public struct DICOMStudioApp: App {
    @State private var viewModel = MainViewModel()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
        }
        .defaultSize(width: 1200, height: 800)
        // Window can shrink to the content's minimum and grow without limit,
        // so the app adapts to any display from a small laptop to an
        // ultrawide. `.contentMinSize` keeps only the lower bound enforced.
        .windowResizability(.contentMinSize)
        .commands { ViewerCommands() }

        #if os(macOS)
        // The printer emulator is watched while a print is being sent from the
        // main window, so it is a window rather than a detail pane. A single
        // `Window` (not a `WindowGroup`): there is one emulator, and choosing
        // the sidebar entry again raises the one that exists instead of opening
        // a second view onto the same server.
        Window("Printer Emulator", id: StudioWindowID.printerEmulator) {
            PrintSCPView(viewModel: viewModel.printSCPViewModel)
                .frame(minWidth: 900, minHeight: 620)
        }
        .defaultSize(width: 1320, height: 880)
        .windowResizability(.contentMinSize)
        #endif

        #if os(macOS)
        Settings {
            SettingsView(viewModel: SettingsViewModel(settingsService: viewModel.settingsService))
        }
        #endif
    }
}
#endif
