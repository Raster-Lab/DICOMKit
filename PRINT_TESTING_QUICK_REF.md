# DICOM Print Testing Quick Reference

Quick commands for testing DICOM Print Management features using the Docker Compose test environment.

## Start Test Servers

```bash
# Start DCM4CHEE (recommended)
docker-compose -f docker-compose-print-test.yml up -d dcm4chee postgres-dcm4chee

# Start Orthanc (alternative)
docker-compose -f docker-compose-print-test.yml up -d orthanc

# Wait for services to be ready (check health status)
docker-compose -f docker-compose-print-test.yml ps
```

## Test with CLI Tool

### Query Printer Status

```bash
# Test DCM4CHEE
dicom-print status pacs://localhost:11112 \
    --aet WORKSTATION \
    --called-ae DCM4CHEE_PRINT

# Test Orthanc
dicom-print status pacs://localhost:11113 \
    --aet WORKSTATION \
    --called-ae ORTHANC_PRINT
```

### Print Test Images

```bash
# Simple print
dicom-print send pacs://localhost:11112 test.dcm \
    --aet WORKSTATION \
    --called-ae DCM4CHEE_PRINT

# Print with options
dicom-print send pacs://localhost:11112 scan.dcm \
    --aet WORKSTATION \
    --called-ae DCM4CHEE_PRINT \
    --copies 2 \
    --film-size 14x17 \
    --orientation landscape \
    --layout 2x2

# Dry run (no actual printing)
dicom-print send pacs://localhost:11112 *.dcm \
    --aet WORKSTATION \
    --called-ae DCM4CHEE_PRINT \
    --dry-run
```

## Test with Swift

### Query Status

```swift
import DICOMNetwork

let config = PrintConfiguration(
    host: "localhost",
    port: 11112,
    callingAETitle: "TEST_SCU",
    calledAETitle: "DCM4CHEE_PRINT"
)

let status = try await DICOMPrintService.getPrinterStatus(
    configuration: config
)
print("Printer: \(status.printerName)")
print("Status: \(status.status)")
```

### Print Image

```swift
let result = try await DICOMPrintService.printImage(
    configuration: config,
    imageData: pixelData,
    options: .default
)
print("Print job UID: \(result.printJobUID)")
```

## Run Integration Tests

```bash
# Set environment variable to enable network tests
export DICOM_INTEGRATION_TESTS_ENABLED=1

# Run print integration tests
swift test --filter PrintServiceIntegrationTests

# Run specific test
swift test --filter testPrinterStatusQuery
```

## View Logs

```bash
# View DCM4CHEE logs
docker-compose -f docker-compose-print-test.yml logs -f dcm4chee

# View Orthanc logs
docker-compose -f docker-compose-print-test.yml logs -f orthanc

# View all logs
docker-compose -f docker-compose-print-test.yml logs -f
```

## Access Web UIs

- **DCM4CHEE**: http://localhost:8080/dcm4chee-arc/ui2/
  - Default credentials: admin/admin
  
- **Orthanc**: http://localhost:8042/
  - Default credentials: orthanc/orthanc

## Stop Servers

```bash
# Stop services (keep data)
docker-compose -f docker-compose-print-test.yml down

# Stop and remove data
docker-compose -f docker-compose-print-test.yml down -v
```

## Troubleshooting

### Connection Refused

```bash
# Check if services are running
docker-compose -f docker-compose-print-test.yml ps

# Check logs for errors
docker-compose -f docker-compose-print-test.yml logs
```

### Port Already in Use

```bash
# Find process using port 11112
lsof -i :11112

# Kill process or change port in docker-compose-print-test.yml
```

### Service Not Ready

```bash
# Wait longer for startup (60-90 seconds for DCM4CHEE)
docker-compose -f docker-compose-print-test.yml logs -f dcm4chee

# Check health status
docker-compose -f docker-compose-print-test.yml ps
```

## Configuration Files

- **docker-compose-print-test.yml** - Service orchestration
- **orthanc-print-config.json** - Orthanc configuration template
- **.gitignore** - Excludes Docker volumes

## Automated Suites (no Docker required)

```bash
# SCU: unit + mock-SCP integration + spawned-binary end-to-end
swift test --filter PrintServiceTests
swift test --filter PrintSCPIntegrationTests
swift test --filter PrintCLIEndToEndTests

# SCP (printer emulator): parser, encoder, loopback SCU→SCP, status matrix (74 tests).
# The filter is a regex over suite names, not the file name.
swift test --filter 'PrintSCP|PrintDatasetReader|PrintImageDisplayFormat|PrintPresentationContext|DIMSENStatusClassification'

# Film composition, output sinks, DCMTK interop (63 tests)
swift test --filter DICOMPrintKitTests

# Studio: marking, presentation-to-film, preview, tile grid, series pane
swift test --filter DICOMStudioTests
```

## Test Against Our Own Printer Emulator

`DICOMPrintServer` is a Print SCP, so a print job can be exercised end to end with no
external server at all — point `dicom-print` at a running emulator, or drive it in-process as
`PrintSCPLoopbackTests` does. See [DICOM_PRINT_SCP_PLAN.md](DICOM_PRINT_SCP_PLAN.md) and
[PRINT_CONFORMANCE.md](PRINT_CONFORMANCE.md).

## DCMTK Interoperability

`Tests/DICOMPrintKitTests/DCMTKInteropTests.swift` runs both directions against **DCMTK
3.7.0** and **skips automatically when DCMTK is not installed** (it looks in
`/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`):

```bash
brew install dcmtk        # then the interop cases stop skipping
swift test --filter DCMTKInteropTests
```

- `dcmpsprt` + `dcmprscu` (DCMTK Print SCU) → our `DICOMPrintServer`
- our `DICOMPrintService` → `dcmprscp` (DCMTK Print SCP, IHE Full profile)

## Documentation

- [PRINT_CONFORMANCE.md](PRINT_CONFORMANCE.md) - Conformance statement (SCU and SCP)
- [PrintServerSetup.md](Documentation/PrintServerSetup.md) - Complete setup guide
- [PrintManagementGuide.md](Sources/DICOMNetwork/DICOMNetwork.docc/PrintManagementGuide.md) - API reference
- [GettingStartedWithPrinting.md](Documentation/GettingStartedWithPrinting.md) - Tutorial
- [TroubleshootingPrint.md](Documentation/TroubleshootingPrint.md) - Problem solving

## Test Data

Create test DICOM files:

```bash
# Use dicom-convert to create test images
dicom-convert input.dcm test-image.dcm --transfer-syntax 1.2.840.10008.1.2.1

# Or use sample DICOM files from test suite
find Tests -name "*.dcm" -type f
```

---

**Version**: v1.4.5  
**Last Updated**: July 29, 2026
