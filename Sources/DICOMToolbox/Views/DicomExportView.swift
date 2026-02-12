#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-export` tool, providing a subcommand picker
/// and dynamic parameter forms for single and bulk image export operations.
public struct DicomExportView: View {
    @Binding var parameterValues: [String: String]
    @Binding var subcommand: String?

    private var tool: ToolDefinition { ToolRegistry.dicomExport }

    public init(parameterValues: Binding<[String: String]>, subcommand: Binding<String?>) {
        self._parameterValues = parameterValues
        self._subcommand = subcommand
    }

    private var currentSubcommand: String {
        subcommand ?? tool.subcommands?.first?.id ?? "single"
    }

    public var body: some View {
        Form {
            // MARK: Subcommand
            ParameterSectionView(
                title: "Export Mode",
                help: "Choose between exporting a single image or bulk-exporting multiple files."
            ) {
                if let subcommands = tool.subcommands {
                    Picker("Mode", selection: Binding(
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
            case "single":
                singleForm
            case "bulk":
                bulkForm
            default:
                singleForm
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if subcommand == nil {
                subcommand = tool.subcommands?.first?.id
            }
        }
    }

    // MARK: - Single Export Subcommand

    @ViewBuilder
    private var singleForm: some View {
        ParameterSectionView(title: "Input", isRequired: true) {
            FileDropZoneView(
                parameterID: "input",
                label: "Input File",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(title: "Output", isRequired: true) {
            OutputPathView(
                parameterID: "output",
                label: "Output File",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(
            title: "Export Settings",
            help: "Choose the output image format for the exported file."
        ) {
            if let sub = tool.subcommands?.first(where: { $0.id == "single" }),
               let formatParam = sub.parameters.first(where: { $0.id == "format" }) {
                EnumPickerView(
                    parameter: formatParam,
                    parameterValues: $parameterValues
                )
            }
        }
    }

    // MARK: - Bulk Export Subcommand

    @ViewBuilder
    private var bulkForm: some View {
        ParameterSectionView(title: "Input", isRequired: true) {
            FileDropZoneView(
                parameterID: "input",
                label: "Input Directory",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(title: "Output", isRequired: true) {
            OutputPathView(
                parameterID: "output",
                label: "Output Directory",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(
            title: "Bulk Settings",
            help: "Configure format and recursive processing for bulk export."
        ) {
            if let sub = tool.subcommands?.first(where: { $0.id == "bulk" }),
               let formatParam = sub.parameters.first(where: { $0.id == "format" }) {
                EnumPickerView(
                    parameter: formatParam,
                    parameterValues: $parameterValues
                )
            }

            Toggle("Recursive", isOn: Binding(
                get: { parameterValues["recursive"] == "true" },
                set: { parameterValues["recursive"] = $0 ? "true" : "" }
            ))
            .help("Process all DICOM files in subdirectories")
        }
    }
}
#endif
