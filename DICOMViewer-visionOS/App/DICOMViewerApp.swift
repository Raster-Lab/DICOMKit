// DICOMViewerApp.swift
// DICOMViewer visionOS - Main App Entry Point
//
// Copyright 2024 DICOMKit. All rights reserved.
// SPDX-License-Identifier: MIT

import SwiftUI
import SwiftData

/// DICOMViewer visionOS App Entry Point
///
/// A spatial computing medical image viewer for Apple Vision Pro.
/// Showcases DICOMKit's capabilities with 3D volume rendering, hand tracking, and collaboration.
@main
struct DICOMViewerApp: App {
    /// SwiftData model container for study persistence
    let modelContainer: ModelContainer
    
    /// Immersive space identifier
    private let immersiveSpaceID = "VolumeImmersiveSpace"
    
    init() {
        do {
            // Configure SwiftData with DICOM models
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
        // Main library window
        WindowGroup(id: "library") {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1200, height: 800)
        
        // Image viewer window
        WindowGroup(id: "viewer", for: UUID.self) { $seriesID in
            if let seriesID {
                Text("Viewer for series: \(seriesID.uuidString)")
                    .padding()
            }
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 800, height: 600)
        
        // Tools palette window
        WindowGroup(id: "tools") {
            Text("Tools Palette")
                .padding()
        }
        .defaultSize(width: 400, height: 600)
        
        // Immersive space for 3D volume rendering
        ImmersiveSpace(id: immersiveSpaceID) {
            VolumeImmersiveView()
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed, .full)
    }
}
