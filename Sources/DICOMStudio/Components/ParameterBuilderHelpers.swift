// ParameterBuilderHelpers.swift
// DICOMStudio
//
// DICOM Studio — Helper enums for Dynamic GUI Controls & Parameter Builder (Milestone 21)

import Foundation

// MARK: - ParameterValidationHelpers

/// Helpers for validating parameter values against rules and DICOM-specific constraints.
public enum ParameterValidationHelpers {

    /// Validates a value against a list of rules and returns the first error message, or `nil` if valid.
    public static func validate(value: ParameterValue, against validations: [ParameterValidation]) -> String? {
        for validation in validations {
            switch validation {
            case .required:
                let str = value.stringRepresentation
                if str.trimmingCharacters(in: .whitespaces).isEmpty {
                    return "This field is required."
                }
            case .maxLength(let max):
                let str = value.stringRepresentation
                if str.count > max {
                    return "Must be \(max) characters or fewer (currently \(str.count))."
                }
            case .range(let min, let max):
                switch value {
                case .int(let v):
                    if Double(v) < min || Double(v) > max {
                        return "Must be between \(Int(min)) and \(Int(max))."
                    }
                case .double(let v):
                    if v < min || v > max {
                        return "Must be between \(min) and \(max)."
                    }
                default:
                    break
                }
            case .regex(let pattern):
                let str = value.stringRepresentation
                if str.range(of: pattern, options: .regularExpression) == nil {
                    return "Value does not match required pattern."
                }
            case .custom(let description):
                return description
            }
        }
        return nil
    }

    /// Validates a DICOM AE Title: must be non-empty and at most 16 characters.
    public static func validateAETitle(_ title: String) -> String? {
        if title.isEmpty { return "AE Title must not be empty." }
        if title.count > 16 { return "AE Title must be 16 characters or fewer (currently \(title.count))." }
        return nil
    }

    /// Validates a TCP port number: must be in the range 1–65535.
    public static func validatePort(_ port: Int) -> String? {
        if port < 1 || port > 65535 {
            return "Port must be between 1 and 65535."
        }
        return nil
    }

    /// Validates a hostname: must be non-empty.
    public static func validateHost(_ host: String) -> String? {
        if host.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Host must not be empty."
        }
        return nil
    }
}

// MARK: - ParameterCatalogHelpers

/// Helpers for building and looking up per-tool parameter configurations.
public enum ParameterCatalogHelpers {

    /// All tool names covered by this catalog.
    public static let allToolNames: [String] = [
        "dicom-info", "dicom-diff", "dicom-convert", "dicom-anon",
        "dicom-compress", "dicom-echo", "dicom-query", "dicom-send",
        "dicom-retrieve", "dicom-uid", "dicom-image", "dicom-json"
    ]

    /// Returns the `ToolParameterConfig` for `toolName`, or `nil` when not found.
    public static func config(for toolName: String) -> ToolParameterConfig? {
        allToolConfigs().first { $0.toolName == toolName }
    }

    /// Returns all 12 representative tool parameter configurations.
    public static func allToolConfigs() -> [ToolParameterConfig] {
        [
            dicomInfo(),
            dicomDiff(),
            dicomConvert(),
            dicomAnon(),
            dicomCompress(),
            dicomEcho(),
            dicomQuery(),
            dicomSend(),
            dicomRetrieve(),
            dicomUID(),
            dicomImage(),
            dicomJSON()
        ]
    }

    // MARK: Private builders

    private static func dicomInfo() -> ToolParameterConfig {
        ToolParameterConfig(
            toolName: "dicom-info",
            parameters: [
                param("--input", "Input File", "DICOM file to inspect.", type: .filePath(allowedExtensions: ["dcm", "dicom"]), required: true),
                param("--output-format", "Output Format", "Format for the output.", type: .picker(options: options(["text", "json", "xml"]))),
                param("--verbose", "Verbose", "Enable verbose output.", type: .toggle)
            ],
            subcommands: []
        )
    }

    private static func dicomDiff() -> ToolParameterConfig {
        ToolParameterConfig(
            toolName: "dicom-diff",
            parameters: [
                param("--file-a", "File A", "First DICOM file.", type: .filePath(allowedExtensions: ["dcm", "dicom"]), required: true),
                param("--file-b", "File B", "Second DICOM file.", type: .filePath(allowedExtensions: ["dcm", "dicom"]), required: true),
                param("--ignore-private", "Ignore Private Tags", "Skip private tag differences.", type: .toggle),
                param("--output-format", "Output Format", "Format for the diff output.", type: .picker(options: options(["text", "json"])))
            ],
            subcommands: []
        )
    }

    private static func dicomConvert() -> ToolParameterConfig {
        // Transfer-syntax picker: human-readable label in the UI, but a stable
        // shortform value flows through to the CLI command preview and the
        // backend (DICOMCore) via `paramValue("transfer-syntax")`. Keep the
        // shortforms aligned with `parseTransferSyntax(_:)` in
        // `CLIWorkshopViewModel` and the `dicom-convert` command-line tool.
        let transferSyntaxOptions: [PickerOption] = [
            PickerOption(id: "evle",               displayName: "Explicit VR Little Endian",          cliValue: "evle"),
            PickerOption(id: "ivle",               displayName: "Implicit VR Little Endian",          cliValue: "ivle"),
            PickerOption(id: "evbe",               displayName: "Explicit VR Big Endian",             cliValue: "evbe"),
            PickerOption(id: "deflate",            displayName: "Deflated Explicit VR Little Endian", cliValue: "deflate"),
            PickerOption(id: "jpeg-baseline",      displayName: "JPEG Baseline (Lossy)",              cliValue: "jpeg-baseline"),
            PickerOption(id: "jpeg-extended",      displayName: "JPEG Extended (Lossy)",              cliValue: "jpeg-extended"),
            PickerOption(id: "jpeg-lossless",      displayName: "JPEG Lossless",                      cliValue: "jpeg-lossless"),
            PickerOption(id: "jpeg-lossless-sv1",  displayName: "JPEG Lossless SV1",                  cliValue: "jpeg-lossless-sv1"),
            PickerOption(id: "j2k-lossless",       displayName: "JPEG 2000 Lossless",                 cliValue: "j2k-lossless"),
            PickerOption(id: "j2k",                displayName: "JPEG 2000 (Lossy)",                  cliValue: "j2k"),
            PickerOption(id: "j2k-part2-lossless", displayName: "JPEG 2000 Part 2 Lossless",          cliValue: "j2k-part2-lossless"),
            PickerOption(id: "j2k-part2",          displayName: "JPEG 2000 Part 2 (Lossy)",           cliValue: "j2k-part2"),
            PickerOption(id: "htj2k-lossless",     displayName: "HTJ2K Lossless",                     cliValue: "htj2k-lossless"),
            PickerOption(id: "htj2k-rpcl",         displayName: "HTJ2K RPCL Lossless",                cliValue: "htj2k-rpcl"),
            PickerOption(id: "htj2k",              displayName: "HTJ2K (Lossy)",                      cliValue: "htj2k"),
            PickerOption(id: "jpegls",             displayName: "JPEG-LS Lossless",                   cliValue: "jpegls"),
            PickerOption(id: "jpegls-near",        displayName: "JPEG-LS Near-Lossless",              cliValue: "jpegls-near"),
            PickerOption(id: "rle",                displayName: "RLE Lossless",                       cliValue: "rle"),
        ]

        return ToolParameterConfig(
            toolName: "dicom-convert",
            parameters: [
                param("--input", "Input File", "Source DICOM file.", type: .filePath(allowedExtensions: ["dcm", "dicom"]), required: true),
                param("--output", "Output File", "Destination file path.", type: .outputPath(defaultExtension: "dcm")),
                param("--transfer-syntax", "Transfer Syntax",
                      "Target transfer syntax (shortform value passed to the CLI).",
                      type: .picker(options: transferSyntaxOptions)),
                param("--codec-backend", "JPEG 2000 Codec",
                      "Codec for JPEG 2000 family transfer syntaxes. J2KSwift is the default and supports HTJ2K; OpenJPEG handles Part 1 / Part 2 only.",
                      type: .picker(options: [
                          PickerOption(id: "j2kswift", displayName: "J2KSwift (default)", cliValue: "--j2kswift"),
                          PickerOption(id: "openjpeg", displayName: "OpenJPEG", cliValue: "--openjpeg")
                      ]),
                      defaultValue: .string("j2kswift")),
                param("--force", "Force", "Overwrite existing output file.", type: .toggle)
            ],
            subcommands: []
        )
    }

    private static func dicomAnon() -> ToolParameterConfig {
        ToolParameterConfig(
            toolName: "dicom-anon",
            parameters: [
                param("--input", "Input File", "DICOM file to anonymise.", type: .filePath(allowedExtensions: ["dcm", "dicom"]), required: true),
                param("--output", "Output File", "Path for the anonymised file.", type: .outputPath(defaultExtension: "dcm")),
                param("--profile", "Anonymisation Profile", "Level of anonymisation to apply.",
                      type: .radio(options: options(["basic", "standard", "full"]))),
                param("--retain-dates", "Retain Dates", "Keep study/series/acquisition dates.", type: .toggle)
            ],
            subcommands: []
        )
    }

    private static func dicomCompress() -> ToolParameterConfig {
        ToolParameterConfig(
            toolName: "dicom-compress",
            parameters: [],
            subcommands: [
                ToolSubcommand(
                    name: "compress",
                    displayName: "Compress",
                    description: "Compress a DICOM file using the specified codec.",
                    parameters: [
                        param("--input", "Input File", "DICOM file to compress.", type: .filePath(allowedExtensions: ["dcm", "dicom"]), required: true),
                        param("--output", "Output File", "Path for the compressed file.", type: .outputPath(defaultExtension: "dcm")),
                        param("--codec", "Codec", "Compression codec to use.",
                              type: .picker(options: options(["jpeg-baseline", "jpeg2000", "rle-lossless"]))),
                        param("--quality", "Quality", "Compression quality (0–100).",
                              type: .slider(min: 0, max: 100, step: 1))
                    ]
                ),
                ToolSubcommand(
                    name: "decompress",
                    displayName: "Decompress",
                    description: "Decompress a DICOM file to uncompressed transfer syntax.",
                    parameters: [
                        param("--input", "Input File", "Compressed DICOM file.", type: .filePath(allowedExtensions: ["dcm", "dicom"]), required: true),
                        param("--output", "Output File", "Path for the decompressed file.", type: .outputPath(defaultExtension: "dcm"))
                    ]
                ),
                ToolSubcommand(
                    name: "info",
                    displayName: "Info",
                    description: "Display compression information for a DICOM file.",
                    parameters: [
                        param("--input", "Input File", "DICOM file to inspect.", type: .filePath(allowedExtensions: ["dcm", "dicom"]), required: true)
                    ]
                )
            ]
        )
    }

    private static func dicomEcho() -> ToolParameterConfig {
        ToolParameterConfig(
            toolName: "dicom-echo",
            parameters: [
                param("--host", "Host", "DICOM server hostname or IP.", type: .host, required: true),
                param("--port", "Port", "DICOM server port.", type: .port, defaultValue: .int(11112)),
                param("--calling-aet", "Calling AE Title", "Local AE Title.", type: .aeTitle),
                param("--called-aet", "Called AE Title", "Remote AE Title.", type: .aeTitle),
                param("--timeout", "Timeout (s)", "Network timeout in seconds.",
                      type: .number(min: 1, max: 300, step: 1)),
                param("--tls", "Use TLS", "Enable TLS for the connection.", type: .toggle)
            ],
            subcommands: []
        )
    }

    private static func dicomQuery() -> ToolParameterConfig {
        ToolParameterConfig(
            toolName: "dicom-query",
            parameters: [
                param("--host", "Host", "DICOM server hostname or IP.", type: .host, required: true),
                param("--port", "Port", "DICOM server port.", type: .port, defaultValue: .int(11112)),
                param("--calling-aet", "Calling AE Title", "Local AE Title.", type: .aeTitle),
                param("--called-aet", "Called AE Title", "Remote AE Title.", type: .aeTitle),
                param("--level", "Query Level", "C-FIND query level.",
                      type: .picker(options: options(["patient", "study", "series", "instance"]))),
                param("--patient-id", "Patient ID", "Patient ID filter.", type: .text(placeholder: "e.g. PAT001")),
                param("--modality", "Modality", "Modality filter (e.g. CT).", type: .text(placeholder: "e.g. CT")),
                param("--study-date", "Study Date", "Study date filter (YYYYMMDD or range).", type: .text(placeholder: "e.g. 20240101"))
            ],
            subcommands: []
        )
    }

    private static func dicomSend() -> ToolParameterConfig {
        ToolParameterConfig(
            toolName: "dicom-send",
            parameters: [
                param("--host", "Host", "Destination DICOM server hostname or IP.", type: .host, required: true),
                param("--port", "Port", "Destination DICOM server port.", type: .port, defaultValue: .int(11112)),
                param("--calling-aet", "Calling AE Title", "Local AE Title.", type: .aeTitle),
                param("--called-aet", "Called AE Title", "Remote AE Title.", type: .aeTitle)
            ],
            subcommands: []
        )
    }

    private static func dicomRetrieve() -> ToolParameterConfig {
        ToolParameterConfig(
            toolName: "dicom-retrieve",
            parameters: [
                param("--host", "Host", "DICOM server hostname or IP.", type: .host, required: true),
                param("--port", "Port", "DICOM server port.", type: .port, defaultValue: .int(11112)),
                param("--calling-aet", "Calling AE Title", "Local AE Title.", type: .aeTitle),
                param("--called-aet", "Called AE Title", "Remote AE Title.", type: .aeTitle),
                param("--study-uid", "Study Instance UID", "UID of the study to retrieve.", type: .text(placeholder: "1.2.840...")),
                param("--method", "Retrieve Method", "DIMSE service to use.",
                      type: .picker(options: options(["c-move", "c-get"]))),
                param("--output-dir", "Output Directory", "Directory for retrieved files.", type: .directoryPath)
            ],
            subcommands: []
        )
    }

    private static func dicomUID() -> ToolParameterConfig {
        ToolParameterConfig(
            toolName: "dicom-uid",
            parameters: [],
            subcommands: [
                ToolSubcommand(
                    name: "generate",
                    displayName: "Generate",
                    description: "Generate one or more new DICOM UIDs.",
                    parameters: [
                        param("--root", "UID Root", "Organisation root for generated UIDs.", type: .text(placeholder: "e.g. 1.2.840.10008")),
                        param("--count", "Count", "Number of UIDs to generate.",
                              type: .number(min: 1, max: 100, step: 1), defaultValue: .int(1))
                    ]
                ),
                ToolSubcommand(
                    name: "validate",
                    displayName: "Validate",
                    description: "Check whether a UID conforms to the DICOM standard.",
                    parameters: [
                        param("--uid", "UID", "UID to validate.", type: .text(placeholder: "1.2.840..."), required: true)
                    ]
                ),
                ToolSubcommand(
                    name: "lookup",
                    displayName: "Lookup",
                    description: "Look up a well-known UID in the DICOM registry.",
                    parameters: [
                        param("--uid", "UID", "UID to look up.", type: .text(placeholder: "1.2.840..."), required: true)
                    ]
                )
            ]
        )
    }

    private static func dicomImage() -> ToolParameterConfig {
        ToolParameterConfig(
            toolName: "dicom-image",
            parameters: [
                param("--input", "Input File", "DICOM file to extract images from.", type: .filePath(allowedExtensions: ["dcm", "dicom"]), required: true),
                param("--output", "Output File", "Path for the exported image.", type: .outputPath(defaultExtension: "png")),
                param("--format", "Image Format", "Output image format.",
                      type: .picker(options: options(["png", "jpeg", "tiff"]))),
                param("--frame-start", "Frame Start", "First frame index (0-based).",
                      type: .number(min: 0, max: 9999, step: 1), defaultValue: .int(0)),
                param("--frame-end", "Frame End", "Last frame index (inclusive).",
                      type: .number(min: 0, max: 9999, step: 1))
            ],
            subcommands: []
        )
    }

    private static func dicomJSON() -> ToolParameterConfig {
        ToolParameterConfig(
            toolName: "dicom-json",
            parameters: [
                param("--input", "Input File", "DICOM file to convert.", type: .filePath(allowedExtensions: ["dcm", "dicom", "json"]), required: true),
                param("--output", "Output File", "Path for the JSON output.", type: .outputPath(defaultExtension: "json")),
                param("--pretty-print", "Pretty Print", "Format JSON output for readability.", type: .toggle)
            ],
            subcommands: []
        )
    }

    // MARK: Private factory helpers

    private static func param(
        _ name: String,
        _ displayName: String,
        _ description: String,
        type paramType: ParameterType,
        required: Bool = false,
        defaultValue: ParameterValue? = nil,
        group: String? = nil
    ) -> ToolParameterDefinition {
        ToolParameterDefinition(
            name: name,
            displayName: displayName,
            description: description,
            type: paramType,
            isRequired: required,
            defaultValue: defaultValue,
            group: group
        )
    }

    private static func options(_ names: [String]) -> [PickerOption] {
        names.map { name in
            PickerOption(
                id: name,
                displayName: name.replacingOccurrences(of: "-", with: " ").capitalized,
                cliValue: name
            )
        }
    }
}

// MARK: - FormRenderingHelpers

/// Helpers for rendering and managing the dynamic parameter form at runtime.
public enum FormRenderingHelpers {

    /// Returns `true` when `entry` should be visible given the currently populated `currentValues`.
    public static func isVisible(entry: ParameterFormEntry, currentValues: [String: ParameterValue]) -> Bool {
        entry.isVisible(currentValues: currentValues)
    }

    /// Builds the CLI command string from `toolName`, an optional `subcommand`, and the current form `entries`.
    public static func generateCommand(
        toolName: String,
        subcommand: String?,
        entries: [ParameterFormEntry]
    ) -> String {
        var parts: [String] = [toolName]
        if let subcommand {
            parts.append(subcommand)
        }

        for entry in entries {
            guard let value = entry.currentValue else { continue }

            switch entry.definition.type {
            case .toggle:
                if case .bool(let flag) = value, flag {
                    parts.append(entry.definition.name)
                }
            default:
                let str = value.stringRepresentation
                if !str.isEmpty {
                    parts.append(entry.definition.name)
                    if str.contains(" ") {
                        parts.append("\"\(str)\"")
                    } else {
                        parts.append(str)
                    }
                }
            }
        }

        return parts.joined(separator: " ")
    }

    /// Returns a copy of `entries` where every entry's value is reset to its `defaultValue` (or `nil`).
    public static func resetToDefaults(entries: [ParameterFormEntry]) -> [ParameterFormEntry] {
        entries.map { entry in
            ParameterFormEntry(
                definition: entry.definition,
                currentValue: entry.definition.defaultValue,
                source: .defaultValue,
                validationError: nil
            )
        }
    }

    /// Returns a copy of `entries` where network-related fields are overwritten by `injection` values.
    public static func applyNetworkInjection(
        to entries: [ParameterFormEntry],
        injection: NetworkInjectionState
    ) -> [ParameterFormEntry] {
        guard injection.isServerConfigured else { return entries }

        let injectionMap: [String: InjectedNetworkParam] = Dictionary(
            uniqueKeysWithValues: injection.injectedParams.map { ($0.parameterName, $0) }
        )

        return entries.map { entry in
            guard let injected = injectionMap[entry.definition.name] else { return entry }
            return ParameterFormEntry(
                definition: entry.definition,
                currentValue: injected.value,
                source: .serverInjected,
                validationError: nil
            )
        }
    }
}

// MARK: - SubcommandHelpers

/// Helpers for resolving subcommand selections and their associated parameters.
public enum SubcommandHelpers {

    /// Returns the active `ToolParameterDefinition` list for `config` and an optional `subcommand` token.
    ///
    /// When `subcommand` is `nil` or the tool has no subcommands, the top-level parameters are returned.
    public static func activeParameters(
        for config: ToolParameterConfig,
        subcommand: String?
    ) -> [ToolParameterDefinition] {
        guard config.hasSubcommands, let subcommand else {
            return config.parameters
        }
        return config.subcommands.first { $0.name == subcommand }?.parameters ?? config.parameters
    }

    /// Returns the ordered list of subcommand token names for `config`.
    public static func subcommandNames(for config: ToolParameterConfig) -> [String] {
        config.subcommands.map(\.name)
    }
}
