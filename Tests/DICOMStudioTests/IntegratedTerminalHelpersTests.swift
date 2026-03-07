// IntegratedTerminalHelpersTests.swift
// DICOMStudioTests
//
// DICOM Studio — Tests for Integrated Terminal helpers (Milestone 20)

import Testing
@testable import DICOMStudio
import Foundation

@Suite("Integrated Terminal Helpers Tests")
struct IntegratedTerminalHelpersTests {

    // MARK: - SyntaxHighlightingHelpers.tokenize

    @Test("tokenize: first token of dicom-echo command is .toolName")
    func test_tokenize_dicomEchoCommand_firstTokenIsToolName() {
        let tokens = SyntaxHighlightingHelpers.tokenize(command: "dicom-echo --host 10.0.0.1 --port 11112")
        #expect(!tokens.isEmpty)
        #expect(tokens[0].type == .toolName)
        #expect(tokens[0].text == "dicom-echo")
    }

    @Test("tokenize: --host token is .flag")
    func test_tokenize_dicomEchoCommand_hostFlagIsFlag() {
        let tokens = SyntaxHighlightingHelpers.tokenize(command: "dicom-echo --host 10.0.0.1 --port 11112")
        let flagToken = tokens.first { $0.text == "--host" }
        #expect(flagToken != nil)
        #expect(flagToken?.type == .flag)
    }

    @Test("tokenize: value following --host is .value")
    func test_tokenize_dicomEchoCommand_hostValueIsValue() {
        let tokens = SyntaxHighlightingHelpers.tokenize(command: "dicom-echo --host 10.0.0.1 --port 11112")
        let valueToken = tokens.first { $0.text == "10.0.0.1" }
        #expect(valueToken != nil)
        #expect(valueToken?.type == .value)
    }

    @Test("tokenize: empty command returns empty array")
    func test_tokenize_emptyCommand_returnsEmpty() {
        let tokens = SyntaxHighlightingHelpers.tokenize(command: "")
        #expect(tokens.isEmpty)
    }

    // MARK: - SyntaxHighlightingHelpers.isFilePath

    @Test("isFilePath: /path/to/file.dcm returns true")
    func test_isFilePath_absolutePath_returnsTrue() {
        #expect(SyntaxHighlightingHelpers.isFilePath("/path/to/file.dcm") == true)
    }

    @Test("isFilePath: bare value with no path indicators returns false")
    func test_isFilePath_bareValue_returnsFalse() {
        #expect(SyntaxHighlightingHelpers.isFilePath("value") == false)
    }

    @Test("isFilePath: tilde-prefixed path returns true")
    func test_isFilePath_tildePrefixed_returnsTrue() {
        #expect(SyntaxHighlightingHelpers.isFilePath("~/Documents/scan.dcm") == true)
    }

    @Test("isFilePath: .dcm extension returns true")
    func test_isFilePath_dcmExtension_returnsTrue() {
        #expect(SyntaxHighlightingHelpers.isFilePath("scan.dcm") == true)
    }

    // MARK: - ANSIParsingHelpers.stripANSI

    @Test("stripANSI: removes ANSI escape sequences from text")
    func test_stripANSI_withEscapeSequences_removesEscapes() {
        let colored = "\u{1B}[32mSuccess\u{1B}[0m"
        let stripped = ANSIParsingHelpers.stripANSI(from: colored)
        #expect(stripped == "Success")
    }

    @Test("stripANSI: plain text without escape sequences is unchanged")
    func test_stripANSI_plainText_unchanged() {
        let plain = "No escapes here"
        #expect(ANSIParsingHelpers.stripANSI(from: plain) == plain)
    }

    @Test("stripANSI: multiple escape sequences are all removed")
    func test_stripANSI_multipleEscapes_allRemoved() {
        let text = "\u{1B}[31mError:\u{1B}[0m file not found"
        let stripped = ANSIParsingHelpers.stripANSI(from: text)
        #expect(stripped == "Error: file not found")
    }

    // MARK: - TerminalCommandBuilderHelpers.quoteIfNeeded

    @Test("quoteIfNeeded: simple word without spaces returns unchanged")
    func test_quoteIfNeeded_simpleWord_returnsUnchanged() {
        #expect(TerminalCommandBuilderHelpers.quoteIfNeeded("simple") == "simple")
    }

    @Test("quoteIfNeeded: path with space is wrapped in double quotes")
    func test_quoteIfNeeded_pathWithSpace_wrapsInDoubleQuotes() {
        #expect(TerminalCommandBuilderHelpers.quoteIfNeeded("path with space") == "\"path with space\"")
    }

    @Test("quoteIfNeeded: word with embedded quotes escapes them")
    func test_quoteIfNeeded_embeddedQuotes_escapesCorrectly() {
        let result = TerminalCommandBuilderHelpers.quoteIfNeeded("a \"b\" c")
        #expect(result == "\"a \\\"b\\\" c\"")
    }

    // MARK: - TerminalCommandBuilderHelpers.build

    @Test("build: result starts with toolName")
    func test_build_basicInvocation_startsWithToolName() {
        let cmd = TerminalCommandBuilderHelpers.build(
            toolName: "dicom-echo",
            subcommand: nil,
            params: ["--host": "10.0.0.1"],
            flags: [],
            positionalArgs: []
        )
        #expect(cmd.hasPrefix("dicom-echo"))
    }

    @Test("build: includes param key and value in output")
    func test_build_withParam_includesKeyAndValue() {
        let cmd = TerminalCommandBuilderHelpers.build(
            toolName: "dicom-echo",
            subcommand: nil,
            params: ["--host": "10.0.0.1"],
            flags: [],
            positionalArgs: []
        )
        #expect(cmd.contains("--host"))
        #expect(cmd.contains("10.0.0.1"))
    }

    @Test("build: subcommand appears after tool name")
    func test_build_withSubcommand_subcommandAfterToolName() {
        let cmd = TerminalCommandBuilderHelpers.build(
            toolName: "dicom-query",
            subcommand: "find",
            params: [:],
            flags: [],
            positionalArgs: []
        )
        #expect(cmd == "dicom-query find")
    }

    // MARK: - TerminalCommandBuilderHelpers.maxOutputBytes

    @Test("maxOutputBytes equals 10_485_760 (10 MB)")
    func test_maxOutputBytes_equals10MB() {
        #expect(TerminalCommandBuilderHelpers.maxOutputBytes == 10_485_760)
    }

    // MARK: - CommandHistoryHelpers.redactPHI

    @Test("redactPHI: redacts PatientName attribute assignment")
    func test_redactPHI_patientNameAssignment_isRedacted() {
        let command = "dicom-anon --PatientName=JohnDoe file.dcm"
        let redacted = CommandHistoryHelpers.redactPHI(from: command)
        #expect(!redacted.contains("JohnDoe"))
        #expect(redacted.contains("PatientName=<redacted>"))
    }

    @Test("redactPHI: replaces path-looking tokens with <path>")
    func test_redactPHI_pathToken_replacedWithPlaceholder() {
        let command = "dicom-info /data/patient/scan.dcm"
        let redacted = CommandHistoryHelpers.redactPHI(from: command)
        #expect(redacted.contains("<path>"))
        #expect(!redacted.contains("/data/patient/scan.dcm"))
    }

    // MARK: - CommandHistoryHelpers.filter

    @Test("filter: empty filter returns all entries")
    func test_filter_emptyFilter_returnsAllEntries() {
        let entries = [
            CommandHistoryEntry(toolName: "dicom-echo", command: "dicom-echo", exitCode: 0, duration: 1.0),
            CommandHistoryEntry(toolName: "dicom-query", command: "dicom-query", exitCode: 1, duration: 2.0),
            CommandHistoryEntry(toolName: "dicom-send", command: "dicom-send", exitCode: 0, duration: 0.5),
        ]
        let filter = CommandHistoryFilter()
        let result = CommandHistoryHelpers.filter(entries: entries, by: filter)
        #expect(result.count == entries.count)
    }

    @Test("filter: toolName filter returns only matching entries")
    func test_filter_toolNameFilter_returnsOnlyMatchingEntries() {
        let entries = [
            CommandHistoryEntry(toolName: "dicom-echo", command: "dicom-echo", exitCode: 0, duration: 1.0),
            CommandHistoryEntry(toolName: "dicom-query", command: "dicom-query", exitCode: 0, duration: 2.0),
        ]
        let filter = CommandHistoryFilter(toolName: "dicom-echo")
        let result = CommandHistoryHelpers.filter(entries: entries, by: filter)
        #expect(result.count == 1)
        #expect(result[0].toolName == "dicom-echo")
    }

    // MARK: - ExecutionHelpers.formatDuration

    @Test("formatDuration: 0.5 seconds formats as 0.5s")
    func test_formatDuration_halfSecond_formatsAsHalfSecond() {
        #expect(ExecutionHelpers.formatDuration(0.5) == "0.5s")
    }

    @Test("formatDuration: 90 seconds formats as 1m 30s")
    func test_formatDuration_90Seconds_formatsAs1m30s() {
        #expect(ExecutionHelpers.formatDuration(90) == "1m 30s")
    }

    @Test("formatDuration: 60 seconds formats as 1m")
    func test_formatDuration_60Seconds_formatsAs1m() {
        #expect(ExecutionHelpers.formatDuration(60) == "1m")
    }

    @Test("formatDuration: whole-second value has no decimal point")
    func test_formatDuration_wholeSecond_noDecimalPoint() {
        #expect(ExecutionHelpers.formatDuration(12) == "12s")
    }

    // MARK: - TerminalDisplayHelpers

    @Test("defaultFontSize returns 12.0")
    func test_defaultFontSize_returns12() {
        #expect(TerminalDisplayHelpers.defaultFontSize() == 12.0)
    }

    @Test("colorSchemeSuggestion(forSystemDark: true) returns .dark")
    func test_colorSchemeSuggestion_systemDark_returnsDark() {
        #expect(TerminalDisplayHelpers.colorSchemeSuggestion(forSystemDark: true) == .dark)
    }

    @Test("colorSchemeSuggestion(forSystemDark: false) returns .light")
    func test_colorSchemeSuggestion_systemLight_returnsLight() {
        #expect(TerminalDisplayHelpers.colorSchemeSuggestion(forSystemDark: false) == .light)
    }
}
