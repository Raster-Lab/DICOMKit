// NetworkUtilityModel.swift
// DICOMStudio
//
// DICOM Studio — Data models for the Network Utility feature.
//
// This feature is deliberately *outside* the DICOM box: a set of general
// network-diagnostic tools (ping, port scan, traceroute, DNS, interfaces,
// netstat) bundled into the app for quick connectivity troubleshooting when
// setting up DICOM associations. The models are plain value types so they
// stay `Sendable` and can cross the actor boundary out of the off-main
// `NetworkUtilityService`.

import Foundation

// MARK: - Sub-tool tabs

/// The six diagnostic tools offered by the Network Utility, surfaced as a
/// horizontal tab picker.
public enum NetworkUtilityTool: String, CaseIterable, Identifiable, Sendable {
    case interfaces  = "INTERFACES"
    case ping        = "PING"
    case portScan    = "PORT_SCAN"
    case traceroute  = "TRACEROUTE"
    case dnsLookup   = "DNS_LOOKUP"
    case netstat     = "NETSTAT"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ping:        return "Ping"
        case .portScan:    return "Port Scanner"
        case .traceroute:  return "Traceroute"
        case .dnsLookup:   return "DNS Lookup"
        case .interfaces:  return "Interfaces"
        case .netstat:     return "Netstat"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .ping:        return "dot.radiowaves.left.and.right"
        case .portScan:    return "lock.open.rotation"
        case .traceroute:  return "point.topleft.down.curvedto.point.bottomright.up"
        case .dnsLookup:   return "magnifyingglass"
        case .interfaces:  return "network"
        case .netstat:     return "list.bullet.rectangle"
        }
    }
}

// MARK: - Shared

/// IP address family selector. `.auto` lets the tool pick (IPv4 first).
public enum IPFamily: String, Sendable, Hashable, CaseIterable, Identifiable {
    case ipv4 = "IPv4", ipv6 = "IPv6", auto = "Auto"
    public var id: String { rawValue }
}

/// Outcome status carried on every result so that "unreachable / NXDOMAIN /
/// all-closed" are treated as *normal data* rather than thrown errors. Only
/// `HostInputError` and a missing binary surface as an alert; everything else
/// renders inline with a human-readable explanation.
public enum NetRunStatus: String, Sendable, Hashable {
    case success
    case unreachable
    case resolutionFailed
    case timedOut
    case binaryMissing
    case cancelled
    case failed

    /// A short human-readable phrase for the non-success states.
    public var message: String {
        switch self {
        case .success:          return "Success"
        case .unreachable:      return "Host unreachable — no replies received."
        case .resolutionFailed: return "Could not resolve host name."
        case .timedOut:         return "Timed out and was stopped."
        case .binaryMissing:    return "Required system tool is not available."
        case .cancelled:        return "Cancelled."
        case .failed:           return "The operation failed."
        }
    }
}

/// Validation failures for user-supplied host / port input. These are the only
/// network-utility errors shown in an alert (vs. rendered inline as data).
public enum HostInputError: Error, Sendable, Equatable {
    case empty
    case leadingDash         // would be read as a CLI flag by ping/traceroute/dig
    case illegalCharacters   // whitespace / shell metacharacters
    case badPortSpec
    case tooManyPorts(Int)

    public var message: String {
        switch self {
        case .empty:               return "Enter a host name or IP address."
        case .leadingDash:         return "Host must not start with “-”."
        case .illegalCharacters:   return "Host contains illegal characters."
        case .badPortSpec:         return "Invalid port list. Use e.g. 22,80,443,8000-8100."
        case .tooManyPorts(let n): return "Too many ports (\(n)). Limit is 2048 per scan."
        }
    }
}

// MARK: - 1. Ping

public struct PingReply: Sendable, Identifiable, Hashable {
    public let id = UUID()
    public var sequence: Int
    public var ttl: Int?
    public var rttMs: Double?   // nil => this probe timed out
    public init(sequence: Int, ttl: Int? = nil, rttMs: Double? = nil) {
        self.sequence = sequence; self.ttl = ttl; self.rttMs = rttMs
    }
}

public struct PingResult: Sendable, Identifiable, Hashable {
    public let id = UUID()
    public var host: String
    public var family: IPFamily
    public var packetsTransmitted: Int
    public var packetsReceived: Int
    public var packetLossPercent: Double
    public var rttMinMs: Double?
    public var rttAvgMs: Double?
    public var rttMaxMs: Double?
    public var rttStddevMs: Double?
    public var replies: [PingReply]
    public var status: NetRunStatus
    public var rawOutput: String
    public init(host: String, family: IPFamily = .ipv4, packetsTransmitted: Int = 0,
                packetsReceived: Int = 0, packetLossPercent: Double = 0,
                rttMinMs: Double? = nil, rttAvgMs: Double? = nil, rttMaxMs: Double? = nil,
                rttStddevMs: Double? = nil, replies: [PingReply] = [],
                status: NetRunStatus = .success, rawOutput: String = "") {
        self.host = host; self.family = family
        self.packetsTransmitted = packetsTransmitted; self.packetsReceived = packetsReceived
        self.packetLossPercent = packetLossPercent
        self.rttMinMs = rttMinMs; self.rttAvgMs = rttAvgMs; self.rttMaxMs = rttMaxMs
        self.rttStddevMs = rttStddevMs; self.replies = replies
        self.status = status; self.rawOutput = rawOutput
    }
}

// MARK: - 2. Port Scanner

public enum PortStatus: String, Sendable, Hashable {
    case open = "Open", closed = "Closed", filtered = "Filtered"
    public var sfSymbol: String {
        switch self {
        case .open:     return "checkmark.circle.fill"
        case .closed:   return "xmark.circle"
        case .filtered: return "questionmark.circle"
        }
    }
}

public struct PortResult: Sendable, Identifiable, Hashable {
    public let id = UUID()
    public var port: Int
    public var status: PortStatus
    public var serviceName: String?
    public var latencyMs: Double?
    public init(port: Int, status: PortStatus, serviceName: String? = nil, latencyMs: Double? = nil) {
        self.port = port; self.status = status; self.serviceName = serviceName; self.latencyMs = latencyMs
    }
}

// MARK: - 3. Traceroute

public struct TracerouteHop: Sendable, Identifiable, Hashable {
    public let id = UUID()
    public var hop: Int
    public var address: String?    // nil when every probe for this hop timed out
    public var rttsMs: [Double]
    public var timedOut: Bool
    public var annotation: String? // !H / !N / !P unreachable markers
    public init(hop: Int, address: String? = nil, rttsMs: [Double] = [],
                timedOut: Bool = false, annotation: String? = nil) {
        self.hop = hop; self.address = address; self.rttsMs = rttsMs
        self.timedOut = timedOut; self.annotation = annotation
    }
}

public struct TracerouteResult: Sendable, Identifiable, Hashable {
    public let id = UUID()
    public var host: String
    public var family: IPFamily
    public var hops: [TracerouteHop]
    public var reachedDestination: Bool
    public var status: NetRunStatus
    public var rawOutput: String
    public init(host: String, family: IPFamily = .ipv4, hops: [TracerouteHop] = [],
                reachedDestination: Bool = false, status: NetRunStatus = .success, rawOutput: String = "") {
        self.host = host; self.family = family; self.hops = hops
        self.reachedDestination = reachedDestination; self.status = status; self.rawOutput = rawOutput
    }
}

// MARK: - 4. DNS Lookup

public enum DNSRecordType: String, CaseIterable, Identifiable, Sendable {
    case a = "A", aaaa = "AAAA", mx = "MX", txt = "TXT", ns = "NS", cname = "CNAME", soa = "SOA"
    public var id: String { rawValue }
    public var displayName: String { rawValue }
}

public struct DNSRecord: Sendable, Identifiable, Hashable {
    public let id = UUID()
    public var name: String
    public var ttlSeconds: Int?
    public var recordClass: String   // typically "IN"
    public var type: DNSRecordType
    public var value: String
    public init(name: String, ttlSeconds: Int? = nil, recordClass: String = "IN",
                type: DNSRecordType, value: String) {
        self.name = name; self.ttlSeconds = ttlSeconds; self.recordClass = recordClass
        self.type = type; self.value = value
    }
}

public struct DNSResult: Sendable, Identifiable, Hashable {
    public let id = UUID()
    public var query: String
    public var records: [DNSRecord]   // all requested types; grouped in the View
    public var status: NetRunStatus
    public var rawOutput: String
    public init(query: String, records: [DNSRecord] = [],
                status: NetRunStatus = .success, rawOutput: String = "") {
        self.query = query; self.records = records; self.status = status; self.rawOutput = rawOutput
    }
}

// MARK: - 5. Interfaces

public struct InterfaceAddress: Sendable, Identifiable, Hashable {
    public let id = UUID()
    public var family: IPFamily   // .ipv4 / .ipv6
    public var address: String    // keeps %scope for link-local IPv6
    public var netmask: String?
    public var prefixLength: Int?
    public init(family: IPFamily, address: String, netmask: String? = nil, prefixLength: Int? = nil) {
        self.family = family; self.address = address; self.netmask = netmask; self.prefixLength = prefixLength
    }
}

/// Cumulative per-interface I/O counters, read from the kernel routing table
/// (`NET_RT_IFLIST2`) as 64-bit values so busy interfaces don't wrap.
public struct InterfaceStatistics: Sendable, Hashable {
    public var packetsIn: UInt64
    public var packetsOut: UInt64
    public var bytesIn: UInt64
    public var bytesOut: UInt64
    public var errorsIn: UInt64
    public var errorsOut: UInt64
    public init(packetsIn: UInt64 = 0, packetsOut: UInt64 = 0,
                bytesIn: UInt64 = 0, bytesOut: UInt64 = 0,
                errorsIn: UInt64 = 0, errorsOut: UInt64 = 0) {
        self.packetsIn = packetsIn; self.packetsOut = packetsOut
        self.bytesIn = bytesIn; self.bytesOut = bytesOut
        self.errorsIn = errorsIn; self.errorsOut = errorsOut
    }
}

public struct NetworkInterface: Sendable, Identifiable, Hashable {
    public let id = UUID()
    public var name: String       // en0, lo0, utun3, …
    public var displayName: String?   // friendly name, e.g. "Wi-Fi" (en0)
    public var isUp: Bool
    public var isRunning: Bool
    public var isLoopback: Bool
    public var supportsMulticast: Bool
    public var macAddress: String?
    public var addresses: [InterfaceAddress]
    public var statistics: InterfaceStatistics?
    public init(name: String, displayName: String? = nil, isUp: Bool, isRunning: Bool,
                isLoopback: Bool, supportsMulticast: Bool = false, macAddress: String? = nil,
                addresses: [InterfaceAddress] = [], statistics: InterfaceStatistics? = nil) {
        self.name = name; self.displayName = displayName
        self.isUp = isUp; self.isRunning = isRunning
        self.isLoopback = isLoopback; self.supportsMulticast = supportsMulticast
        self.macAddress = macAddress; self.addresses = addresses
        self.statistics = statistics
    }

    /// First IPv4 / IPv6 address, for the summary fields in the UI.
    public var ipv4Address: String? { addresses.first { $0.family == .ipv4 }?.address }
    public var ipv6Address: String? { addresses.first { $0.family == .ipv6 }?.address }

    /// "Active" when the link is up and running.
    public var isActive: Bool { isUp && isRunning }

    /// Label for the interface picker, e.g. "Wi-Fi (en0)" or just "en0".
    public var menuTitle: String {
        if let d = displayName, !d.isEmpty { return "\(d) (\(name))" }
        return name
    }
}

// MARK: - 6. Netstat

public enum NetstatMode: String, CaseIterable, Identifiable, Sendable {
    case connections = "CONNECTIONS", routing = "ROUTING"
    public var id: String { rawValue }
    public var displayName: String { self == .connections ? "Connections" : "Routing Table" }
}

public struct NetstatEntry: Sendable, Identifiable, Hashable {
    public let id = UUID()
    public var proto: String         // tcp4 / tcp6 / udp4 / udp6
    public var recvQ: Int
    public var sendQ: Int
    public var localAddress: String
    public var localPort: String     // numeric or "*"
    public var foreignAddress: String
    public var foreignPort: String   // numeric or "*"
    public var state: String         // LISTEN / ESTABLISHED / … ("" for UDP)
    public init(proto: String, recvQ: Int = 0, sendQ: Int = 0,
                localAddress: String, localPort: String,
                foreignAddress: String, foreignPort: String, state: String = "") {
        self.proto = proto; self.recvQ = recvQ; self.sendQ = sendQ
        self.localAddress = localAddress; self.localPort = localPort
        self.foreignAddress = foreignAddress; self.foreignPort = foreignPort; self.state = state
    }
}

public struct RouteEntry: Sendable, Identifiable, Hashable {
    public let id = UUID()
    public var destination: String
    public var gateway: String
    public var flags: String
    public var netif: String
    public var expire: String
    public init(destination: String, gateway: String, flags: String, netif: String, expire: String = "") {
        self.destination = destination; self.gateway = gateway
        self.flags = flags; self.netif = netif; self.expire = expire
    }
}

public struct NetstatResult: Sendable, Hashable {
    public var connections: [NetstatEntry]
    public var listeners: [NetstatEntry]
    public var routes: [RouteEntry]
    public var status: NetRunStatus
    public var rawOutput: String
    public init(connections: [NetstatEntry] = [], listeners: [NetstatEntry] = [],
                routes: [RouteEntry] = [], status: NetRunStatus = .success, rawOutput: String = "") {
        self.connections = connections; self.listeners = listeners
        self.routes = routes; self.status = status; self.rawOutput = rawOutput
    }
}
