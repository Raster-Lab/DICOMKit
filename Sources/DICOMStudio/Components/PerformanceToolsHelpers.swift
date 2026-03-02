// PerformanceToolsHelpers.swift
// DICOMStudio
//
// DICOM Studio — Platform-independent helpers for Performance & Developer Tools (Milestone 13)
// Reference: DICOM PS3.2 (Conformance), PS3.5 (Data Structures), PS3.6 (Data Dictionary)

import Foundation

// MARK: - 13.1 Performance Dashboard Helpers

/// Platform-independent helpers for the performance dashboard.
public enum PerformanceDashboardHelpers: Sendable {

    /// Formats a duration in milliseconds as a human-readable string.
    public static func formatDurationMs(_ ms: Double) -> String {
        if ms < 1.0 {
            return String(format: "%.2f µs", ms * 1000.0)
        } else if ms < 1000.0 {
            return String(format: "%.2f ms", ms)
        } else {
            return String(format: "%.2f s", ms / 1000.0)
        }
    }

    /// Formats a hit rate (0.0–1.0) as a percentage string.
    public static func formatHitRate(_ rate: Double) -> String {
        return String(format: "%.1f%%", rate * 100.0)
    }

    /// Formats a memory value in megabytes as a human-readable string.
    public static func formatMemoryMB(_ mb: Double) -> String {
        if mb < 1024.0 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.2f GB", mb / 1024.0)
        }
    }

    /// Returns a performance badge label based on duration.
    /// - Parameters:
    ///   - durationMs: Duration in milliseconds.
    ///   - thresholdFastMs: Threshold in ms below which performance is "Fast".
    ///   - thresholdSlowMs: Threshold in ms above which performance is "Slow".
    public static func performanceBadge(
        durationMs: Double,
        thresholdFastMs: Double = 10.0,
        thresholdSlowMs: Double = 100.0
    ) -> String {
        if durationMs <= thresholdFastMs { return "Fast" }
        if durationMs >= thresholdSlowMs { return "Slow" }
        return "Normal"
    }

    /// Formats a benchmark result as a CSV row.
    public static func benchmarkResultToCSV(_ result: BenchmarkResult) -> String {
        let statusStr = result.status.rawValue
        let durationStr = String(format: "%.3f", result.durationMs)
        let avgStr = String(format: "%.3f", result.averageIterationMs)
        return "\(result.type.displayName),\(result.iterations),\(durationStr),\(avgStr),\(statusStr)"
    }

    /// Returns CSV header for benchmark results export.
    public static func benchmarkCSVHeader() -> String {
        return "Benchmark,Iterations,TotalMs,AvgPerIterationMs,Status"
    }

    /// Exports an array of benchmark results to CSV string.
    public static func exportBenchmarksToCSV(_ results: [BenchmarkResult]) -> String {
        var lines = [benchmarkCSVHeader()]
        lines += results.map { benchmarkResultToCSV($0) }
        return lines.joined(separator: "\n")
    }

    /// Returns a description for a metric comparison (positive = improvement).
    public static func improvementDescription(beforeMs: Double, afterMs: Double) -> String {
        guard beforeMs > 0 else { return "N/A" }
        let ratio = (beforeMs - afterMs) / beforeMs * 100.0
        if ratio > 0 {
            return String(format: "%.1f%% faster", ratio)
        } else if ratio < 0 {
            return String(format: "%.1f%% slower", -ratio)
        }
        return "No change"
    }
}

// MARK: - 13.2 Cache Management Helpers

/// Platform-independent helpers for cache management display.
public enum CacheManagementHelpers: Sendable {

    /// Formats a byte count as a human-readable size string.
    public static func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            let kb = Double(bytes) / 1024.0
            return String(format: "%.1f KB", kb)
        } else if bytes < 1024 * 1024 * 1024 {
            let mb = Double(bytes) / (1024.0 * 1024.0)
            return String(format: "%.1f MB", mb)
        } else {
            let gb = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
            return String(format: "%.2f GB", gb)
        }
    }

    /// Returns a description of cache fill percentage.
    public static func fillDescription(fillPercentage: Double) -> String {
        switch fillPercentage {
        case ..<25.0:  return "Low usage"
        case ..<60.0:  return "Moderate usage"
        case ..<85.0:  return "High usage"
        default:        return "Near capacity"
        }
    }

    /// Returns a brief age description for a cache item.
    public static func ageDescription(ageSeconds: TimeInterval) -> String {
        if ageSeconds < 60 {
            return "Just now"
        } else if ageSeconds < 3600 {
            let minutes = Int(ageSeconds / 60)
            return "\(minutes) min ago"
        } else if ageSeconds < 86400 {
            let hours = Int(ageSeconds / 3600)
            return "\(hours) hr ago"
        } else {
            let days = Int(ageSeconds / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }

    /// Sorts cache items by LRU order (least recently used first).
    public static func sortByLRU(_ items: [CacheItemInfo]) -> [CacheItemInfo] {
        return items.sorted { $0.lastAccessedAt < $1.lastAccessedAt }
    }

    /// Returns the combined size in bytes of a list of cache items.
    public static func totalSizeBytes(of items: [CacheItemInfo]) -> Int {
        return items.reduce(0) { $0 + $1.sizeBytes }
    }
}

// MARK: - 13.3 Tag Dictionary Helpers

/// Platform-independent helpers for the tag dictionary explorer.
public enum TagDictionaryHelpers: Sendable {

    /// Returns true if the tag entry matches the given search query.
    /// Matches against tag number, name, and keyword (case-insensitive).
    public static func matches(entry: DICOMTagEntry, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let q = query.lowercased()
        return entry.tag.lowercased().contains(q)
            || entry.name.lowercased().contains(q)
            || entry.keyword.lowercased().contains(q)
    }

    /// Filters entries by group filter.
    public static func filter(_ entries: [DICOMTagEntry], by group: TagGroupFilter) -> [DICOMTagEntry] {
        switch group {
        case .all:
            return entries
        case .retired:
            return entries.filter { $0.isRetired }
        case .patient:
            return entries.filter { $0.tag.hasPrefix("(0010,") }
        case .study:
            return entries.filter { $0.tag.hasPrefix("(0020,") }
        case .series:
            return entries.filter { $0.tag.hasPrefix("(0008,") }
        case .equipment:
            return entries.filter { $0.tag.hasPrefix("(0008,") || $0.tag.hasPrefix("(0018,") }
        case .image:
            return entries.filter { $0.tag.hasPrefix("(0028,") }
        }
    }

    /// Searches and filters entries by query and group.
    public static func search(
        _ entries: [DICOMTagEntry],
        query: String,
        group: TagGroupFilter
    ) -> [DICOMTagEntry] {
        let filtered = filter(entries, by: group)
        guard !query.isEmpty else { return filtered }
        return filtered.filter { matches(entry: $0, query: query) }
    }

    /// Returns the VR full name for a given VR code.
    public static func vrFullName(for vrCode: String) -> String {
        switch vrCode.uppercased() {
        case "AE": return "Application Entity"
        case "AS": return "Age String"
        case "AT": return "Attribute Tag"
        case "CS": return "Code String"
        case "DA": return "Date"
        case "DS": return "Decimal String"
        case "DT": return "Date Time"
        case "FL": return "Floating Point Single"
        case "FD": return "Floating Point Double"
        case "IS": return "Integer String"
        case "LO": return "Long String"
        case "LT": return "Long Text"
        case "OB": return "Other Byte String"
        case "OD": return "Other Double String"
        case "OF": return "Other Float String"
        case "OL": return "Other Long"
        case "OV": return "Other 64-bit Very Long"
        case "OW": return "Other Word String"
        case "PN": return "Person Name"
        case "SH": return "Short String"
        case "SL": return "Signed Long"
        case "SQ": return "Sequence of Items"
        case "SS": return "Signed Short"
        case "ST": return "Short Text"
        case "SV": return "Signed 64-bit Very Long"
        case "TM": return "Time"
        case "UC": return "Unlimited Characters"
        case "UI": return "Unique Identifier"
        case "UL": return "Unsigned Long"
        case "UN": return "Unknown"
        case "UR": return "Universal Resource Identifier"
        case "US": return "Unsigned Short"
        case "UT": return "Unlimited Text"
        case "UV": return "Unsigned 64-bit Very Long"
        default:   return vrCode
        }
    }

    /// Returns a built-in set of representative DICOM tag entries for display/testing.
    public static func sampleTagEntries() -> [DICOMTagEntry] {
        return [
            DICOMTagEntry(tag: "(0008,0016)", name: "SOP Class UID",       keyword: "SOPClassUID",      vr: "UI", vm: "1",   tagDescription: "Unique identifier for the SOP Class."),
            DICOMTagEntry(tag: "(0008,0018)", name: "SOP Instance UID",    keyword: "SOPInstanceUID",   vr: "UI", vm: "1",   tagDescription: "Unique identifier for the SOP Instance."),
            DICOMTagEntry(tag: "(0008,0020)", name: "Study Date",          keyword: "StudyDate",        vr: "DA", vm: "1",   tagDescription: "Date the study started."),
            DICOMTagEntry(tag: "(0008,0060)", name: "Modality",            keyword: "Modality",         vr: "CS", vm: "1",   tagDescription: "Type of equipment that originally acquired the data."),
            DICOMTagEntry(tag: "(0010,0010)", name: "Patient's Name",      keyword: "PatientName",      vr: "PN", vm: "1",   tagDescription: "Full name of the patient."),
            DICOMTagEntry(tag: "(0010,0020)", name: "Patient ID",          keyword: "PatientID",        vr: "LO", vm: "1",   tagDescription: "Primary hospital identification number for the patient."),
            DICOMTagEntry(tag: "(0010,0030)", name: "Patient's Birth Date",keyword: "PatientBirthDate", vr: "DA", vm: "1",   tagDescription: "Birth date of the patient."),
            DICOMTagEntry(tag: "(0020,000D)", name: "Study Instance UID",  keyword: "StudyInstanceUID", vr: "UI", vm: "1",   tagDescription: "Unique identifier for the study."),
            DICOMTagEntry(tag: "(0020,000E)", name: "Series Instance UID", keyword: "SeriesInstanceUID",vr: "UI", vm: "1",   tagDescription: "Unique identifier for the series."),
            DICOMTagEntry(tag: "(0028,0010)", name: "Rows",                keyword: "Rows",             vr: "US", vm: "1",   tagDescription: "Number of rows in the image."),
            DICOMTagEntry(tag: "(0028,0011)", name: "Columns",             keyword: "Columns",          vr: "US", vm: "1",   tagDescription: "Number of columns in the image."),
            DICOMTagEntry(tag: "(0028,0100)", name: "Bits Allocated",      keyword: "BitsAllocated",    vr: "US", vm: "1",   tagDescription: "Number of bits allocated for each pixel sample."),
            DICOMTagEntry(tag: "(0028,1050)", name: "Window Center",       keyword: "WindowCenter",     vr: "DS", vm: "1-n", tagDescription: "Window center for display."),
            DICOMTagEntry(tag: "(0028,1051)", name: "Window Width",        keyword: "WindowWidth",      vr: "DS", vm: "1-n", tagDescription: "Window width for display."),
            DICOMTagEntry(tag: "(0008,1030)", name: "Study Description",   keyword: "StudyDescription", vr: "LO", vm: "1",   tagDescription: "Institution-generated description or classification of the study."),
        ]
    }
}

// MARK: - 13.4 UID Lookup Helpers

/// Platform-independent helpers for the UID lookup tool.
public enum UIDLookupHelpers: Sendable {

    /// Validates a DICOM UID string.
    /// A valid UID consists of components separated by dots; each component is a non-negative integer
    /// with no leading zeros (except the component "0" itself); max total length 64 characters.
    public static func validate(uid: String) -> UIDValidationResult {
        if uid.isEmpty {
            return UIDValidationResult(uid: uid, isValid: false, errorMessage: "UID must not be empty.")
        }
        if uid.count > 64 {
            return UIDValidationResult(uid: uid, isValid: false, errorMessage: "UID must not exceed 64 characters.")
        }
        let components = uid.split(separator: ".", omittingEmptySubsequences: false)
        if components.isEmpty {
            return UIDValidationResult(uid: uid, isValid: false, errorMessage: "UID must have at least one component.")
        }
        for component in components {
            if component.isEmpty {
                return UIDValidationResult(uid: uid, isValid: false, errorMessage: "UID components must not be empty.")
            }
            if !component.allSatisfy({ $0.isNumber }) {
                return UIDValidationResult(uid: uid, isValid: false, errorMessage: "UID components must contain only digits.")
            }
            if component.count > 1, component.first == "0" {
                return UIDValidationResult(uid: uid, isValid: false, errorMessage: "UID components must not have leading zeros.")
            }
        }
        return UIDValidationResult(uid: uid, isValid: true)
    }

    /// Generates a new DICOM-compliant UID using the DICOMKit root "2.25" prefix
    /// followed by a decimal representation of a UUID.
    public static func generateUID() -> String {
        let uuid = UUID()
        let uuidString = uuid.uuidString.replacingOccurrences(of: "-", with: "")
        // Convert hex UUID to two UInt64 values and format as decimal
        let highHex = String(uuidString.prefix(16))
        let lowHex  = String(uuidString.suffix(16))
        let high = UInt64(highHex, radix: 16) ?? 0
        let low  = UInt64(lowHex,  radix: 16) ?? 0
        return "2.25.\(high)\(low)"
    }

    /// Returns built-in sample UID entries for display/testing.
    public static func sampleUIDEntries() -> [UIDEntry] {
        return [
            UIDEntry(uid: "1.2.840.10008.1.2",     name: "Implicit VR Little Endian",   category: .transferSyntax, uidDescription: "Default transfer syntax (PS3.5 §10.1)"),
            UIDEntry(uid: "1.2.840.10008.1.2.1",   name: "Explicit VR Little Endian",   category: .transferSyntax, uidDescription: "Most widely used transfer syntax"),
            UIDEntry(uid: "1.2.840.10008.1.2.2",   name: "Explicit VR Big Endian",      category: .transferSyntax, uidDescription: "Retired in DICOM 2014"),
            UIDEntry(uid: "1.2.840.10008.1.2.4.50",name: "JPEG Baseline (Process 1)",   category: .transferSyntax, uidDescription: "Lossy JPEG compression"),
            UIDEntry(uid: "1.2.840.10008.1.2.4.70",name: "JPEG Lossless",               category: .transferSyntax, uidDescription: "Lossless JPEG compression"),
            UIDEntry(uid: "1.2.840.10008.1.2.4.90",name: "JPEG 2000 Lossless",         category: .transferSyntax, uidDescription: "JPEG 2000 lossless compression"),
            UIDEntry(uid: "1.2.840.10008.1.2.4.91",name: "JPEG 2000",                  category: .transferSyntax, uidDescription: "JPEG 2000 with optional lossy compression"),
            UIDEntry(uid: "1.2.840.10008.5.1.4.1.1.2",  name: "CT Image Storage",      category: .sopClass,       uidDescription: "Computed Tomography Image Storage"),
            UIDEntry(uid: "1.2.840.10008.5.1.4.1.1.4",  name: "MR Image Storage",      category: .sopClass,       uidDescription: "Magnetic Resonance Image Storage"),
            UIDEntry(uid: "1.2.840.10008.5.1.4.1.1.128",name: "PET Image Storage",     category: .sopClass,       uidDescription: "Positron Emission Tomography Image Storage"),
            UIDEntry(uid: "1.2.840.10008.5.1.4.1.1.6.1",name: "US Image Storage",      category: .sopClass,       uidDescription: "Ultrasound Image Storage"),
            UIDEntry(uid: "1.2.840.10008.5.1.4.1.1.7",  name: "SC Image Storage",      category: .sopClass,       uidDescription: "Secondary Capture Image Storage"),
            UIDEntry(uid: "1.2.840.10008.1.1",     name: "Verification SOP Class",      category: .wellKnown,      uidDescription: "Used for C-ECHO (ping) verification"),
            UIDEntry(uid: "1.2.840.10008.3.1.1.1", name: "DICOM Application Context",   category: .wellKnown,      uidDescription: "Standard DICOM application context name"),
        ]
    }

    // MARK: - Private (none required)
}

// MARK: - 13.5 Transfer Syntax Info Helpers

/// Platform-independent helpers for transfer syntax information display.
public enum TransferSyntaxInfoHelpers: Sendable {

    /// Returns built-in transfer syntax info entries.
    public static func builtInEntries() -> [TransferSyntaxInfoEntry] {
        return [
            TransferSyntaxInfoEntry(
                uid: "1.2.840.10008.1.2",
                name: "Implicit VR Little Endian",
                tsDescription: "Default DICOM transfer syntax. Implicit VR, little-endian byte order, uncompressed pixel data.",
                compressionType: .none, byteOrder: .littleEndian, vrEncoding: .implicit, supportStatus: .supported
            ),
            TransferSyntaxInfoEntry(
                uid: "1.2.840.10008.1.2.1",
                name: "Explicit VR Little Endian",
                tsDescription: "Most common transfer syntax. Explicit VR, little-endian byte order, uncompressed pixel data.",
                compressionType: .none, byteOrder: .littleEndian, vrEncoding: .explicit, supportStatus: .supported
            ),
            TransferSyntaxInfoEntry(
                uid: "1.2.840.10008.1.2.2",
                name: "Explicit VR Big Endian",
                tsDescription: "Retired in DICOM 2014. Explicit VR, big-endian byte order, uncompressed pixel data.",
                compressionType: .none, byteOrder: .bigEndian, vrEncoding: .explicit, supportStatus: .supported
            ),
            TransferSyntaxInfoEntry(
                uid: "1.2.840.10008.1.2.1.99",
                name: "Deflated Explicit VR Little Endian",
                tsDescription: "Deflate-compressed data set. Explicit VR, little-endian.",
                compressionType: .lossless, byteOrder: .littleEndian, vrEncoding: .explicit, supportStatus: .partiallySupported
            ),
            TransferSyntaxInfoEntry(
                uid: "1.2.840.10008.1.2.4.50",
                name: "JPEG Baseline (Process 1)",
                tsDescription: "Lossy JPEG compression using DCT at 8-bit precision.",
                compressionType: .lossy, byteOrder: .littleEndian, vrEncoding: .explicit, supportStatus: .supported
            ),
            TransferSyntaxInfoEntry(
                uid: "1.2.840.10008.1.2.4.51",
                name: "JPEG Extended (Process 2 & 4)",
                tsDescription: "Lossy JPEG compression using DCT at 12-bit precision.",
                compressionType: .lossy, byteOrder: .littleEndian, vrEncoding: .explicit, supportStatus: .supported
            ),
            TransferSyntaxInfoEntry(
                uid: "1.2.840.10008.1.2.4.57",
                name: "JPEG Lossless Non-Hierarchical (Process 14)",
                tsDescription: "Lossless JPEG compression using predictive coding.",
                compressionType: .lossless, byteOrder: .littleEndian, vrEncoding: .explicit, supportStatus: .supported
            ),
            TransferSyntaxInfoEntry(
                uid: "1.2.840.10008.1.2.4.70",
                name: "JPEG Lossless (SV1)",
                tsDescription: "Lossless JPEG compression using the first-order prediction process.",
                compressionType: .lossless, byteOrder: .littleEndian, vrEncoding: .explicit, supportStatus: .supported
            ),
            TransferSyntaxInfoEntry(
                uid: "1.2.840.10008.1.2.4.80",
                name: "JPEG-LS Lossless",
                tsDescription: "ISO JPEG-LS lossless compression.",
                compressionType: .lossless, byteOrder: .littleEndian, vrEncoding: .explicit, supportStatus: .supported
            ),
            TransferSyntaxInfoEntry(
                uid: "1.2.840.10008.1.2.4.81",
                name: "JPEG-LS Near-Lossless",
                tsDescription: "ISO JPEG-LS near-lossless compression with a user-defined tolerance.",
                compressionType: .lossy, byteOrder: .littleEndian, vrEncoding: .explicit, supportStatus: .supported
            ),
            TransferSyntaxInfoEntry(
                uid: "1.2.840.10008.1.2.4.90",
                name: "JPEG 2000 Lossless",
                tsDescription: "ISO JPEG 2000 lossless compression.",
                compressionType: .lossless, byteOrder: .littleEndian, vrEncoding: .explicit, supportStatus: .supported
            ),
            TransferSyntaxInfoEntry(
                uid: "1.2.840.10008.1.2.4.91",
                name: "JPEG 2000",
                tsDescription: "ISO JPEG 2000 compression with optional lossless or lossy coding.",
                compressionType: .lossy, byteOrder: .littleEndian, vrEncoding: .explicit, supportStatus: .supported
            ),
            TransferSyntaxInfoEntry(
                uid: "1.2.840.10008.1.2.4.201",
                name: "High-Throughput JPEG 2000 Lossless",
                tsDescription: "HTJ2K lossless compression (ISO 15444-15).",
                compressionType: .lossless, byteOrder: .littleEndian, vrEncoding: .explicit, supportStatus: .partiallySupported
            ),
            TransferSyntaxInfoEntry(
                uid: "1.2.840.10008.1.2.5",
                name: "RLE Lossless",
                tsDescription: "Run-length encoding lossless compression.",
                compressionType: .lossless, byteOrder: .littleEndian, vrEncoding: .explicit, supportStatus: .supported
            ),
        ]
    }

    /// Returns the display string for a compatibility check between two transfer syntaxes.
    public static func compatibilityNote(from sourceUID: String, to targetUID: String) -> String {
        guard sourceUID != targetUID else {
            return "No conversion needed — source and target are identical."
        }
        let lossy = [
            "1.2.840.10008.1.2.4.50",
            "1.2.840.10008.1.2.4.51",
            "1.2.840.10008.1.2.4.81",
            "1.2.840.10008.1.2.4.91",
        ]
        if lossy.contains(targetUID) {
            return "⚠ Converting to a lossy transfer syntax will irreversibly reduce image quality."
        }
        return "Conversion is available without quality loss."
    }
}

// MARK: - 13.6 Conformance Statement Helpers

/// Platform-independent helpers for the conformance statement viewer.
public enum ConformanceStatementHelpers: Sendable {

    /// Returns the built-in DICOMKit network service capability matrix.
    public static func networkCapabilities() -> [ConformanceCapabilityEntry] {
        return [
            ConformanceCapabilityEntry(serviceCategory: .dicomNetworking, serviceName: "C-ECHO",  status: .supported,    notes: "Verification SOP Class (PS3.7 §9.1)"),
            ConformanceCapabilityEntry(serviceCategory: .dicomNetworking, serviceName: "C-FIND",  status: .supported,    notes: "Query/Retrieve SCU: Study, Series, Instance (PS3.4 §C)"),
            ConformanceCapabilityEntry(serviceCategory: .dicomNetworking, serviceName: "C-MOVE",  status: .supported,    notes: "Retrieve SCU (PS3.4 §C.4)"),
            ConformanceCapabilityEntry(serviceCategory: .dicomNetworking, serviceName: "C-GET",   status: .supported,    notes: "Retrieve SCU (PS3.4 §C.5)"),
            ConformanceCapabilityEntry(serviceCategory: .dicomNetworking, serviceName: "C-STORE", status: .supported,    notes: "Storage SCU and SCP (PS3.4 §B)"),
            ConformanceCapabilityEntry(serviceCategory: .dicomNetworking, serviceName: "N-ACTION",status: .supported,    notes: "Used for MPPS and Print Management"),
            ConformanceCapabilityEntry(serviceCategory: .dicomNetworking, serviceName: "N-CREATE",status: .supported,    notes: "Used for MPPS and Print Management"),
            ConformanceCapabilityEntry(serviceCategory: .dicomNetworking, serviceName: "N-SET",   status: .supported,    notes: "Used for MPPS finalization"),
            ConformanceCapabilityEntry(serviceCategory: .dicomNetworking, serviceName: "N-GET",   status: .supported,    notes: "Used for Print Management"),
            ConformanceCapabilityEntry(serviceCategory: .dicomNetworking, serviceName: "N-DELETE",status: .supported,    notes: "Used for Print Film Session management"),
            ConformanceCapabilityEntry(serviceCategory: .dicomNetworking, serviceName: "N-EVENT-REPORT", status: .supported, notes: "Used for Storage Commitment"),
            ConformanceCapabilityEntry(serviceCategory: .dicomweb,        serviceName: "WADO-RS", status: .supported,    notes: "DICOMweb retrieve (PS3.18 §10)"),
            ConformanceCapabilityEntry(serviceCategory: .dicomweb,        serviceName: "STOW-RS", status: .supported,    notes: "DICOMweb store (PS3.18 §10.5)"),
            ConformanceCapabilityEntry(serviceCategory: .dicomweb,        serviceName: "QIDO-RS", status: .supported,    notes: "DICOMweb query (PS3.18 §10.6)"),
            ConformanceCapabilityEntry(serviceCategory: .dicomweb,        serviceName: "UPS-RS",  status: .supported,    notes: "Unified Procedure Step (PS3.18 §11)"),
            ConformanceCapabilityEntry(serviceCategory: .dicomweb,        serviceName: "WADO-URI",status: .supported,    notes: "Legacy WADO (PS3.18 §9)"),
        ]
    }

    /// Returns the built-in SOP Class entries.
    public static func sopClassEntries() -> [SOPClassEntry] {
        return [
            SOPClassEntry(uid: "1.2.840.10008.1.1",          name: "Verification",                      role: .both, supportedTransferSyntaxUIDs: ["1.2.840.10008.1.2.1"]),
            SOPClassEntry(uid: "1.2.840.10008.5.1.4.1.1.2",  name: "CT Image Storage",                  role: .both, supportedTransferSyntaxUIDs: ["1.2.840.10008.1.2", "1.2.840.10008.1.2.1", "1.2.840.10008.1.2.4.70", "1.2.840.10008.1.2.4.90", "1.2.840.10008.1.2.4.91"]),
            SOPClassEntry(uid: "1.2.840.10008.5.1.4.1.1.4",  name: "MR Image Storage",                  role: .both, supportedTransferSyntaxUIDs: ["1.2.840.10008.1.2", "1.2.840.10008.1.2.1", "1.2.840.10008.1.2.4.70", "1.2.840.10008.1.2.4.90"]),
            SOPClassEntry(uid: "1.2.840.10008.5.1.4.1.1.128",name: "PET Image Storage",                 role: .both, supportedTransferSyntaxUIDs: ["1.2.840.10008.1.2", "1.2.840.10008.1.2.1"]),
            SOPClassEntry(uid: "1.2.840.10008.5.1.4.1.1.6.1",name: "Ultrasound Image Storage",          role: .both, supportedTransferSyntaxUIDs: ["1.2.840.10008.1.2.1", "1.2.840.10008.1.2.4.50"]),
            SOPClassEntry(uid: "1.2.840.10008.5.1.4.1.1.7",  name: "Secondary Capture Image Storage",   role: .both, supportedTransferSyntaxUIDs: ["1.2.840.10008.1.2.1"]),
            SOPClassEntry(uid: "1.2.840.10008.5.1.4.1.1.88.22",  name: "Enhanced SR Storage",           role: .both, supportedTransferSyntaxUIDs: ["1.2.840.10008.1.2.1"]),
            SOPClassEntry(uid: "1.2.840.10008.5.1.4.1.1.104.1",  name: "Encapsulated PDF Storage",      role: .both, supportedTransferSyntaxUIDs: ["1.2.840.10008.1.2.1"]),
            SOPClassEntry(uid: "1.2.840.10008.5.1.4.1.1.481.3",  name: "RT Structure Set Storage",      role: .both, supportedTransferSyntaxUIDs: ["1.2.840.10008.1.2.1"]),
            SOPClassEntry(uid: "1.2.840.10008.5.1.4.34.6.4",     name: "Unified Procedure Step",        role: .scu,  supportedTransferSyntaxUIDs: ["1.2.840.10008.1.2.1"]),
            SOPClassEntry(uid: "1.2.840.10008.5.1.4.1.2.1.1",    name: "Study Root Q/R - FIND",         role: .scu,  supportedTransferSyntaxUIDs: ["1.2.840.10008.1.2.1"]),
            SOPClassEntry(uid: "1.2.840.10008.5.1.4.1.2.1.2",    name: "Study Root Q/R - MOVE",         role: .scu,  supportedTransferSyntaxUIDs: ["1.2.840.10008.1.2.1"]),
            SOPClassEntry(uid: "1.2.840.10008.5.1.4.1.2.1.3",    name: "Study Root Q/R - GET",          role: .scu,  supportedTransferSyntaxUIDs: ["1.2.840.10008.1.2.1"]),
        ]
    }

    /// Returns the DICOMKit version string for the conformance statement header.
    public static func dicomkitVersion() -> String { return "1.0.0" }

    /// Returns the DICOM standard version reflected in this conformance statement.
    public static func dicomStandardVersion() -> String { return "DICOM 2026a" }

    /// Filters capability entries by service category.
    public static func capabilities(
        _ entries: [ConformanceCapabilityEntry],
        for category: ConformanceServiceCategory
    ) -> [ConformanceCapabilityEntry] {
        return entries.filter { $0.serviceCategory == category }
    }
}
