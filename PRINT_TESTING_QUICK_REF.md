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

## Documentation

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
**Last Updated**: February 15, 2026
