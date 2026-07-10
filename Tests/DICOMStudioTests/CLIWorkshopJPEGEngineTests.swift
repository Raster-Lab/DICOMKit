// CLIWorkshopJPEGEngineTests.swift
// DICOMStudioTests
//
// The Workshop-only "JPEG Engine" picker for dicom-compress: it must appear for a
// JPEG Baseline compress and nowhere else, and it must never leak into the
// copy-pasteable command preview (the `dicom-compress` CLI has no such flag).

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMKit
import Foundation

@Suite("CLI Workshop — dicom-compress JPEG engine picker")
@MainActor
struct CLIWorkshopJPEGEngineTests {

    /// The dicom-compress parameter definitions, as the Workshop builds them.
    private var defs: [CLIParameterDefinition] {
        ToolCatalogHelpers.parameterDefinitions(for: "dicom-compress")
    }

    private func viewModel() -> CLIWorkshopViewModel {
        let vm = CLIWorkshopViewModel()
        vm.setParameterDefinitions(defs)
        return vm
    }

    private func isVisible(_ id: String, in vm: CLIWorkshopViewModel) -> Bool {
        vm.visibleParameters().contains { $0.id == id }
    }

    // MARK: - Definition shape

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("jpegCodec is defined, internal, and offers exactly the two engines")
    func testDefinitionShape() throws {
        let def = try #require(defs.first { $0.id == "jpegCodec" })
        #expect(def.parameterType == .enumPicker)
        #expect(def.allowedValues == JPEGCodecEngine.allCases.map { $0.rawValue })
        #expect(def.defaultValue == JPEGCodecEngine.jli.rawValue)
        // Internal + no flag: this is an in-app encoder choice, not a CLI option.
        #expect(def.isInternal == true)
        #expect(def.flag.isEmpty)
        #expect(def.cliMapping.isEmpty)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("jpegCodec is gated on BOTH operation=compress and codec=jpeg")
    func testDefinitionConditions() throws {
        let def = try #require(defs.first { $0.id == "jpegCodec" })
        #expect(def.visibleWhen?.parameterId == "operation")
        #expect(def.visibleWhen?.values == ["compress"])
        let codecCondition = try #require(def.visibleWhenAll.first { $0.parameterId == "codec" })
        // Derived from the codec map, so it tracks the canonical Baseline codec name.
        #expect(codecCondition.values == ["jpeg"])
    }

    // MARK: - Visibility

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Visible for a JPEG Baseline compress")
    func testVisibleForBaselineCompress() {
        let vm = viewModel()
        vm.updateParameterValue(parameterID: "operation", value: "compress")
        vm.updateParameterValue(parameterID: "codec", value: "jpeg")
        #expect(isVisible("jpegCodec", in: vm))
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Hidden for the other three JPEG syntaxes — ImageIO cannot encode them")
    func testHiddenForOtherJPEGSyntaxes() {
        for codec in ["jpeg-extended", "jpeg-lossless", "jpeg-lossless-sv1"] {
            let vm = viewModel()
            vm.updateParameterValue(parameterID: "operation", value: "compress")
            vm.updateParameterValue(parameterID: "codec", value: codec)
            #expect(!isVisible("jpegCodec", in: vm), "picker leaked for \(codec)")
        }
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Hidden for non-JPEG codecs")
    func testHiddenForNonJPEGCodecs() {
        for codec in ["jpeg2000", "htj2k-lossless", "rle", "jpeg-ls-lossless", "explicit-le"] {
            let vm = viewModel()
            vm.updateParameterValue(parameterID: "operation", value: "compress")
            vm.updateParameterValue(parameterID: "codec", value: codec)
            #expect(!isVisible("jpegCodec", in: vm), "picker leaked for \(codec)")
        }
    }

    /// The regression the second condition exists for: `codec` keeps its value when the
    /// user switches operation, so a single `codec == jpeg` gate would leave the picker
    /// showing on the decompress / batch / info forms.
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Hidden on other operations even after codec was set to jpeg")
    func testHiddenOnOtherOperationsWithStaleCodec() {
        for operation in ["info", "decompress", "batch", "backends"] {
            let vm = viewModel()
            vm.updateParameterValue(parameterID: "operation", value: "compress")
            vm.updateParameterValue(parameterID: "codec", value: "jpeg")
            #expect(isVisible("jpegCodec", in: vm))

            vm.updateParameterValue(parameterID: "operation", value: operation)
            #expect(!isVisible("jpegCodec", in: vm),
                    "picker leaked into '\(operation)' via the stale codec value")
        }
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Hidden by default — the codec default is jpeg-lossless, not jpeg")
    func testHiddenAtDefaults() {
        let vm = viewModel()
        vm.updateParameterValue(parameterID: "operation", value: "compress")
        #expect(!isVisible("jpegCodec", in: vm))
    }

    // MARK: - Command preview

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("jpegCodec never appears in the command preview")
    func testExcludedFromCommandPreview() {
        let values = [
            CLIParameterValue(parameterID: "operation", stringValue: "compress"),
            CLIParameterValue(parameterID: "input", stringValue: "in.dcm"),
            CLIParameterValue(parameterID: "output", stringValue: "out.dcm"),
            CLIParameterValue(parameterID: "codec", stringValue: "jpeg"),
            CLIParameterValue(parameterID: "jpegCodec", stringValue: "native"),
        ]
        let command = CommandBuilderHelpers.buildCommand(
            toolName: "dicom-compress",
            parameterValues: values,
            parameterDefinitions: defs
        )
        // The real CLI has no --jpeg-codec flag, so the pasted command must not carry it
        // (nor a bare "native" token) — it would fail to parse.
        #expect(!command.contains("jpeg-codec"))
        #expect(!command.contains("jpegCodec"))
        #expect(!command.contains("native"))
        // ...while the genuine CLI options still render.
        #expect(command.contains("--codec jpeg"))
        #expect(command.contains("--output out.dcm"))
    }

    // MARK: - Value → engine mapping

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("Picker values round-trip to JPEGCodecEngine; junk falls back to .jli")
    func testEngineRawValueMapping() {
        #expect(JPEGCodecEngine(rawValue: "jli") == .jli)
        #expect(JPEGCodecEngine(rawValue: "native") == .native)
        // The executor's fallback for an unset/unknown stored value.
        #expect((JPEGCodecEngine(rawValue: "") ?? .jli) == .jli)
        #expect((JPEGCodecEngine(rawValue: "bogus") ?? .jli) == .jli)
    }
}
