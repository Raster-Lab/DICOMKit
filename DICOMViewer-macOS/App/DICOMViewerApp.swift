//
//  DICOMViewerApp.swift
//  DICOMViewer macOS
//
//  Created by DICOMKit Team on 2026-02-06.
//  Copyright © 2026 Raster Lab. All rights reserved.
//

import SwiftUI
import SwiftData

@main
struct DICOMViewerApp: App {
    @State private var showingPACSQuery = false
    @State private var showingServerConfig = false
    @State private var showingDownloadQueue = false
    
    var body: some Scene {
        WindowGroup {
            StudyBrowserView()
                .frame(minWidth: 1000, minHeight: 700)
                .sheet(isPresented: $showingPACSQuery) {
                    PACSQueryView()
                }
                .sheet(isPresented: $showingServerConfig) {
                    ServerConfigurationView()
                }
                .sheet(isPresented: $showingDownloadQueue) {
                    DownloadQueueView()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Files...") {
                    // TODO: Implement file import action
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Import Folder...") {
                    // TODO: Implement folder import action
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            
            CommandGroup(after: .sidebar) {
                Divider()
                
                Button("Query PACS...") {
                    showingPACSQuery = true
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Button("Configure Servers...") {
                    showingServerConfig = true
                }
                .keyboardShortcut(",", modifiers: [.command, .shift])
                
                Button("Download Queue...") {
                    showingDownloadQueue = true
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
            
            // Layout shortcuts
            CommandGroup(after: .windowArrangement) {
                Button("1×1 Layout") {
                    // TODO: Send layout change to active viewer
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("2×2 Layout") {
                    // TODO: Send layout change to active viewer
                }
                .keyboardShortcut("2", modifiers: .command)
                
                Button("3×3 Layout") {
                    // TODO: Send layout change to active viewer
                }
                .keyboardShortcut("3", modifiers: .command)
                
                Button("4×4 Layout") {
                    // TODO: Send layout change to active viewer
                }
                .keyboardShortcut("4", modifiers: .command)
                
                Divider()
                
                Button("MPR View") {
                    // TODO: Open MPR view for selected series
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                
                Button("3D Volume Rendering") {
                    // TODO: Open 3D rendering view for selected series
                }
                .keyboardShortcut("3", modifiers: [.command, .shift])
            }
        }
        .modelContainer(DatabaseService.shared.modelContainer)
    }
}
