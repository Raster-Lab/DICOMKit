import Foundation

// MARK: - Utility Tools

extension ToolRegistry {

    static let dicomUid = ToolDefinition(
        name: "DICOM UID",
        command: "dicom-uid",
        category: .utilities,
        abstract: "Generate, validate, and look up DICOM UIDs",
        discussion: """
            Manage DICOM Unique Identifiers (UIDs). Generate new UIDs, validate \
            existing ones, look up standard UID definitions, or regenerate UIDs \
            in DICOM files.
            """,
        icon: "number.circle",
        subcommands: [
            SubcommandDefinition(
                name: "generate",
                abstract: "Generate new DICOM UIDs",
                parameters: [
                    ToolParameter(
                        name: "Count",
                        cliFlag: "--count",
                        type: .number,
                        help: "Number of UIDs to generate",
                        defaultValue: "1"
                    ),
                    ToolParameter(
                        name: "Type",
                        cliFlag: "--type",
                        type: .dropdown(options: [
                            DropdownOption(label: "Study", value: "study",
                                           help: "Study Instance UID"),
                            DropdownOption(label: "Series", value: "series",
                                           help: "Series Instance UID"),
                            DropdownOption(label: "Instance", value: "instance",
                                           help: "SOP Instance UID"),
                            DropdownOption(label: "Generic", value: "generic",
                                           help: "Generic UID"),
                        ]),
                        help: "Type of UID to generate",
                        defaultValue: "generic"
                    ),
                    ToolParameter(
                        name: "Root",
                        cliFlag: "--root",
                        type: .text,
                        help: "Custom UID root prefix"
                    ),
                    ToolParameter(
                        name: "JSON Output",
                        cliFlag: "--json",
                        type: .flag,
                        help: "Output as JSON"
                    ),
                ]
            ),
            SubcommandDefinition(
                name: "validate",
                abstract: "Validate a DICOM UID",
                parameters: [
                    ToolParameter(
                        name: "UID",
                        cliFlag: "",
                        type: .positionalArgument,
                        help: "UID to validate",
                        isRequired: true
                    ),
                ]
            ),
            SubcommandDefinition(
                name: "lookup",
                abstract: "Look up a standard UID",
                parameters: [
                    ToolParameter(
                        name: "UID or Name",
                        cliFlag: "",
                        type: .positionalArgument,
                        help: "UID or name to look up",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Search",
                        cliFlag: "--search",
                        type: .text,
                        help: "Search term for UID lookup"
                    ),
                ]
            ),
            SubcommandDefinition(
                name: "regenerate",
                abstract: "Regenerate UIDs in a DICOM file",
                parameters: [
                    ToolParameter(
                        name: "File",
                        cliFlag: "--file",
                        type: .inputFile(allowedTypes: ["dcm", "dicom"]),
                        help: "DICOM file to regenerate UIDs in",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Output",
                        cliFlag: "--output",
                        type: .outputFile(allowedTypes: ["dcm"]),
                        help: "Output file path"
                    ),
                ]
            ),
        ],
        examples: [
            "dicom-uid generate --count 5 --type study",
            "dicom-uid validate 1.2.840.113619.2.5.1762583153.215519.978957063.78",
            "dicom-uid lookup 1.2.840.10008.1.1",
            "dicom-uid regenerate --file scan.dcm --output new-uids.dcm",
        ]
    )
}
