// WaveformHelpers.swift
// DICOMStudio
//
// DICOM Studio — Platform-independent ECG and hemodynamic waveform display helpers
// Reference: DICOM PS3.3 C.10.9 (Waveform Module), A.34 (Waveform IODs)

import Foundation

/// Platform-independent helpers for waveform (ECG, hemodynamic, audio) display.
public enum WaveformHelpers: Sendable {

    // MARK: - Channel Labels

    /// Standard 12-lead ECG channel labels in clinical order.
    public static func standardECGLeadLabels() -> [String] {
        ["I", "II", "III", "aVR", "aVL", "aVF", "V1", "V2", "V3", "V4", "V5", "V6"]
    }

    /// Common hemodynamic monitoring channel labels.
    public static func hemodynamicChannelLabels() -> [String] {
        ["Art BP", "CVP", "PAP", "PCWP", "ECG", "SpO2", "Resp"]
    }

    // MARK: - SOP Class Display

    /// Returns an SF Symbol name appropriate for the given Waveform SOP Class UID.
    public static func sfSymbolForSopClass(_ sopClassUID: String) -> String {
        if sopClassUID.contains("9.1") { return "waveform.ecg" }
        if sopClassUID.contains("9.2") { return "heart" }
        if sopClassUID.contains("9.4") { return "waveform" }
        if sopClassUID.contains("9.6") { return "lungs" }
        return "waveform"
    }

    /// Returns a human-readable display name for a known Waveform SOP Class UID.
    public static func displayNameForSopClass(_ sopClassUID: String) -> String {
        // Map the tail of the standard waveform SOP class UIDs
        if sopClassUID.hasSuffix("9.1.1") { return "12-Lead ECG" }
        if sopClassUID.hasSuffix("9.1.2") { return "General ECG" }
        if sopClassUID.hasSuffix("9.1.3") { return "Ambulatory ECG" }
        if sopClassUID.hasSuffix("9.2.1") { return "Hemodynamic" }
        if sopClassUID.hasSuffix("9.3.1") { return "Cardiac EP" }
        if sopClassUID.hasSuffix("9.4.1") { return "Voice Audio" }
        if sopClassUID.hasSuffix("9.4.2") { return "General Audio" }
        if sopClassUID.hasSuffix("9.5.1") { return "Arterial Pulse" }
        if sopClassUID.hasSuffix("9.6.1") { return "Respiratory" }
        return "Waveform"
    }

    // MARK: - Grid

    /// Calculates the number of major grid lines for the given time range and paper speed.
    ///
    /// Standard ECG grid: 25 mm per second at 25 mm/s.
    public static func gridLineCount(timeRangeSeconds: Double, paperSpeed: Double) -> Int {
        Int(timeRangeSeconds * paperSpeed / 25.0) + 1
    }

    // MARK: - Formatting

    /// Formats a duration in milliseconds for display.
    ///
    /// Values below 1000 ms are shown as `"X ms"`; ≥1000 ms as `"X.X s"`.
    public static func formatDuration(_ ms: Double) -> String {
        if ms < 1000.0 {
            return String(format: "%.0f ms", ms)
        }
        return String(format: "%.1f s", ms / 1000.0)
    }

    // MARK: - Heart Rate

    /// Calculates heart rate in beats per minute from an RR interval in milliseconds.
    public static func calculateHeartRate(rrIntervalMs: Double) -> Double {
        guard rrIntervalMs > 0 else { return 0 }
        return 60000.0 / rrIntervalMs
    }

    // MARK: - Sample / Time Conversion

    /// Converts a sample index to a time position in seconds.
    public static func sampleToTime(sampleIndex: Int, samplingFrequency: Double) -> Double {
        guard samplingFrequency > 0 else { return 0 }
        return Double(sampleIndex) / samplingFrequency
    }

    /// Normalizes a waveform sample value to [0, 1], clamping outside the range.
    public static func normalizedSample(_ value: Double, min: Double, max: Double) -> Double {
        guard max > min else { return 0.0 }
        return Swift.min(Swift.max((value - min) / (max - min), 0.0), 1.0)
    }

    // MARK: - Type Description

    /// Returns a brief waveform category string for the given SOP Class UID.
    public static func waveformTypeDescription(sopClassUID: String) -> String {
        if sopClassUID.contains("9.1") { return "ECG" }
        if sopClassUID.contains("9.2") { return "Hemodynamic" }
        if sopClassUID.contains("9.4") { return "Audio" }
        return "Waveform"
    }
}
