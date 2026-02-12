import Foundation

// MARK: - Networking Tools

extension ToolRegistry {

    static let dicomEcho = ToolDefinition(
        name: "DICOM Echo",
        command: "dicom-echo",
        category: .networking,
        abstract: "Test DICOM connectivity using C-ECHO",
        discussion: """
            Performs DICOM C-ECHO verification to test connectivity with PACS servers. \
            This is the simplest DICOM network operation and is useful for testing \
            connectivity, network configuration, and server availability.
            """,
        icon: "wave.3.right",
        parameters: [
            ToolParameter(
                name: "Server URL",
                cliFlag: "",
                type: .positionalArgument,
                help: "PACS server URL (pacs://host:port)",
                discussion: "Auto-filled from PACS configuration above",
                isRequired: true,
                isPACSParameter: true
            ),
            ToolParameter(
                name: "AE Title",
                cliFlag: "--aet",
                type: .text,
                help: "Local Application Entity Title (calling AE)",
                isRequired: true,
                isPACSParameter: true
            ),
            ToolParameter(
                name: "Called AE Title",
                cliFlag: "--called-aet",
                type: .text,
                help: "Remote Application Entity Title",
                defaultValue: "ANY-SCP",
                isPACSParameter: true
            ),
            ToolParameter(
                name: "Count",
                cliFlag: "--count",
                type: .number,
                help: "Number of echo requests to send",
                defaultValue: "1"
            ),
            ToolParameter(
                name: "Timeout",
                cliFlag: "--timeout",
                type: .number,
                help: "Connection timeout in seconds",
                defaultValue: "30"
            ),
            ToolParameter(
                name: "Show Statistics",
                cliFlag: "--stats",
                type: .flag,
                help: "Show round-trip time statistics (min/avg/max)"
            ),
            ToolParameter(
                name: "Run Diagnostics",
                cliFlag: "--diagnose",
                type: .flag,
                help: "Run comprehensive network diagnostics",
                discussion: "Performs multiple connectivity tests including stability checks"
            ),
            ToolParameter(
                name: "Verbose",
                cliFlag: "--verbose",
                type: .flag,
                help: "Show detailed connection information"
            ),
        ],
        examples: [
            "dicom-echo pacs://server:11112 --aet TEST_SCU",
            "dicom-echo pacs://server:11112 --aet TEST_SCU --count 10 --stats",
            "dicom-echo pacs://server:11112 --aet TEST_SCU --diagnose",
        ]
    )

    static let dicomQuery = ToolDefinition(
        name: "DICOM Query",
        command: "dicom-query",
        category: .networking,
        abstract: "Query PACS servers using C-FIND",
        discussion: """
            Searches for studies, series, or instances on PACS servers using the \
            DICOM C-FIND service. Supports patient, study, series, and instance level queries.
            """,
        icon: "magnifyingglass",
        parameters: [
            ToolParameter(
                name: "Server URL",
                cliFlag: "",
                type: .positionalArgument,
                help: "PACS server URL (pacs://host:port)",
                isRequired: true,
                isPACSParameter: true
            ),
            ToolParameter(
                name: "AE Title",
                cliFlag: "--aet",
                type: .text,
                help: "Local Application Entity Title",
                isRequired: true,
                isPACSParameter: true
            ),
            ToolParameter(
                name: "Called AE Title",
                cliFlag: "--called-aet",
                type: .text,
                help: "Remote Application Entity Title",
                defaultValue: "ANY-SCP",
                isPACSParameter: true
            ),
            ToolParameter(
                name: "Query Level",
                cliFlag: "--level",
                type: .dropdown(options: [
                    DropdownOption(label: "Patient", value: "patient", help: "Query at patient level"),
                    DropdownOption(label: "Study", value: "study", help: "Query at study level"),
                    DropdownOption(label: "Series", value: "series", help: "Query at series level"),
                    DropdownOption(label: "Instance", value: "instance", help: "Query at instance level"),
                ]),
                help: "Query retrieve level",
                defaultValue: "study"
            ),
            ToolParameter(
                name: "Patient Name",
                cliFlag: "--patient-name",
                type: .text,
                help: "Filter by patient name (supports wildcards: DOE*)"
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
                help: "Filter by study date (YYYYMMDD or range YYYYMMDD-YYYYMMDD)",
                discussion: "Supports single dates and date ranges using hyphen separator"
            ),
            ToolParameter(
                name: "Study UID",
                cliFlag: "--study-uid",
                type: .text,
                help: "Filter by Study Instance UID"
            ),
            ToolParameter(
                name: "Accession Number",
                cliFlag: "--accession-number",
                type: .text,
                help: "Filter by accession number"
            ),
            ToolParameter(
                name: "Modality",
                cliFlag: "--modality",
                type: .dropdown(options: [
                    DropdownOption(label: "Any", value: "", help: "All modalities"),
                    DropdownOption(label: "CT", value: "CT", help: "Computed Tomography"),
                    DropdownOption(label: "MR", value: "MR", help: "Magnetic Resonance"),
                    DropdownOption(label: "CR", value: "CR", help: "Computed Radiography"),
                    DropdownOption(label: "DX", value: "DX", help: "Digital X-Ray"),
                    DropdownOption(label: "US", value: "US", help: "Ultrasound"),
                    DropdownOption(label: "NM", value: "NM", help: "Nuclear Medicine"),
                    DropdownOption(label: "PT", value: "PT", help: "PET"),
                    DropdownOption(label: "XA", value: "XA", help: "Angiography"),
                    DropdownOption(label: "MG", value: "MG", help: "Mammography"),
                ]),
                help: "Filter by imaging modality"
            ),
            ToolParameter(
                name: "Study Description",
                cliFlag: "--study-description",
                type: .text,
                help: "Filter by study description"
            ),
            ToolParameter(
                name: "Output Format",
                cliFlag: "--format",
                type: .dropdown(options: [
                    DropdownOption(label: "Text", value: "text", help: "Tabular text"),
                    DropdownOption(label: "JSON", value: "json", help: "JSON format"),
                    DropdownOption(label: "CSV", value: "csv", help: "CSV format"),
                ]),
                help: "Output format for query results",
                defaultValue: "text"
            ),
            ToolParameter(
                name: "Timeout",
                cliFlag: "--timeout",
                type: .number,
                help: "Connection timeout in seconds",
                defaultValue: "30"
            ),
            ToolParameter(
                name: "Verbose",
                cliFlag: "--verbose",
                type: .flag,
                help: "Show verbose output"
            ),
        ],
        examples: [
            "dicom-query pacs://server:11112 --aet SCU --patient-name DOE*",
            "dicom-query pacs://server:11112 --aet SCU --study-date 20240101-20240131",
            "dicom-query pacs://server:11112 --aet SCU --modality CT --format json",
        ]
    )

    static let dicomRetrieve = ToolDefinition(
        name: "DICOM Retrieve",
        command: "dicom-retrieve",
        category: .networking,
        abstract: "Retrieve studies from PACS using C-MOVE or C-GET",
        discussion: """
            Downloads DICOM studies, series, or instances from PACS servers \
            using C-MOVE or C-GET services.
            """,
        icon: "arrow.down.circle",
        parameters: [
            ToolParameter(
                name: "Server URL",
                cliFlag: "",
                type: .positionalArgument,
                help: "PACS server URL (pacs://host:port)",
                isRequired: true,
                isPACSParameter: true
            ),
            ToolParameter(
                name: "AE Title",
                cliFlag: "--aet",
                type: .text,
                help: "Local Application Entity Title",
                isRequired: true,
                isPACSParameter: true
            ),
            ToolParameter(
                name: "Called AE Title",
                cliFlag: "--called-aet",
                type: .text,
                help: "Remote Application Entity Title",
                defaultValue: "ANY-SCP",
                isPACSParameter: true
            ),
            ToolParameter(
                name: "Study UID",
                cliFlag: "--study-uid",
                type: .text,
                help: "Study Instance UID to retrieve"
            ),
            ToolParameter(
                name: "Series UID",
                cliFlag: "--series-uid",
                type: .text,
                help: "Series Instance UID to retrieve"
            ),
            ToolParameter(
                name: "Instance UID",
                cliFlag: "--instance-uid",
                type: .text,
                help: "SOP Instance UID to retrieve"
            ),
            ToolParameter(
                name: "Output Directory",
                cliFlag: "--output",
                type: .outputDirectory,
                help: "Directory to save retrieved files"
            ),
            ToolParameter(
                name: "Retrieve Method",
                cliFlag: "--method",
                type: .dropdown(options: [
                    DropdownOption(label: "C-MOVE", value: "move",
                                   help: "Use C-MOVE (requires move destination)"),
                    DropdownOption(label: "C-GET", value: "get",
                                   help: "Use C-GET (direct retrieval)"),
                ]),
                help: "Retrieval method",
                discussion: "C-MOVE requires a registered move destination AE. C-GET retrieves directly.",
                defaultValue: "get"
            ),
            ToolParameter(
                name: "Move Destination",
                cliFlag: "--move-dest",
                type: .text,
                help: "Move destination AE Title (required for C-MOVE)",
                isPACSParameter: true
            ),
            ToolParameter(
                name: "Timeout",
                cliFlag: "--timeout",
                type: .number,
                help: "Connection timeout in seconds",
                defaultValue: "30"
            ),
            ToolParameter(
                name: "Parallel",
                cliFlag: "--parallel",
                type: .number,
                help: "Number of parallel retrievals"
            ),
            ToolParameter(
                name: "Hierarchical",
                cliFlag: "--hierarchical",
                type: .flag,
                help: "Use hierarchical retrieval (study→series→instance)"
            ),
            ToolParameter(
                name: "Verbose",
                cliFlag: "--verbose",
                type: .flag,
                help: "Show verbose output"
            ),
        ],
        examples: [
            "dicom-retrieve pacs://server:11112 --aet SCU --study-uid 1.2.3.4",
            "dicom-retrieve pacs://server:11112 --aet SCU --method move --move-dest STORAGE",
        ]
    )

    static let dicomSend = ToolDefinition(
        name: "DICOM Send",
        command: "dicom-send",
        category: .networking,
        abstract: "Send DICOM files to a PACS server using C-STORE",
        discussion: """
            Transmits DICOM files to a remote PACS server using the C-STORE service. \
            Supports batch sending, retry logic, and verification.
            """,
        icon: "arrow.up.circle",
        parameters: [
            ToolParameter(
                name: "Server URL",
                cliFlag: "",
                type: .positionalArgument,
                help: "PACS server URL (pacs://host:port)",
                isRequired: true,
                isPACSParameter: true
            ),
            ToolParameter(
                id: "send_files",
                name: "Files",
                cliFlag: " ",
                type: .positionalFiles(allowedTypes: ["dcm", "dicom"]),
                help: "DICOM files or directories to send",
                isRequired: true
            ),
            ToolParameter(
                name: "AE Title",
                cliFlag: "--aet",
                type: .text,
                help: "Local Application Entity Title",
                isRequired: true,
                isPACSParameter: true
            ),
            ToolParameter(
                name: "Called AE Title",
                cliFlag: "--called-aet",
                type: .text,
                help: "Remote Application Entity Title",
                defaultValue: "ANY-SCP",
                isPACSParameter: true
            ),
            ToolParameter(
                name: "Retry Count",
                cliFlag: "--retry",
                type: .number,
                help: "Number of retry attempts on failure",
                defaultValue: "0"
            ),
            ToolParameter(
                name: "Priority",
                cliFlag: "--priority",
                type: .dropdown(options: [
                    DropdownOption(label: "Medium", value: "medium", help: "Normal priority"),
                    DropdownOption(label: "High", value: "high", help: "High priority"),
                    DropdownOption(label: "Low", value: "low", help: "Low priority"),
                ]),
                help: "DIMSE priority level",
                defaultValue: "medium"
            ),
            ToolParameter(
                name: "Timeout",
                cliFlag: "--timeout",
                type: .number,
                help: "Connection timeout in seconds",
                defaultValue: "30"
            ),
            ToolParameter(
                name: "Recursive",
                cliFlag: "--recursive",
                type: .flag,
                help: "Send files from subdirectories"
            ),
            ToolParameter(
                name: "Verify",
                cliFlag: "--verify",
                type: .flag,
                help: "Verify files after sending (C-ECHO + C-FIND)"
            ),
            ToolParameter(
                name: "Dry Run",
                cliFlag: "--dry-run",
                type: .flag,
                help: "List files without sending"
            ),
            ToolParameter(
                name: "Verbose",
                cliFlag: "--verbose",
                type: .flag,
                help: "Show verbose output"
            ),
        ],
        examples: [
            "dicom-send pacs://server:11112 scan.dcm --aet SCU",
            "dicom-send pacs://server:11112 ./studies/ --aet SCU --recursive",
            "dicom-send pacs://server:11112 *.dcm --aet SCU --verify --verbose",
        ]
    )

    static let dicomQr = ToolDefinition(
        name: "DICOM Q/R",
        command: "dicom-qr",
        category: .networking,
        abstract: "Combined Query/Retrieve workflow",
        discussion: """
            Performs a combined DICOM Query/Retrieve operation. First queries \
            the PACS for matching studies, then retrieves the results.
            """,
        icon: "arrow.triangle.2.circlepath.circle",
        parameters: [
            ToolParameter(
                name: "Server URL",
                cliFlag: "",
                type: .positionalArgument,
                help: "PACS server URL (pacs://host:port)",
                isRequired: true,
                isPACSParameter: true
            ),
            ToolParameter(
                name: "AE Title",
                cliFlag: "--aet",
                type: .text,
                help: "Local Application Entity Title",
                isRequired: true,
                isPACSParameter: true
            ),
            ToolParameter(
                name: "Called AE Title",
                cliFlag: "--called-aet",
                type: .text,
                help: "Remote Application Entity Title",
                defaultValue: "ANY-SCP",
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
                name: "Output Directory",
                cliFlag: "--output",
                type: .outputDirectory,
                help: "Directory to save retrieved files"
            ),
            ToolParameter(
                name: "Method",
                cliFlag: "--method",
                type: .dropdown(options: [
                    DropdownOption(label: "C-GET", value: "get", help: "Direct retrieval"),
                    DropdownOption(label: "C-MOVE", value: "move", help: "Move-based retrieval"),
                ]),
                help: "Retrieval method",
                defaultValue: "get"
            ),
            ToolParameter(
                name: "Move Destination",
                cliFlag: "--move-dest",
                type: .text,
                help: "Move destination AE (for C-MOVE)",
                isPACSParameter: true
            ),
            ToolParameter(
                name: "Auto Retrieve",
                cliFlag: "--auto",
                type: .flag,
                help: "Automatically retrieve all query results"
            ),
            ToolParameter(
                name: "Verbose",
                cliFlag: "--verbose",
                type: .flag,
                help: "Show verbose output"
            ),
        ],
        examples: [
            "dicom-qr pacs://server:11112 --aet SCU --patient-name DOE* --auto",
            "dicom-qr pacs://server:11112 --aet SCU --modality CT --output ./downloads/",
        ]
    )

    static let dicomMwl = ToolDefinition(
        name: "Modality Worklist",
        command: "dicom-mwl",
        category: .networking,
        abstract: "Query Modality Worklist",
        discussion: """
            Queries the DICOM Modality Worklist (MWL) service to find scheduled \
            procedures. Used for integration with RIS/HIS systems.
            """,
        icon: "list.clipboard",
        parameters: [
            ToolParameter(
                name: "Server URL",
                cliFlag: "",
                type: .positionalArgument,
                help: "PACS/RIS server URL (pacs://host:port)",
                isRequired: true,
                isPACSParameter: true
            ),
            ToolParameter(
                name: "AE Title",
                cliFlag: "--aet",
                type: .text,
                help: "Local Application Entity Title",
                isRequired: true,
                isPACSParameter: true
            ),
            ToolParameter(
                name: "Called AE Title",
                cliFlag: "--called-aet",
                type: .text,
                help: "Remote Application Entity Title",
                defaultValue: "ANY-SCP",
                isPACSParameter: true
            ),
            ToolParameter(
                name: "Date",
                cliFlag: "--date",
                type: .text,
                help: "Scheduled procedure date (YYYYMMDD)"
            ),
            ToolParameter(
                name: "Station Name",
                cliFlag: "--station",
                type: .text,
                help: "Scheduled station name"
            ),
            ToolParameter(
                name: "Patient Name",
                cliFlag: "--patient",
                type: .text,
                help: "Patient name filter"
            ),
            ToolParameter(
                name: "Patient ID",
                cliFlag: "--patient-id",
                type: .text,
                help: "Patient ID filter"
            ),
            ToolParameter(
                name: "Modality",
                cliFlag: "--modality",
                type: .text,
                help: "Scheduled modality filter"
            ),
            ToolParameter(
                name: "Timeout",
                cliFlag: "--timeout",
                type: .number,
                help: "Connection timeout in seconds",
                defaultValue: "30"
            ),
            ToolParameter(
                name: "JSON Output",
                cliFlag: "--json",
                type: .flag,
                help: "Output results as JSON"
            ),
            ToolParameter(
                name: "Verbose",
                cliFlag: "--verbose",
                type: .flag,
                help: "Show verbose output"
            ),
        ],
        examples: [
            "dicom-mwl pacs://ris:11112 --aet MODALITY --date 20240115",
            "dicom-mwl pacs://ris:11112 --aet MODALITY --modality CT --json",
        ]
    )

    static let dicomMpps = ToolDefinition(
        name: "DICOM MPPS",
        command: "dicom-mpps",
        category: .networking,
        abstract: "Modality Performed Procedure Step",
        discussion: """
            Manages MPPS (Modality Performed Procedure Step) to report procedure \
            status back to PACS/RIS. Supports creating and updating MPPS instances.
            """,
        icon: "checkmark.circle.badge.questionmark",
        subcommands: [
            SubcommandDefinition(
                name: "create",
                abstract: "Create a new MPPS instance (In Progress)",
                parameters: [
                    ToolParameter(
                        name: "Server URL",
                        cliFlag: "",
                        type: .positionalArgument,
                        help: "PACS server URL",
                        isRequired: true,
                        isPACSParameter: true
                    ),
                    ToolParameter(
                        name: "AE Title",
                        cliFlag: "--aet",
                        type: .text,
                        help: "Local AE Title",
                        isRequired: true,
                        isPACSParameter: true
                    ),
                    ToolParameter(
                        name: "Called AE Title",
                        cliFlag: "--called-aet",
                        type: .text,
                        help: "Remote AE Title",
                        defaultValue: "ANY-SCP",
                        isPACSParameter: true
                    ),
                    ToolParameter(
                        name: "Study UID",
                        cliFlag: "--study-uid",
                        type: .text,
                        help: "Study Instance UID",
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
            SubcommandDefinition(
                name: "update",
                abstract: "Update an existing MPPS instance (Complete/Discontinue)",
                parameters: [
                    ToolParameter(
                        name: "Server URL",
                        cliFlag: "",
                        type: .positionalArgument,
                        help: "PACS server URL",
                        isRequired: true,
                        isPACSParameter: true
                    ),
                    ToolParameter(
                        name: "AE Title",
                        cliFlag: "--aet",
                        type: .text,
                        help: "Local AE Title",
                        isRequired: true,
                        isPACSParameter: true
                    ),
                    ToolParameter(
                        name: "Called AE Title",
                        cliFlag: "--called-aet",
                        type: .text,
                        help: "Remote AE Title",
                        defaultValue: "ANY-SCP",
                        isPACSParameter: true
                    ),
                    ToolParameter(
                        name: "MPPS UID",
                        cliFlag: "--mpps-uid",
                        type: .text,
                        help: "MPPS SOP Instance UID to update",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Status",
                        cliFlag: "--status",
                        type: .dropdown(options: [
                            DropdownOption(label: "Completed", value: "COMPLETED", help: "Procedure completed"),
                            DropdownOption(label: "Discontinued", value: "DISCONTINUED",
                                           help: "Procedure discontinued"),
                        ]),
                        help: "New MPPS status",
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
            "dicom-mpps create pacs://server:11112 --aet SCU --study-uid 1.2.3",
            "dicom-mpps update pacs://server:11112 --aet SCU --mpps-uid 1.2.3 --status COMPLETED",
        ]
    )
}
