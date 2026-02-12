#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-xml` tool, enabling conversion
/// between DICOM and XML formats with pretty-printing and keyword options.
public struct DicomXmlView: View {
    @Binding var parameterValues: [String: String]

    private var tool: ToolDefinition { ToolRegistry.dicomXml }

    public init(parameterValues: Binding<[String: String]>) {
        self._parameterValues = parameterValues
    }

    public var body: some View {
        Form {
            // MARK: Input
            ParameterSectionView(
                title: "Input",
                help: "Select a DICOM file to convert to XML, or an XML file to convert back to DICOM when Reverse mode is enabled.",
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

            // MARK: Options
            ParameterSectionView(
                title: "Options",
                help: "Configure XML output behavior including reverse conversion, formatting, and keyword inclusion."
            ) {
                Toggle("Reverse", isOn: Binding(
                    get: { parameterValues["reverse"] == "true" },
                    set: { parameterValues["reverse"] = $0 ? "true" : "" }
                ))
                .help("Convert XML back to DICOM format")

                Toggle("Pretty Print", isOn: Binding(
                    get: { parameterValues["pretty"] == "true" },
                    set: { parameterValues["pretty"] = $0 ? "true" : "" }
                ))
                .help("Pretty-print the XML output with indentation")

                Toggle("No Keywords", isOn: Binding(
                    get: { parameterValues["no-keywords"] == "true" },
                    set: { parameterValues["no-keywords"] = $0 ? "true" : "" }
                ))
                .help("Omit keyword attributes from XML elements")

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
