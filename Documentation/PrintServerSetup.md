# DICOM Print Server Setup Guide

Complete guide for setting up DICOM Print SCP servers for testing DICOMKit's Print Management features.

## Overview

This guide covers setting up test DICOM Print SCP (Service Class Provider) servers using:
- **DCM4CHEE** - Full-featured open-source PACS with print support
- **Orthanc** - Lightweight DICOM server with print plugin
- **Docker Compose** - Automated setup for integration testing

## Quick Start with Docker Compose

DICOMKit includes a Docker Compose configuration for automated test server setup.

### Prerequisites

- Docker installed (version 20.10 or later)
- Docker Compose installed (version 2.0 or later)
- 2GB free disk space
- Ports 11112, 11113, 8080, 8042 available

### Start DCM4CHEE Print Server

```bash
# Navigate to DICOMKit repository
cd /path/to/DICOMKit

# Start DCM4CHEE with PostgreSQL database
docker-compose -f docker-compose-print-test.yml up -d dcm4chee postgres-dcm4chee

# Wait for server to start (60-90 seconds)
docker-compose -f docker-compose-print-test.yml logs -f dcm4chee

# Verify server is running
docker-compose -f docker-compose-print-test.yml ps
```

**DCM4CHEE Configuration:**
- DICOM Port: `11112`
- AE Title: `DCM4CHEE_PRINT`
- Web UI: http://localhost:8080/dcm4chee-arc/ui2/
- Database: PostgreSQL (pacsdb)

### Start Orthanc Print Server (Alternative)

```bash
# Start Orthanc
docker-compose -f docker-compose-print-test.yml up -d orthanc

# Wait for server to start (30-45 seconds)
docker-compose -f docker-compose-print-test.yml logs -f orthanc

# Verify server is running
docker-compose -f docker-compose-print-test.yml ps
```

**Orthanc Configuration:**
- DICOM Port: `11113`
- AE Title: `ORTHANC_PRINT`
- Web UI: http://localhost:8042/ (user: `orthanc`, pass: `orthanc`)
- REST API: http://localhost:8042/system

### Test Connection

Using the `dicom-print` CLI tool:

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

### Stop Servers

```bash
# Stop all services
docker-compose -f docker-compose-print-test.yml down

# Stop and remove volumes (deletes all data)
docker-compose -f docker-compose-print-test.yml down -v
```

## Manual DCM4CHEE Setup

### Docker Installation

```bash
# Create Docker network
docker network create dicom-print-test

# Start PostgreSQL database
docker run -d \
    --name postgres-dcm4chee \
    --network dicom-print-test \
    -e POSTGRES_DB=pacsdb \
    -e POSTGRES_USER=pacs \
    -e POSTGRES_PASSWORD=pacs \
    -v dcm4chee-db:/var/lib/postgresql/data \
    postgres:15-alpine

# Start DCM4CHEE
docker run -d \
    --name dcm4chee-print-scp \
    --network dicom-print-test \
    -p 11112:11112 \
    -p 8080:8080 \
    -e POSTGRES_DB=pacsdb \
    -e POSTGRES_USER=pacs \
    -e POSTGRES_PASSWORD=pacs \
    -e PRINT_SCP_AET=DCM4CHEE_PRINT \
    dcm4che/dcm4chee-arc-psql:5.31.0
```

### Configuration

Access DCM4CHEE web UI at http://localhost:8080/dcm4chee-arc/ui2/

1. Login with default credentials (admin/admin)
2. Navigate to **Configuration** → **Devices**
3. Select your archive device
4. Enable **Print SCP** application entity
5. Configure print parameters:
   - Supported film sizes
   - Default film orientation
   - Medium types available
   - Print priority handling

### Verify Installation

```bash
# Check DCM4CHEE logs
docker logs dcm4chee-print-scp

# Test DICOM echo (C-ECHO)
echoscu -aet WORKSTATION -aec DCM4CHEE_PRINT localhost 11112

# Test print status query (N-GET)
dicom-print status pacs://localhost:11112 \
    --aet WORKSTATION \
    --called-ae DCM4CHEE_PRINT
```

## Manual Orthanc Setup

### Docker Installation

```bash
# Create configuration file
cat > orthanc-print-config.json << 'EOF'
{
  "Name": "Orthanc Print SCP",
  "DicomAet": "ORTHANC_PRINT",
  "DicomPort": 11113,
  "HttpPort": 8042,
  "RemoteAccessAllowed": true,
  "AuthenticationEnabled": true,
  "RegisteredUsers": {
    "orthanc": "orthanc"
  },
  "DicomAlwaysAllowEcho": true,
  "DicomAlwaysAllowStore": true,
  "DicomCheckCalledAet": false,
  "Plugins": ["/usr/share/orthanc/plugins"]
}
EOF

# Start Orthanc
docker run -d \
    --name orthanc-print-scp \
    -p 11113:11113 \
    -p 8042:8042 \
    -v $(pwd)/orthanc-print-config.json:/etc/orthanc/orthanc.json:ro \
    -v orthanc-db:/var/lib/orthanc/db \
    jodogne/orthanc-plugins:latest
```

### Configuration

Access Orthanc web UI at http://localhost:8042/

1. Login with credentials (orthanc/orthanc)
2. Navigate to **Lookup** to verify server is running
3. Check **System Information** for plugin status

### Verify Installation

```bash
# Check Orthanc logs
docker logs orthanc-print-scp

# Test REST API
curl -u orthanc:orthanc http://localhost:8042/system

# Test DICOM echo
echoscu -aet WORKSTATION -aec ORTHANC_PRINT localhost 11113

# Test print status query
dicom-print status pacs://localhost:11113 \
    --aet WORKSTATION \
    --called-ae ORTHANC_PRINT
```

## Running Integration Tests

### With Docker Compose

```bash
# Start test servers
docker-compose -f docker-compose-print-test.yml up -d

# Wait for services to be healthy
docker-compose -f docker-compose-print-test.yml ps

# Run integration tests
swift test --filter PrintServiceIntegrationTests

# View logs if tests fail
docker-compose -f docker-compose-print-test.yml logs

# Stop servers
docker-compose -f docker-compose-print-test.yml down
```

### Manual Test Execution

```swift
import XCTest
@testable import DICOMNetwork

// Set environment variable to enable integration tests
// export DICOM_INTEGRATION_TESTS_ENABLED=1

class PrintServiceIntegrationTests: XCTestCase {
    let testServerHost = "localhost"
    let testServerPort: UInt16 = 11112
    let testServerAET = "DCM4CHEE_PRINT"
    
    func testPrinterStatusQuery() async throws {
        let config = PrintConfiguration(
            host: testServerHost,
            port: testServerPort,
            callingAETitle: "TEST_SCU",
            calledAETitle: testServerAET
        )
        
        let status = try await DICOMPrintService.getPrinterStatus(
            configuration: config
        )
        
        XCTAssertEqual(status.status, .normal)
        print("Printer: \(status.printerName)")
        print("Status: \(status.status)")
    }
}
```

### Test with CLI Tool

```bash
# Query printer status
dicom-print status pacs://localhost:11112 \
    --aet WORKSTATION \
    --called-ae DCM4CHEE_PRINT

# Print test image
dicom-print send pacs://localhost:11112 test-image.dcm \
    --aet WORKSTATION \
    --called-ae DCM4CHEE_PRINT \
    --copies 1 \
    --film-size 14x17 \
    --dry-run

# Monitor print job
dicom-print job pacs://localhost:11112 \
    --job-id 1.2.840.113619.2.55.3... \
    --aet WORKSTATION \
    --called-ae DCM4CHEE_PRINT
```

## Troubleshooting

### DCM4CHEE Won't Start

**Problem:** Container exits immediately or logs show database errors

**Solution:**
```bash
# Remove old volumes and restart
docker-compose -f docker-compose-print-test.yml down -v
docker-compose -f docker-compose-print-test.yml up -d

# Check PostgreSQL is ready
docker-compose -f docker-compose-print-test.yml logs postgres-dcm4chee
```

### Orthanc Not Responding

**Problem:** DICOM connections timeout or fail

**Solution:**
```bash
# Check Orthanc logs
docker logs orthanc-print-scp

# Verify configuration
docker exec orthanc-print-scp cat /etc/orthanc/orthanc.json

# Test with verbose echo
echoscu -v -aet TEST -aec ORTHANC_PRINT localhost 11113
```

### Connection Refused

**Problem:** "Connection refused" when testing

**Solution:**
1. Verify ports are exposed:
   ```bash
   docker-compose -f docker-compose-print-test.yml ps
   netstat -an | grep 11112
   ```

2. Check firewall rules:
   ```bash
   # Allow DICOM ports
   sudo ufw allow 11112/tcp
   sudo ufw allow 11113/tcp
   ```

3. Verify AE Title configuration matches

### Print Operations Fail

**Problem:** Print commands fail with status codes

**Solution:**
1. Check printer configuration in DCM4CHEE web UI
2. Verify film sizes and layouts are supported
3. Check server logs for detailed error messages
4. Use `--verbose` flag with `dicom-print` for debugging

## Production Considerations

### For Real DICOM Printers

When connecting to production film printers:

1. **Network Security**
   - Use secure networks (VLANs)
   - Configure firewall rules
   - Consider TLS encryption (if supported)

2. **Printer Configuration**
   - Verify supported film sizes
   - Check medium types (clear film, blue film, paper)
   - Test with low-cost paper before using film
   - Configure default print parameters

3. **Error Handling**
   - Implement retry logic for transient failures
   - Monitor printer status before printing
   - Handle out-of-film and out-of-memory errors
   - Log all print operations for audit trail

4. **Quality Control**
   - Test print quality with calibration images
   - Verify window/level settings
   - Check image orientation and layout
   - Validate annotations are readable

### Performance Tuning

For high-volume printing:

1. **Use Print Queue**
   ```swift
   let queue = PrintQueue(
       maxHistorySize: 1000,
       retryPolicy: PrintRetryPolicy(
           maxRetries: 3,
           initialDelay: 2.0,
           maxDelay: 30.0,
           backoffMultiplier: 2.0
       )
   )
   ```

2. **Configure Multiple Printers**
   ```swift
   let registry = PrinterRegistry()
   await registry.addPrinter(radiologyPrinter)
   await registry.addPrinter(backupPrinter)
   ```

3. **Optimize Image Preparation**
   - Cache preprocessed images
   - Use appropriate resize quality
   - Apply window/level before sending

## Additional Resources

- **DICOM Standard**: PS3.4 Annex H - Print Management Service Class
- **DCM4CHEE Documentation**: https://github.com/dcm4che/dcm4chee-arc-light/wiki
- **Orthanc Documentation**: https://www.orthanc-server.com/static.php?page=documentation
- **DICOMKit Print Guide**: [PrintManagementGuide.md](../Sources/DICOMNetwork/DICOMNetwork.docc/PrintManagementGuide.md)
- **Troubleshooting**: [TroubleshootingPrint.md](TroubleshootingPrint.md)

## Support

For issues with:
- **DICOMKit**: Open an issue at https://github.com/Raster-Lab/DICOMKit/issues
- **DCM4CHEE**: Visit https://github.com/dcm4che/dcm4chee-arc-light/issues
- **Orthanc**: Visit https://groups.google.com/g/orthanc-users

---

**Last Updated**: February 2026  
**Version**: 1.4.5
