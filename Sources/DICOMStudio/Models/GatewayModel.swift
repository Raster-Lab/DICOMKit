// GatewayModel.swift
// DICOMStudio
//
// DICOM Studio — Data models for the DICOM Gateway (dicom-gateway)
// Reference: IHE ITI – HL7v2 and FHIR integration profiles

import Foundation

// MARK: - Navigation Tab

/// Navigation tabs for the DICOM Gateway feature.
public enum GatewayTab: String, Sendable, Equatable, Hashable, CaseIterable, Identifiable {
    case gatewayConfig  = "GATEWAY_CONFIG"
    case hl7Conversion  = "HL7_CONVERSION"
    case fhirConversion = "FHIR_CONVERSION"
    case routing        = "ROUTING"
    case monitoring     = "MONITORING"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gatewayConfig:  return "Configuration"
        case .hl7Conversion:  return "HL7 Conversion"
        case .fhirConversion: return "FHIR Conversion"
        case .routing:        return "Routing"
        case .monitoring:     return "Monitoring"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .gatewayConfig:  return "gearshape.2"
        case .hl7Conversion:  return "arrow.left.arrow.right"
        case .fhirConversion: return "flame"
        case .routing:        return "arrow.triangle.branch"
        case .monitoring:     return "chart.xyaxis.line"
        }
    }
}

// MARK: - Gateway Protocol

/// Supported gateway interoperability protocols.
public enum GatewayProtocol: String, Sendable, Equatable, Hashable, CaseIterable, Identifiable {
    case hl7v2  = "HL7_V2"
    case fhirR4 = "FHIR_R4"
    case dicom  = "DICOM"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .hl7v2:  return "HL7 v2.x"
        case .fhirR4: return "FHIR R4"
        case .dicom:  return "DICOM"
        }
    }
}

// MARK: - Gateway Mode

/// Operating mode for the gateway.
public enum GatewayOperationMode: String, Sendable, Equatable, Hashable, CaseIterable, Identifiable {
    case convert       = "CONVERT"
    case listen        = "LISTEN"
    case forward       = "FORWARD"
    case bidirectional = "BIDIRECTIONAL"
    case batch         = "BATCH"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .convert:       return "Convert"
        case .listen:        return "Listen"
        case .forward:       return "Forward"
        case .bidirectional: return "Bidirectional"
        case .batch:         return "Batch"
        }
    }
}

// MARK: - Gateway Configuration

/// Configuration for the DICOM Gateway.
public struct GatewayConfiguration: Sendable, Hashable {
    public var listenPort: Int
    public var listenProtocol: GatewayProtocol
    public var targetHost: String
    public var targetPort: Int
    public var targetProtocol: GatewayProtocol
    public var operationMode: GatewayOperationMode
    public var includePrivateTags: Bool
    public var handleMissingFields: MissingFieldBehavior

    public init(
        listenPort: Int = 2575,
        listenProtocol: GatewayProtocol = .hl7v2,
        targetHost: String = "localhost",
        targetPort: Int = 104,
        targetProtocol: GatewayProtocol = .dicom,
        operationMode: GatewayOperationMode = .convert,
        includePrivateTags: Bool = false,
        handleMissingFields: MissingFieldBehavior = .useDefault
    ) {
        self.listenPort = listenPort
        self.listenProtocol = listenProtocol
        self.targetHost = targetHost
        self.targetPort = targetPort
        self.targetProtocol = targetProtocol
        self.operationMode = operationMode
        self.includePrivateTags = includePrivateTags
        self.handleMissingFields = handleMissingFields
    }
}

// MARK: - Missing Field Behavior

/// How to handle missing mandatory fields during conversion.
public enum MissingFieldBehavior: String, Sendable, Equatable, Hashable, CaseIterable, Identifiable {
    case error      = "ERROR"
    case warn       = "WARN"
    case skip       = "SKIP"
    case useDefault = "USE_DEFAULT"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .error:      return "Error (abort)"
        case .warn:       return "Warn and continue"
        case .skip:       return "Skip missing fields"
        case .useDefault: return "Use default values"
        }
    }
}

// MARK: - Gateway Event

/// A single event logged by the gateway.
public struct GatewayEvent: Sendable, Identifiable, Hashable {
    public let id: UUID
    public var timestamp: Date
    public var level: GatewayEventLevel
    public var sourceProtocol: GatewayProtocol
    public var targetProtocol: GatewayProtocol
    public var message: String
    public var patientID: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: GatewayEventLevel = .info,
        sourceProtocol: GatewayProtocol,
        targetProtocol: GatewayProtocol,
        message: String,
        patientID: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.sourceProtocol = sourceProtocol
        self.targetProtocol = targetProtocol
        self.message = message
        self.patientID = patientID
    }
}

// MARK: - Gateway Event Level

/// Severity level of a gateway log event.
public enum GatewayEventLevel: String, Sendable, Equatable, Hashable, CaseIterable {
    case info    = "INFO"
    case warning = "WARNING"
    case error   = "ERROR"

    public var displayName: String {
        switch self {
        case .info:    return "Info"
        case .warning: return "Warning"
        case .error:   return "Error"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .info:    return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error:   return "xmark.circle.fill"
        }
    }
}

// MARK: - Routing Rule

/// A rule that determines how messages are forwarded.
public struct RoutingRule: Sendable, Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var matchField: String
    public var matchPattern: String
    public var targetHost: String
    public var targetPort: Int
    public var targetProtocol: GatewayProtocol
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        matchField: String = "PatientID",
        matchPattern: String = "*",
        targetHost: String = "localhost",
        targetPort: Int = 104,
        targetProtocol: GatewayProtocol = .dicom,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.matchField = matchField
        self.matchPattern = matchPattern
        self.targetHost = targetHost
        self.targetPort = targetPort
        self.targetProtocol = targetProtocol
        self.isEnabled = isEnabled
    }
}
