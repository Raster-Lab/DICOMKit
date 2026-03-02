// CLIWorkshopHelpersTests.swift
// DICOMStudioTests
//
// DICOM Studio — Tests for CLI Tools Workshop helpers (Milestone 16)

import Testing
@testable import DICOMStudio
import Foundation

@Suite("CLI Workshop Helpers Tests")
struct CLIWorkshopHelpersTests {

    // MARK: - NetworkConfigHelpers

    @Test("validateAETitle accepts valid AE titles")
    func testValidAETitles() {
        #expect(NetworkConfigHelpers.validateAETitle("DICOMSTUDIO") == true)
        #expect(NetworkConfigHelpers.validateAETitle("A") == true)
        #expect(NetworkConfigHelpers.validateAETitle("1234567890123456") == true) // 16 chars
    }

    @Test("validateAETitle rejects invalid AE titles")
    func testInvalidAETitles() {
        #expect(NetworkConfigHelpers.validateAETitle("") == false)
        #expect(NetworkConfigHelpers.validateAETitle("12345678901234567") == false) // 17 chars
        #expect(NetworkConfigHelpers.validateAETitle(" A") == false) // leading space
    }

    @Test("validatePort accepts valid ports")
    func testValidPorts() {
        #expect(NetworkConfigHelpers.validatePort(1) == true)
        #expect(NetworkConfigHelpers.validatePort(11112) == true)
        #expect(NetworkConfigHelpers.validatePort(65535) == true)
    }

    @Test("validatePort rejects invalid ports")
    func testInvalidPorts() {
        #expect(NetworkConfigHelpers.validatePort(0) == false)
        #expect(NetworkConfigHelpers.validatePort(-1) == false)
        #expect(NetworkConfigHelpers.validatePort(65536) == false)
    }

    @Test("validateTimeout accepts valid timeouts")
    func testValidTimeouts() {
        #expect(NetworkConfigHelpers.validateTimeout(5) == true)
        #expect(NetworkConfigHelpers.validateTimeout(60) == true)
        #expect(NetworkConfigHelpers.validateTimeout(300) == true)
    }

    @Test("validateTimeout rejects invalid timeouts")
    func testInvalidTimeouts() {
        #expect(NetworkConfigHelpers.validateTimeout(4) == false)
        #expect(NetworkConfigHelpers.validateTimeout(301) == false)
        #expect(NetworkConfigHelpers.validateTimeout(0) == false)
    }

    @Test("validateHost accepts valid hosts")
    func testValidHosts() {
        #expect(NetworkConfigHelpers.validateHost("localhost") == true)
        #expect(NetworkConfigHelpers.validateHost("192.168.1.1") == true)
        #expect(NetworkConfigHelpers.validateHost("pacs.example.com") == true)
    }

    @Test("validateHost rejects empty or whitespace-only hosts")
    func testInvalidHosts() {
        #expect(NetworkConfigHelpers.validateHost("") == false)
        #expect(NetworkConfigHelpers.validateHost("   ") == false)
    }

    @Test("defaultProfile returns a valid profile")
    func testDefaultProfile() {
        let profile = NetworkConfigHelpers.defaultProfile()
        #expect(profile.name == "Default")
        #expect(profile.aeTitle == "DICOMSTUDIO")
        #expect(profile.calledAET == "ANY-SCP")
        #expect(profile.host == "localhost")
        #expect(profile.port == 11112)
        #expect(profile.timeout == 60)
        #expect(profile.protocolType == .dicom)
        #expect(profile.isDefault == true)
    }

    @Test("connectionSummary formats correctly")
    func testConnectionSummary() {
        let profile = CLINetworkProfile(name: "Test", aeTitle: "MY_AET", calledAET: "PACS",
                                        host: "192.168.1.1", port: 4242)
        let summary = NetworkConfigHelpers.connectionSummary(for: profile)
        #expect(summary.contains("MY_AET"))
        #expect(summary.contains("PACS"))
        #expect(summary.contains("192.168.1.1"))
        #expect(summary.contains("4242"))
    }

    @Test("maxAETitleLength is 16")
    func testMaxAETitleLength() {
        #expect(NetworkConfigHelpers.maxAETitleLength == 16)
    }

    // MARK: - ToolCatalogHelpers

    @Test("allTools returns exactly 29 tools")
    func testAllToolsCount() {
        #expect(ToolCatalogHelpers.allTools().count == 29)
    }

    @Test("totalToolCount is 29")
    func testTotalToolCount() {
        #expect(ToolCatalogHelpers.totalToolCount == 29)
    }

    @Test("fileInspectionTools returns 4 tools")
    func testFileInspectionToolsCount() {
        #expect(ToolCatalogHelpers.fileInspectionTools().count == 4)
    }

    @Test("fileProcessingTools returns 4 tools")
    func testFileProcessingToolsCount() {
        #expect(ToolCatalogHelpers.fileProcessingTools().count == 4)
    }

    @Test("fileOrganizationTools returns 4 tools")
    func testFileOrganizationToolsCount() {
        #expect(ToolCatalogHelpers.fileOrganizationTools().count == 4)
    }

    @Test("dataExportTools returns 6 tools")
    func testDataExportToolsCount() {
        #expect(ToolCatalogHelpers.dataExportTools().count == 6)
    }

    @Test("networkOperationsTools returns 8 tools")
    func testNetworkOperationsToolsCount() {
        #expect(ToolCatalogHelpers.networkOperationsTools().count == 8)
    }

    @Test("automationTools returns 3 tools")
    func testAutomationToolsCount() {
        #expect(ToolCatalogHelpers.automationTools().count == 3)
    }

    @Test("tools(for:) filters correctly by tab")
    func testToolsForTab() {
        for tab in CLIWorkshopTab.allCases {
            let tools = ToolCatalogHelpers.tools(for: tab)
            for tool in tools {
                #expect(tool.category == tab)
            }
        }
    }

    @Test("all tools have unique IDs")
    func testAllToolsUniqueIDs() {
        let ids = ToolCatalogHelpers.allTools().map { $0.id }
        #expect(Set(ids).count == ids.count)
    }

    @Test("all tools have non-empty names and descriptions")
    func testAllToolsProperties() {
        for tool in ToolCatalogHelpers.allTools() {
            #expect(!tool.name.isEmpty)
            #expect(!tool.displayName.isEmpty)
            #expect(!tool.briefDescription.isEmpty)
            #expect(!tool.sfSymbol.isEmpty)
        }
    }

    @Test("network tools require network")
    func testNetworkToolsRequireNetwork() {
        let networkTools = ToolCatalogHelpers.networkOperationsTools()
        for tool in networkTools {
            #expect(tool.requiresNetwork == true)
        }
    }

    @Test("tools with subcommands are identified correctly")
    func testToolsWithSubcommands() {
        let allTools = ToolCatalogHelpers.allTools()
        let withSubcommands = allTools.filter { $0.hasSubcommands }
        #expect(withSubcommands.count >= 6) // compress, dcmdir, export, wado, mpps, study, uid, script
    }

    // MARK: - CommandBuilderHelpers

    @Test("buildCommand with no parameters returns tool name only")
    func testBuildCommandEmpty() {
        let cmd = CommandBuilderHelpers.buildCommand(toolName: "dicom-info", parameterValues: [], parameterDefinitions: [])
        #expect(cmd == "dicom-info")
    }

    @Test("buildCommand with subcommand includes it")
    func testBuildCommandSubcommand() {
        let cmd = CommandBuilderHelpers.buildCommand(toolName: "dicom-compress", subcommand: "compress",
                                                     parameterValues: [], parameterDefinitions: [])
        #expect(cmd == "dicom-compress compress")
    }

    @Test("buildCommand includes flag and value parameters")
    func testBuildCommandWithParams() {
        let defs = [
            CLIParameterDefinition(id: "format", flag: "--format", displayName: "Format", parameterType: .enumPicker)
        ]
        let vals = [CLIParameterValue(parameterID: "format", stringValue: "json")]
        let cmd = CommandBuilderHelpers.buildCommand(toolName: "dicom-info", parameterValues: vals, parameterDefinitions: defs)
        #expect(cmd == "dicom-info --format json")
    }

    @Test("buildCommand handles boolean toggles correctly")
    func testBuildCommandBooleanToggle() {
        let defs = [
            CLIParameterDefinition(id: "verbose", flag: "--verbose", displayName: "Verbose", parameterType: .booleanToggle)
        ]
        let valsTrue = [CLIParameterValue(parameterID: "verbose", stringValue: "true")]
        let valsFalse = [CLIParameterValue(parameterID: "verbose", stringValue: "false")]
        let cmdTrue = CommandBuilderHelpers.buildCommand(toolName: "dicom-info", parameterValues: valsTrue, parameterDefinitions: defs)
        let cmdFalse = CommandBuilderHelpers.buildCommand(toolName: "dicom-info", parameterValues: valsFalse, parameterDefinitions: defs)
        #expect(cmdTrue == "dicom-info --verbose")
        #expect(cmdFalse == "dicom-info")
    }

    @Test("buildCommand handles file path with spaces")
    func testBuildCommandFilePathSpaces() {
        let defs = [
            CLIParameterDefinition(id: "input", flag: "", displayName: "Input", parameterType: .filePath)
        ]
        let vals = [CLIParameterValue(parameterID: "input", stringValue: "/path/to my/file.dcm")]
        let cmd = CommandBuilderHelpers.buildCommand(toolName: "dicom-info", parameterValues: vals, parameterDefinitions: defs)
        #expect(cmd.contains("'/path/to my/file.dcm'"))
    }

    @Test("shellEscape handles paths with spaces")
    func testShellEscapeSpaces() {
        #expect(CommandBuilderHelpers.shellEscape("/simple/path") == "/simple/path")
        #expect(CommandBuilderHelpers.shellEscape("/path with spaces/file.dcm") == "'/path with spaces/file.dcm'")
    }

    @Test("shellEscape handles single quotes")
    func testShellEscapeSingleQuotes() {
        let result = CommandBuilderHelpers.shellEscape("it's a file")
        #expect(result.contains("'\\''"))
    }

    @Test("validateRequired returns true when all required params have values")
    func testValidateRequiredTrue() {
        let defs = [
            CLIParameterDefinition(id: "input", flag: "", displayName: "Input", parameterType: .filePath, isRequired: true)
        ]
        let vals = [CLIParameterValue(parameterID: "input", stringValue: "file.dcm")]
        #expect(CommandBuilderHelpers.validateRequired(parameterValues: vals, parameterDefinitions: defs) == true)
    }

    @Test("validateRequired returns false when required param is missing")
    func testValidateRequiredFalse() {
        let defs = [
            CLIParameterDefinition(id: "input", flag: "", displayName: "Input", parameterType: .filePath, isRequired: true)
        ]
        #expect(CommandBuilderHelpers.validateRequired(parameterValues: [], parameterDefinitions: defs) == false)
    }

    @Test("validateRequired returns false when required param is empty")
    func testValidateRequiredEmpty() {
        let defs = [
            CLIParameterDefinition(id: "input", flag: "", displayName: "Input", parameterType: .filePath, isRequired: true)
        ]
        let vals = [CLIParameterValue(parameterID: "input", stringValue: "  ")]
        #expect(CommandBuilderHelpers.validateRequired(parameterValues: vals, parameterDefinitions: defs) == false)
    }

    @Test("missingRequiredParameters lists missing params")
    func testMissingRequiredParameters() {
        let defs = [
            CLIParameterDefinition(id: "input", flag: "", displayName: "Input File", parameterType: .filePath, isRequired: true),
            CLIParameterDefinition(id: "format", flag: "--format", displayName: "Format", parameterType: .enumPicker, isRequired: false),
        ]
        let missing = CommandBuilderHelpers.missingRequiredParameters(parameterValues: [], parameterDefinitions: defs)
        #expect(missing == ["Input File"])
    }

    @Test("tokenize correctly identifies tool name, flags, values, and paths")
    func testTokenize() {
        let tokens = CommandBuilderHelpers.tokenize("dicom-info --format json /path/to/file.dcm")
        #expect(tokens.count == 4)
        #expect(tokens[0].tokenType == .toolName)
        #expect(tokens[1].tokenType == .flag)
        #expect(tokens[2].tokenType == .value)
        #expect(tokens[3].tokenType == .path)
    }

    @Test("tokenize handles empty command")
    func testTokenizeEmpty() {
        let tokens = CommandBuilderHelpers.tokenize("")
        #expect(tokens.isEmpty)
    }

    // MARK: - FileDropHelpers

    @Test("isDICOMFile recognizes DICOM extensions")
    func testIsDICOMFile() {
        #expect(FileDropHelpers.isDICOMFile("scan.dcm") == true)
        #expect(FileDropHelpers.isDICOMFile("scan.dicom") == true)
        #expect(FileDropHelpers.isDICOMFile("scan.dic") == true)
        #expect(FileDropHelpers.isDICOMFile("scan.DCM") == true)
    }

    @Test("isDICOMFile recognizes extensionless files as potential DICOM")
    func testIsDICOMFileNoExtension() {
        #expect(FileDropHelpers.isDICOMFile("DICOMDIR") == true)
    }

    @Test("isDICOMFile rejects non-DICOM extensions")
    func testIsDICOMFileRejectsNonDICOM() {
        #expect(FileDropHelpers.isDICOMFile("image.png") == false)
        #expect(FileDropHelpers.isDICOMFile("data.json") == false)
    }

    @Test("formatFileSize formats bytes correctly")
    func testFormatFileSize() {
        #expect(FileDropHelpers.formatFileSize(512) == "512 B")
        #expect(FileDropHelpers.formatFileSize(1536).contains("KB"))
        #expect(FileDropHelpers.formatFileSize(2_097_152).contains("MB"))
        #expect(FileDropHelpers.formatFileSize(2_147_483_648).contains("GB"))
    }

    @Test("fileSummary describes file count correctly")
    func testFileSummary() {
        #expect(FileDropHelpers.fileSummary([]) == "No files selected")
        let file = CLIFileEntry(path: "/f", filename: "scan.dcm")
        #expect(FileDropHelpers.fileSummary([file]) == "scan.dcm")
        let file2 = CLIFileEntry(path: "/g", filename: "other.dcm")
        #expect(FileDropHelpers.fileSummary([file, file2]) == "2 files selected")
    }

    // MARK: - ConsoleHelpers

    @Test("maxHistoryCount is 50")
    func testMaxHistoryCount() {
        #expect(ConsoleHelpers.maxHistoryCount == 50)
    }

    @Test("redactPHI redacts patient names")
    func testRedactPHIPatientName() {
        let cmd = "dicom-anon --patient-name \"John Doe\" file.dcm"
        let redacted = ConsoleHelpers.redactPHI(cmd)
        #expect(!redacted.contains("John Doe"))
        #expect(redacted.contains("<redacted>"))
    }

    @Test("redactPHI redacts patient IDs")
    func testRedactPHIPatientID() {
        let cmd = "dicom-anon --patient-id MRN123456 file.dcm"
        let redacted = ConsoleHelpers.redactPHI(cmd)
        #expect(!redacted.contains("MRN123456"))
        #expect(redacted.contains("<redacted>"))
    }

    @Test("redactPHI redacts OAuth tokens")
    func testRedactPHIOAuth() {
        let cmd = "dicom-wado --token secret123abc retrieve"
        let redacted = ConsoleHelpers.redactPHI(cmd)
        #expect(!redacted.contains("secret123abc"))
        #expect(redacted.contains("<redacted>"))
    }

    @Test("redactPHI preserves non-PHI command parts")
    func testRedactPHIPreserves() {
        let cmd = "dicom-info --format json file.dcm"
        let redacted = ConsoleHelpers.redactPHI(cmd)
        #expect(redacted == cmd)
    }

    @Test("formatTimestamp produces non-empty string")
    func testFormatTimestamp() {
        let result = ConsoleHelpers.formatTimestamp(Date())
        #expect(!result.isEmpty)
    }

    @Test("trimHistory keeps at most 50 entries")
    func testTrimHistory() {
        var history: [CLICommandHistoryEntry] = []
        for i in 0..<60 {
            history.append(CLICommandHistoryEntry(toolName: "t\(i)", rawCommand: "c", redactedCommand: "c"))
        }
        let trimmed = ConsoleHelpers.trimHistory(history)
        #expect(trimmed.count == 50)
    }

    @Test("trimHistory preserves history under limit")
    func testTrimHistoryUnderLimit() {
        let history = [CLICommandHistoryEntry(toolName: "t", rawCommand: "c", redactedCommand: "c")]
        let trimmed = ConsoleHelpers.trimHistory(history)
        #expect(trimmed.count == 1)
    }

    // MARK: - EducationalHelpers

    @Test("defaultGlossaryEntries returns 15 entries")
    func testDefaultGlossaryCount() {
        #expect(EducationalHelpers.defaultGlossaryEntries().count == 15)
    }

    @Test("defaultGlossaryCount matches array count")
    func testDefaultGlossaryCountProperty() {
        #expect(EducationalHelpers.defaultGlossaryCount == EducationalHelpers.defaultGlossaryEntries().count)
    }

    @Test("all glossary entries have non-empty term and definition")
    func testGlossaryEntriesContent() {
        for entry in EducationalHelpers.defaultGlossaryEntries() {
            #expect(!entry.term.isEmpty)
            #expect(!entry.definition.isEmpty)
        }
    }

    @Test("filterGlossary returns all entries for empty query")
    func testFilterGlossaryEmptyQuery() {
        let entries = EducationalHelpers.defaultGlossaryEntries()
        let filtered = EducationalHelpers.filterGlossary(entries, query: "")
        #expect(filtered.count == entries.count)
    }

    @Test("filterGlossary filters by term")
    func testFilterGlossaryByTerm() {
        let entries = EducationalHelpers.defaultGlossaryEntries()
        let filtered = EducationalHelpers.filterGlossary(entries, query: "AE Title")
        #expect(filtered.count >= 1)
        #expect(filtered[0].term == "AE Title")
    }

    @Test("filterGlossary filters by definition content")
    func testFilterGlossaryByDefinition() {
        let entries = EducationalHelpers.defaultGlossaryEntries()
        let filtered = EducationalHelpers.filterGlossary(entries, query: "verification")
        #expect(filtered.count >= 1)
    }

    @Test("filterGlossary is case-insensitive")
    func testFilterGlossaryCaseInsensitive() {
        let entries = EducationalHelpers.defaultGlossaryEntries()
        let upper = EducationalHelpers.filterGlossary(entries, query: "AE TITLE")
        let lower = EducationalHelpers.filterGlossary(entries, query: "ae title")
        #expect(upper.count == lower.count)
    }

    @Test("examplePresets returns entries for known tools")
    func testExamplePresetsKnown() {
        let presets = EducationalHelpers.examplePresets(for: "dicom-info")
        #expect(!presets.isEmpty)
        for p in presets {
            #expect(p.toolID == "dicom-info")
            #expect(!p.commandString.isEmpty)
        }
    }

    @Test("examplePresets returns empty for unknown tool")
    func testExamplePresetsUnknown() {
        let presets = EducationalHelpers.examplePresets(for: "nonexistent-tool")
        #expect(presets.isEmpty)
    }
}
