// CLIWorkshopModelTests.swift
// DICOMStudioTests
//
// DICOM Studio — Tests for CLI Tools Workshop models (Milestone 16)

import Testing
@testable import DICOMStudio
import Foundation

@Suite("CLI Workshop Model Tests")
struct CLIWorkshopModelTests {

    // MARK: - CLIWorkshopTab

    @Test("CLIWorkshopTab has 7 cases")
    func testTabCaseCount() {
        #expect(CLIWorkshopTab.allCases.count == 7)
    }

    @Test("CLIWorkshopTab all cases have non-empty display names")
    func testTabDisplayNames() {
        for tab in CLIWorkshopTab.allCases {
            #expect(!tab.displayName.isEmpty)
        }
    }

    @Test("CLIWorkshopTab all cases have non-empty SF symbols")
    func testTabSFSymbols() {
        for tab in CLIWorkshopTab.allCases {
            #expect(!tab.sfSymbol.isEmpty)
        }
    }

    @Test("CLIWorkshopTab all cases have non-empty descriptions")
    func testTabDescriptions() {
        for tab in CLIWorkshopTab.allCases {
            #expect(!tab.tabDescription.isEmpty)
        }
    }

    @Test("CLIWorkshopTab rawValues are unique")
    func testTabRawValuesUnique() {
        let rawValues = CLIWorkshopTab.allCases.map { $0.rawValue }
        #expect(Set(rawValues).count == CLIWorkshopTab.allCases.count)
    }

    @Test("CLIWorkshopTab id equals rawValue")
    func testTabIDEqualsRawValue() {
        for tab in CLIWorkshopTab.allCases {
            #expect(tab.id == tab.rawValue)
        }
    }

    @Test("CLIWorkshopTab fileInspection rawValue is FILE_INSPECTION")
    func testTabFileInspectionRawValue() {
        #expect(CLIWorkshopTab.fileInspection.rawValue == "FILE_INSPECTION")
    }

    // MARK: - CLIProtocolType

    @Test("CLIProtocolType has 2 cases")
    func testProtocolTypeCaseCount() {
        #expect(CLIProtocolType.allCases.count == 2)
    }

    @Test("CLIProtocolType all cases have non-empty display names")
    func testProtocolTypeDisplayNames() {
        for p in CLIProtocolType.allCases {
            #expect(!p.displayName.isEmpty)
        }
    }

    @Test("CLIProtocolType id equals rawValue")
    func testProtocolTypeID() {
        for p in CLIProtocolType.allCases {
            #expect(p.id == p.rawValue)
        }
    }

    // MARK: - CLINetworkProfile

    @Test("CLINetworkProfile convenience init sets defaults correctly")
    func testNetworkProfileDefaults() {
        let profile = CLINetworkProfile(name: "Test")
        #expect(profile.name == "Test")
        #expect(profile.aeTitle == "DICOMSTUDIO")
        #expect(profile.calledAET == "ANY-SCP")
        #expect(profile.host == "localhost")
        #expect(profile.port == 11112)
        #expect(profile.timeout == 60)
        #expect(profile.protocolType == .dicom)
        #expect(profile.isDefault == false)
    }

    @Test("CLINetworkProfile full init round-trips all fields")
    func testNetworkProfileFullInit() {
        let id = UUID()
        let profile = CLINetworkProfile(id: id, name: "Custom", aeTitle: "MY_AET", calledAET: "PACS",
                                        host: "192.168.1.10", port: 4242, timeout: 120,
                                        protocolType: .dicomweb, isDefault: true)
        #expect(profile.id == id)
        #expect(profile.name == "Custom")
        #expect(profile.aeTitle == "MY_AET")
        #expect(profile.calledAET == "PACS")
        #expect(profile.host == "192.168.1.10")
        #expect(profile.port == 4242)
        #expect(profile.timeout == 120)
        #expect(profile.protocolType == .dicomweb)
        #expect(profile.isDefault == true)
    }

    @Test("CLINetworkProfile is Hashable")
    func testNetworkProfileHashable() {
        let id = UUID()
        let p1 = CLINetworkProfile(id: id, name: "A")
        let p2 = CLINetworkProfile(id: id, name: "A")
        #expect(p1 == p2)
    }

    // MARK: - CLIConnectionTestStatus

    @Test("CLIConnectionTestStatus has 4 cases")
    func testConnectionTestStatusCaseCount() {
        #expect(CLIConnectionTestStatus.allCases.count == 4)
    }

    @Test("CLIConnectionTestStatus all cases have non-empty display names and sfSymbols")
    func testConnectionTestStatusProperties() {
        for s in CLIConnectionTestStatus.allCases {
            #expect(!s.displayName.isEmpty)
            #expect(!s.sfSymbol.isEmpty)
        }
    }

    // MARK: - CLIToolDefinition

    @Test("CLIToolDefinition stores fields correctly")
    func testToolDefinition() {
        let tool = CLIToolDefinition(id: "dicom-info", name: "dicom-info", displayName: "Info",
                                     category: .fileInspection, sfSymbol: "info.circle",
                                     briefDescription: "Show info", dicomStandardRef: "PS3.10",
                                     hasSubcommands: false, requiresNetwork: false)
        #expect(tool.id == "dicom-info")
        #expect(tool.name == "dicom-info")
        #expect(tool.displayName == "Info")
        #expect(tool.category == .fileInspection)
        #expect(tool.sfSymbol == "info.circle")
        #expect(tool.briefDescription == "Show info")
        #expect(tool.dicomStandardRef == "PS3.10")
        #expect(tool.hasSubcommands == false)
        #expect(tool.requiresNetwork == false)
    }

    @Test("CLIToolDefinition defaults are correct")
    func testToolDefinitionDefaults() {
        let tool = CLIToolDefinition(id: "test", name: "test", displayName: "Test",
                                     category: .automation, sfSymbol: "star",
                                     briefDescription: "Desc")
        #expect(tool.dicomStandardRef == "")
        #expect(tool.hasSubcommands == false)
        #expect(tool.requiresNetwork == false)
    }

    // MARK: - CLIParameterType

    @Test("CLIParameterType has 12 cases")
    func testParameterTypeCaseCount() {
        #expect(CLIParameterType.allCases.count == 12)
    }

    @Test("CLIParameterType all cases have non-empty display names")
    func testParameterTypeDisplayNames() {
        for pt in CLIParameterType.allCases {
            #expect(!pt.displayName.isEmpty)
        }
    }

    // MARK: - CLIParameterDefinition

    @Test("CLIParameterDefinition stores fields correctly")
    func testParameterDefinition() {
        let def = CLIParameterDefinition(id: "input", flag: "", displayName: "Input File",
                                         parameterType: .filePath, placeholder: "scan.dcm",
                                         helpText: "The DICOM file to inspect", isRequired: true,
                                         isAdvanced: false, defaultValue: "",
                                         allowedValues: [], minValue: nil, maxValue: nil)
        #expect(def.id == "input")
        #expect(def.flag == "")
        #expect(def.displayName == "Input File")
        #expect(def.parameterType == .filePath)
        #expect(def.isRequired == true)
        #expect(def.isAdvanced == false)
    }

    @Test("CLIParameterDefinition defaults are correct")
    func testParameterDefinitionDefaults() {
        let def = CLIParameterDefinition(id: "x", flag: "--x", displayName: "X", parameterType: .textField)
        #expect(def.placeholder == "")
        #expect(def.helpText == "")
        #expect(def.isRequired == false)
        #expect(def.isAdvanced == false)
        #expect(def.defaultValue == "")
        #expect(def.allowedValues.isEmpty)
        #expect(def.minValue == nil)
        #expect(def.maxValue == nil)
    }

    // MARK: - CLIParameterValue

    @Test("CLIParameterValue stores fields correctly")
    func testParameterValue() {
        let val = CLIParameterValue(parameterID: "input", stringValue: "/path/to/file.dcm")
        #expect(val.parameterID == "input")
        #expect(val.stringValue == "/path/to/file.dcm")
    }

    // MARK: - CLIFileDropState

    @Test("CLIFileDropState has 3 cases")
    func testFileDropStateCaseCount() {
        #expect(CLIFileDropState.allCases.count == 3)
    }

    @Test("CLIFileDropState all cases have non-empty display names")
    func testFileDropStateDisplayNames() {
        for s in CLIFileDropState.allCases {
            #expect(!s.displayName.isEmpty)
        }
    }

    // MARK: - CLIFileEntry

    @Test("CLIFileEntry stores fields correctly")
    func testFileEntry() {
        let entry = CLIFileEntry(path: "/data/scan.dcm", filename: "scan.dcm", fileSize: 524288, isDICOM: true)
        #expect(entry.path == "/data/scan.dcm")
        #expect(entry.filename == "scan.dcm")
        #expect(entry.fileSize == 524288)
        #expect(entry.isDICOM == true)
    }

    @Test("CLIFileEntry defaults are correct")
    func testFileEntryDefaults() {
        let entry = CLIFileEntry(path: "/x", filename: "x")
        #expect(entry.fileSize == 0)
        #expect(entry.isDICOM == true)
    }

    // MARK: - CLIConsoleStatus

    @Test("CLIConsoleStatus has 4 cases")
    func testConsoleStatusCaseCount() {
        #expect(CLIConsoleStatus.allCases.count == 4)
    }

    @Test("CLIConsoleStatus all cases have non-empty display names and sfSymbols")
    func testConsoleStatusProperties() {
        for s in CLIConsoleStatus.allCases {
            #expect(!s.displayName.isEmpty)
            #expect(!s.sfSymbol.isEmpty)
        }
    }

    // MARK: - CLISyntaxTokenType

    @Test("CLISyntaxTokenType has 5 cases")
    func testSyntaxTokenTypeCaseCount() {
        #expect(CLISyntaxTokenType.allCases.count == 5)
    }

    @Test("CLISyntaxTokenType all cases have non-empty display names")
    func testSyntaxTokenTypeDisplayNames() {
        for t in CLISyntaxTokenType.allCases {
            #expect(!t.displayName.isEmpty)
        }
    }

    // MARK: - CLISyntaxToken

    @Test("CLISyntaxToken stores fields correctly")
    func testSyntaxToken() {
        let token = CLISyntaxToken(text: "dicom-info", tokenType: .toolName)
        #expect(token.text == "dicom-info")
        #expect(token.tokenType == .toolName)
    }

    // MARK: - CLIExecutionState

    @Test("CLIExecutionState has 5 cases")
    func testExecutionStateCaseCount() {
        #expect(CLIExecutionState.allCases.count == 5)
    }

    @Test("CLIExecutionState all cases have non-empty display names and sfSymbols")
    func testExecutionStateProperties() {
        for s in CLIExecutionState.allCases {
            #expect(!s.displayName.isEmpty)
            #expect(!s.sfSymbol.isEmpty)
        }
    }

    // MARK: - CLICommandHistoryEntry

    @Test("CLICommandHistoryEntry stores fields correctly")
    func testCommandHistoryEntry() {
        let entry = CLICommandHistoryEntry(toolName: "dicom-info", rawCommand: "dicom-info file.dcm",
                                           redactedCommand: "dicom-info file.dcm",
                                           executionState: .completed, exitCode: 0,
                                           outputSnippet: "OK")
        #expect(entry.toolName == "dicom-info")
        #expect(entry.rawCommand == "dicom-info file.dcm")
        #expect(entry.redactedCommand == "dicom-info file.dcm")
        #expect(entry.executionState == .completed)
        #expect(entry.exitCode == 0)
        #expect(entry.outputSnippet == "OK")
    }

    @Test("CLICommandHistoryEntry defaults are correct")
    func testCommandHistoryEntryDefaults() {
        let entry = CLICommandHistoryEntry(toolName: "t", rawCommand: "c", redactedCommand: "c")
        #expect(entry.executionState == .completed)
        #expect(entry.exitCode == nil)
        #expect(entry.outputSnippet == "")
    }

    // MARK: - CLIExperienceMode

    @Test("CLIExperienceMode has 2 cases")
    func testExperienceModeCaseCount() {
        #expect(CLIExperienceMode.allCases.count == 2)
    }

    @Test("CLIExperienceMode all cases have non-empty properties")
    func testExperienceModeProperties() {
        for m in CLIExperienceMode.allCases {
            #expect(!m.displayName.isEmpty)
            #expect(!m.sfSymbol.isEmpty)
            #expect(!m.modeDescription.isEmpty)
            #expect(m.id == m.rawValue)
        }
    }

    // MARK: - CLIGlossaryEntry

    @Test("CLIGlossaryEntry stores fields correctly")
    func testGlossaryEntry() {
        let entry = CLIGlossaryEntry(term: "AE Title", definition: "Application Entity Title",
                                     standardReference: "PS3.8")
        #expect(entry.term == "AE Title")
        #expect(entry.definition == "Application Entity Title")
        #expect(entry.standardReference == "PS3.8")
    }

    @Test("CLIGlossaryEntry default standardReference is empty")
    func testGlossaryEntryDefault() {
        let entry = CLIGlossaryEntry(term: "T", definition: "D")
        #expect(entry.standardReference == "")
    }

    // MARK: - CLIExamplePreset

    @Test("CLIExamplePreset stores fields correctly")
    func testExamplePreset() {
        let preset = CLIExamplePreset(toolID: "dicom-info", title: "Basic",
                                      presetDescription: "Show basic info",
                                      commandString: "dicom-info file.dcm")
        #expect(preset.toolID == "dicom-info")
        #expect(preset.title == "Basic")
        #expect(preset.presetDescription == "Show basic info")
        #expect(preset.commandString == "dicom-info file.dcm")
    }
}
