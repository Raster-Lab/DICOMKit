#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Tab interface showing the 6 tool categories with sidebar navigation
public struct ToolTabView: View {
    @Binding var selectedCategory: ToolCategory
    @Binding var selectedToolID: String?
    @Binding var parameterValues: [String: String]
    @Binding var subcommand: String?
    let networkConfig: NetworkConfigModel
    let isBeginnerMode: Bool

    public init(
        selectedCategory: Binding<ToolCategory>,
        selectedToolID: Binding<String?>,
        parameterValues: Binding<[String: String]>,
        subcommand: Binding<String?>,
        networkConfig: NetworkConfigModel,
        isBeginnerMode: Bool = false
    ) {
        self._selectedCategory = selectedCategory
        self._selectedToolID = selectedToolID
        self._parameterValues = parameterValues
        self._subcommand = subcommand
        self.networkConfig = networkConfig
        self.isBeginnerMode = isBeginnerMode
    }

    public var body: some View {
        TabView(selection: $selectedCategory) {
            ForEach(ToolCategory.allCases) { category in
                toolCategoryContent(category)
                    .tabItem {
                        Label(category.rawValue, systemImage: category.iconName)
                    }
                    .tag(category)
            }
        }
        .onChange(of: selectedCategory) { _, _ in
            // Reset tool selection when switching categories
            selectedToolID = nil
            parameterValues = [:]
            subcommand = nil
        }
    }

    @ViewBuilder
    private func toolCategoryContent(_ category: ToolCategory) -> some View {
        let tools = ToolRegistry.tools(for: category)

        NavigationSplitView {
            List(tools, selection: $selectedToolID) { tool in
                Label(tool.name, systemImage: tool.icon)
                    .tag(tool.id)
                    .accessibilityLabel(tool.name)
                    .accessibilityHint(tool.description)
            }
            .navigationTitle(category.rawValue)
            .accessibilityLabel("\(category.rawValue) tools")
        } detail: {
            if let toolID = selectedToolID,
               let tool = ToolRegistry.tool(withID: toolID) {
                toolDetailView(for: tool)
            } else {
                ContentUnavailableView(
                    "Select a Tool",
                    systemImage: category.iconName,
                    description: Text("Choose a tool from the sidebar to configure its parameters.")
                )
            }
        }
    }

    /// Routes a tool to its dedicated view when available, falling back to the generic form
    @ViewBuilder
    private func toolDetailView(for tool: ToolDefinition) -> some View {
        VStack(spacing: 0) {
            // Tool header with "What does this do?" and example presets
            ToolHeaderView(
                tool: tool,
                parameterValues: $parameterValues,
                subcommand: $subcommand
            )

            Divider()

            // Tool-specific parameter form
            toolParameterView(for: tool)
        }
    }

    @ViewBuilder
    private func toolParameterView(for tool: ToolDefinition) -> some View {
        switch tool.id {
        // File Inspection
        case "dicom-info":
            DicomInfoView(parameterValues: $parameterValues)
        case "dicom-dump":
            DicomDumpView(parameterValues: $parameterValues)
        case "dicom-tags":
            DicomTagsView(parameterValues: $parameterValues)
        case "dicom-diff":
            DicomDiffView(parameterValues: $parameterValues)
        // File Processing
        case "dicom-convert":
            DicomConvertView(parameterValues: $parameterValues)
        case "dicom-validate":
            DicomValidateView(parameterValues: $parameterValues)
        case "dicom-anon":
            DicomAnonView(parameterValues: $parameterValues)
        case "dicom-compress":
            DicomCompressView(parameterValues: $parameterValues, subcommand: $subcommand)
        // File Organization
        case "dicom-split":
            DicomSplitView(parameterValues: $parameterValues)
        case "dicom-merge":
            DicomMergeView(parameterValues: $parameterValues)
        case "dicom-dcmdir":
            DicomDcmdirView(parameterValues: $parameterValues, subcommand: $subcommand)
        case "dicom-archive":
            DicomArchiveView(parameterValues: $parameterValues)
        // Data Export
        case "dicom-json":
            DicomJsonView(parameterValues: $parameterValues)
        case "dicom-xml":
            DicomXmlView(parameterValues: $parameterValues)
        case "dicom-pdf":
            DicomPdfView(parameterValues: $parameterValues)
        case "dicom-image":
            DicomImageView(parameterValues: $parameterValues)
        case "dicom-export":
            DicomExportView(parameterValues: $parameterValues, subcommand: $subcommand)
        case "dicom-pixedit":
            DicomPixeditView(parameterValues: $parameterValues)
        case "dicom-report":
            DicomReportView(parameterValues: $parameterValues)
        // Network Operations
        case "dicom-echo":
            DicomEchoView(parameterValues: $parameterValues, networkConfig: networkConfig)
        case "dicom-query":
            DicomQueryView(parameterValues: $parameterValues, networkConfig: networkConfig)
        case "dicom-send":
            DicomSendView(parameterValues: $parameterValues, networkConfig: networkConfig)
        case "dicom-retrieve":
            DicomRetrieveView(parameterValues: $parameterValues, networkConfig: networkConfig)
        case "dicom-qr":
            DicomQRView(parameterValues: $parameterValues, networkConfig: networkConfig)
        case "dicom-wado":
            DicomWadoView(parameterValues: $parameterValues, subcommand: $subcommand, networkConfig: networkConfig)
        case "dicom-mwl":
            DicomMWLView(parameterValues: $parameterValues, networkConfig: networkConfig)
        case "dicom-mpps":
            DicomMPPSView(parameterValues: $parameterValues, subcommand: $subcommand, networkConfig: networkConfig)
        // Automation
        case "dicom-study":
            DicomStudyView(parameterValues: $parameterValues, subcommand: $subcommand)
        case "dicom-uid":
            DicomUIDView(parameterValues: $parameterValues, subcommand: $subcommand)
        case "dicom-script":
            DicomScriptView(parameterValues: $parameterValues, subcommand: $subcommand)
        default:
            ParameterFormView(
                tool: tool,
                parameterValues: $parameterValues,
                subcommand: $subcommand
            )
        }
    }
}

/// Header section for tool detail view with "What does this do?" and example presets
struct ToolHeaderView: View {
    let tool: ToolDefinition
    @Binding var parameterValues: [String: String]
    @Binding var subcommand: String?
    @State private var isDiscussionExpanded = false
    @State private var showExamples = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(tool.name, systemImage: tool.icon)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                // Example presets button
                Button(action: { showExamples.toggle() }) {
                    Label("Examples", systemImage: "lightbulb")
                }
                .help("Load an example command configuration")
                .accessibilityLabel("Show example commands for \(tool.name)")
                .popover(isPresented: $showExamples) {
                    ExamplePresetsView(
                        toolID: tool.id,
                        parameterValues: $parameterValues,
                        subcommand: $subcommand,
                        onDismiss: { showExamples = false }
                    )
                }
            }

            Text(tool.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityLabel(tool.description)

            // "What does this do?" expandable
            if !tool.discussion.isEmpty {
                DisclosureGroup("What does this do?", isExpanded: $isDiscussionExpanded) {
                    Text(tool.discussion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                .font(.caption)
                .foregroundStyle(.blue)
                .accessibilityLabel("What does this tool do? Tap to expand.")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

/// Dynamic parameter form for a selected tool
struct ParameterFormView: View {
    let tool: ToolDefinition
    @Binding var parameterValues: [String: String]
    @Binding var subcommand: String?

    var body: some View {
        Form {
            // Subcommand picker (if applicable)
            if let subcommands = tool.subcommands {
                Section("Subcommand") {
                    Picker("Operation", selection: Binding(
                        get: { subcommand ?? subcommands.first?.id ?? "" },
                        set: { newValue in
                            subcommand = newValue
                            parameterValues = [:]
                        }
                    )) {
                        ForEach(subcommands) { sub in
                            Text(sub.name).tag(sub.id)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Select operation")

                    if let selectedSub = subcommands.first(where: { $0.id == (subcommand ?? subcommands.first?.id) }) {
                        Text(selectedSub.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Parameters section
            let parameters = currentParameters
            if !parameters.isEmpty {
                Section("Parameters") {
                    ForEach(parameters) { param in
                        parameterControl(for: param)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            // Set default subcommand if tool has subcommands
            if let firstSub = tool.subcommands?.first, subcommand == nil {
                subcommand = firstSub.id
            }
        }
    }

    private var currentParameters: [ParameterDefinition] {
        if let subcommand, let subcommands = tool.subcommands,
           let sub = subcommands.first(where: { $0.id == subcommand }) {
            return sub.parameters
        }
        return tool.parameters
    }

    @ViewBuilder
    private func parameterControl(for param: ParameterDefinition) -> some View {
        HStack {
            switch param.type {
            case .boolean:
                Toggle(isOn: Binding(
                    get: { parameterValues[param.id] == "true" },
                    set: { parameterValues[param.id] = $0 ? "true" : "" }
                )) {
                    HStack {
                        Text(param.label)
                        if param.isRequired {
                            Text("*").foregroundStyle(.red)
                        }
                    }
                }
                .accessibilityLabel(param.label)

            case .enumeration:
                if let enumValues = param.enumValues {
                    Picker(selection: Binding(
                        get: { parameterValues[param.id] ?? param.defaultValue ?? "" },
                        set: { parameterValues[param.id] = $0 }
                    )) {
                        ForEach(enumValues) { ev in
                            Text(ev.label).tag(ev.value)
                        }
                    } label: {
                        HStack {
                            Text(param.label)
                            if param.isRequired {
                                Text("*").foregroundStyle(.red)
                            }
                        }
                    }
                    .accessibilityLabel(param.label)
                }

            case .integer:
                HStack {
                    Text(param.label)
                    if param.isRequired {
                        Text("*").foregroundStyle(.red)
                    }
                    Spacer()
                    TextField(param.defaultValue ?? "0", text: Binding(
                        get: { parameterValues[param.id] ?? "" },
                        set: { parameterValues[param.id] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .accessibilityLabel(param.label)
                }

            case .file:
                HStack {
                    Text(param.label)
                    if param.isRequired {
                        Text("*").foregroundStyle(.red)
                    }
                    Spacer()
                    Text(parameterValues[param.id] ?? "No file selected")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Browse...") {
                        // File picker would open here
                    }
                    .accessibilityLabel("Browse for \(param.label)")
                }

            default:
                HStack {
                    Text(param.label)
                    if param.isRequired {
                        Text("*").foregroundStyle(.red)
                    }
                    Spacer()
                    TextField(param.help, text: Binding(
                        get: { parameterValues[param.id] ?? "" },
                        set: { parameterValues[param.id] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                    .accessibilityLabel(param.label)
                }
            }

            // Help button
            if let discussion = param.discussion, !discussion.isEmpty {
                Button(action: {}) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
                .help(discussion)
                .accessibilityLabel("Help for \(param.label)")
            } else {
                Button(action: {}) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
                .help(param.help)
                .accessibilityLabel("Help for \(param.label)")
            }
        }
    }
}
#endif
