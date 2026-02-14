import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

#if canImport(CoreML)
import CoreML
#endif

#if canImport(Vision)
import Vision
#endif

@main
struct DICOMAI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-ai",
        abstract: "AI/ML integration for DICOM image analysis and enhancement",
        discussion: """
            Integrate AI/ML models for DICOM image analysis, enhancement, and automated reporting.
            Supports CoreML models on Apple platforms and ONNX models via CoreML conversion.
            
            Examples:
              dicom-ai classify chest-xray.dcm --model pneumonia.mlmodel
              dicom-ai segment abdomen-ct.dcm --model organs.mlmodel --output seg.dcm
              dicom-ai detect brain-mri.dcm --model lesion.mlmodel --confidence 0.7
              dicom-ai enhance noisy-image.dcm --model denoise.mlmodel
              dicom-ai batch series/*.dcm --model classifier.mlmodel --output results.json
            """,
        version: "1.4.0",
        subcommands: [
            Classify.self,
            Segment.self,
            Detect.self,
            Enhance.self,
            Batch.self,
        ]
    )
}

// MARK: - Common Options

struct CommonOptions: ParsableArguments {
    @Argument(help: "Path to the DICOM file or directory")
    var input: String
    
    @Option(name: .shortAndLong, help: "CoreML model file path (.mlmodel or .mlmodelc)")
    var model: String
    
    @Option(name: .shortAndLong, help: "Output file path (prints to stdout if omitted)")
    var output: String?
    
    @Option(name: .shortAndLong, help: "Output format: json, text, csv, dicom-sr, dicom-seg")
    var format: OutputFormat = .json
    
    @Option(name: .long, help: "Minimum confidence threshold (0.0-1.0)")
    var confidence: Double = 0.5
    
    @Flag(name: .long, help: "Force parsing of files without DICM prefix")
    var force: Bool = false
    
    @Flag(name: .long, help: "Verbose output for debugging")
    var verbose: Bool = false
    
    @Option(name: .long, help: "Frame index for multi-frame images (default: 0)")
    var frame: Int = 0
}

enum OutputFormat: String, ExpressibleByArgument, CaseIterable, Sendable {
    case json
    case text
    case csv
    case dicomSR = "dicom-sr"
    case dicomSEG = "dicom-seg"
}

// MARK: - Classify Subcommand

struct Classify: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Perform image classification using AI models",
        discussion: """
            Classify DICOM images using trained CoreML models.
            Outputs class labels with confidence scores.
            
            Example:
              dicom-ai classify chest-xray.dcm --model pneumonia-detector.mlmodel --confidence 0.7
            """
    )
    
    @OptionGroup var options: CommonOptions
    
    @Option(name: .long, help: "Maximum number of results to return")
    var topK: Int = 5
    
    mutating func run() throws {
        #if canImport(CoreML)
        if options.verbose {
            print("Loading DICOM file: \(options.input)")
        }
        
        let fileData = try Data(contentsOf: URL(fileURLWithPath: options.input))
        let dicomFile = try DICOMFile.read(from: fileData, force: options.force)
        let dataSet = dicomFile.dataSet
        
        if options.verbose {
            print("Loading CoreML model: \(options.model)")
        }
        
        let modelURL = URL(fileURLWithPath: options.model)
        let engine = try AIEngine(modelURL: modelURL, verbose: options.verbose)
        
        if options.verbose {
            print("Preprocessing image...")
        }
        
        let inputImage = try engine.preprocessImage(from: dataSet, frameIndex: options.frame)
        
        if options.verbose {
            print("Running inference...")
        }
        
        let predictions = try engine.classify(image: inputImage, topK: topK, threshold: options.confidence)
        
        let output: String
        if options.format == .dicomSR {
            if options.verbose {
                print("Creating DICOM SR from predictions...")
            }
            let srDataSet = try AIDICOMOutputGenerator.createSRFromClassification(
                predictions: predictions,
                sourceDataSet: dataSet,
                modelName: URL(fileURLWithPath: options.model).lastPathComponent
            )
            guard let outputPath = options.output else {
                throw AIError.missingOutput("Output file required for DICOM-SR format")
            }
            let srData = srDataSet.write()
            try srData.write(to: URL(fileURLWithPath: outputPath))
            output = "DICOM SR saved to \(outputPath)"
        } else {
            output = formatClassificationResults(
                predictions: predictions,
                format: options.format,
                filePath: options.input
            )
        }
        
        try writeOutput(output, to: options.output)
        #else
        throw AIError.platformNotSupported("CoreML is not available on this platform")
        #endif
    }
}

// MARK: - Segment Subcommand

struct Segment: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Perform image segmentation using AI models",
        discussion: """
            Segment anatomical structures or lesions using trained models.
            Outputs segmentation masks in various formats.
            
            Example:
              dicom-ai segment ct.dcm --model organ-seg.mlmodel --output seg.dcm --format dicom-seg
            """
    )
    
    @OptionGroup var options: CommonOptions
    
    @Option(name: .long, help: "Segmentation labels file (JSON with class names)")
    var labels: String?
    
    mutating func run() throws {
        #if canImport(CoreML)
        if options.verbose {
            print("Loading DICOM file: \(options.input)")
        }
        
        let fileData = try Data(contentsOf: URL(fileURLWithPath: options.input))
        let dicomFile = try DICOMFile.read(from: fileData, force: options.force)
        let dataSet = dicomFile.dataSet
        
        if options.verbose {
            print("Loading CoreML model: \(options.model)")
        }
        
        let modelURL = URL(fileURLWithPath: options.model)
        let engine = try AIEngine(modelURL: modelURL, verbose: options.verbose)
        
        if options.verbose {
            print("Preprocessing image...")
        }
        
        let inputImage = try engine.preprocessImage(from: dataSet, frameIndex: options.frame)
        
        if options.verbose {
            print("Running segmentation...")
        }
        
        let segmentationMask = try engine.segment(image: inputImage)
        
        let output: String
        if options.format == .dicomSEG {
            if options.verbose {
                print("Creating DICOM Segmentation object...")
            }
            let segDICOM = try createDICOMSegmentation(
                sourceDataSet: dataSet,
                segmentationMask: segmentationMask,
                labels: try loadLabels(from: labels)
            )
            guard let outputPath = options.output else {
                throw AIError.missingOutput("Output file required for DICOM-SEG format")
            }
            try segDICOM.write(to: URL(fileURLWithPath: outputPath))
            output = "Segmentation saved to \(outputPath)"
        } else {
            output = formatSegmentationResults(
                mask: segmentationMask,
                format: options.format,
                filePath: options.input
            )
        }
        
        try writeOutput(output, to: options.output)
        #else
        throw AIError.platformNotSupported("CoreML is not available on this platform")
        #endif
    }
}

// MARK: - Detect Subcommand

struct Detect: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Perform object/lesion detection using AI models",
        discussion: """
            Detect objects or lesions with bounding boxes using trained models.
            
            Example:
              dicom-ai detect mri.dcm --model lesion-detect.mlmodel --confidence 0.7
            """
    )
    
    @OptionGroup var options: CommonOptions
    
    @Option(name: .long, help: "Maximum number of detections to return")
    var maxDetections: Int = 10
    
    @Option(name: .long, help: "IoU threshold for non-maximum suppression")
    var iouThreshold: Double = 0.5
    
    mutating func run() throws {
        #if canImport(CoreML)
        if options.verbose {
            print("Loading DICOM file: \(options.input)")
        }
        
        let fileData = try Data(contentsOf: URL(fileURLWithPath: options.input))
        let dicomFile = try DICOMFile.read(from: fileData, force: options.force)
        let dataSet = dicomFile.dataSet
        
        if options.verbose {
            print("Loading CoreML model: \(options.model)")
        }
        
        let modelURL = URL(fileURLWithPath: options.model)
        let engine = try AIEngine(modelURL: modelURL, verbose: options.verbose)
        
        if options.verbose {
            print("Preprocessing image...")
        }
        
        let inputImage = try engine.preprocessImage(from: dataSet, frameIndex: options.frame)
        
        if options.verbose {
            print("Running detection...")
        }
        
        let detections = try engine.detect(
            image: inputImage,
            confidenceThreshold: options.confidence,
            iouThreshold: iouThreshold,
            maxDetections: maxDetections
        )
        
        let output: String
        if options.format == .dicomSR {
            if options.verbose {
                print("Creating DICOM SR from detections...")
            }
            let srDataSet = try AIDICOMOutputGenerator.createSRFromDetections(
                detections: detections,
                sourceDataSet: dataSet,
                modelName: URL(fileURLWithPath: options.model).lastPathComponent
            )
            guard let outputPath = options.output else {
                throw AIError.missingOutput("Output file required for DICOM-SR format")
            }
            let srData = srDataSet.write()
            try srData.write(to: URL(fileURLWithPath: outputPath))
            output = "DICOM SR saved to \(outputPath)"
        } else {
            output = formatDetectionResults(
                detections: detections,
                format: options.format,
                filePath: options.input
            )
        }
        
        try writeOutput(output, to: options.output)
        #else
        throw AIError.platformNotSupported("CoreML is not available on this platform")
        #endif
    }
}

// MARK: - Enhance Subcommand

struct Enhance: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Enhance image quality using AI models",
        discussion: """
            Enhance DICOM images using models trained for denoising,
            super-resolution, or other image enhancement tasks.
            
            Example:
              dicom-ai enhance noisy.dcm --model denoise.mlmodel --output enhanced.dcm
            """
    )
    
    @OptionGroup var options: CommonOptions
    
    mutating func validate() throws {
        guard options.output != nil else {
            throw ValidationError("Output file is required for enhance command")
        }
    }
    
    mutating func run() throws {
        #if canImport(CoreML)
        if options.verbose {
            print("Loading DICOM file: \(options.input)")
        }
        
        let fileData = try Data(contentsOf: URL(fileURLWithPath: options.input))
        let dicomFile = try DICOMFile.read(from: fileData, force: options.force)
        let dataSet = dicomFile.dataSet
        
        if options.verbose {
            print("Loading CoreML model: \(options.model)")
        }
        
        let modelURL = URL(fileURLWithPath: options.model)
        let engine = try AIEngine(modelURL: modelURL, verbose: options.verbose)
        
        if options.verbose {
            print("Preprocessing image...")
        }
        
        let inputImage = try engine.preprocessImage(from: dataSet, frameIndex: options.frame)
        
        if options.verbose {
            print("Running enhancement...")
        }
        
        let enhancedImage = try engine.enhance(image: inputImage)
        
        if options.verbose {
            print("Creating enhanced DICOM file...")
        }
        
        let enhancedDataSet = try createEnhancedDICOM(
            sourceDataSet: dataSet,
            enhancedImage: enhancedImage,
            frameIndex: options.frame
        )
        
        guard let outputPath = options.output else {
            throw AIError.missingOutput("Output file required")
        }
        
        try enhancedDataSet.write(to: URL(fileURLWithPath: outputPath))
        
        let message = "Enhanced image saved to \(outputPath)"
        try writeOutput(message, to: nil)
        #else
        throw AIError.platformNotSupported("CoreML is not available on this platform")
        #endif
    }
}

// MARK: - Batch Subcommand

struct Batch: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Batch process multiple DICOM files",
        discussion: """
            Process multiple DICOM files efficiently with batch inference.
            
            Example:
              dicom-ai batch series/*.dcm --model classifier.mlmodel --output results.csv --format csv
            """
    )
    
    @Argument(parsing: .captureForPassthrough, help: "DICOM files to process")
    var files: [String] = []
    
    @Option(name: .shortAndLong, help: "CoreML model file path")
    var model: String
    
    @Option(name: .shortAndLong, help: "Output file path")
    var output: String
    
    @Option(name: .shortAndLong, help: "Output format: json, csv")
    var format: BatchOutputFormat = .csv
    
    @Option(name: .long, help: "Batch size for inference")
    var batchSize: Int = 1
    
    @Option(name: .long, help: "Minimum confidence threshold")
    var confidence: Double = 0.5
    
    @Flag(name: .long, help: "Force parsing of files without DICM prefix")
    var force: Bool = false
    
    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false
    
    enum BatchOutputFormat: String, ExpressibleByArgument, CaseIterable, Sendable {
        case json
        case csv
    }
    
    mutating func run() throws {
        #if canImport(CoreML)
        guard !files.isEmpty else {
            throw ValidationError("No input files specified")
        }
        
        if verbose {
            print("Processing \(files.count) files with batch size \(batchSize)")
            print("Loading CoreML model: \(model)")
        }
        
        let modelURL = URL(fileURLWithPath: model)
        let engine = try AIEngine(modelURL: modelURL, verbose: verbose)
        
        var allResults: [[String: Any]] = []
        
        for (index, filePath) in files.enumerated() {
            if verbose {
                print("Processing file \(index + 1)/\(files.count): \(filePath)")
            }
            
            do {
                let fileData = try Data(contentsOf: URL(fileURLWithPath: filePath))
                let dicomFile = try DICOMFile.read(from: fileData, force: force)
                let dataSet = dicomFile.dataSet
                
                let inputImage = try engine.preprocessImage(from: dataSet, frameIndex: 0)
                let predictions = try engine.classify(image: inputImage, topK: 5, threshold: confidence)
                
                let result: [String: Any] = [
                    "file": filePath,
                    "predictions": predictions.map { pred in
                        ["label": pred.label, "confidence": pred.confidence]
                    }
                ]
                
                allResults.append(result)
            } catch {
                if verbose {
                    print("Error processing \(filePath): \(error)")
                }
                allResults.append([
                    "file": filePath,
                    "error": error.localizedDescription
                ])
            }
        }
        
        let outputContent: String
        switch format {
        case .json:
            let jsonData = try JSONSerialization.data(withJSONObject: allResults, options: .prettyPrinted)
            outputContent = String(data: jsonData, encoding: .utf8) ?? ""
        case .csv:
            outputContent = formatBatchResultsAsCSV(allResults)
        }
        
        try outputContent.write(toFile: output, atomically: true, encoding: .utf8)
        
        if verbose {
            print("Results saved to \(output)")
        }
        #else
        throw AIError.platformNotSupported("CoreML is not available on this platform")
        #endif
    }
}

// MARK: - Helper Functions

func writeOutput(_ content: String, to outputPath: String?) throws {
    if let path = outputPath {
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    } else {
        print(content)
    }
}

func loadLabels(from path: String?) throws -> [String] {
    guard let path = path else {
        return []
    }
    
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let json = try JSONSerialization.jsonObject(with: data)
    
    if let labels = json as? [String] {
        return labels
    } else if let dict = json as? [String: [String]], let labels = dict["labels"] {
        return labels
    }
    
    throw AIError.invalidLabelsFile("Labels file must contain array of strings")
}

func formatClassificationResults(predictions: [Prediction], format: OutputFormat, filePath: String) -> String {
    switch format {
    case .json:
        let results: [String: Any] = [
            "file": filePath,
            "predictions": predictions.map { ["label": $0.label, "confidence": $0.confidence] }
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: results, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    case .text:
        var output = "Classification Results for \(filePath):\n"
        for (index, pred) in predictions.enumerated() {
            output += "\(index + 1). \(pred.label): \(String(format: "%.2f%%", pred.confidence * 100))\n"
        }
        return output
    case .csv:
        var csv = "file,label,confidence\n"
        for pred in predictions {
            csv += "\(filePath),\(pred.label),\(pred.confidence)\n"
        }
        return csv
    default:
        return "Format \(format) not supported for classification"
    }
}

func formatSegmentationResults(mask: SegmentationMask, format: OutputFormat, filePath: String) -> String {
    switch format {
    case .json:
        let results: [String: Any] = [
            "file": filePath,
            "mask_size": "\(mask.width)x\(mask.height)",
            "num_classes": mask.numClasses
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: results, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    case .text:
        return "Segmentation Results for \(filePath):\nMask Size: \(mask.width)x\(mask.height)\nClasses: \(mask.numClasses)"
    default:
        return "Format \(format) not supported for segmentation"
    }
}

func formatDetectionResults(detections: [Detection], format: OutputFormat, filePath: String) -> String {
    switch format {
    case .json:
        let results: [String: Any] = [
            "file": filePath,
            "detections": detections.map { det in
                [
                    "label": det.label,
                    "confidence": det.confidence,
                    "bbox": [det.bbox.x, det.bbox.y, det.bbox.width, det.bbox.height]
                ]
            }
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: results, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    case .text:
        var output = "Detection Results for \(filePath):\n"
        for (index, det) in detections.enumerated() {
            output += "\(index + 1). \(det.label): \(String(format: "%.2f%%", det.confidence * 100)) at (\(det.bbox.x), \(det.bbox.y), \(det.bbox.width), \(det.bbox.height))\n"
        }
        return output
    case .csv:
        var csv = "file,label,confidence,x,y,width,height\n"
        for det in detections {
            csv += "\(filePath),\(det.label),\(det.confidence),\(det.bbox.x),\(det.bbox.y),\(det.bbox.width),\(det.bbox.height)\n"
        }
        return csv
    default:
        return "Format \(format) not supported for detection"
    }
}

func formatBatchResultsAsCSV(_ results: [[String: Any]]) -> String {
    var csv = "file,label,confidence\n"
    for result in results {
        let file = result["file"] as? String ?? ""
        if let predictions = result["predictions"] as? [[String: Any]] {
            for pred in predictions {
                let label = pred["label"] as? String ?? ""
                let confidence = pred["confidence"] as? Double ?? 0.0
                csv += "\(file),\(label),\(confidence)\n"
            }
        } else if let error = result["error"] as? String {
            csv += "\(file),ERROR,\(error)\n"
        }
    }
    return csv
}

func createDICOMSegmentation(sourceDataSet: DataSet, segmentationMask: SegmentationMask, labels: [String]) throws -> Data {
    return try AIDICOMOutputGenerator.createSegmentationObject(
        sourceDataSet: sourceDataSet,
        segmentationMask: segmentationMask,
        labels: labels,
        modelName: "AI Model"
    )
}

func createEnhancedDICOM(sourceDataSet: DataSet, enhancedImage: ProcessedImage, frameIndex: Int) throws -> Data {
    return try AIDICOMOutputGenerator.createEnhancedDICOMFile(
        sourceDataSet: sourceDataSet,
        enhancedImage: enhancedImage,
        frameIndex: frameIndex
    )
}
