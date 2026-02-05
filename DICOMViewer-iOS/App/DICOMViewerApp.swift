// DICOMViewerApp.swift
// DICOMViewer iOS - Main App Entry Point
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import SwiftUI
import SwiftData

/// DICOMViewer iOS App Entry Point
///
/// A mobile medical image viewer showcasing DICOMKit's capabilities.
/// Target: iOS 17+, iPadOS 17+
@main
struct DICOMViewerApp: App {
    /// SwiftData model container for study persistence
    let modelContainer: ModelContainer
    
    /// App initialization
    init() {
        do {
            // Configure SwiftData with DICOMStudy model
            let schema = Schema([
                DICOMStudy.self,
                DICOMSeries.self,
                DICOMInstance.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to initialize SwiftData: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark) // Medical imaging apps default to dark mode
        }
        .modelContainer(modelContainer)
    }
}
