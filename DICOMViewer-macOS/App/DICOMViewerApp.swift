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
    var body: some Scene {
        WindowGroup {
            StudyBrowserView()
                .frame(minWidth: 1000, minHeight: 700)
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
                Button("Query PACS...") {
                    // TODO: Implement PACS query (Phase 2)
                }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(true) // Disabled until Phase 2
            }
        }
        .modelContainer(DatabaseService.shared.modelContainer)
    }
}
