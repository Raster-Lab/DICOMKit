#if canImport(SwiftUI) && os(macOS)
import SwiftUI

/// Dedicated parameter form for the `dicom-uid` tool, providing subcommand-based
/// forms for UID generation, validation, lookup, and regeneration.
public struct DicomUIDView: View {
    @Binding var parameterValues: [String: String]
    @Binding var subcommand: String?

    private var tool: ToolDefinition { ToolRegistry.dicomUID }

    public init(parameterValues: Binding<[String: String]>, subcommand: Binding<String?>) {
        self._parameterValues = parameterValues
        self._subcommand = subcommand
    }

    private var currentSubcommand: String {
        subcommand ?? tool.subcommands?.first?.id ?? "generate"
    }

    public var body: some View {
        Form {
            // MARK: Subcommand
            ParameterSectionView(
                title: "Operation",
                help: "Generate creates new UIDs, Validate checks UID format, Lookup finds well-known UID definitions, and Regenerate replaces UIDs in DICOM files."
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
            case "generate":
                generateForm
            case "validate":
                validateForm
            case "lookup":
                lookupForm
            case "regenerate":
                regenerateForm
            default:
                generateForm
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if subcommand == nil {
                subcommand = tool.subcommands?.first?.id
            }
        }
    }

    // MARK: - Generate Subcommand

    @ViewBuilder
    private var generateForm: some View {
        ParameterSectionView(
            title: "Generation Settings",
            help: "Configure UID generation parameters. DICOM UIDs follow the format defined in PS3.5 Section 9."
        ) {
            HStack {
                Text("Count")
                Spacer()
                TextField("1", text: Binding(
                    get: { parameterValues["count"] ?? "" },
                    set: { parameterValues["count"] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 100)
            }
            .help("Number of UIDs to generate (default: 1)")

            HStack {
                Text("Type")
                Spacer()
                TextField("UID type", text: Binding(
                    get: { parameterValues["type"] ?? "" },
                    set: { parameterValues["type"] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
            }
            .help("UID type (e.g., Study, Series, Instance)")

            HStack {
                Text("Root OID")
                Spacer()
                TextField("1.2.840.xxxxx", text: Binding(
                    get: { parameterValues["root"] ?? "" },
                    set: { parameterValues["root"] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 250)
            }
            .help("Organization root OID for generated UIDs")

            Toggle("JSON Output", isOn: Binding(
                get: { parameterValues["json"] == "true" },
                set: { parameterValues["json"] = $0 ? "true" : "" }
            ))
            .help("Output generated UIDs in JSON format")
        }
    }

    // MARK: - Validate Subcommand

    @ViewBuilder
    private var validateForm: some View {
        ParameterSectionView(
            title: "UID to Validate",
            help: "Enter a DICOM UID to check its format and structure. Valid UIDs contain only digits and periods, with each component ≤ 39 characters.",
            isRequired: true
        ) {
            HStack {
                Text("UID")
                    .foregroundStyle(.primary)
                Text("*").foregroundStyle(.red)
                Spacer()
                TextField("1.2.840.10008.1.2", text: Binding(
                    get: { parameterValues["uid"] ?? "" },
                    set: { parameterValues["uid"] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 350)
            }
            .help("DICOM UID to validate")
        }
    }

    // MARK: - Lookup Subcommand

    @ViewBuilder
    private var lookupForm: some View {
        ParameterSectionView(
            title: "UID to Look Up",
            help: "Enter a well-known DICOM UID to find its name and description in the DICOM registry (e.g., Transfer Syntax, SOP Class UIDs).",
            isRequired: true
        ) {
            HStack {
                Text("UID")
                    .foregroundStyle(.primary)
                Text("*").foregroundStyle(.red)
                Spacer()
                TextField("1.2.840.10008.1.2", text: Binding(
                    get: { parameterValues["uid"] ?? "" },
                    set: { parameterValues["uid"] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 350)
            }
            .help("DICOM UID to look up in the registry")
        }
    }

    // MARK: - Regenerate Subcommand

    @ViewBuilder
    private var regenerateForm: some View {
        ParameterSectionView(
            title: "Input",
            help: "Select a DICOM file whose UIDs will be regenerated.",
            isRequired: true
        ) {
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
            title: "Regeneration Settings",
            help: "Configure root OID and output options for UID regeneration."
        ) {
            HStack {
                Text("Root OID")
                Spacer()
                TextField("1.2.840.xxxxx", text: Binding(
                    get: { parameterValues["root"] ?? "" },
                    set: { parameterValues["root"] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 250)
            }
            .help("Organization root OID for regenerated UIDs")

            Toggle("JSON Output", isOn: Binding(
                get: { parameterValues["json"] == "true" },
                set: { parameterValues["json"] = $0 ? "true" : "" }
            ))
            .help("Output UID mapping in JSON format")
        }
    }
}
#endif
