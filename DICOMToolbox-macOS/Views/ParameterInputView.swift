import SwiftUI
import UniformTypeIdentifiers

/// Renders the appropriate input control for a tool parameter
struct ParameterInputView: View {

    let parameter: ToolParameter
    @Binding var value: String
    let pacsConfig: PACSConfiguration

    @State private var isShowingHelp = false
    @State private var isFileImporterPresented = false
    @State private var isSavePanelPresented = false
    @State private var isDragTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                // Label with optional help button
                parameterLabel
                    .frame(width: 140, alignment: .trailing)

                // Input control
                inputControl
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Auto-fill indicator for PACS parameters
            if parameter.isPACSParameter && !autoFilledValue.isEmpty && value.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.left")
                        .font(.caption2)
                    Text("Auto-filled from network configuration")
                        .font(.caption2)
                }
                .foregroundStyle(.blue)
                .padding(.leading, 148)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Label

    private var parameterLabel: some View {
        HStack(spacing: 4) {
            if parameter.isRequired {
                Text("*")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Text(parameter.name)
                .font(.body)
                .foregroundStyle(.primary)

            if parameter.discussion != nil {
                Button {
                    isShowingHelp.toggle()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $isShowingHelp) {
                    helpPopover
                }
            }
        }
    }

    // MARK: - Help Popover

    private var helpPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(parameter.name)
                .font(.headline)

            Text(parameter.help)
                .font(.body)

            if let discussion = parameter.discussion {
                Divider()
                Text(discussion)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if !parameter.cliFlag.isEmpty {
                Divider()
                Text("CLI flag: \(parameter.cliFlag)")
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: 320)
    }

    // MARK: - Input Control

    @ViewBuilder
    private var inputControl: some View {
        switch parameter.type {
        case .flag:
            flagInput

        case .text, .positionalArgument:
            textInput

        case .number:
            numberInput

        case .dropdown(let options):
            dropdownInput(options: options)

        case .inputFile(let types):
            fileInput(allowedTypes: types, isOutput: false)

        case .inputDirectory:
            directoryInput(isOutput: false)

        case .outputFile(let types):
            fileInput(allowedTypes: types, isOutput: true)

        case .outputDirectory:
            directoryInput(isOutput: true)

        case .positionalFile(let types):
            fileInput(allowedTypes: types, isOutput: false)

        case .positionalDirectory:
            directoryInput(isOutput: false)

        case .positionalFiles(let types):
            fileInput(allowedTypes: types, isOutput: false)

        case .multiText:
            multiTextInput
        }
    }

    // MARK: - Flag Input (Toggle/Switch)

    private var flagInput: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { value == "true" },
                set: { value = $0 ? "true" : "" }
            )) {
                EmptyView()
            }
            .toggleStyle(.switch)

            Text(parameter.help)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Text Input

    private var textInput: some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField(parameter.help, text: $value)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)

            if let defaultVal = parameter.defaultValue {
                Text("Default: \(defaultVal)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Number Input

    private var numberInput: some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField(parameter.defaultValue ?? "0", text: $value)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 120)

            Text(parameter.help)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Dropdown Input

    private func dropdownInput(options: [DropdownOption]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Picker(parameter.name, selection: $value) {
                Text("— Select —").tag("")
                ForEach(options) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: 240)

            if let selectedOption = options.first(where: { $0.value == value }),
               let help = selectedOption.help {
                Text(help)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - File Input with Drag & Drop

    private func fileInput(allowedTypes: [String], isOutput: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField(isOutput ? "Save path…" : "File path…", text: $value)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)

                if isOutput {
                    Button("Save As…") {
                        showSavePanel(allowedTypes: allowedTypes)
                    }
                    .help("Choose save location")
                } else {
                    Button("Browse…") {
                        showOpenPanel(allowedTypes: allowedTypes, directories: false)
                    }
                    .help("Choose file")
                }
            }

            // Drag and drop target (for input files only)
            if !isOutput {
                FileDropTarget(value: $value, allowedTypes: allowedTypes, isDragTargeted: $isDragTargeted)
            }
        }
    }

    // MARK: - Directory Input

    private func directoryInput(isOutput: Bool) -> some View {
        HStack(spacing: 8) {
            TextField(isOutput ? "Output directory…" : "Directory path…", text: $value)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)

            Button("Choose…") {
                showOpenPanel(allowedTypes: [], directories: true)
            }
            .help("Choose directory")
        }
    }

    // MARK: - Multi-Text Input

    private var multiTextInput: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextEditor(text: $value)
                .font(.body)
                .frame(maxWidth: 300, minHeight: 60, maxHeight: 100)
                .border(Color(nsColor: .separatorColor), width: 0.5)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text("One value per line. \(parameter.help)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - File Dialogs

    private func showOpenPanel(allowedTypes: [String], directories: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = !directories
        panel.canChooseDirectories = directories
        panel.allowsMultipleSelection = false
        if !allowedTypes.isEmpty {
            panel.allowedContentTypes = allowedTypes.compactMap { ext in
                UTType(filenameExtension: ext)
            }
        }
        if panel.runModal() == .OK, let url = panel.url {
            value = url.path
        }
    }

    private func showSavePanel(allowedTypes: [String]) {
        let panel = NSSavePanel()
        if !allowedTypes.isEmpty {
            panel.allowedContentTypes = allowedTypes.compactMap { ext in
                UTType(filenameExtension: ext)
            }
        }
        if panel.runModal() == .OK, let url = panel.url {
            value = url.path
        }
    }

    // MARK: - Auto-fill

    private var autoFilledValue: String {
        guard parameter.isPACSParameter else { return "" }
        let flag = parameter.cliFlag.lowercased()
        if flag == "--aet" { return pacsConfig.localAETitle }
        if flag == "--called-aet" { return pacsConfig.remoteAETitle }
        if case .positionalArgument = parameter.type {
            return pacsConfig.pacsURL
        }
        return ""
    }
}
