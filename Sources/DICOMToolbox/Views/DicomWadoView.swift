#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-wado` tool, providing DICOMweb
/// access (WADO-RS, STOW-RS, QIDO-RS) with subcommand-based dynamic forms.
public struct DicomWadoView: View {
    @Binding var parameterValues: [String: String]
    @Binding var subcommand: String?
    let networkConfig: NetworkConfigModel

    private var tool: ToolDefinition { ToolRegistry.dicomWado }

    public init(parameterValues: Binding<[String: String]>, subcommand: Binding<String?>, networkConfig: NetworkConfigModel) {
        self._parameterValues = parameterValues
        self._subcommand = subcommand
        self.networkConfig = networkConfig
    }

    private var currentSubcommand: String {
        subcommand ?? tool.subcommands?.first?.id ?? "retrieve"
    }

    public var body: some View {
        Form {
            // MARK: Server Connection
            ParameterSectionView(
                title: "DICOMweb Server",
                help: "WADO-RS, STOW-RS, and QIDO-RS operations use HTTP/HTTPS for DICOMweb access. Provide the base URL of the DICOMweb service.",
                isRequired: true
            ) {
                HStack {
                    Text("Base URL")
                        .foregroundStyle(.primary)
                    Text("*").foregroundStyle(.red)
                    Spacer()
                    TextField("https://server/dicom-web", text: Binding(
                        get: { parameterValues["base-url"] ?? "" },
                        set: { parameterValues["base-url"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 350)
                }
                .help("Base URL of the DICOMweb service (e.g., https://pacs.hospital.org/dicom-web)")

                HStack {
                    Text("OAuth2 Token")
                    Spacer()
                    SecureField("Bearer token", text: Binding(
                        get: { parameterValues["token"] ?? "" },
                        set: { parameterValues["token"] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                }
                .help("OAuth2 bearer token for authentication (optional)")
            }

            // MARK: Operation
            ParameterSectionView(
                title: "Operation",
                help: "Select the DICOMweb operation to perform."
            ) {
                if let subcommands = tool.subcommands {
                    Picker("Operation", selection: Binding(
                        get: { currentSubcommand },
                        set: { newValue in
                            subcommand = newValue
                            // Clear non-connection params on subcommand change
                            let connectionKeys: Set<String> = ["base-url", "token"]
                            let keysToRemove = parameterValues.keys.filter { !connectionKeys.contains($0) }
                            for key in keysToRemove {
                                parameterValues.removeValue(forKey: key)
                            }
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
            case "retrieve":
                retrieveForm
            case "store":
                storeForm
            case "query":
                queryForm
            default:
                retrieveForm
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if subcommand == nil {
                subcommand = tool.subcommands?.first?.id
            }
        }
    }

    // MARK: - Retrieve Subcommand

    @ViewBuilder
    private var retrieveForm: some View {
        ParameterSectionView(
            title: "Retrieval Target",
            help: "Specify the UIDs of the DICOM objects to retrieve via WADO-RS.",
            isRequired: true
        ) {
            HStack {
                Text("Study UID")
                    .foregroundStyle(.primary)
                Text("*").foregroundStyle(.red)
                Spacer()
                TextField("1.2.840.xxxxx", text: Binding(
                    get: { parameterValues["study"] ?? "" },
                    set: { parameterValues["study"] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 350)
            }
            .help("Study Instance UID (required for WADO-RS retrieve)")

            HStack {
                Text("Series UID")
                Spacer()
                TextField("1.2.840.xxxxx", text: Binding(
                    get: { parameterValues["series"] ?? "" },
                    set: { parameterValues["series"] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 350)
            }

            HStack {
                Text("Instance UID")
                Spacer()
                TextField("1.2.840.xxxxx", text: Binding(
                    get: { parameterValues["instance"] ?? "" },
                    set: { parameterValues["instance"] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 350)
            }
        }

        ParameterSectionView(title: "Output") {
            OutputPathView(
                parameterID: "output",
                label: "Output Directory",
                isRequired: false,
                parameterValues: $parameterValues
            )

            Toggle("Metadata Only", isOn: Binding(
                get: { parameterValues["metadata"] == "true" },
                set: { parameterValues["metadata"] = $0 ? "true" : "" }
            ))
            .help("Retrieve only DICOM metadata without pixel data")
        }
    }

    // MARK: - Store Subcommand

    @ViewBuilder
    private var storeForm: some View {
        ParameterSectionView(title: "Files to Store", isRequired: true) {
            FileDropZoneView(
                parameterID: "input",
                label: "Input Files",
                isRequired: true,
                parameterValues: $parameterValues
            )
        }
    }

    // MARK: - Query Subcommand

    @ViewBuilder
    private var queryForm: some View {
        ParameterSectionView(
            title: "Query Options",
            help: "QIDO-RS queries the DICOMweb service for DICOM objects."
        ) {
            if let sub = tool.subcommands?.first(where: { $0.id == "query" }),
               let levelParam = sub.parameters.first(where: { $0.id == "level" }) {
                EnumPickerView(
                    parameter: levelParam,
                    parameterValues: $parameterValues
                )
            }
        }
    }
}
#endif
