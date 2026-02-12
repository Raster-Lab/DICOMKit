#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-echo` tool, providing C-ECHO
/// connectivity testing with network configuration integration.
public struct DicomEchoView: View {
    @Binding var parameterValues: [String: String]
    let networkConfig: NetworkConfigModel

    private var tool: ToolDefinition { ToolRegistry.dicomEcho }

    public init(parameterValues: Binding<[String: String]>, networkConfig: NetworkConfigModel) {
        self._parameterValues = parameterValues
        self.networkConfig = networkConfig
    }

    public var body: some View {
        Form {
            // MARK: Server Connection
            ParameterSectionView(
                title: "Server Connection",
                help: "C-ECHO verifies basic DICOM connectivity by sending an association request to the remote PACS server. It is the DICOM equivalent of a network 'ping'.",
                isRequired: true
            ) {
                networkOverrideFields
            }

            // MARK: Echo Options
            ParameterSectionView(
                title: "Echo Options",
                help: "Configure how many echo requests to send and what diagnostics to perform."
            ) {
                HStack {
                    Text("Count")
                    Spacer()
                    TextField("1", text: Binding(
                        get: { parameterValues["count"] ?? "" },
                        set: { parameterValues["count"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                }
                .help("Number of C-ECHO requests to send (1-100)")

                Toggle("Show Statistics", isOn: Binding(
                    get: { parameterValues["stats"] == "true" },
                    set: { parameterValues["stats"] = $0 ? "true" : "" }
                ))
                .help("Display round-trip timing statistics for each echo request")

                Toggle("Run Diagnostics", isOn: Binding(
                    get: { parameterValues["diagnose"] == "true" },
                    set: { parameterValues["diagnose"] = $0 ? "true" : "" }
                ))
                .help("Run comprehensive connection diagnostics including supported transfer syntaxes and presentation contexts")

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

                VStack(alignment: .leading, spacing: 2) {
                    Text("Timeout").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        TextField("Override", text: Binding(
                            get: { parameterValues["timeout"] ?? "" },
                            set: { parameterValues["timeout"] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        Text("s").foregroundStyle(.secondary)
                    }
                    if (parameterValues["timeout"] ?? "").isEmpty {
                        Text("Using: \(networkConfig.timeout)s")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }
}
#endif
