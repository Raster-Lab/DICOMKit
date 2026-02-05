# Troubleshooting Guide

Common issues and solutions when working with DICOMKit.

## File Reading Issues

### "Invalid file" error

**Problem**: `DICOMError.invalidFile` when reading a file.

**Causes and Solutions**:

1. **Missing DICM prefix**: Some legacy files don't have the standard header.
   ```swift
   // Use force mode for legacy files
   let file = try DICOMFile.read(from: data, force: true)
   ```

2. **Corrupted file**: Verify the file integrity.
   ```swift
   // Check file size and magic bytes
   print("File size: \(data.count)")
   if data.count > 132 {
       let prefix = String(data: data[128..<132], encoding: .ascii)
       print("Prefix: \(prefix ?? "none")")  // Should be "DICM"
   }
   ```

3. **Not a DICOM file**: Verify file format.
   - Check file extension
   - Verify source system exports valid DICOM

### "Unsupported Transfer Syntax" error

**Problem**: File uses a compression format not supported.

**Solutions**:

1. Check which transfer syntax is used:
   ```swift
   if let tsUID = file.fileMetaInformation[.transferSyntaxUID]?.stringValue {
       print("Transfer Syntax: \(tsUID)")
   }
   ```

2. Supported transfer syntaxes:
   - `1.2.840.10008.1.2` - Implicit VR Little Endian
   - `1.2.840.10008.1.2.1` - Explicit VR Little Endian
   - `1.2.840.10008.1.2.2` - Explicit VR Big Endian
   - `1.2.840.10008.1.2.4.50` - JPEG Baseline
   - `1.2.840.10008.1.2.4.70` - JPEG Lossless
   - `1.2.840.10008.1.2.4.90/91` - JPEG 2000
   - `1.2.840.10008.1.2.5` - RLE Lossless

3. Convert the file using external tools:
   ```bash
   # Using dcmtk
   dcmconv --write-xfer-little input.dcm output.dcm
   ```

### Memory issues with large files

**Problem**: App crashes or runs out of memory with large files.

**Solutions**:

1. Use metadata-only parsing:
   ```swift
   let options = ParsingOptions(mode: .metadataOnly)
   let file = try DICOMFile.read(from: data, options: options)
   ```

2. Use lazy pixel data loading:
   ```swift
   let options = ParsingOptions(mode: .lazyPixelData)
   let file = try DICOMFile.read(from: data, options: options)
   ```

3. Use memory-mapped files:
   ```swift
   let dataSource = try MemoryMappedDataSource(url: fileURL)
   // Use dataSource with parsing options
   ```

## Image Rendering Issues

### Black or white image

**Problem**: Rendered image appears completely black or white.

**Causes and Solutions**:

1. **Wrong window/level settings**:
   ```swift
   // Get values from the file first
   let windowCenter = file.dataSet.windowCenter ?? 0
   let windowWidth = file.dataSet.windowWidth ?? 1000
   
   // Use these values for rendering
   let renderer = PixelDataRenderer(
       pixelData: pixelData,
       windowCenter: windowCenter,
       windowWidth: windowWidth
   )
   ```

2. **MONOCHROME1 interpretation** (inverted):
   ```swift
   // DICOMKit handles this automatically, but verify:
   print("Photometric: \(pixelData.photometricInterpretation)")
   ```

3. **16-bit data with wrong bit interpretation**:
   ```swift
   print("Bits Allocated: \(pixelData.bitsAllocated)")
   print("Bits Stored: \(pixelData.bitsStored)")
   print("High Bit: \(pixelData.highBit)")
   ```

### Incorrect colors

**Problem**: Color images appear wrong (shifted colors, inverted).

**Solutions**:

1. Check photometric interpretation:
   ```swift
   let photometric = pixelData.photometricInterpretation
   print("Photometric: \(photometric)")
   // Expected: RGB, YBR_FULL, YBR_FULL_422, PALETTE COLOR
   ```

2. For palette color images:
   ```swift
   // Ensure LUT data is present
   if let redLUT = file.dataSet[.redPaletteColorLookupTableData] {
       print("Red LUT present")
   }
   ```

### Blurry or pixelated image

**Problem**: Rendered image quality is poor.

**Solutions**:

1. Check image dimensions:
   ```swift
   print("Size: \(pixelData.columns) x \(pixelData.rows)")
   ```

2. Disable scaling interpolation:
   ```swift
   // In SwiftUI
   Image(cgImage, scale: 1.0, label: Text(""))
       .interpolation(.none)
   ```

3. Use appropriate display size:
   ```swift
   // Scale to fit while maintaining aspect ratio
   .aspectRatio(contentMode: .fit)
   ```

## Network Issues

### Connection failed

**Problem**: Cannot connect to PACS server.

**Debugging**:

```swift
// Enable logging
DICOMLogger.shared.logLevel = .debug

// Test with verification first
let verificationService = VerificationService(client: client)
let success = try await verificationService.verify()
print("Verification: \(success)")
```

**Common causes**:

1. **Wrong port**: Verify DICOM port (usually 104 or 11112)
2. **Firewall blocking**: Ensure port is open
3. **Wrong AE Title**: Verify both calling and called AE titles
4. **TLS mismatch**: Check if server requires TLS

### Association rejected

**Problem**: Server rejects the association.

**Debugging**:

```swift
do {
    try await client.associate()
} catch let error as DICOMNetworkError {
    switch error {
    case .associationRejected(let result, let source, let reason):
        print("Rejected by: \(source)")
        print("Reason: \(reason)")
    default:
        print("Error: \(error)")
    }
}
```

**Common causes**:

1. **Unknown AE Title**: Register your AE with the PACS
2. **IP not allowed**: Add your IP to PACS allowed list
3. **SOP Class not supported**: Check server capabilities

### Query returns no results

**Problem**: C-FIND returns empty results.

**Solutions**:

1. Simplify the query:
   ```swift
   // Start with minimal criteria
   let query = QueryKeys.study()
   // Then add filters incrementally
   ```

2. Check query keys format:
   ```swift
   // Use wildcards for partial matches
   let query = QueryKeys.study(patientName: "SMITH*")
   ```

3. Verify data exists on PACS using vendor tools

## DICOMweb Issues

### HTTP 401 Unauthorized

**Problem**: DICOMweb server rejects requests.

**Solutions**:

1. Configure OAuth2:
   ```swift
   let oauth2 = OAuth2Client(configuration: ...)
   let client = DICOMwebClient(
       configuration: config,
       oauth2Client: oauth2
   )
   ```

2. Check token expiration:
   ```swift
   if oauth2.isTokenExpired {
       try await oauth2.refreshToken()
   }
   ```

### HTTP 404 Not Found

**Problem**: Resources not found.

**Solutions**:

1. Verify URL configuration:
   ```swift
   let config = DICOMwebConfiguration(
       baseURL: URL(string: "https://server/dicom-web")!,
       wadoRoot: "/wado-rs",  // Verify these paths
       qidoRoot: "/qido-rs",
       stowRoot: "/stow-rs"
   )
   ```

2. Check UIDs are correct:
   ```swift
   print("Study UID: \(studyUID)")
   // Ensure no extra spaces or encoding issues
   ```

### Slow retrieval

**Problem**: WADO-RS retrieval is slow.

**Solutions**:

1. Enable caching:
   ```swift
   let cache = InMemoryCache(maxSize: 500 * 1024 * 1024)
   let client = DICOMwebClient(
       configuration: config,
       cache: cache
   )
   ```

2. Request rendered frames for preview:
   ```swift
   // Get JPEG instead of full DICOM
   let jpeg = try await client.retrieveRenderedFrame(
       studyUID: study,
       seriesUID: series,
       instanceUID: instance,
       frameNumber: 1,
       mediaType: .jpeg
   )
   ```

## Character Encoding Issues

### Garbled text

**Problem**: Patient names or descriptions show incorrect characters.

**Solutions**:

1. Check Specific Character Set:
   ```swift
   if let charset = file.dataSet[.specificCharacterSet]?.stringValue {
       print("Character Set: \(charset)")
   }
   ```

2. DICOMKit supports common character sets:
   - ISO IR 100 (Latin-1)
   - ISO IR 192 (UTF-8)
   - Japanese, Korean, Chinese
   - Arabic, Hebrew, Greek, Cyrillic

3. If charset is missing:
   ```swift
   // Try force-reading as UTF-8
   let options = ParsingOptions(defaultCharacterSet: .utf8)
   ```

## Performance Issues

### Slow parsing

**Problem**: File parsing takes too long.

**Solutions**:

1. Use partial parsing:
   ```swift
   var options = ParsingOptions(mode: .metadataOnly)
   options.stopAfterTag = .seriesInstanceUID
   ```

2. Enable SIMD processing:
   ```swift
   // SIMD is automatically used on Apple platforms
   // Verify Accelerate framework is available
   #if canImport(Accelerate)
   print("SIMD acceleration available")
   #endif
   ```

3. Profile with Instruments to find bottlenecks

### High memory usage

**Problem**: App uses too much memory.

**Solutions**:

1. Configure image cache:
   ```swift
   // Use low memory configuration
   let cache = ImageCache(configuration: .lowMemory)
   ```

2. Clear cache periodically:
   ```swift
   ImageCache.shared.clear()
   ```

3. Use memory mapping for files >100MB

## Debug Logging

Enable detailed logging for debugging:

```swift
// Enable DICOM network logging
DICOMLogger.shared.logLevel = .debug

// Enable DICOMweb logging
DICOMwebLogger.shared.logLevel = .verbose
```

## Getting Help

If you can't resolve an issue:

1. Check the [GitHub Issues](https://github.com/raster-image/DICOMKit/issues)
2. Create a minimal reproduction case
3. Include relevant DICOM tag values (anonymized)
4. Share error messages and stack traces
