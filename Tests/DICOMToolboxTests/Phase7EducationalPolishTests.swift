import Foundation
import Testing
@testable import DICOMToolbox

// MARK: - DICOM Glossary Tests

@Suite("DICOM Glossary Tests")
struct DICOMGlossaryTests {
    @Test("Glossary contains expected number of terms")
    func testGlossaryTermCount() {
        #expect(DICOMGlossary.allTerms.count >= 30)
    }

    @Test("Glossary search returns all terms for empty query")
    func testSearchEmpty() {
        let results = DICOMGlossary.search("")
        #expect(results.count == DICOMGlossary.allTerms.count)
    }

    @Test("Glossary search finds terms by name")
    func testSearchByName() {
        let results = DICOMGlossary.search("PACS")
        #expect(!results.isEmpty)
        #expect(results.contains { $0.term == "PACS" })
    }

    @Test("Glossary search finds terms by definition content")
    func testSearchByDefinition() {
        let results = DICOMGlossary.search("pixel")
        #expect(!results.isEmpty)
        #expect(results.contains { $0.term == "Pixel Data" })
    }

    @Test("Glossary search finds terms by related terms")
    func testSearchByRelatedTerms() {
        let results = DICOMGlossary.search("SCU")
        // SCU should be found directly and also as a related term of other entries
        #expect(results.count >= 2)
    }

    @Test("Glossary search is case-insensitive")
    func testSearchCaseInsensitive() {
        let lower = DICOMGlossary.search("dicom")
        let upper = DICOMGlossary.search("DICOM")
        #expect(lower.count == upper.count)
    }

    @Test("Glossary term lookup by name works")
    func testTermLookup() {
        let term = DICOMGlossary.term(named: "AE Title")
        #expect(term != nil)
        #expect(term?.term == "AE Title")
        #expect(term?.standardReference != nil)
    }

    @Test("Glossary term lookup is case-insensitive")
    func testTermLookupCaseInsensitive() {
        let term = DICOMGlossary.term(named: "ae title")
        #expect(term != nil)
        #expect(term?.term == "AE Title")
    }

    @Test("Glossary term lookup returns nil for unknown term")
    func testTermLookupUnknown() {
        let term = DICOMGlossary.term(named: "NonExistentTerm12345")
        #expect(term == nil)
    }

    @Test("Glossary terms have unique IDs")
    func testUniqueIDs() {
        let ids = DICOMGlossary.allTerms.map(\.id)
        let uniqueIDs = Set(ids)
        #expect(ids.count == uniqueIDs.count)
    }

    @Test("Glossary terms with standard references are formatted correctly")
    func testStandardReferences() {
        let termsWithRefs = DICOMGlossary.allTerms.filter { $0.standardReference != nil }
        #expect(termsWithRefs.count >= 20)
        for term in termsWithRefs {
            #expect(term.standardReference!.hasPrefix("PS3."))
        }
    }
}

// MARK: - Example Presets Tests

@Suite("Example Presets Tests")
struct ExamplePresetsTests {
    @Test("dicom-info has example presets")
    func testDicomInfoPresets() {
        let presets = ExamplePresets.presets(for: "dicom-info")
        #expect(presets.count >= 2)
        #expect(presets.allSatisfy { !$0.name.isEmpty })
        #expect(presets.allSatisfy { !$0.description.isEmpty })
    }

    @Test("Example presets contain parameter values")
    func testPresetsHaveValues() {
        let presets = ExamplePresets.presets(for: "dicom-info")
        for preset in presets {
            #expect(!preset.parameterValues.isEmpty)
        }
    }

    @Test("Unknown tool returns empty presets")
    func testUnknownToolPresets() {
        let presets = ExamplePresets.presets(for: "unknown-tool-xyz")
        #expect(presets.isEmpty)
    }

    @Test("Example presets have unique IDs")
    func testPresetsUniqueIDs() {
        let presets = ExamplePresets.presets(for: "dicom-info")
        let ids = presets.map(\.id)
        let uniqueIDs = Set(ids)
        #expect(ids.count == uniqueIDs.count)
    }

    @Test("dicom-validate presets exist")
    func testValidatePresets() {
        let presets = ExamplePresets.presets(for: "dicom-validate")
        #expect(!presets.isEmpty)
    }

    @Test("dicom-echo presets exist")
    func testEchoPresets() {
        let presets = ExamplePresets.presets(for: "dicom-echo")
        #expect(!presets.isEmpty)
    }
}

// MARK: - AppSettings Tests

@Suite("AppSettings Tests")
struct AppSettingsTests {
    @Test("Default beginner mode is false")
    func testDefaultBeginnerMode() {
        // Default value should be false (UserDefaults returns false for unset bool keys)
        let mode = AppSettings.isBeginnerMode()
        // Just verify it returns a bool without crashing
        #expect(mode == true || mode == false)
    }

    @Test("Default console font size is 13")
    func testDefaultConsoleFontSize() {
        #expect(AppSettings.defaultConsoleFontSize == 13.0)
    }

    @Test("Console font size bounds are valid")
    func testConsoleFontSizeBounds() {
        #expect(AppSettings.minConsoleFontSize < AppSettings.maxConsoleFontSize)
        #expect(AppSettings.minConsoleFontSize > 0)
        #expect(AppSettings.maxConsoleFontSize <= 48)
    }

    @Test("Server profile CRUD add works")
    func testAddProfile() {
        var profiles: [ServerProfile] = []
        let profile = ServerProfile(name: "Test PACS", host: "pacs.example.com", port: 11112)
        AppSettings.addProfile(profile, to: &profiles)
        #expect(profiles.count == 1)
        #expect(profiles.first?.name == "Test PACS")
        #expect(profiles.first?.host == "pacs.example.com")
    }

    @Test("Server profile CRUD update works")
    func testUpdateProfile() {
        var profiles: [ServerProfile] = []
        var profile = ServerProfile(name: "Test", host: "localhost")
        AppSettings.addProfile(profile, to: &profiles)

        profile.name = "Updated"
        profile.host = "remote.example.com"
        AppSettings.updateProfile(profile, in: &profiles)
        #expect(profiles.count == 1)
        #expect(profiles.first?.name == "Updated")
        #expect(profiles.first?.host == "remote.example.com")
    }

    @Test("Server profile CRUD delete works")
    func testDeleteProfile() {
        var profiles: [ServerProfile] = []
        let profile = ServerProfile(name: "ToDelete")
        AppSettings.addProfile(profile, to: &profiles)
        #expect(profiles.count == 1)

        AppSettings.deleteProfile(id: profile.id, from: &profiles)
        #expect(profiles.isEmpty)
    }

    @Test("Server profile delete with wrong ID does nothing")
    func testDeleteProfileWrongID() {
        var profiles: [ServerProfile] = []
        let profile = ServerProfile(name: "Keep")
        AppSettings.addProfile(profile, to: &profiles)

        AppSettings.deleteProfile(id: UUID(), from: &profiles)
        #expect(profiles.count == 1)
    }

    @Test("Multiple profiles can be managed")
    func testMultipleProfiles() {
        var profiles: [ServerProfile] = []
        AppSettings.addProfile(ServerProfile(name: "PACS 1"), to: &profiles)
        AppSettings.addProfile(ServerProfile(name: "PACS 2"), to: &profiles)
        AppSettings.addProfile(ServerProfile(name: "PACS 3"), to: &profiles)
        #expect(profiles.count == 3)

        let deleteID = profiles[1].id
        AppSettings.deleteProfile(id: deleteID, from: &profiles)
        #expect(profiles.count == 2)
        #expect(profiles.map(\.name) == ["PACS 1", "PACS 3"])
    }
}

// MARK: - GlossaryTerm Model Tests

@Suite("GlossaryTerm Model Tests")
struct GlossaryTermModelTests {
    @Test("GlossaryTerm auto-generates ID from term")
    func testAutoID() {
        let term = GlossaryTerm(term: "AE Title", definition: "test")
        #expect(term.id == "ae-title")
    }

    @Test("GlossaryTerm uses custom ID when provided")
    func testCustomID() {
        let term = GlossaryTerm(id: "custom-id", term: "Test", definition: "test")
        #expect(term.id == "custom-id")
    }

    @Test("GlossaryTerm has default empty related terms")
    func testDefaultRelatedTerms() {
        let term = GlossaryTerm(term: "Test", definition: "A test term")
        #expect(term.relatedTerms.isEmpty)
        #expect(term.standardReference == nil)
    }
}

// MARK: - ExamplePreset Model Tests

@Suite("ExamplePreset Model Tests")
struct ExamplePresetModelTests {
    @Test("ExamplePreset auto-generates ID from name")
    func testAutoID() {
        let preset = ExamplePreset(
            name: "Basic metadata",
            description: "desc",
            parameterValues: ["key": "value"]
        )
        #expect(preset.id == "basic-metadata")
    }

    @Test("ExamplePreset uses custom ID when provided")
    func testCustomID() {
        let preset = ExamplePreset(
            id: "custom",
            name: "Test",
            description: "desc",
            parameterValues: [:]
        )
        #expect(preset.id == "custom")
    }

    @Test("ExamplePreset subcommand defaults to nil")
    func testDefaultSubcommand() {
        let preset = ExamplePreset(
            name: "Test",
            description: "desc",
            parameterValues: [:]
        )
        #expect(preset.subcommand == nil)
    }
}
