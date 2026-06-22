// NetworkUtilityService.swift
// DICOMStudio
//
// DICOM Studio — Engine for the Network Utility feature.
//
// All six diagnostic tools live here. The split of strategies follows the
// design panel for this feature:
//   • Ping / Traceroute / Netstat  → subprocess (real system binaries, the
//     only unprivileged path to ICMP RTT, raw-ICMP traceroute, and kernel
//     socket tables).
//   • Port Scanner                 → native NWConnection TCP-connect scan.
//   • DNS Lookup                   → `dig` primary, `getaddrinfo` fallback.
//   • Interfaces                   → native `getifaddrs`.
//
// Everything blocking runs OFF the main actor. C pointers (Process, Pipe,
// ifaddrs*, addrinfo*, NWConnection) never cross an `await`: each is reduced
// to a `Sendable` value-type result inside its own function before returning.

#if os(macOS)

import Foundation
import Network
import Darwin

// MARK: - Cancellation plumbing

/// Resume-exactly-once guard for a `CheckedContinuation`. Double-resume is a
/// hard crash, so every NWConnection state branch + the timeout backstop funnel
/// through `tryResume()`.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func tryResume() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}

/// Single-writer `Data` holder, written by exactly one pipe-drain closure and
/// read only after the `DispatchGroup` barrier. Lets the captured mutation
/// satisfy strict concurrency without a per-access lock.
private final class DataBox: @unchecked Sendable {
    var data = Data()
}

/// Lock-guarded boolean, set from a timeout watchdog and read once the child
/// has exited. Used by the streaming runner where there is no DispatchGroup
/// barrier to make a plain `var` capture race-free.
private final class FlagBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set() { lock.lock(); value = true; lock.unlock() }
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return value }
}

/// Thread-safe holder that lets a cancelling task `terminate()` a running child
/// process. The child registers itself; a later `cancel()` (or a `cancel()`
/// that already happened) tears it down.
private final class ProcessKillBox: @unchecked Sendable {
    private let lock = NSLock()
    private weak var proc: Process?
    private var cancelled = false

    /// Registers the live process. Returns `false` if cancellation already
    /// fired, in which case the caller must not start it.
    func register(_ p: Process) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if cancelled { return false }
        proc = p
        return true
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let p = proc
        lock.unlock()
        guard let p, p.isRunning else { return }
        p.terminate()
        // Escalate to SIGKILL if the child ignores SIGTERM, so a wedged process
        // can't keep a pipe open and hang the reader forever.
        let pid = p.processIdentifier
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3) {
            if p.isRunning { kill(pid, SIGKILL) }
        }
    }

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }
}

// MARK: - Service

/// Stateless engine for the Network Utility tools. Holds no mutable shared
/// state, so `@unchecked Sendable` is safe (matches `GatewayService`).
public final class NetworkUtilityService: @unchecked Sendable {

    public init() {}

    /// Decodes a NUL-terminated `[CChar]` C buffer to a String via its pointer
    /// (the array overload of `String(cString:)` is deprecated).
    static func cString(_ buf: [CChar]) -> String {
        buf.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return "" }
            return String(cString: base)
        }
    }

    // Pinned absolute paths — never resolved through `$PATH` (which the child
    // env also locks down) so a hijacked PATH cannot substitute a binary.
    private static let pingBin        = "/sbin/ping"
    private static let ping6Bin       = "/sbin/ping6"
    private static let tracerouteBin  = "/usr/sbin/traceroute"
    private static let traceroute6Bin = "/usr/sbin/traceroute6"
    private static let netstatBin     = "/usr/sbin/netstat"
    private static let digBin         = "/usr/bin/dig"

    /// Common TCP services, used to annotate open ports (incl. DICOM 104/11112).
    private static let serviceHints: [Int: String] = [
        20: "ftp-data", 21: "ftp", 22: "ssh", 23: "telnet", 25: "smtp",
        53: "dns", 80: "http", 104: "dicom", 110: "pop3", 143: "imap",
        389: "ldap", 443: "https", 445: "smb", 587: "smtp", 631: "ipp",
        993: "imaps", 995: "pop3s", 1433: "mssql", 2575: "hl7", 3306: "mysql",
        3389: "rdp", 5432: "postgres", 5900: "vnc", 6379: "redis",
        8042: "orthanc", 8080: "http-alt", 8443: "https-alt", 8888: "http-alt",
        11112: "dicom", 27017: "mongodb"
    ]

    // MARK: Input validation

    /// Validates and normalises a user-supplied host. Arguments are always
    /// passed as an array (never a shell string), so this guards against a
    /// host that would be *misread as a flag* and against stray whitespace /
    /// shell metacharacters rather than against shell injection per se.
    public func validateHost(_ raw: String) throws -> String {
        var host = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Accept a bracketed IPv6 literal like [fe80::1] by stripping brackets.
        if host.hasPrefix("[") && host.hasSuffix("]") && host.count >= 2 {
            host = String(host.dropFirst().dropLast())
        }
        guard !host.isEmpty else { throw HostInputError.empty }
        guard !host.hasPrefix("-") else { throw HostInputError.leadingDash }
        // Allowed: letters, digits, dot, dash, colon (IPv6), percent (v6 scope).
        let allowed = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-:%")
        guard host.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw HostInputError.illegalCharacters
        }
        return host
    }

    /// Parses a port spec such as `"22,80,443,8000-8100"` into a sorted, unique
    /// list of valid ports. Caps the total at 2048 to bound fd usage.
    public func parsePortSpec(_ raw: String) throws -> [Int] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HostInputError.badPortSpec }
        var ports = Set<Int>()
        for token in trimmed.split(separator: ",") {
            let piece = token.trimmingCharacters(in: .whitespaces)
            if piece.contains("-") {
                let bounds = piece.split(separator: "-", maxSplits: 1)
                guard bounds.count == 2,
                      let lo = Int(bounds[0].trimmingCharacters(in: .whitespaces)),
                      let hi = Int(bounds[1].trimmingCharacters(in: .whitespaces)),
                      lo >= 1, hi <= 65535, lo <= hi else {
                    throw HostInputError.badPortSpec
                }
                for p in lo...hi { ports.insert(p) }
            } else {
                guard let p = Int(piece), p >= 1, p <= 65535 else {
                    throw HostInputError.badPortSpec
                }
                ports.insert(p)
            }
            if ports.count > 2048 { throw HostInputError.tooManyPorts(ports.count) }
        }
        return ports.sorted()
    }

    // MARK: 1. Ping (subprocess)

    /// Pings `host`, streaming raw output line-by-line through `onChunk` (which
    /// the caller marshals to the main actor) so the terminal panel fills live,
    /// just like a real `ping` session. The full output is still parsed into a
    /// summarised `PingResult` once the child exits. `onChunk` defaults to a
    /// no-op for callers that only want the final result.
    public func ping(host rawHost: String, count rawCount: Int, family: IPFamily,
                     onChunk: @escaping @Sendable (String) async -> Void = { _ in }) async -> PingResult {
        let host: String
        do { host = try validateHost(rawHost) }
        catch { return PingResult(host: rawHost, status: .failed,
                                  rawOutput: (error as? HostInputError)?.message ?? "Invalid host.") }

        let count = min(max(rawCount, 1), 20)
        let useV6 = (family == .ipv6) || (family == .auto && host.contains(":"))
        let resolvedFamily: IPFamily = useV6 ? .ipv6 : .ipv4
        let bin = useV6 ? Self.ping6Bin : Self.pingBin
        let deadlineSec = count + 2

        // ping6 has no overall-deadline flag; rely on the wall-clock backstop.
        let args: [String] = useV6
            ? ["-n", "-c", String(count), "-i", "1", host]
            : ["-n", "-c", String(count), "-t", String(deadlineSec), "-i", "1", host]

        let out = await runStreamingProcess(executable: bin, arguments: args,
                                            wallTimeout: TimeInterval(deadlineSec + 3),
                                            onChunk: onChunk)
        return Self.parsePing(out, host: host, family: resolvedFamily)
    }

    // MARK: 2. Port Scanner (native NWConnection)

    /// Scans `ports` on `host`, streaming each result through `onResult` (which
    /// the caller marshals to the main actor) so the list fills live and Cancel
    /// is responsive. Bounded to 64 connections in flight.
    public func scanPorts(host rawHost: String, ports: [Int],
                          perPortTimeout: TimeInterval,
                          onResult: @escaping @Sendable (PortResult) async -> Void) async {
        let host = (try? validateHost(rawHost)) ?? rawHost
        let timeout = min(max(perPortTimeout, 0.25), 5.0)
        let window = 64

        await withTaskGroup(of: PortResult.self) { group in
            var iterator = ports.makeIterator()
            var inFlight = 0
            while inFlight < window, let port = iterator.next() {
                group.addTask { await self.connectOnce(host: host, port: port, timeout: timeout) }
                inFlight += 1
            }
            while let result = await group.next() {
                if Task.isCancelled { group.cancelAll(); break }   // drop, don't deliver, once cancelled
                await onResult(result)
                if let port = iterator.next() {
                    group.addTask { await self.connectOnce(host: host, port: port, timeout: timeout) }
                }
            }
        }
    }

    /// One TCP connect probe. Always resolves: a dedicated timer fires
    /// `.filtered` because NWConnection never self-resolves a dropped SYN.
    private func connectOnce(host: String, port: Int, timeout: TimeInterval) async -> PortResult {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            return PortResult(port: port, status: .closed)
        }
        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = max(1, Int(timeout.rounded(.up)))
        let params = NWParameters(tls: nil, tcp: tcp)
        let conn = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: params)
        let queue = DispatchQueue(label: "net.portscan", qos: .utility)
        let start = DispatchTime.now()

        let status: PortStatus = await withCheckedContinuation { (cont: CheckedContinuation<PortStatus, Never>) in
            let once = ResumeOnce()
            @Sendable func finish(_ s: PortStatus) {
                guard once.tryResume() else { return }
                conn.cancel()
                cont.resume(returning: s)
            }
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(.open)
                case .failed:
                    finish(.closed)
                case .waiting(let err):
                    // A refused connection is a definitive "closed". Other
                    // waiting states (no route, transient) fall through to the
                    // timer, which classifies them as filtered.
                    if case .posix(let code) = err, code == .ECONNREFUSED { finish(.closed) }
                default:
                    break
                }
            }
            queue.asyncAfter(deadline: .now() + timeout) { finish(.filtered) }
            conn.start(queue: queue)
        }

        let latency = Double(DispatchTime.now().uptimeNanoseconds &- start.uptimeNanoseconds) / 1_000_000.0
        return PortResult(port: port, status: status,
                          serviceName: Self.serviceHints[port],
                          latencyMs: status == .open ? latency : nil)
    }

    // MARK: 3. Traceroute (subprocess)

    /// Traces hops to `host`, streaming each hop line through `onChunk` as the
    /// system `traceroute` prints it, then parsing the full output for the
    /// structured summary. `onChunk` defaults to a no-op.
    public func traceroute(host rawHost: String, maxHops rawHops: Int, family: IPFamily,
                           onChunk: @escaping @Sendable (String) async -> Void = { _ in }) async -> TracerouteResult {
        let host: String
        do { host = try validateHost(rawHost) }
        catch { return TracerouteResult(host: rawHost, status: .failed,
                                        rawOutput: (error as? HostInputError)?.message ?? "Invalid host.") }

        let maxHops = min(max(rawHops, 1), 30)
        let useV6 = (family == .ipv6) || (family == .auto && host.contains(":"))
        let resolvedFamily: IPFamily = useV6 ? .ipv6 : .ipv4
        let bin = useV6 ? Self.traceroute6Bin : Self.tracerouteBin
        let waitSec = 1, queries = 1
        let args = ["-n", "-w", String(waitSec), "-q", String(queries), "-m", String(maxHops), host]

        let wall = TimeInterval(maxHops * (waitSec + 1) * queries + 5)
        let out = await runStreamingProcess(executable: bin, arguments: args,
                                            wallTimeout: wall, onChunk: onChunk)
        return Self.parseTraceroute(out, host: host, family: resolvedFamily)
    }

    // MARK: 4. DNS Lookup (dig primary, getaddrinfo fallback)

    public func dnsLookup(host rawHost: String, types: [DNSRecordType],
                          onChunk: @escaping @Sendable (String) async -> Void = { _ in }) async -> DNSResult {
        let host: String
        do { host = try validateHost(rawHost) }
        catch { return DNSResult(query: rawHost, status: .failed,
                                 rawOutput: (error as? HostInputError)?.message ?? "Invalid host.") }

        let requested = types.isEmpty ? [.a] : types

        // Primary path: dig, one invocation per record type. Each query echoes
        // its command line and then streams its answer block, so the terminal
        // panel fills type-by-type just like a real shell session.
        if FileManager.default.isExecutableFile(atPath: Self.digBin) {
            var records: [DNSRecord] = []
            var raw = ""
            var anyResolved = false
            for type in requested {
                if Task.isCancelled { return DNSResult(query: host, records: records, status: .cancelled, rawOutput: raw) }
                let args = ["+noall", "+answer", "+nocomments", "+time=2", "+tries=1", host, type.rawValue]
                let header = "$ dig \(args.joined(separator: " "))\n"
                await onChunk(header)
                let out = await runStreamingProcess(executable: Self.digBin, arguments: args,
                                                    wallTimeout: 6, onChunk: onChunk)
                await onChunk("\n")
                raw += header + out.stdout + "\n"
                if out.status == .binaryMissing { break }
                let parsed = Self.parseDig(out.stdout, type: type)
                if !parsed.isEmpty { anyResolved = true }
                records.append(contentsOf: parsed)
            }
            let status: NetRunStatus = anyResolved ? .success : .resolutionFailed
            return DNSResult(query: host, records: records, status: status, rawOutput: raw)
        }

        // Fallback: getaddrinfo gives A/AAAA only.
        let (records, note) = await resolveWithGetaddrinfo(host: host)
        let status: NetRunStatus = records.isEmpty ? .resolutionFailed : .success
        let raw = "dig not available — used getaddrinfo (A/AAAA only).\n" + note
        await onChunk(raw)
        return DNSResult(query: host, records: records, status: status, rawOutput: raw)
    }

    /// `getaddrinfo`-based A/AAAA resolution. Runs off-main; relies on the
    /// system resolver's own timeout.
    private func resolveWithGetaddrinfo(host: String) async -> ([DNSRecord], String) {
        await runBlocking {
            var hints = addrinfo()
            hints.ai_family = AF_UNSPEC
            hints.ai_socktype = SOCK_STREAM
            hints.ai_flags = AI_ADDRCONFIG
            var info: UnsafeMutablePointer<addrinfo>?
            let rc = getaddrinfo(host, nil, &hints, &info)
            guard rc == 0, let first = info else {
                let msg = String(cString: gai_strerror(rc))
                return ([], "getaddrinfo: \(msg)")
            }
            defer { freeaddrinfo(first) }

            var records: [DNSRecord] = []
            var seen = Set<String>()
            var node: UnsafeMutablePointer<addrinfo>? = first
            while let cur = node {
                if let sa = cur.pointee.ai_addr {
                    var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let r = getnameinfo(sa, cur.pointee.ai_addrlen,
                                        &buf, socklen_t(buf.count), nil, 0, NI_NUMERICHOST)
                    if r == 0 {
                        let addr = Self.cString(buf)
                        let type: DNSRecordType = cur.pointee.ai_family == AF_INET6 ? .aaaa : .a
                        let key = "\(type.rawValue)|\(addr)"
                        if !addr.isEmpty, seen.insert(key).inserted {
                            records.append(DNSRecord(name: host, type: type, value: addr))
                        }
                    }
                }
                node = cur.pointee.ai_next
            }
            return (records, "Resolved \(records.count) address(es).")
        }
    }

    // MARK: 5. Interfaces (native getifaddrs)

    public func interfaces() async -> [NetworkInterface] {
        await runBlocking { Self.enumerateInterfaces() }
    }

    // MARK: 6. Netstat (subprocess)

    public func netstat(mode: NetstatMode,
                        onChunk: @escaping @Sendable (String) async -> Void = { _ in }) async -> NetstatResult {
        guard FileManager.default.isExecutableFile(atPath: Self.netstatBin) else {
            return NetstatResult(status: .binaryMissing, rawOutput: "netstat not available at \(Self.netstatBin).")
        }
        switch mode {
        case .routing:
            let out = await runStreamingProcess(executable: Self.netstatBin, arguments: ["-r", "-n"],
                                                wallTimeout: 8, onChunk: onChunk)
            var result = Self.parseRoutes(out.stdout)
            result.status = out.status
            result.rawOutput = out.stdout
            return result
        case .connections:
            // `-n` is mandatory: reverse-DNS / service-name resolution is the #1
            // hidden hang. Query TCP and UDP separately and merge — each streams
            // into the terminal panel as it is produced.
            let tcp = await runStreamingProcess(executable: Self.netstatBin, arguments: ["-a", "-n", "-p", "tcp"],
                                                wallTimeout: 8, onChunk: onChunk)
            if Task.isCancelled { return NetstatResult(status: .cancelled, rawOutput: tcp.stdout) }
            await onChunk("\n")
            let udp = await runStreamingProcess(executable: Self.netstatBin, arguments: ["-a", "-n", "-p", "udp"],
                                                wallTimeout: 8, onChunk: onChunk)
            var result = Self.parseConnections(tcp.stdout + "\n" + udp.stdout)
            result.status = (tcp.status == .success || udp.status == .success) ? .success : tcp.status
            result.rawOutput = tcp.stdout + "\n" + udp.stdout
            return result
        }
    }

    // MARK: - Off-main helpers

    /// Runs synchronous blocking work on a background queue and awaits it.
    private func runBlocking<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { (cont: CheckedContinuation<T, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: work())
            }
        }
    }

    /// Outcome of a child process run.
    struct ProcOutcome: Sendable {
        var stdout: String
        var stderr: String
        var status: NetRunStatus
    }

    /// Launches `executable` with `arguments`, reading output incrementally and
    /// forwarding each chunk through `onChunk` as it arrives so the caller can
    /// render it live. The full output is also accumulated and returned (with
    /// status) so the final outcome can still be parsed. The locale and PATH are
    /// locked so localized output can't break the parsers and a hijacked PATH
    /// can't redirect a child lookup. Cancellable and wall-clock bounded.
    ///
    /// stderr is merged into the same pipe as stdout (like a shell's `2>&1`), so
    /// what streams live is byte-identical to the returned output and ordered
    /// exactly as the child emits it — e.g. `traceroute`'s header line (written
    /// to stderr) appears above its hops instead of jumping in at completion.
    ///
    /// A blocking `availableData` read loop on a background queue bridges into an
    /// `AsyncStream`, whose consumer (this async function) awaits `onChunk` —
    /// the only place that crosses back to the caller's actor.
    private func runStreamingProcess(executable: String, arguments: [String],
                                     wallTimeout: TimeInterval,
                                     onChunk: @escaping @Sendable (String) async -> Void) async -> ProcOutcome {
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            return ProcOutcome(stdout: "", stderr: "\(executable) not found.", status: .binaryMissing)
        }
        let killBox = ProcessKillBox()
        let outBox = DataBox()
        let timedOut = FlagBox()
        let launchFailed = FlagBox()

        let stream = AsyncStream<String> { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [killBox, outBox, timedOut, launchFailed] in
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: executable)
                proc.arguments = arguments
                proc.environment = ["LC_ALL": "C", "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = pipe   // merge stderr → stdout (2>&1)

                guard killBox.register(proc) else { continuation.finish(); return }
                do {
                    try proc.run()
                    if killBox.isCancelled { proc.terminate() }
                } catch {
                    outBox.data = Data("Failed to launch: \(error.localizedDescription)".utf8)
                    launchFailed.set()
                    continuation.finish()
                    return
                }

                // Wall-clock backstop: SIGTERM, escalating to SIGKILL after a
                // grace period if the child ignores it (parity with runProcess).
                // The liveness guard means a child that finished a hair before the
                // deadline is never mislabelled as a timeout.
                let watchdog = DispatchWorkItem { [weak proc] in
                    guard let proc, proc.isRunning else { return }
                    timedOut.set()
                    proc.terminate()
                    let pid = proc.processIdentifier
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3) {
                        if proc.isRunning { kill(pid, SIGKILL) }
                    }
                }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + wallTimeout, execute: watchdog)

                // Blocking incremental read: availableData returns as soon as the
                // child writes, and an empty Data marks EOF. A multibyte UTF-8
                // scalar can straddle two reads, so bytes that don't yet decode
                // are carried forward rather than dropped from the live view.
                let handle = pipe.fileHandleForReading
                var pending = Data()
                while true {
                    let chunk = handle.availableData
                    if chunk.isEmpty { break }
                    outBox.data.append(chunk)
                    pending.append(chunk)
                    if let s = String(data: pending, encoding: .utf8) {
                        continuation.yield(s)
                        pending.removeAll(keepingCapacity: true)
                    }
                }
                // Flush any trailing bytes at EOF (decode with replacement so the
                // live view never silently loses output).
                if !pending.isEmpty { continuation.yield(String(decoding: pending, as: UTF8.self)) }

                watchdog.cancel()
                proc.waitUntilExit()
                continuation.finish()
            }
        }

        return await withTaskCancellationHandler {
            // No per-chunk cancellation break here: that would race the background
            // reader's writes to outBox. Cancellation is handled by killBox (which
            // terminates the child, ending the stream) and, at the call site, by a
            // run-generation guard that drops chunks from a superseded run.
            for await chunk in stream { await onChunk(chunk) }
            let stdout = String(data: outBox.data, encoding: .utf8) ?? ""
            let status: NetRunStatus = launchFailed.isSet ? .failed
                : timedOut.isSet ? .timedOut
                : (killBox.isCancelled ? .cancelled : .success)
            return ProcOutcome(stdout: stdout, stderr: "", status: status)
        } onCancel: {
            killBox.cancel()
        }
    }
}

#endif
