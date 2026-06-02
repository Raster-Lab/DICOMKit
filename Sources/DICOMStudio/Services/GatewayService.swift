// GatewayService.swift
// DICOMStudio
//
// DICOM Studio — Service for DICOM Gateway state management

import Foundation

/// Thread-safe service managing DICOM Gateway state.
public final class GatewayService: @unchecked Sendable {
    private let lock = NSLock()
    private var _configuration: GatewayConfiguration
    private var _routingRules: [RoutingRule] = []
    private var _events: [GatewayEvent] = []
    private var _isRunning: Bool = false

    public init(configuration: GatewayConfiguration = GatewayConfiguration()) {
        self._configuration = configuration
    }

    // MARK: - Configuration

    public var configuration: GatewayConfiguration {
        get { lock.withLock { _configuration } }
        set { lock.withLock { _configuration = newValue } }
    }

    // MARK: - Running State

    public var isRunning: Bool {
        lock.withLock { _isRunning }
    }

    public func setRunning(_ running: Bool) {
        lock.withLock { _isRunning = running }
    }

    // MARK: - Routing Rules

    public var routingRules: [RoutingRule] {
        lock.withLock { _routingRules }
    }

    public func addRoutingRule(_ rule: RoutingRule) {
        lock.withLock { _routingRules.append(rule) }
    }

    public func updateRoutingRule(_ updated: RoutingRule) {
        lock.withLock {
            if let idx = _routingRules.firstIndex(where: { $0.id == updated.id }) {
                _routingRules[idx] = updated
            }
        }
    }

    public func removeRoutingRule(id: UUID) {
        lock.withLock { _routingRules.removeAll { $0.id == id } }
    }

    // MARK: - Event Log

    public var events: [GatewayEvent] {
        lock.withLock { _events }
    }

    public func appendEvent(_ event: GatewayEvent) {
        lock.withLock {
            _events.append(event)
            // Keep at most 500 events to avoid unbounded growth.
            if _events.count > 500 { _events.removeFirst(_events.count - 500) }
        }
    }

    public func clearEvents() {
        lock.withLock { _events.removeAll() }
    }
}
