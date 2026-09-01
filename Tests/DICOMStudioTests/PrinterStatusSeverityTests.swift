// PrinterStatusSeverityTests.swift
// DICOMStudioTests
//
// FR-012 — the printer reports three states (PS3.3 C.13.9) and the UI used to
// show two, so "low on film" and "broken" looked the same. These pin the
// three-way split and the lenient parse that keeps a non-conformant SCP from
// being read as healthy.

import Testing
import Foundation
@testable import DICOMStudio
@testable import DICOMNetwork

@Suite("Printer status severity")
struct PrinterStatusSeverityTests {

    // MARK: - Parsing

    @Test("The three PS3.3 C.13.9 states parse to their own cases")
    func standardStatesParse() {
        #expect(PrinterStatus(status: "NORMAL").severity == .normal)
        #expect(PrinterStatus(status: "WARNING").severity == .warning)
        #expect(PrinterStatus(status: "FAILURE").severity == .failure)
    }

    @Test("A missing or unrecognised status is unknown, never normal")
    func unrecognisedIsUnknown() {
        // The dangerous failure mode: an SCP we cannot read being treated as
        // healthy and handed a job.
        #expect(PrinterStatus(status: "UNKNOWN").severity == .unknown)
        #expect(PrinterStatus(status: "").severity == .unknown)
        #expect(PrinterStatus(status: "SOMETHING ELSE").severity == .unknown)
        #expect(PrinterStatus(status: "NORMALISH").severity == .unknown)
    }

    @Test("Padded and lower-case values still parse — CS values arrive padded")
    func leniencyOnWhitespaceAndCase() {
        #expect(PrinterStatus(status: "NORMAL ").severity == .normal)
        #expect(PrinterStatus(status: " WARNING").severity == .warning)
        #expect(PrinterStatus(status: "failure").severity == .failure)
        #expect(PrinterStatus(status: "\nNORMAL\n").severity == .normal)
    }

    // MARK: - Job acceptance

    @Test("A warning printer still accepts jobs; failure and unknown do not")
    func acceptsJobs() {
        // A printer low on film prints. Blocking on WARNING would stop usable work.
        #expect(PrinterStatusSeverity.normal.acceptsJobs)
        #expect(PrinterStatusSeverity.warning.acceptsJobs)
        #expect(!PrinterStatusSeverity.failure.acceptsJobs)
        #expect(!PrinterStatusSeverity.unknown.acceptsJobs)
    }

    @Test("Convenience predicates agree with severity")
    func predicates() {
        #expect(PrinterStatus(status: "NORMAL").isNormal)
        #expect(!PrinterStatus(status: "WARNING").isNormal)
        #expect(PrinterStatus(status: "WARNING").isWarning)
        #expect(PrinterStatus(status: "FAILURE").isFailure)
        #expect(!PrinterStatus(status: "FAILURE").isWarning)
    }

    // MARK: - Mapping onto connection status

    @Test("Warning maps to its own connection status, not to error")
    func connectionStatusMapping() {
        // The regression this whole change exists to prevent.
        #expect(PrintViewModel.connectionStatus(for: .normal) == .online)
        #expect(PrintViewModel.connectionStatus(for: .warning) == .warning)
        #expect(PrintViewModel.connectionStatus(for: .failure) == .error)
        #expect(PrintViewModel.connectionStatus(for: .unknown) == .unknown)
    }

    @Test("Every severity maps to a distinct connection status")
    func mappingIsInjective() {
        let mapped = PrinterStatusSeverity.allCases.map {
            PrintViewModel.connectionStatus(for: $0)
        }
        #expect(Set(mapped).count == PrinterStatusSeverity.allCases.count)
    }

    // MARK: - Presentation

    @Test("Warning and failure differ in both colour and glyph")
    func presentationDistinguishesWarningFromFailure() {
        // Colour alone is not a safe signal for colour-blind users, so the
        // symbols must differ too.
        #expect(PrinterStatusPresentation.color(for: .warning)
                != PrinterStatusPresentation.color(for: .failure))
        #expect(PrinterStatusPresentation.symbol(for: .warning)
                != PrinterStatusPresentation.symbol(for: .failure))
        #expect(PrinterStatusPresentation.color(for: .normal)
                != PrinterStatusPresentation.color(for: .warning))
    }

    @Test("The printer's own status info survives into the summary")
    func summaryKeepsStatusInfo() {
        // "SUPPLY LOW" is the part a technologist can act on.
        let status = PrinterStatus(status: "WARNING", statusInfo: "SUPPLY LOW")
        let summary = PrinterStatusPresentation.summary(for: status)
        #expect(summary.contains("SUPPLY LOW"))
        #expect(summary.contains("Warning"))
    }

    @Test("A missing or blank status info leaves a clean summary")
    func summaryWithoutStatusInfo() {
        #expect(PrinterStatusPresentation.summary(for: PrinterStatus(status: "NORMAL"))
                == "Normal")
        #expect(PrinterStatusPresentation.summary(
            for: PrinterStatus(status: "NORMAL", statusInfo: "  ")) == "Normal")
    }
}
