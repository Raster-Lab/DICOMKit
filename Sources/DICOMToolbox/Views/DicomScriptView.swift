#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-script` tool, providing subcommand-based
/// forms for running, validating, and generating DICOM automation scripts.
public struct DicomScriptView: View {
    @Binding var parameterValues: [String: String]
    @Binding var subcommand: String?

    private var tool: ToolDefinition { ToolRegistry.dicomScript }

    public init(parameterValues: Binding<[String: String]>, subcommand: Binding<String?>) {
        self._parameterValues = parameterValues
        self._subcommand = subcommand
    }

    private var currentSubcommand: String {
        subcommand ?? tool.subcommands?.first?.id ?? "run"
    }

    public var body: some View {
        Form {
            // MARK: Subcommand
            ParameterSectionView(
                title: "Operation",
                help: "Run executes a script, Validate checks script syntax, and Template generates a starter script file."
            ) {
                if let subcommands = tool.subcommands {
                    Picker("Operation", selection: Binding(
                        get: { currentSubcommand },
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

                    if let selectedSub = tool.subcommands?.first(where: { $0.id == currentSubcommand }) {
                        Text(selectedSub.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: Dynamic Form
            switch currentSubcommand {
            case "run":
                runForm
            case "validate":
                validateForm
            case "template":
                templateForm
            default:
                runForm
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if subcommand == nil {
                subcommand = tool.subcommands?.first?.id
            }
        }
    }

    // MARK: - Run Subcommand

    @ViewBuilder
    private var runForm: some View {
        ParameterSectionView(
            title: "Script File",
            help: "Select the DICOM automation script to execute.",
            isRequired: true
        ) {
            FileDropZoneView(
                parameterID: "script",
                label: "Script File",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(
            title: "Variables",
            help: "Define variables to pass to the script. Each variable uses KEY=VALUE format."
        ) {
            RepeatableOptionView(
                parameterID: "variables",
                label: "Script Variables",
                placeholder: "KEY=VALUE",
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(
            title: "Execution Options",
            help: "Configure how the script is executed."
        ) {
            Toggle("Parallel Execution", isOn: Binding(
                get: { parameterValues["parallel"] == "true" },
                set: { parameterValues["parallel"] = $0 ? "true" : "" }
            ))
            .help("Run script tasks in parallel when possible")

            Toggle("Dry Run", isOn: Binding(
                get: { parameterValues["dry-run"] == "true" },
                set: { parameterValues["dry-run"] = $0 ? "true" : "" }
            ))
            .help("Preview actions without executing them")
        }

        ParameterSectionView(title: "Logging") {
            OutputPathView(
                parameterID: "log",
                label: "Log File",
                isRequired: false,
                parameterValues: $parameterValues
            )
        }
    }

    // MARK: - Validate Subcommand

    @ViewBuilder
    private var validateForm: some View {
        ParameterSectionView(
            title: "Script File",
            help: "Select a script file to validate its syntax and structure.",
            isRequired: true
        ) {
            FileDropZoneView(
                parameterID: "script",
                label: "Script File",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }
    }

    // MARK: - Template Subcommand

    @ViewBuilder
    private var templateForm: some View {
        ParameterSectionView(
            title: "Output",
            help: "Specify the output path for the generated script template."
        ) {
            OutputPathView(
                parameterID: "output",
                label: "Template Output File",
                isRequired: false,
                parameterValues: $parameterValues
            )
        }
    }
}
#endif
