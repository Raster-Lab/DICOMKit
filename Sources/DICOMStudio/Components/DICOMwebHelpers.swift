// DICOMwebHelpers.swift
// DICOMStudio
//
// DICOM Studio — Platform-independent helpers for DICOMweb Integration Hub display
// Reference: DICOM PS3.18 (Web Services)

import Foundation

// MARK: - URL Helpers

/// Platform-independent helpers for DICOMweb base URL validation and formatting.
public enum DICOMwebURLHelpers: Sendable {

    /// Known default ports for common DICOMweb servers.
    public static let defaultPorts: [String: Int] = [
        "orthanc": 8042,
        "dcm4chee": 8080,
        "ohif": 3000
    ]

    /// Returns true if the given string is a valid http or https URL.
    public static func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string),
              let scheme = url.scheme else { return false }
        return scheme == "http" || scheme == "https"
    }

    /// Trims whitespace and removes a trailing slash from the URL string.
    public static func normalizeURL(_ string: String) -> String {
        var result = string.trimmingCharacters(in: .whitespaces)
        if result.hasSuffix("/") { result = String(result.dropLast()) }
        return result
    }

    /// Returns a validation error message, or nil if the URL is valid.
    public static func validationError(for urlString: String) -> String? {
        if urlString.trimmingCharacters(in: .whitespaces).isEmpty {
            return "URL must not be empty."
        }
        guard let url = URL(string: urlString) else {
            return "Invalid URL format."
        }
        guard let scheme = url.scheme, scheme == "http" || scheme == "https" else {
            return "URL must use http or https scheme."
        }
        return nil
    }

    /// Returns the host:port portion of the URL, or the full string if parsing fails.
    public static func displayHost(for urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host else {
            return urlString
        }
        if let port = url.port {
            return "\(host):\(port)"
        }
        return host
    }
}

// MARK: - Auth Helpers

/// Platform-independent helpers for DICOMweb authentication display and validation.
public enum DICOMwebAuthHelpers: Sendable {

    /// Returns the human-readable display name for an authentication method.
    public static func displayName(for method: DICOMwebAuthMethod) -> String {
        method.displayName
    }

    /// Returns true if the method requires a bearer token or JWT.
    public static func requiresToken(_ method: DICOMwebAuthMethod) -> Bool {
        method == .bearer || method == .jwt
    }

    /// Returns true if the method requires username and password.
    public static func requiresCredentials(_ method: DICOMwebAuthMethod) -> Bool {
        method == .basic
    }

    /// Returns true if the method uses OAuth 2.0 PKCE flow.
    public static func requiresOAuth(_ method: DICOMwebAuthMethod) -> Bool {
        method == .oauth2PKCE
    }

    /// Returns a partially masked preview of the token for display.
    ///
    /// - Tokens longer than 20 characters: first 8 chars + "..." + last 4 chars.
    /// - Non-empty tokens ≤ 20 characters: "••••••••".
    /// - Empty string: "".
    public static func tokenPreview(for token: String) -> String {
        if token.isEmpty { return "" }
        if token.count > 20 {
            let prefix = String(token.prefix(8))
            let suffix = String(token.suffix(4))
            return "\(prefix)...\(suffix)"
        }
        return "••••••••"
    }

    /// Returns a validation error for the given auth configuration, or nil if valid.
    public static func validationError(
        for method: DICOMwebAuthMethod,
        token: String,
        username: String,
        password: String
    ) -> String? {
        switch method {
        case .none:
            return nil
        case .bearer, .jwt:
            if token.trimmingCharacters(in: .whitespaces).isEmpty {
                return "A token is required for \(method.displayName) authentication."
            }
            return nil
        case .basic:
            if username.trimmingCharacters(in: .whitespaces).isEmpty {
                return "Username is required for Basic Auth."
            }
            if password.isEmpty {
                return "Password is required for Basic Auth."
            }
            return nil
        case .oauth2PKCE:
            return nil
        }
    }
}

// MARK: - TLS Helpers

/// Platform-independent helpers for DICOMweb TLS mode display.
public enum DICOMwebTLSHelpers: Sendable {

    /// Returns the human-readable display name for a TLS mode.
    public static func displayName(for mode: DICOMwebTLSMode) -> String {
        mode.displayName
    }

    /// Returns a brief security description for a TLS mode.
    public static func securityDescription(for mode: DICOMwebTLSMode) -> String {
        switch mode {
        case .none:        return "Unencrypted HTTP connection"
        case .compatible:  return "TLS 1.2+ encryption"
        case .strict:      return "TLS 1.3 only with strict certificate validation"
        case .development: return "TLS with self-signed certificate support (development only)"
        }
    }

    /// Returns the SF Symbol name appropriate for a TLS mode.
    public static func sfSymbol(for mode: DICOMwebTLSMode) -> String {
        switch mode {
        case .none:        return "lock.slash"
        case .compatible:  return "lock"
        case .strict:      return "lock.shield"
        case .development: return "lock.trianglebadge.exclamationmark"
        }
    }

    /// Returns true if the TLS mode is safe for production use.
    public static func isProductionSafe(_ mode: DICOMwebTLSMode) -> Bool {
        mode == .compatible || mode == .strict
    }
}

// MARK: - QIDO-RS Helpers

/// Platform-independent helpers for QIDO-RS query display and formatting.
public enum DICOMwebQIDOHelpers: Sendable {

    /// Returns the human-readable display name for a QIDO query level.
    public static func displayName(for level: QIDOQueryLevel) -> String {
        level.displayName
    }

    /// Returns the URL path suffix for a QIDO query level.
    public static func endpointSuffix(for level: QIDOQueryLevel) -> String {
        switch level {
        case .study:    return "/studies"
        case .series:   return "/series"
        case .instance: return "/instances"
        }
    }

    /// Formats a DICOM patient name (caret-delimited) for display.
    ///
    /// Empty names return "—"; caret-separated components are joined with ", ".
    public static func formatPatientName(_ name: String) -> String {
        if name.isEmpty { return "—" }
        if name.contains("^") {
            return name
                .replacingOccurrences(of: "^", with: ", ")
                .trimmingCharacters(in: .whitespaces)
        }
        return name
    }

    /// Returns a human-readable study date range string.
    public static func formatStudyDate(from: String, to: String) -> String {
        let hasFrom = !from.isEmpty
        let hasTo   = !to.isEmpty
        switch (hasFrom, hasTo) {
        case (false, false): return "Any date"
        case (true,  false): return "From \(from)"
        case (false, true):  return "Until \(to)"
        case (true,  true):  return "\(from) – \(to)"
        }
    }

    /// Builds a short human-readable summary of the non-empty query parameters.
    public static func buildQuerySummary(params: QIDOQueryParams) -> String {
        var parts: [String] = []
        if !params.patientName.isEmpty    { parts.append("Patient: \(params.patientName)") }
        if !params.patientID.isEmpty      { parts.append("ID: \(params.patientID)") }
        if !params.modality.isEmpty       { parts.append("Modality: \(params.modality)") }
        if !params.studyDateFrom.isEmpty || !params.studyDateTo.isEmpty {
            parts.append("Date: \(formatStudyDate(from: params.studyDateFrom, to: params.studyDateTo))")
        }
        if !params.accessionNumber.isEmpty { parts.append("Acc: \(params.accessionNumber)") }
        if !params.studyDescription.isEmpty { parts.append("Desc: \(params.studyDescription)") }
        if parts.isEmpty {
            switch params.queryLevel {
            case .study:    return "All studies"
            case .series:   return "All series"
            case .instance: return "All instances"
            }
        }
        return parts.joined(separator: " | ")
    }

    /// Returns a pagination summary string such as "Showing 1–20 of 100".
    public static func paginationDescription(offset: Int, limit: Int, total: Int?) -> String {
        let first = offset + 1
        let last  = offset + limit
        if let total = total {
            return "Showing \(first)–\(last) of \(total)"
        }
        return "Showing \(first)–\(last)"
    }
}

// MARK: - WADO-RS Helpers

/// Platform-independent helpers for WADO-RS retrieve job display.
public enum DICOMwebWADOHelpers: Sendable {

    /// Returns the human-readable display name for a WADO retrieve mode.
    public static func displayName(for mode: WADORetrieveMode) -> String {
        mode.displayName
    }

    /// Returns the SF Symbol name for a WADO retrieve mode.
    public static func sfSymbol(for mode: WADORetrieveMode) -> String {
        mode.sfSymbol
    }

    /// Returns the SF Symbol name for a WADO retrieve status.
    public static func sfSymbol(for status: WADORetrieveStatus) -> String {
        switch status {
        case .queued:     return "clock"
        case .inProgress: return "arrow.down.circle"
        case .completed:  return "checkmark.circle.fill"
        case .failed:     return "xmark.circle.fill"
        case .cancelled:  return "slash.circle"
        }
    }

    /// Returns a human-readable progress description for a retrieve job.
    public static func progressDescription(job: WADORetrieveJob) -> String {
        guard let total = job.totalInstances, total > 0 else {
            return "Downloading…"
        }
        let pct = Int((Double(job.instancesReceived) / Double(total)) * 100)
        return "\(job.instancesReceived) / \(total) instances (\(pct)%)"
    }

    /// Formats a byte count as a human-readable string (e.g. "1.2 MB").
    public static func formattedBytesReceived(_ bytes: Int64) -> String {
        switch bytes {
        case ..<1024:
            return "\(bytes) B"
        case ..<(1024 * 1024):
            return String(format: "%.1f KB", Double(bytes) / 1024)
        case ..<(1024 * 1024 * 1024):
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        default:
            return String(format: "%.2f GB", Double(bytes) / (1024 * 1024 * 1024))
        }
    }

    /// Formats a transfer rate in bytes/sec, or "—" if nil.
    public static func formattedTransferRate(_ bytesPerSec: Double?) -> String {
        guard let rate = bytesPerSec else { return "—" }
        switch rate {
        case ..<1024:
            return String(format: "%.0f B/s", rate)
        case ..<(1024 * 1024):
            return String(format: "%.1f KB/s", rate / 1024)
        case ..<(1024 * 1024 * 1024):
            return String(format: "%.1f MB/s", rate / (1024 * 1024))
        default:
            return String(format: "%.2f GB/s", rate / (1024 * 1024 * 1024))
        }
    }
}

// MARK: - STOW-RS Helpers

/// Platform-independent helpers for STOW-RS upload job display.
public enum DICOMwebSTOWHelpers: Sendable {

    /// Returns the human-readable display name for an upload status.
    public static func displayName(for status: STOWUploadStatus) -> String {
        status.displayName
    }

    /// Returns the SF Symbol name for an upload status.
    public static func sfSymbol(for status: STOWUploadStatus) -> String {
        switch status {
        case .queued:     return "clock"
        case .validating: return "checkmark.shield"
        case .uploading:  return "arrow.up.circle"
        case .completed:  return "checkmark.circle.fill"
        case .rejected:   return "xmark.circle.fill"
        case .failed:     return "exclamationmark.circle.fill"
        }
    }

    /// Returns a human-readable progress description for an upload job.
    public static func progressDescription(job: STOWUploadJob) -> String {
        guard job.totalFiles > 0 else { return "Preparing…" }
        let pct = Int((Double(job.uploadedFiles) / Double(job.totalFiles)) * 100)
        return "\(job.uploadedFiles) / \(job.totalFiles) files (\(pct)%)"
    }

    /// Returns a description of the duplicate handling policy.
    public static func duplicateHandlingDescription(_ handling: STOWDuplicateHandling) -> String {
        switch handling {
        case .reject:    return "Reject duplicate (return 409)"
        case .overwrite: return "Overwrite existing instance"
        case .ignore:    return "Silently skip duplicates"
        }
    }

    /// Formats a total byte count as a human-readable string.
    public static func formattedTotalSize(_ bytes: Int64) -> String {
        switch bytes {
        case ..<1024:
            return "\(bytes) B"
        case ..<(1024 * 1024):
            return String(format: "%.1f KB", Double(bytes) / 1024)
        case ..<(1024 * 1024 * 1024):
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        default:
            return String(format: "%.2f GB", Double(bytes) / (1024 * 1024 * 1024))
        }
    }
}

// MARK: - UPS-RS Helpers

/// Platform-independent helpers for UPS-RS workitem display and state machine.
public enum DICOMwebUPSHelpers: Sendable {

    /// Returns the human-readable display name for a UPS state.
    public static func displayName(for state: UPSState) -> String {
        state.displayName
    }

    /// Returns the SF Symbol name for a UPS state.
    public static func sfSymbol(for state: UPSState) -> String {
        switch state {
        case .scheduled:  return "calendar"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed:  return "checkmark.circle.fill"
        case .cancelled:  return "xmark.circle.fill"
        }
    }

    /// Returns true if a state transition from `from` to `to` is allowed.
    public static func canTransition(from: UPSState, to: UPSState) -> Bool {
        from.allowedTransitions.contains(to)
    }

    /// Returns the list of states reachable from the given state.
    public static func availableTransitions(from state: UPSState) -> [UPSState] {
        state.allowedTransitions
    }

    /// Returns a color name string representing the visual indicator for a UPS state.
    ///
    /// The returned strings are SwiftUI `Color` property name strings, suitable for
    /// platform-independent storage and lookup (e.g. `.blue`, `.orange`).
    public static func stateColor(for state: UPSState) -> String {
        switch state {
        case .scheduled:  return ".blue"
        case .inProgress: return ".orange"
        case .completed:  return ".green"
        case .cancelled:  return ".red"
        }
    }

    /// Returns the human-readable display name for a UPS event type.
    public static func eventTypeDisplayName(_ type: UPSEventType) -> String {
        type.displayName
    }
}

// MARK: - Performance Helpers

/// Platform-independent helpers for DICOMweb performance statistics display.
public enum DICOMwebPerformanceHelpers: Sendable {

    /// Formats a latency value in milliseconds as a human-readable string.
    ///
    /// Values below 1 ms show "< 1 ms"; values ≥ 1000 ms are shown in seconds.
    public static func formattedLatency(_ ms: Double) -> String {
        if ms < 1 {
            return "< 1 ms"
        } else if ms < 1000 {
            return String(format: "%.0f ms", ms)
        } else {
            return String(format: "%.1f s", ms / 1000)
        }
    }

    /// Formats a compression ratio as a multiplier string, e.g. "2.5×".
    public static func formattedCompressionRatio(_ ratio: Double) -> String {
        String(format: "%.1f×", ratio)
    }

    /// Formats a cache hit rate fraction as a percentage string, e.g. "85.3%".
    public static func formattedHitRate(_ rate: Double) -> String {
        String(format: "%.1f%%", rate * 100)
    }

    /// Formats a connection pool utilization fraction as a percentage string.
    public static func formattedConnectionPoolUtilization(_ fraction: Double) -> String {
        String(format: "%.1f%%", fraction * 100)
    }

    /// Returns a description of active vs maximum HTTP/2 streams.
    public static func http2StreamsDescription(active: Int, max: Int) -> String {
        "\(active) / \(max) active"
    }

    /// Returns a prefetch effectiveness description, e.g. "Hit: 45, Miss: 5 (90.0%)".
    public static func prefetchEffectivenessDescription(hitCount: Int, missCount: Int) -> String {
        let total = hitCount + missCount
        guard total > 0 else { return "Hit: 0, Miss: 0 (0.0%)" }
        let rate = Double(hitCount) / Double(total) * 100
        return String(format: "Hit: %d, Miss: %d (%.1f%%)", hitCount, missCount, rate)
    }

    /// Returns an overall health label based on error rate and average latency.
    ///
    /// - Excellent: errorRate < 1% and averageLatencyMs < 100 ms
    /// - Good: errorRate < 5% and averageLatencyMs < 500 ms
    /// - Degraded: errorRate < 10% and averageLatencyMs < 2000 ms
    /// - Poor: otherwise
    public static func overallHealthDescription(stats: DICOMwebPerformanceStats) -> String {
        let errorRate   = stats.errorRate
        let latency     = stats.averageLatencyMs
        if errorRate < 0.01 && latency < 100   { return "Excellent" }
        if errorRate < 0.05 && latency < 500   { return "Good" }
        if errorRate < 0.10 && latency < 2000  { return "Degraded" }
        return "Poor"
    }
}
