// SettingsView.swift
// DICOMViewer iOS - Settings View
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import SwiftUI

/// App settings view
struct SettingsView: View {
    @AppStorage("defaultColorScheme") private var defaultColorScheme = "dark"
    @AppStorage("defaultFrameRate") private var defaultFrameRate = 10.0
    @AppStorage("showFrameCounter") private var showFrameCounter = true
    @AppStorage("enableHaptics") private var enableHaptics = true
    
    @State private var showingClearConfirmation = false
    @State private var librarySize: String = "Calculating..."
    
    var body: some View {
        Form {
            // Display Section
            Section("Display") {
                Picker("Theme", selection: $defaultColorScheme) {
                    Text("Dark").tag("dark")
                    Text("Light").tag("light")
                    Text("System").tag("system")
                }
                
                Toggle("Show Frame Counter", isOn: $showFrameCounter)
            }
            
            // Playback Section
            Section("Playback") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Default Frame Rate")
                        Spacer()
                        Text("\(Int(defaultFrameRate)) fps")
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(value: $defaultFrameRate, in: 1...30, step: 1)
                }
            }
            
            // Interaction Section
            Section("Interaction") {
                Toggle("Haptic Feedback", isOn: $enableHaptics)
            }
            
            // Storage Section
            Section("Storage") {
                LabeledContent("Library Size", value: librarySize)
                
                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Text("Clear Library")
                }
            }
            
            // About Section
            Section("About") {
                LabeledContent("App Version", value: appVersion)
                LabeledContent("DICOMKit Version", value: dicomKitVersion)
                
                Link(destination: URL(string: "https://github.com/raster-image/DICOMKit")!) {
                    HStack {
                        Text("GitHub Repository")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Clear Library",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Data", role: .destructive) {
                clearLibrary()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all imported DICOM files. This action cannot be undone.")
        }
        .task {
            await calculateLibrarySize()
        }
    }
    
    /// App version string
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    /// DICOMKit version
    private var dicomKitVersion: String {
        "1.0.14"
    }
    
    /// Calculates library storage size
    private func calculateLibrarySize() async {
        do {
            let size = try await DICOMFileService.shared.librarySize()
            librarySize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        } catch {
            librarySize = "Unknown"
        }
    }
    
    /// Clears the library
    private func clearLibrary() {
        Task {
            try? await DICOMFileService.shared.clearLibrary()
            try? await ThumbnailService.shared.clearDiskCache()
            await calculateLibrarySize()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
