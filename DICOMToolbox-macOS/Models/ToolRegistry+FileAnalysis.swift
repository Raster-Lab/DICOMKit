import Foundation

// MARK: - File Analysis Tools

extension ToolRegistry {

    static let dicomInfo = ToolDefinition(
        name: "DICOM Info",
        command: "dicom-info",
        category: .fileAnalysis,
        abstract: "Display metadata from DICOM medical imaging files",
        discussion: """
            Extracts and displays metadata tags from DICOM Part 10 files. \
            Supports multiple output formats for different use cases including \
            plain text, JSON, and CSV.
            """,
        icon: "info.circle",
        parameters: [
            ToolParameter(
                name: "File Path",
                cliFlag: "",
                type: .positionalFile(allowedTypes: ["dcm", "dicom", "dic"]),
                help: "Path to the DICOM file to inspect",
                isRequired: true
            ),
            ToolParameter(
                name: "Output Format",
                cliFlag: "--format",
                type: .dropdown(options: [
                    DropdownOption(label: "Text", value: "text", help: "Plain text output"),
                    DropdownOption(label: "JSON", value: "json", help: "JSON format"),
                    DropdownOption(label: "CSV", value: "csv", help: "CSV format"),
                ]),
                help: "Output format for the metadata display",
                defaultValue: "text"
            ),
            ToolParameter(
                name: "Filter Tags",
                cliFlag: "--tag",
                type: .multiText,
                help: "Filter by specific tag names (can specify multiple)",
                discussion: "Use DICOM keyword names like PatientName, StudyDate, Modality"
            ),
            ToolParameter(
                name: "Show Private Tags",
                cliFlag: "--show-private",
                type: .flag,
                help: "Include private (vendor-specific) tags in output",
                discussion: "Private tags contain vendor-specific information that may be useful for debugging"
            ),
            ToolParameter(
                name: "Show Statistics",
                cliFlag: "--statistics",
                type: .flag,
                help: "Display file size, tag count, and other statistics"
            ),
            ToolParameter(
                name: "Force Parse",
                cliFlag: "--force",
                type: .flag,
                help: "Attempt to parse files without the standard DICM preamble",
                discussion: "Some older or non-conformant files may lack the DICM prefix"
            ),
        ],
        examples: [
            "dicom-info scan.dcm",
            "dicom-info --format json report.dcm",
            "dicom-info --tag PatientName --tag StudyDate exam.dcm",
        ]
    )

    static let dicomDump = ToolDefinition(
        name: "DICOM Dump",
        command: "dicom-dump",
        category: .fileAnalysis,
        abstract: "Hexadecimal dump of DICOM file contents",
        discussion: """
            Provides a low-level hexadecimal view of DICOM file data. \
            Useful for debugging file structure issues and examining raw data bytes.
            """,
        icon: "text.viewfinder",
        parameters: [
            ToolParameter(
                name: "File Path",
                cliFlag: "",
                type: .positionalFile(allowedTypes: ["dcm", "dicom", "dic"]),
                help: "Path to the DICOM file to dump",
                isRequired: true
            ),
            ToolParameter(
                name: "Tag",
                cliFlag: "--tag",
                type: .text,
                help: "Dump a specific tag (format: 0010,0010)",
                discussion: "Specify a DICOM tag in group,element format to dump only that tag's data"
            ),
            ToolParameter(
                name: "Offset",
                cliFlag: "--offset",
                type: .text,
                help: "Start offset in hex (0x1A0) or decimal",
                discussion: "Begin the dump at a specific byte offset in the file"
            ),
            ToolParameter(
                name: "Length",
                cliFlag: "--length",
                type: .number,
                help: "Number of bytes to display"
            ),
            ToolParameter(
                name: "Bytes Per Line",
                cliFlag: "--bytes-per-line",
                type: .number,
                help: "Number of bytes displayed per line",
                defaultValue: "16"
            ),
            ToolParameter(
                name: "Highlight Tag",
                cliFlag: "--highlight",
                type: .text,
                help: "Highlight a specific tag in the hex output"
            ),
            ToolParameter(
                name: "No Color",
                cliFlag: "--no-color",
                type: .flag,
                help: "Disable ANSI color output"
            ),
            ToolParameter(
                name: "Annotate",
                cliFlag: "--annotate",
                type: .flag,
                help: "Show annotations alongside hex data"
            ),
            ToolParameter(
                name: "Force Parse",
                cliFlag: "--force",
                type: .flag,
                help: "Force parsing of files without DICM prefix"
            ),
            ToolParameter(
                name: "Verbose",
                cliFlag: "--verbose",
                type: .flag,
                help: "Show verbose output"
            ),
        ],
        examples: [
            "dicom-dump scan.dcm",
            "dicom-dump --tag 0010,0010 scan.dcm",
            "dicom-dump --offset 0x80 --length 256 scan.dcm",
        ]
    )

    static let dicomTags = ToolDefinition(
        name: "DICOM Tags",
        command: "dicom-tags",
        category: .fileAnalysis,
        abstract: "Edit, set, or delete DICOM tags",
        discussion: """
            Modify DICOM tag values in files. Supports setting new values, \
            deleting tags, copying tags between files, and removing private tags.
            """,
        icon: "tag",
        parameters: [
            ToolParameter(
                name: "Input File",
                cliFlag: "",
                type: .positionalFile(allowedTypes: ["dcm", "dicom", "dic"]),
                help: "Path to the DICOM file",
                isRequired: true
            ),
            ToolParameter(
                name: "Output",
                cliFlag: "--output",
                type: .outputFile(allowedTypes: ["dcm"]),
                help: "Output file path for modified file"
            ),
            ToolParameter(
                name: "Set Tags",
                cliFlag: "--set",
                type: .multiText,
                help: "Set tag values (format: TAG=VALUE, e.g., 0010,0010=DOE^JOHN)",
                discussion: "Use DICOM group,element format for the tag identifier"
            ),
            ToolParameter(
                name: "Delete Tags",
                cliFlag: "--delete",
                type: .multiText,
                help: "Tags to delete (format: TAG, e.g., 0010,0010)"
            ),
            ToolParameter(
                name: "Copy From",
                cliFlag: "--copy-from",
                type: .inputFile(allowedTypes: ["dcm", "dicom", "dic"]),
                help: "Copy tags from another DICOM file"
            ),
            ToolParameter(
                name: "Tags to Copy",
                cliFlag: "--tags",
                type: .multiText,
                help: "Specific tags to copy (used with --copy-from)"
            ),
            ToolParameter(
                name: "Delete Private",
                cliFlag: "--delete-private",
                type: .flag,
                help: "Remove all private (vendor-specific) tags"
            ),
            ToolParameter(
                name: "Dry Run",
                cliFlag: "--dry-run",
                type: .flag,
                help: "Preview changes without modifying the file"
            ),
            ToolParameter(
                name: "Verbose",
                cliFlag: "--verbose",
                type: .flag,
                help: "Show verbose output"
            ),
        ],
        examples: [
            "dicom-tags scan.dcm --set 0010,0010=DOE^JOHN",
            "dicom-tags scan.dcm --delete 0010,0010 --output modified.dcm",
            "dicom-tags scan.dcm --delete-private --dry-run",
        ]
    )

    static let dicomValidate = ToolDefinition(
        name: "DICOM Validate",
        command: "dicom-validate",
        category: .fileAnalysis,
        abstract: "Validate DICOM files for conformance",
        discussion: """
            Checks DICOM files against the standard for conformance issues. \
            Validates file structure, required tags, value representations, \
            and IOD (Information Object Definition) compliance.
            """,
        icon: "checkmark.shield",
        parameters: [
            ToolParameter(
                name: "Input",
                cliFlag: "",
                type: .positionalFile(allowedTypes: ["dcm", "dicom", "dic"]),
                help: "Path to the DICOM file or directory to validate",
                isRequired: true
            ),
            ToolParameter(
                name: "Validation Level",
                cliFlag: "--level",
                type: .dropdown(options: [
                    DropdownOption(label: "Basic", value: "basic", help: "Basic structure validation"),
                    DropdownOption(label: "Standard", value: "standard", help: "Standard conformance checks"),
                    DropdownOption(label: "Strict", value: "strict", help: "Strict conformance validation"),
                ]),
                help: "Level of validation strictness",
                defaultValue: "standard"
            ),
            ToolParameter(
                name: "IOD",
                cliFlag: "--iod",
                type: .text,
                help: "Specific IOD to validate against (e.g., CT, MR, CR)",
                discussion: "Force validation against a specific Information Object Definition"
            ),
            ToolParameter(
                name: "Output Format",
                cliFlag: "--format",
                type: .dropdown(options: [
                    DropdownOption(label: "Text", value: "text", help: "Human-readable text"),
                    DropdownOption(label: "JSON", value: "json", help: "JSON format"),
                ]),
                help: "Output format for validation results",
                defaultValue: "text"
            ),
            ToolParameter(
                name: "Output File",
                cliFlag: "--output",
                type: .outputFile(allowedTypes: ["txt", "json"]),
                help: "Save validation report to file"
            ),
            ToolParameter(
                name: "Detailed",
                cliFlag: "--detailed",
                type: .flag,
                help: "Show detailed validation messages"
            ),
            ToolParameter(
                name: "Recursive",
                cliFlag: "--recursive",
                type: .flag,
                help: "Recursively validate files in directories"
            ),
            ToolParameter(
                name: "Strict",
                cliFlag: "--strict",
                type: .flag,
                help: "Enable strict validation mode"
            ),
            ToolParameter(
                name: "Force Parse",
                cliFlag: "--force",
                type: .flag,
                help: "Force parsing of files without DICM prefix"
            ),
        ],
        examples: [
            "dicom-validate scan.dcm",
            "dicom-validate --level strict --detailed scan.dcm",
            "dicom-validate --recursive --format json ./studies/",
        ]
    )

    static let dicomDiff = ToolDefinition(
        name: "DICOM Diff",
        command: "dicom-diff",
        category: .fileAnalysis,
        abstract: "Compare two DICOM files and show differences",
        discussion: """
            Compares metadata and optionally pixel data between two DICOM files. \
            Useful for verifying anonymization, tracking changes, or debugging.
            """,
        icon: "arrow.left.arrow.right",
        parameters: [
            ToolParameter(
                id: "file1",
                name: "First File",
                cliFlag: "",
                type: .positionalFile(allowedTypes: ["dcm", "dicom", "dic"]),
                help: "Path to the first DICOM file",
                isRequired: true
            ),
            ToolParameter(
                id: "file2",
                name: "Second File",
                cliFlag: " ",
                type: .positionalFile(allowedTypes: ["dcm", "dicom", "dic"]),
                help: "Path to the second DICOM file",
                isRequired: true
            ),
            ToolParameter(
                name: "Output Format",
                cliFlag: "--format",
                type: .dropdown(options: [
                    DropdownOption(label: "Text", value: "text", help: "Human-readable text"),
                    DropdownOption(label: "JSON", value: "json", help: "JSON format"),
                    DropdownOption(label: "Summary", value: "summary", help: "Brief summary only"),
                ]),
                help: "Output format for diff results",
                defaultValue: "text"
            ),
            ToolParameter(
                name: "Ignore Tags",
                cliFlag: "--ignore-tag",
                type: .multiText,
                help: "Tags to ignore during comparison (can specify multiple)"
            ),
            ToolParameter(
                name: "Ignore Private",
                cliFlag: "--ignore-private",
                type: .flag,
                help: "Skip private tags in comparison"
            ),
            ToolParameter(
                name: "Compare Pixels",
                cliFlag: "--compare-pixels",
                type: .flag,
                help: "Include pixel data in comparison",
                discussion: "Pixel comparison can be slow for large images"
            ),
            ToolParameter(
                name: "Tolerance",
                cliFlag: "--tolerance",
                type: .number,
                help: "Pixel value tolerance for comparison",
                defaultValue: "0.0"
            ),
            ToolParameter(
                name: "Quick Mode",
                cliFlag: "--quick",
                type: .flag,
                help: "Compare metadata only (skip large data elements)"
            ),
            ToolParameter(
                name: "Show Identical",
                cliFlag: "--show-identical",
                type: .flag,
                help: "Include matching tags in the output"
            ),
            ToolParameter(
                name: "Verbose",
                cliFlag: "--verbose",
                type: .flag,
                help: "Show verbose output"
            ),
        ],
        examples: [
            "dicom-diff original.dcm modified.dcm",
            "dicom-diff --format json --ignore-private file1.dcm file2.dcm",
            "dicom-diff --compare-pixels --tolerance 0.01 a.dcm b.dcm",
        ]
    )
}
