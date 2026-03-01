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

        #if os(macOS)
        Settings {
            SettingsView(viewModel: SettingsViewModel(settingsService: viewModel.settingsService))
        }
        #endif
    }
}
#endif
