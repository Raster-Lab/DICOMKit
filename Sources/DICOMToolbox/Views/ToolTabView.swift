#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Tab interface showing the 6 tool categories with sidebar navigation
public struct ToolTabView: View {
    @Binding var selectedCategory: ToolCategory
    @Binding var selectedToolID: String?
    @Binding var parameterValues: [String: String]
    @Binding var subcommand: String?
    let networkConfig: NetworkConfigModel

    public init(
        selectedCategory: Binding<ToolCategory>,
        selectedToolID: Binding<String?>,
        parameterValues: Binding<[String: String]>,
        subcommand: Binding<String?>,
        networkConfig: NetworkConfigModel
    ) {
        self._selectedCategory = selectedCategory
        self._selectedToolID = selectedToolID
        self._parameterValues = parameterValues
        self._subcommand = subcommand
        self.networkConfig = networkConfig
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
            }
            .navigationTitle(category.rawValue)
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
        switch tool.id {
        case "dicom-info":
            DicomInfoView(parameterValues: $parameterValues)
        case "dicom-dump":
            DicomDumpView(parameterValues: $parameterValues)
        case "dicom-tags":
            DicomTagsView(parameterValues: $parameterValues)
        case "dicom-diff":
            DicomDiffView(parameterValues: $parameterValues)
        default:
            ParameterFormView(
                tool: tool,
                parameterValues: $parameterValues,
                subcommand: $subcommand
            )
        }
    }
}

/// Dynamic parameter form for a selected tool
struct ParameterFormView: View {
    let tool: ToolDefinition
    @Binding var parameterValues: [String: String]
    @Binding var subcommand: String?

    var body: some View {
        Form {
            // Tool header
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Label(tool.name, systemImage: tool.icon)
                        .font(.title2)
                    Text(tool.description)
                        .foregroundStyle(.secondary)
                }
            }

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
                }
            }

            // Help button
            if let discussion = param.discussion, !discussion.isEmpty {
                Button(action: {}) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
                .help(discussion)
            } else {
                Button(action: {}) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
                .help(param.help)
            }
        }
    }
}
#endif
