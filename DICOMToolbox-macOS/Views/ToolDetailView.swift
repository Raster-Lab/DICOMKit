import SwiftUI

/// Displays the tool's parameter form and description
struct ToolDetailView: View {

    let tool: ToolDefinition
    @Binding var selectedSubcommand: SubcommandDefinition?
    @Binding var parameterValues: [String: String]
    let pacsConfig: PACSConfiguration
    let onSubcommandChanged: (SubcommandDefinition) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Tool header
                toolHeader

                // Subcommand picker
                if tool.hasSubcommands, let subcommands = tool.subcommands {
                    subcommandPicker(subcommands)
                }

                Divider()

                // Parameter form
                let params = selectedSubcommand?.parameters ?? tool.parameters
                if params.isEmpty {
                    Text("This tool has no configurable parameters.")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    parameterForm(params)
                }

                // Examples
                if !tool.examples.isEmpty {
                    examplesSection
                }
            }
            .padding(20)
        }
    }

    // MARK: - Tool Header

    private var toolHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: tool.icon)
                    .font(.title2)
                    .foregroundStyle(.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(tool.command)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if !tool.discussion.isEmpty {
                Text(tool.discussion)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Subcommand Picker

    private func subcommandPicker(_ subcommands: [SubcommandDefinition]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Subcommand")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Picker("Subcommand", selection: Binding<String>(
                get: { selectedSubcommand?.id ?? subcommands.first?.id ?? "" },
                set: { newID in
                    if let sub = subcommands.first(where: { $0.id == newID }) {
                        onSubcommandChanged(sub)
                    }
                }
            )) {
                ForEach(subcommands) { sub in
                    Text(sub.name)
                        .tag(sub.id)
                }
            }
            .pickerStyle(.segmented)

            if let sub = selectedSubcommand {
                Text(sub.abstract)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Parameter Form

    private func parameterForm(_ parameters: [ToolParameter]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Required parameters section
            let required = parameters.filter { $0.isRequired }
            let optional = parameters.filter { !$0.isRequired }

            if !required.isEmpty {
                Text("Required")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                ForEach(required) { param in
                    ParameterInputView(
                        parameter: param,
                        value: binding(for: param.id),
                        pacsConfig: pacsConfig
                    )
                }
            }

            if !optional.isEmpty {
                if !required.isEmpty {
                    Divider()
                        .padding(.vertical, 4)
                }

                Text("Options")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                ForEach(optional) { param in
                    ParameterInputView(
                        parameter: param,
                        value: binding(for: param.id),
                        pacsConfig: pacsConfig
                    )
                }
            }
        }
    }

    // MARK: - Examples

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .padding(.vertical, 4)

            Text("Examples")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(tool.examples, id: \.self) { example in
                Text(example)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    // MARK: - Helpers

    private func binding(for paramID: String) -> Binding<String> {
        Binding(
            get: { parameterValues[paramID] ?? "" },
            set: { parameterValues[paramID] = $0 }
        )
    }
}
