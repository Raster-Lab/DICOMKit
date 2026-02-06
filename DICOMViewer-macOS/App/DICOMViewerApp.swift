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
        }
        .modelContainer(DatabaseService.shared.modelContainer)
    }
}
