// MetadataPresenter.swift
// DICOMCLITools
//
// Shared rendering logic for `dicom-info`. Used by both the CLI executable
// and the DICOMStudio GUI's CLI Workshop so the two produce byte-identical
// output for the same inputs and parameters.

import Foundation
import DICOMKit
import DICOMCore
import DICOMDictionary
import J2KCore
import J2KCodec

/// Output format selector for `dicom-info`.
public enum MetadataOutputFormat: String, CaseIterable, Sendable {
    case text
    case json
    case csv
}

/// Presents DICOM metadata in various output formats.
///
/// The formatting is intentionally identical to what the `dicom-info`
/// command-line tool produces; both the CLI and the DICOMStudio GUI feed
/// inputs through this type so the shown output matches the shell output
/// byte for byte.
public struct MetadataPresenter {
    public let file: DICOMFile
    public let filterTags: [String]
    public let includePrivate: Bool
    public let showStats: Bool

    public init(
        file: DICOMFile,
        filterTags: [String] = [],
        includePrivate: Bool = false,
        showStats: Bool = false
    ) {
        self.file = file
        // Normalize filter tokens: callers may pass either an array of separate
        // values, or a single string containing comma/whitespace-separated
        // values (e.g. "PatientName, Modality"). Split, trim, and de-duplicate
        // so multi-tag filtering works the same way in every code path.
        self.filterTags = MetadataPresenter.normalizeFilterTokens(filterTags)
        self.includePrivate = includePrivate
        self.showStats = showStats
    }

    /// Splits each entry on commas and whitespace, trims, removes empties,
    /// and de-duplicates while preserving order. Adjacent pairs of 4-hex-digit
    /// tokens are re-joined as `GGGG,EEEE` so a numeric tag like `0010,0010`
    /// is treated as one filter rather than two `0010` substrings.
    public static func normalizeFilterTokens(_ raw: [String]) -> [String] {
        var pieces: [String] = []
        for entry in raw {
            for chunk in entry.split(whereSeparator: { $0 == "," || $0.isWhitespace }) {
                let token = String(chunk).trimmingCharacters(in: .whitespaces)
                if !token.isEmpty { pieces.append(token) }
            }
        }
        // Merge adjacent 4-hex pairs back into "GGGG,EEEE" form.
        var merged: [String] = []
        var i = 0
        while i < pieces.count {
            if i + 1 < pieces.count,
               isFourHex(pieces[i]),
               isFourHex(pieces[i + 1]) {
                merged.append("\(pieces[i]),\(pieces[i + 1])")
                i += 2
            } else {
                merged.append(pieces[i])
                i += 1
            }
        }
        // De-duplicate (case-insensitive), preserve order.
        var seen = Set<String>()
        var result: [String] = []
        for token in merged {
            let key = token.lowercased()
            if seen.insert(key).inserted {
                result.append(token)
            }
        }
        return result
    }

    /// Returns true when `s` is exactly four hexadecimal digits.
    private static func isFourHex(_ s: String) -> Bool {
        s.count == 4 && s.allSatisfy { $0.isHexDigit }
    }

    /// Returns true when `tag` matches any of the configured filter tokens.
    /// A filter matches when a token is contained (case-insensitive) in any of:
    ///   - the dictionary `name`            (e.g. "Patient's Name")
    ///   - the dictionary `keyword`         (e.g. "PatientName")
    ///   - the canonical tag description    (e.g. "(0010,0010)")
    ///   - the bare "GGGG,EEEE" form        (e.g. "0010,0010")
    ///   - the packed "GGGGEEEE" form       (e.g. "00100010")
    func matchesFilter(tag: Tag) -> Bool {
        if filterTags.isEmpty { return true }
        let entry = DataElementDictionary.lookup(tag: tag)
        let name = entry?.name ?? ""
        let keyword = entry?.keyword ?? ""
        let description = tag.description
        let bareNumeric = String(format: "%04X,%04X", tag.group, tag.element)
        let packedNumeric = String(format: "%04X%04X", tag.group, tag.element)
        for filter in filterTags {
            if name.localizedCaseInsensitiveContains(filter)
                || keyword.localizedCaseInsensitiveContains(filter)
                || description.localizedCaseInsensitiveContains(filter)
                || bareNumeric.localizedCaseInsensitiveContains(filter)
                || packedNumeric.localizedCaseInsensitiveContains(filter) {
                return true
            }
        }
        return false
    }

    public func render(format: MetadataOutputFormat) throws -> String {
        switch format {
        case .text:
            return renderPlainText()
        case .json:
            return try renderJSON()
        case .csv:
            return renderCSV()
        }
    }

    // MARK: - Plain Text Output

    private func renderPlainText() -> String {
        var output = ""

        if showStats {
            output += renderFileStatistics()
            output += "\n"

            let tsUID = file.fileMetaInformation.string(for: .transferSyntaxUID) ?? ""
            if isJ2KTransferSyntax(tsUID) {
                output += renderJ2KSection(tsUID: tsUID)
                output += "\n"
            }
        }

        output += "=== File Meta Information ===\n"
        output += renderDataSetAsText(file.fileMetaInformation)
        output += "\n=== Main Data Set ===\n"
        output += renderDataSetAsText(file.dataSet)

        return output
    }

    private func renderFileStatistics() -> String {
        var stats = "=== File Statistics ===\n"

        if let transferSyntax = file.fileMetaInformation.string(for: .transferSyntaxUID) {
            stats += "Transfer Syntax: \(transferSyntax)\n"
        }

        if let sopClass = file.dataSet.string(for: .sopClassUID) {
            stats += "SOP Class: \(sopClass)\n"
        }

        if let modality = file.dataSet.string(for: .modality) {
            stats += "Modality: \(modality)\n"
        }

        return stats
    }

    private func renderDataSetAsText(_ dataSet: DataSet) -> String {
        var lines: [String] = []
        let allTags = dataSet.tags

        for tag in allTags {
            guard let element = dataSet[tag] else { continue }

            // Skip private tags unless requested
            if tag.isPrivate && !includePrivate {
                continue
            }

            // Filter by tag name/keyword/number if specified
            guard matchesFilter(tag: tag) else { continue }

            let valueStr = formatElementValue(element)
            let tagName = DataElementDictionary.lookup(tag: tag)?.name ?? "Unknown"
            let paddedName = tagName.count >= 40
                ? tagName
                : tagName + String(repeating: " ", count: 40 - tagName.count)
            let line = "\(tag.description) \(paddedName) VR=\(element.vr.rawValue) \(valueStr)"
            lines.append(line)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - JSON Output

    private func renderJSON() throws -> String {
        var jsonDict: [String: Any] = [:]

        if showStats {
            jsonDict["statistics"] = buildStatisticsDict()
        }

        jsonDict["fileMetaInformation"] = buildDataSetDict(file.fileMetaInformation)
        jsonDict["dataSet"] = buildDataSetDict(file.dataSet)

        let jsonData = try JSONSerialization.data(withJSONObject: jsonDict, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? ""
    }

    private func buildStatisticsDict() -> [String: String] {
        var stats: [String: String] = [:]

        if let transferSyntax = file.fileMetaInformation.string(for: .transferSyntaxUID) {
            stats["transferSyntax"] = transferSyntax
        }

        if let sopClass = file.dataSet.string(for: .sopClassUID) {
            stats["sopClass"] = sopClass
        }

        if let modality = file.dataSet.string(for: .modality) {
            stats["modality"] = modality
        }

        // Add J2K metadata when transfer syntax is JPEG 2000
        let tsUID = file.fileMetaInformation.string(for: .transferSyntaxUID) ?? ""
        if isJ2KTransferSyntax(tsUID) {
            let j2kInfo = buildJ2KMetadataDict(tsUID: tsUID)
            for (key, value) in j2kInfo {
                stats["j2k_\(key)"] = value
            }
        }

        return stats
    }

    private func buildDataSetDict(_ dataSet: DataSet) -> [[String: Any]] {
        var elements: [[String: Any]] = []
        let allTags = dataSet.tags

        for tag in allTags {
            guard let element = dataSet[tag] else { continue }

            if tag.isPrivate && !includePrivate {
                continue
            }

            guard matchesFilter(tag: tag) else { continue }

            var elementDict: [String: Any] = [
                "tag": tag.description,
                "name": DataElementDictionary.lookup(tag: tag)?.name ?? "Unknown",
                "vr": element.vr.rawValue
            ]

            if let stringValue = element.stringValue {
                elementDict["value"] = stringValue
            }

            elements.append(elementDict)
        }

        return elements
    }

    // MARK: - CSV Output

    private func renderCSV() -> String {
        var csv = "Tag,Name,VR,Value\n"

        let allElements = collectAllElements()

        for (tag, element) in allElements {
            let valueStr = formatElementValue(element).replacingOccurrences(of: "\"", with: "\"\"")
            let tagName = DataElementDictionary.lookup(tag: tag)?.name ?? "Unknown"
            let line = "\"\(tag.description)\",\"\(tagName)\",\"\(element.vr.rawValue)\",\"\(valueStr)\"\n"
            csv += line
        }

        return csv
    }

    // MARK: - Helper Methods

    private func collectAllElements() -> [(Tag, DataElement)] {
        var results: [(Tag, DataElement)] = []

        for tag in file.fileMetaInformation.tags {
            guard let element = file.fileMetaInformation[tag] else { continue }
            if shouldIncludeElement(tag: tag) {
                results.append((tag, element))
            }
        }

        for tag in file.dataSet.tags {
            guard let element = file.dataSet[tag] else { continue }
            if shouldIncludeElement(tag: tag) {
                results.append((tag, element))
            }
        }

        return results
    }

    private func shouldIncludeElement(tag: Tag) -> Bool {
        if tag.isPrivate && !includePrivate {
            return false
        }
        return matchesFilter(tag: tag)
    }

    private func formatElementValue(_ element: DataElement) -> String {
        if let stringValue = element.stringValue {
            if stringValue.count > 80 {
                return String(stringValue.prefix(77)) + "..."
            }
            return stringValue
        }

        let valueLength = element.length
        if valueLength > 1024 {
            let mb = Double(valueLength) / 1_048_576.0
            return String(format: "<Binary data: %.2f MB>", mb)
        } else if valueLength > 0 {
            return "<Binary data: \(valueLength) bytes>"
        }

        return ""
    }

    // MARK: - JPEG 2000 Metadata

    private static let j2kTransferSyntaxUIDs: Set<String> = [
        "1.2.840.10008.1.2.4.90",   // JPEG 2000 Lossless
        "1.2.840.10008.1.2.4.91",   // JPEG 2000 (Lossy or Lossless)
        "1.2.840.10008.1.2.4.92",   // JPEG 2000 Part 2 Lossless
        "1.2.840.10008.1.2.4.93",   // JPEG 2000 Part 2
        "1.2.840.10008.1.2.4.201",  // HTJ2K Lossless (RPCL)
        "1.2.840.10008.1.2.4.202",  // HTJ2K Lossless
        "1.2.840.10008.1.2.4.203",  // HTJ2K RPCL Lossless
        "1.2.840.10008.1.2.4.204"   // HTJ2K (Lossy)
    ]

    private func isJ2KTransferSyntax(_ uid: String) -> Bool {
        MetadataPresenter.j2kTransferSyntaxUIDs.contains(uid)
    }

    private func j2kTransferSyntaxLabel(_ uid: String) -> String {
        switch uid {
        case "1.2.840.10008.1.2.4.90": return "JPEG 2000 Image Compression (Lossless Only)"
        case "1.2.840.10008.1.2.4.91": return "JPEG 2000 Image Compression"
        case "1.2.840.10008.1.2.4.92": return "JPEG 2000 Part 2 Lossless"
        case "1.2.840.10008.1.2.4.93": return "JPEG 2000 Part 2"
        case "1.2.840.10008.1.2.4.201": return "HTJ2K Lossless (RPCL)"
        case "1.2.840.10008.1.2.4.202": return "HTJ2K Lossless"
        case "1.2.840.10008.1.2.4.203": return "HTJ2K RPCL Lossless Only"
        case "1.2.840.10008.1.2.4.204": return "HTJ2K (Lossy)"
        default: return "JPEG 2000 (unknown variant)"
        }
    }

    private func firstEncapsulatedFragment() -> Data? {
        guard let pixelElement = file.dataSet[.pixelData],
              let fragments = pixelElement.encapsulatedFragments,
              let first = fragments.first else {
            return nil
        }
        return first
    }

    private func renderJ2KSection(tsUID: String) -> String {
        var lines = ["=== JPEG 2000 Codestream Info ==="]
        lines.append("Transfer Syntax : \(j2kTransferSyntaxLabel(tsUID))")
        lines.append("UID             : \(tsUID)")
        
        let isHTJ2K = tsUID.hasPrefix("1.2.840.10008.1.2.4.20")
        lines.append("HTJ2K           : \(isHTJ2K ? "Yes" : "No")")
        
        if let fragment = firstEncapsulatedFragment() {
            lines.append("First fragment  : \(fragment.count) bytes")
            
            // Quick HTJ2K capability check via marker inspection
            let capResult = J2KHTInteroperabilityValidator()
                .validateCapabilitySignaling(codestream: fragment)
            lines.append("HTJ2K (CAP mrk) : \(capResult.isHTJ2K ? "Yes" : "No")")
            if capResult.isMixedMode {
                lines.append("Mixed mode      : Yes")
            }
            if !capResult.warnings.isEmpty {
                lines.append("Warnings        : \(capResult.warnings.joined(separator: "; "))")
            }
        } else {
            lines.append("Pixel data      : Not found or uncompressed")
        }
        
        if let frameStr = file.dataSet.string(for: .numberOfFrames) {
            lines.append("Frames          : \(frameStr)")
        }
        if let rows = file.dataSet.string(for: .rows) {
            lines.append("Rows            : \(rows)")
        }
        if let cols = file.dataSet.string(for: .columns) {
            lines.append("Columns         : \(cols)")
        }
        if let bitsAlloc = file.dataSet.string(for: .bitsAllocated) {
            lines.append("Bits Allocated  : \(bitsAlloc)")
        }
        
        return lines.joined(separator: "\n") + "\n"
    }
    
    private func buildJ2KMetadataDict(tsUID: String) -> [String: String] {
        var info: [String: String] = [:]
        info["transferSyntaxLabel"] = j2kTransferSyntaxLabel(tsUID)
        info["isHTJ2K"] = tsUID.hasPrefix("1.2.840.10008.1.2.4.20") ? "true" : "false"
        
        if let fragment = firstEncapsulatedFragment() {
            let capResult = J2KHTInteroperabilityValidator()
                .validateCapabilitySignaling(codestream: fragment)
            info["capMarkerHTJ2K"] = capResult.isHTJ2K ? "true" : "false"
            info["isMixedMode"] = capResult.isMixedMode ? "true" : "false"
            info["firstFragmentBytes"] = "\(fragment.count)"
        }
        
        return info
    }
}
