import Foundation
import DICOMKit
import DICOMCore

#if canImport(CoreML)
import CoreML
#endif

#if canImport(Vision)
import Vision
#endif

#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if canImport(CoreImage)
import CoreImage
#endif

#if canImport(Accelerate)
import Accelerate
#endif

// MARK: - AI Engine

@available(macOS 14.0, iOS 17.0, *)
class AIEngine {
    private let model: MLModel?
    private let verbose: Bool
    private let modelURL: URL
    
    init(modelURL: URL, verbose: Bool = false) throws {
        self.modelURL = modelURL
        self.verbose = verbose
        
        #if canImport(CoreML)
        // Try to load the CoreML model
        do {
            let compiledURL: URL
            if modelURL.pathExtension == "mlmodelc" {
                // Already compiled
                compiledURL = modelURL
            } else if modelURL.pathExtension == "mlmodel" {
                // Need to compile
                if verbose {
                    print("Compiling CoreML model...")
                }
                compiledURL = try MLModel.compileModel(at: modelURL)
            } else {
                throw AIError.invalidModelFormat("Model must be .mlmodel or .mlmodelc")
            }
            
            let configuration = MLModelConfiguration()
            #if os(macOS) || os(iOS)
            configuration.computeUnits = .all  // Use CPU, GPU, and Neural Engine
            #endif
            
            self.model = try MLModel(contentsOf: compiledURL, configuration: configuration)
            
            if verbose {
                print("Model loaded successfully")
                if let modelDescription = self.model?.modelDescription {
                    print("Input: \(modelDescription.inputDescriptionsByName.keys)")
                    print("Output: \(modelDescription.outputDescriptionsByName.keys)")
                }
            }
        } catch {
            if verbose {
                print("Failed to load CoreML model: \(error)")
            }
            self.model = nil
            throw AIError.modelLoadFailed("Failed to load CoreML model: \(error.localizedDescription)")
        }
        #else
        self.model = nil
        throw AIError.platformNotSupported("CoreML is not available on this platform")
        #endif
    }
    
    // MARK: - Image Preprocessing
    
    func preprocessImage(from dataSet: DataSet, frameIndex: Int = 0) throws -> ProcessedImage {
        // Extract pixel data from DICOM
        guard let pixelData = dataSet.element(for: .pixelData)?.valueData else {
            throw AIError.noPixelData("No pixel data found in DICOM file")
        }
        
        // Get image dimensions
        guard let rows = dataSet.uint16(for: .rows),
              let columns = dataSet.uint16(for: .columns) else {
            throw AIError.missingMetadata("Missing Rows or Columns in DICOM")
        }
        
        let bitsAllocated = dataSet.uint16(for: .bitsAllocated) ?? 16
        let samplesPerPixel = dataSet.uint16(for: .samplesPerPixel) ?? 1
        let photometricInterpretation = dataSet.string(for: .photometricInterpretation) ?? "MONOCHROME2"
        
        if verbose {
            print("Image dimensions: \(columns)x\(rows), \(bitsAllocated) bits, \(samplesPerPixel) samples per pixel")
            print("Photometric interpretation: \(photometricInterpretation)")
        }
        
        // Create processed image structure
        let processedImage = ProcessedImage(
            width: Int(columns),
            height: Int(rows),
            bitsPerPixel: Int(bitsAllocated),
            samplesPerPixel: Int(samplesPerPixel),
            photometricInterpretation: photometricInterpretation,
            pixelData: pixelData
        )
        
        return processedImage
    }
    
    // MARK: - Classification
    
    func classify(image: ProcessedImage, topK: Int = 5, threshold: Double = 0.0) throws -> [Prediction] {
        #if canImport(CoreML)
        guard let model = model else {
            throw AIError.modelNotLoaded("Model not loaded")
        }
        
        // Convert processed image to MLFeatureProvider
        let input = try createMLInput(from: image)
        
        // Run prediction
        let output = try model.prediction(from: input)
        
        // Extract classification results
        let predictions = try extractClassificationPredictions(from: output, topK: topK, threshold: threshold)
        
        return predictions
        #else
        throw AIError.platformNotSupported("CoreML not available")
        #endif
    }
    
    // MARK: - Segmentation
    
    func segment(image: ProcessedImage) throws -> SegmentationMask {
        #if canImport(CoreML)
        guard let model = model else {
            throw AIError.modelNotLoaded("Model not loaded")
        }
        
        // Convert processed image to MLFeatureProvider
        let input = try createMLInput(from: image)
        
        // Run prediction
        let output = try model.prediction(from: input)
        
        // Extract segmentation mask
        let mask = try extractSegmentationMask(from: output, width: image.width, height: image.height)
        
        return mask
        #else
        throw AIError.platformNotSupported("CoreML not available")
        #endif
    }
    
    // MARK: - Detection
    
    func detect(image: ProcessedImage, confidenceThreshold: Double, iouThreshold: Double, maxDetections: Int) throws -> [Detection] {
        #if canImport(CoreML)
        guard let model = model else {
            throw AIError.modelNotLoaded("Model not loaded")
        }
        
        // Convert processed image to MLFeatureProvider
        let input = try createMLInput(from: image)
        
        // Run prediction
        let output = try model.prediction(from: input)
        
        // Extract detection results
        var detections = try extractDetections(from: output, confidenceThreshold: confidenceThreshold)
        
        // Apply non-maximum suppression
        detections = applyNMS(detections: detections, iouThreshold: iouThreshold)
        
        // Limit to max detections
        if detections.count > maxDetections {
            detections = Array(detections.prefix(maxDetections))
        }
        
        return detections
        #else
        throw AIError.platformNotSupported("CoreML not available")
        #endif
    }
    
    // MARK: - Enhancement
    
    func enhance(image: ProcessedImage) throws -> ProcessedImage {
        #if canImport(CoreML)
        guard let model = model else {
            throw AIError.modelNotLoaded("Model not loaded")
        }
        
        // Convert processed image to MLFeatureProvider
        let input = try createMLInput(from: image)
        
        // Run prediction
        let output = try model.prediction(from: input)
        
        // Extract enhanced image
        let enhancedImage = try extractEnhancedImage(from: output, sourceImage: image)
        
        return enhancedImage
        #else
        throw AIError.platformNotSupported("CoreML not available")
        #endif
    }
    
    // MARK: - Helper Methods
    
    #if canImport(CoreML)
    private func createMLInput(from image: ProcessedImage) throws -> MLFeatureProvider {
        // This is a simplified implementation
        // Real implementation would need to handle different model input types
        
        guard let model = model else {
            throw AIError.modelNotLoaded("Model not loaded")
        }
        
        let inputDescriptions = model.modelDescription.inputDescriptionsByName
        guard let firstInput = inputDescriptions.first else {
            throw AIError.invalidModelFormat("No input found in model")
        }
        
        let inputName = firstInput.key
        let inputDescription = firstInput.value
        
        // For now, we'll create a simple dictionary-based feature provider
        // Real implementation would convert image data to appropriate format
        let features: [String: Any] = [inputName: image.pixelData as Any]
        
        return try MLDictionaryFeatureProvider(dictionary: features)
    }
    
    private func extractClassificationPredictions(from output: MLFeatureProvider, topK: Int, threshold: Double) throws -> [Prediction] {
        // Try to find classification probabilities in output
        let outputDescriptions = model?.modelDescription.outputDescriptionsByName ?? [:]
        
        var predictions: [Prediction] = []
        
        // Look for common output names
        for (name, description) in outputDescriptions {
            if let multiArray = output.featureValue(for: name)?.multiArrayValue {
                // Convert MultiArray to predictions
                predictions = try extractPredictionsFromMultiArray(multiArray, threshold: threshold)
                break
            } else if let dictionary = output.featureValue(for: name)?.dictionaryValue {
                // Handle dictionary output (label: probability)
                for (label, prob) in dictionary {
                    if let labelStr = label as? String, let probDouble = prob as? Double {
                        if probDouble >= threshold {
                            predictions.append(Prediction(label: labelStr, confidence: probDouble))
                        }
                    }
                }
                break
            }
        }
        
        // Sort by confidence and take top K
        predictions.sort { $0.confidence > $1.confidence }
        return Array(predictions.prefix(topK))
    }
    
    private func extractPredictionsFromMultiArray(_ multiArray: MLMultiArray, threshold: Double) throws -> [Prediction] {
        var predictions: [Prediction] = []
        
        // Assuming the multiArray contains class probabilities
        let count = multiArray.count
        for i in 0..<count {
            let confidence = multiArray[i].doubleValue
            if confidence >= threshold {
                predictions.append(Prediction(label: "class_\(i)", confidence: confidence))
            }
        }
        
        return predictions
    }
    
    private func extractSegmentationMask(from output: MLFeatureProvider, width: Int, height: Int) throws -> SegmentationMask {
        // Try to find segmentation mask in output
        let outputDescriptions = model?.modelDescription.outputDescriptionsByName ?? [:]
        
        for (name, _) in outputDescriptions {
            if let multiArray = output.featureValue(for: name)?.multiArrayValue {
                // Assume multiArray contains segmentation mask
                let maskData = try convertMultiArrayToMask(multiArray)
                return SegmentationMask(width: width, height: height, data: maskData, numClasses: 2)
            }
        }
        
        throw AIError.invalidModelOutput("Could not extract segmentation mask from model output")
    }
    
    private func convertMultiArrayToMask(_ multiArray: MLMultiArray) throws -> Data {
        // Convert MLMultiArray to Data
        let count = multiArray.count
        var data = Data(count: count)
        
        for i in 0..<count {
            let value = multiArray[i].uint8Value
            data[i] = value
        }
        
        return data
    }
    
    private func extractDetections(from output: MLFeatureProvider, confidenceThreshold: Double) throws -> [Detection] {
        // This is a simplified implementation
        // Real detection models would have specific output formats (e.g., YOLO, SSD)
        
        var detections: [Detection] = []
        
        // Try to extract bounding boxes and confidence scores
        // This would need to be customized based on the model architecture
        
        return detections
    }
    
    private func extractEnhancedImage(from output: MLFeatureProvider, sourceImage: ProcessedImage) throws -> ProcessedImage {
        // Extract enhanced image from model output
        let outputDescriptions = model?.modelDescription.outputDescriptionsByName ?? [:]
        
        for (name, _) in outputDescriptions {
            if let multiArray = output.featureValue(for: name)?.multiArrayValue {
                // Convert multiArray to pixel data
                let enhancedPixelData = try convertMultiArrayToPixelData(multiArray)
                
                return ProcessedImage(
                    width: sourceImage.width,
                    height: sourceImage.height,
                    bitsPerPixel: sourceImage.bitsPerPixel,
                    samplesPerPixel: sourceImage.samplesPerPixel,
                    photometricInterpretation: sourceImage.photometricInterpretation,
                    pixelData: enhancedPixelData
                )
            }
        }
        
        throw AIError.invalidModelOutput("Could not extract enhanced image from model output")
    }
    
    private func convertMultiArrayToPixelData(_ multiArray: MLMultiArray) throws -> Data {
        // Convert MLMultiArray to pixel data
        let count = multiArray.count
        var data = Data(count: count * 2) // Assuming 16-bit pixels
        
        for i in 0..<count {
            let value = multiArray[i].uint16Value
            data.withUnsafeMutableBytes { ptr in
                ptr.storeBytes(of: value.littleEndian, toByteOffset: i * 2, as: UInt16.self)
            }
        }
        
        return data
    }
    
    private func applyNMS(detections: [Detection], iouThreshold: Double) -> [Detection] {
        // Non-Maximum Suppression implementation
        var result: [Detection] = []
        var remaining = detections.sorted { $0.confidence > $1.confidence }
        
        while !remaining.isEmpty {
            let best = remaining.removeFirst()
            result.append(best)
            
            remaining = remaining.filter { detection in
                let iou = calculateIoU(best.bbox, detection.bbox)
                return iou < iouThreshold
            }
        }
        
        return result
    }
    
    private func calculateIoU(_ box1: BoundingBox, _ box2: BoundingBox) -> Double {
        let x1 = max(box1.x, box2.x)
        let y1 = max(box1.y, box2.y)
        let x2 = min(box1.x + box1.width, box2.x + box2.width)
        let y2 = min(box1.y + box1.height, box2.y + box2.height)
        
        let intersectionWidth = max(0, x2 - x1)
        let intersectionHeight = max(0, y2 - y1)
        let intersectionArea = intersectionWidth * intersectionHeight
        
        let box1Area = box1.width * box1.height
        let box2Area = box2.width * box2.height
        let unionArea = box1Area + box2Area - intersectionArea
        
        return unionArea > 0 ? intersectionArea / unionArea : 0
    }
    #endif
}

// MARK: - Data Structures

struct ProcessedImage: Sendable {
    let width: Int
    let height: Int
    let bitsPerPixel: Int
    let samplesPerPixel: Int
    let photometricInterpretation: String
    let pixelData: Data
}

struct Prediction: Sendable {
    let label: String
    let confidence: Double
}

struct SegmentationMask: Sendable {
    let width: Int
    let height: Int
    let data: Data
    let numClasses: Int
}

struct Detection: Sendable {
    let label: String
    let confidence: Double
    let bbox: BoundingBox
}

struct BoundingBox: Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

// MARK: - Errors

enum AIError: Error, LocalizedError, Sendable {
    case platformNotSupported(String)
    case modelLoadFailed(String)
    case modelNotLoaded(String)
    case invalidModelFormat(String)
    case invalidModelOutput(String)
    case noPixelData(String)
    case missingMetadata(String)
    case missingOutput(String)
    case invalidLabelsFile(String)
    case notImplemented(String)
    
    var errorDescription: String? {
        switch self {
        case .platformNotSupported(let message),
             .modelLoadFailed(let message),
             .modelNotLoaded(let message),
             .invalidModelFormat(let message),
             .invalidModelOutput(let message),
             .noPixelData(let message),
             .missingMetadata(let message),
             .missingOutput(let message),
             .invalidLabelsFile(let message),
             .notImplemented(let message):
            return message
        }
    }
}
