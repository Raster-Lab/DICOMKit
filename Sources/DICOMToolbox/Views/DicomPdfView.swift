#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-pdf` tool, enabling encapsulation
/// of PDF files into DICOM format or extraction of PDFs from DICOM objects.
public struct DicomPdfView: View {
    @Binding var parameterValues: [String: String]

    private var tool: ToolDefinition { ToolRegistry.dicomPdf }

    public init(parameterValues: Binding<[String: String]>) {
        self._parameterValues = parameterValues
    }

    public var body: some View {
        Form {
            // MARK: Input
            ParameterSectionView(
                title: "Input",
                help: "Select a PDF file to encapsulate into DICOM, or a DICOM file to extract a PDF from (with Extract enabled).",
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
            ParameterSectionView(title: "Output", isRequired: true) {
                OutputPathView(
                    parameterID: "output",
                    label: "Output File",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Patient Metadata
            ParameterSectionView(
                title: "Patient Metadata",
                help: "Patient information to embed when encapsulating a PDF into DICOM format."
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
                .help("Patient name for DICOM encapsulation")

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
                .help("Patient ID for DICOM encapsulation")
            }

            // MARK: Options
            ParameterSectionView(title: "Options") {
                Toggle("Extract", isOn: Binding(
                    get: { parameterValues["extract"] == "true" },
                    set: { parameterValues["extract"] = $0 ? "true" : "" }
                ))
                .help("Extract PDF from a DICOM file instead of encapsulating")

                Toggle("Show Metadata", isOn: Binding(
                    get: { parameterValues["show-metadata"] == "true" },
                    set: { parameterValues["show-metadata"] = $0 ? "true" : "" }
                ))
                .help("Display DICOM metadata information")
            }
        }
        .formStyle(.grouped)
    }
}
#endif
