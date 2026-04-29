import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

struct DICOM3D: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-3d",
        abstract: "3D reconstruction, MPR, and JP3D volumetric encoding from DICOM series",
        discussion: """
            Perform 3D volume reconstruction, MPR, projection techniques, and JP3D
            volumetric encode/decode from multi-slice DICOM series.

            Examples:
              # Generate axial, sagittal, coronal MPR
              dicom-3d mpr series/*.dcm --output mpr/ --planes axial,sagittal,coronal

              # Maximum Intensity Projection
              dicom-3d mip series/*.dcm --output mip.png --thickness 20

              # 3D surface rendering
              dicom-3d surface series/*.dcm --threshold 200 --output surface.stl

              # Encode a slice series as a JP3D volume document
              dicom-3d encode-volume series/*.dcm --output volume.jp3d.dcm
              dicom-3d encode-volume ./series/ --output volume.jp3d.dcm --mode lossless-htj2k

              # Decode a JP3D document back to individual DICOM slices
              dicom-3d decode-volume volume.jp3d.dcm --output ./decoded/

              # Inspect JP3D document metadata (no decode)
              dicom-3d inspect volume.jp3d.dcm
              dicom-3d inspect volume.jp3d.dcm --json
            """,
        version: "1.5.0",
        subcommands: [
            MPRCommand.self,
            MIPCommand.self,
            MinIPCommand.self,
            AverageCommand.self,
            SurfaceCommand.self,
            VolumeCommand.self,
            ExportCommand.self,
            EncodeVolumeCommand.self,
            DecodeVolumeCommand.self,
            InspectCommand.self,
            BackendsCommand.self
        ]
    )
}

// MARK: - MPR Command

struct MPRCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mpr",
        abstract: "Generate Multi-Planar Reformation (MPR) images"
    )
    
    @Argument(help: "Input DICOM files (multi-slice series)")
    var inputPaths: [String]
    
    @Option(name: .shortAndLong, help: "Output directory or file path")
    var output: String
    
    @Option(name: .long, help: "Planes to generate: axial, sagittal, coronal, or oblique")
    var planes: String = "axial,sagittal,coronal"
    
    @Option(name: .long, help: "Output format: png, dcm")
    var format: OutputFormat = .png
    
    @Option(name: .long, help: "Slice thickness in mm")
    var thickness: Double?
    
    @Option(name: .long, help: "Interpolation method: nearest, linear, cubic")
    var interpolation: InterpolationMethod = .linear
    
    @Option(name: .long, help: "Window center for display")
    var windowCenter: Double?
    
    @Option(name: .long, help: "Window width for display")
    var windowWidth: Double?
    
    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false
    
    mutating func validate() throws {
        guard !inputPaths.isEmpty else {
            throw ValidationError("At least one input file is required")
        }
        
        for path in inputPaths {
            guard FileManager.default.fileExists(atPath: path) else {
                throw ValidationError("File not found: \(path)")
            }
        }
        
        let validPlanes = ["axial", "sagittal", "coronal", "oblique"]
        let requestedPlanes = planes.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        for plane in requestedPlanes {
            guard validPlanes.contains(plane) else {
                throw ValidationError("Invalid plane: \(plane). Must be one of: \(validPlanes.joined(separator: ", "))")
            }
        }
    }
    
    mutating func run() throws {
        if verbose {
            print("Loading \(inputPaths.count) DICOM files...")
        }
        
        // Load volume
        let loader = VolumeLoader(verbose: verbose)
        let volume = try loader.loadVolume(from: inputPaths)
        
        if verbose {
            print("Volume loaded: \(volume.dimensions.width)x\(volume.dimensions.height)x\(volume.dimensions.depth)")
            print("Spacing: \(volume.spacing.x)x\(volume.spacing.y)x\(volume.spacing.z) mm")
        }
        
        // Generate MPR
        let generator = MPRGenerator(volume: volume, interpolation: interpolation, verbose: verbose)
        let requestedPlanes = planes.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        
        // Create output directory if needed
        let outputURL = URL(fileURLWithPath: output)
        if requestedPlanes.count > 1 || !output.hasSuffix(".png") {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        for planeName in requestedPlanes {
            if verbose {
                print("Generating \(planeName) MPR...")
            }
            
            let planeType: PlaneType
            switch planeName {
            case "axial":
                planeType = .axial
            case "sagittal":
                planeType = .sagittal
            case "coronal":
                planeType = .coronal
            default:
                continue
            }
            
            let slices = try generator.generateMPR(plane: planeType, sliceThickness: thickness)
            
            if verbose {
                print("Generated \(slices.count) \(planeName) slices")
            }
            
            // Save slices
            let outputDir = requestedPlanes.count > 1 ? outputURL.appendingPathComponent(planeName) : outputURL
            if requestedPlanes.count > 1 {
                try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true, attributes: nil)
            }
            
            for (index, slice) in slices.enumerated() {
                let fileName: String
                if requestedPlanes.count > 1 || slices.count > 1 {
                    fileName = "\(planeName)_\(String(format: "%04d", index)).png"
                } else {
                    fileName = outputURL.lastPathComponent
                }
                
                let sliceURL = requestedPlanes.count > 1 ? outputDir.appendingPathComponent(fileName) : outputDir.deletingLastPathComponent().appendingPathComponent(fileName)
                try slice.savePNG(to: sliceURL, windowCenter: windowCenter, windowWidth: windowWidth)
            }
        }
        
        if verbose {
            print("MPR generation complete. Output: \(output)")
        }
    }
}

// MARK: - MIP Command

struct MIPCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mip",
        abstract: "Generate Maximum Intensity Projection (MIP)"
    )
    
    @Argument(help: "Input DICOM files (multi-slice series)")
    var inputPaths: [String]
    
    @Option(name: .shortAndLong, help: "Output file path")
    var output: String
    
    @Option(name: .long, help: "Projection direction: axial, sagittal, coronal")
    var direction: String = "axial"
    
    @Option(name: .long, help: "Slab thickness in mm (0 = full volume)")
    var thickness: Double = 0
    
    @Option(name: .long, help: "Window center for display")
    var windowCenter: Double?
    
    @Option(name: .long, help: "Window width for display")
    var windowWidth: Double?
    
    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false
    
    mutating func validate() throws {
        guard !inputPaths.isEmpty else {
            throw ValidationError("At least one input file is required")
        }
        
        let validDirections = ["axial", "sagittal", "coronal"]
        guard validDirections.contains(direction.lowercased()) else {
            throw ValidationError("Invalid direction: \(direction). Must be one of: \(validDirections.joined(separator: ", "))")
        }
    }
    
    mutating func run() throws {
        if verbose {
            print("Loading \(inputPaths.count) DICOM files...")
        }
        
        // Load volume
        let loader = VolumeLoader(verbose: verbose)
        let volume = try loader.loadVolume(from: inputPaths)
        
        if verbose {
            print("Volume loaded: \(volume.dimensions.width)x\(volume.dimensions.height)x\(volume.dimensions.depth)")
        }
        
        // Generate MIP
        let renderer = ProjectionRenderer(volume: volume, verbose: verbose)
        let projection: ProjectionType
        
        switch direction.lowercased() {
        case "axial":
            projection = .axial
        case "sagittal":
            projection = .sagittal
        case "coronal":
            projection = .coronal
        default:
            projection = .axial
        }
        
        let result = try renderer.maximumIntensityProjection(
            direction: projection,
            slabThickness: thickness > 0 ? thickness : nil
        )
        
        // Save output
        let outputURL = URL(fileURLWithPath: output)
        try result.savePNG(to: outputURL, windowCenter: windowCenter, windowWidth: windowWidth)
        
        if verbose {
            print("MIP saved to: \(output)")
        }
    }
}

// MARK: - MinIP Command

struct MinIPCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "minip",
        abstract: "Generate Minimum Intensity Projection (MinIP)"
    )
    
    @Argument(help: "Input DICOM files (multi-slice series)")
    var inputPaths: [String]
    
    @Option(name: .shortAndLong, help: "Output file path")
    var output: String
    
    @Option(name: .long, help: "Projection direction: axial, sagittal, coronal")
    var direction: String = "axial"
    
    @Option(name: .long, help: "Slab thickness in mm (0 = full volume)")
    var thickness: Double = 0
    
    @Option(name: .long, help: "Window center for display")
    var windowCenter: Double?
    
    @Option(name: .long, help: "Window width for display")
    var windowWidth: Double?
    
    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false
    
    mutating func validate() throws {
        guard !inputPaths.isEmpty else {
            throw ValidationError("At least one input file is required")
        }
    }
    
    mutating func run() throws {
        if verbose {
            print("Loading \(inputPaths.count) DICOM files...")
        }
        
        let loader = VolumeLoader(verbose: verbose)
        let volume = try loader.loadVolume(from: inputPaths)
        
        let renderer = ProjectionRenderer(volume: volume, verbose: verbose)
        let projection: ProjectionType
        
        switch direction.lowercased() {
        case "axial":
            projection = .axial
        case "sagittal":
            projection = .sagittal
        case "coronal":
            projection = .coronal
        default:
            projection = .axial
        }
        
        let result = try renderer.minimumIntensityProjection(
            direction: projection,
            slabThickness: thickness > 0 ? thickness : nil
        )
        
        let outputURL = URL(fileURLWithPath: output)
        try result.savePNG(to: outputURL, windowCenter: windowCenter, windowWidth: windowWidth)
        
        if verbose {
            print("MinIP saved to: \(output)")
        }
    }
}

// MARK: - Average Command

struct AverageCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "average",
        abstract: "Generate Average Intensity Projection"
    )
    
    @Argument(help: "Input DICOM files (multi-slice series)")
    var inputPaths: [String]
    
    @Option(name: .shortAndLong, help: "Output file path")
    var output: String
    
    @Option(name: .long, help: "Projection direction: axial, sagittal, coronal")
    var direction: String = "axial"
    
    @Option(name: .long, help: "Window center for display")
    var windowCenter: Double?
    
    @Option(name: .long, help: "Window width for display")
    var windowWidth: Double?
    
    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false
    
    mutating func validate() throws {
        guard !inputPaths.isEmpty else {
            throw ValidationError("At least one input file is required")
        }
    }
    
    mutating func run() throws {
        if verbose {
            print("Loading \(inputPaths.count) DICOM files...")
        }
        
        let loader = VolumeLoader(verbose: verbose)
        let volume = try loader.loadVolume(from: inputPaths)
        
        let renderer = ProjectionRenderer(volume: volume, verbose: verbose)
        let projection: ProjectionType
        
        switch direction.lowercased() {
        case "axial":
            projection = .axial
        case "sagittal":
            projection = .sagittal
        case "coronal":
            projection = .coronal
        default:
            projection = .axial
        }
        
        let result = try renderer.averageIntensityProjection(direction: projection)
        
        let outputURL = URL(fileURLWithPath: output)
        try result.savePNG(to: outputURL, windowCenter: windowCenter, windowWidth: windowWidth)
        
        if verbose {
            print("Average projection saved to: \(output)")
        }
    }
}

// MARK: - Surface Command

struct SurfaceCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "surface",
        abstract: "Extract 3D surface mesh using Marching Cubes"
    )
    
    @Argument(help: "Input DICOM files (multi-slice series)")
    var inputPaths: [String]
    
    @Option(name: .shortAndLong, help: "Output file path (.stl or .obj)")
    var output: String
    
    @Option(name: .long, help: "Threshold value for surface extraction")
    var threshold: Double
    
    @Option(name: .long, help: "Output format: stl, obj")
    var format: MeshFormat = .stl
    
    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false
    
    mutating func validate() throws {
        guard !inputPaths.isEmpty else {
            throw ValidationError("At least one input file is required")
        }
    }
    
    mutating func run() throws {
        if verbose {
            print("Loading \(inputPaths.count) DICOM files...")
        }
        
        let loader = VolumeLoader(verbose: verbose)
        let volume = try loader.loadVolume(from: inputPaths)
        
        if verbose {
            print("Extracting surface at threshold: \(threshold)")
        }
        
        let extractor = SurfaceExtractor(volume: volume, verbose: verbose)
        let mesh = try extractor.extractSurface(threshold: threshold)
        
        let outputURL = URL(fileURLWithPath: output)
        
        switch format {
        case .stl:
            try mesh.saveSTL(to: outputURL)
        case .obj:
            try mesh.saveOBJ(to: outputURL)
        }
        
        if verbose {
            print("Surface mesh saved to: \(output)")
            print("Vertices: \(mesh.vertices.count), Triangles: \(mesh.triangles.count)")
        }
    }
}

// MARK: - Volume Command

struct VolumeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "volume",
        abstract: "Render volume using ray casting"
    )
    
    @Argument(help: "Input DICOM files (multi-slice series)")
    var inputPaths: [String]
    
    @Option(name: .shortAndLong, help: "Output file path")
    var output: String
    
    @Option(name: .long, help: "Camera angle as azimuth,elevation (degrees)")
    var cameraAngle: String?
    
    @Option(name: .long, help: "Transfer function file (JSON)")
    var transferFunction: String?
    
    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false
    
    mutating func validate() throws {
        guard !inputPaths.isEmpty else {
            throw ValidationError("At least one input file is required")
        }
    }
    
    mutating func run() throws {
        print("Volume rendering not yet implemented")
        throw ExitCode.failure
    }
}

// MARK: - Export Command

struct ExportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export volume in various formats (NIfTI, MetaImage)"
    )
    
    @Argument(help: "Input DICOM files (multi-slice series)")
    var inputPaths: [String]
    
    @Option(name: .shortAndLong, help: "Output file prefix")
    var output: String
    
    @Option(name: .long, help: "Export formats: nifti, metaimage")
    var formats: String = "nifti"
    
    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false
    
    mutating func validate() throws {
        guard !inputPaths.isEmpty else {
            throw ValidationError("At least one input file is required")
        }
    }
    
    mutating func run() throws {
        if verbose {
            print("Loading \(inputPaths.count) DICOM files...")
        }
        
        let loader = VolumeLoader(verbose: verbose)
        let volume = try loader.loadVolume(from: inputPaths)
        
        let requestedFormats = formats.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        
        for format in requestedFormats {
            if verbose {
                print("Exporting as \(format)...")
            }
            
            switch format {
            case "nifti":
                let outputURL = URL(fileURLWithPath: output).appendingPathExtension("nii")
                try volume.exportNIfTI(to: outputURL)
                if verbose {
                    print("NIfTI saved to: \(outputURL.path)")
                }
            case "metaimage":
                let outputURL = URL(fileURLWithPath: output).appendingPathExtension("mhd")
                try volume.exportMetaImage(to: outputURL)
                if verbose {
                    print("MetaImage saved to: \(outputURL.path)")
                }
            default:
                print("Warning: Unknown format '\(format)', skipping")
            }
        }
    }
}

// MARK: - Supporting Types

enum OutputFormat: String, ExpressibleByArgument {
    case png
    case dcm
}

enum InterpolationMethod: String, ExpressibleByArgument {
    case nearest
    case linear
    case cubic
}

enum MeshFormat: String, ExpressibleByArgument {
    case stl
    case obj
}

// MARK: - Backends Command

struct BackendsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "backends",
        abstract: "List available hardware acceleration backends",
        discussion: """
            Displays the hardware acceleration backends available on this platform.
            
            Examples:
              dicom-3d backends
              dicom-3d backends --json
            """
    )

    @Flag(name: .long, help: "Output as JSON")
    var json: Bool = false

    mutating func run() throws {
        let best = CodecBackendProbe.bestAvailable

        if json {
            var items: [[String: Any]] = []
            for backend in CodecBackend.allCases {
                let isAvail = CodecBackendProbe.isAvailable(backend)
                items.append([
                    "backend": backend.rawValue,
                    "available": isAvail,
                    "active": backend == best,
                    "displayName": backend.displayName
                ])
            }
            let data = try JSONSerialization.data(withJSONObject: items, options: [.prettyPrinted])
            print(String(data: data, encoding: .utf8) ?? "")
        } else {
            print("Available hardware acceleration backends:")
            print("")
            for backend in CodecBackend.allCases {
                let isAvail = CodecBackendProbe.isAvailable(backend)
                let marker = isAvail ? (backend == best ? "✓ (active)" : "✓") : "✗"
                print("  [\(marker)] \(backend.rawValue.padding(toLength: 12, withPad: " ", startingAt: 0))\(backend.displayName)")
            }
            print("")
            print("Active backend: \(best.displayName)")
        }
    }
}

// MARK: - Encode Volume Command

struct EncodeVolumeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "encode-volume",
        abstract: "Encode a DICOM slice series as a JP3D volumetric document",
        discussion: """
            Reads a multi-slice DICOM series, validates uniform slice spacing, and
            encodes the volume as a single JP3D encapsulated DICOM document using
            J2KSwift v3.2.0.

            The output file uses the private SOP class UID
            1.2.826.0.1.3680043.10.511.10 — not suitable for standard interchange.

            Compression modes:
              lossless         ISO/IEC 15444-1 lossless (default)
              lossless-htj2k   HTJ2K lossless (~5× faster decode than lossless)
              lossy            JPEG 2000 lossy at given --psnr
              lossy-htj2k      HTJ2K lossy at given --psnr

            Examples:
              dicom-3d encode-volume series/*.dcm --output vol.jp3d.dcm
              dicom-3d encode-volume ./series/ --output vol.jp3d.dcm --mode lossless-htj2k
              dicom-3d encode-volume series/*.dcm --output vol.jp3d.dcm --mode lossy --psnr 55
            """
    )

    @Argument(help: "Input DICOM files or a single directory containing the series")
    var inputPaths: [String]

    @Option(name: .shortAndLong, help: "Output JP3D DICOM document file path")
    var output: String

    @Option(name: .long, help: "Compression mode: lossless, lossless-htj2k, lossy, lossy-htj2k")
    var mode: String = "lossless"

    @Option(name: .long, help: "Target PSNR in dB for lossy modes (default: 40.0)")
    var psnr: Double = 40.0

    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false

    mutating func validate() throws {
        guard !inputPaths.isEmpty else {
            throw ValidationError("At least one input path is required")
        }
        let validModes = ["lossless", "lossless-htj2k", "lossy", "lossy-htj2k"]
        guard validModes.contains(mode.lowercased()) else {
            throw ValidationError("Invalid --mode '\(mode)'. Must be one of: \(validModes.joined(separator: ", "))")
        }
        guard psnr > 0 else {
            throw ValidationError("--psnr must be positive")
        }
    }

    mutating func run() throws {
        let urls = try resolveInputFiles(from: inputPaths)
        guard !urls.isEmpty else {
            throw ValidationError("No DICOM files found at the specified path(s)")
        }

        if verbose { print("Loading \(urls.count) DICOM file(s)...") }

        var series: [DICOMFile] = []
        for url in urls {
            do {
                series.append(try DICOMFile.read(from: url))
            } catch {
                throw ValidationError("Failed to read '\(url.lastPathComponent)': \(error.localizedDescription)")
            }
        }

        let compressionMode: JP3DCodec.CompressionMode
        switch mode.lowercased() {
        case "lossless":         compressionMode = .lossless
        case "lossless-htj2k":   compressionMode = .losslessHTJ2K
        case "lossy":            compressionMode = .lossy(psnr: psnr)
        case "lossy-htj2k":      compressionMode = .lossyHTJ2K(psnr: psnr)
        default:                 compressionMode = .lossless
        }

        if verbose { print("Encoding \(series.count) slice(s) — mode: \(mode)...") }

        let document = try waitForTask(Task {
            try await JP3DVolumeDocument.encode(series: series, compressionMode: compressionMode)
        })

        let outputURL = URL(fileURLWithPath: output)
        let data = try document.write()
        try data.write(to: outputURL)

        let sizeMB = String(format: "%.1f", Double(data.count) / 1_048_576)
        if verbose {
            print("JP3D document written to: \(output) (\(sizeMB) MB)")
        } else {
            print("Encoded \(series.count) slices → \(output) (\(sizeMB) MB)")
        }
    }
}

// MARK: - Decode Volume Command

struct DecodeVolumeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "decode-volume",
        abstract: "Decode a JP3D volumetric document back to individual DICOM slices",
        discussion: """
            Reads a JP3D DICOM document, decodes the JP3D codestream, and writes one
            DICOM file per slice into the output directory.

            Output files are named slice_0000.dcm, slice_0001.dcm, …

            Example:
              dicom-3d decode-volume volume.jp3d.dcm --output ./decoded/
            """
    )

    @Argument(help: "JP3D DICOM document file to decode")
    var inputPath: String

    @Option(name: .shortAndLong, help: "Output directory for decoded DICOM slices")
    var output: String

    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false

    mutating func validate() throws {
        guard FileManager.default.fileExists(atPath: inputPath) else {
            throw ValidationError("File not found: \(inputPath)")
        }
    }

    mutating func run() throws {
        if verbose { print("Reading JP3D document: \(inputPath)") }

        let file = try DICOMFile.read(from: URL(fileURLWithPath: inputPath))

        guard JP3DVolumeDocument.isJP3DVolumeDocument(file) else {
            throw ValidationError("'\(inputPath)' is not a JP3D volume document (wrong SOP class)")
        }

        if verbose { print("Decoding JP3D codestream...") }

        let slices = try waitForTask(Task {
            try await JP3DVolumeDocument.decode(from: file)
        })

        let outputURL = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        if verbose { print("Writing \(slices.count) slice(s) to: \(output)") }

        for (index, slice) in slices.enumerated() {
            let name = String(format: "slice_%04d.dcm", index)
            let data = try slice.write()
            try data.write(to: outputURL.appendingPathComponent(name))
        }

        print("Decoded \(slices.count) slices → \(output)")
    }
}

// MARK: - Inspect Command

struct InspectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "inspect",
        abstract: "Display metadata from a JP3D volumetric document without decoding",
        discussion: """
            Reads only the JSON sidecar embedded in a JP3D DICOM document, printing
            geometry, spacing, compression mode, and patient/study metadata.
            The JP3D codestream is not decoded, so this is near-instantaneous.

            Examples:
              dicom-3d inspect volume.jp3d.dcm
              dicom-3d inspect volume.jp3d.dcm --json
            """
    )

    @Argument(help: "JP3D DICOM document file to inspect")
    var inputPath: String

    @Flag(name: .long, help: "Output raw sidecar JSON instead of formatted text")
    var json: Bool = false

    mutating func validate() throws {
        guard FileManager.default.fileExists(atPath: inputPath) else {
            throw ValidationError("File not found: \(inputPath)")
        }
    }

    mutating func run() throws {
        let file = try DICOMFile.read(from: URL(fileURLWithPath: inputPath))

        guard JP3DVolumeDocument.isJP3DVolumeDocument(file) else {
            throw ValidationError("'\(inputPath)' is not a JP3D volume document (wrong SOP class)")
        }

        guard let payloadElement = file.dataSet[.encapsulatedDocument] else {
            throw ValidationError("JP3D document is missing the Encapsulated Document element")
        }
        let payload = payloadElement.valueData

        guard payload.count >= 8 else {
            throw ValidationError("JP3D payload too short (\(payload.count) bytes)")
        }

        let jp3dLen = Int(payload.subdata(in: 0..<4).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
        let jsonOffset = 4 + jp3dLen
        guard jsonOffset + 4 <= payload.count else {
            throw ValidationError("JP3D codestream length overflows payload")
        }
        let jsonLen = Int(payload.subdata(in: jsonOffset..<(jsonOffset + 4)).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
        guard jsonOffset + 4 + jsonLen <= payload.count else {
            throw ValidationError("JP3D sidecar JSON length overflows payload")
        }
        let jsonData = payload.subdata(in: (jsonOffset + 4)..<(jsonOffset + 4 + jsonLen))

        guard let meta = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw ValidationError("Failed to parse JP3D sidecar JSON")
        }

        if json {
            // Pretty-print the raw sidecar JSON plus size annotations
            var augmented = meta
            augmented["_jp3dCodestreamBytes"] = jp3dLen
            augmented["_sidecarJsonBytes"] = jsonLen
            augmented["_totalPayloadBytes"] = payload.count
            let out = try JSONSerialization.data(withJSONObject: augmented, options: [.prettyPrinted, .sortedKeys])
            print(String(data: out, encoding: .utf8) ?? "")
            return
        }

        // Formatted text output
        let rows       = meta["rows"]         as? Int    ?? 0
        let columns    = meta["columns"]      as? Int    ?? 0
        let frames     = meta["frames"]       as? Int    ?? 0
        let bitsAlloc  = meta["bitsAllocated"]as? Int    ?? 16
        let bitsStored = meta["bitsStored"]   as? Int    ?? 12
        let signed     = meta["signed"]       as? Bool   ?? false
        let spacingX   = meta["spacingX"]     as? Double ?? 0
        let spacingY   = meta["spacingY"]     as? Double ?? 0
        let spacingZ   = meta["spacingZ"]     as? Double ?? 0
        let compression = meta["compressionMode"] as? String ?? "unknown"
        let psnrVal    = meta["psnr"]         as? Double

        let patient  = (meta["patientName"]   as? String).map { "  Patient:          \($0)\n" } ?? ""
        let patientID = (meta["patientID"]    as? String).map { "  Patient ID:        \($0)\n" } ?? ""
        let modality = (meta["modality"]      as? String).map { "  Modality:          \($0)\n" } ?? ""
        let study    = (meta["studyInstanceUID"] as? String).map { "  Study UID:         \($0)\n" } ?? ""
        let series   = (meta["seriesDescription"] as? String).map { "  Series:            \($0)\n" } ?? ""
        let sopInst  = file.dataSet.string(for: .sopInstanceUID) ?? "—"

        let psnrLine = psnrVal.map { "  Target PSNR:       \(String(format: "%.1f", $0)) dB\n" } ?? ""
        let j2kMB    = String(format: "%.2f", Double(jp3dLen) / 1_048_576)
        let totalMB  = String(format: "%.2f", Double(payload.count) / 1_048_576)

        print("""
            JP3D Volume Document
            \(patient)\(patientID)\(modality)\(study)\(series)  SOP Instance UID:  \(sopInst)
              Dimensions:        \(rows) × \(columns) × \(frames) (rows × cols × slices)
              Voxel spacing:     \(String(format: "%.4g × %.4g × %.4g", spacingX, spacingY, spacingZ)) mm
              Bits allocated:    \(bitsAlloc)  stored: \(bitsStored)  signed: \(signed)
              Compression mode:  \(compression)\(psnrLine)  Codestream size:   \(j2kMB) MB  (\(jp3dLen) bytes)
              Total payload:     \(totalMB) MB  (\(payload.count) bytes)
            """)
    }
}

// MARK: - Async bridge

private final class AsyncResultBox<T>: @unchecked Sendable {
    var result: Result<T, Error>?
}

private func waitForTask<T>(_ task: Task<T, Error>) throws -> T {
    let sema = DispatchSemaphore(value: 0)
    let box = AsyncResultBox<T>()
    Task {
        do {
            let value = try await task.value
            box.result = .success(value)
        } catch {
            box.result = .failure(error)
        }
        sema.signal()
    }
    sema.wait()
    switch box.result! {
    case .success(let value): return value
    case .failure(let error): throw error
    }
}

// MARK: - Input resolution

/// Resolves a list of paths into an array of DICOM file URLs.
/// If a single directory is given, returns all `.dcm` files inside it (sorted by name).
private func resolveInputFiles(from paths: [String]) throws -> [URL] {
    let fm = FileManager.default
    if paths.count == 1 {
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: paths[0], isDirectory: &isDir), isDir.boolValue {
            let dir = URL(fileURLWithPath: paths[0])
            let contents = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            return contents
                .filter { $0.pathExtension.lowercased() == "dcm" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        }
    }
    return paths.map { URL(fileURLWithPath: $0) }
}

// MARK: - Main

DICOM3D.main()
