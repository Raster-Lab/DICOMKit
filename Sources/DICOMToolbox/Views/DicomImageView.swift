#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-image` tool, enabling encapsulation
/// of standard image files (PNG, JPEG, etc.) into DICOM format with patient metadata.
public struct DicomImageView: View {
    @Binding var parameterValues: [String: String]

    private var tool: ToolDefinition { ToolRegistry.dicomImage }

    public init(parameterValues: Binding<[String: String]>) {
        self._parameterValues = parameterValues
    }

    public var body: some View {
        Form {
            // MARK: Input
            ParameterSectionView(
                title: "Input",
                help: "Select an image file (PNG, JPEG, TIFF, etc.) to encapsulate as a DICOM object.",
                isRequired: true
            ) {
                FileDropZoneView(
                    parameterID: "input",
                    label: "Input Image",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Output
            ParameterSectionView(title: "Output", isRequired: true) {
                OutputPathView(
                    parameterID: "output",
                    label: "Output DICOM File",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Patient Metadata
            ParameterSectionView(
                title: "Patient Metadata",
                help: "Patient information to embed in the DICOM output."
            ) {
                HStack {
                    Text("Patient Name")
                    Spacer()
                    TextField("e.g. SMITH^JOHN", text: Binding(
                        get: { parameterValues["patient-name"] ?? "" },
                        set: { parameterValues["patient-name"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
                .help("Patient name for the DICOM output")

                HStack {
                    Text("Patient ID")
                    Spacer()
                    TextField("e.g. 12345", text: Binding(
                        get: { parameterValues["patient-id"] ?? "" },
                        set: { parameterValues["patient-id"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
                .help("Patient ID for the DICOM output")

                HStack {
                    Text("Modality")
                    Spacer()
                    TextField("e.g. OT", text: Binding(
                        get: { parameterValues["modality"] ?? "" },
                        set: { parameterValues["modality"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
                .help("Imaging modality code (e.g., OT for Other, SC for Secondary Capture)")
            }

            // MARK: Options
            ParameterSectionView(title: "Options") {
                Toggle("Use EXIF", isOn: Binding(
                    get: { parameterValues["use-exif"] == "true" },
                    set: { parameterValues["use-exif"] = $0 ? "true" : "" }
                ))
                .help("Import EXIF metadata from the source image")

                Toggle("Recursive", isOn: Binding(
                    get: { parameterValues["recursive"] == "true" },
                    set: { parameterValues["recursive"] = $0 ? "true" : "" }
                ))
                .help("Process all image files in subdirectories")
            }
        }
        .formStyle(.grouped)
    }
}
#endif
