#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-qr` tool, providing a combined
/// query-retrieve interface with workflow mode selection.
public struct DicomQRView: View {
    @Binding var parameterValues: [String: String]
    let networkConfig: NetworkConfigModel

    private var tool: ToolDefinition { ToolRegistry.dicomQR }

    public init(parameterValues: Binding<[String: String]>, networkConfig: NetworkConfigModel) {
        self._parameterValues = parameterValues
        self.networkConfig = networkConfig
    }

    public var body: some View {
        Form {
            // MARK: Server Connection
            ParameterSectionView(
                title: "Server Connection",
                help: "Combined query-retrieve performs a C-FIND followed by C-MOVE/C-GET in a single workflow. Network settings are inherited from the PACS Configuration bar.",
                isRequired: true
            ) {
                networkOverrideFields
            }

            // MARK: Retrieval Options
            ParameterSectionView(
                title: "Retrieval Options",
                help: "Configure the retrieval method and output location."
            ) {
                if let methodParam = tool.parameters.first(where: { $0.id == "method" }) {
                    EnumPickerView(
                        parameter: methodParam,
                        parameterValues: $parameterValues
                    )
                }

                HStack {
                    Text("Move Destination")
                    Spacer()
                    TextField("Destination AET", text: Binding(
                        get: { parameterValues["move-dest"] ?? "" },
                        set: { parameterValues["move-dest"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
                .help("AE Title of the destination for C-MOVE operations")

                OutputPathView(
                    parameterID: "output",
                    label: "Output Directory",
                    isRequired: false,
                    parameterValues: $parameterValues
                )
            }

            // MARK: Workflow Mode
            ParameterSectionView(
                title: "Workflow Mode",
                help: "Interactive mode lets you review query results before retrieving. Auto mode retrieves all matching results automatically."
            ) {
                Toggle("Interactive", isOn: Binding(
                    get: { parameterValues["interactive"] == "true" },
                    set: { parameterValues["interactive"] = $0 ? "true" : "" }
                ))
                .help("Review query results before initiating retrieval")

                Toggle("Auto Retrieve", isOn: Binding(
                    get: { parameterValues["auto"] == "true" },
                    set: { parameterValues["auto"] = $0 ? "true" : "" }
                ))
                .help("Automatically retrieve all matching results without confirmation")
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
