import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

struct DICOM3D: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-3d",
        abstract: "3D reconstruction and Multi-Planar Reformation (MPR) from DICOM series",
        discussion: """
            Perform 3D volume reconstruction, MPR, and advanced projection techniques
            from multi-slice DICOM series for medical imaging visualization.
            
            Examples:
              # Generate axial, sagittal, coronal MPR
              dicom-3d mpr series/*.dcm --output mpr/ --planes axial,sagittal,coronal
              
              # Maximum Intensity Projection
              dicom-3d mip series/*.dcm --output mip.png --thickness 20
              
              # 3D surface rendering
              dicom-3d surface series/*.dcm --threshold 200 --output surface.stl
              
              # Volume rendering
              dicom-3d volume series/*.dcm --output volume.png
            """,
        version: "1.4.0",
        subcommands: [
            MPRCommand.self,
            MIPCommand.self,
            MinIPCommand.self,
            AverageCommand.self,
            SurfaceCommand.self,
            VolumeCommand.self,
            ExportCommand.self
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

// MARK: - Main

DICOM3D.main()
