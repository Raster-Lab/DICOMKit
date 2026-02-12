import Foundation

// MARK: - DICOMweb Tools

extension ToolRegistry {

    static let dicomWado = ToolDefinition(
        name: "DICOM WADO",
        command: "dicom-wado",
        category: .dicomweb,
        abstract: "DICOMweb operations (QIDO-RS, WADO-RS, STOW-RS)",
        discussion: """
            Performs DICOMweb RESTful operations including study search (QIDO-RS), \
            study retrieval (WADO-RS), and study storage (STOW-RS).
            """,
        icon: "globe",
        subcommands: [
            SubcommandDefinition(
                name: "query",
                abstract: "Search for studies using QIDO-RS",
                parameters: [
                    ToolParameter(
                        name: "Base URL",
                        cliFlag: "",
                        type: .positionalArgument,
                        help: "DICOMweb server base URL (https://server/dicomweb)",
                        isRequired: true,
                        isPACSParameter: true
                    ),
                    ToolParameter(
                        name: "Patient Name",
                        cliFlag: "--patient-name",
                        type: .text,
                        help: "Filter by patient name"
                    ),
                    ToolParameter(
                        name: "Patient ID",
                        cliFlag: "--patient-id",
                        type: .text,
                        help: "Filter by patient ID"
                    ),
                    ToolParameter(
                        name: "Study Date",
                        cliFlag: "--study-date",
                        type: .text,
                        help: "Filter by study date"
                    ),
                    ToolParameter(
                        name: "Modality",
                        cliFlag: "--modality",
                        type: .text,
                        help: "Filter by modality"
                    ),
                    ToolParameter(
                        name: "Limit",
                        cliFlag: "--limit",
                        type: .number,
                        help: "Maximum number of results"
                    ),
                    ToolParameter(
                        name: "Verbose",
                        cliFlag: "--verbose",
                        type: .flag,
                        help: "Show verbose output"
                    ),
                ]
            ),
            SubcommandDefinition(
                name: "retrieve",
                abstract: "Retrieve studies/series/instances using WADO-RS",
                parameters: [
                    ToolParameter(
                        name: "Base URL",
                        cliFlag: "",
                        type: .positionalArgument,
                        help: "DICOMweb server base URL",
                        isRequired: true,
                        isPACSParameter: true
                    ),
                    ToolParameter(
                        name: "Study UID",
                        cliFlag: "--study-uid",
                        type: .text,
                        help: "Study Instance UID to retrieve",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Series UID",
                        cliFlag: "--series-uid",
                        type: .text,
                        help: "Series Instance UID (optional)"
                    ),
                    ToolParameter(
                        name: "Output Directory",
                        cliFlag: "--output",
                        type: .outputDirectory,
                        help: "Directory to save retrieved files"
                    ),
                    ToolParameter(
                        name: "Verbose",
                        cliFlag: "--verbose",
                        type: .flag,
                        help: "Show verbose output"
                    ),
                ]
            ),
            SubcommandDefinition(
                name: "store",
                abstract: "Store DICOM files using STOW-RS",
                parameters: [
                    ToolParameter(
                        name: "Base URL",
                        cliFlag: "",
                        type: .positionalArgument,
                        help: "DICOMweb server base URL",
                        isRequired: true,
                        isPACSParameter: true
                    ),
                    ToolParameter(
                        name: "Files",
                        cliFlag: " ",
                        type: .positionalFiles(allowedTypes: ["dcm", "dicom"]),
                        help: "DICOM files to store",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Verbose",
                        cliFlag: "--verbose",
                        type: .flag,
                        help: "Show verbose output"
                    ),
                ]
            ),
        ],
        examples: [
            "dicom-wado query https://server/dicomweb --patient-name DOE*",
            "dicom-wado retrieve https://server/dicomweb --study-uid 1.2.3",
            "dicom-wado store https://server/dicomweb scan.dcm",
        ]
    )

    static let dicomJson = ToolDefinition(
        name: "DICOM JSON",
        command: "dicom-json",
        category: .dicomweb,
        abstract: "Convert DICOM to/from JSON format",
        discussion: """
            Converts DICOM files to the DICOM JSON Model (PS3.18 Annex F) \
            or converts DICOM JSON back to DICOM Part 10 files.
            """,
        icon: "curlybraces",
        parameters: [
            ToolParameter(
                name: "Input",
                cliFlag: "",
                type: .positionalFile(allowedTypes: ["dcm", "dicom", "json"]),
                help: "Input DICOM or JSON file",
                isRequired: true
            ),
            ToolParameter(
                name: "Output",
                cliFlag: "--output",
                type: .outputFile(allowedTypes: ["json", "dcm"]),
                help: "Output file path"
            ),
            ToolParameter(
                name: "Reverse",
                cliFlag: "--reverse",
                type: .flag,
                help: "Convert JSON to DICOM (reverse operation)"
            ),
            ToolParameter(
                name: "Pretty Print",
                cliFlag: "--pretty",
                type: .flag,
                help: "Pretty-print JSON output with indentation"
            ),
            ToolParameter(
                name: "Inline Threshold",
                cliFlag: "--inline-threshold",
                type: .number,
                help: "Maximum size for inline binary data (bytes)",
                discussion: "Binary data larger than this threshold will use bulk data URIs"
            ),
            ToolParameter(
                name: "Bulk Data URL",
                cliFlag: "--bulk-data-url",
                type: .text,
                help: "Base URL for bulk data references"
            ),
            ToolParameter(
                name: "Metadata Only",
                cliFlag: "--metadata-only",
                type: .flag,
                help: "Export metadata only (exclude pixel data)"
            ),
            ToolParameter(
                name: "Stream Mode",
                cliFlag: "--stream",
                type: .flag,
                help: "Use streaming mode for large files"
            ),
            ToolParameter(
                name: "Verbose",
                cliFlag: "--verbose",
                type: .flag,
                help: "Show verbose output"
            ),
        ],
        examples: [
            "dicom-json scan.dcm --output metadata.json --pretty",
            "dicom-json metadata.json --reverse --output restored.dcm",
            "dicom-json scan.dcm --metadata-only --pretty",
        ]
    )

    static let dicomXml = ToolDefinition(
        name: "DICOM XML",
        command: "dicom-xml",
        category: .dicomweb,
        abstract: "Convert DICOM to/from XML format",
        discussion: """
            Converts DICOM files to the DICOM XML (PS3.19) representation \
            or converts DICOM XML back to DICOM Part 10 files.
            """,
        icon: "chevron.left.forwardslash.chevron.right",
        parameters: [
            ToolParameter(
                name: "Input",
                cliFlag: "",
                type: .positionalFile(allowedTypes: ["dcm", "dicom", "xml"]),
                help: "Input DICOM or XML file",
                isRequired: true
            ),
            ToolParameter(
                name: "Output",
                cliFlag: "--output",
                type: .outputFile(allowedTypes: ["xml", "dcm"]),
                help: "Output file path"
            ),
            ToolParameter(
                name: "Reverse",
                cliFlag: "--reverse",
                type: .flag,
                help: "Convert XML to DICOM (reverse operation)"
            ),
            ToolParameter(
                name: "Pretty Print",
                cliFlag: "--pretty",
                type: .flag,
                help: "Pretty-print XML output with indentation"
            ),
            ToolParameter(
                name: "Inline Threshold",
                cliFlag: "--inline-threshold",
                type: .number,
                help: "Maximum size for inline binary data (bytes)"
            ),
            ToolParameter(
                name: "Metadata Only",
                cliFlag: "--metadata-only",
                type: .flag,
                help: "Export metadata only (exclude pixel data)"
            ),
            ToolParameter(
                name: "Verbose",
                cliFlag: "--verbose",
                type: .flag,
                help: "Show verbose output"
            ),
        ],
        examples: [
            "dicom-xml scan.dcm --output metadata.xml --pretty",
            "dicom-xml metadata.xml --reverse --output restored.dcm",
        ]
    )
}
