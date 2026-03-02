// CLIWorkshopHelpers.swift
// DICOMStudio
//
// DICOM Studio — Platform-independent helpers for CLI Tools Workshop (Milestone 16)

import Foundation

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
                              dicomStandardRef: "PS3.7", requiresNetwork: true),
            CLIToolDefinition(id: "dicom-query", name: "dicom-query", displayName: "DICOM Query",
                              category: .networkOperations, sfSymbol: "magnifyingglass",
                              briefDescription: "Query DICOM servers with C-FIND",
                              dicomStandardRef: "PS3.4", requiresNetwork: true),
            CLIToolDefinition(id: "dicom-send", name: "dicom-send", displayName: "DICOM Send",
                              category: .networkOperations, sfSymbol: "arrow.up.circle",
                              briefDescription: "Send DICOM files to servers with C-STORE",
                              dicomStandardRef: "PS3.4", requiresNetwork: true),
            CLIToolDefinition(id: "dicom-retrieve", name: "dicom-retrieve", displayName: "DICOM Retrieve",
                              category: .networkOperations, sfSymbol: "arrow.down.circle",
                              briefDescription: "Retrieve DICOM files from PACS with C-MOVE/C-GET",
                              dicomStandardRef: "PS3.4", requiresNetwork: true),
            CLIToolDefinition(id: "dicom-qr", name: "dicom-qr", displayName: "Query-Retrieve",
                              category: .networkOperations, sfSymbol: "arrow.up.arrow.down.circle",
                              briefDescription: "Combined query-retrieve workflow",
                              dicomStandardRef: "PS3.4", requiresNetwork: true),
            CLIToolDefinition(id: "dicom-wado", name: "dicom-wado", displayName: "DICOMweb",
                              category: .networkOperations, sfSymbol: "globe",
                              briefDescription: "DICOMweb WADO-RS, QIDO-RS, STOW-RS, and UPS-RS",
                              dicomStandardRef: "PS3.18", hasSubcommands: true, requiresNetwork: true),
            CLIToolDefinition(id: "dicom-mwl", name: "dicom-mwl", displayName: "Modality Worklist",
                              category: .networkOperations, sfSymbol: "list.clipboard",
                              briefDescription: "Query Modality Worklist for scheduled procedures",
                              dicomStandardRef: "PS3.4", requiresNetwork: true),
            CLIToolDefinition(id: "dicom-mpps", name: "dicom-mpps", displayName: "MPPS",
                              category: .networkOperations, sfSymbol: "clock.arrow.2.circlepath",
                              briefDescription: "Modality Performed Procedure Step management",
                              dicomStandardRef: "PS3.4", hasSubcommands: true, requiresNetwork: true),
        ]
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
    public static var totalToolCount: Int { 29 }
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
        for value in parameterValues {
            guard !value.stringValue.isEmpty else { continue }
            guard let def = parameterDefinitions.first(where: { $0.id == value.parameterID }) else { continue }
            switch def.parameterType {
            case .booleanToggle:
                if value.stringValue == "true" {
                    parts.append(def.flag)
                }
            case .filePath, .outputPath:
                if def.flag.isEmpty {
                    parts.append(shellEscape(value.stringValue))
                } else {
                    parts.append(def.flag)
                    parts.append(shellEscape(value.stringValue))
                }
            default:
                parts.append(def.flag)
                parts.append(value.stringValue)
            }
        }
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
        case "dicom-echo":
            return [
                CLIExamplePreset(toolID: toolID, title: "Basic Echo Test",
                                 presetDescription: "Test connectivity to a PACS server",
                                 commandString: "dicom-echo --host pacs.example.com --port 11112 --ae-title STUDIO --called-aet PACS"),
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
                CLIExamplePreset(toolID: toolID, title: "Convert to JPEG 2000",
                                 presetDescription: "Re-encode pixel data with JPEG 2000 lossless",
                                 commandString: "dicom-convert --transfer-syntax jpeg2000-lossless --output converted.dcm scan.dcm"),
            ]
        case "dicom-query":
            return [
                CLIExamplePreset(toolID: toolID, title: "Query Studies by Modality",
                                 presetDescription: "Find all CT studies on the PACS",
                                 commandString: "dicom-query --level study --modality CT --host pacs.example.com"),
            ]
        default:
            return []
        }
    }

    /// Returns the total number of glossary entries.
    public static var defaultGlossaryCount: Int { defaultGlossaryEntries().count }
}
