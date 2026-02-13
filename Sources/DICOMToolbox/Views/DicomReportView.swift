#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-report` tool, enabling generation
/// of clinical reports from DICOM Structured Report objects with template,
/// language, branding, and image embedding support.
public struct DicomReportView: View {
    @Binding var parameterValues: [String: String]

    private var tool: ToolDefinition { ToolRegistry.dicomReport }

    public init(parameterValues: Binding<[String: String]>) {
        self._parameterValues = parameterValues
    }

    public var body: some View {
        Form {
            // MARK: Input
            ParameterSectionView(
                title: "Input",
                help: "Select a DICOM Structured Report (SR) file to generate a clinical report from.",
                isRequired: true
            ) {
                FileDropZoneView(
                    parameterID: "filePath",
                    label: "DICOM SR File",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Output
            ParameterSectionView(title: "Output", isRequired: true) {
                OutputPathView(
                    parameterID: "output",
                    label: "Output File",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Report Format
            ParameterSectionView(
                title: "Report Format",
                help: "Choose the output format for the generated report. HTML supports image embedding, branding, and styled templates."
            ) {
                if let formatParam = tool.parameters.first(where: { $0.id == "format" }) {
                    EnumPickerView(
                        parameter: formatParam,
                        parameterValues: $parameterValues
                    )
                }
            }

            // MARK: Template
            ParameterSectionView(
                title: "Report Template",
                help: "Select a specialty-specific template that controls section ordering, color scheme, and content focus."
            ) {
                if let templateParam = tool.parameters.first(where: { $0.id == "template" }) {
                    EnumPickerView(
                        parameter: templateParam,
                        parameterValues: $parameterValues
                    )
                }
            }

            // MARK: Language
            ParameterSectionView(
                title: "Language",
                help: "Select the language for report section headers and labels."
            ) {
                if let langParam = tool.parameters.first(where: { $0.id == "language" }) {
                    EnumPickerView(
                        parameter: langParam,
                        parameterValues: $parameterValues
                    )
                }
            }

            // MARK: Branding
            ParameterSectionView(
                title: "Branding",
                help: "Customize the report with your institution's logo, title, and footer text. Applicable to HTML and PDF formats."
            ) {
                HStack {
                    Text("Custom Title")
                    Spacer()
                    TextField("Override SR title", text: Binding(
                        get: { parameterValues["title"] ?? "" },
                        set: { parameterValues["title"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 250)
                }
                .help("Custom report title (overrides the SR document title)")

                FileDropZoneView(
                    parameterID: "logo",
                    label: "Logo Image",
                    isRequired: false,
                    parameterValues: $parameterValues
                )

                HStack {
                    Text("Footer Text")
                    Spacer()
                    TextField("e.g. Confidential", text: Binding(
                        get: { parameterValues["footer"] ?? "" },
                        set: { parameterValues["footer"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 250)
                }
                .help("Custom footer text for the report")
            }

            // MARK: Image Embedding
            ParameterSectionView(
                title: "Image Embedding",
                help: "Embed referenced DICOM images into the report as inline images. Only supported for HTML format."
            ) {
                Toggle("Embed Images", isOn: Binding(
                    get: { parameterValues["embed-images"] == "true" },
                    set: { parameterValues["embed-images"] = $0 ? "true" : "" }
                ))
                .help("Embed referenced images from the SR document into the report")

                FileDropZoneView(
                    parameterID: "image-dir",
                    label: "Image Directory",
                    isRequired: false,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Content Options
            ParameterSectionView(title: "Content Options") {
                Toggle("Include Measurements", isOn: Binding(
                    get: { parameterValues["include-measurements"] != "false" },
                    set: { parameterValues["include-measurements"] = $0 ? "" : "false" }
                ))
                .help("Include measurement tables in the report output")

                Toggle("Include Summary", isOn: Binding(
                    get: { parameterValues["include-summary"] != "false" },
                    set: { parameterValues["include-summary"] = $0 ? "" : "false" }
                ))
                .help("Include finding summaries in the report")
            }

            // MARK: Advanced Options
            ParameterSectionView(title: "Advanced") {
                Toggle("Force Parse", isOn: Binding(
                    get: { parameterValues["force"] == "true" },
                    set: { parameterValues["force"] = $0 ? "true" : "" }
                ))
                .help("Force parsing of files without DICM prefix")

                Toggle("Verbose", isOn: Binding(
                    get: { parameterValues["verbose"] == "true" },
                    set: { parameterValues["verbose"] = $0 ? "true" : "" }
                ))
                .help("Enable verbose output for debugging")
            }
        }
        .formStyle(.grouped)
    }
}
#endif
