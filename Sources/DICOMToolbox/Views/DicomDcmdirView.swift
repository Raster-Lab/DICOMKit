#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-dcmdir` tool, providing a subcommand picker
/// and dynamic parameter forms for create, validate, and dump operations.
public struct DicomDcmdirView: View {
    @Binding var parameterValues: [String: String]
    @Binding var subcommand: String?

    private var tool: ToolDefinition { ToolRegistry.dicomDcmdir }

    public init(parameterValues: Binding<[String: String]>, subcommand: Binding<String?>) {
        self._parameterValues = parameterValues
        self._subcommand = subcommand
    }

    private var currentSubcommand: String {
        subcommand ?? tool.subcommands?.first?.id ?? "create"
    }

    public var body: some View {
        Form {
            // MARK: Subcommand
            ParameterSectionView(
                title: "Operation",
                help: "Choose the DICOMDIR operation to perform."
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
            case "create":
                createForm
            case "validate":
                validateForm
            case "dump":
                dumpForm
            default:
                createForm
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if subcommand == nil {
                subcommand = tool.subcommands?.first?.id
            }
        }
    }

    // MARK: - Create Subcommand

    @ViewBuilder
    private var createForm: some View {
        ParameterSectionView(
            title: "Input",
            help: "Select the directory containing DICOM files to index.",
            isRequired: true
        ) {
            FileDropZoneView(
                parameterID: "input",
                label: "Input Directory",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(title: "Output") {
            OutputPathView(
                parameterID: "output",
                label: "DICOMDIR Output",
                isRequired: false,
                parameterValues: $parameterValues
            )
        }
    }

    // MARK: - Validate Subcommand

    @ViewBuilder
    private var validateForm: some View {
        ParameterSectionView(
            title: "Input",
            help: "Select a DICOMDIR file to validate its structure and references.",
            isRequired: true
        ) {
            FileDropZoneView(
                parameterID: "input",
                label: "DICOMDIR File",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }
    }

    // MARK: - Dump Subcommand

    @ViewBuilder
    private var dumpForm: some View {
        ParameterSectionView(
            title: "Input",
            help: "Select a DICOMDIR file to display its contents.",
            isRequired: true
        ) {
            FileDropZoneView(
                parameterID: "input",
                label: "DICOMDIR File",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }
    }
}
#endif
