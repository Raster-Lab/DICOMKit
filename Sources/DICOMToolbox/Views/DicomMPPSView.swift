#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-mpps` tool, providing Modality Performed
/// Procedure Step operations with subcommand-based forms for create and update.
public struct DicomMPPSView: View {
    @Binding var parameterValues: [String: String]
    @Binding var subcommand: String?
    let networkConfig: NetworkConfigModel

    private var tool: ToolDefinition { ToolRegistry.dicomMPPS }

    public init(parameterValues: Binding<[String: String]>, subcommand: Binding<String?>, networkConfig: NetworkConfigModel) {
        self._parameterValues = parameterValues
        self._subcommand = subcommand
        self.networkConfig = networkConfig
    }

    private var currentSubcommand: String {
        subcommand ?? tool.subcommands?.first?.id ?? "create"
    }

    public var body: some View {
        Form {
            // MARK: Server Connection
            ParameterSectionView(
                title: "Server Connection",
                help: "MPPS (Modality Performed Procedure Step) reports procedure progress to a PACS/RIS. Network settings are inherited from the PACS Configuration bar.",
                isRequired: true
            ) {
                networkOverrideFields
            }

            // MARK: Operation
            ParameterSectionView(
                title: "Operation",
                help: "Create starts a new procedure step. Update changes the status of an existing step (e.g., marking it as completed)."
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
            case "create":
                createForm
            case "update":
                updateForm
            default:
                createForm
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if subcommand == nil {
                subcommand = tool.subcommands?.first?.id
            }
        }
    }

    // MARK: - Create Subcommand

    @ViewBuilder
    private var createForm: some View {
        ParameterSectionView(title: "Procedure Details", isRequired: true) {
            HStack {
                Text("Study UID")
                    .foregroundStyle(.primary)
                Text("*").foregroundStyle(.red)
                Spacer()
                TextField("1.2.840.xxxxx", text: Binding(
                    get: { parameterValues["study-uid"] ?? "" },
                    set: { parameterValues["study-uid"] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 350)
            }
            .help("Study Instance UID for the procedure being performed")

            if let sub = tool.subcommands?.first(where: { $0.id == "create" }),
               let statusParam = sub.parameters.first(where: { $0.id == "status" }) {
                EnumPickerView(
                    parameter: statusParam,
                    parameterValues: $parameterValues
                )
            }
        }
    }

    // MARK: - Update Subcommand

    @ViewBuilder
    private var updateForm: some View {
        ParameterSectionView(title: "Procedure Details", isRequired: true) {
            HStack {
                Text("Study UID")
                    .foregroundStyle(.primary)
                Text("*").foregroundStyle(.red)
                Spacer()
                TextField("1.2.840.xxxxx", text: Binding(
                    get: { parameterValues["study-uid"] ?? "" },
                    set: { parameterValues["study-uid"] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 350)
            }
            .help("Study Instance UID of the procedure to update")

            if let sub = tool.subcommands?.first(where: { $0.id == "update" }),
               let statusParam = sub.parameters.first(where: { $0.id == "status" }) {
                EnumPickerView(
                    parameter: statusParam,
                    parameterValues: $parameterValues
                )
            }
        }
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
