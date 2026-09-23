// CLIWorkshopTransitiveVisibilityTests.swift
// DICOMStudioTests
//
// Visibility conditions chain: dicom-mwl's HL7 fields are gated on `create-method`,
// which is itself gated on `operation == create`. The original bug: `satisfies` falls
// back to a referenced parameter's `defaultValue` when unset, so under `operation ==
// query` the hidden `create-method` still read as its default "hl7" and dragged the
// HL7 Port and MSH-3…MSH-6 fields into the query form — which speaks DIMSE C-FIND and
// has no HL7/MLLP leg at all. These tests assert visibility is transitive: a condition
// on a hidden controller cannot hold.

import Testing
@testable import DICOMStudio
import DICOMCore
import DICOMKit
import Foundation

@Suite("CLI Workshop — transitive parameter visibility")
@MainActor
struct CLIWorkshopTransitiveVisibilityTests {

    /// The dicom-mwl parameter definitions, as the Workshop builds them.
    private var defs: [CLIParameterDefinition] {
        ToolCatalogHelpers.parameterDefinitions(for: "dicom-mwl")
    }

    /// Every parameter that travels only on the HL7 ORM^O01 create path.
    private static let hl7OnlyIDs = [
        "hl7-port",
        "sending-application",
        "sending-facility",
        "receiving-application",
        "receiving-facility"
    ]

    /// A view model on the dicom-mwl spec, in Advanced mode so that `visibleParameters()`
    /// returns advanced parameters too (the four MSH fields are `isAdvanced`) and one
    /// membership check covers the whole form.
    private func viewModel(operation: String, createMethod: String? = nil) -> CLIWorkshopViewModel {
        let vm = CLIWorkshopViewModel()
        vm.setParameterDefinitions(defs)
        vm.experienceMode = .advanced
        vm.updateParameterValue(parameterID: "operation", value: operation)
        if let createMethod {
            vm.updateParameterValue(parameterID: "create-method", value: createMethod)
        }
        return vm
    }

    private func isVisible(_ id: String, in vm: CLIWorkshopViewModel) -> Bool {
        vm.visibleParameters().contains { $0.id == id }
    }

    // MARK: - Spec shape

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("create-method is gated on the create operation and defaults to hl7")
    func testCreateMethodIsItselfConditional() throws {
        let def = try #require(defs.first { $0.id == "create-method" })
        let condition = try #require(def.visibleWhen)
        #expect(condition.parameterId == "operation")
        #expect(condition.values == ["create"])
        // The default is what leaked: it makes a hidden controller still report "hl7".
        #expect(def.defaultValue == "hl7")
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("every HL7-only parameter is gated on create-method == hl7")
    func testHL7ParametersAreGatedOnCreateMethod() throws {
        for id in Self.hl7OnlyIDs {
            let def = try #require(defs.first { $0.id == id }, "missing \(id)")
            let condition = try #require(def.visibleWhen, "\(id) has no visibleWhen")
            #expect(condition.parameterId == "create-method", "\(id)")
            #expect(condition.values == ["hl7"], "\(id)")
        }
    }

    // MARK: - The regression

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("HL7 fields stay hidden in the query form")
    func testHL7FieldsHiddenForQuery() {
        let vm = viewModel(operation: "query")
        #expect(isVisible("create-method", in: vm) == false)
        for id in Self.hl7OnlyIDs {
            #expect(isVisible(id, in: vm) == false, "\(id) leaked into the query form")
        }
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("the REST-only field also stays hidden in the query form")
    func testRESTFieldHiddenForQuery() {
        // rest-base-url is gated on create-method == "rest"; it must not reappear
        // under query after the user has visited the create form and chosen REST.
        let vm = viewModel(operation: "query", createMethod: "rest")
        #expect(isVisible("rest-base-url", in: vm) == false)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("query-only filters remain visible in the query form")
    func testQueryFiltersStillVisible() {
        // Guards against over-hiding: the fix must not suppress ordinary
        // single-condition parameters gated directly on `operation`.
        let vm = viewModel(operation: "query")
        for id in ["date-from", "time-from", "station", "patient", "patient-id",
                   "modality", "sps-status", "query-accession-number"] {
            #expect(isVisible(id, in: vm) == true, "\(id) should be visible for query")
        }
    }

    // MARK: - The create form still works

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("HL7 fields appear for an HL7 create")
    func testHL7FieldsVisibleForHL7Create() {
        let vm = viewModel(operation: "create", createMethod: "hl7")
        #expect(isVisible("create-method", in: vm) == true)
        for id in Self.hl7OnlyIDs {
            #expect(isVisible(id, in: vm) == true, "\(id) should be visible for an HL7 create")
        }
        #expect(isVisible("rest-base-url", in: vm) == false)
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("HL7 fields appear for a create that leaves create-method at its default")
    func testHL7FieldsVisibleForDefaultedCreate() {
        // The defaultValue fallback is legitimate here: create-method is visible,
        // so its unset default of "hl7" should drive the HL7 fields on.
        let vm = viewModel(operation: "create")
        for id in Self.hl7OnlyIDs {
            #expect(isVisible(id, in: vm) == true, "\(id) should follow the hl7 default")
        }
    }

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("choosing REST swaps the HL7 fields for the REST base URL")
    func testRESTCreateHidesHL7Fields() {
        let vm = viewModel(operation: "create", createMethod: "rest")
        #expect(isVisible("rest-base-url", in: vm) == true)
        for id in Self.hl7OnlyIDs {
            #expect(isVisible(id, in: vm) == false, "\(id) should be hidden for a REST create")
        }
    }

    // MARK: - Command preview

    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    @Test("no HL7 flag reaches the query command preview")
    func testQueryPreviewCarriesNoHL7Flags() {
        let vm = viewModel(operation: "query")
        vm.updateParameterValue(parameterID: "host", value: "172.17.1.200")
        vm.rebuildCommandPreview()
        let preview = vm.commandPreview
        // These parameters are `isInternal`, so they were already excluded from the
        // preview; assert it explicitly so a future un-internalling cannot regress it.
        for flag in ["--hl7-port", "--sending-app", "--sending-facility",
                     "--receiving-app", "--receiving-facility"] {
            #expect(preview.contains(flag) == false, "preview leaked \(flag)")
        }
    }
}
