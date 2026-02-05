// DICOMKit Sample Code: Transfer Syntax Handling
//
// This example demonstrates how to:
// - Detect transfer syntax of DICOM files
// - Work with uncompressed formats
// - Handle compressed pixel data
// - Understand byte order (endianness)
// - Best practices for transfer syntax handling
// - Common transfer syntaxes by modality

import DICOMKit
import Foundation

// MARK: - Example 1: Detecting Transfer Syntax

func example1_detectTransferSyntax() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    print("File Transfer Syntax Information:")
    print("  Transfer Syntax UID: \(file.transferSyntaxUID)")
    
    // Look up transfer syntax name
    let transferSyntaxName = getTransferSyntaxName(file.transferSyntaxUID)
    print("  Transfer Syntax Name: \(transferSyntaxName)")
    
    // Check characteristics
    let isCompressed = isCompressedTransferSyntax(file.transferSyntaxUID)
    let isLittleEndian = !file.transferSyntaxUID.contains("1.2.2") // Big Endian marker
    let isExplicitVR = file.transferSyntaxUID != "1.2.840.10008.1.2" // Implicit VR
    
    print("\nCharacteristics:")
    print("  Compressed: \(isCompressed ? "Yes" : "No")")
    print("  Byte Order: \(isLittleEndian ? "Little Endian" : "Big Endian")")
    print("  VR: \(isExplicitVR ? "Explicit" : "Implicit")")
}

// Helper function to get transfer syntax name
func getTransferSyntaxName(_ uid: String) -> String {
    switch uid {
    case "1.2.840.10008.1.2":
        return "Implicit VR Little Endian"
    case "1.2.840.10008.1.2.1":
        return "Explicit VR Little Endian"
    case "1.2.840.10008.1.2.2":
        return "Explicit VR Big Endian"
    case "1.2.840.10008.1.2.1.99":
        return "Deflated Explicit VR Little Endian"
    case "1.2.840.10008.1.2.4.50":
        return "JPEG Baseline (Process 1)"
    case "1.2.840.10008.1.2.4.51":
        return "JPEG Extended (Process 2 & 4)"
    case "1.2.840.10008.1.2.4.57":
        return "JPEG Lossless, Non-Hierarchical (Process 14)"
    case "1.2.840.10008.1.2.4.70":
        return "JPEG Lossless, Non-Hierarchical, First-Order Prediction"
    case "1.2.840.10008.1.2.4.90":
        return "JPEG 2000 Image Compression (Lossless Only)"
    case "1.2.840.10008.1.2.4.91":
        return "JPEG 2000 Image Compression"
    case "1.2.840.10008.1.2.5":
        return "RLE Lossless"
    default:
        return "Unknown (\(uid))"
    }
}

// Helper function to check if compressed
func isCompressedTransferSyntax(_ uid: String) -> Bool {
    return uid.contains("1.2.4") || uid.contains("1.2.5") || uid.contains(".99")
}

// MARK: - Example 2: Common Transfer Syntaxes

func example2_commonTransferSyntaxes() {
    print("Common DICOM Transfer Syntaxes:")
    
    print("\n1. Uncompressed (Most Common):")
    print("   • Implicit VR Little Endian (1.2.840.10008.1.2)")
    print("     - Default transfer syntax")
    print("     - VR must be inferred from data dictionary")
    print("     - Little endian byte order")
    print("   • Explicit VR Little Endian (1.2.840.10008.1.2.1)")
    print("     - VR explicitly specified in data elements")
    print("     - Little endian byte order")
    print("     - Recommended for new implementations")
    
    print("\n2. Compressed (Pixel Data Only):")
    print("   • JPEG Baseline (1.2.840.10008.1.2.4.50)")
    print("     - 8-bit lossy compression")
    print("     - Common in CT, MR")
    print("   • JPEG Lossless (1.2.840.10008.1.2.4.70)")
    print("     - Lossless compression")
    print("     - First-order prediction")
    print("   • JPEG 2000 Lossless (1.2.840.10008.1.2.4.90)")
    print("     - Modern lossless compression")
    print("     - Better compression than JPEG Lossless")
    print("   • JPEG 2000 (1.2.840.10008.1.2.4.91)")
    print("     - Lossy compression option")
    print("   • RLE Lossless (1.2.840.10008.1.2.5)")
    print("     - Run-length encoding")
    print("     - Simple lossless compression")
    
    print("\n3. Special Cases:")
    print("   • Deflated Explicit VR (1.2.840.10008.1.2.1.99)")
    print("     - ZIP/deflate compression on entire dataset")
    print("     - Not just pixel data")
    print("   • Explicit VR Big Endian (1.2.840.10008.1.2.2)")
    print("     - Deprecated, rarely used")
    print("     - Big endian byte order")
}

// MARK: - Example 3: Working with Uncompressed Pixel Data

func example3_uncompressedPixelData() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/uncompressed/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("❌ No pixel data")
        return
    }
    
    print("Uncompressed Pixel Data:")
    print("  Transfer Syntax: \(getTransferSyntaxName(file.transferSyntaxUID))")
    print("  Rows: \(pixelData.rows)")
    print("  Columns: \(pixelData.columns)")
    print("  Frames: \(pixelData.numberOfFrames)")
    print("  Bits Allocated: \(pixelData.bitsAllocated)")
    print("  Samples per Pixel: \(pixelData.samplesPerPixel)")
    
    // Calculate expected size
    let bytesPerSample = pixelData.bitsAllocated / 8
    let expectedSize = pixelData.rows * pixelData.columns * 
                      pixelData.numberOfFrames * 
                      pixelData.samplesPerPixel * 
                      bytesPerSample
    
    print("  Expected pixel data size: \(expectedSize) bytes")
    
    // Access raw frame data
    if let frameData = try? pixelData.frameData(at: 0) {
        print("  Actual frame 0 size: \(frameData.count) bytes")
    }
}

// MARK: - Example 4: Handling Compressed Pixel Data

func example4_compressedPixelData() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/compressed/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    
    guard let pixelData = file.pixelData else {
        print("❌ No pixel data")
        return
    }
    
    let isCompressed = isCompressedTransferSyntax(file.transferSyntaxUID)
    
    print("Pixel Data Information:")
    print("  Transfer Syntax: \(getTransferSyntaxName(file.transferSyntaxUID))")
    print("  Compressed: \(isCompressed ? "Yes" : "No")")
    
    if isCompressed {
        print("\nCompressed Pixel Data Handling:")
        print("  • DICOMKit automatically decompresses when creating CGImage")
        print("  • Compression only affects pixel data, not metadata")
        print("  • Multiple frames may be compressed separately")
        
        // DICOMKit handles decompression transparently
        #if canImport(CoreGraphics)
        if let image = try pixelData.createCGImage(frame: 0) {
            print("\n✅ Decompressed and created image: \(image.width)×\(image.height)")
        }
        #endif
    } else {
        print("\n✅ Uncompressed pixel data - no decompression needed")
    }
}

// MARK: - Example 5: Transfer Syntax by Modality

func example5_transferSyntaxByModality() {
    print("Typical Transfer Syntaxes by Modality:")
    
    print("\nCT (Computed Tomography):")
    print("  • Explicit VR Little Endian (most common)")
    print("  • JPEG Baseline for lossy compression")
    print("  • JPEG Lossless for archival")
    
    print("\nMR (Magnetic Resonance):")
    print("  • Explicit VR Little Endian (most common)")
    print("  • JPEG 2000 for modern systems")
    print("  • Uncompressed for processing")
    
    print("\nUS (Ultrasound):")
    print("  • JPEG Baseline for color doppler")
    print("  • RLE Lossless for loops")
    print("  • Explicit VR Little Endian")
    
    print("\nCR/DX (Digital Radiography):")
    print("  • JPEG 2000 Lossless (high quality)")
    print("  • JPEG Baseline for previews")
    print("  • Explicit VR Little Endian")
    
    print("\nSC (Secondary Capture):")
    print("  • JPEG Baseline (screenshots)")
    print("  • Explicit VR Little Endian")
    
    print("\nPT (PET):")
    print("  • Explicit VR Little Endian (16-bit)")
    print("  • JPEG 2000 Lossless for archival")
    
    print("\nNM (Nuclear Medicine):")
    print("  • Explicit VR Little Endian")
    print("  • Uncompressed (processing required)")
}

// MARK: - Example 6: Checking Transfer Syntax Support

func example6_checkTransferSyntaxSupport() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/file.dcm")
    
    do {
        let file = try DICOMFile.read(from: fileURL)
        print("✅ Transfer syntax supported: \(getTransferSyntaxName(file.transferSyntaxUID))")
        
        // Try to access pixel data to verify full support
        if let pixelData = file.pixelData {
            #if canImport(CoreGraphics)
            if let _ = try? pixelData.createCGImage(frame: 0) {
                print("✅ Pixel data decompression supported")
            } else {
                print("⚠️  Pixel data present but image creation failed")
            }
            #endif
        } else {
            print("ℹ️  No pixel data in file")
        }
        
    } catch DICOMError.unsupportedTransferSyntax(let uid) {
        print("❌ Unsupported transfer syntax: \(getTransferSyntaxName(uid))")
        print("   UID: \(uid)")
    } catch {
        print("❌ Error: \(error)")
    }
}

// MARK: - Example 7: Byte Order Considerations

func example7_byteOrderConsiderations() {
    print("Byte Order (Endianness) in DICOM:")
    
    print("\nLittle Endian (Most Common):")
    print("  • Least significant byte first")
    print("  • Used by most DICOM files")
    print("  • Native format for Intel/AMD processors")
    print("  • Transfer Syntax: 1.2.840.10008.1.2, 1.2.840.10008.1.2.1")
    
    print("\nBig Endian (Deprecated):")
    print("  • Most significant byte first")
    print("  • Transfer Syntax: 1.2.840.10008.1.2.2")
    print("  • Deprecated since 2016")
    print("  • Rarely encountered")
    
    print("\nExample:")
    print("  Value: 256 (decimal) = 0x0100")
    print("  Little Endian bytes: [0x00, 0x01]")
    print("  Big Endian bytes: [0x01, 0x00]")
    
    print("\nDICOMKit handles byte order automatically based on transfer syntax")
}

// MARK: - Example 8: Encapsulated vs Native Pixel Data

func example8_encapsulatedVsNative() throws {
    let fileURL = URL(fileURLWithPath: "/path/to/file.dcm")
    let file = try DICOMFile.read(from: fileURL)
    let dataSet = file.dataSet
    
    // Check if pixel data is encapsulated (compressed)
    let isEncapsulated = isCompressedTransferSyntax(file.transferSyntaxUID)
    
    print("Pixel Data Format:")
    print("  Transfer Syntax: \(getTransferSyntaxName(file.transferSyntaxUID))")
    print("  Format: \(isEncapsulated ? "Encapsulated" : "Native")")
    
    if isEncapsulated {
        print("\nEncapsulated Pixel Data:")
        print("  • Stored in DICOM encapsulation format")
        print("  • Contains offset table and fragments")
        print("  • Each frame may be separate fragment")
        print("  • Compressed data (JPEG, JPEG 2000, RLE)")
        
        // Offset table information
        print("\nStructure:")
        print("  1. Basic Offset Table (optional)")
        print("  2. Pixel Data Fragments")
        print("  3. Sequence Delimiter Item")
    } else {
        print("\nNative Pixel Data:")
        print("  • Stored as contiguous bytes")
        print("  • Direct pixel value access")
        print("  • No compression")
        print("  • Simpler to process")
    }
}

// MARK: - Example 9: Transfer Syntax Negotiation Concepts

func example9_transferSyntaxNegotiation() {
    print("Transfer Syntax Negotiation (DICOM Networking):")
    
    print("\nWhen Sending Files (C-STORE SCU):")
    print("  1. Propose one or more transfer syntaxes")
    print("  2. Include original file's transfer syntax")
    print("  3. Optionally propose uncompressed as fallback")
    print("  4. Receiver accepts one transfer syntax")
    print("  5. Send in accepted transfer syntax")
    
    print("\nCommon Strategies:")
    print("  • Preserve Original: Keep file's original encoding")
    print("  • Decompress All: Convert to Explicit VR Little Endian")
    print("  • Compress for Network: Convert to JPEG 2000")
    print("  • Universal Support: Use Implicit VR Little Endian")
    
    print("\nNegotiation Example:")
    print("  SCU Proposes:")
    print("    1. JPEG 2000 Lossless (1.2.840.10008.1.2.4.90)")
    print("    2. JPEG Lossless (1.2.840.10008.1.2.4.70)")
    print("    3. Explicit VR Little Endian (1.2.840.10008.1.2.1)")
    print("  SCP Accepts:")
    print("    → Explicit VR Little Endian (1.2.840.10008.1.2.1)")
    print("  Result:")
    print("    → SCU must send in Explicit VR Little Endian")
    
    print("\nDICOMKit Support:")
    print("  • Reads all common transfer syntaxes")
    print("  • Writes uncompressed formats")
    print("  • Automatic decompression on read")
    print("  • Negotiation handled by DICOMNetwork module")
}

// MARK: - Example 10: Best Practices

func example10_bestPractices() {
    print("Transfer Syntax Best Practices:")
    
    print("\n1. Reading Files:")
    print("  ✅ Check transfer syntax before processing")
    print("  ✅ Handle unsupported transfer syntax gracefully")
    print("  ✅ Log transfer syntax for debugging")
    print("  ✅ Use DICOMKit's automatic decompression")
    
    print("\n2. Writing Files:")
    print("  ✅ Use Explicit VR Little Endian (1.2.840.10008.1.2.1)")
    print("  ✅ Include transfer syntax in file meta information")
    print("  ✅ Match pixel data encoding to transfer syntax")
    print("  ⚠️  Avoid Implicit VR for new files")
    
    print("\n3. Archival:")
    print("  ✅ Use lossless compression (JPEG 2000, JPEG Lossless)")
    print("  ✅ Preserve original transfer syntax when possible")
    print("  ✅ Document compression ratios")
    print("  ⚠️  Avoid lossy compression for diagnostic images")
    
    print("\n4. Network Transfer:")
    print("  ✅ Propose multiple transfer syntaxes")
    print("  ✅ Include uncompressed as fallback")
    print("  ✅ Verify receiver capabilities")
    print("  ✅ Log negotiation results")
    
    print("\n5. Performance:")
    print("  ✅ Cache decompressed frames for multi-frame")
    print("  ✅ Use background threads for decompression")
    print("  ✅ Consider memory vs. speed tradeoffs")
    print("  ⚠️  Compressed files may be slower to read")
    
    print("\n6. Compatibility:")
    print("  ✅ Support both Implicit and Explicit VR")
    print("  ✅ Handle Little and Big Endian (if legacy)")
    print("  ✅ Test with files from multiple vendors")
    print("  ✅ Validate against DICOM conformance statements")
}

// MARK: - Transfer Syntax Reference

/*
 Complete Transfer Syntax Reference:
 
 UNCOMPRESSED:
 --------------
 1.2.840.10008.1.2           - Implicit VR Little Endian (Default)
 1.2.840.10008.1.2.1         - Explicit VR Little Endian (Recommended)
 1.2.840.10008.1.2.2         - Explicit VR Big Endian (Deprecated)
 
 DEFLATED:
 --------------
 1.2.840.10008.1.2.1.99      - Deflated Explicit VR Little Endian
 
 JPEG FAMILY:
 --------------
 1.2.840.10008.1.2.4.50      - JPEG Baseline (Process 1) - 8-bit lossy
 1.2.840.10008.1.2.4.51      - JPEG Extended (Process 2 & 4) - 12-bit lossy
 1.2.840.10008.1.2.4.57      - JPEG Lossless, Non-Hierarchical (Process 14)
 1.2.840.10008.1.2.4.70      - JPEG Lossless, First-Order Prediction
 
 JPEG 2000:
 --------------
 1.2.840.10008.1.2.4.90      - JPEG 2000 Lossless Only
 1.2.840.10008.1.2.4.91      - JPEG 2000 (Lossy or Lossless)
 
 RLE:
 --------------
 1.2.840.10008.1.2.5         - RLE Lossless
 
 MPEG:
 --------------
 1.2.840.10008.1.2.4.100     - MPEG2 Main Profile @ Main Level
 1.2.840.10008.1.2.4.101     - MPEG2 Main Profile @ High Level
 1.2.840.10008.1.2.4.102     - MPEG-4 AVC/H.264 High Profile
 1.2.840.10008.1.2.4.103     - MPEG-4 AVC/H.264 BD-compatible
 
 USAGE BY CLINICAL SCENARIO:
 ----------------------------
 • Acquisition:        Explicit VR Little Endian (no compression)
 • Network Transfer:   JPEG 2000 Lossless (efficient bandwidth)
 • Short-term Archive: JPEG Lossless (good compression)
 • Long-term Archive:  JPEG 2000 Lossless (best compression)
 • Display Preview:    JPEG Baseline (fast, good quality)
 • Cine Loops:        MPEG-4 or RLE (video or per-frame)
 
 DICOMKIT SUPPORT:
 ------------------
 ✅ Reading:  All common transfer syntaxes
 ✅ Writing:  Uncompressed (Implicit/Explicit VR)
 ✅ Pixel:    Automatic decompression to CGImage
 ⚠️  Note:    MPEG formats require additional codecs
 */
