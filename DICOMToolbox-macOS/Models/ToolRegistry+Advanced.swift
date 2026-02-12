import Foundation

// MARK: - Advanced Tools

extension ToolRegistry {

    static let dicomAnon = ToolDefinition(
        name: "DICOM Anonymize",
        command: "dicom-anon",
        category: .advanced,
        abstract: "Anonymize DICOM files to remove patient information",
        discussion: """
            Removes or replaces protected health information (PHI) from DICOM files. \
            Supports multiple anonymization profiles and customizable rules for \
            HIPAA compliance and research use.
            """,
        icon: "person.badge.minus",
        parameters: [
            ToolParameter(
                name: "Input",
                cliFlag: "",
                type: .positionalFile(allowedTypes: ["dcm", "dicom", "dic"]),
                help: "Input DICOM file or directory",
                isRequired: true
            ),
            ToolParameter(
                name: "Output",
                cliFlag: "--output",
                type: .outputFile(allowedTypes: ["dcm"]),
                help: "Output file or directory for anonymized files"
            ),
            ToolParameter(
                name: "Profile",
                cliFlag: "--profile",
                type: .dropdown(options: [
                    DropdownOption(label: "Basic", value: "basic",
                                   help: "Remove common PHI fields"),
                    DropdownOption(label: "Clinical Trial", value: "clinical-trial",
                                   help: "DICOM PS3.15 clinical trial de-identification"),
                    DropdownOption(label: "Research", value: "research",
                                   help: "Comprehensive research anonymization"),
                ]),
                help: "Anonymization profile to apply",
                discussion: "Each profile defines which tags to remove, replace, or preserve",
                defaultValue: "basic"
            ),
            ToolParameter(
                name: "Shift Dates",
                cliFlag: "--shift-dates",
                type: .number,
                help: "Number of days to shift all dates",
                discussion: "Preserves temporal relationships while de-identifying dates"
            ),
            ToolParameter(
                name: "Regenerate UIDs",
                cliFlag: "--regenerate-uids",
                type: .flag,
                help: "Generate new UIDs for all instances",
                discussion: "Creates new Study, Series, and SOP Instance UIDs"
            ),
            ToolParameter(
                name: "Remove Tags",
                cliFlag: "--remove",
                type: .multiText,
                help: "Additional tags to remove (format: group,element)"
            ),
            ToolParameter(
                name: "Replace Tags",
                cliFlag: "--replace",
                type: .multiText,
                help: "Tags to replace with values (format: TAG=VALUE)"
            ),
            ToolParameter(
                name: "Keep Tags",
                cliFlag: "--keep",
                type: .multiText,
                help: "Tags to preserve (override profile removal)"
            ),
            ToolParameter(
                name: "Recursive",
                cliFlag: "--recursive",
                type: .flag,
                help: "Process directories recursively"
            ),
            ToolParameter(
                name: "Dry Run",
                cliFlag: "--dry-run",
                type: .flag,
                help: "Preview anonymization without modifying files"
            ),
            ToolParameter(
                name: "Backup",
                cliFlag: "--backup",
                type: .flag,
                help: "Create backup copies of original files"
            ),
            ToolParameter(
                name: "Audit Log",
                cliFlag: "--audit-log",
                type: .outputFile(allowedTypes: ["log", "txt"]),
                help: "Path to save an audit log of changes"
            ),
            ToolParameter(
                name: "Force",
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
            "dicom-anon scan.dcm --output anon.dcm --profile basic",
            "dicom-anon ./studies/ --recursive --profile research --shift-dates 30",
            "dicom-anon scan.dcm --dry-run --verbose",
        ]
    )

    static let dicomArchive = ToolDefinition(
        name: "DICOM Archive",
        command: "dicom-archive",
        category: .advanced,
        abstract: "Manage DICOM file archives",
        discussion: """
            Create and manage organized DICOM file archives with import, \
            query, export, and integrity checking capabilities.
            """,
        icon: "archivebox",
        subcommands: [
            SubcommandDefinition(
                name: "init",
                abstract: "Initialize a new archive",
                parameters: [
                    ToolParameter(
                        name: "Archive Path",
                        cliFlag: "--path",
                        type: .outputDirectory,
                        help: "Directory path for the new archive",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Force",
                        cliFlag: "--force",
                        type: .flag,
                        help: "Overwrite existing archive"
                    ),
                ]
            ),
            SubcommandDefinition(
                name: "import",
                abstract: "Import files into an archive",
                parameters: [
                    ToolParameter(
                        name: "Files",
                        cliFlag: "",
                        type: .positionalFiles(allowedTypes: ["dcm", "dicom"]),
                        help: "Files or directories to import",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Archive",
                        cliFlag: "--archive",
                        type: .inputDirectory,
                        help: "Archive directory path",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Recursive",
                        cliFlag: "--recursive",
                        type: .flag,
                        help: "Scan directories recursively"
                    ),
                    ToolParameter(
                        name: "Skip Duplicates",
                        cliFlag: "--skip-duplicates",
                        type: .flag,
                        help: "Skip files with duplicate SOP Instance UIDs"
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
                name: "stats",
                abstract: "Show archive statistics",
                parameters: [
                    ToolParameter(
                        name: "Archive",
                        cliFlag: "",
                        type: .positionalDirectory,
                        help: "Archive directory path",
                        isRequired: true
                    ),
                ]
            ),
        ],
        examples: [
            "dicom-archive init --path ./my-archive",
            "dicom-archive import ./studies/ --archive ./my-archive --recursive",
            "dicom-archive stats ./my-archive",
        ]
    )

    static let dicomDcmdir = ToolDefinition(
        name: "DICOMDIR",
        command: "dicom-dcmdir",
        category: .advanced,
        abstract: "Create and manage DICOMDIR files",
        discussion: """
            DICOMDIR is a directory file that provides an index of DICOM files \
            on removable media (CD/DVD/USB). This tool creates, validates, \
            and displays DICOMDIR files.
            """,
        icon: "folder",
        subcommands: [
            SubcommandDefinition(
                name: "create",
                abstract: "Create a DICOMDIR from a directory of DICOM files",
                parameters: [
                    ToolParameter(
                        name: "Input Directory",
                        cliFlag: "",
                        type: .positionalDirectory,
                        help: "Directory containing DICOM files",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Output",
                        cliFlag: "--output",
                        type: .outputFile(allowedTypes: ["dcm"]),
                        help: "Output DICOMDIR file path"
                    ),
                    ToolParameter(
                        name: "File Set ID",
                        cliFlag: "--file-set-id",
                        type: .text,
                        help: "File Set ID for the DICOMDIR"
                    ),
                    ToolParameter(
                        name: "Recursive",
                        cliFlag: "--recursive",
                        type: .flag,
                        help: "Scan subdirectories recursively"
                    ),
                    ToolParameter(
                        name: "Strict",
                        cliFlag: "--strict",
                        type: .flag,
                        help: "Enable strict validation"
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
                name: "validate",
                abstract: "Validate an existing DICOMDIR",
                parameters: [
                    ToolParameter(
                        name: "DICOMDIR Path",
                        cliFlag: "",
                        type: .positionalFile(allowedTypes: ["dcm", "DICOMDIR"]),
                        help: "Path to the DICOMDIR file",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Check Files",
                        cliFlag: "--check-files",
                        type: .flag,
                        help: "Verify referenced files exist"
                    ),
                    ToolParameter(
                        name: "Detailed",
                        cliFlag: "--detailed",
                        type: .flag,
                        help: "Show detailed validation results"
                    ),
                ]
            ),
            SubcommandDefinition(
                name: "dump",
                abstract: "Display DICOMDIR contents",
                parameters: [
                    ToolParameter(
                        name: "DICOMDIR Path",
                        cliFlag: "",
                        type: .positionalFile(allowedTypes: ["dcm", "DICOMDIR"]),
                        help: "Path to the DICOMDIR file",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Format",
                        cliFlag: "--format",
                        type: .dropdown(options: [
                            DropdownOption(label: "Tree", value: "tree", help: "Tree view"),
                            DropdownOption(label: "JSON", value: "json", help: "JSON format"),
                            DropdownOption(label: "Text", value: "text", help: "Plain text"),
                        ]),
                        help: "Output display format",
                        defaultValue: "tree"
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
            "dicom-dcmdir create ./dicom-files/ --output DICOMDIR",
            "dicom-dcmdir validate DICOMDIR --check-files",
            "dicom-dcmdir dump DICOMDIR --format tree",
        ]
    )

    static let dicomStudy = ToolDefinition(
        name: "DICOM Study",
        command: "dicom-study",
        category: .advanced,
        abstract: "Study organization and management",
        discussion: """
            Organize, summarize, check, and compare DICOM studies. \
            Provides study-level operations for managing collections of DICOM files.
            """,
        icon: "folder.badge.gearshape",
        subcommands: [
            SubcommandDefinition(
                name: "organize",
                abstract: "Organize DICOM files by patient/study/series hierarchy",
                parameters: [
                    ToolParameter(
                        name: "Input Directory",
                        cliFlag: "",
                        type: .positionalDirectory,
                        help: "Directory with DICOM files to organize",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Output Directory",
                        cliFlag: "--output",
                        type: .outputDirectory,
                        help: "Output directory for organized files"
                    ),
                    ToolParameter(
                        name: "Copy",
                        cliFlag: "--copy",
                        type: .flag,
                        help: "Copy files instead of moving them"
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
                name: "summary",
                abstract: "Show a summary of studies in a directory",
                parameters: [
                    ToolParameter(
                        name: "Input Directory",
                        cliFlag: "",
                        type: .positionalDirectory,
                        help: "Directory containing DICOM files",
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
                name: "check",
                abstract: "Check study completeness and consistency",
                parameters: [
                    ToolParameter(
                        name: "Input Directory",
                        cliFlag: "",
                        type: .positionalDirectory,
                        help: "Directory containing DICOM files",
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
            "dicom-study organize ./unsorted/ --output ./organized/ --copy",
            "dicom-study summary ./studies/",
            "dicom-study check ./patient-study/",
        ]
    )

    static let dicomScript = ToolDefinition(
        name: "DICOM Script",
        command: "dicom-script",
        category: .advanced,
        abstract: "Run DICOM processing scripts",
        discussion: """
            Execute scripted DICOM processing workflows. Supports batch operations, \
            variable substitution, and template-based processing.
            """,
        icon: "applescript",
        subcommands: [
            SubcommandDefinition(
                name: "run",
                abstract: "Execute a DICOM processing script",
                parameters: [
                    ToolParameter(
                        name: "Script File",
                        cliFlag: "",
                        type: .positionalFile(allowedTypes: ["dscript", "txt", "json"]),
                        help: "Path to the script file",
                        isRequired: true
                    ),
                    ToolParameter(
                        name: "Variables",
                        cliFlag: "--variables",
                        type: .multiText,
                        help: "Script variables (format: KEY=VALUE)"
                    ),
                    ToolParameter(
                        name: "Dry Run",
                        cliFlag: "--dry-run",
                        type: .flag,
                        help: "Preview script execution without running"
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
                name: "validate",
                abstract: "Validate a script file",
                parameters: [
                    ToolParameter(
                        name: "Script File",
                        cliFlag: "",
                        type: .positionalFile(allowedTypes: ["dscript", "txt", "json"]),
                        help: "Path to the script file to validate",
                        isRequired: true
                    ),
                ]
            ),
        ],
        examples: [
            "dicom-script run workflow.dscript --variables INPUT=./data OUTPUT=./results",
            "dicom-script validate workflow.dscript",
        ]
    )
}
