#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// The main content view for the DICOMToolbox application.
/// Layout: Network Config Bar (top) → Tool Tab Interface (middle) → Console (bottom)
public struct ContentView: View {
    @State private var networkConfig = NetworkConfigModel()
    @State private var selectedCategory: ToolCategory = .fileInspection
    @State private var selectedToolID: String?
    @State private var parameterValues: [String: String] = [:]
    @State private var subcommand: String?
    @State private var consoleOutput: String = ""
    @State private var executionStatus: ExecutionStatus = .idle
    @State private var historyEntries: [CommandHistoryEntry] = CommandHistory.load()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Network Configuration Bar
            NetworkConfigView(config: $networkConfig)
                .padding(.horizontal)
                .padding(.top, 8)

            Divider().padding(.vertical, 4)

            // Tool Tab Interface with sidebar
            ToolTabView(
                selectedCategory: $selectedCategory,
                selectedToolID: $selectedToolID,
                parameterValues: $parameterValues,
                subcommand: $subcommand,
                networkConfig: networkConfig
            )

            Divider().padding(.vertical, 4)

            // Console Window
            ConsoleView(
                toolID: selectedToolID,
                parameterValues: parameterValues,
                subcommand: subcommand,
                networkConfig: networkConfig,
                output: $consoleOutput,
                status: $executionStatus,
                historyEntries: $historyEntries
            )
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
}
#endif
