# Frequently Asked Questions

Common questions about DICOMKit.

## General Questions

### What is DICOMKit?

DICOMKit is a pure Swift DICOM toolkit for Apple platforms (iOS, macOS, visionOS). It provides native Swift implementations for reading, parsing, writing, and networking with DICOM medical imaging files.

### Which platforms does DICOMKit support?

- **iOS** 17.0 and later
- **macOS** 14.0 and later
- **visionOS** 1.0 and later

### What Swift version is required?

DICOMKit requires **Swift 6.2** or later and uses strict concurrency checking.

### Is DICOMKit production-ready?

Yes, DICOMKit v1.0+ is designed for production use. It includes comprehensive test coverage, performance optimizations, and follows DICOM standard compliance.

### Does DICOMKit require any external dependencies?

No, DICOMKit is a pure Swift implementation with no external dependencies. It uses only Apple frameworks (Foundation, CoreGraphics, Accelerate).

---

## File Handling

### How do I read a DICOM file?

```swift
import DICOMKit

let data = try Data(contentsOf: fileURL)
let dicomFile = try DICOMFile.read(from: data)

// Access patient information
let patientName = dicomFile.dataSet.patientName
```

### How do I write/create a DICOM file?

```swift
import DICOMKit

// Create a new DataSet
var dataSet = DataSet()
dataSet[.patientName] = DataElement(tag: .patientName, vr: .PN, value: "DOE^JOHN")
dataSet[.patientID] = DataElement(tag: .patientID, vr: .LO, value: "12345")
// ... add more elements

// Create DICOM file
let dicomFile = try DICOMFile.create(dataSet: dataSet, sopClassUID: sopClassUID)
let data = try dicomFile.write()
try data.write(to: outputURL)
```

### What transfer syntaxes are supported?

DICOMKit supports:
- Implicit VR Little Endian
- Explicit VR Little Endian
- Explicit VR Big Endian (Retired)
- Deflated Explicit VR Little Endian
- JPEG Baseline
- JPEG Lossless
- JPEG 2000 (Lossless and Lossy)
- RLE Lossless

### Can I read DICOM files without the DICM prefix?

Yes, use the `force` parameter:

```swift
let file = try DICOMFile.read(from: data, force: true)
```

---

## Image Rendering

### How do I render a DICOM image?

```swift
import DICOMKit

let pixelData = try dicomFile.extractPixelData()
let renderer = PixelDataRenderer(pixelData: pixelData)

if let cgImage = renderer.renderFrame(0) {
    // Use the CGImage
}
```

### How do I adjust window/level?

```swift
let renderer = PixelDataRenderer(
    pixelData: pixelData,
    windowCenter: 40,
    windowWidth: 400
)

// Or specify per-frame
if let image = renderer.renderFrame(0, windowCenter: 40, windowWidth: 400) {
    // Use image
}
```

### What photometric interpretations are supported?

- MONOCHROME1 (inverted grayscale)
- MONOCHROME2 (standard grayscale)
- RGB
- PALETTE COLOR
- YBR_FULL
- YBR_FULL_422
- YBR_PARTIAL_420

### How do I handle multi-frame images?

```swift
let numberOfFrames = pixelData.numberOfFrames

for frameIndex in 0..<numberOfFrames {
    if let image = renderer.renderFrame(frameIndex) {
        // Process each frame
    }
}
```

---

## Networking

### How do I query a PACS server?

```swift
import DICOMNetwork

let client = DICOMClient(
    host: "pacs.hospital.com",
    port: 11112,
    callingAETitle: "MY_APP",
    calledAETitle: "PACS"
)

try await client.associate()

let queryService = QueryService(client: client)
let results = try await queryService.findStudies(QueryKeys.study(patientID: "12345"))

try await client.release()
```

### Does DICOMKit support C-MOVE and C-GET?

Yes, both are supported through the `RetrieveService`:

```swift
let retrieveService = RetrieveService(client: client)

// C-GET (receive directly)
let files = try await retrieveService.getStudy(studyInstanceUID: uid)

// C-MOVE (send to another AE)
try await retrieveService.moveStudy(studyInstanceUID: uid, destinationAE: "WORKSTATION")
```

### Does DICOMKit support TLS/SSL?

Yes:

```swift
let tlsConfig = TLSConfiguration(
    certificatePath: "/path/to/cert.pem",
    keyPath: "/path/to/key.pem"
)

let client = DICOMClient(
    host: "secure-pacs.com",
    port: 11112,
    callingAETitle: "MY_APP",
    calledAETitle: "PACS",
    tlsConfiguration: tlsConfig
)
```

### How do I receive images as a Storage SCP?

```swift
let scp = StorageSCP(port: 11112, aeTitle: "MY_SCP")

scp.onImageReceived = { dicomFile in
    // Handle received image
    print("Received: \(dicomFile.dataSet.sopInstanceUID ?? "")")
}

try await scp.start()
```

---

## DICOMweb

### How do I use DICOMweb?

```swift
import DICOMWeb

let config = DICOMwebConfiguration(
    baseURL: URL(string: "https://server/dicom-web")!
)

let client = DICOMwebClient(configuration: config)

// Query studies (QIDO-RS)
let query = QIDOQuery.studies().patientID("12345")
let results = try await client.queryStudies(query)

// Retrieve study (WADO-RS)
let files = try await client.retrieveStudy(studyUID: uid)
```

### Does DICOMKit support OAuth2?

Yes, for DICOMweb:

```swift
let oauth2 = OAuth2Client(configuration: OAuth2Configuration(
    tokenEndpoint: URL(string: "https://auth.server/token")!,
    clientID: "my_client",
    clientSecret: "secret"
))

let client = DICOMwebClient(configuration: config, oauth2Client: oauth2)
```

---

## Presentation States

### How do I apply a Grayscale Presentation State?

```swift
let gsps = try GrayscalePresentationState.read(from: gspsFile)
let transformedImage = try gsps.apply(to: dicomFile)
```

### What presentation states are supported?

- Grayscale Softcopy Presentation State (GSPS)
- Color Softcopy Presentation State (CSPS)
- Pseudo-Color Softcopy Presentation State

---

## Structured Reporting

### How do I create an SR document?

```swift
let builder = SRDocumentBuilder(
    title: "Imaging Report",
    templateID: "TID1500"
)

builder.addTextContent(
    conceptName: CodedConcept(meaning: "Finding", value: "121071"),
    text: "Normal chest X-ray"
)

let srDocument = try builder.build()
```

### What SR templates are supported?

DICOMKit supports:
- Basic Text SR
- Enhanced SR
- Comprehensive SR
- Comprehensive 3D SR
- TID 1500 (Measurement Report)

---

## Performance

### How do I optimize memory usage for large files?

```swift
// Use metadata-only parsing
let options = ParsingOptions(mode: .metadataOnly)
let file = try DICOMFile.read(from: data, options: options)

// Or use lazy loading
let options = ParsingOptions(mode: .lazyPixelData)
```

### How do I enable SIMD acceleration?

SIMD acceleration is automatic on Apple platforms when the Accelerate framework is available. No configuration needed.

### How do I cache images?

```swift
let cache = ImageCache(configuration: .default)

// Store
cache.set(cgImage, for: "key")

// Retrieve
if let cached = cache.get(key: "key") {
    // Use cached image
}
```

---

## Compliance

### Is DICOMKit HIPAA compliant?

DICOMKit is a library that helps you build HIPAA-compliant applications. It:
- Does not transmit PHI to third parties
- Supports TLS encryption
- Provides anonymization utilities
- Does not log sensitive data

Your application is responsible for overall HIPAA compliance.

### Which DICOM standard version does DICOMKit follow?

DICOMKit follows DICOM 2025e and aims for full compliance with relevant parts of the standard.

### Where can I find the Conformance Statement?

See [Documentation/ConformanceStatement.md](ConformanceStatement.md) for the detailed DICOM Conformance Statement.

---

## Troubleshooting

### Why does my file fail to parse?

See the [Troubleshooting Guide](Troubleshooting.md) for common issues and solutions.

### Where can I get help?

1. Check the [GitHub Issues](https://github.com/raster-image/DICOMKit/issues)
2. Read the documentation
3. Create a new issue with a minimal reproduction case

---

## Contributing

### How can I contribute to DICOMKit?

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines on:
- Reporting bugs
- Suggesting features
- Submitting pull requests
- Code style guidelines

### Is DICOMKit open source?

Yes, DICOMKit is released under the MIT License. See [LICENSE](../LICENSE) for details.
