// CLIWorkshopHelpers.swift
// DICOMStudio
//
// DICOM Studio — Platform-independent helpers for CLI Tools Workshop (Milestone 16)

import Foundation
import DICOMCLITools

// MARK: - 16.1 Network Configuration Helpers

/// Helpers for PACS network configuration validation and defaults.
public enum NetworkConfigHelpers: Sendable {

    /// Maximum allowed length for a DICOM AE Title (PS3.8).
    public static let maxAETitleLength: Int = 16

    /// Default DICOM port number.
    public static let defaultPort: Int = 11112

    /// Default timeout in seconds.
    public static let defaultTimeout: Int = 60

    /// Validates an AE Title string.
    public static func validateAETitle(_ aeTitle: String) -> Bool {
        !aeTitle.isEmpty && aeTitle.count <= maxAETitleLength && aeTitle == aeTitle.trimmingCharacters(in: .whitespaces)
    }

    /// Validates a port number.
    public static func validatePort(_ port: Int) -> Bool {
        port >= 1 && port <= 65535
    }

    /// Validates a timeout value in seconds.
    public static func validateTimeout(_ timeout: Int) -> Bool {
        timeout >= 5 && timeout <= 300
    }

    /// Validates a hostname or IP address (non-empty check).
    public static func validateHost(_ host: String) -> Bool {
        !host.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Returns a default network profile.
    public static func defaultProfile() -> CLINetworkProfile {
        CLINetworkProfile(
            name: "Default",
            aeTitle: "DICOMSTUDIO",
            calledAET: "ANY-SCP",
            host: "localhost",
            port: defaultPort,
            timeout: defaultTimeout,
            protocolType: .dicom,
            isDefault: true
        )
    }

    /// Builds the connection summary string for a profile.
    public static func connectionSummary(for profile: CLINetworkProfile) -> String {
        "\(profile.aeTitle) → \(profile.calledAET)@\(profile.host):\(profile.port) (\(profile.protocolType.displayName))"
    }
}

// MARK: - 16.2 Tool Catalog Helpers

/// Helpers for building the catalog of all 29 CLI tools.
public enum ToolCatalogHelpers: Sendable {

    /// Returns all 29 CLI tool definitions organized by tab.
    public static func allTools() -> [CLIToolDefinition] {
        var tools: [CLIToolDefinition] = []
        tools.append(contentsOf: fileInspectionTools())
        tools.append(contentsOf: fileProcessingTools())
        tools.append(contentsOf: fileOrganizationTools())
        tools.append(contentsOf: dataExportTools())
        tools.append(contentsOf: networkOperationsTools())
        tools.append(contentsOf: automationTools())
        return tools
    }

    /// Returns tools for the File Inspection tab.
    public static func fileInspectionTools() -> [CLIToolDefinition] {
        [
            CLIToolDefinition(id: "dicom-info", name: "dicom-info", displayName: "DICOM Info",
                              category: .fileInspection, sfSymbol: "info.circle",
                              briefDescription: "Display DICOM file metadata, tags, and statistics",
                              dicomStandardRef: "PS3.10"),
            CLIToolDefinition(id: "dicom-dump", name: "dicom-dump", displayName: "DICOM Dump",
                              category: .fileInspection, sfSymbol: "text.alignleft",
                              briefDescription: "Hexadecimal dump with DICOM structure annotations",
                              dicomStandardRef: "PS3.5"),
            CLIToolDefinition(id: "dicom-tags", name: "dicom-tags", displayName: "DICOM Tags",
                              category: .fileInspection, sfSymbol: "tag",
                              briefDescription: "Tag dictionary lookup, set, and delete operations",
                              dicomStandardRef: "PS3.6"),
            CLIToolDefinition(id: "dicom-diff", name: "dicom-diff", displayName: "DICOM Diff",
                              category: .fileInspection, sfSymbol: "arrow.left.arrow.right",
                              briefDescription: "Compare two DICOM files and show differences"),
        ]
    }

    /// Returns tools for the File Processing tab.
    public static func fileProcessingTools() -> [CLIToolDefinition] {
        [
            CLIToolDefinition(id: "dicom-convert", name: "dicom-convert", displayName: "DICOM Convert",
                              category: .fileProcessing, sfSymbol: "arrow.triangle.2.circlepath",
                              briefDescription: "Transfer syntax conversion and image export",
                              dicomStandardRef: "PS3.5"),
            CLIToolDefinition(id: "dicom-validate", name: "dicom-validate", displayName: "DICOM Validate",
                              category: .fileProcessing, sfSymbol: "checkmark.shield",
                              briefDescription: "DICOM conformance validation against IODs",
                              dicomStandardRef: "PS3.3"),
            CLIToolDefinition(id: "dicom-anon", name: "dicom-anon", displayName: "DICOM Anon",
                              category: .fileProcessing, sfSymbol: "person.crop.circle.badge.minus",
                              briefDescription: "Anonymize DICOM files following PS3.15 profiles",
                              dicomStandardRef: "PS3.15"),
            CLIToolDefinition(id: "dicom-compress", name: "dicom-compress", displayName: "DICOM Compress",
                              category: .fileProcessing, sfSymbol: "archivebox",
                              briefDescription: "Compress and decompress DICOM pixel data",
                              dicomStandardRef: "PS3.5", hasSubcommands: true),
        ]
    }

    /// Returns tools for the File Organization tab.
    public static func fileOrganizationTools() -> [CLIToolDefinition] {
        [
            CLIToolDefinition(id: "dicom-split", name: "dicom-split", displayName: "DICOM Split",
                              category: .fileOrganization, sfSymbol: "rectangle.split.2x1",
                              briefDescription: "Split multi-frame DICOM files into single frames"),
            CLIToolDefinition(id: "dicom-merge", name: "dicom-merge", displayName: "DICOM Merge",
                              category: .fileOrganization, sfSymbol: "rectangle.compress.vertical",
                              briefDescription: "Merge single-frame DICOM files into multi-frame"),
            CLIToolDefinition(id: "dicom-dcmdir", name: "dicom-dcmdir", displayName: "DICOMDIR",
                              category: .fileOrganization, sfSymbol: "folder.badge.plus",
                              briefDescription: "Create, validate, and manage DICOMDIR files",
                              dicomStandardRef: "PS3.10", hasSubcommands: true),
            CLIToolDefinition(id: "dicom-archive", name: "dicom-archive", displayName: "DICOM Archive",
                              category: .fileOrganization, sfSymbol: "tray.full",
                              briefDescription: "Archive DICOM files into organized directory structures"),
        ]
    }

    /// Returns tools for the Data Export tab.
    public static func dataExportTools() -> [CLIToolDefinition] {
        [
            CLIToolDefinition(id: "dicom-json", name: "dicom-json", displayName: "DICOM JSON",
                              category: .dataExport, sfSymbol: "curlybraces",
                              briefDescription: "Convert DICOM to/from JSON format",
                              dicomStandardRef: "PS3.18"),
            CLIToolDefinition(id: "dicom-xml", name: "dicom-xml", displayName: "DICOM XML",
                              category: .dataExport, sfSymbol: "chevron.left.forwardslash.chevron.right",
                              briefDescription: "Convert DICOM to/from XML format",
                              dicomStandardRef: "PS3.19"),
            CLIToolDefinition(id: "dicom-pdf", name: "dicom-pdf", displayName: "DICOM PDF",
                              category: .dataExport, sfSymbol: "doc.richtext",
                              briefDescription: "Extract or encapsulate PDF documents in DICOM"),
            CLIToolDefinition(id: "dicom-image", name: "dicom-image", displayName: "DICOM Image",
                              category: .dataExport, sfSymbol: "photo",
                              briefDescription: "Extract images and create Secondary Capture objects"),
            CLIToolDefinition(id: "dicom-export", name: "dicom-export", displayName: "DICOM Export",
                              category: .dataExport, sfSymbol: "square.and.arrow.up.on.square",
                              briefDescription: "Export frames as images, contact sheets, or animations",
                              hasSubcommands: true),
            CLIToolDefinition(id: "dicom-pixedit", name: "dicom-pixedit", displayName: "Pixel Edit",
                              category: .dataExport, sfSymbol: "pencil.and.outline",
                              briefDescription: "Edit pixel data: mask, crop, fill, and invert"),
        ]
    }

    /// Returns tools for the Network Operations tab.
    public static func networkOperationsTools() -> [CLIToolDefinition] {
        [
            CLIToolDefinition(id: "dicom-echo", name: "dicom-echo", displayName: "DICOM Echo",
                              category: .networkOperations, sfSymbol: "wave.3.right",
                              briefDescription: "Verify DICOM network connectivity with C-ECHO",
                              dicomStandardRef: "PS3.7", requiresNetwork: true,
                              networkToolGroup: .dimse),
            CLIToolDefinition(id: "dicom-query", name: "dicom-query", displayName: "DICOM Query",
                              category: .networkOperations, sfSymbol: "magnifyingglass",
                              briefDescription: "Query DICOM servers with C-FIND",
                              dicomStandardRef: "PS3.4", requiresNetwork: true,
                              networkToolGroup: .dimse),
            CLIToolDefinition(id: "dicom-send", name: "dicom-send", displayName: "DICOM Send",
                              category: .networkOperations, sfSymbol: "arrow.up.circle",
                              briefDescription: "Send DICOM files to servers with C-STORE",
                              dicomStandardRef: "PS3.4", requiresNetwork: true,
                              networkToolGroup: .dimse),
            CLIToolDefinition(id: "dicom-retrieve", name: "dicom-retrieve", displayName: "DICOM Retrieve",
                              category: .networkOperations, sfSymbol: "arrow.down.circle",
                              briefDescription: "Retrieve DICOM files from PACS with C-MOVE/C-GET",
                              dicomStandardRef: "PS3.4", requiresNetwork: true,
                              networkToolGroup: .dimse),
            CLIToolDefinition(id: "dicom-qr", name: "dicom-qr", displayName: "Query-Retrieve",
                              category: .networkOperations, sfSymbol: "arrow.up.arrow.down.circle",
                              briefDescription: "Combined query-retrieve workflow",
                              dicomStandardRef: "PS3.4", requiresNetwork: true,
                              networkToolGroup: .dimse),
            CLIToolDefinition(id: "dicom-mwl", name: "dicom-mwl", displayName: "Modality Worklist",
                              category: .networkOperations, sfSymbol: "list.clipboard",
                              briefDescription: "Query Modality Worklist for scheduled procedures",
                              dicomStandardRef: "PS3.4", requiresNetwork: true,
                              networkToolGroup: .dimse),
            CLIToolDefinition(id: "dicom-mpps", name: "dicom-mpps", displayName: "MPPS",
                              category: .networkOperations, sfSymbol: "clock.arrow.2.circlepath",
                              briefDescription: "Modality Performed Procedure Step management",
                              dicomStandardRef: "PS3.4", hasSubcommands: true, requiresNetwork: true,
                              networkToolGroup: .dimse),
            CLIToolDefinition(id: "dicom-qido", name: "dicom-wado query", displayName: "QIDO-RS Query",
                              category: .networkOperations, sfSymbol: "magnifyingglass.circle",
                              briefDescription: "Query DICOMweb servers with QIDO-RS",
                              dicomStandardRef: "PS3.18", requiresNetwork: true,
                              networkToolGroup: .dicomweb),
            CLIToolDefinition(id: "dicom-wado", name: "dicom-wado retrieve", displayName: "WADO-RS Retrieve",
                              category: .networkOperations, sfSymbol: "arrow.down.circle",
                              briefDescription: "Retrieve DICOM objects via WADO-RS or WADO-URI",
                              dicomStandardRef: "PS3.18", requiresNetwork: true,
                              networkToolGroup: .dicomweb),
            CLIToolDefinition(id: "dicom-stow", name: "dicom-wado store", displayName: "STOW-RS Store",
                              category: .networkOperations, sfSymbol: "arrow.up.circle",
                              briefDescription: "Upload DICOM files via STOW-RS",
                              dicomStandardRef: "PS3.18", requiresNetwork: true,
                              networkToolGroup: .dicomweb),
            CLIToolDefinition(id: "dicom-ups", name: "dicom-wado ups", displayName: "UPS-RS Worklist",
                              category: .networkOperations, sfSymbol: "list.bullet.clipboard",
                              briefDescription: "Manage Unified Procedure Steps via UPS-RS",
                              dicomStandardRef: "PS3.18", hasSubcommands: true, requiresNetwork: true,
                              networkToolGroup: .dicomweb),
        ]
    }

    /// Returns network operations tools grouped by DIMSE vs DICOMweb.
    public static func groupedNetworkOperationsTools() -> [(group: NetworkToolGroup, tools: [CLIToolDefinition])] {
        let tools = networkOperationsTools()
        return NetworkToolGroup.allCases.compactMap { group in
            let matching = tools.filter { $0.networkToolGroup == group }
            return matching.isEmpty ? nil : (group: group, tools: matching)
        }
    }

    /// Returns tools for the Automation tab.
    public static func automationTools() -> [CLIToolDefinition] {
        [
            CLIToolDefinition(id: "dicom-study", name: "dicom-study", displayName: "Study Tools",
                              category: .automation, sfSymbol: "folder.badge.person.crop",
                              briefDescription: "Study-level organize, summary, check, stats, compare",
                              hasSubcommands: true),
            CLIToolDefinition(id: "dicom-uid", name: "dicom-uid", displayName: "UID Tools",
                              category: .automation, sfSymbol: "number",
                              briefDescription: "Generate, validate, lookup, and regenerate UIDs",
                              hasSubcommands: true),
            CLIToolDefinition(id: "dicom-script", name: "dicom-script", displayName: "Scripting",
                              category: .automation, sfSymbol: "scroll",
                              briefDescription: "Run, validate, and template DICOM processing scripts",
                              hasSubcommands: true),
        ]
    }

    /// Returns tools filtered by the given tab category.
    public static func tools(for tab: CLIWorkshopTab) -> [CLIToolDefinition] {
        allTools().filter { $0.category == tab }
    }

    /// Returns the total count of tools.
    public static var totalToolCount: Int { 33 }

    // MARK: - Tool Purpose Descriptions

    /// Returns a rich multi-sentence purpose description for the given tool ID.
    /// Used in the CLI Workshop tool header panel.
    public static func toolPurposeDescription(for toolID: String) -> String {
        switch toolID {
        case "dicom-convert":
            return """
                dicom-convert re-encodes DICOM files into a different transfer syntax, \
                or exports their pixel data to a standard image format (PNG, JPEG, or TIFF). \
                It supports single-file and bulk-directory conversion. \
                For image export it can apply window/level values so output images are \
                correctly windowed — useful for CT, MR, and X-ray reading applications. \
                Conversions are handled natively using DICOMKit without any third-party dependencies.
                """
        case "dicom-info":
            return "Displays all DICOM tags, pixel statistics, and file metadata from a DICOM file or directory."
        case "dicom-dump":
            return "Prints a hex dump of a DICOM file annotated with tag names and VR information."
        case "dicom-validate":
            return "Checks a DICOM file for conformance against the matching IOD and returns a structured report."
        case "dicom-anon":
            return "Removes or replaces patient-identifying attributes according to PS3.15 anonymization profiles."
        case "dicom-compress":
            return "Compresses or decompresses DICOM pixel data using standard photometric and codec options."
        case "dicom-query":
            return "Queries a DICOM server using C-FIND to search for patients, studies, series, or instances."
        case "dicom-send":
            return "Sends DICOM files to a remote storage SCP using C-STORE."
        case "dicom-retrieve":
            return "Retrieves DICOM objects from a remote server using C-MOVE or C-GET."
        case "dicom-echo":
            return "Sends one or more C-ECHO requests to verify DICOM network connectivity and round-trip latency."
        default:
            return ""
        }
    }

    /// Returns short capability bullet points for the given tool ID.
    /// Each string is a terse label (no trailing punctuation).
    public static func toolCapabilities(for toolID: String) -> [String] {
        switch toolID {
        case "dicom-convert":
            return [
                "Transfer syntax re-encoding (PS3.5)",
                "Compressed encoding: JPEG, JPEG 2000, JPEG-LS, RLE",
                "Export to PNG, JPEG, TIFF",
                "Window / level adjustment on export",
                "Multi-frame: choose specific frame",
                "Batch directory conversion",
                "Strip private tags",
                "Post-conversion DICOM validation",
            ]
        default:
            return []
        }
    }

    /// Returns M16-style parameter definitions for a tool by ID.
    public static func parameterDefinitions(for toolID: String) -> [CLIParameterDefinition] {
        switch toolID {
        case "dicom-echo":
            return [
                CLIParameterDefinition(
                    id: "host", flag: "--host", displayName: "Host",
                    parameterType: .textField, placeholder: "hostname or IP address",
                    helpText: "PACS server hostname or IP address (optionally host:port)",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "port", flag: "--port", displayName: "Port",
                    parameterType: .integerField, placeholder: "11112",
                    helpText: "PACS server port (default: 11112)",
                    defaultValue: "11112", minValue: 1, maxValue: 65535
                ),
                CLIParameterDefinition(
                    id: "aet", flag: "--aet", displayName: "AE Title",
                    parameterType: .textField, placeholder: "DICOMSTUDIO",
                    helpText: "Local Application Entity title (calling AE)",
                    isRequired: true,
                    defaultValue: "DICOMSTUDIO"
                ),
                CLIParameterDefinition(
                    id: "called-aet", flag: "--called-aet", displayName: "Called AE Title",
                    parameterType: .textField, placeholder: "ANY-SCP",
                    helpText: "Remote server Application Entity title",
                    defaultValue: "ANY-SCP"
                ),
                CLIParameterDefinition(
                    id: "count", flag: "--count", displayName: "Echo Count",
                    parameterType: .integerField, placeholder: "1",
                    helpText: "Number of echo requests to send (default: 1)",
                    defaultValue: "1", minValue: 1, maxValue: 1000
                ),
                CLIParameterDefinition(
                    id: "timeout", flag: "--timeout", displayName: "Timeout (s)",
                    parameterType: .enumPicker, placeholder: "30",
                    helpText: "Connection timeout in seconds",
                    defaultValue: "30",
                    allowedValues: ["5", "10", "15", "30", "60", "120", "300"]
                ),
                CLIParameterDefinition(
                    id: "stats", flag: "--stats", displayName: "Show Statistics",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Show statistics (min/avg/max round-trip time)"
                ),
                CLIParameterDefinition(
                    id: "diagnose", flag: "--diagnose", displayName: "Network Diagnostics",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Run network diagnostics"
                ),
                CLIParameterDefinition(
                    id: "verbose", flag: "--verbose", displayName: "Verbose",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Show verbose output including connection details"
                ),
            ]
        case "dicom-query":
            return [
                CLIParameterDefinition(
                    id: "host", flag: "--host", displayName: "Host",
                    parameterType: .textField, placeholder: "hostname or IP address",
                    helpText: "PACS server hostname or IP address (optionally host:port)",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "port", flag: "--port", displayName: "Port",
                    parameterType: .integerField, placeholder: "11112",
                    helpText: "PACS server port (default: 11112)",
                    defaultValue: "11112", minValue: 1, maxValue: 65535
                ),
                CLIParameterDefinition(
                    id: "aet", flag: "--aet", displayName: "AE Title",
                    parameterType: .textField, placeholder: "DICOMSTUDIO",
                    helpText: "Local Application Entity title (calling AE)",
                    isRequired: true,
                    defaultValue: "DICOMSTUDIO"
                ),
                CLIParameterDefinition(
                    id: "called-aet", flag: "--called-aet", displayName: "Called AE Title",
                    parameterType: .textField, placeholder: "ANY-SCP",
                    helpText: "Remote server Application Entity title",
                    defaultValue: "ANY-SCP"
                ),
                CLIParameterDefinition(
                    id: "level", flag: "--level", displayName: "Query Level",
                    parameterType: .enumPicker, placeholder: "study",
                    helpText: "Query retrieve level (PS3.4 C.6)",
                    defaultValue: "study",
                    allowedValues: ["patient", "study", "series", "instance"]
                ),
                CLIParameterDefinition(
                    id: "patient-id", flag: "--patient-id", displayName: "Patient ID",
                    parameterType: .textField, placeholder: "e.g. PAT001",
                    helpText: "Patient ID to search for (0010,0020)"
                ),
                CLIParameterDefinition(
                    id: "patient-name", flag: "--patient-name", displayName: "Patient Name",
                    parameterType: .textField, placeholder: "e.g. DOE^JOHN or DOE*",
                    helpText: "Patient name to search for — supports wildcards * and ? (0010,0010)"
                ),
                CLIParameterDefinition(
                    id: "study-date", flag: "--study-date", displayName: "Study Date",
                    parameterType: .textField, placeholder: "e.g. 20260101 or 20260101-20260310",
                    helpText: "Study date or range in YYYYMMDD format (0008,0020)"
                ),
                CLIParameterDefinition(
                    id: "modality", flag: "--modality", displayName: "Modality",
                    parameterType: .enumPicker, placeholder: "Any",
                    helpText: "Imaging modality filter (0008,0060)",
                    allowedValues: ["", "CT", "MR", "US", "XA", "CR", "DX", "MG", "NM", "PT", "RF", "SC", "OT"]
                ),
                CLIParameterDefinition(
                    id: "study-uid", flag: "--study-uid", displayName: "Study Instance UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619...",
                    helpText: "Study Instance UID to filter by (0020,000D)"
                ),
                CLIParameterDefinition(
                    id: "series-uid", flag: "--series-uid", displayName: "Series Instance UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619...",
                    helpText: "Series Instance UID to filter by (0020,000E)"
                ),
                CLIParameterDefinition(
                    id: "accession-number", flag: "--accession-number", displayName: "Accession Number",
                    parameterType: .textField, placeholder: "e.g. ACC12345",
                    helpText: "Accession Number to filter by (0008,0050)"
                ),
                CLIParameterDefinition(
                    id: "study-description", flag: "--study-description", displayName: "Study Description",
                    parameterType: .textField, placeholder: "e.g. CHEST* or *ABDOMEN*",
                    helpText: "Study description filter — supports wildcards (0008,1030)",
                    isAdvanced: true
                ),
                CLIParameterDefinition(
                    id: "referring-physician", flag: "--referring-physician", displayName: "Referring Physician",
                    parameterType: .textField, placeholder: "e.g. SMITH^JANE",
                    helpText: "Referring physician name (0008,0090)",
                    isAdvanced: true
                ),
                CLIParameterDefinition(
                    id: "timeout", flag: "--timeout", displayName: "Timeout (s)",
                    parameterType: .enumPicker, placeholder: "60",
                    helpText: "Connection timeout in seconds",
                    defaultValue: "60",
                    allowedValues: ["5", "10", "15", "30", "60", "120", "300"]
                ),
                CLIParameterDefinition(
                    id: "output-format", flag: "--format", displayName: "Output Format",
                    parameterType: .enumPicker, placeholder: "table",
                    helpText: "Output format for query results",
                    defaultValue: "table",
                    allowedValues: ["table", "json", "csv", "compact"]
                ),
                CLIParameterDefinition(
                    id: "verbose", flag: "--verbose", displayName: "Verbose",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Show verbose output including query details"
                ),
            ]
        case "dicom-send":
            return [
                CLIParameterDefinition(
                    id: "host", flag: "--host", displayName: "Host",
                    parameterType: .textField, placeholder: "hostname or IP address",
                    helpText: "PACS server hostname or IP address (optionally host:port)",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "port", flag: "--port", displayName: "Port",
                    parameterType: .integerField, placeholder: "11112",
                    helpText: "PACS server port (default: 11112)",
                    defaultValue: "11112", minValue: 1, maxValue: 65535
                ),
                CLIParameterDefinition(
                    id: "aet", flag: "--aet", displayName: "AE Title",
                    parameterType: .textField, placeholder: "DICOMSTUDIO",
                    helpText: "Local Application Entity title (calling AE)",
                    isRequired: true,
                    defaultValue: "DICOMSTUDIO"
                ),
                CLIParameterDefinition(
                    id: "called-aet", flag: "--called-aet", displayName: "Called AE Title",
                    parameterType: .textField, placeholder: "ANY-SCP",
                    helpText: "Remote server Application Entity title",
                    defaultValue: "ANY-SCP"
                ),
                CLIParameterDefinition(
                    id: "files", flag: "", displayName: "DICOM Files",
                    parameterType: .filePath, placeholder: "Drag and drop DICOM files or directories",
                    helpText: "DICOM files or directories to send (C-STORE)",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "recursive", flag: "--recursive", displayName: "Recursive Scan",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Recursively scan directories for DICOM files",
                    defaultValue: "false"
                ),
                CLIParameterDefinition(
                    id: "verify", flag: "--verify", displayName: "Verify (C-ECHO)",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Verify connection with C-ECHO before sending"
                ),
                CLIParameterDefinition(
                    id: "priority", flag: "--priority", displayName: "Priority",
                    parameterType: .enumPicker, placeholder: "medium",
                    helpText: "DIMSE operation priority level",
                    defaultValue: "medium",
                    allowedValues: ["low", "medium", "high"]
                ),
                CLIParameterDefinition(
                    id: "retry", flag: "--retry", displayName: "Retry Attempts",
                    parameterType: .integerField, placeholder: "0",
                    helpText: "Number of retry attempts on failure (exponential backoff)",
                    isAdvanced: true,
                    defaultValue: "0", minValue: 0, maxValue: 10
                ),
                CLIParameterDefinition(
                    id: "timeout", flag: "--timeout", displayName: "Timeout (s)",
                    parameterType: .enumPicker, placeholder: "60",
                    helpText: "Connection timeout in seconds",
                    defaultValue: "60",
                    allowedValues: ["10", "30", "60", "120", "300"]
                ),
                CLIParameterDefinition(
                    id: "dry-run", flag: "--dry-run", displayName: "Dry Run",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Show what would be sent without actually sending",
                    isAdvanced: true
                ),
                CLIParameterDefinition(
                    id: "transfer-syntax", flag: "--transfer-syntax", displayName: "Transfer Syntax",
                    parameterType: .enumPicker, placeholder: "Any (negotiate)",
                    helpText: "Preferred transfer syntax proposed during C-STORE presentation context negotiation (PS3.8 §9.3.2)",
                    allowedValues: ["", "explicit-vr-le", "implicit-vr-le", "jpeg-baseline", "jpeg-lossless", "jpeg2000-lossless", "jpeg2000", "htj2k-lossless", "htj2k-rpcl", "htj2k", "rle-lossless", "deflate"]
                ),
                CLIParameterDefinition(
                    id: "verbose", flag: "--verbose", displayName: "Verbose",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Show verbose output including progress"
                ),
            ]
        case "dicom-retrieve":
            return [
                CLIParameterDefinition(
                    id: "host", flag: "--host", displayName: "Host",
                    parameterType: .textField, placeholder: "hostname or IP address",
                    helpText: "PACS server hostname or IP address (optionally host:port)",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "port", flag: "--port", displayName: "Port",
                    parameterType: .integerField, placeholder: "11112",
                    helpText: "PACS server port (default: 11112)",
                    defaultValue: "11112", minValue: 1, maxValue: 65535
                ),
                CLIParameterDefinition(
                    id: "aet", flag: "--aet", displayName: "AE Title",
                    parameterType: .textField, placeholder: "DICOMSTUDIO",
                    helpText: "Local Application Entity title (calling AE)",
                    isRequired: true,
                    defaultValue: "DICOMSTUDIO"
                ),
                CLIParameterDefinition(
                    id: "called-aet", flag: "--called-aet", displayName: "Called AE Title",
                    parameterType: .textField, placeholder: "ANY-SCP",
                    helpText: "Remote server Application Entity title",
                    defaultValue: "ANY-SCP"
                ),
                CLIParameterDefinition(
                    id: "method", flag: "--method", displayName: "Retrieval Method",
                    parameterType: .enumPicker, placeholder: "c-move",
                    helpText: "C-MOVE instructs the server to push files to a destination; C-GET pulls directly",
                    defaultValue: "c-move",
                    allowedValues: ["c-move", "c-get"]
                ),
                CLIParameterDefinition(
                    id: "move-dest", flag: "--move-dest", displayName: "Move Destination AET",
                    parameterType: .textField, placeholder: "e.g. MY_STORE_SCP",
                    helpText: "Destination AE title to receive files (required for C-MOVE)"
                ),
                CLIParameterDefinition(
                    id: "study-uid", flag: "--study-uid", displayName: "Study Instance UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619...",
                    helpText: "Study Instance UID to retrieve (0020,000D)"
                ),
                CLIParameterDefinition(
                    id: "series-uid", flag: "--series-uid", displayName: "Series Instance UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619...",
                    helpText: "Series Instance UID for series-level retrieval (0020,000E)"
                ),
                CLIParameterDefinition(
                    id: "instance-uid", flag: "--instance-uid", displayName: "SOP Instance UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619...",
                    helpText: "SOP Instance UID for instance-level retrieval (0008,0018)",
                    isAdvanced: true
                ),
                CLIParameterDefinition(
                    id: "uid-list", flag: "--uid-list", displayName: "UID List File",
                    parameterType: .filePath, placeholder: "e.g. study_uids.txt",
                    helpText: "File containing list of Study UIDs to retrieve (one per line)",
                    isAdvanced: true
                ),
                CLIParameterDefinition(
                    id: "output", flag: "--output", displayName: "Output Directory",
                    parameterType: .outputPath, placeholder: "e.g. ~/Downloads/studies",
                    helpText: "Directory where retrieved files will be saved",
                    defaultValue: "."
                ),
                CLIParameterDefinition(
                    id: "hierarchical", flag: "--hierarchical", displayName: "Hierarchical Output",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Organize output as Patient/Study/Series directory tree"
                ),
                CLIParameterDefinition(
                    id: "parallel", flag: "--parallel", displayName: "Parallel Operations",
                    parameterType: .integerField, placeholder: "1",
                    helpText: "Number of concurrent retrieval operations",
                    isAdvanced: true,
                    defaultValue: "1", minValue: 1, maxValue: 8
                ),
                CLIParameterDefinition(
                    id: "timeout", flag: "--timeout", displayName: "Timeout (s)",
                    parameterType: .enumPicker, placeholder: "60",
                    helpText: "Connection timeout in seconds",
                    defaultValue: "60",
                    allowedValues: ["10", "30", "60", "120", "300"]
                ),
                CLIParameterDefinition(
                    id: "transfer-syntax", flag: "--transfer-syntax", displayName: "Transfer Syntax",
                    parameterType: .enumPicker, placeholder: "Any (negotiate)",
                    helpText: "Requested transfer syntax for retrieved files — negotiated during association setup (PS3.8 §9.3.2)",
                    allowedValues: ["", "explicit-vr-le", "implicit-vr-le", "jpeg-baseline", "jpeg-lossless", "jpeg2000-lossless", "jpeg2000", "rle-lossless"]
                ),
                CLIParameterDefinition(
                    id: "verbose", flag: "--verbose", displayName: "Verbose",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Show verbose output including progress"
                ),
            ]
        case "dicom-qr":
            return [
                CLIParameterDefinition(
                    id: "host", flag: "--host", displayName: "Host",
                    parameterType: .textField, placeholder: "hostname or IP address",
                    helpText: "PACS server hostname or IP address (optionally host:port)",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "port", flag: "--port", displayName: "Port",
                    parameterType: .integerField, placeholder: "11112",
                    helpText: "PACS server port (default: 11112)",
                    defaultValue: "11112", minValue: 1, maxValue: 65535
                ),
                CLIParameterDefinition(
                    id: "aet", flag: "--aet", displayName: "AE Title",
                    parameterType: .textField, placeholder: "DICOMSTUDIO",
                    helpText: "Local Application Entity title (calling AE)",
                    isRequired: true,
                    defaultValue: "DICOMSTUDIO"
                ),
                CLIParameterDefinition(
                    id: "called-aet", flag: "--called-aet", displayName: "Called AE Title",
                    parameterType: .textField, placeholder: "ANY-SCP",
                    helpText: "Remote server Application Entity title",
                    defaultValue: "ANY-SCP"
                ),
                CLIParameterDefinition(
                    id: "mode", flag: "", displayName: "Operation Mode",
                    parameterType: .flagPicker, placeholder: "interactive",
                    helpText: "Interactive: select studies; Auto: retrieve all matches; Review: query only",
                    defaultValue: "interactive",
                    allowedValues: ["interactive", "auto", "review"]
                ),
                CLIParameterDefinition(
                    id: "method", flag: "--method", displayName: "Retrieval Method",
                    parameterType: .enumPicker, placeholder: "c-move",
                    helpText: "C-MOVE instructs the server to push files; C-GET pulls directly",
                    defaultValue: "c-move",
                    allowedValues: ["c-move", "c-get"]
                ),
                CLIParameterDefinition(
                    id: "move-dest", flag: "--move-dest", displayName: "Move Destination AET",
                    parameterType: .textField, placeholder: "e.g. MY_STORE_SCP",
                    helpText: "Destination AE title to receive files (required for C-MOVE)"
                ),
                CLIParameterDefinition(
                    id: "patient-name", flag: "--patient-name", displayName: "Patient Name",
                    parameterType: .textField, placeholder: "e.g. DOE^JOHN or DOE*",
                    helpText: "Patient name filter — supports wildcards * and ? (0010,0010)"
                ),
                CLIParameterDefinition(
                    id: "patient-id", flag: "--patient-id", displayName: "Patient ID",
                    parameterType: .textField, placeholder: "e.g. PAT001",
                    helpText: "Patient ID to search for (0010,0020)"
                ),
                CLIParameterDefinition(
                    id: "study-date", flag: "--study-date", displayName: "Study Date",
                    parameterType: .textField, placeholder: "e.g. 20260101 or 20260101-20260310",
                    helpText: "Study date or range in YYYYMMDD format (0008,0020)"
                ),
                CLIParameterDefinition(
                    id: "modality", flag: "--modality", displayName: "Modality",
                    parameterType: .enumPicker, placeholder: "Any",
                    helpText: "Imaging modality filter (0008,0060)",
                    allowedValues: ["", "CT", "MR", "US", "XA", "CR", "DX", "MG", "NM", "PT", "RF", "SC", "OT"]
                ),
                CLIParameterDefinition(
                    id: "study-uid", flag: "--study-uid", displayName: "Study Instance UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619...",
                    helpText: "Study Instance UID to filter by (0020,000D)",
                    isAdvanced: true
                ),
                CLIParameterDefinition(
                    id: "study-description", flag: "--study-description", displayName: "Study Description",
                    parameterType: .textField, placeholder: "e.g. CHEST* or *ABDOMEN*",
                    helpText: "Study description filter — supports wildcards (0008,1030)",
                    isAdvanced: true
                ),
                CLIParameterDefinition(
                    id: "output", flag: "--output", displayName: "Output Directory",
                    parameterType: .outputPath, placeholder: "e.g. ~/Downloads/studies",
                    helpText: "Directory where retrieved files will be saved",
                    defaultValue: "."
                ),
                CLIParameterDefinition(
                    id: "hierarchical", flag: "--hierarchical", displayName: "Hierarchical Output",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Organize output as Patient/Study/Series directory tree"
                ),
                CLIParameterDefinition(
                    id: "validate", flag: "--validate", displayName: "Validate Files",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Validate retrieved files after download",
                    isAdvanced: true
                ),
                CLIParameterDefinition(
                    id: "parallel", flag: "--parallel", displayName: "Parallel Operations",
                    parameterType: .integerField, placeholder: "1",
                    helpText: "Maximum concurrent retrieval operations",
                    isAdvanced: true,
                    defaultValue: "1", minValue: 1, maxValue: 8
                ),
                CLIParameterDefinition(
                    id: "timeout", flag: "--timeout", displayName: "Timeout (s)",
                    parameterType: .enumPicker, placeholder: "60",
                    helpText: "Connection timeout in seconds",
                    defaultValue: "60",
                    allowedValues: ["10", "30", "60", "120", "300"]
                ),
                CLIParameterDefinition(
                    id: "transfer-syntax", flag: "--transfer-syntax", displayName: "Transfer Syntax",
                    parameterType: .enumPicker, placeholder: "Any (negotiate)",
                    helpText: "Requested transfer syntax for retrieved files — negotiated during association setup (PS3.8 §9.3.2)",
                    allowedValues: ["", "explicit-vr-le", "implicit-vr-le", "jpeg-baseline", "jpeg-lossless", "jpeg2000-lossless", "jpeg2000", "rle-lossless"]
                ),
            ]
        case "dicom-mwl":
            return [
                CLIParameterDefinition(
                    id: "operation", flag: "", displayName: "Operation",
                    parameterType: .subcommand, placeholder: "query",
                    helpText: "Modality Worklist operation: query scheduled procedures (C-FIND) or create a new worklist item (N-CREATE)",
                    isRequired: true,
                    defaultValue: "query",
                    allowedValues: ["query", "create"]
                ),
                CLIParameterDefinition(
                    id: "host", flag: "--host", displayName: "Host",
                    parameterType: .textField, placeholder: "hostname or IP address",
                    helpText: "Worklist SCP hostname or IP address (optionally host:port) (PS3.4 Annex K)",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "port", flag: "--port", displayName: "Port",
                    parameterType: .integerField, placeholder: "11112",
                    helpText: "PACS server port (default: 11112)",
                    defaultValue: "11112", minValue: 1, maxValue: 65535
                ),
                CLIParameterDefinition(
                    id: "aet", flag: "--aet", displayName: "AE Title",
                    parameterType: .textField, placeholder: "MODALITY",
                    helpText: "Local AE title identifying this modality (up to 16 characters)",
                    isRequired: true,
                    defaultValue: "DICOMSTUDIO"
                ),
                CLIParameterDefinition(
                    id: "called-aet", flag: "--called-aet", displayName: "Called AE Title",
                    parameterType: .textField, placeholder: "ANY-SCP",
                    helpText: "Remote Worklist SCP Application Entity title",
                    defaultValue: "ANY-SCP"
                ),
                // ----- Query parameters (C-FIND) -----
                CLIParameterDefinition(
                    id: "date-from", flag: "--date", displayName: "Date",
                    parameterType: .textField, placeholder: "today / YYYYMMDD",
                    helpText: "Scheduled date filter — use 'today', 'tomorrow', or YYYYMMDD format (0040,0002)",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["query"])
                ),
                CLIParameterDefinition(
                    id: "date-to", flag: "--date-to", displayName: "Date To",
                    parameterType: .textField, placeholder: "tomorrow / YYYYMMDD",
                    helpText: "End of scheduled date range (inclusive) — used by DICOMStudio's internal execution only",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["query"])
                ),
                CLIParameterDefinition(
                    id: "station", flag: "--station", displayName: "Station AE Title",
                    parameterType: .textField, placeholder: "e.g. CT1",
                    helpText: "Filter by Scheduled Station AE Title (0040,0001)",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["query"])
                ),
                CLIParameterDefinition(
                    id: "patient", flag: "--patient", displayName: "Patient Name",
                    parameterType: .textField, placeholder: "e.g. DOE^JOHN or DOE*",
                    helpText: "Filter by patient name — supports wildcards * and ? (0010,0010)",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["query"])
                ),
                CLIParameterDefinition(
                    id: "patient-id", flag: "--patient-id", displayName: "Patient ID",
                    parameterType: .textField, placeholder: "e.g. PAT001",
                    helpText: "Filter by patient ID (0010,0020)",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["query"])
                ),
                CLIParameterDefinition(
                    id: "modality", flag: "--modality", displayName: "Modality",
                    parameterType: .enumPicker, placeholder: "Any",
                    helpText: "Filter by scheduled imaging modality (0040,0001)",
                    allowedValues: ["", "CT", "MR", "US", "XA", "CR", "DX", "MG", "NM", "PT", "RF", "SC", "OT"],
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["query"])
                ),
                CLIParameterDefinition(
                    id: "sps-status", flag: "--sps-status", displayName: "SPS Status",
                    parameterType: .enumPicker, placeholder: "Any",
                    helpText: "Filter by Scheduled Procedure Step Status (0040,0004)",
                    allowedValues: ["", "SCHEDULED", "IN PROGRESS", "DISCONTINUED", "COMPLETED"],
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["query"])
                ),
                CLIParameterDefinition(
                    id: "query-accession-number", flag: "--accession-number", displayName: "Accession Number",
                    parameterType: .textField, placeholder: "e.g. ACC12345",
                    helpText: "Filter by accession number (0008,0050)",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["query"])
                ),
                // ----- Create parameters (DICOMStudio-internal, no CLI equivalent) -----
                // Note: `dicom-mwl` CLI only supports the `query` subcommand.
                // MWL item creation is performed by DICOMStudio via HL7 ORM^O01
                // or REST API — these parameters drive the internal execution
                // but are excluded from the command preview (`isInternal: true`).
                CLIParameterDefinition(
                    id: "create-method", flag: "", displayName: "Create Method",
                    parameterType: .enumPicker, placeholder: "hl7",
                    helpText: "How to create the worklist item. HL7 (recommended): sends an ORM^O01 order message via MLLP — automatically creates the patient and worklist. REST: posts DICOM JSON to the server's REST API (requires the patient to exist first).",
                    isInternal: true,
                    defaultValue: "hl7",
                    allowedValues: ["hl7", "rest"],
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "hl7-port", flag: "--hl7-port", displayName: "HL7 Port",
                    parameterType: .integerField, placeholder: "2575",
                    helpText: "HL7 MLLP listener port on the server (default: 2575 for dcm4chee-arc)",
                    isInternal: true,
                    defaultValue: "2575", minValue: 1, maxValue: 65535,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "create-method", values: ["hl7"])
                ),
                CLIParameterDefinition(
                    id: "create-patient-name", flag: "--patient-name", displayName: "Patient Name",
                    parameterType: .textField, placeholder: "e.g. DOE^JOHN",
                    helpText: "Patient's Name (0010,0010) — required for worklist creation",
                    isRequired: true,
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "create-patient-id", flag: "--patient-id", displayName: "Patient ID",
                    parameterType: .textField, placeholder: "e.g. PAT001",
                    helpText: "Patient ID (0010,0020) — required for worklist creation",
                    isRequired: true,
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "patient-dob", flag: "--patient-dob", displayName: "Patient Birth Date",
                    parameterType: .textField, placeholder: "YYYYMMDD",
                    helpText: "Patient's Birth Date (0010,0030) in YYYYMMDD format",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "patient-sex", flag: "--patient-sex", displayName: "Patient Sex",
                    parameterType: .enumPicker, placeholder: "Unknown",
                    helpText: "Patient's Sex (0010,0040)",
                    isInternal: true,
                    allowedValues: ["", "M", "F", "O"],
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "accession-number", flag: "--accession-number", displayName: "Accession Number",
                    parameterType: .textField, placeholder: "e.g. ACC12345",
                    helpText: "Accession Number (0008,0050) — links worklist item to the imaging order",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "referring-physician", flag: "--referring-physician", displayName: "Referring Physician",
                    parameterType: .textField, placeholder: "e.g. SMITH^JANE",
                    helpText: "Referring Physician's Name (0008,0090)",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "procedure-id", flag: "--procedure-id", displayName: "Requested Procedure ID",
                    parameterType: .textField, placeholder: "e.g. PROC001",
                    helpText: "Requested Procedure ID (0040,1001)",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "procedure-desc", flag: "--procedure-desc", displayName: "Procedure Description",
                    parameterType: .textField, placeholder: "e.g. CT Head Without Contrast",
                    helpText: "Requested Procedure Description (0032,1070)",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "create-modality", flag: "--modality", displayName: "Modality",
                    parameterType: .enumPicker, placeholder: "CT",
                    helpText: "Scheduled modality for the procedure step (0008,0060)",
                    isInternal: true,
                    defaultValue: "CT",
                    allowedValues: ["CT", "MR", "US", "XA", "CR", "DX", "MG", "NM", "PT", "RF", "SC", "OT"],
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "scheduled-station", flag: "--scheduled-station", displayName: "Scheduled Station AET",
                    parameterType: .textField, placeholder: "e.g. CT1",
                    helpText: "Scheduled Station AE Title (0040,0001) — the modality that will perform the procedure",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "station-name", flag: "--station-name", displayName: "Station Name",
                    parameterType: .textField, placeholder: "e.g. CT_SCANNER_1",
                    helpText: "Scheduled Station Name (0040,0010)",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "scheduled-date", flag: "--scheduled-date", displayName: "Scheduled Date",
                    parameterType: .textField, placeholder: "YYYYMMDD or today",
                    helpText: "Scheduled Procedure Step Start Date (0040,0002) — defaults to today",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "scheduled-time", flag: "--scheduled-time", displayName: "Scheduled Time",
                    parameterType: .textField, placeholder: "HHMMSS e.g. 143000",
                    helpText: "Scheduled Procedure Step Start Time (0040,0003)",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "sps-id", flag: "--sps-id", displayName: "Procedure Step ID",
                    parameterType: .textField, placeholder: "e.g. SPS001",
                    helpText: "Scheduled Procedure Step ID (0040,0009) — defaults to SPS001",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "sps-desc", flag: "--sps-desc", displayName: "Step Description",
                    parameterType: .textField, placeholder: "e.g. CT Head Scan",
                    helpText: "Scheduled Procedure Step Description (0040,0007)",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "performing-physician", flag: "--physician", displayName: "Performing Physician",
                    parameterType: .textField, placeholder: "e.g. JONES^ALICE",
                    helpText: "Scheduled Performing Physician's Name (0040,0006)",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "rest-base-url", flag: "--rest-url", displayName: "REST Base URL",
                    parameterType: .textField, placeholder: "e.g. http://host:8080/dcm4chee-arc",
                    helpText: "REST base URL for MWL item creation. MWL creation uses the server's REST API (not DIMSE). Default: http://<host>:8080/dcm4chee-arc",
                    isAdvanced: true,
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "create-method", values: ["rest"])
                ),
                CLIParameterDefinition(
                    id: "sending-application", flag: "--sending-app", displayName: "Sending Application",
                    parameterType: .textField, placeholder: "DICOMSTUDIO",
                    helpText: "HL7 MSH-3 Sending Application name (default: DICOMSTUDIO)",
                    isAdvanced: true,
                    isInternal: true,
                    defaultValue: "DICOMSTUDIO",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "create-method", values: ["hl7"])
                ),
                CLIParameterDefinition(
                    id: "sending-facility", flag: "--sending-facility", displayName: "Sending Facility",
                    parameterType: .textField, placeholder: "IMAGING",
                    helpText: "HL7 MSH-4 Sending Facility name (default: IMAGING)",
                    isAdvanced: true,
                    isInternal: true,
                    defaultValue: "IMAGING",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "create-method", values: ["hl7"])
                ),
                CLIParameterDefinition(
                    id: "receiving-application", flag: "--receiving-app", displayName: "Receiving Application",
                    parameterType: .textField, placeholder: "DCM4CHEE",
                    helpText: "HL7 MSH-5 Receiving Application name (default: DCM4CHEE)",
                    isAdvanced: true,
                    isInternal: true,
                    defaultValue: "DCM4CHEE",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "create-method", values: ["hl7"])
                ),
                CLIParameterDefinition(
                    id: "receiving-facility", flag: "--receiving-facility", displayName: "Receiving Facility",
                    parameterType: .textField, placeholder: "HOSPITAL",
                    helpText: "HL7 MSH-6 Receiving Facility name (default: HOSPITAL)",
                    isAdvanced: true,
                    isInternal: true,
                    defaultValue: "HOSPITAL",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "create-method", values: ["hl7"])
                ),
                // ----- Common parameters -----
                CLIParameterDefinition(
                    id: "timeout", flag: "--timeout", displayName: "Timeout (s)",
                    parameterType: .enumPicker, placeholder: "60",
                    helpText: "Connection timeout in seconds",
                    defaultValue: "60",
                    allowedValues: ["5", "10", "15", "30", "60", "120", "300"]
                ),
                CLIParameterDefinition(
                    id: "json", flag: "--json", displayName: "JSON Output",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Output results in JSON format"
                ),
                CLIParameterDefinition(
                    id: "verbose", flag: "--verbose", displayName: "Verbose",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Show detailed connection and query information"
                ),
            ]
        case "dicom-mpps":
            return [
                CLIParameterDefinition(
                    id: "operation", flag: "", displayName: "Operation",
                    parameterType: .subcommand, placeholder: "create",
                    helpText: "MPPS operation: create a new procedure step (N-CREATE) or update an existing one (N-SET)",
                    isRequired: true,
                    defaultValue: "create",
                    allowedValues: ["create", "update"]
                ),
                CLIParameterDefinition(
                    id: "host", flag: "--host", displayName: "Host",
                    parameterType: .textField, placeholder: "hostname or IP address",
                    helpText: "MPPS SCP hostname or IP address (optionally host:port) (PS3.4 Annex F)",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "port", flag: "--port", displayName: "Port",
                    parameterType: .integerField, placeholder: "11112",
                    helpText: "PACS server port (default: 11112)",
                    defaultValue: "11112", minValue: 1, maxValue: 65535
                ),
                CLIParameterDefinition(
                    id: "aet", flag: "--aet", displayName: "AE Title",
                    parameterType: .textField, placeholder: "MODALITY",
                    helpText: "Local AE title identifying the modality sending MPPS notifications",
                    isRequired: true,
                    defaultValue: "DICOMSTUDIO"
                ),
                CLIParameterDefinition(
                    id: "called-aet", flag: "--called-aet", displayName: "Called AE Title",
                    parameterType: .textField, placeholder: "ANY-SCP",
                    helpText: "Remote MPPS SCP Application Entity title",
                    defaultValue: "ANY-SCP"
                ),
                // ----- N-CREATE parameters (PS3.4 Table F.7.2-1) -----
                CLIParameterDefinition(
                    id: "patient-name", flag: "--patient-name", displayName: "Patient Name",
                    parameterType: .textField, placeholder: "e.g. DOE^JOHN",
                    helpText: "Patient's Name (0010,0010) — included in the N-CREATE dataset sent to the PACS",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "patient-id", flag: "--patient-id", displayName: "Patient ID",
                    parameterType: .textField, placeholder: "e.g. PAT001",
                    helpText: "Patient ID (0010,0020) — included in the N-CREATE dataset sent to the PACS",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "study-uid", flag: "--study-uid", displayName: "Study Instance UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619...",
                    helpText: "Study Instance UID for the procedure step (0020,000D) — required for N-CREATE",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "sps-id", flag: "--sps-id", displayName: "Scheduled Procedure Step ID",
                    parameterType: .textField, placeholder: "e.g. SPS001",
                    helpText: "Scheduled Procedure Step ID (0040,0009) from the MWL item — links this MPPS to the worklist entry so the server transitions the MWL status from SCHEDULED to IN PROGRESS",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "modality", flag: "--modality", displayName: "Modality",
                    parameterType: .enumPicker, placeholder: "CT",
                    helpText: "Modality being performed (0008,0060) — sent via DICOMStudio internal execution",
                    isInternal: true,
                    defaultValue: "CT",
                    allowedValues: ["CT", "MR", "US", "XA", "CR", "DX", "MG", "NM", "PT", "RF", "SC", "OT"],
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "procedure-id", flag: "--procedure-id", displayName: "Procedure Step ID",
                    parameterType: .textField, placeholder: "e.g. SPS001",
                    helpText: "Performed Procedure Step ID (0040,0253) — sent via DICOMStudio internal execution",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "procedure-desc", flag: "--procedure-desc", displayName: "Procedure Description",
                    parameterType: .textField, placeholder: "e.g. CT Head Without Contrast",
                    helpText: "Performed Procedure Step Description (0040,0254) — sent via DICOMStudio internal execution",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "accession-number", flag: "--accession-number", displayName: "Accession Number",
                    parameterType: .textField, placeholder: "e.g. ACC12345",
                    helpText: "Accession Number (0008,0050) — links the MPPS to the imaging order and helps the server match the MWL item",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "performing-physician", flag: "--physician", displayName: "Performing Physician",
                    parameterType: .textField, placeholder: "e.g. SMITH^JANE",
                    helpText: "Name of performing physician (0008,1050) — sent via DICOMStudio internal execution",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                CLIParameterDefinition(
                    id: "station-name", flag: "--station-name", displayName: "Station Name",
                    parameterType: .textField, placeholder: "e.g. CT_SCANNER_1",
                    helpText: "Performing Station Name (0008,1010) — sent via DICOMStudio internal execution",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create"])
                ),
                // ----- N-SET parameters -----
                CLIParameterDefinition(
                    id: "mpps-uid", flag: "--mpps-uid", displayName: "MPPS Instance UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619...",
                    helpText: "MPPS SOP Instance UID from a previous create — required for update (N-SET)",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["update"])
                ),
                CLIParameterDefinition(
                    id: "status", flag: "--status", displayName: "Status",
                    parameterType: .enumPicker, placeholder: "IN PROGRESS",
                    helpText: "Performed Procedure Step Status (0040,0252) — IN PROGRESS for create; COMPLETED or DISCONTINUED for update",
                    defaultValue: "IN PROGRESS",
                    allowedValues: ["IN PROGRESS", "COMPLETED", "DISCONTINUED"]
                ),
                CLIParameterDefinition(
                    id: "series-uid", flag: "--series-uid", displayName: "Series Instance UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619...",
                    helpText: "Series Instance UID of the acquired images — used in N-SET for Performed Series Sequence (0008,1115)",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["update"])
                ),
                CLIParameterDefinition(
                    id: "image-uids", flag: "--image-uids", displayName: "Image SOP Instance UIDs",
                    parameterType: .textField, placeholder: "UID1,UID2,...",
                    helpText: "Comma-separated SOP Instance UIDs of acquired images — sent via DICOMStudio internal execution (CLI uses --image-uid, repeatable)",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["update"])
                ),
                CLIParameterDefinition(
                    id: "discontinue-reason", flag: "--discontinue-reason", displayName: "Discontinuation Reason",
                    parameterType: .textField, placeholder: "e.g. Patient refused",
                    helpText: "Reason for discontinuation (0040,0281) — sent via DICOMStudio internal execution",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["update"])
                ),
                CLIParameterDefinition(
                    id: "timeout", flag: "--timeout", displayName: "Timeout (s)",
                    parameterType: .enumPicker, placeholder: "60",
                    helpText: "Connection timeout in seconds",
                    defaultValue: "60",
                    allowedValues: ["5", "10", "15", "30", "60", "120", "300"]
                ),
                CLIParameterDefinition(
                    id: "verbose", flag: "--verbose", displayName: "Verbose",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Show detailed connection and operation information"
                ),
            ]
        case "dicom-qido":
            return [
                CLIParameterDefinition(
                    id: "url", flag: "", displayName: "Base URL",
                    parameterType: .textField, placeholder: "e.g. https://pacs.hospital.com/dicom-web",
                    helpText: "DICOMweb server base URL (PS3.18 §6.5)",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "level", flag: "--level", displayName: "Query Level",
                    parameterType: .enumPicker, placeholder: "study",
                    helpText: "QIDO-RS query level — determines which resource is searched (PS3.18 §10.6)",
                    defaultValue: "study",
                    allowedValues: ["study", "series", "instance"]
                ),
                CLIParameterDefinition(
                    id: "patient-name", flag: "--patient-name", displayName: "Patient Name",
                    parameterType: .textField, placeholder: "e.g. DOE^JOHN or DOE*",
                    helpText: "Patient name filter — supports wildcards * and ? (0010,0010)"
                ),
                CLIParameterDefinition(
                    id: "patient-id", flag: "--patient-id", displayName: "Patient ID",
                    parameterType: .textField, placeholder: "e.g. PAT001",
                    helpText: "Patient ID to search for (0010,0020)"
                ),
                CLIParameterDefinition(
                    id: "study-date", flag: "--study-date", displayName: "Study Date",
                    parameterType: .textField, placeholder: "e.g. 20260101 or 20260101-20260310",
                    helpText: "Study date or range in YYYYMMDD format (0008,0020)"
                ),
                CLIParameterDefinition(
                    id: "modality", flag: "--modality", displayName: "Modality",
                    parameterType: .enumPicker, placeholder: "Any",
                    helpText: "Modalities in Study filter (0008,0061)",
                    allowedValues: ["", "CT", "MR", "US", "XA", "CR", "DX", "MG", "NM", "PT", "RF", "SC", "OT"]
                ),
                CLIParameterDefinition(
                    id: "study-uid", flag: "--study", displayName: "Study Instance UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619...",
                    helpText: "Study Instance UID to filter results (0020,000D)"
                ),
                CLIParameterDefinition(
                    id: "study-description", flag: "--study-description", displayName: "Study Description",
                    parameterType: .textField, placeholder: "e.g. Chest CT or CHEST*",
                    helpText: "Study description filter — supports wildcards (0008,1030)",
                    isAdvanced: true
                ),
                CLIParameterDefinition(
                    id: "limit", flag: "--limit", displayName: "Result Limit",
                    parameterType: .integerField, placeholder: "100",
                    helpText: "Maximum number of results to return",
                    defaultValue: "100", minValue: 1, maxValue: 10000
                ),
                CLIParameterDefinition(
                    id: "offset", flag: "--offset", displayName: "Offset",
                    parameterType: .integerField, placeholder: "0",
                    helpText: "Number of results to skip for pagination",
                    isAdvanced: true, defaultValue: "0", minValue: 0, maxValue: 100000
                ),
                CLIParameterDefinition(
                    id: "auth", flag: "--auth", displayName: "Authentication",
                    parameterType: .enumPicker, placeholder: "none",
                    helpText: "Authentication method for the DICOMweb server",
                    isInternal: true,
                    defaultValue: "none",
                    allowedValues: ["none", "basic", "bearer"]
                ),
                CLIParameterDefinition(
                    id: "token", flag: "--token", displayName: "Token / Password",
                    parameterType: .secureField, placeholder: "Bearer token or password",
                    helpText: "Authentication token (bearer) or password (basic auth)",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "auth", values: ["basic", "bearer"])
                ),
                CLIParameterDefinition(
                    id: "username", flag: "--username", displayName: "Username",
                    parameterType: .textField, placeholder: "e.g. admin",
                    helpText: "Username for basic authentication",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "auth", values: ["basic"])
                ),
                CLIParameterDefinition(
                    id: "output-format", flag: "--format", displayName: "Output Format",
                    parameterType: .enumPicker, placeholder: "table",
                    helpText: "Output format for query results",
                    defaultValue: "table",
                    allowedValues: ["table", "json", "csv"]
                ),
                CLIParameterDefinition(
                    id: "timeout", flag: "--timeout", displayName: "Timeout (s)",
                    parameterType: .enumPicker, placeholder: "30",
                    helpText: "HTTP request timeout in seconds",
                    isInternal: true,
                    defaultValue: "30",
                    allowedValues: ["5", "10", "15", "30", "60", "120", "300"]
                ),
            ]
        case "dicom-wado":
            return [
                CLIParameterDefinition(
                    id: "wado-protocol", flag: "", displayName: "Protocol",
                    parameterType: .enumPicker, placeholder: "wado-rs",
                    helpText: "WADO-RS (modern RESTful) or WADO-URI (legacy query-parameter)",
                    isInternal: true,
                    defaultValue: "wado-rs",
                    allowedValues: ["wado-rs", "wado-uri"],
                    cliMapping: ["wado-uri": "--uri"]
                ),
                CLIParameterDefinition(
                    id: "url", flag: "", displayName: "Base URL",
                    parameterType: .textField, placeholder: "e.g. https://pacs.hospital.com/dicom-web",
                    helpText: "DICOMweb server base URL (PS3.18 §6.5)",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "study-uid", flag: "--study", displayName: "Study Instance UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619...",
                    helpText: "Study Instance UID to retrieve (0020,000D)",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "series-uid", flag: "--series", displayName: "Series Instance UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619...",
                    helpText: "Series Instance UID (0020,000E). Required for WADO-URI and series/instance retrieval."
                ),
                CLIParameterDefinition(
                    id: "instance-uid", flag: "--instance", displayName: "SOP Instance UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619...",
                    helpText: "SOP Instance UID (0008,0018). Required for WADO-URI and instance/rendered retrieval."
                ),
                CLIParameterDefinition(
                    id: "frames", flag: "--frames", displayName: "Frame Numbers",
                    parameterType: .textField, placeholder: "e.g. 1,2,3",
                    helpText: "Frame numbers to retrieve (comma-separated, 1-based). Requires --series and --instance.",
                    isAdvanced: true
                ),
                CLIParameterDefinition(
                    id: "metadata", flag: "--metadata", displayName: "Metadata Only",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Retrieve only metadata (not pixel data)",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "wado-protocol", values: ["wado-rs"])
                ),
                CLIParameterDefinition(
                    id: "rendered", flag: "--rendered", displayName: "Rendered Image",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Retrieve rendered image instead of DICOM. Requires --series and --instance.",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "wado-protocol", values: ["wado-rs"])
                ),
                CLIParameterDefinition(
                    id: "thumbnail", flag: "--thumbnail", displayName: "Thumbnail",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Retrieve thumbnail images",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "wado-protocol", values: ["wado-rs"])
                ),
                CLIParameterDefinition(
                    id: "content-type", flag: "", displayName: "Content Type",
                    parameterType: .enumPicker, placeholder: "application/dicom",
                    helpText: "Requested content type for WADO-URI response",
                    isInternal: true,
                    defaultValue: "application/dicom",
                    allowedValues: ["application/dicom", "image/jpeg", "image/png", "image/gif"],
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "wado-protocol", values: ["wado-uri"]),
                    cliMapping: [
                        "image/jpeg": "--content-type image/jpeg",
                        "image/png": "--content-type image/png",
                        "image/gif": "--content-type image/gif",
                    ]
                ),
                CLIParameterDefinition(
                    id: "output", flag: "-o", displayName: "Output Directory",
                    parameterType: .outputPath, placeholder: "e.g. ~/Downloads/studies",
                    helpText: "Directory where retrieved files will be saved"
                ),
                CLIParameterDefinition(
                    id: "format", flag: "--format", displayName: "Metadata Format",
                    parameterType: .enumPicker, placeholder: "json",
                    helpText: "Output format for metadata: json or xml",
                    defaultValue: "json",
                    allowedValues: ["json", "xml"],
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "wado-protocol", values: ["wado-rs"])
                ),
                CLIParameterDefinition(
                    id: "auth", flag: "--auth", displayName: "Authentication",
                    parameterType: .enumPicker, placeholder: "none",
                    helpText: "Authentication method for the DICOMweb server",
                    isInternal: true,
                    defaultValue: "none",
                    allowedValues: ["none", "basic", "bearer"]
                ),
                CLIParameterDefinition(
                    id: "token", flag: "--token", displayName: "Token / Password",
                    parameterType: .secureField, placeholder: "Bearer token or password",
                    helpText: "OAuth2 bearer token for authentication",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "auth", values: ["basic", "bearer"])
                ),
                CLIParameterDefinition(
                    id: "username", flag: "--username", displayName: "Username",
                    parameterType: .textField, placeholder: "e.g. admin",
                    helpText: "Username for basic authentication",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "auth", values: ["basic"])
                ),
                CLIParameterDefinition(
                    id: "timeout", flag: "--timeout", displayName: "Timeout (s)",
                    parameterType: .integerField, placeholder: "60",
                    helpText: "Connection timeout in seconds (default: 60)",
                    isAdvanced: true,
                    defaultValue: "60", minValue: 1, maxValue: 600
                ),
                CLIParameterDefinition(
                    id: "verbose", flag: "--verbose", displayName: "Verbose",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Show verbose output including progress"
                ),
            ]
        case "dicom-stow":
            return [
                CLIParameterDefinition(
                    id: "url", flag: "", displayName: "Base URL",
                    parameterType: .textField, placeholder: "e.g. https://pacs.hospital.com/dicom-web",
                    helpText: "DICOMweb server base URL (PS3.18 §6.5)",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "files", flag: "", displayName: "DICOM Files",
                    parameterType: .filePath, placeholder: "Drag and drop DICOM files or directories",
                    helpText: "DICOM files or directories to upload via STOW-RS (PS3.18 §10.5)",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "study-uid", flag: "--study", displayName: "Target Study UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619...",
                    helpText: "Study Instance UID for targeted storage (0020,000D)"
                ),
                CLIParameterDefinition(
                    id: "input", flag: "--input", displayName: "Input File List",
                    parameterType: .filePath, placeholder: "e.g. files.txt",
                    helpText: "File containing list of DICOM files to upload (one per line)",
                    isAdvanced: true
                ),
                CLIParameterDefinition(
                    id: "batch", flag: "--batch", displayName: "Batch Size",
                    parameterType: .integerField, placeholder: "10",
                    helpText: "Number of files to upload per batch (default: 10)",
                    defaultValue: "10", minValue: 1, maxValue: 100
                ),
                CLIParameterDefinition(
                    id: "continue-on-error", flag: "--continue-on-error", displayName: "Continue on Error",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Continue on errors instead of stopping"
                ),
                CLIParameterDefinition(
                    id: "auth", flag: "--auth", displayName: "Authentication",
                    parameterType: .enumPicker, placeholder: "none",
                    helpText: "Authentication method for the DICOMweb server",
                    isInternal: true,
                    defaultValue: "none",
                    allowedValues: ["none", "basic", "bearer"]
                ),
                CLIParameterDefinition(
                    id: "token", flag: "--token", displayName: "Token / Password",
                    parameterType: .secureField, placeholder: "Bearer token or password",
                    helpText: "OAuth2 bearer token for authentication",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "auth", values: ["basic", "bearer"])
                ),
                CLIParameterDefinition(
                    id: "username", flag: "--username", displayName: "Username",
                    parameterType: .textField, placeholder: "e.g. admin",
                    helpText: "Username for basic authentication",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "auth", values: ["basic"])
                ),
                CLIParameterDefinition(
                    id: "verbose", flag: "--verbose", displayName: "Verbose",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Show verbose output including progress"
                ),
            ]
        case "dicom-ups":
            return [
                CLIParameterDefinition(
                    id: "operation", flag: "", displayName: "Operation",
                    parameterType: .enumPicker, placeholder: "search",
                    helpText: "UPS-RS operation: search workitems, get details, create workitem, change state, or subscribe to events",
                    isRequired: true, isInternal: true,
                    defaultValue: "search",
                    allowedValues: ["search", "get", "create-workitem", "change-state", "subscribe"],
                    cliMapping: [
                        "subscribe": "--subscribe",
                    ]
                ),

                CLIParameterDefinition(
                    id: "url", flag: "", displayName: "Base URL",
                    parameterType: .textField, placeholder: "e.g. https://pacs.hospital.com/dicom-web",
                    helpText: "DICOMweb server base URL (PS3.18 §6.5)",
                    isRequired: true
                ),
                // --search flag (shown when operation=search)
                CLIParameterDefinition(
                    id: "search-flag", flag: "--search", displayName: "Search",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Search for worklist items",
                    defaultValue: "true",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["search"])
                ),
                // --get <uid> (shown when operation=get)
                CLIParameterDefinition(
                    id: "get-uid", flag: "--get", displayName: "Get Workitem UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619...",
                    helpText: "Get specific worklist item by UID",
                    isRequired: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["get"])
                ),
                // --create-workitem flag (shown when operation=create-workitem)
                CLIParameterDefinition(
                    id: "create-workitem-flag", flag: "--create-workitem", displayName: "Create Workitem",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Create a new worklist item from command-line options",
                    defaultValue: "true",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create-workitem"])
                ),
                // --update <uid> (shown when operation=change-state)
                CLIParameterDefinition(
                    id: "update-uid", flag: "--update", displayName: "Update Workitem UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619...",
                    helpText: "Workitem UID to update state for",
                    isRequired: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["change-state"])
                ),
                // Create-specific parameters
                CLIParameterDefinition(
                    id: "workitem-uid", flag: "--workitem-uid", displayName: "Workitem UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619... (auto-generated if empty)",
                    helpText: "UPS Workitem SOP Instance UID — auto-generated for create if omitted",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create-workitem", "subscribe"])
                ),
                CLIParameterDefinition(
                    id: "subscribe-aet", flag: "--aet", displayName: "AE Title",
                    parameterType: .textField, placeholder: "e.g. DICOM_STUDIO",
                    helpText: "Local Application Entity Title for subscribe/unsubscribe",
                    isRequired: true,
                    defaultValue: "DICOM_STUDIO",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["subscribe"])
                ),
                // --workitem-uid also visible for change-state (used in command preview)
                // Note: change-state uses --update <uid> from update-uid parameter, not --workitem-uid
                CLIParameterDefinition(
                    id: "create-label", flag: "--label", displayName: "Procedure Step Label",
                    parameterType: .textField, placeholder: "e.g. CT Scan Chest",
                    helpText: "Human-readable label for the procedure step (0074,1204)",
                    isRequired: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create-workitem"])
                ),
                CLIParameterDefinition(
                    id: "create-patient-name", flag: "--patient-name", displayName: "Patient Name",
                    parameterType: .textField, placeholder: "e.g. Doe^Jane",
                    helpText: "Patient name in DICOM format Last^First (0010,0010)",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create-workitem"])
                ),
                CLIParameterDefinition(
                    id: "create-patient-id", flag: "--patient-id", displayName: "Patient ID",
                    parameterType: .textField, placeholder: "e.g. PAT001",
                    helpText: "Patient identifier (0010,0020)",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create-workitem"])
                ),
                CLIParameterDefinition(
                    id: "create-priority", flag: "--priority", displayName: "Priority",
                    parameterType: .enumPicker, placeholder: "MEDIUM",
                    helpText: "Scheduled Procedure Step Priority (0074,1200)",
                    defaultValue: "MEDIUM",
                    allowedValues: ["STAT", "HIGH", "MEDIUM", "LOW"],
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create-workitem"])
                ),
                CLIParameterDefinition(
                    id: "create-scheduled-start", flag: "--scheduled-start", displayName: "Scheduled Start",
                    parameterType: .textField, placeholder: "e.g. 2026-03-20T14:00:00",
                    helpText: "Scheduled procedure step start date/time in ISO 8601 format",
                    isAdvanced: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create-workitem"])
                ),
                CLIParameterDefinition(
                    id: "create-study-uid", flag: "--study-uid", displayName: "Study Instance UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.840.113619...",
                    helpText: "Study Instance UID for the workitem",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create-workitem"])
                ),
                CLIParameterDefinition(
                    id: "create-accession", flag: "--accession-number", displayName: "Accession Number",
                    parameterType: .textField, placeholder: "e.g. ACC12345",
                    helpText: "Accession number (0008,0050)",
                    isAdvanced: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create-workitem"])
                ),
                CLIParameterDefinition(
                    id: "create-station-name", flag: "--station-name", displayName: "Station Name",
                    parameterType: .textField, placeholder: "e.g. CT_SCANNER_1",
                    helpText: "Scheduled station name for the procedure",
                    isAdvanced: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create-workitem"])
                ),
                CLIParameterDefinition(
                    id: "create-performer", flag: "--performer-name", displayName: "Performer Name",
                    parameterType: .textField, placeholder: "e.g. Tech^Mary",
                    helpText: "Scheduled human performer name",
                    isAdvanced: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create-workitem"])
                ),
                CLIParameterDefinition(
                    id: "create-comments", flag: "--comments", displayName: "Comments",
                    parameterType: .textField, placeholder: "e.g. Patient prepped for contrast",
                    helpText: "Comments on the scheduled procedure step (0040,0400)",
                    isAdvanced: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["create-workitem"])
                ),
                // Change-state parameters
                CLIParameterDefinition(
                    id: "state", flag: "--state", displayName: "Target State",
                    parameterType: .enumPicker, placeholder: "IN_PROGRESS",
                    helpText: "New state: SCHEDULED, IN_PROGRESS, COMPLETED, CANCELED",
                    defaultValue: "IN_PROGRESS",
                    allowedValues: ["SCHEDULED", "IN_PROGRESS", "COMPLETED", "CANCELED"],
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["change-state"])
                ),
                CLIParameterDefinition(
                    id: "change-state-aet", flag: "--aet", displayName: "Requesting AE",
                    parameterType: .textField, placeholder: "e.g. DCM4CHEE",
                    helpText: "Requesting AE Title — required by some servers (e.g. dcm4chee-arc) as the last path segment",
                    isRequired: true,
                    defaultValue: "DCM4CHEE",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["change-state"])
                ),
                CLIParameterDefinition(
                    id: "transaction-uid", flag: "--transaction-uid", displayName: "Transaction UID",
                    parameterType: .textField, placeholder: "e.g. 1.2.826.0.1.3680043...",
                    helpText: "Transaction UID — auto-generated for IN_PROGRESS, required for COMPLETED/CANCELED",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["change-state"])
                ),
                // Search-specific parameters
                CLIParameterDefinition(
                    id: "filter-state", flag: "--filter-state", displayName: "State Filter",
                    parameterType: .enumPicker, placeholder: "Any",
                    helpText: "Filter by Procedure Step State",
                    allowedValues: ["", "SCHEDULED", "IN_PROGRESS", "COMPLETED", "CANCELED"],
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["search"])
                ),
                CLIParameterDefinition(
                    id: "scheduled-station", flag: "--scheduled-station", displayName: "Scheduled Station",
                    parameterType: .textField, placeholder: "e.g. CT_SCANNER_1",
                    helpText: "Filter by Scheduled Station AE",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["search"])
                ),
                // ----- DICOMweb Auth Parameters -----
                CLIParameterDefinition(
                    id: "auth", flag: "--auth", displayName: "Authentication",
                    parameterType: .enumPicker, placeholder: "none",
                    helpText: "Authentication method for the DICOMweb server",
                    isInternal: true,
                    defaultValue: "none",
                    allowedValues: ["none", "basic", "bearer"]
                ),
                CLIParameterDefinition(
                    id: "token", flag: "--token", displayName: "Token / Password",
                    parameterType: .secureField, placeholder: "Bearer token or password",
                    helpText: "OAuth2 bearer token for authentication",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "auth", values: ["basic", "bearer"])
                ),
                CLIParameterDefinition(
                    id: "username", flag: "--username", displayName: "Username",
                    parameterType: .textField, placeholder: "e.g. admin",
                    helpText: "Username for basic authentication",
                    isInternal: true,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "auth", values: ["basic"])
                ),
                CLIParameterDefinition(
                    id: "output-format", flag: "--format", displayName: "Output Format",
                    parameterType: .enumPicker, placeholder: "table",
                    helpText: "Output format for results",
                    defaultValue: "table",
                    allowedValues: ["table", "json"],
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["search", "get"])
                ),
                CLIParameterDefinition(
                    id: "verbose", flag: "--verbose", displayName: "Verbose",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Show verbose output"
                ),
            ]
        case "dicom-convert":
            return [
                CLIParameterDefinition(
                    id: "inputPath", flag: "", displayName: "Input File/Directory",
                    parameterType: .filePath, placeholder: "Path to DICOM file or directory",
                    helpText: "DICOM file or directory to convert",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "output", flag: "--output", displayName: "Output Path",
                    parameterType: .outputPath, placeholder: "Output file or directory path",
                    helpText: "Destination file or directory for the converted output",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "format", flag: "--format", displayName: "Output Format",
                    parameterType: .enumPicker, placeholder: "dicom",
                    helpText: "Output format: DICOM (transfer syntax conversion) or image export (PNG, JPEG, TIFF)",
                    defaultValue: "dicom",
                    allowedValues: ["dicom", "png", "jpeg", "tiff"]
                ),
                CLIParameterDefinition(
                    id: "transfer-syntax", flag: "--transfer-syntax", displayName: "Transfer Syntax",
                    parameterType: .enumPicker, placeholder: "Target transfer syntax",
                    helpText: "Target transfer syntax for DICOM-to-DICOM conversion — supports uncompressed and compressed encoding (PS3.5 §10)",
                    allowedValues: [
                        "",
                        "ExplicitVRLittleEndian",
                        "ImplicitVRLittleEndian",
                        "ExplicitVRBigEndian",
                        "DEFLATE",
                        "JPEGBaseline",
                        "JPEGExtended",
                        "JPEGLossless",
                        "JPEGLosslessSV1",
                        "JPEG2000Lossless",
                        "JPEG2000",
                        "JPEGLSLossless",
                        "JPEGLSNearLossless",
                        "RLELossless",
                    ],
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "format", values: ["dicom"])
                ),
                CLIParameterDefinition(
                    id: "quality", flag: "--quality", displayName: "JPEG Quality",
                    parameterType: .integerField, placeholder: "90",
                    helpText: "JPEG compression quality (1–100, default: 90)",
                    defaultValue: "90", minValue: 1, maxValue: 100,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "format", values: ["jpeg"])
                ),
                CLIParameterDefinition(
                    id: "window-center", flag: "--window-center", displayName: "Window Center",
                    parameterType: .textField, placeholder: "e.g. 40",
                    helpText: "Window center value (Hounsfield units for CT)",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "format", values: ["png", "jpeg", "tiff"])
                ),
                CLIParameterDefinition(
                    id: "window-width", flag: "--window-width", displayName: "Window Width",
                    parameterType: .textField, placeholder: "e.g. 400",
                    helpText: "Window width value for controlling brightness range",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "format", values: ["png", "jpeg", "tiff"])
                ),
                CLIParameterDefinition(
                    id: "apply-window", flag: "--apply-window", displayName: "Apply Window/Level",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Apply window center/width values during image export",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "format", values: ["png", "jpeg", "tiff"])
                ),
                CLIParameterDefinition(
                    id: "frame", flag: "--frame", displayName: "Frame Number",
                    parameterType: .integerField, placeholder: "0",
                    helpText: "Frame number to export from multi-frame DICOM files (0-indexed)",
                    minValue: 0, maxValue: 9999,
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "format", values: ["png", "jpeg", "tiff"])
                ),
                CLIParameterDefinition(
                    id: "strip-private", flag: "--strip-private", displayName: "Strip Private Tags",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Remove vendor-specific private tags from the output file",
                    isAdvanced: true
                ),
                CLIParameterDefinition(
                    id: "recursive", flag: "--recursive", displayName: "Recursive",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Process all DICOM files in subdirectories when input is a directory",
                    isAdvanced: true
                ),
                CLIParameterDefinition(
                    id: "validate", flag: "--validate", displayName: "Validate Output",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Validate the converted output file for DICOM conformance",
                    isAdvanced: true
                ),
                CLIParameterDefinition(
                    id: "force", flag: "--force", displayName: "Force Parse",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Attempt to parse files that lack the standard DICM preamble",
                    isAdvanced: true
                ),
            ]
        case "dicom-info":
            return [
                CLIParameterDefinition(
                    id: "filePath", flag: "", displayName: "DICOM File",
                    parameterType: .filePath, placeholder: "Path to DICOM file",
                    helpText: "Path to the DICOM file to inspect",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "format", flag: "--format", displayName: "Output Format",
                    parameterType: .enumPicker, placeholder: "text",
                    helpText: "Output format: text, json, or csv",
                    defaultValue: "text",
                    allowedValues: ["text", "json", "csv"]
                ),
                CLIParameterDefinition(
                    id: "tag", flag: "--tag", displayName: "Filter Tags",
                    parameterType: .textField, placeholder: "PatientName,Modality",
                    helpText: "Filter by specific tag names (comma-separated)"
                ),
                CLIParameterDefinition(
                    id: "show-private", flag: "--show-private", displayName: "Show Private Tags",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Include private tags in output"
                ),
                CLIParameterDefinition(
                    id: "statistics", flag: "--statistics", displayName: "Show Statistics",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Show file statistics"
                ),
                CLIParameterDefinition(
                    id: "force", flag: "--force", displayName: "Force Parse",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Force parsing of files without DICM prefix",
                    isAdvanced: true
                ),
            ]
        case "dicom-dump":
            return [
                CLIParameterDefinition(
                    id: "filePath", flag: "", displayName: "DICOM File",
                    parameterType: .filePath, placeholder: "Path to DICOM file",
                    helpText: "Path to the DICOM file to dump",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "tag", flag: "--tag", displayName: "Tag",
                    parameterType: .textField, placeholder: "0010,0010",
                    helpText: "Dump only the specified tag (format: GGGG,EEEE)"
                ),
                CLIParameterDefinition(
                    id: "offset", flag: "--offset", displayName: "Start Offset",
                    parameterType: .textField, placeholder: "0",
                    helpText: "Start offset in bytes (decimal or 0xHEX)"
                ),
                CLIParameterDefinition(
                    id: "length", flag: "--length", displayName: "Length",
                    parameterType: .integerField, placeholder: "256",
                    helpText: "Number of bytes to dump",
                    minValue: 1
                ),
                CLIParameterDefinition(
                    id: "bytes-per-line", flag: "--bytes-per-line", displayName: "Bytes per Line",
                    parameterType: .integerField, placeholder: "16",
                    helpText: "Bytes per line (default: 16)",
                    defaultValue: "16", minValue: 1, maxValue: 64
                ),
                CLIParameterDefinition(
                    id: "highlight", flag: "--highlight", displayName: "Highlight Tag",
                    parameterType: .textField, placeholder: "0010,0010",
                    helpText: "Highlight a specific tag in the dump"
                ),
                CLIParameterDefinition(
                    id: "no-color", flag: "--no-color", displayName: "Disable Color",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Disable ANSI color output"
                ),
                CLIParameterDefinition(
                    id: "annotate", flag: "--annotate", displayName: "Annotate Tags",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Show tag annotations alongside hex bytes"
                ),
                CLIParameterDefinition(
                    id: "verbose", flag: "--verbose", displayName: "Verbose",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Verbose output with VR and length details"
                ),
                CLIParameterDefinition(
                    id: "force", flag: "--force", displayName: "Force Parse",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Force parsing of files without DICM prefix",
                    isAdvanced: true
                ),
            ]
        case "dicom-tags":
            return [
                CLIParameterDefinition(
                    id: "input", flag: "", displayName: "Input File",
                    parameterType: .filePath, placeholder: "Path to input DICOM file",
                    helpText: "Input DICOM file path",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "output", flag: "--output", displayName: "Output File",
                    parameterType: .outputPath, placeholder: "Path to output DICOM file",
                    helpText: "Output file path (defaults to overwrite input). If a directory is selected, the input file name is appended."
                ),
                // Single dropdown selecting which tag operation to perform.
                // The picker itself does not emit any CLI flag (`isInternal:
                // true`); it just controls which of the operation-specific
                // input fields is visible below.
                CLIParameterDefinition(
                    id: "operation", flag: "", displayName: "Operation",
                    parameterType: .enumPicker, placeholder: "set",
                    helpText: "Tag operation to perform on the input file",
                    isRequired: true,
                    isInternal: true,
                    defaultValue: "set",
                    allowedValues: ["set", "delete", "delete-private", "copy-from"]
                ),
                CLIParameterDefinition(
                    id: "set", flag: "--set", displayName: "Set Tag",
                    parameterType: .textField, placeholder: "PatientName=Anonymous",
                    helpText: "Tag values to set (format: TagName=Value or GGGG,EEEE=Value). Separate multiple with ';'.",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["set"])
                ),
                CLIParameterDefinition(
                    id: "delete", flag: "--delete", displayName: "Delete Tag",
                    parameterType: .textField, placeholder: "PatientID",
                    helpText: "Tag(s) to delete (by name or GGGG,EEEE). Separate multiple with ',' or ';'.",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["delete"])
                ),
                CLIParameterDefinition(
                    id: "delete-private", flag: "--delete-private", displayName: "Delete Private Tags",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Delete all private tags (odd group numbers)",
                    defaultValue: "true",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["delete-private"])
                ),
                CLIParameterDefinition(
                    id: "copy-from", flag: "--copy-from", displayName: "Copy From",
                    parameterType: .filePath, placeholder: "Path to source DICOM file",
                    helpText: "Copy tags from another DICOM file",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["copy-from"])
                ),
                CLIParameterDefinition(
                    id: "tags", flag: "--tags", displayName: "Tags to Copy",
                    parameterType: .textField, placeholder: "PatientName,StudyDate",
                    helpText: "Comma-separated tag names to copy (used with Copy From)",
                    visibleWhen: CLIParameterVisibilityCondition(parameterId: "operation", values: ["copy-from"])
                ),
                CLIParameterDefinition(
                    id: "verbose", flag: "--verbose", displayName: "Verbose",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Show verbose output of every change"
                ),
                CLIParameterDefinition(
                    id: "dry-run", flag: "--dry-run", displayName: "Dry Run",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Show what would be changed without writing"
                ),
            ]
        case "dicom-diff":
            return [
                CLIParameterDefinition(
                    id: "file1", flag: "", displayName: "File 1",
                    parameterType: .filePath, placeholder: "First DICOM file",
                    helpText: "First DICOM file to compare",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "file2", flag: "", displayName: "File 2",
                    parameterType: .filePath, placeholder: "Second DICOM file",
                    helpText: "Second DICOM file to compare",
                    isRequired: true
                ),
                CLIParameterDefinition(
                    id: "format", flag: "--format", displayName: "Output Format",
                    parameterType: .enumPicker, placeholder: "text",
                    helpText: "Output format: text, json, or summary",
                    defaultValue: "text",
                    allowedValues: ["text", "json", "summary"]
                ),
                CLIParameterDefinition(
                    id: "ignore-tag", flag: "--ignore-tag", displayName: "Ignore Tag",
                    parameterType: .textField, placeholder: "0008,0012",
                    helpText: "Tag to ignore (e.g. '0008,0012' or 'SOPInstanceUID')"
                ),
                CLIParameterDefinition(
                    id: "ignore-private", flag: "--ignore-private", displayName: "Ignore Private Tags",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Ignore all private tags during comparison"
                ),
                CLIParameterDefinition(
                    id: "compare-pixels", flag: "--compare-pixels", displayName: "Compare Pixels",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Compare pixel data in addition to metadata"
                ),
                CLIParameterDefinition(
                    id: "tolerance", flag: "--tolerance", displayName: "Pixel Tolerance",
                    parameterType: .textField, placeholder: "0",
                    helpText: "Pixel value tolerance for comparison (default: 0)",
                    defaultValue: "0"
                ),
                CLIParameterDefinition(
                    id: "quick", flag: "--quick", displayName: "Quick (Metadata Only)",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Skip pixel data comparison entirely"
                ),
                CLIParameterDefinition(
                    id: "show-identical", flag: "--show-identical", displayName: "Show Identical Tags",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Show identical tags in detailed mode"
                ),
                CLIParameterDefinition(
                    id: "verbose", flag: "--verbose", displayName: "Verbose",
                    parameterType: .booleanToggle, placeholder: "",
                    helpText: "Verbose output with detailed information"
                ),
            ]
        default:
            return []
        }
    }
}

// MARK: - 16.3 Command Builder Helpers

/// Helpers for building CLI command strings from parameters.
public enum CommandBuilderHelpers: Sendable {

    /// Builds a CLI command string from tool name and parameter values.
    public static func buildCommand(
        toolName: String,
        subcommand: String? = nil,
        parameterValues: [CLIParameterValue],
        parameterDefinitions: [CLIParameterDefinition]
    ) -> String {
        var parts: [String] = [toolName]
        if let sub = subcommand, !sub.isEmpty {
            parts.append(sub)
        }

        // Some DIMSE tools use a positional host:port argument:
        //   dicom-echo <host:port> --aet ...
        //   dicom-query <host:port> --aet ...
        //   dicom-send <host:port> --aet ... <files>
        //   dicom-retrieve <host:port> --aet ...
        //   dicom-qr <host:port> --aet ...
        //   dicom-mwl <host:port> --aet ...
        //   dicom-mpps <host:port> --aet ...
        // Keep host/port fields in the UI for convenience, but suppress their flag
        // form in the command preview — combine them into a single positional token instead.
        let usesPositionalEndpoint = toolName == "dicom-echo" || toolName == "dicom-query"
            || toolName == "dicom-send" || toolName == "dicom-retrieve"
            || toolName == "dicom-qr" || toolName == "dicom-mwl"
            || toolName == "dicom-mpps"
        var skipParameterIDs: Set<String> = []
        if usesPositionalEndpoint {
            let hostValue = parameterValues.first(where: { $0.parameterID == "host" })?.stringValue ?? ""
            let portValueRaw = parameterValues.first(where: { $0.parameterID == "port" })?.stringValue ?? ""
            let defaultPort = parameterDefinitions.first(where: { $0.id == "port" })?.defaultValue ?? ""
            let effectivePort = portValueRaw.isEmpty ? defaultPort : portValueRaw

            if !hostValue.isEmpty {
                let endpoint: String
                if hostValue.contains(":") || effectivePort.isEmpty {
                    endpoint = hostValue
                } else {
                    endpoint = "\(hostValue):\(effectivePort)"
                }
                parts.append(shellEscape(endpoint))
            }

            skipParameterIDs = ["host", "port"]
        }

        // Collect mapped tokens from internal parameters (e.g. --subscribe, --uri)
        // and defer them until after the first positional argument (URL) so the
        // command reads: `tool subcommand <url> --flag ...` not `tool subcommand --flag <url> ...`
        var deferredMappedTokens: [String] = []
        var positionalSeen = false

        // Iterate in definition order so the command preview matches the canonical parameter order
        for def in parameterDefinitions {
            if skipParameterIDs.contains(def.id) {
                continue
            }
            // Internal parameters with a cliMapping emit mapped CLI tokens
            if def.isInternal {
                if !def.cliMapping.isEmpty {
                    let value = parameterValues.first(where: { $0.parameterID == def.id })?.stringValue ?? ""
                    let effective = value.isEmpty ? def.defaultValue : value
                    if let mapped = def.cliMapping[effective], !mapped.isEmpty {
                        if positionalSeen {
                            parts.append(mapped)
                        } else {
                            deferredMappedTokens.append(mapped)
                        }
                    }
                }
                continue
            }
            // Skip parameters whose visibility condition is not met
            if let condition = def.visibleWhen {
                let currentValue = parameterValues.first(where: { $0.parameterID == condition.parameterId })?.stringValue ?? ""
                let effectiveValue = currentValue.isEmpty
                    ? parameterDefinitions.first(where: { $0.id == condition.parameterId })?.defaultValue ?? ""
                    : currentValue
                if !condition.values.contains(effectiveValue) {
                    continue
                }
            }
            guard let value = parameterValues.first(where: { $0.parameterID == def.id }) else { continue }
            guard !value.stringValue.isEmpty else { continue }
            switch def.parameterType {
            case .booleanToggle:
                if value.stringValue == "true" {
                    parts.append(def.flag)
                }
            case .flagPicker:
                // Flag pickers emit "--<value>" (e.g. "--interactive") instead of "--flag value"
                parts.append("--\(value.stringValue)")
            case .filePath, .outputPath:
                if def.flag.isEmpty {
                    parts.append(shellEscape(value.stringValue))
                    // Flush deferred internal tokens after positional arg (URL)
                    if !positionalSeen {
                        positionalSeen = true
                        parts.append(contentsOf: deferredMappedTokens)
                        deferredMappedTokens.removeAll()
                    }
                } else {
                    parts.append(def.flag)
                    parts.append(shellEscape(value.stringValue))
                }
            case .subcommand:
                // Subcommands are positional — insert right after the tool name (index 1)
                if !value.stringValue.isEmpty {
                    parts.insert(value.stringValue, at: 1)
                }
            default:
                if def.flag.isEmpty {
                    parts.append(shellEscape(value.stringValue))
                    // Flush deferred internal tokens after positional arg (URL)
                    if !positionalSeen {
                        positionalSeen = true
                        parts.append(contentsOf: deferredMappedTokens)
                        deferredMappedTokens.removeAll()
                    }
                } else if def.id == "ignore-tag" {
                    // ArgumentParser's `--ignore-tag` is repeatable. When the
                    // user enters multiple tokens in the single text field,
                    // emit one `--flag value` pair per token instead of a
                    // quoted multi-token string (which the CLI rejects with
                    // "Invalid tag format: 0010,0010 0010,0040").
                    let tokens = MetadataPresenter.normalizeFilterTokens(
                        value.stringValue
                            .split(whereSeparator: { $0 == ";" || $0.isWhitespace })
                            .map { String($0) }
                    )
                    if tokens.isEmpty {
                        parts.append(def.flag)
                        parts.append(shellEscape(value.stringValue))
                    } else {
                        for token in tokens {
                            parts.append(def.flag)
                            parts.append(shellEscape(token))
                        }
                    }
                } else {
                    parts.append(def.flag)
                    parts.append(shellEscape(value.stringValue))
                }
            }
        }
        // Append any remaining deferred tokens (if no positional arg was seen)
        parts.append(contentsOf: deferredMappedTokens)
        return parts.joined(separator: " ")
    }

    /// Shell-escapes a file path.
    public static func shellEscape(_ path: String) -> String {
        if path.contains(" ") || path.contains("'") || path.contains("\"") {
            let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
            return "'\(escaped)'"
        }
        return path
    }

    /// Validates that all required parameters have values.
    public static func validateRequired(
        parameterValues: [CLIParameterValue],
        parameterDefinitions: [CLIParameterDefinition]
    ) -> Bool {
        let requiredDefs = parameterDefinitions.filter { $0.isRequired }
        for def in requiredDefs {
            // Skip required parameters that are conditionally hidden
            if let condition = def.visibleWhen {
                let currentValue = parameterValues.first(where: { $0.parameterID == condition.parameterId })?.stringValue ?? ""
                let effectiveValue = currentValue.isEmpty
                    ? parameterDefinitions.first(where: { $0.id == condition.parameterId })?.defaultValue ?? ""
                    : currentValue
                if !condition.values.contains(effectiveValue) {
                    continue
                }
            }
            guard let val = parameterValues.first(where: { $0.parameterID == def.id }) else { return false }
            if val.stringValue.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        }
        return true
    }

    /// Returns the list of missing required parameter display names.
    public static func missingRequiredParameters(
        parameterValues: [CLIParameterValue],
        parameterDefinitions: [CLIParameterDefinition]
    ) -> [String] {
        let requiredDefs = parameterDefinitions.filter { $0.isRequired }
        var missing: [String] = []
        for def in requiredDefs {
            let val = parameterValues.first(where: { $0.parameterID == def.id })
            if val == nil || val!.stringValue.trimmingCharacters(in: .whitespaces).isEmpty {
                missing.append(def.displayName)
            }
        }
        return missing
    }

    /// Tokenizes a command string for syntax highlighting.
    public static func tokenize(_ command: String) -> [CLISyntaxToken] {
        let parts = command.split(separator: " ", omittingEmptySubsequences: true)
        var tokens: [CLISyntaxToken] = []
        for (index, part) in parts.enumerated() {
            let text = String(part)
            let tokenType: CLISyntaxTokenType
            if index == 0 {
                tokenType = .toolName
            } else if text.hasPrefix("--") || text.hasPrefix("-") {
                tokenType = .flag
            } else if text.contains("/") || text.contains(".dcm") || text.contains(".dicom") {
                tokenType = .path
            } else {
                tokenType = .value
            }
            tokens.append(CLISyntaxToken(text: text, tokenType: tokenType))
        }
        return tokens
    }
}

// MARK: - 16.4 File Drop Helpers

/// Helpers for file drop zone logic.
public enum FileDropHelpers: Sendable {

    /// Validates whether a filename has a DICOM-compatible extension.
    public static func isDICOMFile(_ filename: String) -> Bool {
        let lower = filename.lowercased()
        return lower.hasSuffix(".dcm") || lower.hasSuffix(".dicom") || lower.hasSuffix(".dic") || !lower.contains(".")
    }

    /// Formats a file size in bytes to a human-readable string.
    public static func formatFileSize(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
        } else {
            return String(format: "%.2f GB", Double(bytes) / (1024.0 * 1024.0 * 1024.0))
        }
    }

    /// Returns a brief summary for a list of files.
    public static func fileSummary(_ files: [CLIFileEntry]) -> String {
        switch files.count {
        case 0:  return "No files selected"
        case 1:  return files[0].filename
        default: return "\(files.count) files selected"
        }
    }
}

// MARK: - 16.5 Console Helpers

/// Helpers for CLI console display and PHI redaction.
public enum ConsoleHelpers: Sendable {

    /// Maximum number of commands to retain in history.
    public static let maxHistoryCount: Int = 50

    /// Redacts potential PHI from a command string.
    public static func redactPHI(_ command: String) -> String {
        var result = command
        // Redact patterns that look like patient names (--patient-name "...")
        let namePattern = #"(--patient[_-]?name\s+)("[^"]*"|'[^']*'|\S+)"#
        if let regex = try? NSRegularExpression(pattern: namePattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1<redacted>"
            )
        }
        // Redact patient IDs
        let idPattern = #"(--patient[_-]?id\s+)("[^"]*"|'[^']*'|\S+)"#
        if let regex = try? NSRegularExpression(pattern: idPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1<redacted>"
            )
        }
        // Redact OAuth2 tokens
        let tokenPattern = #"(--token\s+|--oauth[_-]?token\s+)("[^"]*"|'[^']*'|\S+)"#
        if let regex = try? NSRegularExpression(pattern: tokenPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1<redacted>"
            )
        }
        return result
    }

    /// Formats a timestamp for display in command history.
    public static func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    /// Trims history to the maximum count, removing oldest entries.
    public static func trimHistory(_ history: [CLICommandHistoryEntry]) -> [CLICommandHistoryEntry] {
        if history.count <= maxHistoryCount { return history }
        return Array(history.suffix(maxHistoryCount))
    }
}

// MARK: - 16.8 Educational Helpers

/// Helpers for educational features like glossary and example presets.
public enum EducationalHelpers: Sendable {

    /// Returns sample DICOM glossary entries.
    public static func defaultGlossaryEntries() -> [CLIGlossaryEntry] {
        [
            CLIGlossaryEntry(term: "AE Title", definition: "Application Entity Title — a unique identifier (up to 16 characters) for a DICOM application on the network.", standardReference: "PS3.8"),
            CLIGlossaryEntry(term: "SOP Class", definition: "Service-Object Pair Class — defines the type of DICOM object and the services that can operate on it.", standardReference: "PS3.4"),
            CLIGlossaryEntry(term: "Transfer Syntax", definition: "Defines how DICOM data is encoded, including byte order, VR encoding, and pixel data compression.", standardReference: "PS3.5"),
            CLIGlossaryEntry(term: "IOD", definition: "Information Object Definition — a data model specifying the attributes of a real-world object (e.g., CT Image).", standardReference: "PS3.3"),
            CLIGlossaryEntry(term: "DICOMDIR", definition: "A directory file that indexes the contents of DICOM media (e.g., CD/DVD).", standardReference: "PS3.10"),
            CLIGlossaryEntry(term: "C-ECHO", definition: "DICOM verification service — tests network connectivity between two DICOM nodes.", standardReference: "PS3.7"),
            CLIGlossaryEntry(term: "C-FIND", definition: "DICOM query service — searches for studies, series, or images on a remote PACS.", standardReference: "PS3.4"),
            CLIGlossaryEntry(term: "C-STORE", definition: "DICOM storage service — sends DICOM objects to a remote storage SCP.", standardReference: "PS3.4"),
            CLIGlossaryEntry(term: "C-MOVE", definition: "DICOM retrieval service — instructs a PACS to send objects to a specified destination.", standardReference: "PS3.4"),
            CLIGlossaryEntry(term: "C-GET", definition: "DICOM retrieval service — retrieves objects directly over the existing association.", standardReference: "PS3.4"),
            CLIGlossaryEntry(term: "VR", definition: "Value Representation — the data type of a DICOM attribute (e.g., DA for Date, PN for Person Name).", standardReference: "PS3.5"),
            CLIGlossaryEntry(term: "UID", definition: "Unique Identifier — a globally unique string identifying DICOM objects, classes, and transfer syntaxes.", standardReference: "PS3.5"),
            CLIGlossaryEntry(term: "WADO-RS", definition: "Web Access to DICOM Objects using RESTful Services — retrieve DICOM data over HTTP.", standardReference: "PS3.18"),
            CLIGlossaryEntry(term: "QIDO-RS", definition: "Query based on ID for DICOM Objects using RESTful Services — search for DICOM data over HTTP.", standardReference: "PS3.18"),
            CLIGlossaryEntry(term: "STOW-RS", definition: "Store Over the Web using RESTful Services — upload DICOM data over HTTP.", standardReference: "PS3.18"),
        ]
    }

    /// Filters glossary entries by a search query.
    public static func filterGlossary(_ entries: [CLIGlossaryEntry], query: String) -> [CLIGlossaryEntry] {
        guard !query.isEmpty else { return entries }
        let lower = query.lowercased()
        return entries.filter {
            $0.term.lowercased().contains(lower) ||
            $0.definition.lowercased().contains(lower)
        }
    }

    /// Returns example command presets for a given tool.
    public static func examplePresets(for toolID: String) -> [CLIExamplePreset] {
        switch toolID {
        case "dicom-info":
            return [
                CLIExamplePreset(toolID: toolID, title: "Basic File Info",
                                 presetDescription: "Display metadata in text format",
                                 commandString: "dicom-info scan.dcm"),
                CLIExamplePreset(toolID: toolID, title: "JSON Output with Statistics",
                                 presetDescription: "Output metadata as JSON with file statistics",
                                 commandString: "dicom-info --format json --statistics scan.dcm"),
            ]
        case "dicom-dump":
            return [
                CLIExamplePreset(toolID: toolID, title: "Full Hex Dump",
                                 presetDescription: "Annotated hex dump of an entire DICOM file",
                                 commandString: "dicom-dump --annotate scan.dcm"),
                CLIExamplePreset(toolID: toolID, title: "Dump Single Tag",
                                 presetDescription: "Show only the bytes for the PatientName tag",
                                 commandString: "dicom-dump --tag 0010,0010 --verbose scan.dcm"),
            ]
        case "dicom-tags":
            return [
                CLIExamplePreset(toolID: toolID, title: "Anonymize Patient Name",
                                 presetDescription: "Replace PatientName and remove PatientID",
                                 commandString: "dicom-tags --set PatientName=Anonymous --delete PatientID --output anon.dcm scan.dcm"),
                CLIExamplePreset(toolID: toolID, title: "Strip Private Tags (Dry Run)",
                                 presetDescription: "Preview removal of all private tags",
                                 commandString: "dicom-tags --delete-private --dry-run --verbose scan.dcm"),
            ]
        case "dicom-diff":
            return [
                CLIExamplePreset(toolID: toolID, title: "Quick Metadata Diff",
                                 presetDescription: "Compare metadata only, summary output",
                                 commandString: "dicom-diff --quick --format summary file1.dcm file2.dcm"),
                CLIExamplePreset(toolID: toolID, title: "Full Compare with Pixels",
                                 presetDescription: "Compare metadata and pixel data with tolerance",
                                 commandString: "dicom-diff --compare-pixels --tolerance 5 --ignore-tag SOPInstanceUID file1.dcm file2.dcm"),
            ]
        case "dicom-echo":
            return [
                CLIExamplePreset(toolID: toolID, title: "Basic Echo Test",
                                 presetDescription: "Test connectivity to a PACS server",
                                 commandString: "dicom-echo --host pacs.example.com --port 11112 --aet STUDIO --called-aet PACS"),
                CLIExamplePreset(toolID: toolID, title: "Echo with Stats",
                                 presetDescription: "Send 10 echoes and show round-trip statistics",
                                 commandString: "dicom-echo --host pacs.example.com --port 11112 --aet STUDIO --count 10 --stats"),
            ]
        case "dicom-anon":
            return [
                CLIExamplePreset(toolID: toolID, title: "Basic Anonymization",
                                 presetDescription: "Anonymize using the basic profile",
                                 commandString: "dicom-anon --profile basic --output /output/ scan.dcm"),
                CLIExamplePreset(toolID: toolID, title: "Dry Run Preview",
                                 presetDescription: "Preview anonymization changes without writing files",
                                 commandString: "dicom-anon --profile basic --dry-run scan.dcm"),
            ]
        case "dicom-convert":
            return [
                CLIExamplePreset(toolID: toolID, title: "Convert to Explicit VR Little Endian",
                                 presetDescription: "Re-encode a DICOM file with Explicit VR Little Endian transfer syntax",
                                 commandString: "dicom-convert scan.dcm --output converted.dcm --format dicom --transfer-syntax ExplicitVRLittleEndian"),
                CLIExamplePreset(toolID: toolID, title: "Export as PNG with Windowing",
                                 presetDescription: "Export pixel data as PNG with custom window/level for CT",
                                 commandString: "dicom-convert ct.dcm --output ct.png --format png --apply-window --window-center 40 --window-width 400"),
                CLIExamplePreset(toolID: toolID, title: "Export as JPEG (High Quality)",
                                 presetDescription: "Export pixel data as high-quality JPEG image",
                                 commandString: "dicom-convert xray.dcm --output xray.jpg --format jpeg --quality 95"),
                CLIExamplePreset(toolID: toolID, title: "Batch Convert Directory",
                                 presetDescription: "Recursively convert all files in a directory to Implicit VR",
                                 commandString: "dicom-convert input/ --output output/ --format dicom --transfer-syntax ImplicitVRLittleEndian --recursive"),
            ]
        case "dicom-query":
            return [
                CLIExamplePreset(toolID: toolID, title: "Query Studies by Modality",
                                 presetDescription: "Find all CT studies on the PACS",
                                 commandString: "dicom-query --host pacs.example.com --port 11112 --aet STUDIO --modality CT"),
                CLIExamplePreset(toolID: toolID, title: "Query by Patient Name",
                                 presetDescription: "Search for studies by patient name with wildcards",
                                 commandString: "dicom-query --host pacs.example.com --port 11112 --aet STUDIO --patient-name \"SMITH*\" --format json"),
            ]
        default:
            return []
        }
    }

    /// Returns the total number of glossary entries.
    public static var defaultGlossaryCount: Int { defaultGlossaryEntries().count }

    // MARK: - DICOM Tag Formatting

    /// Formats a raw 8-character tag string into (GGGG,EEEE) format.
    public static func formatTag(_ tag: String) -> String {
        guard tag.count == 8 else { return tag }
        let group = tag.prefix(4)
        let element = tag.suffix(4)
        return "\(group),\(element)"
    }

    /// Lookup table for common DICOM tag names used in UPS.
    private static let tagNames: [String: String] = [
        "00080016": "SOP Class UID",
        "00080018": "SOP Instance UID",
        "00080050": "Accession Number",
        "00080090": "Referring Physician",
        "00080100": "Code Value",
        "00080102": "Coding Scheme Designator",
        "00080104": "Code Meaning",
        "00081110": "Referenced Study Sequence",
        "00081150": "Referenced SOP Class UID",
        "00081155": "Referenced SOP Instance UID",
        "00081195": "Transaction UID",
        "00100010": "Patient's Name",
        "00100020": "Patient ID",
        "00100030": "Patient's Birth Date",
        "00100040": "Patient's Sex",
        "0020000D": "Study Instance UID",
        "0020000E": "Series Instance UID",
        "00321060": "Requested Procedure Description",
        "00400009": "Scheduled Procedure Step ID",
        "00400400": "Comments on Scheduled Procedure Step",
        "0040A370": "Referenced Request Sequence",
        "00401001": "Requested Procedure ID",
        "00404005": "Scheduled Procedure Step Start DateTime",
        "00404010": "Scheduled Procedure Step Modification DateTime",
        "00404011": "Expected Completion DateTime",
        "00404018": "Scheduled Workitem Code Sequence",
        "00404021": "Input Information Sequence",
        "00404025": "Scheduled Station Name Code Sequence",
        "00404026": "Scheduled Station Class Code Sequence",
        "00404027": "Scheduled Station Geographic Location Code Sequence",
        "00404033": "Output Information Sequence",
        "00404034": "Scheduled Human Performers Sequence",
        "00404035": "Actual Human Performers Sequence",
        "00404036": "Human Performer Code Sequence",
        "00404037": "Human Performer's Name",
        "00404041": "Input Readiness State",
        "00404052": "Procedure Step Cancellation DateTime",
        "00741000": "Procedure Step State",
        "00741002": "Contact URI",
        "00741004": "Procedure Step Progress",
        "00741006": "Procedure Step Progress Description",
        "00741200": "Scheduled Procedure Step Priority",
        "00741202": "Worklist Label",
        "00741204": "Procedure Step Label",
        "00741210": "Scheduled Processing Parameters Sequence",
        "00741236": "Procedure Step Discontinuation Reason Code Sequence",
        "00741238": "Reason for Cancellation",
    ]

    /// Returns a human-readable name for a DICOM tag, or the raw tag if unknown.
    public static func dicomTagName(for tag: String) -> String {
        return tagNames[tag.uppercased()] ?? tag
    }
}
