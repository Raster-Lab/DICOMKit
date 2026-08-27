import Foundation
import ArgumentParser
import DICOMCore
import DICOMKit
import DICOMNetwork
// Shared print core: image preparation, job options, workflow orchestration,
// and console formatting — the same code paths DICOMStudio's print screen uses.
import DICOMPrintKit

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

              # A scout over its slices: one image in the top row, three beneath
              dicom-print send pacs://server:11112 *.dcm --aet APP --layout 'ROW\\1,3'
            
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
            try await PrintWorkflow.printerStatus(configuration: config)
        }

        // Output is rendered by the shared formatter so the terminal and the
        // DICOMStudio print console stay identical.
        switch format {
        case .text:
            PrintConsoleFormatter.printerStatusText(status).forEach(fprintln)
        case .json:
            if let json = PrintConsoleFormatter.printerStatusJSON(status) {
                print(json)
            }
        }

        #else
        throw ValidationError("Network functionality is not available on this platform")
        #endif
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

              # A scout over its slices: one image in the top row, three beneath
              dicom-print send pacs://server:11112 *.dcm --aet APP --layout 'ROW\\1,3'
            
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
    
    @Option(name: .long, help: "Image layout: a grid (1x1 to 4x5) or an Image Display Format ('ROW\\2,1,2', 'COL\\1,2' — quote it, the shell eats backslashes); auto if not specified")
    var layout: LayoutOption?

    @Option(name: .long, help: "Layout preset: single, comparison, grid, multi-phase (sets layout + film size + orientation; conflicts with --layout)")
    var template: TemplateOption?

    @Option(name: .long, help: "Medium type: paper, clear-film, blue-film (default: paper)")
    var medium: MediumOption = .paper

    @Option(name: .long, help: "Magnification type: replicate, bilinear, cubic, none (default: replicate)")
    var magnification: MagnificationOption = .replicate

    @Option(name: .long, help: "Film destination: magazine, processor, bin-1, bin-2 (default: processor)")
    var filmDestination: FilmDestinationOption = .processor

    @Flag(name: .long, help: "Query printer status before printing; abort on FAILURE, warn on WARNING")
    var checkStatus: Bool = false

    @Flag(name: .customLong("verify"), help: "Perform a C-ECHO connectivity check against the printer before printing")
    var verifyFirst: Bool = false

    @Option(name: .long, help: "Output format: text, json (json writes the result object to stdout; diagnostics stay on stderr)")
    var format: OutputFormat = .text

    @Option(name: .long, help: "Color mode: grayscale, color (default: grayscale)")
    var color: ColorModeOption = .grayscale

    @Option(name: .long, help: "1-based frame to print from multi-frame files (default: 1)")
    var frame: Int = 1

    @Flag(name: .long, help: "Print every frame of multi-frame files (one image box per frame)")
    var allFrames: Bool = false

    @Flag(name: .long, help: "Send stored pixel values without preprocessing (no rescale/window/inversion). Compressed sources are still decoded.")
    var raw: Bool = false

    @Option(name: .long, help: "Explicit VOI window center (requires --window-width; overrides the data set's window)")
    var windowCenter: Double?

    @Option(name: .long, help: "Explicit VOI window width (requires --window-center)")
    var windowWidth: Double?

    @Option(name: .long, help: "Grayscale output bit depth: 8 or 12 (default: 8). PS3.3 Table C.13-3 allows Bits Stored of 8 or 12 only; 12 sends 12-in-16 P-Values. A higher value is clamped, not refused.")
    var bitDepth: Int = 8

    @Option(name: .long, help: "Presentation LUT shape: identity, inverse, lin-od (default: none)")
    var presentationLut: PresentationLUTOption?

    @Option(name: .long, help: ArgumentHelp(
        "Pseudo-colour palette baked into the pixels (default: none, grayscale).",
        discussion: PaletteOption.discussion))
    var palette: PaletteOption?

    @Option(name: .long, help: "Annotation text to place on the film (repeatable; position is order given). Requires --annotation-format.")
    var annotate: [String] = []

    @Option(name: .long, help: "Printer-configured Annotation Display Format ID (required with --annotate)")
    var annotationFormat: String?

    @Flag(name: .shortAndLong, help: "Recursively scan directories for DICOM files")
    var recursive: Bool = false
    
    @Flag(name: .long, help: "Show what would be printed without actually printing")
    var dryRun: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show verbose output with progress")
    var verbose: Bool = false
    
    @Option(name: .long, help: "Connection timeout in seconds (default: 60)")
    var timeout: Int = 60

    @Option(name: .long, help: "Retry the print on connection/setup failure, up to N times with exponential backoff (default: 0)")
    var retries: Int = 0

    mutating func run() throws {
        #if canImport(Network)
        let serverInfo = try parseServerURL(url)

        // Argument-surface checks (they name flags that only exist here);
        // everything expressible on the request itself is validated by the
        // shared PrintJobRequest.validate() below, with identical wording.
        if template != nil && layout != nil {
            throw ValidationError("--template and --layout are mutually exclusive; --template sets the layout")
        }
        if allFrames && frame != 1 {
            throw ValidationError("--frame and --all-frames are mutually exclusive")
        }
        if (windowCenter == nil) != (windowWidth == nil) {
            throw ValidationError("--window-center and --window-width must be given together")
        }

        // Build annotations (position follows the order given on the command line).
        let printAnnotations = annotate.enumerated().map { index, text in
            PrintAnnotation(position: UInt16(index + 1), text: text)
        }

        // One shared description of the job — the same value type the
        // DICOMStudio print sheet builds from its controls.
        let request = PrintJobRequest(
            copies: copies,
            priority: priority.printPriority,
            mediumType: medium.mediumType,
            filmDestination: filmDestination.filmDestination,
            layoutSelection: {
                if let template { return .template(template.preset) }
                if let layout { return layout.selection }
                return .automatic
            }(),
            filmSize: filmSize.filmSize,
            filmOrientation: orientation.orientation,
            magnificationType: magnification.magnificationType,
            presentationLUTShape: presentationLut?.shape,
            annotations: printAnnotations,
            annotationDisplayFormatID: annotationFormat,
            colorMode: color.printColorMode,
            frameSelection: allFrames ? .all : .single(frame),
            raw: raw,
            windowSettings: {
                guard let center = windowCenter, let width = windowWidth else { return nil }
                return WindowSettings(center: center, width: width)
            }(),
            bitDepth: bitDepth,
            palette: palette?.palette,
            verifyFirst: verifyFirst,
            checkStatus: checkStatus,
            retries: retries,
            dryRun: dryRun
        )
        do {
            try request.validate()
        } catch let error as PrintRequestError {
            throw ValidationError(error.message)
        }

        let effectiveFilmSize = request.effectiveFilmSize
        let effectiveOrientation = request.effectiveFilmOrientation

        let config = PrintConfiguration(
            host: serverInfo.host,
            port: serverInfo.port,
            callingAETitle: aet,
            calledAETitle: calledAet,
            timeout: TimeInterval(timeout),
            colorMode: color.printColorMode
        )

        if verbose {
            fprintln("DICOM Print Tool v\(toolVersion)")
            fprintln("=======================")
            fprintln("Server: \(serverInfo.host):\(serverInfo.port)")
            fprintln("Calling AE: \(aet)")
            fprintln("Called AE: \(calledAet)")
            fprintln("Copies: \(copies)")
            fprintln("Film Size: \(effectiveFilmSize.rawValue)")
            fprintln("Orientation: \(effectiveOrientation.rawValue)")
            fprintln("Priority: \(priority.printPriority.rawValue)")
            fprintln("Medium: \(medium.mediumType.rawValue)")
            fprintln("Color Mode: \(color.printColorMode.rawValue)")
            if let presentationLut = presentationLut {
                fprintln("Presentation LUT: \(presentationLut.shape.rawValue)")
            }
            if let palette = palette?.palette, !palette.isGrayscale {
                // The UID when the standard defines one: it is the only durable
                // name for the palette, and the film itself cannot carry it.
                let identity = palette.wellKnownSOPInstanceUID.map { " [\($0)]" } ?? ""
                fprintln("Palette: \(palette.displayName)\(identity)")
                fprintln("  Colour prints at 8-bit RGB; --bit-depth applies to "
                       + "grayscale film only.")
            }
            if !printAnnotations.isEmpty, let fmt = annotationFormat {
                fprintln("Annotations: \(printAnnotations.count) (format \(fmt))")
            }
            if let template = template {
                fprintln("Template: \(template.rawValue)")
            }
            if let layout = layout {
                fprintln("Layout: \(layout.rawValue)")
            }
            if retries > 0 {
                fprintln("Retries: \(retries)")
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
        
        // Pre-flight checks, image preparation, and the print itself all run
        // through the shared print core (DICOMPrintKit) — the same code the
        // DICOMStudio print screen calls.
        let printRequest = request
        let printConfig = config
        let beVerbose = verbose

        // Diagnostics: verbose-only detail is gated here; notices, warnings,
        // and printer events (N-EVENT-REPORT) are always shown.
        let diagnostics: PrintWorkflow.DiagnosticHandler = { diagnostic in
            switch diagnostic {
            case .info(let message):
                if beVerbose { fprintln(message) }
            case .notice(let message):
                fprintln(message)
            case .warning(let message):
                fprintln(message)
            case .event(let event):
                if event.isFault {
                    fprintln("⚠ \(event.summary)")
                } else if beVerbose {
                    fprintln("• \(event.summary)")
                }
            }
        }

        do {
            try runAsync {
                try await PrintWorkflow.preflight(
                    configuration: printConfig,
                    request: printRequest,
                    diagnostics: diagnostics
                )
            }
        } catch let error as PrintRequestError {
            throw ValidationError(error.message)
        } catch is PrintWorkflowError {
            // The explanatory line was already emitted by the diagnostics hook.
            throw ExitCode.failure
        }

        // Read, decode, and prepare files for printing.
        //
        // - Encapsulated sources (JPEG/J2K/JPEG-LS/RLE) are decoded to native
        //   frames — Basic Grayscale/Color Image Boxes require uncompressed
        //   pixel data (PS3.3 C.13.5).
        // - --frame / --all-frames select frames from multi-frame files; each
        //   selected frame becomes one image box.
        // - Unless --raw, each frame runs through ImagePreprocessor (rescale →
        //   VOI window → MONOCHROME1 inversion → 8-bit MONOCHROME2, or 8-bit
        //   RGB/grayscale for color sources) so the print matches clinical
        //   presentation instead of raw stored values.
        let inputFiles = filesToPrint
        let images: [PreparedPrintImage]
        do {
            images = try runAsync {
                try await PrintImagePreparer().prepare(
                    paths: inputFiles,
                    request: printRequest,
                    onProgress: { line in if beVerbose { fprintln(line) } }
                )
            }
        } catch let error as PrintRequestError {
            throw ValidationError(error.message)
        }

        if verbose {
            fprintln("Printing \(images.count) image(s)...")
            let plan = printRequest.plan(forImageCount: images.count)
            if plan.filmCount > 1 {
                fprintln(PrintConsoleFormatter.planSummary(plan))
            }
        }

        let result: PrintResult
        do {
            result = try runAsync {
                try await PrintWorkflow.execute(
                    configuration: printConfig,
                    request: printRequest,
                    images: images,
                    diagnostics: diagnostics
                )
            }
        } catch let error as PrintRequestError {
            throw ValidationError(error.message)
        }

        // Output contract (P3-2): machine-readable result on stdout in JSON
        // mode; human-readable text and diagnostics always on stderr.
        switch format {
        case .text:
            PrintConsoleFormatter.printResultText(result).forEach(fprintln)
        case .json:
            if let json = PrintConsoleFormatter.printResultJSON(result) {
                print(json)
            }
        }

        // Automation contract: a failed print must exit non-zero. The message
        // was already emitted above, so exit silently with failure.
        if !result.success {
            throw ExitCode.failure
        }

        #else
        throw ValidationError("Network functionality is not available on this platform")
        #endif
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
        
        let printJobUID = jobId
        let status = try runAsync {
            try await PrintWorkflow.jobStatus(
                configuration: config,
                printJobUID: printJobUID
            )
        }

        switch format {
        case .text:
            PrintConsoleFormatter.jobStatusText(status).forEach(fprintln)
        case .json:
            if let json = PrintConsoleFormatter.jobStatusJSON(status) {
                print(json)
            }
        }

        #else
        throw ValidationError("Network functionality is not available on this platform")
        #endif
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
    case size8_5x11 = "8.5x11"
    case size10x12 = "10x12"
    case size10x14 = "10x14"
    case size11x14 = "11x14"
    case size11x17 = "11x17"
    case size14x14 = "14x14"
    case size14x17 = "14x17"
    case size24x24cm = "24x24cm"
    case size24x30cm = "24x30cm"
    case a4
    case a3

    var filmSize: FilmSize {
        switch self {
        case .size8x10: return .size8InX10In
        case .size8_5x11: return .size8_5InX11In
        case .size10x12: return .size10InX12In
        case .size10x14: return .size10InX14In
        case .size11x14: return .size11InX14In
        case .size11x17: return .size11InX17In
        case .size14x14: return .size14InX14In
        case .size14x17: return .size14InX17In
        case .size24x24cm: return .size24CmX24Cm
        case .size24x30cm: return .size24CmX30Cm
        case .a4: return .a4
        case .a3: return .a3
        }
    }
}

enum MagnificationOption: String, ExpressibleByArgument {
    case replicate
    case bilinear
    case cubic
    case none

    var magnificationType: MagnificationType {
        switch self {
        case .replicate: return .replicate
        case .bilinear: return .bilinear
        case .cubic: return .cubic
        case .none: return MagnificationType.none
        }
    }
}

enum FilmDestinationOption: String, ExpressibleByArgument {
    case magazine
    case processor
    case bin1 = "bin-1"
    case bin2 = "bin-2"

    var filmDestination: FilmDestination {
        switch self {
        case .magazine: return .magazine
        case .processor: return .processor
        case .bin1: return .bin1
        case .bin2: return .bin2
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

/// A `--layout` argument: a grid token from the shared catalogue ("2x3"), or an
/// Image Display Format (2010,0010) as PS3.3 C.13.3 writes one.
///
/// The format forms are how the standard states a film whose rows hold different
/// numbers of images — `ROW\1,2` is one image over two — which no rows × columns
/// token can name.
struct LayoutOption: ExpressibleByArgument {
    /// What was typed, echoed back in the run banner.
    let rawValue: String

    /// The layout the job is built with.
    let selection: PrintLayoutSelection

    init?(argument: String) {
        rawValue = argument
        if let option = PrintLayoutOption(rawValue: argument.lowercased()) {
            selection = .explicit(option)
        } else if let format = PrintImageDisplayFormat.validated(argument) {
            selection = .displayFormat(format)
        } else {
            return nil
        }
    }

    static var allValueStrings: [String] {
        // The same two catalogues the print sheet's gallery offers.
        PrintLayoutOption.allCases.map(\.rawValue)
            + PrintBandLayout.allCases.map(\.imageDisplayFormat)
    }
}

/// A pseudo-colour palette named on the command line.
///
/// The cases are not written out: they are the shared
/// ``DICOMCore/PseudoColorPalette``, lower-cased and hyphenated, so the CLI
/// cannot come to disagree with the app about which palettes exist or what they
/// are called. Adding a palette to the shared type adds it here.
struct PaletteOption: ExpressibleByArgument {
    let palette: PseudoColorPalette

    /// `HOT_METAL_BLUE` → `hot-metal-blue`.
    static func token(for palette: PseudoColorPalette) -> String {
        palette.rawValue.lowercased().replacingOccurrences(of: "_", with: "-")
    }

    init?(argument: String) {
        let wanted = argument.lowercased()
        guard let match = PseudoColorPalette.allCases.first(where: {
            Self.token(for: $0) == wanted
        }) else { return nil }
        self.palette = match
    }

    /// The palettes, grouped, for `--help`. Grouped for the same reason the
    /// picker is: the DICOM heading is a promise the others cannot make.
    static var discussion: String {
        PseudoColorPalette.catalog.map { entry in
            let names = entry.palettes.map(token(for:)).joined(separator: ", ")
            return "\(entry.group.title): \(names)"
        }.joined(separator: "\n")
        + "\n\nColour is baked into 8-bit RGB before sending: DICOM Print "
        + "Management cannot name a palette to a printer (PS3.3 Table C.13-5 "
        + "allows only RGB in a Basic Color Image Sequence). --bit-depth and a "
        + "lin-od presentation LUT therefore apply to grayscale film only."
    }
}

enum PresentationLUTOption: String, ExpressibleByArgument {
    case identity
    case inverse
    case linOD = "lin-od"

    var shape: PresentationLUTShape {
        switch self {
        case .identity: return .identity
        case .inverse: return .inverseRendered
        case .linOD: return .linearOpticalDensity
        }
    }
}

enum TemplateOption: String, ExpressibleByArgument {
    case single
    case comparison
    case grid
    case multiPhase = "multi-phase"

    /// The shared preset this argument maps to (same raw values).
    var preset: PrintTemplatePreset {
        PrintTemplatePreset(rawValue: rawValue) ?? .single
    }

    /// The built-in `PrintTemplate` this option maps to.
    var template: PrintTemplate { preset.template }

    /// The image layout (rows × columns) for this template.
    var printLayout: PrintLayout { preset.layout }
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

    var printColorMode: DICOMNetwork.PrintColorMode {
        switch self {
        case .grayscale: return .grayscale
        case .color: return .color
        }
    }

    /// The DICOMKit-side color mode used by ImagePreprocessor (a distinct type
    /// from DICOMNetwork.PrintColorMode, resolved here to avoid ambiguity).
    var preprocessColorMode: DICOMKit.PrintColorMode {
        switch self {
        case .grayscale: return .grayscale
        case .color: return .color
        }
    }
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
        // UInt16(urlPort) would trap on out-of-range values (P2-5).
        guard let validPort = UInt16(exactly: urlPort), validPort > 0 else {
            throw ValidationError("Port \(urlPort) is out of range (1-65535)")
        }
        port = validPort
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
