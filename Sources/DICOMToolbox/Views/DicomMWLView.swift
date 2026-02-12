#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-mwl` tool, providing Modality
/// Worklist query interface with date, station, patient, and modality filters.
public struct DicomMWLView: View {
    @Binding var parameterValues: [String: String]
    let networkConfig: NetworkConfigModel

    private var tool: ToolDefinition { ToolRegistry.dicomMWL }

    public init(parameterValues: Binding<[String: String]>, networkConfig: NetworkConfigModel) {
        self._parameterValues = parameterValues
        self.networkConfig = networkConfig
    }

    public var body: some View {
        Form {
            // MARK: Server Connection
            ParameterSectionView(
                title: "Server Connection",
                help: "Modality Worklist (MWL) queries a PACS or RIS for scheduled procedures. Network settings are inherited from the PACS Configuration bar.",
                isRequired: true
            ) {
                networkOverrideFields
            }

            // MARK: Query Filters
            ParameterSectionView(
                title: "Query Filters",
                help: "Filter worklist items by date, station, patient, or modality. Leave empty to match all."
            ) {
                HStack {
                    Text("Scheduled Date")
                    Spacer()
                    TextField("YYYYMMDD", text: Binding(
                        get: { parameterValues["date"] ?? "" },
                        set: { parameterValues["date"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
                .help("Filter by scheduled procedure date (YYYYMMDD format)")

                HStack {
                    Text("Station")
                    Spacer()
                    TextField("Station name", text: Binding(
                        get: { parameterValues["station"] ?? "" },
                        set: { parameterValues["station"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
                .help("Filter by scheduled station name")

                HStack {
                    Text("Patient")
                    Spacer()
                    TextField("Patient name", text: Binding(
                        get: { parameterValues["patient"] ?? "" },
                        set: { parameterValues["patient"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
                .help("Filter by patient name (wildcards supported)")

                HStack {
                    Text("Modality")
                    Spacer()
                    TextField("e.g., CT, MR, US", text: Binding(
                        get: { parameterValues["modality"] ?? "" },
                        set: { parameterValues["modality"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                }
                .help("Filter by modality type (CT, MR, US, etc.)")
            }

            // MARK: Output Options
            ParameterSectionView(title: "Output Options") {
                Toggle("JSON Output", isOn: Binding(
                    get: { parameterValues["json"] == "true" },
                    set: { parameterValues["json"] = $0 ? "true" : "" }
                ))
                .help("Output results in JSON format instead of table format")
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
