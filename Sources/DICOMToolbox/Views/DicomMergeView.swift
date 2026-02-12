#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-merge` tool, enabling merging
/// of multiple DICOM files with sort and validation options.
public struct DicomMergeView: View {
    @Binding var parameterValues: [String: String]

    private var tool: ToolDefinition { ToolRegistry.dicomMerge }

    public init(parameterValues: Binding<[String: String]>) {
        self._parameterValues = parameterValues
    }

    public var body: some View {
        Form {
            // MARK: Input
            ParameterSectionView(
                title: "Input Files",
                help: "Select multiple DICOM files to merge into a single output. You can drop multiple files or use Browse to select them.",
                isRequired: true
            ) {
                FileDropZoneView(
                    parameterID: "inputs",
                    label: "Input Files",
                    isRequired: true,
                    allowsMultipleFiles: true,
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

            // MARK: Merge Options
            ParameterSectionView(
                title: "Merge Options",
                help: "Configure how files are sorted and the output format."
            ) {
                if let formatParam = tool.parameters.first(where: { $0.id == "format" }) {
                    EnumPickerView(
                        parameter: formatParam,
                        parameterValues: $parameterValues
                    )
                }

                HStack {
                    Text("Sort By")
                    Spacer()
                    TextField("e.g. InstanceNumber", text: Binding(
                        get: { parameterValues["sort-by"] ?? "" },
                        set: { parameterValues["sort-by"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
                .help("Sort files by a DICOM field before merging")
            }

            // MARK: Options
            ParameterSectionView(title: "Options") {
                Toggle("Validate", isOn: Binding(
                    get: { parameterValues["validate"] == "true" },
                    set: { parameterValues["validate"] = $0 ? "true" : "" }
                ))
                .help("Validate the merged output file")

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
