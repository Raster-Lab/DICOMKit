// DICOMKit Sample Code: Error Handling
//
// This example demonstrates how to:
// - Handle DICOMError cases
// - Implement robust error handling patterns
// - Validate DICOM files
// - Recover from errors
// - Provide user-friendly error messages

import DICOMKit
import Foundation

// MARK: - Example 1: Basic Error Handling

func example1_basicErrorHandling() {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    
    do {
        let file = try DICOMFile.read(from: fileURL)
        print("✅ Successfully loaded DICOM file")
        print("   SOP Class: \(file.sopClassUID)")
    } catch {
        print("❌ Failed to load DICOM file: \(error.localizedDescription)")
    }
}

// MARK: - Example 2: Specific Error Handling

func example2_specificErrors() {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    
    do {
        let file = try DICOMFile.read(from: fileURL)
        print("✅ File loaded successfully")
    } catch DICOMError.invalidPreamble {
        print("❌ Invalid DICOM preamble")
        print("   This might not be a DICOM Part 10 file")
        print("   Try reading with force: true for legacy files")
        
    } catch DICOMError.invalidDICMPrefix {
        print("❌ Missing 'DICM' prefix at offset 128")
        print("   This is not a valid DICOM Part 10 file")
        
    } catch DICOMError.unsupportedTransferSyntax(let uid) {
        print("❌ Unsupported transfer syntax: \(uid)")
        print("   This file uses a compression or encoding not supported by DICOMKit")
        
    } catch DICOMError.unexpectedEndOfData {
        print("❌ Unexpected end of data")
        print("   The file appears to be truncated or corrupted")
        
    } catch DICOMError.invalidVR(let vr) {
        print("❌ Invalid Value Representation: \(vr)")
        print("   The file contains an unrecognized VR")
        
    } catch DICOMError.invalidTag {
        print("❌ Invalid tag format")
        print("   A tag in the file is malformed")
        
    } catch DICOMError.parsingFailed(let message) {
        print("❌ Parsing failed: \(message)")
        
    } catch {
        print("❌ Unexpected error: \(error)")
    }
}

// MARK: - Example 3: Handling Legacy Files

func example3_legacyFiles() {
    let fileURL = URL(fileURLWithPath: "/path/to/legacy/file.dcm")
    
    // First try standard reading
    do {
        let file = try DICOMFile.read(from: fileURL)
        print("✅ Standard DICOM file loaded")
    } catch DICOMError.invalidPreamble, DICOMError.invalidDICMPrefix {
        // If it's not a standard Part 10 file, try forcing
        print("⚠️ Not a standard Part 10 file, trying force mode...")
        
        do {
            let file = try DICOMFile.read(from: fileURL, force: true)
            print("✅ Legacy DICOM file loaded with force mode")
            print("   This file may not have the standard DICOM preamble")
        } catch {
            print("❌ Failed even with force mode: \(error.localizedDescription)")
        }
    } catch {
        print("❌ Other error: \(error.localizedDescription)")
    }
}

// MARK: - Example 4: File Validation

func example4_fileValidation() -> Bool {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    
    // Check 1: File exists
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        print("❌ File does not exist")
        return false
    }
    
    // Check 2: File is readable
    guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
        print("❌ File is not readable (permission denied)")
        return false
    }
    
    // Check 3: File has content
    do {
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        if fileSize == 0 {
            print("❌ File is empty")
            return false
        }
        
        if fileSize < 132 {
            print("❌ File too small to be a valid DICOM file (< 132 bytes)")
            return false
        }
        
        print("   File size: \(fileSize) bytes")
    } catch {
        print("❌ Cannot read file attributes: \(error)")
        return false
    }
    
    // Check 4: Parse as DICOM
    do {
        _ = try DICOMFile.read(from: fileURL)
        print("✅ Valid DICOM file")
        return true
    } catch {
        print("❌ Invalid DICOM file: \(error.localizedDescription)")
        return false
    }
}

// MARK: - Example 5: Bulk File Processing with Error Handling

func example5_bulkProcessing() {
    let directoryURL = URL(fileURLWithPath: "/path/to/study")
    
    do {
        let files = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "dcm" }
        
        var successCount = 0
        var failureCount = 0
        var errors: [(String, Error)] = []
        
        print("Processing \(files.count) files...")
        
        for fileURL in files {
            do {
                let file = try DICOMFile.read(from: fileURL)
                successCount += 1
                
                // Process the file...
                print("✅ \(fileURL.lastPathComponent): \(file.sopInstanceUID)")
                
            } catch {
                failureCount += 1
                errors.append((fileURL.lastPathComponent, error))
                print("❌ \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        // Summary
        print("\n=== Summary ===")
        print("Total: \(files.count)")
        print("Success: \(successCount)")
        print("Failed: \(failureCount)")
        
        if !errors.isEmpty {
            print("\n=== Errors ===")
            for (filename, error) in errors {
                print("\(filename): \(error.localizedDescription)")
            }
        }
        
    } catch {
        print("❌ Cannot read directory: \(error)")
    }
}

// MARK: - Example 6: Error Recovery

func example6_errorRecovery() {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    
    var file: DICOMFile?
    
    // Attempt 1: Standard reading
    do {
        file = try DICOMFile.read(from: fileURL)
        print("✅ Loaded with standard method")
    } catch DICOMError.invalidPreamble, DICOMError.invalidDICMPrefix {
        print("⚠️ Standard method failed, trying force mode...")
        
        // Attempt 2: Force mode for legacy files
        do {
            file = try DICOMFile.read(from: fileURL, force: true)
            print("✅ Loaded with force mode")
        } catch {
            print("❌ Force mode also failed: \(error.localizedDescription)")
        }
    } catch DICOMError.unsupportedTransferSyntax(let uid) {
        print("❌ Unsupported transfer syntax: \(uid)")
        print("   Consider converting this file to a supported transfer syntax")
        
    } catch {
        print("❌ Unrecoverable error: \(error.localizedDescription)")
    }
    
    // Use the file if successfully loaded
    if let file = file {
        print("Successfully recovered and loaded file")
        print("SOP Instance UID: \(file.sopInstanceUID)")
    } else {
        print("Unable to load file after all recovery attempts")
    }
}

// MARK: - Example 7: Safe Tag Access

func example7_safeTagAccess() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    let dataSet = file.dataSet
    
    // Always use optional binding for tag access
    
    // Safe: Returns nil if tag doesn't exist
    if let patientName = dataSet.string(for: .patientName) {
        print("Patient Name: \(patientName)")
    } else {
        print("Patient Name not found")
    }
    
    // Provide defaults for missing tags
    let patientID = dataSet.string(for: .patientID) ?? "Unknown"
    print("Patient ID: \(patientID)")
    
    // Check tag existence before accessing
    if dataSet[.pixelData] != nil {
        print("File contains pixel data")
        
        if let pixelData = file.pixelData {
            print("Dimensions: \(pixelData.descriptor.columns) × \(pixelData.descriptor.rows)")
        }
    } else {
        print("No pixel data (might be SR, PR, or other non-image IOD)")
    }
    
    // Handle sequences safely
    if let element = dataSet[.referencedSeriesSequence],
       case .sequence(let items) = element.value {
        print("Referenced Series Sequence has \(items.count) items")
        
        for item in items {
            let seriesUID = item.uid(for: .seriesInstanceUID)?.uid ?? "Unknown"
            print("  Series: \(seriesUID)")
        }
    }
}

// MARK: - Example 8: User-Friendly Error Messages

func example8_userFriendlyMessages() {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    
    do {
        let file = try DICOMFile.read(from: fileURL)
        print("File loaded successfully")
    } catch let error as DICOMError {
        let userMessage = getUserFriendlyMessage(for: error)
        print("Error: \(userMessage)")
    } catch {
        print("Error: Unable to open file. Please check the file and try again.")
    }
}

func getUserFriendlyMessage(for error: DICOMError) -> String {
    switch error {
    case .invalidPreamble, .invalidDICMPrefix:
        return "This file does not appear to be a valid DICOM file. Please check that you selected the correct file."
        
    case .unsupportedTransferSyntax(let uid):
        return "This DICOM file uses an unsupported compression format (\(uid)). Please convert the file to a supported format."
        
    case .unexpectedEndOfData:
        return "The file appears to be incomplete or corrupted. Please try re-downloading or re-exporting the file."
        
    case .invalidVR(let vr):
        return "The file contains invalid data (VR: \(vr)). It may be corrupted or non-conformant."
        
    case .invalidTag:
        return "The file structure is invalid. It may be corrupted or improperly formatted."
        
    case .parsingFailed(let message):
        return "Unable to read the file: \(message)"
    }
}

// MARK: - Example 9: Logging Errors

func example9_errorLogging() {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    
    do {
        let file = try DICOMFile.read(from: fileURL)
        logSuccess(file: fileURL, sopInstanceUID: file.sopInstanceUID)
    } catch {
        logError(file: fileURL, error: error)
    }
}

func logSuccess(file: URL, sopInstanceUID: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("[\(timestamp)] SUCCESS: \(file.lastPathComponent) - SOP: \(sopInstanceUID)")
}

func logError(file: URL, error: Error) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("[\(timestamp)] ERROR: \(file.lastPathComponent)")
    print("  Type: \(type(of: error))")
    print("  Message: \(error.localizedDescription)")
    
    if let dicomError = error as? DICOMError {
        print("  DICOM Error: \(dicomError)")
    }
}

// MARK: - Example 10: Async Error Handling (Swift Concurrency)

@available(iOS 13.0, macOS 10.15, *)
func example10_asyncErrorHandling() async {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    
    do {
        // Async file reading
        let data = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    let data = try Data(contentsOf: fileURL)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        // Parse DICOM
        let file = try DICOMFile.read(from: data)
        print("✅ Async loaded: \(file.sopInstanceUID)")
        
    } catch {
        print("❌ Async error: \(error.localizedDescription)")
    }
}

// MARK: - Running the Examples

// Uncomment to run individual examples:
// example1_basicErrorHandling()
// example2_specificErrors()
// example3_legacyFiles()
// _ = example4_fileValidation()
// example5_bulkProcessing()
// example6_errorRecovery()
// try? example7_safeTagAccess()
// example8_userFriendlyMessages()
// example9_errorLogging()

// For Swift 5.5+:
// Task {
//     await example10_asyncErrorHandling()
// }

// MARK: - Quick Reference

/*
 DICOMError Cases:
 
 • .invalidPreamble             - Missing or invalid 128-byte preamble
 • .invalidDICMPrefix           - Missing "DICM" at offset 128
 • .unexpectedEndOfData         - File truncated or incomplete
 • .invalidVR(String)           - Unknown Value Representation
 • .unsupportedTransferSyntax(String) - Compression not supported
 • .invalidTag                  - Malformed tag
 • .parsingFailed(String)       - General parsing error
 
 Error Handling Patterns:
 
 1. Basic Try-Catch:
    do {
        let file = try DICOMFile.read(from: url)
    } catch {
        print(error.localizedDescription)
    }
 
 2. Specific Error Handling:
    catch DICOMError.invalidPreamble {
        // Handle specific error
    }
 
 3. Force Mode for Legacy Files:
    try DICOMFile.read(from: url, force: true)
 
 4. Optional Binding:
    if let value = dataSet.string(for: tag) {
        // Use value
    }
 
 5. Default Values:
    let value = dataSet.string(for: tag) ?? "default"
 
 Best Practices:
 
 1. Always handle errors when reading files
 2. Validate files before processing in bulk operations
 3. Use optional binding for tag access
 4. Provide user-friendly error messages
 5. Log errors for debugging
 6. Try force mode for legacy files
 7. Check for required tags before assuming they exist
 8. Handle missing pixel data gracefully
 9. Use do-catch for operations that can fail
 10. Consider async/await for file I/O in apps
 
 Common Scenarios:
 
 • File doesn't exist:          → Check with FileManager before reading
 • Not a DICOM file:            → Catch .invalidPreamble or .invalidDICMPrefix
 • Legacy file:                 → Use force: true
 • Unsupported compression:     → Catch .unsupportedTransferSyntax
 • Corrupted file:              → Catch .unexpectedEndOfData
 • Missing tag:                 → Use optional binding, returns nil
 • Wrong VR type:               → Use correct accessor method for VR
 
 Error Message Localization:
 
 All DICOMError cases conform to LocalizedError, providing
 localized descriptions via error.localizedDescription.
 
 Custom error messages can be created for better UX.
 */
