#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-dump` tool, providing hex-level
/// inspection controls including offset, length, and display formatting options.
public struct DicomDumpView: View {
    @Binding var parameterValues: [String: String]

    private var tool: ToolDefinition { ToolRegistry.dicomDump }

    public init(parameterValues: Binding<[String: String]>) {
        self._parameterValues = parameterValues
    }

    public var body: some View {
        Form {
            // MARK: Input
            ParameterSectionView(title: "Input", isRequired: true) {
                FileDropZoneView(
                    parameterID: "filePath",
                    label: "Input File",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Filter
            ParameterSectionView(
                title: "Filter",
                help: "Narrow the hex dump to a specific tag, byte offset, or length range."
            ) {
                HStack {
                    Text("Filter Tag")
                    Spacer()
                    TextField("e.g. 0010,0010", text: Binding(
                        get: { parameterValues["tag"] ?? "" },
                        set: { parameterValues["tag"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
                .help("Show only the hex data for a specific DICOM tag")

                HStack {
                    Text("Offset")
                    Spacer()
                    TextField("0x0000", text: Binding(
                        get: { parameterValues["offset"] ?? "" },
                        set: { parameterValues["offset"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
                .help("Start offset in hexadecimal format")

                HStack {
                    Text("Length")
                    Spacer()
                    TextField("bytes", text: Binding(
                        get: { parameterValues["length"] ?? "" },
                        set: { parameterValues["length"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
                .help("Number of bytes to display")
            }

            // MARK: Display
            ParameterSectionView(title: "Display") {
                HStack {
                    Text("Bytes Per Line")
                    Spacer()
                    Picker("Bytes Per Line", selection: Binding(
                        get: { parameterValues["bytes-per-line"] ?? "16" },
                        set: { parameterValues["bytes-per-line"] = $0 }
                    )) {
                        Text("8").tag("8")
                        Text("16").tag("16")
                        Text("32").tag("32")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                    .labelsHidden()
                }

                Toggle("Annotate", isOn: Binding(
                    get: { parameterValues["annotate"] == "true" },
                    set: { parameterValues["annotate"] = $0 ? "true" : "" }
                ))
                .help("Add human-readable annotations to hex output")

                Toggle("No Color", isOn: Binding(
                    get: { parameterValues["no-color"] == "true" },
                    set: { parameterValues["no-color"] = $0 ? "true" : "" }
                ))
                .help("Disable ANSI color codes in output")
            }

            // MARK: Options
            ParameterSectionView(title: "Options") {
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
