# Distribution and Deployment Guide

This document provides comprehensive guidance for distributing and deploying DICOMKit components.

## Table of Contents

1. [Package Distribution](#package-distribution)
2. [CLI Tools Distribution](#cli-tools-distribution)
3. [Demo Applications](#demo-applications)
4. [Docker Deployment](#docker-deployment)
5. [Integration Examples](#integration-examples)

---

## Package Distribution

### Swift Package Manager (Primary Method)

DICOMKit is distributed as a Swift Package, making it easy to integrate into Swift projects.

#### Adding as a Dependency

In your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Raster-Lab/DICOMKit.git", from: "1.0.0")
]
```

Then add the specific modules you need to your targets:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "DICOMKit", package: "DICOMKit"),      // High-level API
        .product(name: "DICOMCore", package: "DICOMKit"),     // Core parsing
        .product(name: "DICOMNetwork", package: "DICOMKit"),  // PACS networking
        .product(name: "DICOMWeb", package: "DICOMKit"),      // DICOMweb services
    ]
)
```

#### In Xcode Projects

1. File → Add Package Dependencies...
2. Enter: `https://github.com/Raster-Lab/DICOMKit.git`
3. Select version: "1.0.0" (or "Up to Next Major")
4. Choose the modules you need: DICOMKit, DICOMCore, DICOMNetwork, DICOMWeb

---

## CLI Tools Distribution

DICOMKit includes 29 command-line tools for working with DICOM files. Multiple distribution methods are available:

### Method 1: Homebrew (Recommended for macOS Users)

The easiest installation method for macOS users:

```bash
brew tap Raster-Lab/dicomkit
brew install dicomkit
```

See [HOMEBREW_TAP_SETUP.md](Documentation/HOMEBREW_TAP_SETUP.md) for tap setup details.

### Method 2: Direct Download from GitHub Releases

Pre-built binaries are available from GitHub Releases:

1. Go to https://github.com/Raster-Lab/DICOMKit/releases
2. Download `dicomkit-cli-tools-v1.0.0-macos-arm64.tar.gz`
3. Extract and install:

```bash
tar -xzf dicomkit-cli-tools-v1.0.0-macos-arm64.tar.gz
sudo cp bin/dicom-* /usr/local/bin/
```

### Method 3: Build from Source

See [INSTALLATION.md](INSTALLATION.md) for detailed instructions.

```bash
git clone https://github.com/Raster-Lab/DICOMKit.git
cd DICOMKit
./Scripts/install-cli-tools.sh
```

### Tool Categories

**Phase 1 - Core Tools** (7 tools):
- `dicom-info` - Display DICOM metadata
- `dicom-convert` - Convert transfer syntaxes and export images
- `dicom-validate` - Validate DICOM conformance
- `dicom-anon` - Anonymize patient information
- `dicom-dump` - Hexadecimal inspection
- `dicom-query` - Query PACS servers
- `dicom-send` - Send files to PACS

**Phase 2 - Enhanced Workflow** (4 tools):
- `dicom-diff` - Compare DICOM files
- `dicom-retrieve` - Retrieve from PACS (C-MOVE/C-GET)
- `dicom-split` - Extract frames from multi-frame images
- `dicom-merge` - Create multi-frame images

**Phase 3 - Format Conversion** (4 tools):
- `dicom-json` - Convert to/from DICOM JSON
- `dicom-xml` - Convert to/from DICOM XML
- `dicom-pdf` - Handle encapsulated PDF/CDA documents
- `dicom-image` - Convert images to DICOM Secondary Capture

**Phase 4 - Archive Management** (3 tools):
- `dicom-dcmdir` - Create and manage DICOMDIR files
- `dicom-archive` - Local DICOM archive with indexing
- `dicom-export` - Advanced export with metadata embedding

**Phase 5 - Network & Workflow** (5 tools):
- `dicom-qr` - Integrated query-retrieve workflow
- `dicom-wado` - DICOMweb client (WADO-RS, QIDO-RS, STOW-RS)
- `dicom-echo` - Network diagnostics (C-ECHO)
- `dicom-mwl` - Modality Worklist queries
- `dicom-mpps` - Modality Performed Procedure Step

**Phase 6 - Advanced Utilities** (6 tools):
- `dicom-pixedit` - Pixel data manipulation
- `dicom-tags` - Tag manipulation utilities
- `dicom-uid` - UID generation and management
- `dicom-compress` - Compression/decompression
- `dicom-study` - Study/Series organization
- `dicom-script` - Workflow automation scripting

---

## Demo Applications

DICOMKit includes three fully-functional demo applications:

### DICOMViewer iOS

Mobile DICOM viewer for iPhone and iPad.

**Distribution Options:**
1. **TestFlight** (recommended for beta testing)
2. **App Store** (for public distribution)
3. **Direct Installation** (Xcode required)

**Building from Source:**
```bash
cd DICOMViewer-iOS
open DICOMViewer.xcodeproj
# Build and run in Xcode
```

### DICOMViewer macOS

Professional diagnostic workstation for macOS.

**Distribution Options:**
1. **Mac App Store**
2. **Direct Download** (.dmg package)
3. **Homebrew Cask** (future)

**Building from Source:**
```bash
cd DICOMViewer-macOS
open DICOMViewer.xcodeproj
# Build and run in Xcode
```

### DICOMViewer visionOS

Spatial computing medical imaging app for Apple Vision Pro.

**Distribution Options:**
1. **TestFlight** (recommended for beta testing)
2. **App Store** (for public distribution)

**Building from Source:**
```bash
cd DICOMViewer-visionOS
open DICOMViewer.xcodeproj
# Build and run in Xcode with visionOS simulator
```

**Note:** Demo applications are provided as examples and starting points. For production medical imaging applications, additional testing, validation, and regulatory compliance (FDA, CE marking, etc.) are required.

---

## Docker Deployment

Docker containers enable easy deployment of DICOMKit server components.

### DICOMweb Server Container

Create a `Dockerfile` for the DICOMweb server:

```dockerfile
FROM swift:6.2-jammy

WORKDIR /app

# Copy source code
COPY . .

# Build DICOMweb server
RUN swift build -c release --product DICOMWebServer

# Expose DICOMweb ports
EXPOSE 8080

# Run server
CMD [".build/release/DICOMWebServer"]
```

Build and run:

```bash
docker build -t dicomkit-server .
docker run -p 8080:8080 dicomkit-server
```

### Docker Compose for Full Stack

`docker-compose.yml` example:

```yaml
version: '3.8'

services:
  dicomweb-server:
    build: .
    ports:
      - "8080:8080"
    environment:
      - DICOM_STORAGE_PATH=/data/dicom
      - LOG_LEVEL=info
    volumes:
      - dicom-data:/data/dicom
    restart: unless-stopped

  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: dicomkit
      POSTGRES_USER: dicom
      POSTGRES_PASSWORD: changeme
    volumes:
      - postgres-data:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  dicom-data:
  postgres-data:
```

Start the stack:

```bash
docker-compose up -d
```

### Kubernetes Deployment

Example Kubernetes deployment (k8s/deployment.yaml):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dicomkit-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: dicomkit-server
  template:
    metadata:
      labels:
        app: dicomkit-server
    spec:
      containers:
      - name: dicomkit
        image: dicomkit-server:latest
        ports:
        - containerPort: 8080
        env:
        - name: LOG_LEVEL
          value: "info"
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
---
apiVersion: v1
kind: Service
metadata:
  name: dicomkit-service
spec:
  selector:
    app: dicomkit-server
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: LoadBalancer
```

Deploy:

```bash
kubectl apply -f k8s/deployment.yaml
```

---

## Integration Examples

### Example 1: Swift iOS App Integration

```swift
import SwiftUI
import DICOMKit

struct DICOMReaderView: View {
    @State private var dicomFile: DICOMFile?
    @State private var patientName: String = ""
    
    var body: some View {
        VStack {
            Button("Open DICOM File") {
                openDICOMFile()
            }
            
            if let file = dicomFile {
                Text("Patient: \(patientName)")
                    .font(.headline)
            }
        }
    }
    
    func openDICOMFile() {
        // File picker logic here
        if let url = selectedFileURL {
            do {
                dicomFile = try DICOMFile(fileURL: url)
                patientName = dicomFile?.dataSet.string(for: .patientName) ?? "Unknown"
            } catch {
                print("Error reading DICOM file: \(error)")
            }
        }
    }
}
```

### Example 2: Command-Line Tool Integration

```bash
#!/bin/bash
# Batch anonymization script

INPUT_DIR="/path/to/dicom/input"
OUTPUT_DIR="/path/to/dicom/output"

# Anonymize all DICOM files
for file in "$INPUT_DIR"/*.dcm; do
    basename=$(basename "$file")
    dicom-anon \
        --input "$file" \
        --output "$OUTPUT_DIR/$basename" \
        --patient-name "Anonymous" \
        --patient-id "ANON$(date +%s)"
done

echo "Anonymization complete: $(ls -1 $OUTPUT_DIR | wc -l) files"
```

### Example 3: DICOMweb Client Integration

```swift
import DICOMWeb

let client = DICOMwebClient(baseURL: URL(string: "https://dicom.example.com")!)

// Query for studies
let studies = try await client.searchStudies(
    patientName: "Doe^John",
    studyDate: "20240101-20241231"
)

// Retrieve a study
for study in studies {
    let instances = try await client.retrieveStudy(
        studyUID: study.studyInstanceUID
    )
    print("Retrieved \(instances.count) instances")
}
```

### Example 4: PACS Integration

```swift
import DICOMNetwork

// Configure PACS connection
let config = AssociationConfiguration(
    callingAE: "MY_APP",
    calledAE: "PACS_SCP",
    host: "pacs.hospital.org",
    port: 11112
)

// Query for patients
let queryService = QueryService(configuration: config)
let results = try await queryService.findPatients(
    patientName: "Smith*",
    patientID: nil
)

// Retrieve studies
let retrieveService = RetrieveService(configuration: config)
for result in results {
    try await retrieveService.moveStudy(
        studyUID: result.studyInstanceUID,
        destinationAE: "MY_STORAGE"
    )
}
```

---

## Deployment Checklist

### Pre-Deployment

- [ ] All tests pass (`swift test`)
- [ ] Code builds without warnings (`swift build -c release`)
- [ ] Security scan clean (CodeQL)
- [ ] Documentation up to date
- [ ] Version numbers updated
- [ ] CHANGELOG.md updated

### Distribution

- [ ] GitHub release created
- [ ] Release notes written
- [ ] Binaries built and uploaded
- [ ] Checksums generated
- [ ] Homebrew formula updated
- [ ] Documentation deployed

### Post-Deployment

- [ ] Installation verified on clean system
- [ ] CLI tools work correctly
- [ ] Package Manager integration tested
- [ ] User documentation verified
- [ ] Announcement posted (if applicable)

---

## Support and Resources

- **Documentation**: https://github.com/Raster-Lab/DICOMKit/tree/main/Documentation
- **Issues**: https://github.com/Raster-Lab/DICOMKit/issues
- **Installation Guide**: [INSTALLATION.md](INSTALLATION.md)
- **Homebrew Setup**: [HOMEBREW_TAP_SETUP.md](Documentation/HOMEBREW_TAP_SETUP.md)

---

**Last Updated**: February 2026  
**Version**: 1.0.0
