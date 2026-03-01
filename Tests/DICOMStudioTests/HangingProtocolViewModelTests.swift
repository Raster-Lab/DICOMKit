// HangingProtocolViewModelTests.swift
// DICOMStudioTests
//
// Tests for HangingProtocolViewModel

import Testing
@testable import DICOMStudio
import Foundation

@Suite("HangingProtocolViewModel Tests")
struct HangingProtocolViewModelTests {

    @Test("Initial state")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testInitialState() {
        let vm = HangingProtocolViewModel()
        #expect(vm.currentLayout == .single)
        #expect(!vm.hasActiveProtocol)
        #expect(vm.userProtocols.isEmpty)
        #expect(!vm.isEditing)
        #expect(!vm.allProtocols.isEmpty) // Built-in protocols loaded
    }

    @Test("Apply protocol")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testApplyProtocol() {
        let vm = HangingProtocolViewModel()
        let proto = HangingProtocolModel(name: "Test", layoutType: .twoByTwo)
        vm.applyProtocol(proto)
        #expect(vm.hasActiveProtocol)
        #expect(vm.currentLayout == .twoByTwo)
        #expect(vm.activeProtocolName == "Test")
    }

    @Test("Clear protocol")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testClearProtocol() {
        let vm = HangingProtocolViewModel()
        let proto = HangingProtocolModel(name: "Test", layoutType: .twoByTwo)
        vm.applyProtocol(proto)
        vm.clearProtocol()
        #expect(!vm.hasActiveProtocol)
        #expect(vm.currentLayout == .single)
    }

    @Test("Auto-select CT protocol")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testAutoSelectCT() {
        let vm = HangingProtocolViewModel()
        vm.autoSelectProtocol(modality: "CT")
        #expect(vm.hasActiveProtocol)
    }

    @Test("Set layout directly")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetLayout() {
        let vm = HangingProtocolViewModel()
        vm.setLayout(.threeByThree)
        #expect(vm.currentLayout == .threeByThree)
    }

    @Test("Set custom layout")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testSetCustomLayout() {
        let vm = HangingProtocolViewModel()
        vm.setCustomLayout(columns: 3, rows: 2)
        #expect(vm.currentLayout == .custom)
        #expect(vm.customColumns == 3)
        #expect(vm.customRows == 2)
    }

    @Test("Custom layout clamped to max")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCustomLayoutClamped() {
        let vm = HangingProtocolViewModel()
        vm.setCustomLayout(columns: 10, rows: 10)
        #expect(vm.customColumns == 4)
        #expect(vm.customRows == 4)
    }

    @Test("Protocol editing - save")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testProtocolEditingSave() {
        let vm = HangingProtocolViewModel()
        vm.startNewProtocol()
        #expect(vm.isEditing)

        vm.editingName = "My CT"
        vm.editingModality = "CT"
        vm.editingLayoutType = .twoByTwo

        let result = vm.saveEditedProtocol()
        #expect(result != nil)
        #expect(result?.name == "My CT")
        #expect(!vm.isEditing)
        #expect(vm.userProtocols.count == 1)
    }

    @Test("Protocol editing - save empty name fails")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testProtocolEditingEmptyName() {
        let vm = HangingProtocolViewModel()
        vm.startNewProtocol()
        vm.editingName = ""
        vm.editingModality = "CT"

        let result = vm.saveEditedProtocol()
        #expect(result == nil)
    }

    @Test("Protocol editing - cancel")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testProtocolEditingCancel() {
        let vm = HangingProtocolViewModel()
        vm.startNewProtocol()
        vm.editingName = "My CT"
        vm.cancelEditing()
        #expect(!vm.isEditing)
        #expect(vm.editingName.isEmpty)
    }

    @Test("Delete user protocol")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testDeleteUserProtocol() {
        let vm = HangingProtocolViewModel()
        vm.startNewProtocol()
        vm.editingName = "To Delete"
        vm.editingModality = "CT"
        let proto = vm.saveEditedProtocol()!

        vm.applyProtocol(proto)
        vm.deleteUserProtocol(proto.id)
        #expect(vm.userProtocols.isEmpty)
        #expect(!vm.hasActiveProtocol)
    }

    @Test("Edit existing protocol")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testEditExisting() {
        let vm = HangingProtocolViewModel()
        let proto = HangingProtocolModel(
            name: "Existing",
            layoutType: .twoByOne,
            matchingCriteria: ProtocolMatchingCriteria(modality: "CT")
        )
        vm.startEditingProtocol(proto)
        #expect(vm.isEditing)
        #expect(vm.editingName == "Existing")
        #expect(vm.editingModality == "CT")
    }

    @Test("Layout description")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testLayoutDescription() {
        let vm = HangingProtocolViewModel()
        vm.setLayout(.twoByTwo)
        #expect(vm.layoutDescription == "2×2 (4 viewports)")
    }

    @Test("Effective dimensions")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testEffectiveDimensions() {
        let vm = HangingProtocolViewModel()
        vm.setLayout(.threeByTwo)
        #expect(vm.effectiveColumns == 3)
        #expect(vm.effectiveRows == 1) // 3x2 is 3 cols, 1 row
        #expect(vm.effectiveCellCount == 3)
    }

    @Test("Custom layout effective dimensions")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testCustomEffectiveDimensions() {
        let vm = HangingProtocolViewModel()
        vm.setCustomLayout(columns: 3, rows: 2)
        #expect(vm.effectiveColumns == 3)
        #expect(vm.effectiveRows == 2)
        #expect(vm.effectiveCellCount == 6)
    }

    @Test("Service injection")
    @available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
    func testServiceInjection() {
        let service = HangingProtocolService()
        let vm = HangingProtocolViewModel(hangingProtocolService: service)
        #expect(vm.hangingProtocolService === service)
    }
}
