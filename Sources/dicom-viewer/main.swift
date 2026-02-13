import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

struct DICOMViewer: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-viewer",
        abstract: "View DICOM images directly in the terminal",
        discussion: """
            Display DICOM images using ASCII art, ANSI colors, or terminal graphics
            protocols (iTerm2, Kitty, Sixel) for quick image inspection and triage.
            
            Examples:
              dicom-viewer scan.dcm
              dicom-viewer scan.dcm --mode ascii --quality high
              dicom-viewer scan.dcm --mode ansi --color 24bit
              dicom-viewer ct.dcm --window-center -600 --window-width 1500
              dicom-viewer scan.dcm --show-info
              dicom-viewer series/*.dcm --thumbnail
            """,
        version: "1.4.0"
    )

    @Argument(help: "Path(s) to DICOM file(s)")
    var filePaths: [String]

    @Option(name: .shortAndLong, help: "Display mode: ascii, ansi, iterm2, kitty, sixel")
    var mode: DisplayMode = .ascii

    @Option(name: .long, help: "ASCII art quality: low, high (default: high)")
    var quality: AsciiQuality = .high

    @Option(name: .long, help: "ANSI color depth: 256, 24bit (default: 24bit)")
    var color: ANSIColorDepth = .truecolor

    @Option(name: .long, help: "Window center (level) for display")
    var windowCenter: Double?

    @Option(name: .long, help: "Window width for display")
    var windowWidth: Double?

    @Option(name: .long, help: "Frame number to display (0-based, default: 0)")
    var frame: Int = 0

    @Option(name: .long, help: "Output width in characters")
    var width: Int?

    @Option(name: .long, help: "Output height in characters")
    var height: Int?

    @Flag(name: .long, help: "Invert pixel values")
    var invert: Bool = false

    @Flag(name: .long, help: "Show patient and study information overlay")
    var showInfo: Bool = false

    @Flag(name: .long, help: "Show overlays and annotations")
    var showOverlay: Bool = false

    @Flag(name: .long, help: "Display as thumbnail grid (for multiple files or frames)")
    var thumbnail: Bool = false

    @Option(name: .long, help: "Thumbnail grid size as WxH (e.g., 80x40)")
    var size: String?

    @Flag(name: .long, help: "Force parsing of files without DICM prefix")
    var force: Bool = false

    @Flag(name: .long, help: "Verbose output for debugging")
    var verbose: Bool = false

    mutating func validate() throws {
        guard !filePaths.isEmpty else {
            throw ValidationError("At least one DICOM file path is required")
        }

        for path in filePaths {
            guard FileManager.default.fileExists(atPath: path) else {
                throw ValidationError("File not found: \(path)")
            }
        }

        if windowCenter != nil && windowWidth == nil {
            throw ValidationError("--window-width must be provided when --window-center is set")
        }

        if windowWidth != nil && windowCenter == nil {
            throw ValidationError("--window-center must be provided when --window-width is set")
        }

        if frame < 0 {
            throw ValidationError("Frame number must be non-negative")
        }

        if let w = width, w < 1 {
            throw ValidationError("Width must be at least 1")
        }
        if let h = height, h < 1 {
            throw ValidationError("Height must be at least 1")
        }

        // Parse size option
        if let sizeStr = size {
            let parts = sizeStr.lowercased().split(separator: "x")
            guard parts.count == 2,
                  let w = Int(parts[0]), w > 0,
                  let h = Int(parts[1]), h > 0 else {
                throw ValidationError("Size must be in format WxH (e.g., 80x40)")
            }
        }
    }

    mutating func run() throws {
        if thumbnail && filePaths.count > 1 {
            try renderMultiFileThumbnails()
        } else if thumbnail {
            try renderFrameThumbnails()
        } else {
            try renderSingleImage()
        }
    }

    // MARK: - Single Image Rendering

    private func renderSingleImage() throws {
        let path = filePaths[0]

        if verbose {
            print("Reading DICOM file: \(path)")
        }

        let fileData = try Data(contentsOf: URL(fileURLWithPath: path))
        let dicomFile = try DICOMFile.read(from: fileData, force: force)
        let renderer = TerminalRenderer(dicomFile: dicomFile, verbose: verbose)

        // Show info overlay
        if showInfo {
            let info = renderer.generateInfoOverlay()
            print(info)
            print(String(repeating: "─", count: 40))
        }

        // Extract and render
        let image = try renderer.extractPixels(
            frame: frame,
            windowCenter: windowCenter,
            windowWidth: windowWidth,
            invert: invert
        )

        let termSize = TerminalSize.detect()
        let fitSize = TerminalRenderer.fitToTerminal(
            imageWidth: image.width,
            imageHeight: image.height,
            terminalWidth: termSize.width,
            terminalHeight: termSize.height,
            customWidth: width,
            customHeight: height
        )

        let scaled = TerminalRenderer.scaleImage(image, toWidth: fitSize.width, toHeight: fitSize.height)

        if verbose {
            print("Terminal: \(termSize.width)x\(termSize.height)")
            print("Scaled to: \(fitSize.width)x\(fitSize.height)")
        }

        let output: String
        switch mode {
        case .ascii:
            output = TerminalRenderer.renderASCII(scaled, quality: quality)
        case .ansi:
            output = TerminalRenderer.renderANSI(scaled, colorDepth: color)
        case .iterm2:
            output = TerminalRenderer.renderITerm2(image, width: width, height: height)
        case .kitty:
            output = TerminalRenderer.renderKitty(image)
        case .sixel:
            output = TerminalRenderer.renderSixel(scaled)
        }

        print(output, terminator: "")

        // Show overlay info at bottom
        if showOverlay {
            let totalFrames = renderer.frameCount()
            print("\u{1B}[0m") // Reset colors
            print("[\(path)] Frame \(frame + 1)/\(totalFrames) | \(image.originalColumns)x\(image.originalRows)")
        }
    }

    // MARK: - Thumbnail Grid Rendering

    private func renderFrameThumbnails() throws {
        let path = filePaths[0]
        let fileData = try Data(contentsOf: URL(fileURLWithPath: path))
        let dicomFile = try DICOMFile.read(from: fileData, force: force)
        let renderer = TerminalRenderer(dicomFile: dicomFile, verbose: verbose)

        let totalFrames = renderer.frameCount()
        let frameIndices = Array(0..<totalFrames)

        if verbose {
            print("Rendering \(totalFrames) frames as thumbnails")
        }

        let termSize = parseTerminalSize()

        let output = try renderer.renderThumbnailGrid(
            frames: frameIndices,
            mode: mode,
            terminalSize: termSize,
            quality: quality,
            colorDepth: color
        )

        print(output, terminator: "")
    }

    private func renderMultiFileThumbnails() throws {
        let termSize = parseTerminalSize()
        let totalFiles = filePaths.count
        let gridCols = min(totalFiles, max(1, termSize.width / 20))
        let thumbWidth = max(10, (termSize.width - gridCols - 1) / gridCols)
        let thumbHeight = max(5, (termSize.height - 2) / ((totalFiles + gridCols - 1) / gridCols))

        if verbose {
            print("Rendering \(totalFiles) files as thumbnails (\(gridCols) columns)")
        }

        var output = ""
        var rowThumbnails: [(NormalizedImage, String)] = []

        for (i, path) in filePaths.enumerated() {
            do {
                let fileData = try Data(contentsOf: URL(fileURLWithPath: path))
                let dicomFile = try DICOMFile.read(from: fileData, force: force)
                let renderer = TerminalRenderer(dicomFile: dicomFile, verbose: false)
                let image = try renderer.extractPixels(
                    windowCenter: windowCenter,
                    windowWidth: windowWidth,
                    invert: invert
                )
                let scaled = TerminalRenderer.scaleImage(image, toWidth: thumbWidth, toHeight: thumbHeight)
                let filename = URL(fileURLWithPath: path).lastPathComponent
                rowThumbnails.append((scaled, filename))
            } catch {
                if verbose {
                    print("Warning: Could not render \(path): \(error)")
                }
            }

            // Render row when full or at end
            if rowThumbnails.count == gridCols || i == filePaths.count - 1 {
                // Render thumbnails side by side
                let ramp = quality == .high ? TerminalRenderer.highQualityRamp : TerminalRenderer.lowQualityRamp
                for y in 0..<thumbHeight {
                    for (j, (thumb, _)) in rowThumbnails.enumerated() {
                        if j > 0 { output += " " }
                        if y < thumb.height {
                            for x in 0..<thumb.width {
                                let value = thumb.pixels[y * thumb.width + x]
                                let index = min(Int(value * Double(ramp.count - 1)), ramp.count - 1)
                                output.append(ramp[index])
                            }
                        }
                    }
                    output += "\n"
                }

                // Labels
                for (j, (_, name)) in rowThumbnails.enumerated() {
                    if j > 0 { output += " " }
                    let truncated = name.count > thumbWidth ? String(name.prefix(thumbWidth - 3)) + "..." : name
                    let padding = max(0, thumbWidth - truncated.count)
                    output += String(repeating: " ", count: padding / 2) + truncated
                    output += String(repeating: " ", count: padding - padding / 2)
                }
                output += "\n\n"

                rowThumbnails.removeAll()
            }
        }

        print(output, terminator: "")
    }

    // MARK: - Helpers

    private func parseTerminalSize() -> TerminalSize {
        if let sizeStr = size {
            let parts = sizeStr.lowercased().split(separator: "x")
            if parts.count == 2, let w = Int(parts[0]), let h = Int(parts[1]) {
                return TerminalSize(width: w, height: h)
            }
        }
        return TerminalSize.detect()
    }
}

// MARK: - ExpressibleByArgument conformances

extension DisplayMode: ExpressibleByArgument {}
extension AsciiQuality: ExpressibleByArgument {}
extension ANSIColorDepth: ExpressibleByArgument {}

DICOMViewer.main()
