#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-convert` tool, providing structured sections
/// for input/output selection, transfer syntax conversion, image format export,
/// and processing options like windowing and private tag removal.
public struct DicomConvertView: View {
    @Binding var parameterValues: [String: String]

    private var tool: ToolDefinition { ToolRegistry.dicomConvert }

    public init(parameterValues: Binding<[String: String]>) {
        self._parameterValues = parameterValues
    }

    public var body: some View {
        Form {
            // MARK: Input
            ParameterSectionView(
                title: "Input",
                help: "Select the DICOM file or directory to convert. When a directory is selected with Recursive enabled, all DICOM files within will be processed.",
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
            ParameterSectionView(title: "Output", isRequired: true) {
                OutputPathView(
                    parameterID: "output",
                    label: "Output Path",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Conversion Options
            ParameterSectionView(
                title: "Conversion Options",
                help: "Choose the target transfer syntax for DICOM-to-DICOM conversion, or select an image format to export pixel data."
            ) {
                if let syntaxParam = tool.parameters.first(where: { $0.id == "transfer-syntax" }) {
                    EnumPickerView(
                        parameter: syntaxParam,
                        parameterValues: $parameterValues
                    )
                }

                if let formatParam = tool.parameters.first(where: { $0.id == "format" }) {
                    EnumPickerView(
                        parameter: formatParam,
                        parameterValues: $parameterValues
                    )
                }

                // JPEG Quality slider - shown contextually
                HStack {
                    Text("JPEG Quality")
                    Spacer()
                    TextField("1-100", text: Binding(
                        get: { parameterValues["quality"] ?? "" },
                        set: { parameterValues["quality"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 100)
                }
                .help("JPEG compression quality (1-100, default: 85). Only applies when output format is JPEG.")
            }

            // MARK: Windowing
            ParameterSectionView(
                title: "Windowing",
                help: "Window/level settings control how pixel values are mapped to display brightness. These are essential for proper visualization of CT, MR, and other modalities."
            ) {
                HStack {
                    Text("Window Center")
                    Spacer()
                    TextField("e.g. 40", text: Binding(
                        get: { parameterValues["window-center"] ?? "" },
                        set: { parameterValues["window-center"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 150)
                }
                .help("Center of the display window (Hounsfield units for CT)")

                HStack {
                    Text("Window Width")
                    Spacer()
                    TextField("e.g. 400", text: Binding(
                        get: { parameterValues["window-width"] ?? "" },
                        set: { parameterValues["window-width"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 150)
                }
                .help("Width of the display window")

                HStack {
                    Text("Frame Number")
                    Spacer()
                    TextField("0", text: Binding(
                        get: { parameterValues["frame"] ?? "" },
                        set: { parameterValues["frame"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 100)
                }
                .help("Frame number to extract from multi-frame DICOM files (0-indexed)")

                Toggle("Apply Window", isOn: Binding(
                    get: { parameterValues["apply-window"] == "true" },
                    set: { parameterValues["apply-window"] = $0 ? "true" : "" }
                ))
                .help("Apply the window center/width values when exporting to image formats")
            }

            // MARK: Options
            ParameterSectionView(title: "Options") {
                Toggle("Strip Private Tags", isOn: Binding(
                    get: { parameterValues["strip-private"] == "true" },
                    set: { parameterValues["strip-private"] = $0 ? "true" : "" }
                ))
                .help("Remove vendor-specific private tags from the output file")

                Toggle("Validate Output", isOn: Binding(
                    get: { parameterValues["validate"] == "true" },
                    set: { parameterValues["validate"] = $0 ? "true" : "" }
                ))
                .help("Run validation on the converted output file")

                Toggle("Recursive", isOn: Binding(
                    get: { parameterValues["recursive"] == "true" },
                    set: { parameterValues["recursive"] = $0 ? "true" : "" }
                ))
                .help("Process all DICOM files in subdirectories")

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
