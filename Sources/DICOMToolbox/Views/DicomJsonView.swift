#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-json` tool, enabling conversion
/// between DICOM and JSON formats with pretty-printing and metadata options.
public struct DicomJsonView: View {
    @Binding var parameterValues: [String: String]

    private var tool: ToolDefinition { ToolRegistry.dicomJson }

    public init(parameterValues: Binding<[String: String]>) {
        self._parameterValues = parameterValues
    }

    public var body: some View {
        Form {
            // MARK: Input
            ParameterSectionView(
                title: "Input",
                help: "Select a DICOM file to convert to JSON, or a JSON file to convert back to DICOM when Reverse mode is enabled.",
                isRequired: true
            ) {
                FileDropZoneView(
                    parameterID: "input",
                    label: "Input File",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Output
            ParameterSectionView(title: "Output") {
                OutputPathView(
                    parameterID: "output",
                    label: "Output File",
                    isRequired: false,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Format Options
            ParameterSectionView(
                title: "Format Options",
                help: "Choose the JSON output format. Standard uses a simple key-value structure; DICOMweb uses the DICOM JSON Model (PS3.18)."
            ) {
                if let formatParam = tool.parameters.first(where: { $0.id == "format" }) {
                    EnumPickerView(
                        parameter: formatParam,
                        parameterValues: $parameterValues
                    )
                }
            }

            // MARK: Options
            ParameterSectionView(title: "Options") {
                Toggle("Reverse", isOn: Binding(
                    get: { parameterValues["reverse"] == "true" },
                    set: { parameterValues["reverse"] = $0 ? "true" : "" }
                ))
                .help("Convert JSON back to DICOM format")

                Toggle("Pretty Print", isOn: Binding(
                    get: { parameterValues["pretty"] == "true" },
                    set: { parameterValues["pretty"] = $0 ? "true" : "" }
                ))
                .help("Pretty-print the JSON output with indentation")

                Toggle("Metadata Only", isOn: Binding(
                    get: { parameterValues["metadata-only"] == "true" },
                    set: { parameterValues["metadata-only"] = $0 ? "true" : "" }
                ))
                .help("Export only metadata, excluding pixel data")
            }
        }
        .formStyle(.grouped)
    }
}
#endif
