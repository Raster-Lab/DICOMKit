// NetworkUtilityViewModel.swift
// DICOMStudio
//
// DICOM Studio — ViewModel for the Network Utility feature (general,
// non-DICOM network diagnostics). Owns the input + result state for all six
// tools and a single cancellable task. All blocking work lives in
// `NetworkUtilityService`; this layer only marshals input and results.

import Foundation
import Observation

@available(macOS 14.0, iOS 17.0, visionOS 1.0, *)
@Observable
@MainActor
public final class NetworkUtilityViewModel {

    #if os(macOS)
    private let service = NetworkUtilityService()
    #endif

    /// The currently selected tool. Switching tools cancels any in-flight run.
    /// Defaults to Interfaces — the first tab and the most useful landing view.
    public var activeTool: NetworkUtilityTool = .interfaces {
        didSet { if oldValue != activeTool { cancel() } }
    }

    /// True while a run is in progress (drives the spinner + Cancel button).
    public var isRunning: Bool = false

    /// Set only for input-validation failures and missing system tools — the
    /// two cases the View surfaces as an alert. All other failures render
    /// inline as result data.
    public var errorMessage: String?

    private var runningTask: Task<Void, Never>?

    /// Bumped on every ping/traceroute/DNS/netstat run and on cancel, so streamed
    /// chunks from a superseded or cancelled run are dropped instead of leaking
    /// into the next run's live output. The subprocess analogue of
    /// `portScanGeneration` — the shared `isRunning` flag is not a safe identity
    /// because a quick cancel-then-rerun re-raises it for a *different* run.
    private var streamGeneration: Int = 0

    /// Target host / IP shared by Ping, Port Scanner and Traceroute — entering
    /// it in any one of the three tabs carries it to the others.
    public var sharedHost: String = ""

    // MARK: Ping state
    public var pingCount: Int = 5
    public var pingFamily: IPFamily = .auto
    public var pingResult: PingResult?

    // MARK: Port scan state
    public var portSpec: String = "22,80,443,104,11112,8042,8080"
    public var portTimeout: Double = 1.5
    public var portResults: [PortResult] = []
    /// Bumped on each scan; streamed results from a superseded scan are dropped.
    private var portScanGeneration: Int = 0

    // MARK: Traceroute state
    public var traceMaxHops: Int = 20
    public var traceFamily: IPFamily = .auto
    public var traceResult: TracerouteResult?

    // MARK: DNS state
    public var dnsHost: String = ""
    public var dnsTypes: Set<DNSRecordType> = [.a, .aaaa]
    public var dnsResult: DNSResult?

    // MARK: Interfaces state
    public var interfaces: [NetworkInterface] = []
    /// Tracked by name (not UUID) so the selection survives a refresh, which
    /// rebuilds every `NetworkInterface` with a fresh id.
    public var selectedInterfaceName: String?

    /// The interface currently shown in the detail panel: the explicit
    /// selection if still present, otherwise the first interface.
    public var selectedInterface: NetworkInterface? {
        if let n = selectedInterfaceName, let m = interfaces.first(where: { $0.name == n }) { return m }
        return interfaces.first
    }

    // MARK: Netstat state
    public var netstatMode: NetstatMode = .connections
    public var netstatResult: NetstatResult?

    public init() {}

    // MARK: - Lifecycle

    /// Cancels the in-flight run (if any) and clears the running flag. Called
    /// on tool switch, on a fresh run, and on view disappearance.
    public func cancel() {
        runningTask?.cancel()
        runningTask = nil
        streamGeneration &+= 1   // invalidate any in-flight streamed chunks
        isRunning = false
    }

    /// Validates a host, surfacing a `HostInputError` as an alert. Returns nil
    /// (and sets `errorMessage`) when invalid or off-platform.
    private func validatedHost(_ raw: String) -> String? {
        #if os(macOS)
        do { return try service.validateHost(raw) }
        catch { errorMessage = (error as? HostInputError)?.message ?? "Invalid host."; return nil }
        #else
        errorMessage = "Network Utility requires macOS."
        return nil
        #endif
    }

    // MARK: - 1. Ping

    public func runPing() {
        guard !isRunning, let host = validatedHost(sharedHost) else { return }
        #if os(macOS)
        let count = pingCount, family = pingFamily
        let resolvedFamily: IPFamily = (family == .ipv6 || (family == .auto && host.contains(":"))) ? .ipv6 : .ipv4
        // Seed an empty result so the terminal panel can fill live as output
        // streams in; the parsed summary replaces it when the run completes.
        pingResult = PingResult(host: host, family: resolvedFamily, status: .success, rawOutput: "")
        streamGeneration &+= 1; let gen = streamGeneration
        isRunning = true
        runningTask = Task {
            let result = await service.ping(host: host, count: count, family: family) { chunk in
                await MainActor.run {
                    guard self.streamGeneration == gen else { return }
                    self.pingResult?.rawOutput += chunk
                }
            }
            guard !Task.isCancelled, self.streamGeneration == gen else { return }
            self.pingResult = result
            self.isRunning = false
        }
        #endif
    }

    // MARK: - 2. Port Scanner

    public func runPortScan() {
        guard !isRunning, let host = validatedHost(sharedHost) else { return }
        #if os(macOS)
        let ports: [Int]
        do { ports = try service.parsePortSpec(portSpec) }
        catch { errorMessage = (error as? HostInputError)?.message ?? "Invalid port list."; return }

        portScanGeneration &+= 1
        let gen = portScanGeneration
        portResults = []
        isRunning = true
        let timeout = portTimeout
        runningTask = Task {
            await service.scanPorts(host: host, ports: ports, perPortTimeout: timeout) { result in
                // Drop appends from a scan that has been cancelled or superseded
                // by a newer run, so stale ports can't leak into the live list.
                await MainActor.run {
                    guard self.portScanGeneration == gen else { return }
                    self.portResults.append(result)
                }
            }
            guard !Task.isCancelled, self.portScanGeneration == gen else { return }
            self.portResults.sort { $0.port < $1.port }
            self.isRunning = false
        }
        #endif
    }

    // MARK: - 3. Traceroute

    public func runTraceroute() {
        guard !isRunning, let host = validatedHost(sharedHost) else { return }
        #if os(macOS)
        let maxHops = traceMaxHops, family = traceFamily
        let resolvedFamily: IPFamily = (family == .ipv6 || (family == .auto && host.contains(":"))) ? .ipv6 : .ipv4
        // Seed an empty result so hops fill the terminal panel live.
        traceResult = TracerouteResult(host: host, family: resolvedFamily, status: .success, rawOutput: "")
        streamGeneration &+= 1; let gen = streamGeneration
        isRunning = true
        runningTask = Task {
            let result = await service.traceroute(host: host, maxHops: maxHops, family: family) { chunk in
                await MainActor.run {
                    guard self.streamGeneration == gen else { return }
                    self.traceResult?.rawOutput += chunk
                }
            }
            guard !Task.isCancelled, self.streamGeneration == gen else { return }
            self.traceResult = result
            self.isRunning = false
        }
        #endif
    }

    // MARK: - 4. DNS Lookup

    public func runDNSLookup() {
        guard !isRunning, let host = validatedHost(dnsHost) else { return }
        #if os(macOS)
        let types = DNSRecordType.allCases.filter { dnsTypes.contains($0) }
        guard !types.isEmpty else { errorMessage = "Select at least one record type."; return }
        // Seed an empty result so each dig query streams into the panel live.
        dnsResult = DNSResult(query: host, status: .success, rawOutput: "")
        streamGeneration &+= 1; let gen = streamGeneration
        isRunning = true
        runningTask = Task {
            let result = await service.dnsLookup(host: host, types: types) { chunk in
                await MainActor.run {
                    guard self.streamGeneration == gen else { return }
                    self.dnsResult?.rawOutput += chunk
                }
            }
            guard !Task.isCancelled, self.streamGeneration == gen else { return }
            self.dnsResult = result
            self.isRunning = false
        }
        #endif
    }

    public func toggleDNSType(_ type: DNSRecordType) {
        if dnsTypes.contains(type) { dnsTypes.remove(type) } else { dnsTypes.insert(type) }
    }

    // MARK: - 5. Interfaces

    public func loadInterfaces() {
        guard !isRunning else { return }
        #if os(macOS)
        isRunning = true
        runningTask = Task {
            let result = await service.interfaces()
            guard !Task.isCancelled else { return }
            self.interfaces = result
            // Default the selection to the first active, non-loopback interface
            // with an IPv4 address (typically Wi-Fi / Ethernet), else the first.
            if self.selectedInterfaceName == nil
                || !result.contains(where: { $0.name == self.selectedInterfaceName }) {
                self.selectedInterfaceName =
                    result.first(where: { !$0.isLoopback && $0.ipv4Address != nil })?.name
                    ?? result.first?.name
            }
            self.isRunning = false
        }
        #endif
    }

    // MARK: - 6. Netstat

    public func runNetstat() {
        guard !isRunning else { return }
        #if os(macOS)
        // Seed an empty result so sockets / routes stream into the panel live.
        netstatResult = NetstatResult(status: .success, rawOutput: "")
        streamGeneration &+= 1; let gen = streamGeneration
        isRunning = true
        let mode = netstatMode
        runningTask = Task {
            let result = await service.netstat(mode: mode) { chunk in
                await MainActor.run {
                    guard self.streamGeneration == gen else { return }
                    self.netstatResult?.rawOutput += chunk
                }
            }
            guard !Task.isCancelled, self.streamGeneration == gen else { return }
            self.netstatResult = result
            self.isRunning = false
        }
        #endif
    }
}
