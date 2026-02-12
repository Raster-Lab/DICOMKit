#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-study` tool, providing subcommand-based
/// forms for study organization, summary, checking, statistics, and comparison.
public struct DicomStudyView: View {
    @Binding var parameterValues: [String: String]
    @Binding var subcommand: String?

    private var tool: ToolDefinition { ToolRegistry.dicomStudy }

    public init(parameterValues: Binding<[String: String]>, subcommand: Binding<String?>) {
        self._parameterValues = parameterValues
        self._subcommand = subcommand
    }

    private var currentSubcommand: String {
        subcommand ?? tool.subcommands?.first?.id ?? "organize"
    }

    public var body: some View {
        Form {
            // MARK: Subcommand
            ParameterSectionView(
                title: "Operation",
                help: "Choose the study management operation to perform. Organize restructures files, Summary shows an overview, Check validates completeness, Stats provides detailed metrics, and Compare finds differences between studies."
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
            case "organize":
                organizeForm
            case "summary":
                summaryForm
            case "check":
                checkForm
            case "stats":
                statsForm
            case "compare":
                compareForm
            default:
                organizeForm
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if subcommand == nil {
                subcommand = tool.subcommands?.first?.id
            }
        }
    }

    // MARK: - Organize Subcommand

    @ViewBuilder
    private var organizeForm: some View {
        ParameterSectionView(
            title: "Input",
            help: "Select the directory containing DICOM files to organize.",
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
                label: "Output Directory",
                isRequired: false,
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(
            title: "Organization Settings",
            help: "Configure the pattern used to organize files. Use placeholders like {PatientName}, {StudyDate}, {Modality}, {SeriesNumber}."
        ) {
            HStack {
                Text("Pattern")
                Spacer()
                TextField("{PatientName}/{StudyDate}/{Modality}", text: Binding(
                    get: { parameterValues["pattern"] ?? "" },
                    set: { parameterValues["pattern"] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 350)
            }
            .help("Directory organization pattern with placeholders")

            if let sub = tool.subcommands?.first(where: { $0.id == "organize" }),
               let formatParam = sub.parameters.first(where: { $0.id == "format" }) {
                EnumPickerView(
                    parameter: formatParam,
                    parameterValues: $parameterValues
                )
            }
        }
    }

    // MARK: - Summary Subcommand

    @ViewBuilder
    private var summaryForm: some View {
        ParameterSectionView(
            title: "Input",
            help: "Select a study directory to display its summary.",
            isRequired: true
        ) {
            FileDropZoneView(
                parameterID: "input",
                label: "Study Directory",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(title: "Output Format") {
            if let sub = tool.subcommands?.first(where: { $0.id == "summary" }),
               let formatParam = sub.parameters.first(where: { $0.id == "format" }) {
                EnumPickerView(
                    parameter: formatParam,
                    parameterValues: $parameterValues
                )
            }
        }
    }

    // MARK: - Check Subcommand

    @ViewBuilder
    private var checkForm: some View {
        ParameterSectionView(
            title: "Input",
            help: "Select a study directory to check for completeness.",
            isRequired: true
        ) {
            FileDropZoneView(
                parameterID: "input",
                label: "Study Directory",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(
            title: "Check Settings",
            help: "Optionally specify the expected number of series to validate completeness."
        ) {
            HStack {
                Text("Expected Series")
                Spacer()
                TextField("Number", text: Binding(
                    get: { parameterValues["expected-series"] ?? "" },
                    set: { parameterValues["expected-series"] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 100)
            }
            .help("Expected number of series in the study")

            if let sub = tool.subcommands?.first(where: { $0.id == "check" }),
               let formatParam = sub.parameters.first(where: { $0.id == "format" }) {
                EnumPickerView(
                    parameter: formatParam,
                    parameterValues: $parameterValues
                )
            }
        }
    }

    // MARK: - Stats Subcommand

    @ViewBuilder
    private var statsForm: some View {
        ParameterSectionView(
            title: "Input",
            help: "Select a study directory to display detailed statistics.",
            isRequired: true
        ) {
            FileDropZoneView(
                parameterID: "input",
                label: "Study Directory",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(title: "Output Format") {
            if let sub = tool.subcommands?.first(where: { $0.id == "stats" }),
               let formatParam = sub.parameters.first(where: { $0.id == "format" }) {
                EnumPickerView(
                    parameter: formatParam,
                    parameterValues: $parameterValues
                )
            }
        }
    }

    // MARK: - Compare Subcommand

    @ViewBuilder
    private var compareForm: some View {
        ParameterSectionView(
            title: "First Study",
            help: "Select the first study directory for comparison.",
            isRequired: true
        ) {
            FileDropZoneView(
                parameterID: "input",
                label: "First Study Directory",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(
            title: "Second Study",
            help: "Select the second study directory for comparison.",
            isRequired: true
        ) {
            FileDropZoneView(
                parameterID: "input2",
                label: "Second Study Directory",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(title: "Output Format") {
            if let sub = tool.subcommands?.first(where: { $0.id == "compare" }),
               let formatParam = sub.parameters.first(where: { $0.id == "format" }) {
                EnumPickerView(
                    parameter: formatParam,
                    parameterValues: $parameterValues
                )
            }
        }
    }
}
#endif
