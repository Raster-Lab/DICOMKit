#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-diff` tool, enabling side-by-side
/// comparison of two DICOM files with configurable tolerance, tag filtering,
/// and pixel data comparison options.
public struct DicomDiffView: View {
    @Binding var parameterValues: [String: String]

    private var tool: ToolDefinition { ToolRegistry.dicomDiff }

    public init(parameterValues: Binding<[String: String]>) {
        self._parameterValues = parameterValues
    }

    public var body: some View {
        Form {
            // MARK: Files to Compare
            ParameterSectionView(title: "Files to Compare", isRequired: true) {
                FileDropZoneView(
                    parameterID: "file1",
                    label: "File 1",
                    isRequired: true,
                    parameterValues: $parameterValues
                )

                FileDropZoneView(
                    parameterID: "file2",
                    label: "File 2",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Output
            ParameterSectionView(title: "Output") {
                if let formatParam = tool.parameters.first(where: { $0.id == "format" }) {
                    EnumPickerView(
                        parameter: formatParam,
                        parameterValues: $parameterValues
                    )
                }
            }

            // MARK: Comparison Options
            ParameterSectionView(
                title: "Comparison Options",
                help: "Fine-tune the comparison by ignoring specific tags, setting numeric tolerances, or including pixel data analysis."
            ) {
                if let ignoreTagParam = tool.parameters.first(where: { $0.id == "ignore-tag" }) {
                    RepeatableOptionView(
                        parameter: ignoreTagParam,
                        parameterValues: $parameterValues
                    )
                }

                HStack {
                    Text("Tolerance")
                    Spacer()
                    TextField("e.g. 0.001", text: Binding(
                        get: { parameterValues["tolerance"] ?? "" },
                        set: { parameterValues["tolerance"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
                .help("Numeric comparison tolerance for floating-point values")

                Toggle("Ignore Private Tags", isOn: Binding(
                    get: { parameterValues["ignore-private"] == "true" },
                    set: { parameterValues["ignore-private"] = $0 ? "true" : "" }
                ))
                .help("Skip vendor-specific private tags during comparison")

                Toggle("Compare Pixels", isOn: Binding(
                    get: { parameterValues["compare-pixels"] == "true" },
                    set: { parameterValues["compare-pixels"] = $0 ? "true" : "" }
                ))
                .help("Include pixel data in the comparison (may be slow for large images)")

                Toggle("Quick Mode", isOn: Binding(
                    get: { parameterValues["quick"] == "true" },
                    set: { parameterValues["quick"] = $0 ? "true" : "" }
                ))
                .help("Stop comparison at the first difference found")

                Toggle("Show Identical", isOn: Binding(
                    get: { parameterValues["show-identical"] == "true" },
                    set: { parameterValues["show-identical"] = $0 ? "true" : "" }
                ))
                .help("Include matching tags in the output alongside differences")
            }
        }
        .formStyle(.grouped)
    }
}
#endif
