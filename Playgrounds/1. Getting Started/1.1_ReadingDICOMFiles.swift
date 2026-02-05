// DICOMKit Sample Code: Reading DICOM Files
//
// This example demonstrates how to:
// - Import DICOMKit framework
// - Read a DICOM file from disk
// - Access file meta information
// - Handle common errors
// - Load multiple files

import DICOMKit
import Foundation

// MARK: - Example 1: Basic File Reading

func example1_basicReading() throws {
    // Read a DICOM file from a URL
    // Replace with path to your DICOM file
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    
    let dicomFile = try DICOMFile(contentsOf: fileURL)
    
    // Access file meta information
    print("Transfer Syntax: \(dicomFile.transferSyntax)")
    print("SOP Class UID: \(dicomFile.sopClassUID)")
    print("SOP Instance UID: \(dicomFile.sopInstanceUID)")
}

// MARK: - Example 2: Error Handling

func example2_errorHandling() {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    
    do {
        let file = try DICOMFile(contentsOf: fileURL)
        print("Successfully loaded DICOM file")
        print("SOP Class: \(file.sopClassUID)")
    } catch let error as DICOMError {
        switch error {
        case .invalidFile:
            print("Error: Not a valid DICOM file")
        case .unsupportedTransferSyntax(let uid):
            print("Error: Unsupported transfer syntax: \(uid)")
        case .corruptedData:
            print("Error: File data is corrupted")
        default:
            print("Error: \(error.localizedDescription)")
        }
    } catch {
        print("Unexpected error: \(error)")
    }
}

// MARK: - Example 3: Loading Multiple Files

func example3_multipleFiles() throws {
    // Load all DICOM files from a directory
    let directory = URL(fileURLWithPath: "/path/to/study/directory")
    
    let fileManager = FileManager.default
    let files = try fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
    )
    .filter { $0.pathExtension == "dcm" }
    
    print("Found \(files.count) DICOM files")
    
    for fileURL in files {
        if let file = try? DICOMFile(contentsOf: fileURL) {
            print("Loaded: \(file.sopInstanceUID)")
        } else {
            print("Failed to load: \(fileURL.lastPathComponent)")
        }
    }
}

// MARK: - Example 4: Checking File Validity

func example4_checkValidity() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    
    // Check if file exists
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        print("File does not exist")
        return
    }
    
    // Attempt to read
    do {
        let file = try DICOMFile(contentsOf: fileURL)
        print("✅ Valid DICOM file")
        print("   Transfer Syntax: \(file.transferSyntax)")
        
        // Check if it has pixel data
        if file.pixelData != nil {
            print("   Contains pixel data")
        } else {
            print("   No pixel data (might be a non-image IOD)")
        }
    } catch {
        print("❌ Invalid or corrupted DICOM file: \(error)")
    }
}

// MARK: - Example 5: Reading from Data

func example5_readingFromData() throws {
    // You can also read DICOM from Data (e.g., from network download)
    let fileURL = URL(fileURLWithPath: "/path/to/your/file.dcm")
    let data = try Data(contentsOf: fileURL)
    
    // Parse DICOM from data
    let dicomFile = try DICOMFile(data: data)
    
    print("Loaded from Data")
    print("Size: \(data.count) bytes")
    print("SOP Instance UID: \(dicomFile.sopInstanceUID)")
}

// MARK: - Running the Examples

// Uncomment to run individual examples:
// try? example1_basicReading()
// example2_errorHandling()
// try? example3_multipleFiles()
// try? example4_checkValidity()
// try? example5_readingFromData()

// MARK: - Quick Reference

/*
 Key DICOMKit Types for File Reading:
 
 • DICOMFile          - Main class for reading DICOM files
 • DICOMError         - Error types thrown by DICOMKit
 • Tag                - Represents a DICOM tag (group, element)
 • DataElement        - Individual tag with value
 
 Common DICOMFile Properties:
 
 • transferSyntax     - Transfer syntax UID
 • sopClassUID        - SOP Class UID
 • sopInstanceUID     - SOP Instance UID
 • elements           - All data elements in the file
 • pixelData          - Pixel data (if present)
 
 Common Initializers:
 
 • init(contentsOf:)  - Read from file URL
 • init(data:)        - Parse from Data
 
 Common Error Types:
 
 • .invalidFile              - Not a DICOM file
 • .unsupportedTransferSyntax - Transfer syntax not supported
 • .corruptedData            - File is corrupted
 • .missingRequiredTag       - Required tag missing
 
 Tips:
 
 1. Always handle errors when reading files
 2. Use optional binding (if let) for safer access
 3. Check for pixel data before assuming file contains images
 4. DICOM files typically have .dcm extension but may vary
 5. File meta information is required in Part 10 files
 */
