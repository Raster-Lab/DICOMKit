#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-anon` tool, providing structured sections
/// for input/output, anonymization profile selection, date shifting, UID regeneration,
/// custom tag actions, and safety options like dry run and backup.
public struct DicomAnonView: View {
    @Binding var parameterValues: [String: String]

    private var tool: ToolDefinition { ToolRegistry.dicomAnon }

    public init(parameterValues: Binding<[String: String]>) {
        self._parameterValues = parameterValues
    }

    public var body: some View {
        Form {
            // MARK: Input
            ParameterSectionView(
                title: "Input",
                help: "Select the DICOM file or directory containing files to anonymize.",
                isRequired: true
            ) {
                FileDropZoneView(
                    parameterID: "inputPath",
                    label: "Input File/Directory",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Output
            ParameterSectionView(title: "Output") {
                OutputPathView(
                    parameterID: "output",
                    label: "Output Path",
                    isRequired: false,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Anonymization Profile
            ParameterSectionView(
                title: "Anonymization Profile",
                help: "Profiles define which tags are removed, replaced, or preserved according to DICOM PS3.15 Attribute Confidentiality Profiles."
            ) {
                if let profileParam = tool.parameters.first(where: { $0.id == "profile" }) {
                    EnumPickerView(
                        parameter: profileParam,
                        parameterValues: $parameterValues
                    )
                }

                HStack {
                    Text("Date Shift (days)")
                    Spacer()
                    TextField("e.g. 30", text: Binding(
                        get: { parameterValues["shift-dates"] ?? "" },
                        set: { parameterValues["shift-dates"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 100)
                }
                .help("Shift all dates by the specified number of days. Preserves relative time intervals between dates within the same study.")

                Toggle("Regenerate UIDs", isOn: Binding(
                    get: { parameterValues["regenerate-uids"] == "true" },
                    set: { parameterValues["regenerate-uids"] = $0 ? "true" : "" }
                ))
                .help("Generate new unique identifiers (UIDs) for Study, Series, and SOP Instance UIDs")
            }

            // MARK: Custom Tag Actions
            ParameterSectionView(
                title: "Custom Tag Actions",
                help: "Override the profile by specifying individual tags to remove, replace, or keep."
            ) {
                if let removeParam = tool.parameters.first(where: { $0.id == "remove" }) {
                    RepeatableOptionView(
                        parameter: removeParam,
                        parameterValues: $parameterValues
                    )
                }

                if let replaceParam = tool.parameters.first(where: { $0.id == "replace" }) {
                    RepeatableOptionView(
                        parameter: replaceParam,
                        parameterValues: $parameterValues
                    )
                }

                if let keepParam = tool.parameters.first(where: { $0.id == "keep" }) {
                    RepeatableOptionView(
                        parameter: keepParam,
                        parameterValues: $parameterValues
                    )
                }
            }

            // MARK: Options
            ParameterSectionView(title: "Options") {
                Toggle("Recursive", isOn: Binding(
                    get: { parameterValues["recursive"] == "true" },
                    set: { parameterValues["recursive"] = $0 ? "true" : "" }
                ))
                .help("Process all DICOM files in subdirectories")

                Toggle("Dry Run", isOn: Binding(
                    get: { parameterValues["dry-run"] == "true" },
                    set: { parameterValues["dry-run"] = $0 ? "true" : "" }
                ))
                .foregroundStyle(.blue)
                .help("Preview the anonymization changes without modifying any files")

                Toggle("Create Backup", isOn: Binding(
                    get: { parameterValues["backup"] == "true" },
                    set: { parameterValues["backup"] = $0 ? "true" : "" }
                ))
                .help("Create backup copies of original files before anonymization")
            }

            // MARK: Audit
            ParameterSectionView(
                title: "Audit",
                help: "Generate an audit log documenting all anonymization actions for regulatory compliance."
            ) {
                OutputPathView(
                    parameterID: "audit-log",
                    label: "Audit Log File",
                    isRequired: false,
                    parameterValues: $parameterValues
                )
            }
        }
        .formStyle(.grouped)
    }
}
#endif
