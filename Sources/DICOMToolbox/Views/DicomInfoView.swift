#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-info` tool, providing structured sections
/// for input file selection, output format options, tag filtering, and boolean flags.
public struct DicomInfoView: View {
    @Binding var parameterValues: [String: String]

    private var tool: ToolDefinition { ToolRegistry.dicomInfo }

    public init(parameterValues: Binding<[String: String]>) {
        self._parameterValues = parameterValues
    }

    public var body: some View {
        Form {
            // MARK: Input
            ParameterSectionView(
                title: "Input",
                help: "DICOM metadata includes patient demographics, study and series information, acquisition parameters, and technical details about the image encoding.",
                isRequired: true
            ) {
                FileDropZoneView(
                    parameterID: "filePath",
                    label: "Input File",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Output Options
            ParameterSectionView(title: "Output Options") {
                if let formatParam = tool.parameters.first(where: { $0.id == "format" }) {
                    EnumPickerView(
                        parameter: formatParam,
                        parameterValues: $parameterValues
                    )
                }

                if let tagParam = tool.parameters.first(where: { $0.id == "tag" }) {
                    RepeatableOptionView(
                        parameter: tagParam,
                        parameterValues: $parameterValues
                    )
                }
            }

            // MARK: Options
            ParameterSectionView(title: "Options") {
                Toggle("Show Private Tags", isOn: Binding(
                    get: { parameterValues["show-private"] == "true" },
                    set: { parameterValues["show-private"] = $0 ? "true" : "" }
                ))
                .help("Include vendor-specific private tags in the output")

                Toggle("Show Statistics", isOn: Binding(
                    get: { parameterValues["statistics"] == "true" },
                    set: { parameterValues["statistics"] = $0 ? "true" : "" }
                ))
                .help("Display file size, tag count, and encoding statistics")

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
