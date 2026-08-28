//
// EmulatorOptions.swift
// dicom-printscp
//
// Flags → `PrintSCPSettings`.
//
// Every option is optional: a flag that was not given leaves whatever `--config`
// (or the built-in default) already holds, so a stored configuration and a
// command line compose instead of one silently erasing the other. The settings
// type itself, and every default in it, is the shared one DICOM Studio fills in
// from its own configuration sheet.
//
// Three groups, because `serve` needs all of them and `simulate` — which never
// touches the network — needs only composition and output.
//

import Foundation
import ArgumentParser
import DICOMPrintKit

// MARK: - Transport and negotiated capability

/// What the emulator presents to the network, and what it agrees to accept.
struct TransportOptions: ParsableArguments {

    @Option(name: .long, help: "TCP port to listen on (default: 11113)")
    var port: Int?

    @Option(name: .long, help: "AE title the emulator answers as (default: DCMPRINT)")
    var aeTitle: String?

    @Option(name: .long, help: "Maximum concurrent associations (default: 10)")
    var maxAssociations: Int?

    @Option(name: .long, help: "Seconds an idle association may sit before it is aborted; 0 disables (default: 300)")
    var idleTimeout: Double?

    @Option(name: .long, help: "Calling AE title to accept (repeatable; default: accept all)")
    var allowAe: [String] = []

    @Option(name: .long, help: "Calling AE title to refuse (repeatable; takes precedence over --allow-ae)")
    var denyAe: [String] = []

    @Option(name: .long, help: "Maximum PDU size accepted during negotiation, in bytes (default: 65536)")
    var maxPdu: Int?

    @Flag(name: .customLong("accept-color"), inversion: .prefixedNo,
          help: "Accept the Color Print Management Meta SOP Class (default: yes)")
    var acceptColor: Bool?

    @Flag(name: .customLong("presentation-lut"), inversion: .prefixedNo,
          help: "Accept Presentation LUT N-CREATE (default: yes)")
    var presentationLUT: Bool?

    @Flag(name: .customLong("annotation-box"), inversion: .prefixedNo,
          help: "Accept Basic Annotation Box N-CREATE / N-SET (default: yes)")
    var annotationBox: Bool?

    @Option(name: .long, help: "Annotation boxes offered per film box (default: 6)")
    var annotationBoxesPerFilm: Int?

    @Flag(name: .long, help: "Push Print Job N-EVENT-REPORTs after N-ACTION")
    var pushJobEvents: Bool = false

    @Option(name: .long,
            help: "Film size to accept (repeatable; default: all). Values: \(OptionTokens.filmSizes)")
    var filmSize: [String] = []

    @Option(name: .long,
            help: "Medium type to accept (repeatable; default: all). Values: \(OptionTokens.media)")
    var medium: [String] = []

    @Option(name: .long, help: "Maximum image boxes a film box may declare (default: 64)")
    var maxImageBoxes: Int?

    @Option(name: .long, help: "Largest image dimension accepted in an image box, in pixels (default: 10000)")
    var maxImageDimension: Int?

    // MARK: Reported identity (N-GET on the Printer SOP Instance)

    @Option(name: .long, help: "Printer Name (2110,0030)")
    var printerName: String?

    @Option(name: .long, help: "Manufacturer (0008,0070)")
    var manufacturer: String?

    @Option(name: .long, help: "Manufacturer Model Name (0008,1090)")
    var model: String?

    @Option(name: .long, help: "Device Serial Number (0018,1000)")
    var serialNumber: String?

    @Option(name: .long, help: "Software Version (0018,1020)")
    var softwareVersion: String?

    @Option(name: .long,
            help: "Printer Status (2110,0010) reported to N-GET: \(OptionTokens.printerStatuses)")
    var printerStatus: String?

    @Option(name: .long, help: "Printer Status Info (2110,0020); empty uses the status's own text")
    var statusInfo: String?

    /// Applies the flags that were given.
    func apply(to settings: inout PrintSCPSettings) throws {
        if let port { settings.port = port }
        if let aeTitle { settings.aeTitle = aeTitle }
        if let maxAssociations { settings.maxConcurrentAssociations = maxAssociations }
        if let idleTimeout { settings.associationIdleTimeoutSeconds = idleTimeout }
        if !allowAe.isEmpty { settings.allowedCallingAETitles = allowAe.joined(separator: ",") }
        if !denyAe.isEmpty { settings.deniedCallingAETitles = denyAe.joined(separator: ",") }
        if let maxPdu { settings.maxPDUSize = maxPdu }

        if let acceptColor { settings.supportsColor = acceptColor }
        if let presentationLUT { settings.acceptPresentationLUT = presentationLUT }
        if let annotationBox { settings.acceptAnnotationBox = annotationBox }
        if let annotationBoxesPerFilm { settings.annotationBoxesPerFilm = annotationBoxesPerFilm }
        if pushJobEvents { settings.pushPrintJobEvents = true }
        if !filmSize.isEmpty {
            settings.supportedFilmSizeTokens = try filmSize.map {
                try OptionTokens.validate($0, in: PrintOptionCatalog.filmSizes.map(\.cliToken), flag: "--film-size")
            }
        }
        if !medium.isEmpty {
            settings.supportedMediumTokens = try medium.map {
                try OptionTokens.validate($0, in: PrintOptionCatalog.mediumTypes.map(\.cliToken), flag: "--medium")
            }
        }
        if let maxImageBoxes { settings.maxImageBoxesPerFilm = maxImageBoxes }
        if let maxImageDimension { settings.maxImageBoxPixelDimension = maxImageDimension }

        if let printerName { settings.printerName = printerName }
        if let manufacturer { settings.manufacturer = manufacturer }
        if let model { settings.manufacturerModelName = model }
        if let serialNumber { settings.deviceSerialNumber = serialNumber }
        if let softwareVersion { settings.softwareVersion = softwareVersion }
        if let printerStatus {
            let token = try OptionTokens.validate(
                printerStatus,
                in: PrintOptionCatalog.emulatedPrinterStatuses.map(\.cliToken),
                flag: "--printer-status")
            settings.printerStatus = PrintOptionCatalog.emulatedPrinterStatus(forToken: token) ?? .normal
        }
        if let statusInfo { settings.printerStatusInfo = statusInfo }
    }
}

// MARK: - Composition

/// How a received film is turned into a sheet.
struct CompositionOptions: ParsableArguments {

    @Option(name: .long, help: "Rasterization resolution of the composed sheet (default: 300)")
    var dpi: Double?

    @Option(name: .long, help: "Density interpretation: \(OptionTokens.densities) (default: paper)")
    var density: String?

    @Option(name: .long, help: "Sheet margin in millimetres (default: 5)")
    var marginMm: Double?

    @Option(name: .long, help: "Gap between image cells in millimetres (default: 2)")
    var cellSpacingMm: Double?

    @Flag(name: .customLong("annotations"), inversion: .prefixedNo,
          help: "Draw Basic Annotation Box text on the sheet (default: yes)")
    var annotations: Bool?

    @Flag(name: .customLong("trim-marks"), inversion: .prefixedNo,
          help: "Draw crop marks when Trim (2010,0140) is YES (default: yes)")
    var trimMarks: Bool?

    @Option(name: .long, help: "Cap on the composed bitmap's longest side, in pixels (default: 12000)")
    var maxPixels: Int?

    func apply(to settings: inout PrintSCPSettings) throws {
        if let dpi { settings.dpi = dpi }
        if let density {
            let token = try OptionTokens.validate(
                density,
                in: PrintOptionCatalog.densityMappings.map(\.cliToken),
                flag: "--density")
            settings.densityMapping = PrintOptionCatalog.densityMapping(forToken: token) ?? .paperDirect
        }
        if let marginMm { settings.marginMillimeters = marginMm }
        if let cellSpacingMm { settings.cellSpacingMillimeters = cellSpacingMm }
        if let annotations { settings.drawAnnotations = annotations }
        if let trimMarks { settings.drawTrimMarks = trimMarks }
        if let maxPixels { settings.maximumPixelDimension = maxPixels }
    }
}

// MARK: - Output

/// Where composed films go.
struct FilmOutputOptions: ParsableArguments {

    @Option(name: .long, help: "Film output: \(OptionTokens.outputs) (repeatable)")
    var output: [String] = []

    @Option(name: .long, help: "Directory written films are saved to (default: ~/Downloads/DICOMKit Films)")
    var outputDir: String?

    @Option(name: .long, help: "File-name pattern; tokens {job} {session} {film} {ae} {index} {timestamp}")
    var namePattern: String?

    @Option(name: .long,
            help: "Spool film to this CUPS queue (requires --allow-paper; empty uses the system default queue)")
    var paperQueue: String?

    @Flag(name: .long, help: "Enable paper spooling. Required for --paper-queue to have any effect.")
    var allowPaper: Bool = false

    @Flag(name: .long, help: "Open each written film in the default viewer")
    var open: Bool = false

    /// Applies the flags that were given.
    ///
    /// - Parameters:
    ///   - defaultOutput: What to write when neither `--output` nor a stored
    ///     configuration selects anything. Both subcommands pass `png`: a tool
    ///     that receives film and silently discards it is not useful.
    ///   - outputWasConfigured: Whether a stored configuration was loaded, in
    ///     which case its output selection stands rather than the default.
    func apply(
        to settings: inout PrintSCPSettings,
        defaultOutput: String? = nil,
        outputWasConfigured: Bool = false
    ) throws {
        if let outputDir { settings.outputDirectory = outputDir }
        if let namePattern { settings.fileNamePattern = namePattern }

        let selected = output.isEmpty
            ? (outputWasConfigured ? [] : [defaultOutput].compactMap { $0 })
            : output
        if !selected.isEmpty {
            settings.savePDF = false
            settings.saveImage = false
            for value in selected {
                switch try OptionTokens.validate(value, in: ["png", "tiff", "pdf", "none"], flag: "--output") {
                case "png":
                    settings.saveImage = true
                    settings.imageFormat = .png
                case "tiff":
                    settings.saveImage = true
                    settings.imageFormat = .tiff
                case "pdf":
                    settings.savePDF = true
                default:
                    break
                }
            }
        }

        // Paper output is opt-in by construction: naming a queue is not consent
        // to spool hundreds of pages, so the gate is the flag.
        if let paperQueue { settings.paperQueue = paperQueue }
        settings.sendToPaperQueue = allowPaper
        if paperQueue != nil, !allowPaper {
            throw PrintSCPCommandError(
                "--paper-queue needs --allow-paper; refusing to spool to a real printer by accident")
        }
    }
}

// MARK: - Token help and validation

/// Token lists and checking, all derived from the shared option catalog so the
/// help text cannot drift from what the library accepts.
enum OptionTokens {
    static var filmSizes: String { PrintOptionCatalog.filmSizes.map(\.cliToken).joined(separator: ", ") }
    static var media: String { PrintOptionCatalog.mediumTypes.map(\.cliToken).joined(separator: ", ") }
    static var densities: String { PrintOptionCatalog.densityMappings.map(\.cliToken).joined(separator: ", ") }
    static var orientations: String { PrintOptionCatalog.orientations.map(\.cliToken).joined(separator: ", ") }
    static var magnifications: String { PrintOptionCatalog.magnificationTypes.map(\.cliToken).joined(separator: ", ") }
    static var polarities: String { PrintOptionCatalog.polarities.map(\.cliToken).joined(separator: ", ") }
    static var presentationLUTShapes: String {
        PrintOptionCatalog.presentationLUTShapes.map(\.cliToken).joined(separator: ", ")
    }
    static var colorModes: String { PrintOptionCatalog.colorModes.map(\.cliToken).joined(separator: ", ") }
    static var layouts: String { PrintLayoutOption.allCases.map(\.rawValue).joined(separator: ", ") }
    static var printerStatuses: String {
        PrintOptionCatalog.emulatedPrinterStatuses.map(\.cliToken).joined(separator: ", ")
    }
    static let outputs = "png, tiff, pdf, none"

    /// Lower-cases and checks one token, naming the valid ones on failure.
    @discardableResult
    static func validate(_ value: String, in allowed: [String], flag: String) throws -> String {
        let token = value.lowercased()
        guard allowed.contains(token) else {
            throw PrintSCPCommandError(
                "Invalid \(flag) value '\(value)'. Valid values: \(allowed.joined(separator: ", "))")
        }
        return token
    }
}

// MARK: - Configuration file

/// `--config` handling, shared by every subcommand that takes settings.
struct ConfigOptions: ParsableArguments {

    @Option(name: .long, help: "Settings file to read (default: ~/.config/dicomkit/printscp.json when it exists)")
    var config: String?

    @Flag(name: .long, help: "Write the resolved settings back to the configuration file and exit")
    var saveConfig: Bool = false

    /// The default location, a sibling of `dicom-print`'s `printers.json`.
    static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/dicomkit/printscp.json")
    }

    /// The file this invocation reads and writes.
    var url: URL {
        guard let config, !config.isEmpty else { return Self.defaultURL }
        return URL(fileURLWithPath: (config as NSString).expandingTildeInPath)
    }

    /// Whether a stored configuration exists to read.
    var hasStoredSettings: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// The stored settings, or the defaults when there is no file.
    func load() -> PrintSCPSettings {
        hasStoredSettings ? PrintSCPSettingsFile.read(from: url) : PrintSCPSettings()
    }

    /// Writes settings back to the configuration file.
    func save(_ settings: PrintSCPSettings) throws {
        try PrintSCPSettingsFile.write(settings, to: url)
    }
}
