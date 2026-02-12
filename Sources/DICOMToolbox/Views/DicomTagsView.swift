#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-tags` tool, allowing users to view,
/// set, delete, and copy DICOM tag values with dry-run preview support.
public struct DicomTagsView: View {
    @Binding var parameterValues: [String: String]

    private var tool: ToolDefinition { ToolRegistry.dicomTags }

    public init(parameterValues: Binding<[String: String]>) {
        self._parameterValues = parameterValues
    }

    public var body: some View {
        Form {
            // MARK: Input
            ParameterSectionView(title: "Input", isRequired: true) {
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
                    parameterValues: $parameterValues
                )
            }

            // MARK: Modify Tags
            ParameterSectionView(
                title: "Modify Tags",
                help: "Use TAG=VALUE format to set tags (e.g. 0010,0010=Anonymous). Specify tag IDs to delete."
            ) {
                if let setParam = tool.parameters.first(where: { $0.id == "set" }) {
                    RepeatableOptionView(
                        parameter: setParam,
                        parameterValues: $parameterValues
                    )
                }

                if let deleteParam = tool.parameters.first(where: { $0.id == "delete" }) {
                    RepeatableOptionView(
                        parameter: deleteParam,
                        parameterValues: $parameterValues
                    )
                }
            }

            // MARK: Copy Tags
            ParameterSectionView(
                title: "Copy Tags",
                help: "Copy tag values from a reference DICOM file or use a tag list file to specify which tags to copy."
            ) {
                FileDropZoneView(
                    parameterID: "copy-from",
                    label: "Copy From",
                    parameterValues: $parameterValues
                )

                FileDropZoneView(
                    parameterID: "tags",
                    label: "Tag List File",
                    parameterValues: $parameterValues
                )
            }

            // MARK: Options
            ParameterSectionView(title: "Options") {
                Toggle("Delete Private Tags", isOn: Binding(
                    get: { parameterValues["delete-private"] == "true" },
                    set: { parameterValues["delete-private"] = $0 ? "true" : "" }
                ))
                .help("Remove all vendor-specific private tags from the file")

                Toggle("Dry Run", isOn: Binding(
                    get: { parameterValues["dry-run"] == "true" },
                    set: { parameterValues["dry-run"] = $0 ? "true" : "" }
                ))
                .bold()
                .help("Preview all modifications without writing changes to disk")
            }
        }
        .formStyle(.grouped)
    }
}
#endif
