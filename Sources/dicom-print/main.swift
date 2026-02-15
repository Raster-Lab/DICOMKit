import Foundation
import ArgumentParser
import DICOMCore
import DICOMNetwork

// MARK: - Constants

/// Tool version - used in both CommandConfiguration and verbose output
private let toolVersion = "1.4.5"

/// DICOM file format constants
private let dicomPreambleSize = 128
private let dicomHeaderSize = 132  // Preamble (128) + Magic bytes (4)
private let dicomMagicBytes = Data([0x44, 0x49, 0x43, 0x4D])  // "DICM"

/// DICOM Print CLI Tool
///
/// Provides command-line interface for DICOM Print Management operations.
/// Supports querying printer status, sending images to print, managing printer
/// configurations, and monitoring print jobs.
///
/// Reference: DICOM PS3.4 Annex H - Print Management Service Class
struct DICOMPrint: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-print",
        abstract: "DICOM Print Management - print medical images to DICOM printers",
        discussion: """
            Send DICOM images to DICOM-compliant printers using the Print Management
            Service Class. Supports film printing, printer status queries, job monitoring,
            and printer configuration management.
            
            URL Format:
              pacs://hostname:port     - DICOM Print protocol
            
            Examples:
              # Query printer status
              dicom-print status pacs://192.168.1.100:11112 --aet WORKSTATION
            
              # Print single DICOM image
              dicom-print send pacs://192.168.1.100:11112 image.dcm --aet WORKSTATION
            
              # Print multiple images with layout
              dicom-print send pacs://server:11112 *.dcm --aet APP --layout 2x3
            
              # Print with specific options
              dicom-print send pacs://server:11112 scan.dcm --aet APP \\
                  --copies 2 --film-size 14x17 --orientation landscape
            
              # Monitor print job status
              dicom-print job pacs://server:11112 --aet APP --job-id 1.2.840...
            
              # List configured printers (from local config)
              dicom-print list-printers
            
              # Add a new printer configuration
              dicom-print add-printer --name radiology-printer \\
                  --host 192.168.1.100 --port 11112 --called-ae PRINT_SCP
            """,
        version: toolVersion,
        subcommands: [
            StatusCommand.self,
            SendCommand.self,
            JobCommand.self,
            ListPrintersCommand.self,
            AddPrinterCommand.self,
            RemovePrinterCommand.self
        ],
        defaultSubcommand: SendCommand.self
    )
}

// MARK: - Async Runner Helper

/// Thread-safe container for async results
private final class AsyncResultBox<T: Sendable>: @unchecked Sendable {
    private var _value: Result<T, Error>?
    private let lock = NSLock()
    
    var value: Result<T, Error>? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }
}

/// Runs async code synchronously using a thread-safe result container
func runAsync<T: Sendable>(_ block: @Sendable @escaping () async throws -> T) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    let resultBox = AsyncResultBox<T>()
    
    Task {
        do {
            let value = try await block()
            resultBox.value = .success(value)
        } catch {
            resultBox.value = .failure(error)
        }
        semaphore.signal()
    }
    semaphore.wait()
    
    guard let result = resultBox.value else {
        throw ValidationError("Async operation did not complete")
    }
    return try result.get()
}

// MARK: - Status Command

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Query DICOM printer status",
        discussion: """
            Queries the status of a DICOM printer using the N-GET service.
            Returns printer status, name, and capabilities.
            
            Examples:
              dicom-print status pacs://192.168.1.100:11112 --aet WORKSTATION
              dicom-print status pacs://server:11112 --aet APP --verbose
            """
    )
    
    @Argument(help: "Printer URL (pacs://host:port)")
    var url: String
    
    @Option(name: .long, help: "Local Application Entity Title (calling AE)")
    var aet: String
    
    @Option(name: .long, help: "Remote Application Entity Title (default: ANY-SCP)")
    var calledAet: String = "ANY-SCP"
    
    @Option(name: .long, help: "Connection timeout in seconds (default: 30)")
    var timeout: Int = 30
    
    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose: Bool = false
    
    @Option(name: .long, help: "Output format: text, json (default: text)")
    var format: OutputFormat = .text
    
    mutating func run() throws {
        #if canImport(Network)
        let serverInfo = try parseServerURL(url)
        
        let config = PrintConfiguration(
            host: serverInfo.host,
            port: serverInfo.port,
            callingAETitle: aet,
            calledAETitle: calledAet,
            timeout: TimeInterval(timeout)
        )
        
        if verbose {
            fprintln("Querying printer status...")
            fprintln("  Host: \(serverInfo.host):\(serverInfo.port)")
            fprintln("  Calling AE: \(aet)")
            fprintln("  Called AE: \(calledAet)")
            fprintln("")
        }
        
        let status = try runAsync {
            try await DICOMPrintService.getPrinterStatus(configuration: config)
        }
        
        switch format {
        case .text:
            printStatusText(status)
        case .json:
            printStatusJSON(status)
        }
        
        #else
        throw ValidationError("Network functionality is not available on this platform")
        #endif
    }
    
    func printStatusText(_ status: PrinterStatus) {
        fprintln("Printer Status")
        fprintln("==============")
        fprintln("Name: \(status.printerName ?? "Unknown")")
        fprintln("Status: \(status.status)")
        if let info = status.statusInfo {
            fprintln("Status Info: \(info)")
        }
        fprintln("Is Normal: \(status.isNormal ? "Yes" : "No")")
    }
    
    func printStatusJSON(_ status: PrinterStatus) {
        var dict: [String: Any] = [
            "status": status.status,
            "isNormal": status.isNormal
        ]
        if let name = status.printerName { dict["name"] = name }
        if let info = status.statusInfo { dict["statusInfo"] = info }
        
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    }
}

// MARK: - Send Command

struct SendCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "send",
        abstract: "Send DICOM images to printer",
        discussion: """
            Sends DICOM images to a DICOM printer using the Print Management Service.
            Supports single images, multiple images with automatic layout, and templates.
            
            Examples:
              # Print single image
              dicom-print send pacs://server:11112 image.dcm --aet WORKSTATION
            
              # Print with custom options
              dicom-print send pacs://server:11112 scan.dcm --aet APP \\
                  --copies 2 --film-size 14x17 --orientation landscape
            
              # Print multiple images with layout
              dicom-print send pacs://server:11112 *.dcm --aet APP --layout 2x3
            
              # Print directory recursively
              dicom-print send pacs://server:11112 studies/ --aet APP --recursive
            """
    )
    
    @Argument(help: "Printer URL (pacs://host:port)")
    var url: String
    
    @Argument(help: "DICOM files or directories to print")
    var paths: [String]
    
    @Option(name: .long, help: "Local Application Entity Title (calling AE)")
    var aet: String
    
    @Option(name: .long, help: "Remote Application Entity Title (default: ANY-SCP)")
    var calledAet: String = "ANY-SCP"
    
    @Option(name: .long, help: "Number of copies (default: 1)")
    var copies: Int = 1
    
    @Option(name: .long, help: "Film size: 8x10, 10x12, 10x14, 11x14, 11x17, 14x14, 14x17, a4, a3 (default: 14x17)")
    var filmSize: FilmSizeOption = .size14x17
    
    @Option(name: .long, help: "Film orientation: portrait, landscape (default: portrait)")
    var orientation: OrientationOption = .portrait
    
    @Option(name: .long, help: "Print priority: low, medium, high (default: medium)")
    var priority: PrintPriorityOption = .medium
    
    @Option(name: .long, help: "Image layout: 1x1, 1x2, 2x1, 2x2, 2x3, 3x3, 3x4, 4x4, 4x5 (auto if not specified)")
    var layout: LayoutOption?
    
    @Option(name: .long, help: "Medium type: paper, clear-film, blue-film (default: paper)")
    var medium: MediumOption = .paper
    
    @Flag(name: .shortAndLong, help: "Recursively scan directories for DICOM files")
    var recursive: Bool = false
    
    @Flag(name: .long, help: "Show what would be printed without actually printing")
    var dryRun: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show verbose output with progress")
    var verbose: Bool = false
    
    @Option(name: .long, help: "Connection timeout in seconds (default: 60)")
    var timeout: Int = 60
    
    mutating func run() throws {
        #if canImport(Network)
        let serverInfo = try parseServerURL(url)
        
        let config = PrintConfiguration(
            host: serverInfo.host,
            port: serverInfo.port,
            callingAETitle: aet,
            calledAETitle: calledAet,
            timeout: TimeInterval(timeout)
        )
        
        if verbose {
            fprintln("DICOM Print Tool v\(toolVersion)")
            fprintln("=======================")
            fprintln("Server: \(serverInfo.host):\(serverInfo.port)")
            fprintln("Calling AE: \(aet)")
            fprintln("Called AE: \(calledAet)")
            fprintln("Copies: \(copies)")
            fprintln("Film Size: \(filmSize.filmSize.rawValue)")
            fprintln("Orientation: \(orientation.orientation.rawValue)")
            fprintln("Priority: \(priority.printPriority.rawValue)")
            fprintln("Medium: \(medium.mediumType.rawValue)")
            if let layout = layout {
                fprintln("Layout: \(layout.rawValue)")
            }
            if dryRun {
                fprintln("Mode: DRY RUN (no files will be printed)")
            }
            fprintln("")
        }
        
        // Gather files to print
        let filesToPrint = try gatherFiles(from: paths, recursive: recursive)
        
        if filesToPrint.isEmpty {
            throw ValidationError("No DICOM files found to print")
        }
        
        if verbose || dryRun {
            fprintln("Found \(filesToPrint.count) file(s) to print")
            if verbose {
                for (index, path) in filesToPrint.enumerated() {
                    fprintln("  [\(index + 1)] \(path)")
                }
                fprintln("")
            }
        }
        
        if dryRun {
            fprintln("Dry run complete. Use without --dry-run to print files.")
            return
        }
        
        // Create print options
        let options = PrintOptions(
            numberOfCopies: copies,
            priority: priority.printPriority,
            filmSize: filmSize.filmSize,
            filmOrientation: orientation.orientation,
            mediumType: medium.mediumType
        )
        
        // Read and print files
        let parser = DICOMParser()
        var imageDataList: [Data] = []
        for path in filesToPrint {
            guard let data = FileManager.default.contents(atPath: path) else {
                throw ValidationError("Cannot read file: \(path)")
            }
            
            // Parse DICOM and extract pixel data
            let dataSet = try parser.parse(data: data)
            
            // Get pixel data from the dataset
            guard let pixelData = dataSet.data(for: .pixelData) else {
                throw ValidationError("No pixel data found in: \(path)")
            }
            
            imageDataList.append(pixelData)
        }
        
        // Print based on number of images
        if imageDataList.count == 1 {
            // Single image print
            if verbose {
                fprintln("Printing single image...")
            }
            
            let result = try runAsync {
                try await DICOMPrintService.printImage(
                    configuration: config,
                    imageData: imageDataList[0],
                    options: options
                )
            }
            
            printResult(result, verbose: verbose)
        } else {
            // Multi-image print
            if verbose {
                fprintln("Printing \(imageDataList.count) images...")
            }
            
            let result = try runAsync {
                try await DICOMPrintService.printImages(
                    configuration: config,
                    images: imageDataList,
                    options: options
                )
            }
            
            printResult(result, verbose: verbose)
        }
        
        #else
        throw ValidationError("Network functionality is not available on this platform")
        #endif
    }
    
    func printResult(_ result: PrintResult, verbose: Bool) {
        if result.success {
            fprintln("✓ Print job submitted successfully")
            if let jobUID = result.printJobUID {
                fprintln("  Print Job UID: \(jobUID)")
            }
            if let sessionUID = result.filmSessionUID {
                fprintln("  Film Session UID: \(sessionUID)")
            }
        } else {
            fprintln("✗ Print failed")
            if let error = result.errorMessage {
                fprintln("  Error: \(error)")
            }
        }
    }
    
    func gatherFiles(from paths: [String], recursive: Bool) throws -> [String] {
        var files: [String] = []
        let fileManager = FileManager.default
        
        for path in paths {
            let expandedPaths = expandGlobPattern(path)
            
            for expandedPath in expandedPaths {
                var isDirectory: ObjCBool = false
                
                guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory) else {
                    if verbose {
                        fprintln("Warning: Path not found: \(expandedPath)")
                    }
                    continue
                }
                
                if isDirectory.boolValue {
                    let foundFiles = try scanDirectory(expandedPath, recursive: recursive)
                    files.append(contentsOf: foundFiles)
                } else {
                    files.append(expandedPath)
                }
            }
        }
        
        return files
    }
    
    func expandGlobPattern(_ pattern: String) -> [String] {
        let fileManager = FileManager.default
        
        if !pattern.contains("*") && !pattern.contains("?") {
            return [pattern]
        }
        
        let url = URL(fileURLWithPath: pattern)
        let directory = url.deletingLastPathComponent().path
        let filePattern = url.lastPathComponent
        
        guard let enumerator = fileManager.enumerator(atPath: directory) else {
            // Log warning for debugging but return empty - directory may not exist or not be accessible
            if verbose {
                fprintln("Warning: Cannot enumerate directory for glob: \(directory)")
            }
            return []
        }
        
        var matches: [String] = []
        for case let item as String in enumerator {
            if matchesPattern(item, pattern: filePattern) {
                matches.append((directory as NSString).appendingPathComponent(item))
            }
        }
        
        return matches
    }
    
    func matchesPattern(_ string: String, pattern: String) -> Bool {
        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")
        
        guard let regex = try? NSRegularExpression(pattern: "^" + regexPattern + "$") else {
            return false
        }
        
        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, range: range) != nil
    }
    
    func scanDirectory(_ path: String, recursive: Bool) throws -> [String] {
        let fileManager = FileManager.default
        var files: [String] = []
        
        if recursive {
            guard let enumerator = fileManager.enumerator(atPath: path) else {
                throw ValidationError("Cannot access directory: \(path)")
            }
            
            for case let item as String in enumerator {
                let fullPath = (path as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                   !isDirectory.boolValue,
                   isDICOMFile(fullPath) {
                    files.append(fullPath)
                }
            }
        } else {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for item in contents {
                let fullPath = (path as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                
                if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                   !isDirectory.boolValue,
                   isDICOMFile(fullPath) {
                    files.append(fullPath)
                }
            }
        }
        
        return files
    }
    
    func isDICOMFile(_ path: String) -> Bool {
        // Check file extension first
        let ext = (path as NSString).pathExtension.lowercased()
        if ["dcm", "dicom", "dic"].contains(ext) {
            return true
        }
        
        // Check for DICOM magic bytes
        guard let fileHandle = FileHandle(forReadingAtPath: path),
              let data = try? fileHandle.read(upToCount: dicomHeaderSize) else {
            return false
        }
        
        // DICOM files have "DICM" magic bytes at offset 128 (after preamble)
        if data.count >= dicomHeaderSize {
            let magic = data[dicomPreambleSize..<dicomHeaderSize]
            return magic == dicomMagicBytes
        }
        
        return false
    }
}

// MARK: - Job Command

struct JobCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "job",
        abstract: "Query print job status",
        discussion: """
            Queries the status of a print job using the N-GET service.
            
            Examples:
              dicom-print job pacs://server:11112 --aet APP --job-id 1.2.840...
            """
    )
    
    @Argument(help: "Printer URL (pacs://host:port)")
    var url: String
    
    @Option(name: .long, help: "Local Application Entity Title (calling AE)")
    var aet: String
    
    @Option(name: .long, help: "Remote Application Entity Title (default: ANY-SCP)")
    var calledAet: String = "ANY-SCP"
    
    @Option(name: .long, help: "Print Job SOP Instance UID to query")
    var jobId: String
    
    @Option(name: .long, help: "Connection timeout in seconds (default: 30)")
    var timeout: Int = 30
    
    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose: Bool = false
    
    @Option(name: .long, help: "Output format: text, json (default: text)")
    var format: OutputFormat = .text
    
    mutating func run() throws {
        #if canImport(Network)
        let serverInfo = try parseServerURL(url)
        
        let config = PrintConfiguration(
            host: serverInfo.host,
            port: serverInfo.port,
            callingAETitle: aet,
            calledAETitle: calledAet,
            timeout: TimeInterval(timeout)
        )
        
        if verbose {
            fprintln("Querying print job status...")
            fprintln("  Job ID: \(jobId)")
            fprintln("")
        }
        
        let status = try runAsync {
            try await DICOMPrintService.getPrintJobStatus(
                configuration: config,
                printJobUID: jobId
            )
        }
        
        switch format {
        case .text:
            printJobStatusText(status)
        case .json:
            printJobStatusJSON(status)
        }
        
        #else
        throw ValidationError("Network functionality is not available on this platform")
        #endif
    }
    
    func printJobStatusText(_ status: PrintJobStatus) {
        fprintln("Print Job Status")
        fprintln("================")
        fprintln("Job UID: \(status.printJobUID)")
        fprintln("Status: \(status.executionStatus)")
        if let info = status.executionStatusInfo {
            fprintln("Status Info: \(info)")
        }
        if let creationDate = status.creationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            fprintln("Created: \(formatter.string(from: creationDate))")
        }
    }
    
    func printJobStatusJSON(_ status: PrintJobStatus) {
        var dict: [String: Any] = [
            "jobUID": status.printJobUID,
            "status": status.executionStatus
        ]
        if let info = status.executionStatusInfo { dict["statusInfo"] = info }
        if let creationDate = status.creationDate {
            dict["creationDate"] = ISO8601DateFormatter().string(from: creationDate)
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    }
}

// MARK: - List Printers Command

struct ListPrintersCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-printers",
        abstract: "List configured printers",
        discussion: """
            Lists printers configured in the local configuration file.
            
            Configuration file location:
              macOS: ~/.config/dicomkit/printers.json
              Linux: ~/.config/dicomkit/printers.json
            
            Examples:
              dicom-print list-printers
              dicom-print list-printers --format json
            """
    )
    
    @Option(name: .long, help: "Output format: text, json (default: text)")
    var format: OutputFormat = .text
    
    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose: Bool = false
    
    mutating func run() throws {
        let configManager = PrinterConfigManager()
        let printers = try configManager.loadPrinters()
        
        if printers.isEmpty {
            fprintln("No printers configured.")
            fprintln("")
            fprintln("Add a printer with:")
            fprintln("  dicom-print add-printer --name radiology-printer \\")
            fprintln("      --host 192.168.1.100 --port 11112 --called-ae PRINT_SCP")
            return
        }
        
        switch format {
        case .text:
            printPrintersText(printers)
        case .json:
            printPrintersJSON(printers)
        }
    }
    
    func printPrintersText(_ printers: [SavedPrinterConfig]) {
        fprintln("Configured Printers")
        fprintln("===================")
        fprintln("")
        
        for (index, printer) in printers.enumerated() {
            let defaultMark = printer.isDefault ? " (default)" : ""
            fprintln("[\(index + 1)] \(printer.name)\(defaultMark)")
            fprintln("    Host: \(printer.host):\(printer.port)")
            fprintln("    Called AE: \(printer.calledAETitle)")
            if let callingAE = printer.callingAETitle {
                fprintln("    Calling AE: \(callingAE)")
            }
            fprintln("    Color Mode: \(printer.colorMode)")
            fprintln("")
        }
    }
    
    func printPrintersJSON(_ printers: [SavedPrinterConfig]) {
        let dicts = printers.map { printer -> [String: Any] in
            var dict: [String: Any] = [
                "name": printer.name,
                "host": printer.host,
                "port": printer.port,
                "calledAETitle": printer.calledAETitle,
                "colorMode": printer.colorMode,
                "isDefault": printer.isDefault
            ]
            if let callingAE = printer.callingAETitle {
                dict["callingAETitle"] = callingAE
            }
            return dict
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: dicts, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    }
}

// MARK: - Add Printer Command

struct AddPrinterCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add-printer",
        abstract: "Add a new printer configuration",
        discussion: """
            Adds a new printer to the local configuration file.
            
            Examples:
              dicom-print add-printer --name radiology-printer \\
                  --host 192.168.1.100 --port 11112 --called-ae PRINT_SCP
            
              dicom-print add-printer --name color-printer \\
                  --host 10.0.0.50 --port 11112 --called-ae COLOR_PRINT \\
                  --color color --default
            """
    )
    
    @Option(name: .long, help: "Printer name (identifier)")
    var name: String
    
    @Option(name: .long, help: "Printer hostname or IP address")
    var host: String
    
    @Option(name: .long, help: "Printer DICOM port (default: 11112)")
    var port: Int = 11112
    
    @Option(name: .long, help: "Remote Application Entity Title (called AE)")
    var calledAe: String
    
    @Option(name: .long, help: "Local Application Entity Title (calling AE, optional)")
    var callingAe: String?
    
    @Option(name: .long, help: "Color mode: grayscale, color (default: grayscale)")
    var color: ColorModeOption = .grayscale
    
    @Flag(name: .long, help: "Set as default printer")
    var `default`: Bool = false
    
    mutating func run() throws {
        let configManager = PrinterConfigManager()
        
        let printer = SavedPrinterConfig(
            name: name,
            host: host,
            port: port,
            calledAETitle: calledAe,
            callingAETitle: callingAe,
            colorMode: color.rawValue,
            isDefault: `default`
        )
        
        try configManager.addPrinter(printer)
        
        fprintln("✓ Printer '\(name)' added successfully")
        if `default` {
            fprintln("  Set as default printer")
        }
        fprintln("")
        fprintln("Use with:")
        fprintln("  dicom-print send pacs://\(host):\(port) image.dcm --aet \(callingAe ?? "YOUR_AE")")
    }
}

// MARK: - Remove Printer Command

struct RemovePrinterCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove-printer",
        abstract: "Remove a printer configuration",
        discussion: """
            Removes a printer from the local configuration file.
            
            Examples:
              dicom-print remove-printer --name radiology-printer
            """
    )
    
    @Option(name: .long, help: "Printer name to remove")
    var name: String
    
    mutating func run() throws {
        let configManager = PrinterConfigManager()
        
        try configManager.removePrinter(named: name)
        
        fprintln("✓ Printer '\(name)' removed successfully")
    }
}

// MARK: - Option Types

enum OutputFormat: String, ExpressibleByArgument {
    case text
    case json
}

enum FilmSizeOption: String, ExpressibleByArgument {
    case size8x10 = "8x10"
    case size10x12 = "10x12"
    case size10x14 = "10x14"
    case size11x14 = "11x14"
    case size11x17 = "11x17"
    case size14x14 = "14x14"
    case size14x17 = "14x17"
    case a4
    case a3
    
    var filmSize: FilmSize {
        switch self {
        case .size8x10: return .size8InX10In
        case .size10x12: return .size10InX12In
        case .size10x14: return .size10InX14In
        case .size11x14: return .size11InX14In
        case .size11x17: return .size11InX17In
        case .size14x14: return .size14InX14In
        case .size14x17: return .size14InX17In
        case .a4: return .a4
        case .a3: return .a3
        }
    }
}

enum OrientationOption: String, ExpressibleByArgument {
    case portrait
    case landscape
    
    var orientation: FilmOrientation {
        switch self {
        case .portrait: return .portrait
        case .landscape: return .landscape
        }
    }
}

enum PrintPriorityOption: String, ExpressibleByArgument {
    case low
    case medium
    case high
    
    var printPriority: PrintPriority {
        switch self {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }
}

enum LayoutOption: String, ExpressibleByArgument {
    case layout1x1 = "1x1"
    case layout1x2 = "1x2"
    case layout2x1 = "2x1"
    case layout2x2 = "2x2"
    case layout2x3 = "2x3"
    case layout3x3 = "3x3"
    case layout3x4 = "3x4"
    case layout4x4 = "4x4"
    case layout4x5 = "4x5"
    
    var imageDisplayFormat: String {
        switch self {
        case .layout1x1: return "STANDARD\\1,1"
        case .layout1x2: return "STANDARD\\1,2"
        case .layout2x1: return "STANDARD\\2,1"
        case .layout2x2: return "STANDARD\\2,2"
        case .layout2x3: return "STANDARD\\2,3"
        case .layout3x3: return "STANDARD\\3,3"
        case .layout3x4: return "STANDARD\\3,4"
        case .layout4x4: return "STANDARD\\4,4"
        case .layout4x5: return "STANDARD\\4,5"
        }
    }
}

enum MediumOption: String, ExpressibleByArgument {
    case paper
    case clearFilm = "clear-film"
    case blueFilm = "blue-film"
    
    var mediumType: MediumType {
        switch self {
        case .paper: return .paper
        case .clearFilm: return .clearFilm
        case .blueFilm: return .blueFilm
        }
    }
}

enum ColorModeOption: String, ExpressibleByArgument {
    case grayscale
    case color
}

// MARK: - Printer Configuration Manager

/// Manages local printer configuration file
struct PrinterConfigManager {
    let configPath: String
    
    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        configPath = "\(homeDir)/.config/dicomkit/printers.json"
    }
    
    func loadPrinters() throws -> [SavedPrinterConfig] {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: configPath) else {
            return []
        }
        
        let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
        let decoder = JSONDecoder()
        return try decoder.decode([SavedPrinterConfig].self, from: data)
    }
    
    func savePrinters(_ printers: [SavedPrinterConfig]) throws {
        let fileManager = FileManager.default
        let configDir = (configPath as NSString).deletingLastPathComponent
        
        // Create config directory if needed
        if !fileManager.fileExists(atPath: configDir) {
            try fileManager.createDirectory(atPath: configDir, withIntermediateDirectories: true)
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(printers)
        try data.write(to: URL(fileURLWithPath: configPath))
    }
    
    func addPrinter(_ printer: SavedPrinterConfig) throws {
        var printers = try loadPrinters()
        
        // Check for duplicate name
        if printers.contains(where: { $0.name == printer.name }) {
            throw ValidationError("Printer with name '\(printer.name)' already exists")
        }
        
        // If setting as default, unset other defaults
        if printer.isDefault {
            printers = printers.map { p in
                var modified = p
                modified.isDefault = false
                return modified
            }
        }
        
        printers.append(printer)
        try savePrinters(printers)
    }
    
    func removePrinter(named name: String) throws {
        var printers = try loadPrinters()
        
        guard printers.contains(where: { $0.name == name }) else {
            throw ValidationError("Printer with name '\(name)' not found")
        }
        
        printers.removeAll { $0.name == name }
        try savePrinters(printers)
    }
}

/// Saved printer configuration
struct SavedPrinterConfig: Codable {
    var name: String
    var host: String
    var port: Int
    var calledAETitle: String
    var callingAETitle: String?
    var colorMode: String
    var isDefault: Bool
}

// MARK: - Helper Functions

func parseServerURL(_ urlString: String) throws -> (scheme: String, host: String, port: UInt16) {
    guard let url = URL(string: urlString) else {
        throw ValidationError("Invalid URL: \(urlString)")
    }
    
    guard let scheme = url.scheme, scheme == "pacs" else {
        throw ValidationError("URL must use pacs:// scheme")
    }
    
    guard let host = url.host else {
        throw ValidationError("URL must include a hostname")
    }
    
    let port: UInt16
    if let urlPort = url.port {
        port = UInt16(urlPort)
    } else {
        port = 11112 // Default DICOM print port
    }
    
    return (scheme, host, port)
}

/// Prints to stderr
func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}

// MARK: - Main Entry Point

DICOMPrint.main()
