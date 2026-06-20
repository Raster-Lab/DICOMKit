// NetworkUtilityService+Parsing.swift
// DICOMStudio
//
// DICOM Studio — Output parsers + native interface enumeration for the
// Network Utility. Split out of NetworkUtilityService for readability; all
// methods are pure (no I/O) except `enumerateInterfaces`, which is a single
// instantaneous local syscall walk.

#if os(macOS)

import Foundation
import Darwin
import SystemConfiguration

extension NetworkUtilityService {

    // MARK: - Regex helper

    /// Returns the capture groups (index 0 = whole match) of the first match,
    /// or nil. Missing optional groups come back as "".
    static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = re.firstMatch(in: text, options: [], range: range) else { return nil }
        var groups: [String] = []
        for i in 0..<m.numberOfRanges {
            if let r = Range(m.range(at: i), in: text) { groups.append(String(text[r])) }
            else { groups.append("") }
        }
        return groups
    }

    private static func indicatesResolutionFailure(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("cannot resolve")
            || lower.contains("unknown host")
            || lower.contains("name or service not known")
            || lower.contains("no address associated")
            || lower.contains("nodename nor servname")
    }

    // MARK: - 1. Ping

    static func parsePing(_ out: ProcOutcome, host: String, family: IPFamily) -> PingResult {
        let raw = out.stdout + (out.stderr.isEmpty ? "" : "\n" + out.stderr)
        if out.status == .binaryMissing {
            return PingResult(host: host, family: family, status: .binaryMissing, rawOutput: raw)
        }

        var replies: [PingReply] = []
        for line in out.stdout.split(separator: "\n", omittingEmptySubsequences: true) {
            // icmp_seq / ttl|hlim / time — covers both ping (ttl) and ping6 (hlim).
            if let g = firstMatch(#"icmp_seq=(\d+)\s+(?:ttl|hlim)=(\d+)\s+time=([0-9.]+)\s*ms"#, in: String(line)),
               let seq = Int(g[1]) {
                replies.append(PingReply(sequence: seq, ttl: Int(g[2]), rttMs: Double(g[3])))
            }
        }

        var transmitted = 0, received = 0, loss = 0.0
        if let g = firstMatch(#"(\d+)\s+packets transmitted,\s+(\d+)\s+packets received,\s+([0-9.]+)%\s+packet loss"#, in: out.stdout) {
            transmitted = Int(g[1]) ?? 0
            received = Int(g[2]) ?? 0
            loss = Double(g[3]) ?? 0
        } else {
            received = replies.count
            loss = transmitted == 0 ? (received == 0 ? 100 : 0) : 0
        }

        // Tolerant of "stddev" (IPv4) vs "std-dev" (IPv6) and "nan" values.
        var rttMin: Double?, rttAvg: Double?, rttMax: Double?, rttStd: Double?
        if let g = firstMatch(#"min/avg/max/std-?dev\s*=\s*([0-9.]+)/([0-9.]+)/([0-9.]+)/([0-9.a-z]+)\s*ms"#, in: out.stdout) {
            // A single reply yields a "nan" stddev; Double("nan") is a real NaN,
            // not nil, so drop non-finite values explicitly (keeps NaN out of the
            // Hashable model and stops the View printing "nan").
            let finite: (String) -> Double? = { Double($0).flatMap { $0.isFinite ? $0 : nil } }
            rttMin = finite(g[1]); rttAvg = finite(g[2]); rttMax = finite(g[3]); rttStd = finite(g[4])
        }

        let status: NetRunStatus
        switch out.status {
        case .cancelled:           status = .cancelled
        case .timedOut:            status = received > 0 ? .success : .timedOut
        case .binaryMissing:       status = .binaryMissing
        default:
            if indicatesResolutionFailure(raw)      { status = .resolutionFailed }
            else if received == 0                   { status = .unreachable }
            else                                    { status = .success }
        }

        return PingResult(host: host, family: family,
                          packetsTransmitted: transmitted, packetsReceived: received,
                          packetLossPercent: loss,
                          rttMinMs: rttMin, rttAvgMs: rttAvg, rttMaxMs: rttMax, rttStddevMs: rttStd,
                          replies: replies, status: status, rawOutput: raw)
    }

    // MARK: - 3. Traceroute

    static func parseTraceroute(_ out: ProcOutcome, host: String, family: IPFamily) -> TracerouteResult {
        let raw = out.stdout + (out.stderr.isEmpty ? "" : "\n" + out.stderr)
        if out.status == .binaryMissing {
            return TracerouteResult(host: host, family: family, status: .binaryMissing, rawOutput: raw)
        }

        // Destination IP from the header: "traceroute to host (1.2.3.4), ..."
        var destIP: String?
        if let g = firstMatch(#"traceroute6?\s+to\s+\S+\s+\(([^)]+)\)"#, in: out.stdout) {
            destIP = g[1]
        }

        var hops: [TracerouteHop] = []
        for rawLine in out.stdout.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            guard let g = firstMatch(#"^\s*(\d+)\s+(.*)$"#, in: line), let hopNum = Int(g[1]) else { continue }
            let tokens = g[2].split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            var address: String?
            var rtts: [Double] = []
            var timedOutProbes = 0
            var annotation: String?
            for tok in tokens {
                if tok == "ms" { continue }
                if tok == "*" { timedOutProbes += 1; continue }
                if tok.hasPrefix("!") { annotation = tok; continue }
                if let v = Double(tok) { rtts.append(v); continue }   // "192.168.1.1" is not a Double
                if address == nil, tok.contains(":") || tok.contains(".") { address = tok }
            }
            let allTimedOut = address == nil && rtts.isEmpty && timedOutProbes > 0
            hops.append(TracerouteHop(hop: hopNum, address: address, rttsMs: rtts,
                                      timedOut: allTimedOut, annotation: annotation))
        }

        let reached = destIP != nil && hops.contains { $0.address == destIP }
        let status: NetRunStatus
        switch out.status {
        case .cancelled:     status = .cancelled
        case .timedOut:      status = hops.isEmpty ? .timedOut : .success
        case .binaryMissing: status = .binaryMissing
        default:
            if indicatesResolutionFailure(raw)  { status = .resolutionFailed }
            else if hops.isEmpty                { status = .failed }
            else                                { status = .success }
        }

        return TracerouteResult(host: host, family: family, hops: hops,
                                reachedDestination: reached, status: status, rawOutput: raw)
    }

    // MARK: - 4. DNS (dig +noall +answer)

    static func parseDig(_ stdout: String, type requested: DNSRecordType) -> [DNSRecord] {
        var records: [DNSRecord] = []
        for rawLine in stdout.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix(";") { continue }
            let cols = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard cols.count >= 5 else { continue }
            let name = cols[0]
            let ttl = Int(cols[1])
            let recClass = cols[2]
            let typeToken = cols[3].uppercased()
            let recType = DNSRecordType(rawValue: typeToken) ?? requested
            var value = cols[4...].joined(separator: " ")
            if recType == .txt {
                // RFC 1035: a TXT record is one or more quoted character-strings;
                // concatenate them all (handles long multi-segment SPF/DKIM rows),
                // falling back to the raw value when no quotes are present.
                if let re = try? NSRegularExpression(pattern: "\"([^\"]*)\"") {
                    let ns = value as NSString
                    let matches = re.matches(in: value, range: NSRange(location: 0, length: ns.length))
                    if !matches.isEmpty {
                        value = matches.map { ns.substring(with: $0.range(at: 1)) }.joined()
                    }
                }
            }
            records.append(DNSRecord(name: name, ttlSeconds: ttl, recordClass: recClass,
                                     type: recType, value: value))
        }
        return records
    }

    // MARK: - 6. Netstat

    /// Splits an address+port string at the LAST ".". IPv6 keeps its ":" and
    /// "%scope". "*.*" -> ("*","*").
    private static func splitAddrPort(_ s: String) -> (addr: String, port: String) {
        guard let dot = s.lastIndex(of: ".") else { return (s, "") }
        let addr = String(s[s.startIndex..<dot])
        let port = String(s[s.index(after: dot)...])
        return (addr.isEmpty ? "*" : addr, port)
    }

    static func parseConnections(_ stdout: String) -> NetstatResult {
        var connections: [NetstatEntry] = []
        var listeners: [NetstatEntry] = []
        let maxRows = 2000
        for rawLine in stdout.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            let cols = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard let proto = cols.first,
                  proto.hasPrefix("tcp") || proto.hasPrefix("udp"),
                  cols.count >= 5 else { continue }
            let (localAddr, localPort) = splitAddrPort(cols[3])
            let (foreignAddr, foreignPort) = splitAddrPort(cols[4])
            let state = cols.count >= 6 ? cols[5] : ""
            let entry = NetstatEntry(proto: proto,
                                     recvQ: Int(cols[1]) ?? 0, sendQ: Int(cols[2]) ?? 0,
                                     localAddress: localAddr, localPort: localPort,
                                     foreignAddress: foreignAddr, foreignPort: foreignPort,
                                     state: state)
            let isListener = state == "LISTEN" || (state.isEmpty && foreignPort == "*")
            if isListener {
                if listeners.count < maxRows { listeners.append(entry) }
            } else {
                if connections.count < maxRows { connections.append(entry) }
            }
        }
        return NetstatResult(connections: connections, listeners: listeners)
    }

    static func parseRoutes(_ stdout: String) -> NetstatResult {
        var routes: [RouteEntry] = []
        let maxRows = 2000
        for rawLine in stdout.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            let cols = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard cols.count >= 4 else { continue }
            // Skip section headers and the column header row.
            let head = cols[0]
            if head == "Routing" || head == "Internet:" || head == "Internet6:" || head == "Destination" { continue }
            let route = RouteEntry(destination: cols[0], gateway: cols[1], flags: cols[2],
                                   netif: cols[3], expire: cols.count >= 5 ? cols[4] : "")
            if routes.count < maxRows { routes.append(route) }
        }
        return NetstatResult(routes: routes)
    }

    // MARK: - 5. Interfaces (native getifaddrs)

    static func enumerateInterfaces() -> [NetworkInterface] {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else { return [] }
        defer { freeifaddrs(ifap) }

        let friendly = friendlyInterfaceNames()        // BSD name -> "Wi-Fi"
        let statsByIndex = interfaceStatistics()        // if-index -> counters

        var byName: [String: NetworkInterface] = [:]
        var order: [String] = []

        var node: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = node {
            defer { node = cur.pointee.ifa_next }
            let ifa = cur.pointee
            let name = String(cString: ifa.ifa_name)
            let flags = ifa.ifa_flags

            if byName[name] == nil {
                let index = Int(if_nametoindex(ifa.ifa_name))
                byName[name] = NetworkInterface(
                    name: name,
                    displayName: friendly[name],
                    isUp: (flags & UInt32(IFF_UP)) != 0,
                    isRunning: (flags & UInt32(IFF_RUNNING)) != 0,
                    isLoopback: (flags & UInt32(IFF_LOOPBACK)) != 0,
                    supportsMulticast: (flags & UInt32(IFF_MULTICAST)) != 0,
                    macAddress: nil, addresses: [],
                    statistics: statsByIndex[index])
                order.append(name)
            }

            guard let sa = ifa.ifa_addr else { continue }
            let family = sa.pointee.sa_family

            if family == sa_family_t(AF_INET) || family == sa_family_t(AF_INET6) {
                let salen = socklen_t(sa.pointee.sa_len)
                var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                guard getnameinfo(sa, salen, &hostBuf, socklen_t(hostBuf.count), nil, 0, NI_NUMERICHOST) == 0
                else { continue }
                let address = cString(hostBuf)

                var maskStr: String?
                var prefix: Int?
                if let nm = ifa.ifa_netmask {
                    let nmLen = socklen_t(nm.pointee.sa_len)
                    var maskBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(nm, nmLen, &maskBuf, socklen_t(maskBuf.count), nil, 0, NI_NUMERICHOST) == 0 {
                        maskStr = cString(maskBuf)
                        if family == sa_family_t(AF_INET) { prefix = prefixLengthIPv4(maskStr!) }
                    }
                }
                let fam: IPFamily = family == sa_family_t(AF_INET6) ? .ipv6 : .ipv4
                byName[name]?.addresses.append(
                    InterfaceAddress(family: fam, address: address, netmask: maskStr, prefixLength: prefix))
            } else if family == sa_family_t(AF_LINK) {
                if let mac = macAddress(from: sa), byName[name]?.macAddress == nil {
                    byName[name]?.macAddress = mac
                }
            }
        }

        return order.compactMap { byName[$0] }
    }

    /// Maps each BSD interface name (en0, en1, …) to its localized display
    /// name ("Wi-Fi", "Thunderbolt Ethernet", …) via SystemConfiguration.
    /// Interfaces SC doesn't know about (lo0, utun*) simply stay unmapped.
    private static func friendlyInterfaceNames() -> [String: String] {
        var map: [String: String] = [:]
        guard let list = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return map }
        for intf in list {
            guard let bsd = SCNetworkInterfaceGetBSDName(intf) as String? else { continue }
            if let disp = SCNetworkInterfaceGetLocalizedDisplayName(intf) as String? {
                map[bsd] = disp
            }
        }
        return map
    }

    /// Reads 64-bit cumulative I/O counters for every interface from the kernel
    /// routing table (`NET_RT_IFLIST2`), keyed by interface index. getifaddrs'
    /// own `if_data` only carries 32-bit counters, which wrap on busy links —
    /// so this uses `if_msghdr2` / `if_data64` for accurate byte totals.
    private static func interfaceStatistics() -> [Int: InterfaceStatistics] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0) == 0, len > 0 else { return [:] }
        var buf = [UInt8](repeating: 0, count: len)
        guard sysctl(&mib, UInt32(mib.count), &buf, &len, nil, 0) == 0 else { return [:] }

        var result: [Int: InterfaceStatistics] = [:]
        buf.withUnsafeBytes { raw in
            let hdrSize = MemoryLayout<if_msghdr>.size
            var offset = 0
            while offset + hdrSize <= len {
                let hdr = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                let msglen = Int(hdr.ifm_msglen)
                if msglen <= 0 { break }
                if Int32(hdr.ifm_type) == RTM_IFINFO2,
                   offset + MemoryLayout<if_msghdr2>.size <= len {
                    let m2 = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    let d = m2.ifm_data
                    result[Int(m2.ifm_index)] = InterfaceStatistics(
                        packetsIn: UInt64(d.ifi_ipackets),
                        packetsOut: UInt64(d.ifi_opackets),
                        bytesIn: UInt64(d.ifi_ibytes),
                        bytesOut: UInt64(d.ifi_obytes),
                        errorsIn: UInt64(d.ifi_ierrors),
                        errorsOut: UInt64(d.ifi_oerrors))
                }
                offset += msglen
            }
        }
        return result
    }

    /// Counts set bits in a dotted-quad netmask -> CIDR prefix length.
    private static func prefixLengthIPv4(_ mask: String) -> Int? {
        let octets = mask.split(separator: ".").compactMap { UInt8($0) }
        guard octets.count == 4 else { return nil }
        return octets.reduce(0) { $0 + $1.nonzeroBitCount }
    }

    /// Extracts a colon-separated MAC from an `AF_LINK` sockaddr. The link-layer
    /// address lives at `sdl_data + sdl_nlen` inside the *variable-length*
    /// sockaddr the kernel allocated (`sa_len` bytes), so it is read from the
    /// original pointer rather than a fixed 12-byte value copy — otherwise
    /// interfaces with names ≥ 7 chars (e.g. `bridge0`) would lose their MAC.
    private static func macAddress(from sa: UnsafeMutablePointer<sockaddr>) -> String? {
        let (nlen, alen) = sa.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) {
            (Int($0.pointee.sdl_nlen), Int($0.pointee.sdl_alen))
        }
        guard alen == 6 else { return nil }
        let saLen = Int(sa.pointee.sa_len)
        let dataOffset = MemoryLayout<sockaddr_dl>.offset(of: \.sdl_data) ?? 8
        guard dataOffset + nlen + alen <= saLen else { return nil }
        let base = UnsafeRawPointer(sa)
        let bytes = (0..<alen).map { base.load(fromByteOffset: dataOffset + nlen + $0, as: UInt8.self) }
        guard bytes.contains(where: { $0 != 0 }) else { return nil }
        return bytes.map { String(format: "%02x", $0) }.joined(separator: ":")
    }
}

#endif
