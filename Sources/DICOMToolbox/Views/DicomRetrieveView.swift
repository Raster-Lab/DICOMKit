#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-retrieve` tool, providing C-MOVE/C-GET
/// retrieval with method-dependent fields and UID-based target selection.
public struct DicomRetrieveView: View {
    @Binding var parameterValues: [String: String]
    let networkConfig: NetworkConfigModel

    private var tool: ToolDefinition { ToolRegistry.dicomRetrieve }

    public init(parameterValues: Binding<[String: String]>, networkConfig: NetworkConfigModel) {
        self._parameterValues = parameterValues
        self.networkConfig = networkConfig
    }

    /// Whether the current method is C-MOVE (requires move destination)
    private var isCMove: Bool {
        (parameterValues["method"] ?? "c-move") == "c-move"
    }

    public var body: some View {
        Form {
            // MARK: Server Connection
            ParameterSectionView(
                title: "Server Connection",
                help: "Configure the PACS server to retrieve files from. Network settings are inherited from the PACS Configuration bar.",
                isRequired: true
            ) {
                networkOverrideFields
            }

            // MARK: Retrieval Target
            ParameterSectionView(
                title: "Retrieval Target",
                help: "Specify the DICOM UIDs identifying the objects to retrieve. At least one UID must be provided.",
                isRequired: true
            ) {
                HStack {
                    Text("Study UID")
                    Spacer()
                    TextField("1.2.840.xxxxx", text: Binding(
                        get: { parameterValues["study-uid"] ?? "" },
                        set: { parameterValues["study-uid"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 350)
                }
                .help("Study Instance UID to retrieve")

                HStack {
                    Text("Series UID")
                    Spacer()
                    TextField("1.2.840.xxxxx", text: Binding(
                        get: { parameterValues["series-uid"] ?? "" },
                        set: { parameterValues["series-uid"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 350)
                }
                .help("Series Instance UID to retrieve (narrows to specific series)")

                HStack {
                    Text("Instance UID")
                    Spacer()
                    TextField("1.2.840.xxxxx", text: Binding(
                        get: { parameterValues["instance-uid"] ?? "" },
                        set: { parameterValues["instance-uid"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 350)
                }
                .help("SOP Instance UID to retrieve (narrows to specific instance)")
            }

            // MARK: Output
            ParameterSectionView(title: "Output", isRequired: true) {
                OutputPathView(
                    parameterID: "output",
                    label: "Output Directory",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Retrieval Method
            ParameterSectionView(
                title: "Retrieval Method",
                help: "C-MOVE instructs the PACS to push files to a specified destination AET. C-GET pulls files directly to this application."
            ) {
                if let methodParam = tool.parameters.first(where: { $0.id == "method" }) {
                    EnumPickerView(
                        parameter: methodParam,
                        parameterValues: $parameterValues
                    )
                }

                if isCMove {
                    HStack {
                        Text("Move Destination")
                            .foregroundStyle(.primary)
                        Text("*").foregroundStyle(.red)
                        Spacer()
                        TextField("Destination AET", text: Binding(
                            get: { parameterValues["move-dest"] ?? "" },
                            set: { parameterValues["move-dest"] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                    }
                    .help("The AE Title of the destination where the PACS should send files (required for C-MOVE)")
                }
            }

            // MARK: Advanced Options
            ParameterSectionView(title: "Advanced Options") {
                HStack {
                    Text("Parallel Operations")
                    Spacer()
                    TextField("1", text: Binding(
                        get: { parameterValues["parallel"] ?? "" },
                        set: { parameterValues["parallel"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                }
                .help("Number of parallel retrieval operations (1-8)")

                Toggle("Verbose", isOn: Binding(
                    get: { parameterValues["verbose"] == "true" },
                    set: { parameterValues["verbose"] = $0 ? "true" : "" }
                ))
                .help("Show detailed protocol-level output")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Network Override Fields

    @ViewBuilder
    private var networkOverrideFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.secondary)
                Text("Network settings inherited from PACS Configuration above")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Server URL").font(.caption).foregroundStyle(.secondary)
                    TextField("pacs://host:port", text: Binding(
                        get: { parameterValues["url"] ?? "" },
                        set: { parameterValues["url"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    if (parameterValues["url"] ?? "").isEmpty {
                        Text("Using: \(networkConfig.serverURL)")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AE Title").font(.caption).foregroundStyle(.secondary)
                    TextField("Override AET", text: Binding(
                        get: { parameterValues["aet"] ?? "" },
                        set: { parameterValues["aet"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    if (parameterValues["aet"] ?? "").isEmpty {
                        Text("Using: \(networkConfig.aeTitle)")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Called AET").font(.caption).foregroundStyle(.secondary)
                    TextField("Override Called AET", text: Binding(
                        get: { parameterValues["called-aet"] ?? "" },
                        set: { parameterValues["called-aet"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    if (parameterValues["called-aet"] ?? "").isEmpty {
                        Text("Using: \(networkConfig.calledAET)")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }
}
#endif
