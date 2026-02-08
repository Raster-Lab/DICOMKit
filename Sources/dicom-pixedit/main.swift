import Foundation
import ArgumentParser
import DICOMCore
import DICOMKit
import DICOMDictionary

@available(macOS 10.15, *)
struct DICOMPixedit: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-pixedit",
        abstract: "Edit pixel data in DICOM files",
        discussion: """
            Provides pixel data manipulation tools for DICOM images including
            masking burned-in annotations, cropping regions, adjusting window/level,
            and converting photometric interpretation.
            
            Examples:
              # Mask a region (e.g., burned-in text)
              dicom-pixedit file.dcm --output masked.dcm --mask-region 0,0,200,50
              
              # Mask with specific fill value
              dicom-pixedit file.dcm --output masked.dcm --mask-region 0,0,200,50 --fill-value 0
              
              # Crop to region of interest
              dicom-pixedit file.dcm --output cropped.dcm --crop 100,100,400,400
              
              # Adjust window/level permanently (bake into pixel data)
              dicom-pixedit ct.dcm --output windowed.dcm --window-center 40 --window-width 400 --apply-window
              
              # Invert pixel values
              dicom-pixedit file.dcm --output inverted.dcm --invert
            """,
        version: "1.3.0"
    )
    
    @Argument(help: "Input DICOM file path")
    var input: String
    
    @Option(name: .long, help: "Output DICOM file path")
    var output: String
    
    @Option(name: .long, help: "Mask region (x,y,width,height) - sets pixels to fill value")
    var maskRegion: String?
    
    @Option(name: .long, help: "Fill value for masked regions (default: 0)")
    var fillValue: Int?
    
    @Option(name: .long, help: "Crop region (x,y,width,height)")
    var crop: String?
    
    @Option(name: .long, help: "Window center for window/level application")
    var windowCenter: Double?
    
    @Option(name: .long, help: "Window width for window/level application")
    var windowWidth: Double?
    
    @Flag(name: .long, help: "Apply window/level permanently to pixel data")
    var applyWindow: Bool = false
    
    @Flag(name: .long, help: "Invert pixel values")
    var invert: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose: Bool = false
    
    mutating func run() throws {
        // Validate input file exists
        guard FileManager.default.fileExists(atPath: input) else {
            throw ValidationError("Input file not found: \(input)")
        }
        
        // Build operations list
        var operations: [PixelOperation] = []
        
        let editor = PixelEditor(verbose: verbose)
        
        if let maskRegionStr = maskRegion {
            let region = try editor.parseRegion(maskRegionStr)
            let fill = fillValue ?? 0
            operations.append(.mask(x: region.x, y: region.y, width: region.width, height: region.height, fillValue: fill))
        }
        
        if let cropStr = crop {
            let region = try editor.parseRegion(cropStr)
            operations.append(.crop(x: region.x, y: region.y, width: region.width, height: region.height))
        }
        
        if applyWindow {
            guard let center = windowCenter, let width = windowWidth else {
                throw ValidationError("--apply-window requires both --window-center and --window-width")
            }
            operations.append(.windowLevel(center: center, width: width))
        }
        
        if invert {
            operations.append(.invert)
        }
        
        guard !operations.isEmpty else {
            throw ValidationError("No operations specified. Use --mask-region, --crop, --apply-window, or --invert")
        }
        
        if verbose {
            fprintln("Input: \(input)")
            fprintln("Output: \(output)")
            fprintln("Operations: \(operations.count)")
        }
        
        try editor.processFile(inputPath: input, outputPath: output, operations: operations)
        
        if verbose {
            fprintln("Done.")
        }
    }
}

struct ValidationError: Error, LocalizedError {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    var errorDescription: String? {
        message
    }
}

private func fprintln(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8) ?? Data())
}

DICOMPixedit.main()
