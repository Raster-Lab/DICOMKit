// WaveformHelpersTests.swift
// DICOMStudioTests

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Waveform Helpers Tests")
struct WaveformHelpersTests {

    // MARK: - standardECGLeadLabels

    @Test("standardECGLeadLabels returns 12 labels")
    func testStandardECGLeadLabelsCount() {
        let labels = WaveformHelpers.standardECGLeadLabels()
        #expect(labels.count == 12)
    }

    @Test("standardECGLeadLabels first label is I")
    func testStandardECGLeadLabelsFirst() {
        let labels = WaveformHelpers.standardECGLeadLabels()
        #expect(labels.first == "I")
    }

    @Test("standardECGLeadLabels last label is V6")
    func testStandardECGLeadLabelsLast() {
        let labels = WaveformHelpers.standardECGLeadLabels()
        #expect(labels.last == "V6")
    }

    // MARK: - hemodynamicChannelLabels

    @Test("hemodynamicChannelLabels returns non-empty list")
    func testHemodynamicChannelLabelsNonEmpty() {
        let labels = WaveformHelpers.hemodynamicChannelLabels()
        #expect(!labels.isEmpty)
    }

    @Test("hemodynamicChannelLabels includes Art BP")
    func testHemodynamicChannelLabelsContainsArtBP() {
        let labels = WaveformHelpers.hemodynamicChannelLabels()
        #expect(labels.contains("Art BP"))
    }

    // MARK: - displayNameForSopClass

    @Test("displayNameForSopClass 12-lead ECG UID returns 12-Lead ECG")
    func testDisplayNameForSopClassECG() {
        let name = WaveformHelpers.displayNameForSopClass("1.2.840.10008.5.1.4.1.1.9.1.1")
        #expect(name == "12-Lead ECG")
    }

    @Test("displayNameForSopClass hemodynamic UID returns Hemodynamic")
    func testDisplayNameForSopClassHemodynamic() {
        let name = WaveformHelpers.displayNameForSopClass("1.2.840.10008.5.1.4.1.1.9.2.1")
        #expect(name == "Hemodynamic")
    }

    @Test("displayNameForSopClass unknown UID returns Waveform")
    func testDisplayNameForSopClassUnknown() {
        let name = WaveformHelpers.displayNameForSopClass("1.2.3.4.5.6")
        #expect(name == "Waveform")
    }

    @Test("displayNameForSopClass respiratory UID returns Respiratory")
    func testDisplayNameForSopClassRespiratory() {
        let name = WaveformHelpers.displayNameForSopClass("1.2.840.10008.5.1.4.1.1.9.6.1")
        #expect(name == "Respiratory")
    }

    // MARK: - gridLineCount

    @Test("gridLineCount returns reasonable value for 10 seconds at 25mm/s")
    func testGridLineCountStandard() {
        let count = WaveformHelpers.gridLineCount(timeRangeSeconds: 10.0, paperSpeed: 25.0)
        #expect(count > 0)
        #expect(count == 11) // Int(10 * 25 / 25) + 1
    }

    // MARK: - formatDuration

    @Test("formatDuration for 120 ms contains ms")
    func testFormatDuration120ms() {
        let s = WaveformHelpers.formatDuration(120.0)
        #expect(s.contains("ms"))
    }

    @Test("formatDuration for 1200 ms contains s")
    func testFormatDuration1200ms() {
        let s = WaveformHelpers.formatDuration(1200.0)
        #expect(s.contains("s"))
    }

    // MARK: - calculateHeartRate

    @Test("calculateHeartRate for 600 ms RR is 100 bpm")
    func testCalculateHeartRate600ms() {
        let hr = WaveformHelpers.calculateHeartRate(rrIntervalMs: 600.0)
        #expect(abs(hr - 100.0) < 0.01)
    }

    @Test("calculateHeartRate for 1000 ms RR is 60 bpm")
    func testCalculateHeartRate1000ms() {
        let hr = WaveformHelpers.calculateHeartRate(rrIntervalMs: 1000.0)
        #expect(abs(hr - 60.0) < 0.01)
    }

    // MARK: - sampleToTime

    @Test("sampleToTime converts 250 samples at 250 Hz to 1.0 second")
    func testSampleToTime() {
        let t = WaveformHelpers.sampleToTime(sampleIndex: 250, samplingFrequency: 250.0)
        #expect(abs(t - 1.0) < 0.0001)
    }

    @Test("sampleToTime returns 0 for zero sampling frequency")
    func testSampleToTimeZeroFrequency() {
        let t = WaveformHelpers.sampleToTime(sampleIndex: 100, samplingFrequency: 0.0)
        #expect(t == 0.0)
    }

    // MARK: - waveformTypeDescription

    @Test("waveformTypeDescription for ECG SOP class contains ECG")
    func testWaveformTypeDescriptionECG() {
        let desc = WaveformHelpers.waveformTypeDescription(sopClassUID: "1.2.840.10008.5.1.4.1.1.9.1.1")
        #expect(desc.contains("ECG"))
    }

    @Test("waveformTypeDescription for unknown returns Waveform")
    func testWaveformTypeDescriptionUnknown() {
        let desc = WaveformHelpers.waveformTypeDescription(sopClassUID: "9.9.9.9")
        #expect(desc == "Waveform")
    }
}
