#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-split` tool, enabling splitting
/// of multi-frame DICOM files into individual frames with format and range options.
public struct DicomSplitView: View {
    @Binding var parameterValues: [String: String]

    private var tool: ToolDefinition { ToolRegistry.dicomSplit }

    public init(parameterValues: Binding<[String: String]>) {
        self._parameterValues = parameterValues
    }

    public var body: some View {
        Form {
            // MARK: Input
            ParameterSectionView(
                title: "Input",
                help: "Select a multi-frame DICOM file to split into individual frames.",
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
                    label: "Output Directory",
                    isRequired: false,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Split Options
            ParameterSectionView(
                title: "Split Options",
                help: "Specify the frame range and output format for split frames."
            ) {
                HStack {
                    Text("Frame Range")
                    Spacer()
                    TextField("e.g. 1-10", text: Binding(
                        get: { parameterValues["frames"] ?? "" },
                        set: { parameterValues["frames"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
                .help("Frame range to extract (e.g., 1-10, 5, 1-5,8,10-15)")

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
