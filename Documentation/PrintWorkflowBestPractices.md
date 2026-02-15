# Print Workflow Best Practices

Advanced techniques and recommendations for production DICOM printing implementations.

## Overview

This guide covers best practices for implementing DICOM Print Management in production medical imaging applications. It includes performance optimization, error handling strategies, quality control, and workflow integration patterns.

## Production Workflow Design

### 1. Implement Print Queue Management

For applications that handle multiple concurrent print requests, use a centralized print queue:

```swift
actor PrintManager {
    private let queue: PrintQueue
    private let registry: PrinterRegistry
    
    init() {
        self.queue = PrintQueue(
            maxHistorySize: 1000,
            retryPolicy: PrintRetryPolicy(
                maxRetries: 3,
                initialDelay: 2.0,
                maxDelay: 30.0,
                backoffMultiplier: 2.0
            )
        )
        self.registry = PrinterRegistry()
    }
    
    func submitPrintJob(
        images: [Data],
        priority: PrintPriority,
        printerName: String?,
        options: PrintOptions
    ) async throws -> UUID {
        // Select printer
        let printer: PrinterInfo
        if let name = printerName {
            printer = try await registry.getPrinter(name: name)
        } else {
            guard let defaultPrinter = await registry.defaultPrinter() else {
                throw PrintError.printerNotFound(name: "default")
            }
            printer = defaultPrinter
        }
        
        // Create job
        let job = PrintJob(
            configuration: printer.configuration,
            imageURLs: [], // Convert Data to temp URLs if needed
            images: images,
            options: options,
            priority: priority,
            label: "Job \(Date())"
        )
        
        // Enqueue
        return await queue.enqueue(job: job)
    }
}
```

### 2. Printer Status Monitoring

Implement periodic printer status checks:

```swift
actor PrinterHealthMonitor {
    private let registry: PrinterRegistry
    private var monitorTask: Task<Void, Never>?
    
    func startMonitoring(interval: TimeInterval = 60) {
        monitorTask = Task {
            while !Task.isCancelled {
                await checkAllPrinters()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }
    
    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }
    
    private func checkAllPrinters() async {
        let printers = await registry.allPrinters()
        
        for printer in printers {
            do {
                let status = try await DICOMPrintService.getPrinterStatus(
                    configuration: printer.configuration
                )
                
                let isAvailable = status.status == .normal
                await registry.updateAvailability(
                    id: printer.id,
                    isAvailable: isAvailable
                )
                
                if !isAvailable {
                    // Notify admin/user of printer issue
                    await notifyPrinterIssue(printer: printer, status: status)
                }
                
            } catch {
                await registry.updateAvailability(
                    id: printer.id,
                    isAvailable: false
                )
            }
        }
    }
    
    private func notifyPrinterIssue(printer: PrinterInfo, status: PrinterStatus) async {
        // Implement notification (log, email, UI alert, etc.)
        print("⚠️ Printer \(printer.name) issue: \(status.statusInfo)")
    }
}
```

### 3. Automatic Printer Failover

Implement failover to alternate printers:

```swift
func printWithFailover(
    images: [Data],
    options: PrintOptions,
    registry: PrinterRegistry
) async throws -> PrintResult {
    let printers = await registry.availablePrinters(
        requiresColor: options.colorMode == .color,
        filmSize: options.filmSize
    )
    
    guard !printers.isEmpty else {
        throw PrintError.printerUnavailable(message: "No available printers")
    }
    
    var lastError: Error?
    
    for printer in printers {
        do {
            print("Attempting print on: \(printer.name)")
            let result = try await DICOMPrintService.printImages(
                configuration: printer.configuration,
                images: images,
                options: options
            )
            print("✅ Print successful on: \(printer.name)")
            return result
            
        } catch {
            print("❌ Print failed on \(printer.name): \(error)")
            lastError = error
            continue
        }
    }
    
    throw lastError ?? PrintError.printerUnavailable(message: "All printers failed")
}
```

## Image Quality Optimization

### 1. Pre-Processing Pipeline

Implement a standardized image preparation pipeline:

```swift
actor ImagePrintPreparator {
    private let preprocessor = ImagePreprocessor()
    private let resizer = ImageResizer()
    private let annotator = AnnotationRenderer()
    
    func prepareForPrint(
        dicomDataSet: DataSet,
        targetSize: CGSize,
        includeAnnotations: Bool,
        patientName: String?,
        studyDescription: String?
    ) async throws -> Data {
        // Step 1: Preprocess (window/level, polarity, rescale)
        let prepared = try await preprocessor.prepareForPrint(
            dataSet: dicomDataSet,
            targetSize: targetSize,
            colorMode: .grayscale
        )
        
        // Step 2: Resize to optimal dimensions
        let resized = try await resizer.resize(
            pixelData: prepared.pixelData,
            from: CGSize(
                width: Double(prepared.width),
                height: Double(prepared.height)
            ),
            to: targetSize,
            mode: .fit,
            quality: .high
        )
        
        // Step 3: Add annotations if requested
        if includeAnnotations {
            var annotations: [PrintAnnotation] = []
            
            // Add patient info
            if let patientName = patientName {
                annotations.append(
                    PrintAnnotation(
                        text: patientName,
                        position: .topLeft,
                        fontSize: 16,
                        color: .white
                    )
                )
            }
            
            // Add study description
            if let studyDescription = studyDescription {
                annotations.append(
                    PrintAnnotation(
                        text: studyDescription,
                        position: .topRight,
                        fontSize: 14,
                        color: .white
                    )
                )
            }
            
            // Add date/time
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            annotations.append(
                PrintAnnotation(
                    text: dateFormatter.string(from: Date()),
                    position: .bottomRight,
                    fontSize: 12,
                    color: .white
                )
            )
            
            return try await annotator.addAnnotations(
                to: resized,
                imageSize: targetSize,
                annotations: annotations
            )
        }
        
        return resized
    }
}
```

### 2. Modality-Specific Settings

Apply optimal settings based on modality:

```swift
func printOptionsForModality(_ modality: String) -> PrintOptions {
    switch modality.uppercased() {
    case "CT":
        return PrintOptions(
            filmSize: .size14InX17In,
            filmOrientation: .portrait,
            magnificationType: .cubic,
            mediumType: .clearFilm,
            numberOfCopies: 1,
            priority: .medium
        )
        
    case "MR":
        return PrintOptions(
            filmSize: .size14InX17In,
            filmOrientation: .portrait,
            magnificationType: .cubic,
            mediumType: .clearFilm,
            numberOfCopies: 1,
            priority: .medium
        )
        
    case "MG": // Mammography
        return .mammography
        
    case "US": // Ultrasound
        return PrintOptions(
            filmSize: .size11InX14In,
            filmOrientation: .portrait,
            magnificationType: .replicate,
            mediumType: .clearFilm,
            numberOfCopies: 1,
            priority: .low
        )
        
    case "CR", "DX": // Computed/Digital Radiography
        return PrintOptions(
            filmSize: .size14InX17In,
            filmOrientation: .portrait,
            magnificationType: .cubic,
            mediumType: .blueFilm,
            numberOfCopies: 1,
            priority: .medium
        )
        
    default:
        return .default
    }
}
```

### 3. Quality Validation

Validate images before printing:

```swift
func validateForPrint(dicomDataSet: DataSet) throws {
    // Check required attributes
    guard dicomDataSet.string(for: .sopInstanceUID) != nil else {
        throw PrintError.invalidImage(message: "Missing SOP Instance UID")
    }
    
    guard let rows = dicomDataSet.uint16(for: .rows),
          let cols = dicomDataSet.uint16(for: .columns),
          rows > 0, cols > 0 else {
        throw PrintError.invalidImage(message: "Invalid image dimensions")
    }
    
    // Check minimum resolution
    let minDimension = min(rows, cols)
    guard minDimension >= 256 else {
        throw PrintError.invalidImage(
            message: "Image resolution too low: \(rows)×\(cols)"
        )
    }
    
    // Check pixel data exists
    guard dicomDataSet.data(for: .pixelData) != nil else {
        throw PrintError.invalidImage(message: "Missing pixel data")
    }
    
    // Warn if aspect ratio unusual
    let aspectRatio = Double(rows) / Double(cols)
    if aspectRatio > 2.0 || aspectRatio < 0.5 {
        print("⚠️ Unusual aspect ratio: \(aspectRatio)")
    }
}
```

## Performance Optimization

### 1. Batch Processing

Process multiple images in parallel:

```swift
func prepareBatchForPrint(
    dataSets: [DataSet],
    targetSize: CGSize
) async throws -> [Data] {
    let preparator = ImagePrintPreparator()
    
    return try await withThrowingTaskGroup(of: (Int, Data).self) { group in
        for (index, dataSet) in dataSets.enumerated() {
            group.addTask {
                let prepared = try await preparator.prepareForPrint(
                    dicomDataSet: dataSet,
                    targetSize: targetSize,
                    includeAnnotations: true,
                    patientName: dataSet.string(for: .patientName),
                    studyDescription: dataSet.string(for: .studyDescription)
                )
                return (index, prepared)
            }
        }
        
        var results = [(Int, Data)]()
        for try await result in group {
            results.append(result)
        }
        
        // Sort by index to maintain order
        results.sort { $0.0 < $1.0 }
        return results.map { $0.1 }
    }
}
```

### 2. Memory Management

Handle large image batches efficiently:

```swift
actor MemoryEfficientPrinter {
    private let maxConcurrentImages = 5
    
    func printLargeBatch(
        imageURLs: [URL],
        configuration: PrintConfiguration,
        options: PrintOptions
    ) async throws {
        // Process in chunks to avoid memory pressure
        let chunks = imageURLs.chunked(into: maxConcurrentImages)
        
        for (chunkIndex, chunk) in chunks.enumerated() {
            print("Processing chunk \(chunkIndex + 1) of \(chunks.count)")
            
            // Load chunk
            let images = try chunk.map { url -> Data in
                let file = try DICOMFile(path: url.path)
                let pixelData = try file.extractPixelData()
                return pixelData.data
            }
            
            // Print chunk
            let result = try await DICOMPrintService.printImages(
                configuration: configuration,
                images: images,
                options: options
            )
            
            print("✅ Chunk \(chunkIndex + 1) printed: \(result.printJobUID)")
            
            // Allow memory to be reclaimed
            try await Task.sleep(for: .seconds(0.5))
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
```

### 3. Connection Pooling

Reuse connections for multiple print jobs:

```swift
actor PrintConnectionPool {
    private var connections: [UUID: PrintConnection] = [:]
    private let maxConnections = 3
    
    struct PrintConnection {
        let id: UUID
        let configuration: PrintConfiguration
        var lastUsed: Date
        var inUse: Bool
    }
    
    func acquireConnection(
        configuration: PrintConfiguration
    ) async -> PrintConnection {
        // Find available connection for this config
        if let connection = connections.values.first(where: {
            $0.configuration.host == configuration.host &&
            $0.configuration.port == configuration.port &&
            !$0.inUse
        }) {
            var updated = connection
            updated.inUse = true
            updated.lastUsed = Date()
            connections[connection.id] = updated
            return updated
        }
        
        // Create new connection if under limit
        if connections.count < maxConnections {
            let connection = PrintConnection(
                id: UUID(),
                configuration: configuration,
                lastUsed: Date(),
                inUse: true
            )
            connections[connection.id] = connection
            return connection
        }
        
        // Wait for available connection
        try? await Task.sleep(for: .seconds(1))
        return await acquireConnection(configuration: configuration)
    }
    
    func releaseConnection(id: UUID) {
        if var connection = connections[id] {
            connection.inUse = false
            connection.lastUsed = Date()
            connections[id] = connection
        }
    }
    
    func cleanupOldConnections(olderThan: TimeInterval = 300) {
        let cutoff = Date().addingTimeInterval(-olderThan)
        connections = connections.filter { _, conn in
            conn.inUse || conn.lastUsed > cutoff
        }
    }
}
```

## Error Handling Strategies

### 1. Comprehensive Error Recovery

Implement retry logic with exponential backoff:

```swift
func printWithRetry(
    images: [Data],
    configuration: PrintConfiguration,
    options: PrintOptions,
    maxRetries: Int = 3
) async throws -> PrintResult {
    var attempt = 0
    var lastError: Error?
    
    while attempt < maxRetries {
        do {
            return try await DICOMPrintService.printImages(
                configuration: configuration,
                images: images,
                options: options
            )
        } catch let error as PrintError {
            lastError = error
            attempt += 1
            
            // Determine if retry makes sense
            let shouldRetry = switch error {
            case .connectionFailed, .timeout, .networkError:
                true  // Network issues - retry
            case .printerUnavailable:
                false // Printer offline - don't retry
            case .insufficientMemory:
                false // Memory issue - don't retry
            default:
                attempt < 2  // Retry once for other errors
            }
            
            guard shouldRetry && attempt < maxRetries else {
                throw error
            }
            
            // Exponential backoff
            let delay = Double(attempt) * Double(attempt) * 2.0
            print("⚠️ Print attempt \(attempt) failed, retrying in \(delay)s...")
            try await Task.sleep(for: .seconds(delay))
            
        } catch {
            throw error
        }
    }
    
    throw lastError ?? PrintError.unknown(message: "Max retries exceeded")
}
```

### 2. Partial Failure Handling

Handle scenarios where some images fail:

```swift
func handlePartialPrintResult(_ result: PrintResult) async throws {
    guard let partial = result as? PartialPrintResult else {
        // Complete success
        return
    }
    
    if partial.isPartiallySuccessful {
        print("⚠️ Partial print: \(partial.successCount) of \(partial.totalCount) succeeded")
        
        // Log failed positions
        for (index, error) in zip(partial.failedPositions, partial.errors) {
            print("  Position \(index): \(error.description)")
        }
        
        // Attempt to reprint failed images
        if partial.failureCount <= 3 {
            print("Retrying failed images...")
            // Implementation depends on your data model
            // Extract and retry only the failed images
        }
    } else {
        // All failed
        throw PrintError.batchPrintFailed(
            message: "All \(partial.totalCount) images failed"
        )
    }
}
```

### 3. User-Friendly Error Messages

Provide actionable feedback:

```swift
func userFriendlyErrorMessage(for error: PrintError) -> (title: String, message: String, actions: [String]) {
    switch error {
    case .printerUnavailable(let message):
        return (
            title: "Printer Unavailable",
            message: "The printer is currently offline or not responding.\n\nDetails: \(message)",
            actions: ["Check printer power", "Verify network connection", "Contact IT support"]
        )
        
    case .connectionFailed(let message):
        return (
            title: "Connection Failed",
            message: "Unable to connect to the printer.\n\nDetails: \(message)",
            actions: ["Check printer address", "Verify firewall settings", "Test network connectivity"]
        )
        
    case .insufficientMemory:
        return (
            title: "Printer Memory Full",
            message: "The printer does not have enough memory for this print job.",
            actions: ["Reduce number of images", "Use smaller film size", "Wait and try again"]
        )
        
    case .filmSessionCreationFailed(let statusCode):
        return (
            title: "Print Setup Failed",
            message: "Unable to start print session (Status: \(statusCode)).",
            actions: ["Check printer film supply", "Verify printer is ready", "Contact administrator"]
        )
        
    default:
        return (
            title: "Print Error",
            message: error.description,
            actions: [error.recoverySuggestion]
        )
    }
}
```

## Security and Compliance

### 1. Audit Logging

Log all print operations:

```swift
actor PrintAuditLogger {
    private let logPath: String
    
    func logPrintAttempt(
        user: String,
        patientID: String,
        studyUID: String,
        numberOfImages: Int,
        printer: String,
        timestamp: Date = Date()
    ) async {
        let entry = """
        [\(timestamp.ISO8601Format())] PRINT_ATTEMPT
        User: \(user)
        Patient: \(patientID)
        Study: \(studyUID)
        Images: \(numberOfImages)
        Printer: \(printer)
        """
        
        await appendToLog(entry)
    }
    
    func logPrintSuccess(
        printJobUID: String,
        duration: TimeInterval
    ) async {
        let entry = """
        [\(Date().ISO8601Format())] PRINT_SUCCESS
        Job: \(printJobUID)
        Duration: \(String(format: "%.2f", duration))s
        """
        
        await appendToLog(entry)
    }
    
    func logPrintFailure(
        error: Error,
        user: String,
        studyUID: String
    ) async {
        let entry = """
        [\(Date().ISO8601Format())] PRINT_FAILURE
        User: \(user)
        Study: \(studyUID)
        Error: \(error.localizedDescription)
        """
        
        await appendToLog(entry)
    }
    
    private func appendToLog(_ entry: String) async {
        // Implementation: write to file, database, or logging service
        print(entry)
    }
}
```

### 2. PHI Protection

Remove patient identifiers when appropriate:

```swift
func anonymizeForPrint(dataSet: DataSet) -> DataSet {
    var anonymized = dataSet
    
    // Remove or replace patient identifiers
    anonymized.setString("ANONYMOUS", for: .patientName)
    anonymized.setString("00000000", for: .patientID)
    anonymized.setString("", for: .patientBirthDate)
    
    // Keep clinical data needed for interpretation
    // (modality, study date, body part, etc.)
    
    return anonymized
}
```

## Testing Strategy

### 1. Unit Tests for Print Logic

```swift
import XCTest
@testable import DICOMNetwork

class PrintWorkflowTests: XCTestCase {
    func testPrintOptionsForModality() {
        let ctOptions = printOptionsForModality("CT")
        XCTAssertEqual(ctOptions.filmSize, .size14InX17In)
        XCTAssertEqual(ctOptions.mediumType, .clearFilm)
        
        let mammoOptions = printOptionsForModality("MG")
        XCTAssertEqual(mammoOptions.priority, .high)
    }
    
    func testImageValidation() throws {
        var validDataSet = DataSet()
        validDataSet.setString("1.2.3.4.5", for: .sopInstanceUID)
        validDataSet.setUInt16(512, for: .rows)
        validDataSet.setUInt16(512, for: .columns)
        validDataSet.setData(Data(repeating: 0, count: 512 * 512), for: .pixelData)
        
        XCTAssertNoThrow(try validateForPrint(dicomDataSet: validDataSet))
    }
}
```

### 2. Integration Tests with Print SCP

```swift
func testEndToEndPrintWorkflow() async throws {
    // Requires DCM4CHEE or Orthanc running on localhost:11112
    let config = PrintConfiguration(
        host: "localhost",
        port: 11112,
        callingAETitle: "TEST",
        calledAETitle: "PRINT_SCP"
    )
    
    // Test data
    let testImage = Data(repeating: 128, count: 512 * 512)
    
    // Execute print
    let result = try await DICOMPrintService.printImage(
        configuration: config,
        imageData: testImage,
        options: .default
    )
    
    XCTAssertNotNil(result.printJobUID)
    XCTAssertNotNil(result.filmSessionUID)
}
```

## Monitoring and Metrics

Track key performance indicators:

```swift
actor PrintMetrics {
    private var totalPrints: Int = 0
    private var successfulPrints: Int = 0
    private var failedPrints: Int = 0
    private var totalImages: Int = 0
    private var averageDuration: TimeInterval = 0
    
    func recordPrintAttempt(
        images: Int,
        success: Bool,
        duration: TimeInterval
    ) {
        totalPrints += 1
        totalImages += images
        
        if success {
            successfulPrints += 1
        } else {
            failedPrints += 1
        }
        
        // Update moving average
        let totalDuration = averageDuration * Double(totalPrints - 1) + duration
        averageDuration = totalDuration / Double(totalPrints)
    }
    
    func getMetrics() -> PrintMetricsReport {
        PrintMetricsReport(
            totalPrints: totalPrints,
            successRate: Double(successfulPrints) / Double(max(1, totalPrints)),
            averageDuration: averageDuration,
            totalImages: totalImages,
            averageImagesPerPrint: Double(totalImages) / Double(max(1, totalPrints))
        )
    }
}

struct PrintMetricsReport {
    let totalPrints: Int
    let successRate: Double
    let averageDuration: TimeInterval
    let totalImages: Int
    let averageImagesPerPrint: Double
    
    var description: String {
        """
        Print Metrics Report
        -------------------
        Total Prints: \(totalPrints)
        Success Rate: \(String(format: "%.1f%%", successRate * 100))
        Average Duration: \(String(format: "%.2fs", averageDuration))
        Total Images: \(totalImages)
        Avg Images/Print: \(String(format: "%.1f", averageImagesPerPrint))
        """
    }
}
```

## Conclusion

Following these best practices will help you build robust, efficient, and user-friendly DICOM printing functionality. Remember to:

- ✅ Implement comprehensive error handling
- ✅ Use print queues for production workloads
- ✅ Monitor printer health proactively
- ✅ Optimize image quality for each modality
- ✅ Manage resources efficiently
- ✅ Log operations for audit trails
- ✅ Test thoroughly before deployment

## See Also

- [Getting Started with DICOM Printing](GettingStartedWithPrinting.md)
- [Troubleshooting Print Issues](TroubleshootingPrint.md)
- [Print Management API Reference](../Sources/DICOMNetwork/DICOMNetwork.docc/PrintManagementGuide.md)
