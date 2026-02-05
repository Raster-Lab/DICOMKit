// ContentView.swift
// DICOMViewer iOS - Main Content View
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import SwiftUI
import SwiftData

/// Main Content View with Tab Navigation
///
/// Provides the primary navigation structure with:
/// - Library: Study browser and management
/// - Viewer: Image viewing and tools
/// - Settings: App configuration
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var selectedStudy: DICOMStudy?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Library Tab
            NavigationStack {
                LibraryView(selectedStudy: $selectedStudy, onOpenViewer: {
                    selectedTab = 1
                })
            }
            .tabItem {
                Label("Library", systemImage: "folder")
            }
            .tag(0)
            
            // Viewer Tab
            NavigationStack {
                if let study = selectedStudy {
                    ViewerContainerView(study: study)
                } else {
                    EmptyViewerView()
                }
            }
            .tabItem {
                Label("Viewer", systemImage: "eye")
            }
            .tag(1)
            
            // Settings Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(2)
        }
    }
}

/// Empty state view when no study is selected
struct EmptyViewerView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("No Study Selected")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Select a study from the Library tab to view DICOM images")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .navigationTitle("Viewer")
    }
}

#Preview {
    ContentView()
}
