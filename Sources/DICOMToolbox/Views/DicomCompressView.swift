#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-compress` tool, providing a subcommand picker
/// and dynamic parameter forms for compress, decompress, info, and batch operations.
public struct DicomCompressView: View {
    @Binding var parameterValues: [String: String]
    @Binding var subcommand: String?

    private var tool: ToolDefinition { ToolRegistry.dicomCompress }

    public init(parameterValues: Binding<[String: String]>, subcommand: Binding<String?>) {
        self._parameterValues = parameterValues
        self._subcommand = subcommand
    }

    private var currentSubcommand: String {
        subcommand ?? tool.subcommands?.first?.id ?? "compress"
    }

    public var body: some View {
        Form {
            // MARK: Subcommand
            ParameterSectionView(
                title: "Operation",
                help: "Choose the compression operation to perform."
            ) {
                if let subcommands = tool.subcommands {
                    Picker("Operation", selection: Binding(
                        get: { currentSubcommand },
                        set: { newValue in
                            subcommand = newValue
                            parameterValues = [:]
                        }
                    )) {
                        ForEach(subcommands) { sub in
                            Text(sub.name).tag(sub.id)
                        }
                    }
                    .pickerStyle(.segmented)

                    if let selectedSub = tool.subcommands?.first(where: { $0.id == currentSubcommand }) {
                        Text(selectedSub.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: Dynamic Form
            switch currentSubcommand {
            case "compress":
                compressForm
            case "decompress":
                decompressForm
            case "info":
                infoForm
            case "batch":
                batchForm
            default:
                compressForm
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if subcommand == nil {
                subcommand = tool.subcommands?.first?.id
            }
        }
    }

    // MARK: - Compress Subcommand

    @ViewBuilder
    private var compressForm: some View {
        ParameterSectionView(title: "Input", isRequired: true) {
            FileDropZoneView(
                parameterID: "input",
                label: "Input File",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(title: "Output") {
            OutputPathView(
                parameterID: "output",
                label: "Output File",
                isRequired: false,
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(
            title: "Compression Settings",
            help: "Select the codec and quality for compression. Lossy codecs like JPEG reduce file size but discard some image data."
        ) {
            if let sub = tool.subcommands?.first(where: { $0.id == "compress" }),
               let codecParam = sub.parameters.first(where: { $0.id == "codec" }) {
                EnumPickerView(
                    parameter: codecParam,
                    parameterValues: $parameterValues
                )
            }

            HStack {
                Text("Quality")
                Spacer()
                TextField("1-100", text: Binding(
                    get: { parameterValues["quality"] ?? "" },
                    set: { parameterValues["quality"] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 100)
            }
            .help("Compression quality (1-100). Lower values produce smaller files with more data loss.")
        }
    }

    // MARK: - Decompress Subcommand

    @ViewBuilder
    private var decompressForm: some View {
        ParameterSectionView(title: "Input", isRequired: true) {
            FileDropZoneView(
                parameterID: "input",
                label: "Input File",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(title: "Output") {
            OutputPathView(
                parameterID: "output",
                label: "Output File",
                isRequired: false,
                parameterValues: $parameterValues
            )
        }
    }

    // MARK: - Info Subcommand

    @ViewBuilder
    private var infoForm: some View {
        ParameterSectionView(
            title: "Input",
            help: "Select a DICOM file to display its compression details.",
            isRequired: true
        ) {
            FileDropZoneView(
                parameterID: "input",
                label: "Input File",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }
    }

    // MARK: - Batch Subcommand

    @ViewBuilder
    private var batchForm: some View {
        ParameterSectionView(title: "Input", isRequired: true) {
            FileDropZoneView(
                parameterID: "input",
                label: "Input Directory",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(title: "Output") {
            OutputPathView(
                parameterID: "output",
                label: "Output Directory",
                isRequired: false,
                parameterValues: $parameterValues
            )
        }

        ParameterSectionView(
            title: "Batch Settings",
            help: "Configure codec and recursive processing for batch operations."
        ) {
            if let sub = tool.subcommands?.first(where: { $0.id == "batch" }),
               let codecParam = sub.parameters.first(where: { $0.id == "codec" }) {
                EnumPickerView(
                    parameter: codecParam,
                    parameterValues: $parameterValues
                )
            }

            Toggle("Recursive", isOn: Binding(
                get: { parameterValues["recursive"] == "true" },
                set: { parameterValues["recursive"] = $0 ? "true" : "" }
            ))
            .help("Process all DICOM files in subdirectories")
        }
    }
}
#endif
