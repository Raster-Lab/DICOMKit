// CLIWorkshopViewModelTests.swift
// DICOMStudioTests
//
// DICOM Studio — Tests for CLI Tools Workshop ViewModel (Milestone 16)

import Testing
@testable import DICOMStudio
import Foundation

@Suite("CLI Workshop ViewModel Tests")
@MainActor
struct CLIWorkshopViewModelTests {

    // MARK: - Initialization

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("ViewModel initializes with default state")
    func testInit() {
        let vm = CLIWorkshopViewModel()
        #expect(vm.activeTab == .fileInspection)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.networkProfiles.count == 1)
        #expect(vm.activeProfileID == nil)
        #expect(vm.connectionTestStatus == .untested)
        #expect(vm.tools.count == 29)
        #expect(vm.selectedToolID == nil)
        #expect(vm.parameterDefinitions.isEmpty)
        #expect(vm.parameterValues.isEmpty)
        #expect(vm.inputFiles.isEmpty)
        #expect(vm.outputPath == "")
        #expect(vm.fileDropState == .empty)
        #expect(vm.consoleStatus == .idle)
        #expect(vm.consoleOutput == "")
        #expect(vm.commandPreview == "")
        #expect(vm.commandHistory.isEmpty)
        #expect(vm.experienceMode == .beginner)
        #expect(!vm.glossaryEntries.isEmpty)
        #expect(vm.glossarySearchQuery == "")
    }

    // MARK: - 16.1 Network Configuration

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("addProfile increases profile count")
    func testAddProfile() {
        let vm = CLIWorkshopViewModel()
        let profile = CLINetworkProfile(name: "New")
        vm.addProfile(profile)
        #expect(vm.networkProfiles.count == 2)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("removeProfile decreases profile count")
    func testRemoveProfile() {
        let vm = CLIWorkshopViewModel()
        let profile = CLINetworkProfile(name: "ToRemove")
        vm.addProfile(profile)
        vm.removeProfile(id: profile.id)
        #expect(vm.networkProfiles.count == 1)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("removeProfile resets activeProfileID if removed profile was active")
    func testRemoveActiveProfile() {
        let vm = CLIWorkshopViewModel()
        let profile = CLINetworkProfile(name: "Active")
        vm.addProfile(profile)
        vm.setActiveProfile(id: profile.id)
        vm.removeProfile(id: profile.id)
        #expect(vm.activeProfileID != profile.id)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("updateProfile updates matching profile fields")
    func testUpdateProfile() {
        let vm = CLIWorkshopViewModel()
        var profile = CLINetworkProfile(name: "Original")
        vm.addProfile(profile)
        profile.name = "Updated"
        vm.updateProfile(profile)
        let updated = vm.networkProfiles.first { $0.id == profile.id }
        #expect(updated?.name == "Updated")
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("activeProfile returns first profile when no activeProfileID set")
    func testActiveProfileDefault() {
        let vm = CLIWorkshopViewModel()
        let profile = vm.activeProfile()
        #expect(profile != nil)
        #expect(profile?.name == "Default")
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("activeConnectionSummary returns formatted string")
    func testActiveConnectionSummary() {
        let vm = CLIWorkshopViewModel()
        let summary = vm.activeConnectionSummary()
        #expect(summary.contains("DICOMSTUDIO"))
        #expect(summary.contains("ANY-SCP"))
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("updateConnectionTestStatus changes status")
    func testUpdateConnectionTestStatus() {
        let vm = CLIWorkshopViewModel()
        vm.updateConnectionTestStatus(.success)
        #expect(vm.connectionTestStatus == .success)
    }

    // MARK: - 16.2 Tool Selection

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("selectTool updates selectedToolID")
    func testSelectTool() {
        let vm = CLIWorkshopViewModel()
        vm.selectTool(id: "dicom-info")
        #expect(vm.selectedToolID == "dicom-info")
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("selectTool resets parameters and console")
    func testSelectToolResetsState() {
        let vm = CLIWorkshopViewModel()
        vm.parameterValues = [CLIParameterValue(parameterID: "x", stringValue: "y")]
        vm.consoleOutput = "old output"
        vm.selectTool(id: "dicom-info")
        #expect(vm.parameterValues.isEmpty)
        #expect(vm.consoleOutput == "")
        #expect(vm.consoleStatus == .idle)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("selectedTool returns matching tool")
    func testSelectedTool() {
        let vm = CLIWorkshopViewModel()
        vm.selectTool(id: "dicom-info")
        let tool = vm.selectedTool()
        #expect(tool != nil)
        #expect(tool?.name == "dicom-info")
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("selectedTool returns nil when no tool selected")
    func testSelectedToolNil() {
        let vm = CLIWorkshopViewModel()
        #expect(vm.selectedTool() == nil)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("toolsForActiveTab returns tools for current tab")
    func testToolsForActiveTab() {
        let vm = CLIWorkshopViewModel()
        vm.activeTab = .fileInspection
        let tools = vm.toolsForActiveTab()
        #expect(tools.count == 4)
        for tool in tools {
            #expect(tool.category == .fileInspection)
        }
    }

    // MARK: - 16.3 Parameter Configuration

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("updateParameterValue creates new entry if missing")
    func testUpdateParameterValueCreates() {
        let vm = CLIWorkshopViewModel()
        vm.updateParameterValue(parameterID: "format", value: "json")
        #expect(vm.parameterValues.count == 1)
        #expect(vm.parameterValues[0].stringValue == "json")
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("updateParameterValue updates existing entry")
    func testUpdateParameterValueUpdates() {
        let vm = CLIWorkshopViewModel()
        vm.updateParameterValue(parameterID: "format", value: "json")
        vm.updateParameterValue(parameterID: "format", value: "csv")
        #expect(vm.parameterValues.count == 1)
        #expect(vm.parameterValues[0].stringValue == "csv")
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("isCommandValid returns true when required params are satisfied")
    func testIsCommandValidTrue() {
        let vm = CLIWorkshopViewModel()
        vm.setParameterDefinitions([
            CLIParameterDefinition(id: "input", flag: "", displayName: "Input", parameterType: .filePath, isRequired: true)
        ])
        vm.updateParameterValue(parameterID: "input", value: "file.dcm")
        #expect(vm.isCommandValid == true)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("isCommandValid returns false when required params are missing")
    func testIsCommandValidFalse() {
        let vm = CLIWorkshopViewModel()
        vm.setParameterDefinitions([
            CLIParameterDefinition(id: "input", flag: "", displayName: "Input", parameterType: .filePath, isRequired: true)
        ])
        #expect(vm.isCommandValid == false)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("visibleParameters in beginner mode hides advanced params")
    func testVisibleParametersBeginner() {
        let vm = CLIWorkshopViewModel()
        vm.setParameterDefinitions([
            CLIParameterDefinition(id: "input", flag: "", displayName: "Input", parameterType: .filePath, isAdvanced: false),
            CLIParameterDefinition(id: "force", flag: "--force-parse", displayName: "Force Parse", parameterType: .booleanToggle, isAdvanced: true),
        ])
        vm.experienceMode = .beginner
        let visible = vm.visibleParameters()
        #expect(visible.count == 1)
        #expect(visible[0].id == "input")
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("visibleParameters in advanced mode shows all params")
    func testVisibleParametersAdvanced() {
        let vm = CLIWorkshopViewModel()
        vm.setParameterDefinitions([
            CLIParameterDefinition(id: "input", flag: "", displayName: "Input", parameterType: .filePath, isAdvanced: false),
            CLIParameterDefinition(id: "force", flag: "--force-parse", displayName: "Force Parse", parameterType: .booleanToggle, isAdvanced: true),
        ])
        vm.experienceMode = .advanced
        let visible = vm.visibleParameters()
        #expect(visible.count == 2)
    }

    // MARK: - 16.4 File Drop Zone

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("addInputFile updates files and drop state")
    func testAddInputFile() {
        let vm = CLIWorkshopViewModel()
        let file = CLIFileEntry(path: "/f", filename: "scan.dcm")
        vm.addInputFile(file)
        #expect(vm.inputFiles.count == 1)
        #expect(vm.fileDropState == .selected)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("removeInputFile resets drop state when empty")
    func testRemoveInputFile() {
        let vm = CLIWorkshopViewModel()
        let file = CLIFileEntry(path: "/f", filename: "scan.dcm")
        vm.addInputFile(file)
        vm.removeInputFile(id: file.id)
        #expect(vm.inputFiles.isEmpty)
        #expect(vm.fileDropState == .empty)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("updateFileDropState changes state")
    func testUpdateFileDropState() {
        let vm = CLIWorkshopViewModel()
        vm.updateFileDropState(.dragHover)
        #expect(vm.fileDropState == .dragHover)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("updateOutputPath stores path")
    func testUpdateOutputPath() {
        let vm = CLIWorkshopViewModel()
        vm.updateOutputPath("/output")
        #expect(vm.outputPath == "/output")
    }

    // MARK: - 16.5 Console

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("rebuildCommandPreview generates correct preview")
    func testRebuildCommandPreview() {
        let vm = CLIWorkshopViewModel()
        vm.selectTool(id: "dicom-info")
        vm.setParameterDefinitions([
            CLIParameterDefinition(id: "format", flag: "--format", displayName: "Format", parameterType: .enumPicker)
        ])
        vm.updateParameterValue(parameterID: "format", value: "json")
        #expect(vm.commandPreview.contains("dicom-info"))
        #expect(vm.commandPreview.contains("--format"))
        #expect(vm.commandPreview.contains("json"))
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("rebuildCommandPreview is empty when no tool selected")
    func testRebuildCommandPreviewNoTool() {
        let vm = CLIWorkshopViewModel()
        vm.rebuildCommandPreview()
        #expect(vm.commandPreview == "")
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("commandTokens returns tokens for current preview")
    func testCommandTokens() {
        let vm = CLIWorkshopViewModel()
        vm.selectTool(id: "dicom-info")
        vm.setParameterDefinitions([
            CLIParameterDefinition(id: "format", flag: "--format", displayName: "Format", parameterType: .enumPicker)
        ])
        vm.updateParameterValue(parameterID: "format", value: "json")
        let tokens = vm.commandTokens()
        #expect(!tokens.isEmpty)
        #expect(tokens[0].tokenType == .toolName)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("clearConsoleOutput resets output and status")
    func testClearConsoleOutput() {
        let vm = CLIWorkshopViewModel()
        vm.consoleOutput = "some output"
        vm.consoleStatus = .success
        vm.clearConsoleOutput()
        #expect(vm.consoleOutput == "")
        #expect(vm.consoleStatus == .idle)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("appendConsoleOutput accumulates text")
    func testAppendConsoleOutput() {
        let vm = CLIWorkshopViewModel()
        vm.appendConsoleOutput("Line 1\n")
        vm.appendConsoleOutput("Line 2\n")
        #expect(vm.consoleOutput == "Line 1\nLine 2\n")
    }

    // MARK: - 16.6 Command History

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("addToHistory creates entry with PHI redaction")
    func testAddToHistory() {
        let vm = CLIWorkshopViewModel()
        vm.addToHistory(toolName: "dicom-anon", command: "dicom-anon --patient-name \"John Doe\" file.dcm",
                        exitCode: 0, output: "Done")
        #expect(vm.commandHistory.count == 1)
        #expect(vm.commandHistory[0].redactedCommand.contains("<redacted>"))
        #expect(!vm.commandHistory[0].redactedCommand.contains("John Doe"))
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("addToHistory sets completed state on exit code 0")
    func testAddToHistorySuccess() {
        let vm = CLIWorkshopViewModel()
        vm.addToHistory(toolName: "t", command: "c", exitCode: 0, output: "")
        #expect(vm.commandHistory[0].executionState == .completed)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("addToHistory sets failed state on non-zero exit code")
    func testAddToHistoryFailure() {
        let vm = CLIWorkshopViewModel()
        vm.addToHistory(toolName: "t", command: "c", exitCode: 1, output: "")
        #expect(vm.commandHistory[0].executionState == .failed)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("clearHistory removes all entries")
    func testClearHistory() {
        let vm = CLIWorkshopViewModel()
        vm.addToHistory(toolName: "t", command: "c", exitCode: 0, output: "")
        vm.clearHistory()
        #expect(vm.commandHistory.isEmpty)
    }

    // MARK: - 16.8 Educational Features

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("toggleExperienceMode switches between modes")
    func testToggleExperienceMode() {
        let vm = CLIWorkshopViewModel()
        #expect(vm.experienceMode == .beginner)
        vm.toggleExperienceMode()
        #expect(vm.experienceMode == .advanced)
        vm.toggleExperienceMode()
        #expect(vm.experienceMode == .beginner)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("setExperienceMode directly sets mode")
    func testSetExperienceMode() {
        let vm = CLIWorkshopViewModel()
        vm.setExperienceMode(.advanced)
        #expect(vm.experienceMode == .advanced)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("filteredGlossaryEntries returns all for empty query")
    func testFilteredGlossaryAll() {
        let vm = CLIWorkshopViewModel()
        let all = vm.filteredGlossaryEntries()
        #expect(all.count == vm.glossaryEntries.count)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("filteredGlossaryEntries filters by query")
    func testFilteredGlossaryQuery() {
        let vm = CLIWorkshopViewModel()
        vm.updateGlossarySearch("AE Title")
        let filtered = vm.filteredGlossaryEntries()
        #expect(filtered.count >= 1)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("examplePresetsForSelectedTool returns presets for known tool")
    func testExamplePresetsForTool() {
        let vm = CLIWorkshopViewModel()
        vm.selectTool(id: "dicom-info")
        let presets = vm.examplePresetsForSelectedTool()
        #expect(!presets.isEmpty)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("examplePresetsForSelectedTool returns empty when no tool selected")
    func testExamplePresetsNoTool() {
        let vm = CLIWorkshopViewModel()
        let presets = vm.examplePresetsForSelectedTool()
        #expect(presets.isEmpty)
    }
}
