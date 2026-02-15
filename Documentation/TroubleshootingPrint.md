# Troubleshooting DICOM Print Issues

A comprehensive guide to diagnosing and resolving common DICOM printing problems.

## Overview

This guide helps you diagnose and fix issues with DICOM Print Management. It covers connection problems, print failures, image quality issues, and performance problems.

## Quick Diagnostics

### Step 1: Verify Printer Connection

Test basic connectivity to the printer:

```swift
import DICOMNetwork

func diagnoseConnection(host: String, port: UInt16) async {
    print("🔍 Diagnosing connection to \(host):\(port)...")
    
    let config = PrintConfiguration(
        host: host,
        port: port,
        callingAETitle: "DIAGNOSTIC",
        calledAETitle: "PRINT_SCP"
    )
    
    // Test 1: TCP connectivity
    print("\n📡 Test 1: TCP Connection")
    do {
        // Note: This is pseudocode - actual implementation would use Socket
        print("✅ TCP connection successful")
    } catch {
        print("❌ TCP connection failed: \(error)")
        print("💡 Check firewall and network settings")
        return
    }
    
    // Test 2: Query printer status
    print("\n📡 Test 2: DICOM Status Query")
    do {
        let status = try await DICOMPrintService.getPrinterStatus(
            configuration: config
        )
        print("✅ DICOM connection successful")
        print("   Printer: \(status.printerName)")
        print("   Status: \(status.status)")
        print("   Info: \(status.statusInfo)")
        
        if status.status != .normal {
            print("⚠️ Printer status is not NORMAL")
        }
    } catch {
        print("❌ DICOM connection failed: \(error)")
        print("💡 Verify AE Titles and DICOM configuration")
    }
}
```

## Common Issues and Solutions

### Issue 1: Connection Refused

**Symptoms:**
- "Connection refused" error
- "Unable to connect to printer" message

**Possible Causes:**

1. **Printer is offline or powered off**
   ```swift
   // Check printer power and network status
   // Ping the printer IP address
   ```

2. **Wrong IP address or port**
   ```swift
   // Verify printer configuration
   let config = PrintConfiguration(
       host: "192.168.1.100",  // Check IP
       port: 11112,             // Standard DICOM port
       callingAETitle: "APP",
       calledAETitle: "PRINT_SCP"
   )
   ```

3. **Firewall blocking connection**
   - Open port 11112 (or configured port) on firewall
   - Check both local and remote firewalls
   - Verify network routing

**Solutions:**

```bash
# Test TCP connectivity
telnet 192.168.1.100 11112

# Or using nc (netcat)
nc -zv 192.168.1.100 11112

# Ping printer
ping 192.168.1.100
```

### Issue 2: Association Rejected

**Symptoms:**
- "Association rejected" error
- Error code 0x0002 (Rejected Permanent)

**Possible Causes:**

1. **Wrong AE Title**
   ```swift
   // Verify AE Titles match printer configuration
   let config = PrintConfiguration(
       host: "192.168.1.100",
       port: 11112,
       callingAETitle: "WORKSTATION",  // Your application
       calledAETitle: "PRINT_SCP"       // Must match printer
   )
   ```

2. **Unsupported SOP Class**
   - Printer may not support print management
   - Check printer capabilities

3. **Maximum associations reached**
   - Printer has limited concurrent connections
   - Wait and retry

**Solutions:**

```swift
// Query printer with correct AE Titles
func verifyAETitles(
    host: String,
    port: UInt16,
    callingAE: String,
    calledAE: String
) async throws {
    let config = PrintConfiguration(
        host: host,
        port: port,
        callingAETitle: callingAE,
        calledAETitle: calledAE
    )
    
    do {
        let status = try await DICOMPrintService.getPrinterStatus(
            configuration: config
        )
        print("✅ AE Titles correct: \(calledAE)")
    } catch {
        print("❌ Check AE Title configuration")
        print("   Try: ANY-SCP, PRINT_SCP, or printer-specific AE")
    }
}
```

### Issue 3: Print Job Fails

**Symptoms:**
- Print job created but fails to print
- Status shows "PENDING" or "FAILURE"

**Diagnosis:**

```swift
func diagnosePrintJob(
    configuration: PrintConfiguration,
    printJobUID: String
) async throws {
    let status = try await DICOMPrintService.getPrintJobStatus(
        configuration: configuration,
        printJobUID: printJobUID
    )
    
    print("Job Status: \(status.executionStatus)")
    print("Job Info: \(status.executionStatusInfo)")
    
    switch status.executionStatus.lowercased() {
    case "pending":
        print("⏳ Job is queued - wait for processing")
        
    case "printing":
        print("🖨️ Job is currently printing")
        
    case "done":
        print("✅ Job completed successfully")
        
    case "failure":
        print("❌ Job failed")
        print("Reason: \(status.executionStatusInfo)")
        
    default:
        print("⚠️ Unknown status: \(status.executionStatus)")
    }
}
```

**Common Causes:**

1. **Insufficient Memory**
   ```
   Error: 0xA700 - Refused: Out of Resources
   ```
   
   **Solution:**
   - Reduce number of images per film
   - Use smaller film size
   - Reduce image resolution

2. **Invalid Film Size**
   ```
   Error: 0xA900 - Film size not supported
   ```
   
   **Solution:**
   ```swift
   // Query supported film sizes
   let status = try await DICOMPrintService.getPrinterStatus(
       configuration: config
   )
   // Check status.capabilities for supported sizes
   
   // Use supported size
   let options = PrintOptions(filmSize: .size14InX17In)
   ```

3. **Out of Film**
   ```
   Printer Status: WARNING
   Status Info: Film supply low
   ```
   
   **Solution:** Reload printer film

### Issue 4: Poor Image Quality

**Symptoms:**
- Pixelated images
- Incorrect window/level
- Wrong colors

**Solutions:**

#### 1. Incorrect Window/Level

```swift
func fixWindowLevel(dataSet: DataSet) async throws -> Data {
    let preprocessor = ImagePreprocessor()
    
    // Apply appropriate window/level for modality
    let modality = dataSet.string(for: .modality) ?? ""
    
    let prepared = try await preprocessor.prepareForPrint(
        dataSet: dataSet,
        targetSize: CGSize(width: 1024, height: 1024),
        colorMode: .grayscale
    )
    
    return prepared.pixelData
}
```

#### 2. Low Resolution

```swift
// Use high-quality resize
let resizer = ImageResizer()
let resized = try await resizer.resize(
    pixelData: lowResData,
    from: CGSize(width: 256, height: 256),
    to: CGSize(width: 1024, height: 1024),
    mode: .fit,
    quality: .high  // Use bicubic interpolation
)
```

#### 3. Wrong Polarity

```swift
// Check and correct polarity
let photometricInterpretation = dataSet.string(for: .photometricInterpretation)

let imageBox = ImageBoxContent(
    imageBoxUID: imageBoxUID,
    position: 1,
    pixelData: pixelData,
    polarity: photometricInterpretation == "MONOCHROME1" ? .reverse : .normal
)
```

### Issue 5: Timeout Errors

**Symptoms:**
- "Request timeout" error
- Operation hangs indefinitely

**Solutions:**

1. **Increase Timeout**
   ```swift
   let config = PrintConfiguration(
       host: "192.168.1.100",
       port: 11112,
       callingAETitle: "APP",
       calledAETitle: "PRINT_SCP",
       timeout: 60  // Increase from default 30s
   )
   ```

2. **Check Network Performance**
   ```bash
   # Test latency
   ping -c 10 192.168.1.100
   
   # Check bandwidth
   iperf3 -c 192.168.1.100
   ```

3. **Reduce Image Size**
   ```swift
   // Reduce image dimensions before sending
   let resizer = ImageResizer()
   let smaller = try await resizer.resize(
       pixelData: largeImage,
       from: CGSize(width: 2048, height: 2048),
       to: CGSize(width: 1024, height: 1024),
       mode: .fit,
       quality: .medium
   )
   ```

### Issue 6: Memory Issues

**Symptoms:**
- Out of memory crashes
- "Insufficient memory" errors from printer

**Solutions:**

1. **Process Images in Batches**
   ```swift
   func printLargeBatch(
       imageURLs: [URL],
       config: PrintConfiguration
   ) async throws {
       // Process 5 images at a time
       let batchSize = 5
       
       for start in stride(from: 0, to: imageURLs.count, by: batchSize) {
           let end = min(start + batchSize, imageURLs.count)
           let batch = Array(imageURLs[start..<end])
           
           // Load batch
           let images = try batch.map { url in
               let file = try DICOMFile(path: url.path)
               return try file.extractPixelData().data
           }
           
           // Print batch
           _ = try await DICOMPrintService.printImages(
               configuration: config,
               images: images,
               options: .default
           )
           
           print("Printed batch \(start/batchSize + 1)")
       }
   }
   ```

2. **Use Memory-Mapped Files**
   ```swift
   // For very large DICOM files
   let file = try DICOMFile(path: path, memoryMapped: true)
   ```

3. **Reduce Image Quality**
   ```swift
   let options = PrintOptions(
       filmSize: .size11InX14In,  // Smaller film
       magnificationType: .replicate  // Lower quality
   )
   ```

### Issue 7: Partial Print Failures

**Symptoms:**
- Some images print, others fail
- Partial success messages

**Handling:**

```swift
func handlePartialFailure(result: PrintResult) async throws {
    guard let partial = result as? PartialPrintResult else {
        return  // Complete success
    }
    
    print("⚠️ Partial failure: \(partial.failureCount) of \(partial.totalCount) failed")
    
    // Log failed positions
    for (position, error) in zip(partial.failedPositions, partial.errors) {
        print("Position \(position): \(error.description)")
        
        // Determine if retryable
        if case .imageBoxSetFailed(_, let statusCode) = error {
            if statusCode == 0xA900 {
                print("  → Resource error, may succeed on retry")
            } else if statusCode == 0xC000 {
                print("  → Invalid data, will not succeed on retry")
            }
        }
    }
    
    // Offer to retry failed images
    if partial.failureCount <= 3 {
        print("Attempting to retry failed images...")
        // Extract and retry only failed images
    }
}
```

## Diagnostic Tools

### 1. Comprehensive Printer Test

```swift
struct PrinterDiagnostics {
    static func runFullDiagnostics(
        host: String,
        port: UInt16,
        callingAE: String,
        calledAE: String
    ) async {
        print("=" * 60)
        print("DICOM Printer Diagnostics")
        print("=" * 60)
        print()
        
        let config = PrintConfiguration(
            host: host,
            port: port,
            callingAETitle: callingAE,
            calledAETitle: calledAE
        )
        
        // Test 1: Connection
        print("Test 1: Basic Connection")
        print("-" * 40)
        await testConnection(config)
        print()
        
        // Test 2: Printer Status
        print("Test 2: Printer Status")
        print("-" * 40)
        await testPrinterStatus(config)
        print()
        
        // Test 3: Film Session
        print("Test 3: Film Session Creation")
        print("-" * 40)
        await testFilmSession(config)
        print()
        
        // Test 4: Simple Print
        print("Test 4: Simple Print Test")
        print("-" * 40)
        await testSimplePrint(config)
        print()
        
        print("=" * 60)
        print("Diagnostics Complete")
        print("=" * 60)
    }
    
    private static func testConnection(_ config: PrintConfiguration) async {
        // Implementation...
    }
    
    private static func testPrinterStatus(_ config: PrintConfiguration) async {
        do {
            let status = try await DICOMPrintService.getPrinterStatus(
                configuration: config
            )
            print("✅ Status query successful")
            print("   Printer: \(status.printerName)")
            print("   Status: \(status.status)")
        } catch {
            print("❌ Status query failed: \(error)")
        }
    }
    
    private static func testFilmSession(_ config: PrintConfiguration) async {
        do {
            let session = FilmSession(
                numberOfCopies: 1,
                printPriority: .medium,
                mediumType: .paper
            )
            let uid = try await DICOMPrintService.createFilmSession(
                configuration: config,
                filmSession: session
            )
            print("✅ Film session created: \(uid)")
            
            // Cleanup
            try await DICOMPrintService.deleteFilmSession(
                configuration: config,
                filmSessionUID: uid
            )
            print("✅ Film session deleted")
        } catch {
            print("❌ Film session test failed: \(error)")
        }
    }
    
    private static func testSimplePrint(_ config: PrintConfiguration) async {
        // Create test image (128x128 grayscale)
        let testImage = Data(repeating: 128, count: 128 * 128)
        
        do {
            let result = try await DICOMPrintService.printImage(
                configuration: config,
                imageData: testImage,
                options: .draft  // Use draft for testing
            )
            print("✅ Test print successful")
            print("   Job: \(result.printJobUID)")
        } catch {
            print("❌ Test print failed: \(error)")
        }
    }
}
```

### 2. Network Packet Capture

For deep debugging, capture DICOM network traffic:

```bash
# Using tcpdump (requires root)
sudo tcpdump -i any -w dicom_print.pcap 'port 11112'

# Using Wireshark
# Filter: dicom
# Analyze PDUs, DIMSE messages, and status codes
```

### 3. Enable Verbose Logging

```swift
// Enable detailed logging
DICOMLogger.shared.level = .debug

// Print operations will now show detailed network traffic
```

## Error Code Reference

| Code | Meaning | Solution |
|------|---------|----------|
| 0x0000 | Success | Operation completed successfully |
| 0x0001 | Rejected Permanent | Check AE Titles and configuration |
| 0x0002 | Rejected Transient | Retry after delay |
| 0xA700 | Out of Resources | Reduce print job size |
| 0xA900 | Invalid Attribute | Check print parameters |
| 0xC000 | Cannot Understand | Invalid image data |
| 0xFE00 | Cancel | Operation was cancelled |

## Platform-Specific Issues

### iOS/iPadOS

**Issue:** App suspended during long print job

**Solution:**
```swift
// Request background time for printing
let taskID = await UIApplication.shared.beginBackgroundTask {
    print("⚠️ Background time expired")
}

defer {
    await UIApplication.shared.endBackgroundTask(taskID)
}

// Perform print
let result = try await DICOMPrintService.printImage(...)
```

### macOS

**Issue:** App Sandbox restrictions

**Solution:**
- Enable "Outgoing Connections (Client)" in entitlements
- Add exception for printer IP if needed

### Linux

**Issue:** Network interface selection

**Solution:**
```swift
// Bind to specific interface if multiple NICs
let config = PrintConfiguration(
    host: "192.168.1.100",
    port: 11112,
    callingAETitle: "APP",
    calledAETitle: "PRINT_SCP",
    localAddress: "192.168.1.50"  // Bind to specific interface
)
```

## Performance Troubleshooting

### Slow Print Operations

**Symptoms:**
- Print takes much longer than expected
- Progress stalls

**Diagnosis:**

```swift
func measurePrintPerformance(
    config: PrintConfiguration,
    imageData: Data
) async throws -> TimeInterval {
    let start = Date()
    
    _ = try await DICOMPrintService.printImage(
        configuration: config,
        imageData: imageData,
        options: .default
    )
    
    let duration = Date().timeIntervalSince(start)
    print("Print took \(String(format: "%.2f", duration))s")
    
    // Expected: < 5s for single image
    if duration > 10 {
        print("⚠️ Performance is slow")
        print("Check:")
        print("- Network latency")
        print("- Image size")
        print("- Printer processing time")
    }
    
    return duration
}
```

**Solutions:**
- Reduce image resolution
- Use faster network connection
- Enable connection pooling
- Batch multiple images

## Getting Help

If you're still experiencing issues:

1. **Check Documentation**
   - [Print Management Guide](../Sources/DICOMNetwork/DICOMNetwork.docc/PrintManagementGuide.md)
   - [Getting Started with Printing](GettingStartedWithPrinting.md)
   - [Best Practices](PrintWorkflowBestPractices.md)

2. **Run Full Diagnostics**
   ```swift
   await PrinterDiagnostics.runFullDiagnostics(
       host: "192.168.1.100",
       port: 11112,
       callingAE: "APP",
       calledAE: "PRINT_SCP"
   )
   ```

3. **Check Printer Logs**
   - Most DICOM printers maintain logs
   - Check for error messages
   - Look for rejected associations

4. **Test with Another Tool**
   - Use `dcmtk` tools (dcmprscu, dcmpssnd)
   - Compare behavior
   - Isolate issue to printer vs. implementation

5. **Contact Support**
   - GitHub Issues: Include diagnostic output
   - Include printer model and firmware version
   - Provide sample DICOM files if possible

## Checklist: Before Reporting Issues

When reporting print issues, include:

- [ ] Printer make and model
- [ ] DICOMKit version
- [ ] Platform (iOS/macOS/Linux) and version
- [ ] Output of `PrinterDiagnostics.runFullDiagnostics()`
- [ ] Error messages and stack traces
- [ ] Network configuration (IP, port, AE titles)
- [ ] Sample code reproducing the issue
- [ ] Does it work with other DICOM tools?

## Frequently Asked Questions

### Q: Can I test without a physical printer?

**A:** Yes! Use DCM4CHEE or Orthanc with print support:

```bash
# DCM4CHEE with Docker
docker run -p 11112:11112 dcm4che/dcm4chee-arc-psql:5.31.0

# Orthanc with print plugin
docker run -p 11112:11112 jodogne/orthanc-plugins:latest
```

### Q: What's the maximum number of images per print?

**A:** This depends on the printer's memory. Typically:
- Standard printers: 4-12 images
- High-end printers: Up to 20 images
- Use batching for larger sets

### Q: Can I print to PDF instead of film?

**A:** Many print simulators can save to PDF. Check your printer's configuration.

### Q: Why are my images inverted (dark/light flipped)?

**A:** Check the polarity setting. MONOCHROME1 images need `polarity: .reverse`.

### Q: How do I cancel a print job in progress?

**A:** Use the print queue's cancel method:
```swift
await printQueue.cancel(jobID: jobID)
```

## See Also

- [Getting Started with DICOM Printing](GettingStartedWithPrinting.md)
- [Print Workflow Best Practices](PrintWorkflowBestPractices.md)
- [Print Management API Reference](../Sources/DICOMNetwork/DICOMNetwork.docc/PrintManagementGuide.md)
- DICOM Standard PS3.4 Annex H
