#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-send` tool, providing C-STORE
/// file sending with multi-file support, retry logic, and priority options.
public struct DicomSendView: View {
    @Binding var parameterValues: [String: String]
    let networkConfig: NetworkConfigModel

    private var tool: ToolDefinition { ToolRegistry.dicomSend }

    public init(parameterValues: Binding<[String: String]>, networkConfig: NetworkConfigModel) {
        self._parameterValues = parameterValues
        self.networkConfig = networkConfig
    }

    public var body: some View {
        Form {
            // MARK: Server Connection
            ParameterSectionView(
                title: "Server Connection",
                help: "C-STORE sends DICOM files to a remote PACS server. Network settings are inherited from the PACS Configuration bar.",
                isRequired: true
            ) {
                networkOverrideFields
            }

            // MARK: Files to Send
            ParameterSectionView(
                title: "Files to Send",
                help: "Select one or more DICOM files or a directory to send. When recursive is enabled, all DICOM files in subdirectories will be included.",
                isRequired: true
            ) {
                FileDropZoneView(
                    parameterID: "paths",
                    label: "DICOM Files",
                    isRequired: true,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Send Options
            ParameterSectionView(
                title: "Send Options",
                help: "Configure how files are sent to the PACS server."
            ) {
                Toggle("Recursive", isOn: Binding(
                    get: { parameterValues["recursive"] == "true" },
                    set: { parameterValues["recursive"] = $0 ? "true" : "" }
                ))
                .help("Process directories recursively to find all DICOM files")

                Toggle("Verify First", isOn: Binding(
                    get: { parameterValues["verify"] == "true" },
                    set: { parameterValues["verify"] = $0 ? "true" : "" }
                ))
                .help("Run C-ECHO to verify connectivity before sending files")

                HStack {
                    Text("Retry Count")
                    Spacer()
                    TextField("0", text: Binding(
                        get: { parameterValues["retry"] ?? "" },
                        set: { parameterValues["retry"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                }
                .help("Number of retry attempts on failure (0-10)")

                if let priorityParam = tool.parameters.first(where: { $0.id == "priority" }) {
                    EnumPickerView(
                        parameter: priorityParam,
                        parameterValues: $parameterValues
                    )
                }
            }

            // MARK: Safety Options
            ParameterSectionView(title: "Safety Options") {
                Toggle("Dry Run", isOn: Binding(
                    get: { parameterValues["dry-run"] == "true" },
                    set: { parameterValues["dry-run"] = $0 ? "true" : "" }
                ))
                .foregroundStyle(.orange)
                .help("Preview which files would be sent without actually sending them")

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
