// GatewayViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for DICOM Gateway feature (dicom-gateway)

import Foundation
import Observation

/// ViewModel for the DICOM Gateway feature.
///
/// Manages HL7 v2 ↔ DICOM and FHIR R4 ↔ DICOM conversion,
/// routing rules, and gateway monitoring.
@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
@MainActor
public final class GatewayViewModel {
    private let service: GatewayService

    // MARK: - Navigation

    public var activeTab: GatewayTab = .gatewayConfig

    // MARK: - Configuration

    public var configuration: GatewayConfiguration
    public var isGatewayRunning: Bool = false

    // MARK: - HL7 Conversion

    public var hl7InputPath: String = ""
    public var hl7OutputPath: String = ""
    public var hl7ToFhir: Bool = false
    public var hl7ConversionResult: String = ""

    // MARK: - FHIR Conversion

    public var fhirInputPath: String = ""
    public var fhirOutputPath: String = ""
    public var fhirToDicom: Bool = true
    public var fhirConversionResult: String = ""

    // MARK: - Routing Rules

    public var routingRules: [RoutingRule] = []
    public var newRule: RoutingRule = RoutingRule(name: "")
    public var isAddRuleSheetPresented: Bool = false

    // MARK: - Monitoring

    public var events: [GatewayEvent] = []
    public var eventLevelFilter: GatewayEventLevel? = nil

    // MARK: - UI State

    public var isLoading: Bool = false
    public var errorMessage: String? = nil
    public var statusMessage: String = "Gateway stopped."

    public init(service: GatewayService = GatewayService()) {
        self.service = service
        self.configuration = service.configuration
        self.routingRules = service.routingRules
        self.events = service.events
        self.isGatewayRunning = service.isRunning
    }

    // MARK: - Gateway Control

    public func startGateway() {
        service.setRunning(true)
        isGatewayRunning = true
        statusMessage = "Gateway running on port \(configuration.listenPort)…"
        let event = GatewayEvent(
            level: .info,
            sourceProtocol: configuration.listenProtocol,
            targetProtocol: configuration.targetProtocol,
            message: "Gateway started on port \(configuration.listenPort)"
        )
        service.appendEvent(event)
        events = service.events
    }

    public func stopGateway() {
        service.setRunning(false)
        isGatewayRunning = false
        statusMessage = "Gateway stopped."
        let event = GatewayEvent(
            level: .info,
            sourceProtocol: configuration.listenProtocol,
            targetProtocol: configuration.targetProtocol,
            message: "Gateway stopped"
        )
        service.appendEvent(event)
        events = service.events
    }

    public func saveConfiguration() {
        service.configuration = configuration
        statusMessage = "Configuration saved."
    }

    // MARK: - HL7 Conversion

    public func convertHL7() {
        guard !hl7InputPath.isEmpty else {
            errorMessage = "HL7 input path is required."
            return
        }
        let direction = hl7ToFhir ? "HL7 → FHIR" : "HL7 → DICOM"
        hl7ConversionResult = "[\(direction)] dicom-gateway convert \"\(hl7InputPath)\" --source hl7 --target \(hl7ToFhir ? "fhir" : "dicom") \(hl7OutputPath.isEmpty ? "" : "--output \"\(hl7OutputPath)\"")"
    }

    // MARK: - FHIR Conversion

    public func convertFHIR() {
        guard !fhirInputPath.isEmpty else {
            errorMessage = "FHIR input path is required."
            return
        }
        let direction = fhirToDicom ? "FHIR → DICOM" : "DICOM → FHIR"
        fhirConversionResult = "[\(direction)] dicom-gateway convert \"\(fhirInputPath)\" --source \(fhirToDicom ? "fhir" : "dicom") --target \(fhirToDicom ? "dicom" : "fhir") \(fhirOutputPath.isEmpty ? "" : "--output \"\(fhirOutputPath)\"")"
    }

    // MARK: - Routing Rules

    public func addRoutingRule() {
        guard !newRule.name.isEmpty else {
            errorMessage = "Rule name is required."
            return
        }
        service.addRoutingRule(newRule)
        routingRules = service.routingRules
        newRule = RoutingRule(name: "")
        isAddRuleSheetPresented = false
    }

    public func removeRoutingRule(id: UUID) {
        service.removeRoutingRule(id: id)
        routingRules = service.routingRules
    }

    public func toggleRoutingRule(id: UUID) {
        if let idx = routingRules.firstIndex(where: { $0.id == id }) {
            var rule = routingRules[idx]
            rule.isEnabled.toggle()
            service.updateRoutingRule(rule)
            routingRules = service.routingRules
        }
    }

    // MARK: - Monitoring

    public var filteredEvents: [GatewayEvent] {
        guard let filter = eventLevelFilter else { return events }
        return events.filter { $0.level == filter }
    }

    public func clearEvents() {
        service.clearEvents()
        events = service.events
    }
}
