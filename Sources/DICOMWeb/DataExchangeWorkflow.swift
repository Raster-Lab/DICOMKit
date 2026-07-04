import Foundation
import DICOMCore
import DICOMKit
import DICOMDictionary

/// Shared orchestration for `dicom-json` / `dicom-xml` — the single pipeline
/// (read → filter → metadata-only → encode → console lines, and the reverse
/// decode path) used by BOTH the CLIs and DICOMStudio's Workshop executors.
///
/// Before this existed, only the raw `DICOMJSONEncoder`/`DICOMXMLEncoder`
/// primitives were shared: each CLI hand-rolled the pipeline in `main.swift`
/// and the app re-hand-rolled it, so behavior (default output path, write-vs-
/// console) and verbose text had drifted. The CLI's behavior is canonical:
/// output ALWAYS goes to a file (default `<input>.json`/`.xml`/`.dcm`), never
/// to the console.
public enum DataExchangeWorkflow {

    // MARK: - Common options

    public struct Options: Sendable {
        public var reverse: Bool
        public var pretty: Bool
        public var includeEmpty: Bool
        public var inlineThreshold: Int
        public var bulkDataURL: String?
        public var metadataOnly: Bool
        public var filterTags: [String]
        public var verbose: Bool
        /// JSON only: sort keys alphabetically (CLI default; `--no-sort-keys` clears it).
        public var sortKeys: Bool
        /// XML only: include keyword attributes (CLI default; `--no-keywords` clears it).
        public var includeKeywords: Bool

        public init(
            reverse: Bool = false, pretty: Bool = false, includeEmpty: Bool = false,
            inlineThreshold: Int = 1024, bulkDataURL: String? = nil,
            metadataOnly: Bool = false, filterTags: [String] = [], verbose: Bool = false,
            sortKeys: Bool = true, includeKeywords: Bool = true
        ) {
            self.reverse = reverse; self.pretty = pretty; self.includeEmpty = includeEmpty
            self.inlineThreshold = inlineThreshold; self.bulkDataURL = bulkDataURL
            self.metadataOnly = metadataOnly; self.filterTags = filterTags; self.verbose = verbose
            self.sortKeys = sortKeys; self.includeKeywords = includeKeywords
        }
    }

    public enum Format: String, Sendable {
        case json
        case xml

        /// "JSON" / "XML" as spelled in the CLI's console lines.
        var label: String { rawValue.uppercased() }
        /// Default output extension for the forward (DICOM → text) direction.
        var textExtension: String { rawValue }
    }

    public enum WorkflowError: Error, LocalizedError {
        case invalidTag(String)
        case invalidTagFormat(String)

        public var errorDescription: String? {
            switch self {
            case .invalidTag(let s): return "Invalid tag: \(s)"
            case .invalidTagFormat(let s): return "Invalid tag format: \(s). Expected format: GGGG,EEEE"
            }
        }
    }

    // MARK: - Path + console (shared text, CLI-canonical)

    /// Default output path when `--output` is omitted: the input path with its
    /// extension swapped to `.json`/`.xml` (forward) or `.dcm` (reverse).
    public static func defaultOutputPath(input: String, reverse: Bool, format: Format) -> String {
        let inputURL = URL(fileURLWithPath: input)
        let ext = reverse ? "dcm" : format.textExtension
        return inputURL.deletingPathExtension().appendingPathExtension(ext).path
    }

    /// Verbose run header ("Input:/Output:/Mode:" + blank line); empty when not verbose.
    public static func headerLines(
        input: String, output: String, reverse: Bool, format: Format, verbose: Bool
    ) -> [String] {
        guard verbose else { return [] }
        let mode = reverse ? "\(format.label) → DICOM" : "DICOM → \(format.label)"
        return ["Input:  \(input)", "Output: \(output)", "Mode:   \(mode)", ""]
    }

    /// Verbose completion block (blank + "✓ Conversion complete" + size); empty when not verbose.
    public static func completionLines(outputSize: Int64, verbose: Bool) -> [String] {
        guard verbose else { return [] }
        return ["", "✓ Conversion complete", "  Output size: \(formatFileSize(outputSize))"]
    }

    /// The CLIs' shared file-size wording (KB/MB with two decimals, bytes below 1 KB).
    public static func formatFileSize(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        if mb >= 1 { return String(format: "%.2f MB", mb) }
        if kb >= 1 { return String(format: "%.2f KB", kb) }
        return "\(bytes) bytes"
    }

    // MARK: - Filter-tag resolution

    /// Resolves `--filter-tag` specifiers (dictionary keyword or `GGGG,EEEE` hex)
    /// to tags; throws the CLI's exact error on an unresolvable entry.
    public static func resolveFilterTags(_ specs: [String]) throws -> Set<Tag> {
        var tagSet = Set<Tag>()
        for tagString in specs {
            if let entry = DataElementDictionary.lookup(keyword: tagString) {
                tagSet.insert(entry.tag)
            } else if let tag = parseTagString(tagString) {
                tagSet.insert(tag)
            } else {
                throw WorkflowError.invalidTag(tagString)
            }
        }
        return tagSet
    }

    private static func parseTagString(_ string: String) -> Tag? {
        let components = string.split(separator: ",")
        guard components.count == 2,
              let group = UInt16(components[0], radix: 16),
              let element = UInt16(components[1], radix: 16) else { return nil }
        return Tag(group: group, element: element)
    }

    // MARK: - Forward: DICOM → JSON/XML

    /// Converts DICOM bytes to JSON or XML, returning the encoded bytes plus the
    /// CLI's verbose progress lines (empty when not verbose). No file I/O — the
    /// caller reads/writes (the CLI directly; the app via its sandbox-aware
    /// OutputAccess path) and passes its measured read duration so the verbose
    /// text keeps the CLI's exact line shapes.
    public static func encode(
        dicomData: Data, format: Format, options: Options, readSeconds: TimeInterval = 0
    ) throws -> (data: Data, console: [String]) {
        var console: [String] = []
        func vlog(_ line: String) { if options.verbose { console.append(line) } }

        vlog("Read DICOM file: \(formatFileSize(Int64(dicomData.count))) in \(String(format: "%.2f", readSeconds))s")
        let parseStart = Date()
        let dicomFile = try DICOMFile.read(from: dicomData)
        vlog("Parsed DICOM: \(dicomFile.dataSet.allElements.count) elements in \(String(format: "%.2f", Date().timeIntervalSince(parseStart)))s")

        var elements = dicomFile.dataSet.allElements
        if !options.filterTags.isEmpty {
            let tagSet = try resolveFilterTags(options.filterTags)
            elements = elements.filter { tagSet.contains($0.tag) }
            vlog("Filtered to \(elements.count) elements")
        }
        if options.metadataOnly {
            elements = elements.filter { $0.tag != Tag.pixelData }
        }

        let bulkDataBaseURL = options.bulkDataURL.flatMap { URL(string: $0) }
        let threshold = options.inlineThreshold > 0 ? options.inlineThreshold : nil

        let encodeStart = Date()
        let encoded: Data
        switch format {
        case .json:
            let encoder = DICOMJSONEncoder(configuration: .init(
                includeEmptyValues: options.includeEmpty,
                inlineBinaryThreshold: threshold,
                bulkDataBaseURL: bulkDataBaseURL,
                prettyPrinted: options.pretty,
                sortedKeys: options.sortKeys
            ))
            encoded = try encoder.encode(elements)
        case .xml:
            let encoder = DICOMXMLEncoder(configuration: .init(
                includeEmptyValues: options.includeEmpty,
                inlineBinaryThreshold: threshold,
                bulkDataBaseURL: bulkDataBaseURL,
                prettyPrinted: options.pretty,
                includeKeywords: options.includeKeywords
            ))
            encoded = try encoder.encode(elements)
        }
        vlog("Encoded to \(format.label): \(formatFileSize(Int64(encoded.count))) in \(String(format: "%.2f", Date().timeIntervalSince(encodeStart)))s")

        return (encoded, console)
    }

    // MARK: - Reverse: JSON/XML → DICOM

    /// Decodes JSON or XML bytes back to a Part-10 DICOM file, returning the
    /// DICOM bytes plus the CLI's verbose progress lines.
    public static func decode(
        textData: Data, format: Format, options: Options, readSeconds: TimeInterval = 0
    ) throws -> (data: Data, console: [String]) {
        var console: [String] = []
        func vlog(_ line: String) { if options.verbose { console.append(line) } }

        vlog("Read \(format.label) file: \(formatFileSize(Int64(textData.count))) in \(String(format: "%.2f", readSeconds))s")

        let decodeStart = Date()
        let elements: [DataElement]
        switch format {
        case .json:
            let decoder = DICOMJSONDecoder(configuration: .init(
                allowMissingVR: true, fetchBulkData: false, bulkDataHandler: nil))
            elements = try decoder.decode(textData)
        case .xml:
            let decoder = DICOMXMLDecoder(configuration: .init(
                allowMissingVR: true, fetchBulkData: false, bulkDataHandler: nil))
            elements = try decoder.decode(textData)
        }
        vlog("Decoded \(format.label): \(elements.count) elements in \(String(format: "%.2f", Date().timeIntervalSince(decodeStart)))s")

        let createStart = Date()
        let dataSet = DataSet(elements: elements)
        let transferSyntaxUID = dataSet[Tag.transferSyntaxUID]?.stringValue ?? "1.2.840.10008.1.2.1"
        let dicomFile = DICOMFile.create(dataSet: dataSet, transferSyntaxUID: transferSyntaxUID)
        vlog("Created DICOM file in \(String(format: "%.2f", Date().timeIntervalSince(createStart)))s")

        let dicomData = try dicomFile.write()

        return (dicomData, console)
    }

    // MARK: - Write-stage verbose lines (emitted by the caller after persisting)

    /// Forward direction: "Wrote output file in X.XXs" (empty when not verbose).
    public static func forwardWriteLine(seconds: TimeInterval, verbose: Bool) -> [String] {
        verbose ? ["Wrote output file in \(String(format: "%.2f", seconds))s"] : []
    }

    /// Reverse direction: "Wrote DICOM file: SIZE in X.XXs" (empty when not verbose).
    public static func reverseWriteLine(size: Int64, seconds: TimeInterval, verbose: Bool) -> [String] {
        verbose ? ["Wrote DICOM file: \(formatFileSize(size)) in \(String(format: "%.2f", seconds))s"] : []
    }
}
