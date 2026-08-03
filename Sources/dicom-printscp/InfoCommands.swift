//
// InfoCommands.swift
// dicom-printscp
//
// `status` and `queues` — the two questions that do not need a listener.
//

import Foundation
import ArgumentParser
import DICOMPrintKit

// MARK: - status

/// Reports what the emulator would answer an SCU's N-GET with, without binding
/// a port — so a configuration can be checked before a modality is pointed at it.
struct StatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show the printer identity and status the emulator would report",
        discussion: """
            Answers the same question `dicom-print status` asks over the network,
            from the configuration alone. Useful for checking a --config file, and
            for confirming what --printer-status failure will make an SCU see.
            """
    )

    @OptionGroup var transport: TransportOptions
    @OptionGroup var composition: CompositionOptions
    @OptionGroup var filmOutput: FilmOutputOptions
    @OptionGroup var configOptions: ConfigOptions

    @Option(name: .long, help: "Output format: text, json")
    var format: OutputFormat = .text

    @Flag(name: .shortAndLong, help: "Show the full resolved configuration")
    var verbose: Bool = false

    func run() async throws {
        var settings = configOptions.load()
        try transport.apply(to: &settings)
        try composition.apply(to: &settings)
        try filmOutput.apply(to: &settings, outputWasConfigured: configOptions.hasStoredSettings)

        let console = Console(format: format, quiet: false)

        if configOptions.saveConfig {
            try configOptions.save(settings)
            console.line("Wrote \(configOptions.url.path)")
            return
        }

        switch format {
        case .text:
            console.lines(PrintSCPConsole.printerStatusText(settings: settings))
            if verbose {
                console.line("")
                console.lines(PrintSCPConsole.startupSummary(
                    settings: settings, boundPort: UInt16(clamping: settings.port)))
            }
        case .json:
            if verbose {
                let data = try PrintSCPSettingsFile.encode(settings)
                console.line(String(decoding: data, as: UTF8.self))
            } else if let json = PrintSCPConsole.printerStatusJSON(settings: settings) {
                console.line(json)
            }
        }
    }
}

// MARK: - queues

/// Lists the CUPS queues `--paper-queue` can name.
struct QueuesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "queues",
        abstract: "List the paper printer queues available for --paper-queue"
    )

    @Option(name: .long, help: "Output format: text, json")
    var format: OutputFormat = .text

    func run() async throws {
        let queues = PrintSCPService().availablePaperQueues()
        let console = Console(format: format, quiet: false)

        switch format {
        case .text:
            console.lines(PrintSCPConsole.queuesText(queues))
        case .json:
            if let json = PrintSCPConsole.queuesJSON(queues) { console.line(json) }
        }
    }
}
