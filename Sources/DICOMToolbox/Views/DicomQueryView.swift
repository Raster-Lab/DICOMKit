#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-query` tool, providing C-FIND
/// query interface with search criteria, query level, and output format options.
public struct DicomQueryView: View {
    @Binding var parameterValues: [String: String]
    let networkConfig: NetworkConfigModel

    private var tool: ToolDefinition { ToolRegistry.dicomQuery }

    public init(parameterValues: Binding<[String: String]>, networkConfig: NetworkConfigModel) {
        self._parameterValues = parameterValues
        self.networkConfig = networkConfig
    }

    public var body: some View {
        Form {
            // MARK: Server Connection
            ParameterSectionView(
                title: "Server Connection",
                help: "C-FIND queries a remote PACS server for DICOM objects matching the search criteria. Network settings are inherited from the PACS Configuration bar.",
                isRequired: true
            ) {
                networkOverrideFields
            }

            // MARK: Query Level
            ParameterSectionView(
                title: "Query Level",
                help: "The query level determines what type of DICOM objects to search for. Patient-level returns patient demographics, Study-level returns studies, Series-level returns series within a study, and Instance-level returns individual images."
            ) {
                if let levelParam = tool.parameters.first(where: { $0.id == "level" }) {
                    EnumPickerView(
                        parameter: levelParam,
                        parameterValues: $parameterValues
                    )
                }
            }

            // MARK: Search Criteria
            ParameterSectionView(
                title: "Search Criteria",
                help: "Specify search filters. Wildcards (* and ?) are supported in text fields. Leave fields empty to match all values."
            ) {
                HStack {
                    Text("Patient Name")
                    Spacer()
                    TextField("e.g., SMITH* or *JOHN*", text: Binding(
                        get: { parameterValues["patient-name"] ?? "" },
                        set: { parameterValues["patient-name"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 250)
                }
                .help("Patient name filter (DICOM wildcards supported: * matches any, ? matches single character)")

                HStack {
                    Text("Patient ID")
                    Spacer()
                    TextField("Patient ID", text: Binding(
                        get: { parameterValues["patient-id"] ?? "" },
                        set: { parameterValues["patient-id"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 250)
                }
                .help("Filter by patient ID")

                HStack {
                    Text("Study Date")
                    Spacer()
                    TextField("YYYYMMDD or YYYYMMDD-YYYYMMDD", text: Binding(
                        get: { parameterValues["study-date"] ?? "" },
                        set: { parameterValues["study-date"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 250)
                }
                .help("Filter by study date. Use YYYYMMDD format or YYYYMMDD-YYYYMMDD for date ranges.")

                if let modalityParam = tool.parameters.first(where: { $0.id == "modality" }) {
                    EnumPickerView(
                        parameter: modalityParam,
                        parameterValues: $parameterValues
                    )
                }
            }

            // MARK: Output Options
            ParameterSectionView(title: "Output Options") {
                if let formatParam = tool.parameters.first(where: { $0.id == "format" }) {
                    EnumPickerView(
                        parameter: formatParam,
                        parameterValues: $parameterValues
                    )
                }

                Toggle("Verbose", isOn: Binding(
                    get: { parameterValues["verbose"] == "true" },
                    set: { parameterValues["verbose"] = $0 ? "true" : "" }
                ))
                .help("Show detailed protocol-level output including association negotiation")
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
