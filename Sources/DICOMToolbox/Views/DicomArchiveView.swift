#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-archive` tool, enabling archival
/// of DICOM files into ZIP or TAR format with recursive processing.
public struct DicomArchiveView: View {
    @Binding var parameterValues: [String: String]

    private var tool: ToolDefinition { ToolRegistry.dicomArchive }

    public init(parameterValues: Binding<[String: String]>) {
        self._parameterValues = parameterValues
    }

    public var body: some View {
        Form {
            // MARK: Input
            ParameterSectionView(
                title: "Input",
                help: "Select files or a directory to archive.",
                isRequired: true
            ) {
                FileDropZoneView(
                    parameterID: "input",
                    label: "Input",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Output
            ParameterSectionView(title: "Output", isRequired: true) {
                OutputPathView(
                    parameterID: "output",
                    label: "Archive Output",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Archive Options
            ParameterSectionView(
                title: "Archive Options",
                help: "Choose the archive format for the output file."
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
                Toggle("Recursive", isOn: Binding(
                    get: { parameterValues["recursive"] == "true" },
                    set: { parameterValues["recursive"] = $0 ? "true" : "" }
                ))
                .help("Process all DICOM files in subdirectories")
            }
        }
        .formStyle(.grouped)
    }
}
#endif
