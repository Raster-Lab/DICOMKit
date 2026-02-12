import SwiftUI

/// The main application entry point for DICOMToolbox
@main
struct DICOMToolboxApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 960, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 850)
    }
}
