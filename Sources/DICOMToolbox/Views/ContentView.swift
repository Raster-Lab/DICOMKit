#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// The main content view for the DICOMToolbox application.
/// Layout: Toolbar → Network Config Bar (top) → Tool Tab Interface (middle) → Console (bottom)
public struct ContentView: View {
    @State private var networkConfig = NetworkConfigModel()
    @State private var selectedCategory: ToolCategory = .fileInspection
    @State private var selectedToolID: String?
    @State private var parameterValues: [String: String] = [:]
    @State private var subcommand: String?
    @State private var consoleOutput: String = ""
    @State private var executionStatus: ExecutionStatus = .idle
    @State private var historyEntries: [CommandHistoryEntry] = CommandHistory.load()
    @State private var isBeginnerMode: Bool = AppSettings.isBeginnerMode()
    @State private var showGlossary = false
    @State private var showSettings = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsSuccess = true
    @State private var consoleFontSize: Double = AppSettings.consoleFontSize()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar bar
            toolbarBar

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
                networkConfig: networkConfig,
                isBeginnerMode: isBeginnerMode
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
                historyEntries: $historyEntries,
                consoleFontSize: consoleFontSize,
                onCommandCompleted: { success, message in
                    toastMessage = message
                    toastIsSuccess = success
                    withAnimation(.easeInOut) {
                        showToast = true
                    }
                }
            )
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .toast(isPresented: $showToast, message: toastMessage, isSuccess: toastIsSuccess)
        .frame(minWidth: 1200, minHeight: 800)
        .sheet(isPresented: $showGlossary) {
            GlossaryView()
                .frame(width: 700, height: 500)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onChange(of: showSettings) { _, _ in
            // Reload settings when settings sheet closes
            isBeginnerMode = AppSettings.isBeginnerMode()
            consoleFontSize = AppSettings.consoleFontSize()
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbarBar: some View {
        HStack(spacing: 12) {
            // App title
            Label("DICOMToolbox", systemImage: "stethoscope")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            // Beginner/Advanced mode toggle
            Toggle(isOn: $isBeginnerMode) {
                Label(
                    isBeginnerMode ? "Beginner" : "Advanced",
                    systemImage: isBeginnerMode ? "graduationcap" : "wrench.and.screwdriver"
                )
                .font(.subheadline)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .onChange(of: isBeginnerMode) { _, newValue in
                AppSettings.setBeginnerMode(newValue)
            }
            .help(isBeginnerMode ? "Switch to Advanced mode to see all parameters" : "Switch to Beginner mode to hide advanced parameters")
            .accessibilityLabel("Mode toggle: \(isBeginnerMode ? "Beginner" : "Advanced")")

            Divider().frame(height: 20)

            // Glossary button
            Button(action: { showGlossary.toggle() }) {
                Label("Glossary", systemImage: "character.book.closed")
            }
            .help("Open DICOM Glossary")
            .accessibilityLabel("Open DICOM Glossary")

            // Settings button
            Button(action: { showSettings.toggle() }) {
                Label("Settings", systemImage: "gearshape")
            }
            .help("Open Settings")
            .accessibilityLabel("Open Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
#endif
