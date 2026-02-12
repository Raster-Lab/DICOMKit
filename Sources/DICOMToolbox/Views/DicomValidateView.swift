#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-validate` tool, providing structured sections
/// for input selection, validation level configuration, output format, and strictness options.
public struct DicomValidateView: View {
    @Binding var parameterValues: [String: String]

    private var tool: ToolDefinition { ToolRegistry.dicomValidate }

    public init(parameterValues: Binding<[String: String]>) {
        self._parameterValues = parameterValues
    }

    public var body: some View {
        Form {
            // MARK: Input
            ParameterSectionView(
                title: "Input",
                help: "Select the DICOM file or directory to validate against the DICOM standard.",
                isRequired: true
            ) {
                FileDropZoneView(
                    parameterID: "inputPath",
                    label: "Input File/Directory",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Validation Settings
            ParameterSectionView(
                title: "Validation Settings",
                help: "Configure the depth of validation. Higher levels perform more thorough checks but take longer."
            ) {
                if let levelParam = tool.parameters.first(where: { $0.id == "level" }) {
                    EnumPickerView(
                        parameter: levelParam,
                        parameterValues: $parameterValues
                    )
                }

                if let formatParam = tool.parameters.first(where: { $0.id == "format" }) {
                    EnumPickerView(
                        parameter: formatParam,
                        parameterValues: $parameterValues
                    )
                }
            }

            // MARK: Output
            ParameterSectionView(title: "Output") {
                OutputPathView(
                    parameterID: "output",
                    label: "Report File (optional)",
                    isRequired: false,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Options
            ParameterSectionView(title: "Options") {
                Toggle("Detailed Report", isOn: Binding(
                    get: { parameterValues["detailed"] == "true" },
                    set: { parameterValues["detailed"] = $0 ? "true" : "" }
                ))
                .help("Include detailed findings and DICOM standard references in the report")

                Toggle("Recursive", isOn: Binding(
                    get: { parameterValues["recursive"] == "true" },
                    set: { parameterValues["recursive"] = $0 ? "true" : "" }
                ))
                .help("Process all DICOM files in subdirectories")

                Toggle("Strict Mode", isOn: Binding(
                    get: { parameterValues["strict"] == "true" },
                    set: { parameterValues["strict"] = $0 ? "true" : "" }
                ))
                .foregroundStyle(.orange)
                .help("Treat warnings as errors — any non-conformance will cause validation to fail")

                Toggle("Force Parse", isOn: Binding(
                    get: { parameterValues["force"] == "true" },
                    set: { parameterValues["force"] = $0 ? "true" : "" }
                ))
                .foregroundStyle(.orange)
                .help("Attempt to parse files that lack the standard DICM preamble")
            }
        }
        .formStyle(.grouped)
    }
}
#endif
