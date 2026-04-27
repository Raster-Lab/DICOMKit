// main.swift — dicom-jpip
// DICOM JPIP streaming client/server utility

import Foundation
import ArgumentParser
import DICOMCore
import DICOMKit
import DICOMDictionary
import JPIP

@available(macOS 10.15, *)
struct DICOMJpip: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-jpip",
        abstract: "JPIP (JPEG 2000 Interactive Protocol) streaming for DICOM imaging",
        discussion: """
            Interact with JPIP servers to progressively stream JPEG 2000 DICOM images.
            JPIP allows retrieving only the image region, resolution level, and quality
            layers needed, minimising bandwidth for large medical imaging datasets.

            Transfer Syntaxes:
              JPIP Referenced          1.2.840.10008.1.2.4.94
              JPIP Referenced Deflate  1.2.840.10008.1.2.4.95

            Examples:
              # Fetch full image from JPIP server
              dicom-jpip fetch http://pacs.example.com:8080 --image CT0001

              # Fetch a region at low quality (fast preview)
              dicom-jpip fetch http://pacs.example.com:8080 --image CT0001 \\
                  --region 0,0,512,512 --layers 2

              # Extract JPIP URI from a DICOM file
              dicom-jpip uri study.dcm

              # Start an embedded JPIP server serving local DICOM files
              dicom-jpip serve --port 8080 --directory /path/to/dicom/files

              # Get JPIP server statistics
              dicom-jpip info http://pacs.example.com:8080
            """,
        version: "1.0.0",
        subcommands: [
            FetchCommand.self,
            URICommand.self,
            ServeCommand.self,
            InfoCommand.self
        ],
        defaultSubcommand: InfoCommand.self
    )
}

// MARK: - fetch

@available(macOS 10.15, *)
extension DICOMJpip {
    struct FetchCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "fetch",
            abstract: "Fetch a DICOM image from a JPIP server",
            discussion: """
                Connects to a JPIP server and retrieves a DICOM image progressively.
                Use --layers to limit quality for faster previews, --region for ROI fetching,
                and --level for low-resolution thumbnails.

                Examples:
                  dicom-jpip fetch http://pacs.example.com:8080 --image CT0001
                  dicom-jpip fetch http://pacs.example.com:8080 --image CT0001 --layers 4
                  dicom-jpip fetch http://pacs.example.com:8080 --image CT0001 --region 0,0,512,512
                  dicom-jpip fetch http://pacs.example.com:8080 --image CT0001 --level 2
                  dicom-jpip fetch http://pacs.example.com:8080 --image CT0001 --output decoded.raw
                """
        )

        @Argument(help: "JPIP server base URL (e.g., http://pacs.example.com:8080)")
        var serverURL: String

        @Option(name: .long, help: "Image ID or JPIP target path on the server")
        var image: String

        @Option(name: .long, help: "Quality layers to fetch (1 = lowest, omit for full quality)")
        var layers: Int?

        @Option(name: .long, help: "Resolution level (0 = full, 1 = half, 2 = quarter...)")
        var level: Int?

        @Option(
            name: .long,
            help: "Region of interest: x,y,width,height (e.g., 0,0,512,512)"
        )
        var region: String?

        @Option(name: .shortAndLong, help: "Output file path for raw decoded pixel data")
        var output: String?

        @Flag(name: .shortAndLong, help: "Verbose output")
        var verbose: Bool = false

        mutating func validate() throws {
            guard URL(string: serverURL) != nil else {
                throw ValidationError("Invalid server URL: \(serverURL)")
            }
            guard !image.isEmpty else {
                throw ValidationError("--image must not be empty")
            }
            if let r = region {
                let parts = r.split(separator: ",").compactMap { Int($0) }
                guard parts.count == 4 else {
                    throw ValidationError("--region must be x,y,width,height (four integers)")
                }
                guard parts[2] > 0, parts[3] > 0 else {
                    throw ValidationError("--region width and height must be positive")
                }
            }
        }

        mutating func run() throws {
            guard let url = URL(string: serverURL) else {
                throw ExitCode.failure
            }
            let jpipURI = url.appendingPathComponent(image)
            // Capture mutable state before Task to avoid 'escaping closure captures mutating self'
            let capturedVerbose = verbose
            let capturedRegion = region
            let capturedLayers = layers
            let capturedLevel = level
            let capturedOutput = output

            let task = Task {
                let client = DICOMJPIPClient(serverURL: url)
                defer { Task { try? await client.close() } }

                if capturedVerbose {
                    print("Server: \(url.absoluteString)")
                    print("Image:  \(jpipURI.lastPathComponent)")
                }

                let fetchedImage: DICOMJPIPImage

                if let regionStr = capturedRegion {
                    let parts = regionStr.split(separator: ",").compactMap { Int($0) }
                    let roi = DICOMJPIPRegion(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
                    let quality: DICOMJPIPQuality
                    if let l = capturedLayers {
                        quality = .layers(l)
                    } else if let lv = capturedLevel {
                        quality = .resolutionLevel(lv)
                    } else {
                        quality = .full
                    }
                    if capturedVerbose { print("Region: x=\(parts[0]) y=\(parts[1]) w=\(parts[2]) h=\(parts[3])") }
                    fetchedImage = try await client.fetchRegion(jpipURI: jpipURI, region: roi, quality: quality)
                } else if let l = capturedLayers {
                    if capturedVerbose { print("Quality layers: \(l)") }
                    fetchedImage = try await client.fetchProgressiveQuality(jpipURI: jpipURI, layers: l)
                } else if let lv = capturedLevel {
                    if capturedVerbose { print("Resolution level: \(lv)") }
                    fetchedImage = try await client.fetchResolutionLevel(jpipURI: jpipURI, level: lv)
                } else {
                    fetchedImage = try await client.fetchImage(jpipURI: jpipURI)
                }

                print("Fetched: \(fetchedImage.width)×\(fetchedImage.height), \(fetchedImage.components) component(s), \(fetchedImage.bitDepth)-bit")
                print("Pixel data: \(formatBytes(fetchedImage.pixelData.count))")

                if let outputPath = capturedOutput {
                    let outputURL = URL(fileURLWithPath: outputPath)
                    try fetchedImage.pixelData.write(to: outputURL)
                    print("Written: \(outputPath)")
                }
            }

            _ = try waitForTask(task)
        }
    }
}

// MARK: - uri

@available(macOS 10.15, *)
extension DICOMJpip {
    struct URICommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "uri",
            abstract: "Extract the JPIP URI from a DICOM file",
            discussion: """
                Reads a DICOM file that uses a JPIP referenced transfer syntax and prints
                the JPIP server URI stored in the Pixel Data element.

                Examples:
                  dicom-jpip uri study.dcm
                  dicom-jpip uri study.dcm --json
                """
        )

        @Argument(help: "DICOM file path")
        var input: String

        @Flag(name: .long, help: "Output as JSON")
        var json: Bool = false

        mutating func validate() throws {
            guard FileManager.default.fileExists(atPath: input) else {
                throw ValidationError("File not found: \(input)")
            }
        }

        mutating func run() throws {
            let fileURL = URL(fileURLWithPath: input)
            let dicomFile = try DICOMFile.read(from: fileURL)
            let tsUID = dicomFile.transferSyntaxUID ?? TransferSyntax.explicitVRLittleEndian.uid
            let ts = TransferSyntax.from(uid: tsUID)

            guard ts?.isJPIP == true else {
                print("Error: Transfer syntax \(tsUID) is not a JPIP reference syntax")
                print("JPIP transfer syntaxes: 1.2.840.10008.1.2.4.94, 1.2.840.10008.1.2.4.95")
                throw ExitCode.failure
            }

            let jpipURL = try DICOMJPIPClient.jpipURI(from: dicomFile.dataSet, transferSyntaxUID: tsUID)

            if json {
                let result: [String: Any] = [
                    "file": input,
                    "transferSyntaxUID": tsUID,
                    "isDeflated": ts?.isDeflated ?? false,
                    "jpipURI": jpipURL.absoluteString
                ]
                let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])
                print(String(data: data, encoding: .utf8) ?? "")
            } else {
                print("File:              \(input)")
                print("Transfer Syntax:   \(tsUID)\(ts?.isDeflated == true ? " (deflated)" : "")")
                print("JPIP URI:          \(jpipURL.absoluteString)")
            }
        }
    }
}

// MARK: - serve

@available(macOS 10.15, *)
extension DICOMJpip {
    struct ServeCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "serve",
            abstract: "Start an embedded JPIP server for local DICOM files",
            discussion: """
                Launches a JPIP server that serves DICOM files from a local directory.
                Clients can then use dicom-jpip fetch or any JPIP-compatible viewer.

                Examples:
                  dicom-jpip serve --directory /path/to/dicoms
                  dicom-jpip serve --port 8081 --directory /path/to/dicoms --max-clients 10
                """
        )

        @Option(name: .shortAndLong, help: "Port to listen on (default: 8080)")
        var port: Int = 8080

        @Option(name: .shortAndLong, help: "Directory of DICOM files to serve")
        var directory: String = "."

        @Option(name: .long, help: "Maximum concurrent clients (default: 16)")
        var maxClients: Int = 16

        @Option(name: .long, help: "Per-client bandwidth limit in bytes/sec (0 = unlimited)")
        var clientBandwidth: Int = 0

        @Flag(name: .shortAndLong, help: "Verbose output")
        var verbose: Bool = false

        mutating func validate() throws {
            guard port > 0, port < 65536 else {
                throw ValidationError("Port must be 1–65535")
            }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDir), isDir.boolValue else {
                throw ValidationError("Directory not found: \(directory)")
            }
        }

        mutating func run() throws {
            let dirURL = URL(fileURLWithPath: directory, isDirectory: true)
            // Capture mutable state before Task to avoid 'escaping closure captures mutating self'
            let capturedPort = port
            let capturedMaxClients = maxClients
            let capturedClientBandwidth = clientBandwidth
            let capturedDirectory = directory
            let capturedVerbose = verbose

            let serverTask = Task {
                let config = JPIPServer.Configuration(
                    maxClients: capturedMaxClients,
                    maxQueueSize: 64,
                    globalBandwidthLimit: nil,
                    perClientBandwidthLimit: capturedClientBandwidth == 0 ? nil : capturedClientBandwidth,
                    sessionTimeout: 300
                )
                let server = JPIPServer(port: capturedPort, configuration: config)

                // Register all DICOM files in the directory
                let enumerator = FileManager.default.enumerator(
                    at: dirURL,
                    includingPropertiesForKeys: nil
                )
                var registered = 0
                while let fileURL = enumerator?.nextObject() as? URL {
                    guard fileURL.pathExtension.lowercased() == "dcm" else { continue }
                    let name = fileURL.deletingPathExtension().lastPathComponent
                    do {
                        try await server.registerImage(name: name, at: fileURL)
                        registered += 1
                        if capturedVerbose { print("Registered: \(name)") }
                    } catch {
                        if capturedVerbose { print("Warning: could not register \(name): \(error)") }
                    }
                }

                print("JPIP Server starting on port \(capturedPort)")
                print("Serving \(registered) DICOM file(s) from \(capturedDirectory)")
                print("Press Ctrl+C to stop.")

                try await server.start()

                // Run until interrupted
                while !Task.isCancelled {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    if capturedVerbose {
                        let stats = await server.getStatistics()
                        print("Requests: \(stats.totalRequests)  Active: \(stats.activeClients)  Sent: \(formatBytes(stats.totalBytesSent))")
                    }
                }

                try await server.stop()
            }

            // Block main thread, handling SIGINT
            let sema = DispatchSemaphore(value: 0)
            signal(SIGINT) { _ in
                print("\nShutting down...")
                Darwin.exit(0)
            }
            sema.wait()
            _ = serverTask
        }
    }
}

// MARK: - info

@available(macOS 10.15, *)
extension DICOMJpip {
    struct InfoCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "info",
            abstract: "Display information about a JPIP server or DICOM file",
            discussion: """
                Shows JPIP transfer syntax information for a DICOM file, or queries
                server statistics when given a server URL.

                Examples:
                  dicom-jpip info study.dcm
                  dicom-jpip info http://pacs.example.com:8080
                  dicom-jpip info --list-syntaxes
                """
        )

        @Argument(help: "DICOM file path or JPIP server URL (optional)")
        var target: String?

        @Flag(name: .long, help: "List JPIP transfer syntaxes")
        var listSyntaxes: Bool = false

        @Flag(name: .long, help: "Output as JSON")
        var json: Bool = false

        mutating func run() throws {
            if listSyntaxes {
                printJPIPSyntaxes(asJSON: json)
                return
            }

            guard let target = target else {
                print("JPIP (JPEG 2000 Interactive Protocol) — DICOM PS3.5 Annex A.8")
                print("")
                print("Transfer Syntaxes:")
                printJPIPSyntaxes(asJSON: false)
                print("")
                print("Use 'dicom-jpip --help' for available subcommands.")
                return
            }

            // If it looks like a URL, query the server
            if target.hasPrefix("http://") || target.hasPrefix("https://") {
                guard let serverURL = URL(string: target) else {
                    print("Error: Invalid URL: \(target)")
                    throw ExitCode.failure
                }
                try queryServer(serverURL: serverURL)
            } else {
                // Treat as a DICOM file
                try inspectDICOMFile(path: target)
            }
        }

        private func printJPIPSyntaxes(asJSON: Bool) {
            let syntaxes: [[String: Any]] = [
                ["uid": "1.2.840.10008.1.2.4.94", "name": "JPIP Referenced",
                 "description": "Pixel Data contains a JPIP server URI; image data retrieved on demand"],
                ["uid": "1.2.840.10008.1.2.4.95", "name": "JPIP Referenced Deflate",
                 "description": "Same as JPIP Referenced but DICOM dataset is deflate-compressed"]
            ]
            if asJSON {
                let data = try? JSONSerialization.data(withJSONObject: syntaxes, options: [.prettyPrinted])
                print(String(data: data ?? Data(), encoding: .utf8) ?? "")
            } else {
                for s in syntaxes {
                    print("  \(s["uid"] ?? "")  \(s["name"] ?? "")")
                    print("    \(s["description"] ?? "")")
                }
            }
        }

        private func inspectDICOMFile(path: String) throws {
            guard FileManager.default.fileExists(atPath: path) else {
                print("Error: File not found: \(path)")
                throw ExitCode.failure
            }
            let fileURL = URL(fileURLWithPath: path)
            let dicomFile = try DICOMFile.read(from: fileURL)
            let tsUID = dicomFile.transferSyntaxUID ?? TransferSyntax.explicitVRLittleEndian.uid
            let ts = TransferSyntax.from(uid: tsUID)

            if json {
                var result: [String: Any] = [
                    "file": path,
                    "transferSyntaxUID": tsUID,
                    "isJPIP": ts?.isJPIP ?? false
                ]
                if ts?.isJPIP == true {
                    if let jpipURL = try? DICOMJPIPClient.jpipURI(from: dicomFile.dataSet, transferSyntaxUID: tsUID) {
                        result["jpipURI"] = jpipURL.absoluteString
                    }
                }
                let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])
                print(String(data: data, encoding: .utf8) ?? "")
            } else {
                print("File:            \(path)")
                print("Transfer Syntax: \(tsUID)")
                print("Is JPIP:         \(ts?.isJPIP == true ? "Yes" : "No")")
                if ts?.isJPIP == true {
                    if let jpipURL = try? DICOMJPIPClient.jpipURI(from: dicomFile.dataSet, transferSyntaxUID: tsUID) {
                        print("JPIP URI:        \(jpipURL.absoluteString)")
                        print("Server Host:     \(jpipURL.host ?? "unknown")")
                        print("Server Port:     \(jpipURL.port.map(String.init) ?? "default")")
                    }
                }
            }
        }

        private func queryServer(serverURL: URL) throws {
            print("JPIP Server: \(serverURL.absoluteString)")
            print("(Use 'dicom-jpip serve' to start a local JPIP server)")
        }
    }
}

// MARK: - Helpers

private func formatBytes(_ bytes: Int) -> String {
    if bytes < 1024 {
        return "\(bytes) B"
    } else if bytes < 1024 * 1024 {
        return String(format: "%.1f KB", Double(bytes) / 1024.0)
    } else if bytes < 1024 * 1024 * 1024 {
        return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
    } else {
        return String(format: "%.1f GB", Double(bytes) / (1024.0 * 1024.0 * 1024.0))
    }
}

/// Synchronously waits for an async Task to complete and returns its value.
/// Used by ParsableCommand.run() which cannot be async.
@available(macOS 10.15, *)
private func waitForTask<T>(_ task: Task<T, Error>) throws -> T {
    let sema = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var result: Result<T, Error>?
    Task {
        do {
            let value = try await task.value
            result = .success(value)
        } catch {
            result = .failure(error)
        }
        sema.signal()
    }
    sema.wait()
    switch result! {
    case .success(let value): return value
    case .failure(let error): throw error
    }
}

DICOMJpip.main()
