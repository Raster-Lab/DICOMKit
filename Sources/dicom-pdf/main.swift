import Foundation
import ArgumentParser
import DICOMKit
import DICOMCore
import DICOMDictionary

struct DICOMPdf: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dicom-pdf",
        abstract: "Extract and encapsulate PDF/CDA/3D documents from/to DICOM format",
        discussion: """
            Extract documents (PDF, CDA, STL, OBJ, MTL) from DICOM Encapsulated Document files,
            or encapsulate documents into DICOM format for PACS storage.
            
            Supported document types:
            - PDF (Portable Document Format)
            - CDA (Clinical Document Architecture XML)
            - STL (Stereolithography 3D models)
            - OBJ (Wavefront 3D object files)
            - MTL (Wavefront material files)
            
            Examples:
              # Extract PDF from DICOM
              dicom-pdf report.dcm --output report.pdf --extract
              
              # Create Encapsulated PDF DICOM
              dicom-pdf report.pdf --output report.dcm \\
                --patient-name "DOE^JOHN" \\
                --patient-id "12345" \\
                --title "Radiology Report"
              
              # Extract CDA document
              dicom-pdf cda.dcm --output cda.xml --extract
              
              # Batch extract all documents from directory
              dicom-pdf study/ --output documents/ --extract --recursive
              
              # Encapsulate 3D model
              dicom-pdf model.stl --output model.dcm \\
                --patient-name "SMITH^JANE" \\
                --study-uid "1.2.3.4.5"
            """,
        version: "1.1.5"
    )
    
    @Argument(help: "Input file or directory (DICOM or document)")
    var input: String
    
    @Option(name: .shortAndLong, help: "Output file or directory path")
    var output: String?
    
    @Flag(name: .long, help: "Extract mode: Extract document from DICOM")
    var extract: Bool = false
    
    @Option(name: .long, help: "Patient Name (for encapsulation mode)")
    var patientName: String?
    
    @Option(name: .long, help: "Patient ID (for encapsulation mode)")
    var patientId: String?
    
    @Option(name: .long, help: "Document Title (for encapsulation mode)")
    var title: String?
    
    @Option(name: .long, help: "Study Instance UID (auto-generated if not provided)")
    var studyUid: String?
    
    @Option(name: .long, help: "Series Instance UID (auto-generated if not provided)")
    var seriesUid: String?
    
    @Option(name: .long, help: "Modality (default: DOC for documents, M3D for 3D models)")
    var modality: String?
    
    @Option(name: .long, help: "Series Description")
    var seriesDescription: String?
    
    @Option(name: .long, help: "Series Number")
    var seriesNumber: Int?
    
    @Option(name: .long, help: "Instance Number")
    var instanceNumber: Int?
    
    @Flag(name: .long, help: "Process directories recursively")
    var recursive: Bool = false
    
    @Flag(name: .long, help: "Show document metadata (extract mode)")
    var showMetadata: Bool = false
    
    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false
    
    mutating func run() throws {
        // Validate input exists
        guard FileManager.default.fileExists(atPath: input) else {
            throw ValidationError("Input path not found: \(input)")
        }
        
        // Determine if input is a directory
        var isDirectory: ObjCBool = false
        _ = FileManager.default.fileExists(atPath: input, isDirectory: &isDirectory)
        
        if isDirectory.boolValue {
            guard recursive else {
                throw ValidationError("Directory processing requires --recursive flag")
            }
            
            if extract {
                try extractFromDirectory(inputPath: input, outputPath: output)
            } else {
                try encapsulateFromDirectory(inputPath: input, outputPath: output)
            }
        } else {
            if extract {
                try extractFromFile(inputPath: input, outputPath: output)
            } else {
                try encapsulateFile(inputPath: input, outputPath: output)
            }
        }
    }
    
    // MARK: - Extraction Mode
    
    private func extractFromFile(inputPath: String, outputPath: String?) throws {
        if verbose {
            print("Extracting document from: \(inputPath)")
        }
        
        // Read DICOM file
        let inputData = try Data(contentsOf: URL(fileURLWithPath: inputPath))
        let dicomFile = try DICOMFile.read(from: inputData)
        
        // Parse encapsulated document
        let document = try EncapsulatedDocumentParser.parse(from: dicomFile.dataSet)
        
        // Show metadata if requested
        if showMetadata {
            // Shared renderer (DICOMKit) — emitted verbatim by the Studio reimplementation too.
            print(document.metadataReport(), terminator: "")
        }

        // Determine output path
        let finalOutputPath: String
        if let specifiedOutput = outputPath {
            finalOutputPath = specifiedOutput
        } else {
            // Auto-generate output filename based on document type
            let inputURL = URL(fileURLWithPath: inputPath)
            let baseName = inputURL.deletingPathExtension().lastPathComponent
            let fileExtension = document.documentType.fileExtension
            finalOutputPath = inputURL.deletingLastPathComponent()
                .appendingPathComponent("\(baseName).\(fileExtension)")
                .path
        }

        // Write document data
        try document.documentData.write(to: URL(fileURLWithPath: finalOutputPath))

        if verbose {
            print("✓ Extracted \(document.documentType) (\(EncapsulatedDocumentFormatting.fileSize(Int64(document.documentData.count))))")
            print("  Output: \(finalOutputPath)")
        } else {
            print("Extracted: \(finalOutputPath)")
        }
    }
    
    private func extractFromDirectory(inputPath: String, outputPath: String?) throws {
        let inputURL = URL(fileURLWithPath: inputPath)
        
        // Determine output directory
        let outputDirURL: URL
        if let specifiedOutput = outputPath {
            outputDirURL = URL(fileURLWithPath: specifiedOutput)
        } else {
            outputDirURL = inputURL.appendingPathComponent("extracted")
        }
        
        // Create output directory
        try FileManager.default.createDirectory(at: outputDirURL, withIntermediateDirectories: true)
        
        if verbose {
            print("Extracting documents from: \(inputPath)")
            print("Output directory: \(outputDirURL.path)")
            print()
        }
        
        var successCount = 0
        var failureCount = 0
        var extractedFiles: [String] = []
        
        // Enumerate DICOM files
        let enumerator = FileManager.default.enumerator(
            at: inputURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            // Skip non-files
            guard let isRegularFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                  isRegularFile else {
                continue
            }
            
            // Try to extract from this file
            do {
                let inputData = try Data(contentsOf: fileURL)
                let dicomFile = try DICOMFile.read(from: inputData)
                let document = try EncapsulatedDocumentParser.parse(from: dicomFile.dataSet)
                
                // Generate output filename
                let baseName = fileURL.deletingPathExtension().lastPathComponent
                let fileExtension = document.documentType.fileExtension
                let outputFileURL = outputDirURL.appendingPathComponent("\(baseName).\(fileExtension)")
                
                // Write document data
                try document.documentData.write(to: outputFileURL)
                
                successCount += 1
                extractedFiles.append(outputFileURL.path)
                
                if verbose {
                    print("✓ \(fileURL.lastPathComponent) → \(outputFileURL.lastPathComponent)")
                }
            } catch {
                failureCount += 1
                if verbose {
                    print("✗ \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
        
        // Summary
        print()
        print("Extraction complete:")
        print("  Successful: \(successCount)")
        if failureCount > 0 {
            print("  Failed: \(failureCount)")
        }
        print("  Output directory: \(outputDirURL.path)")
    }
    
    // MARK: - Encapsulation Mode
    
    private func encapsulateFile(inputPath: String, outputPath: String?) throws {
        if verbose {
            print("Encapsulating document: \(inputPath)")
        }
        
        // Read document file
        let documentData = try Data(contentsOf: URL(fileURLWithPath: inputPath))
        
        // Detect document type from file extension (shared DICOMKit mapping)
        let inputURL = URL(fileURLWithPath: inputPath)
        let documentType = EncapsulatedDocumentType(fileExtension: inputURL.pathExtension)

        // Validate required metadata for encapsulation
        guard let patientName = patientName, !patientName.isEmpty else {
            throw ValidationError("Patient Name is required for encapsulation (--patient-name)")
        }

        guard let patientId = patientId, !patientId.isEmpty else {
            throw ValidationError("Patient ID is required for encapsulation (--patient-id)")
        }

        // Generate UIDs if not provided (shared UIDGenerator — same as the app).
        let finalStudyUID = studyUid ?? UIDGenerator.generateUID().value
        let finalSeriesUID = seriesUid ?? UIDGenerator.generateUID().value

        // Determine modality (explicit override, else the document-type default).
        let finalModality: String
        if let m = modality, !m.isEmpty {
            finalModality = m
        } else {
            finalModality = documentType.defaultModality
        }

        // Build encapsulated document (shared option chain).
        let builder = EncapsulatedDocumentBuilder(
            documentData: documentData,
            mimeType: documentType.expectedMIMEType,
            documentType: documentType,
            studyInstanceUID: finalStudyUID,
            seriesInstanceUID: finalSeriesUID
        )
        .applyStandardOptions(
            patientName: patientName,
            patientID: patientId,
            modality: finalModality,
            title: title,
            seriesDescription: seriesDescription,
            seriesNumber: seriesNumber,
            instanceNumber: instanceNumber
        )

        let dataSet = try builder.buildDataSet()
        
        // Create DICOM file
        let dicomFile = DICOMFile.create(
            dataSet: dataSet,
            // F15: the file-meta Media Storage SOP Class UID must equal the dataset's
            // SOP Class UID (PS3.10), not default to Secondary Capture (1.1.7).
            sopClassUID: documentType.sopClassUID,
            transferSyntaxUID: "1.2.840.10008.1.2.1" // Explicit VR Little Endian
        )
        
        // Write DICOM file
        let dicomData = try dicomFile.write()
        
        // Determine output path
        let finalOutputPath: String
        if let specifiedOutput = outputPath {
            finalOutputPath = specifiedOutput
        } else {
            finalOutputPath = inputURL.deletingPathExtension().appendingPathExtension("dcm").path
        }
        
        try dicomData.write(to: URL(fileURLWithPath: finalOutputPath))
        
        if verbose {
            print("✓ Encapsulated \(documentType) (\(EncapsulatedDocumentFormatting.fileSize(Int64(documentData.count))))")
            print("  DICOM size: \(EncapsulatedDocumentFormatting.fileSize(Int64(dicomData.count)))")
            print("  Patient: \(patientName) [\(patientId)]")
            print("  Study UID: \(finalStudyUID)")
            print("  Output: \(finalOutputPath)")
        } else {
            print("Encapsulated: \(finalOutputPath)")
        }
    }
    
    private func encapsulateFromDirectory(inputPath: String, outputPath: String?) throws {
        let inputURL = URL(fileURLWithPath: inputPath)
        
        // Determine output directory
        let outputDirURL: URL
        if let specifiedOutput = outputPath {
            outputDirURL = URL(fileURLWithPath: specifiedOutput)
        } else {
            outputDirURL = inputURL.appendingPathComponent("encapsulated")
        }
        
        // Create output directory
        try FileManager.default.createDirectory(at: outputDirURL, withIntermediateDirectories: true)
        
        if verbose {
            print("Encapsulating documents from: \(inputPath)")
            print("Output directory: \(outputDirURL.path)")
            print()
        }
        
        // Validate required metadata
        guard let patientName = patientName, !patientName.isEmpty else {
            throw ValidationError("Patient Name is required for batch encapsulation (--patient-name)")
        }
        
        guard let patientId = patientId, !patientId.isEmpty else {
            throw ValidationError("Patient ID is required for batch encapsulation (--patient-id)")
        }
        
        var successCount = 0
        var failureCount = 0
        var instanceNum = instanceNumber ?? 1
        
        // Generate series UIDs once for the batch (shared UIDGenerator — same as the app).
        let finalStudyUID = studyUid ?? UIDGenerator.generateUID().value
        let finalSeriesUID = seriesUid ?? UIDGenerator.generateUID().value
        
        // Enumerate document files
        let enumerator = FileManager.default.enumerator(
            at: inputURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            // Skip non-files
            guard let isRegularFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                  isRegularFile else {
                continue
            }
            
            // Check if it's a supported document type (shared DICOMKit mapping)
            let documentType = EncapsulatedDocumentType(fileExtension: fileURL.pathExtension)
            guard documentType != .unknown else {
                if verbose {
                    print("⊘ \(fileURL.lastPathComponent): Unsupported file type")
                }
                continue
            }

            // Try to encapsulate this file
            do {
                let documentData = try Data(contentsOf: fileURL)

                // Determine modality (explicit override, else the document-type default).
                let finalModality: String
                if let m = modality, !m.isEmpty {
                    finalModality = m
                } else {
                    finalModality = documentType.defaultModality
                }

                // Build encapsulated document (shared option chain; batch uses the running instance counter).
                let builder = EncapsulatedDocumentBuilder(
                    documentData: documentData,
                    mimeType: documentType.expectedMIMEType,
                    documentType: documentType,
                    studyInstanceUID: finalStudyUID,
                    seriesInstanceUID: finalSeriesUID
                )
                .applyStandardOptions(
                    patientName: patientName,
                    patientID: patientId,
                    modality: finalModality,
                    title: title,
                    seriesDescription: seriesDescription,
                    seriesNumber: seriesNumber,
                    instanceNumber: instanceNum
                )

                let dataSet = try builder.buildDataSet()
                
                // Create DICOM file
                let dicomFile = DICOMFile.create(
                    dataSet: dataSet,
                    sopClassUID: documentType.sopClassUID,  // F15: match dataset SOP class (PS3.10)
                    transferSyntaxUID: "1.2.840.10008.1.2.1"
                )
                
                let dicomData = try dicomFile.write()
                
                // Generate output filename
                let baseName = fileURL.deletingPathExtension().lastPathComponent
                let outputFileURL = outputDirURL.appendingPathComponent("\(baseName).dcm")
                
                try dicomData.write(to: outputFileURL)
                
                successCount += 1
                instanceNum += 1
                
                if verbose {
                    print("✓ \(fileURL.lastPathComponent) → \(outputFileURL.lastPathComponent)")
                }
            } catch {
                failureCount += 1
                if verbose {
                    print("✗ \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
        
        // Summary
        print()
        print("Encapsulation complete:")
        print("  Successful: \(successCount)")
        if failureCount > 0 {
            print("  Failed: \(failureCount)")
        }
        print("  Study UID: \(finalStudyUID)")
        print("  Series UID: \(finalSeriesUID)")
        print("  Output directory: \(outputDirURL.path)")
    }
    
    // MARK: - Helper Methods
    //
    // Document-type ↔ file-extension mapping, default modality, the byte-size
    // formatter, the `--show-metadata` report, and the builder option chain all
    // moved to DICOMKit's shared `EncapsulatedDocumentWorkflow` so the CLI and the
    // Studio reimplementation cannot drift. UID generation now uses the shared
    // `UIDGenerator` (DICOMCore) — the same generator the app uses.
}

enum ExportFormat: String, ExpressibleByArgument {
    case pdf
    case xml
    case stl
    case obj
    case mtl
    case dicom
}

DICOMPdf.main()

