# DICOMweb Guide

Learn how to use DICOMweb RESTful services for querying and retrieving DICOM objects.

## Overview

DICOMWeb provides HTTP-based access to DICOM data using the DICOMweb standard (QIDO-RS, WADO-RS, STOW-RS). This guide covers client configuration and common operations.

## Configuring the Client

Create a DICOMweb client with your server configuration:

```swift
import DICOMWeb

let config = DICOMwebConfiguration(
    baseURL: URL(string: "https://pacs.hospital.com/dicom-web")!,
    wadoRoot: "/wado-rs",
    qidoRoot: "/qido-rs",
    stowRoot: "/stow-rs"
)

let client = DICOMwebClient(configuration: config)
```

## Querying Studies (QIDO-RS)

Search for studies using QIDO-RS:

```swift
// Build a query
let query = QIDOQuery.studies()
    .patientName(contains: "SMITH")
    .modality("CT")
    .studyDate(from: "20240101", to: "20241231")
    .limit(50)

// Execute the query
let results = try await client.queryStudies(query)

for study in results.studies {
    print("Study UID: \(study.studyInstanceUID)")
    print("Patient: \(study.patientName ?? "Unknown")")
    print("Description: \(study.studyDescription ?? "Unknown")")
}
```

### Query Filters

DICOMweb supports comprehensive filtering:

```swift
// Patient-level queries
let patientQuery = QIDOQuery.studies()
    .patientID("12345")
    .patientName(contains: "DOE")
    .patientBirthDate("19800101")

// Study-level queries
let studyQuery = QIDOQuery.studies()
    .accessionNumber("A12345")
    .studyDescription(contains: "CHEST")
    .referringPhysicianName("JONES")

// Series-level queries
let seriesQuery = QIDOQuery.series(studyUID: "1.2.3.4.5")
    .modality("CT")
    .seriesNumber(1)
```

## Retrieving Images (WADO-RS)

Retrieve DICOM objects using WADO-RS:

```swift
// Retrieve a complete study
let studyData = try await client.retrieveStudy(
    studyUID: "1.2.3.4.5"
)

for dicomFile in studyData {
    print("Retrieved: \(dicomFile.dataSet.sopInstanceUID ?? "")")
}

// Retrieve a specific series
let seriesData = try await client.retrieveSeries(
    studyUID: "1.2.3.4.5",
    seriesUID: "1.2.3.4.5.6"
)

// Retrieve a single instance
let instanceData = try await client.retrieveInstance(
    studyUID: "1.2.3.4.5",
    seriesUID: "1.2.3.4.5.6",
    instanceUID: "1.2.3.4.5.6.7"
)
```

### Retrieve Rendered Images

Get pre-rendered images (JPEG, PNG) for quick preview:

```swift
// Get a rendered frame
let imageData = try await client.retrieveRenderedFrame(
    studyUID: "1.2.3.4.5",
    seriesUID: "1.2.3.4.5.6",
    instanceUID: "1.2.3.4.5.6.7",
    frameNumber: 1,
    mediaType: .jpeg,
    quality: 80,
    windowCenter: 40,
    windowWidth: 400
)

#if canImport(UIKit)
let image = UIImage(data: imageData)
#elseif canImport(AppKit)
let image = NSImage(data: imageData)
#endif
```

### Retrieve Thumbnails

Generate thumbnails for study browsing:

```swift
let thumbnail = try await client.retrieveRenderedFrame(
    studyUID: "1.2.3.4.5",
    seriesUID: "1.2.3.4.5.6",
    instanceUID: "1.2.3.4.5.6.7",
    frameNumber: 1,
    mediaType: .jpeg,
    quality: 50,
    viewport: (width: 128, height: 128)
)
```

## Storing Images (STOW-RS)

Store DICOM objects using STOW-RS:

```swift
// Store a single instance
let response = try await client.storeInstance(dicomFile)

if response.success {
    print("Stored successfully")
} else {
    for failure in response.failures {
        print("Failed: \(failure.sopInstanceUID) - \(failure.reason)")
    }
}

// Store multiple instances
let bulkResponse = try await client.storeInstances([
    dicomFile1,
    dicomFile2,
    dicomFile3
])
```

## OAuth2 Authentication

Configure OAuth2 for secure access:

```swift
let oauth2Config = OAuth2Configuration(
    tokenEndpoint: URL(string: "https://auth.hospital.com/token")!,
    clientID: "my_app",
    clientSecret: "secret",
    scope: "dicom"
)

let tokenStore = InMemoryTokenStore()
let oauth2Client = OAuth2Client(
    configuration: oauth2Config,
    tokenStore: tokenStore
)

let client = DICOMwebClient(
    configuration: config,
    oauth2Client: oauth2Client
)
```

## Response Caching

Enable caching for better performance:

```swift
let cache = InMemoryCache(
    maxEntries: 1000,
    maxSize: 500 * 1024 * 1024  // 500 MB
)

let client = DICOMwebClient(
    configuration: config,
    cache: cache
)

// Cached queries are served from memory
let results = try await client.queryStudies(query)
```

## Error Handling

Handle DICOMweb errors:

```swift
do {
    let results = try await client.queryStudies(query)
} catch let error as DICOMwebError {
    switch error {
    case .httpError(let statusCode, let message):
        print("HTTP \(statusCode): \(message)")
    case .invalidResponse:
        print("Invalid response from server")
    case .authenticationRequired:
        print("Authentication required")
    case .notFound:
        print("Resource not found")
    default:
        print("DICOMweb error: \(error)")
    }
}
```

## Conformance Statement

Generate a conformance statement for your implementation:

```swift
let generator = ConformanceStatementGenerator(
    implementationName: "My DICOM App",
    implementationVersion: "1.0.0",
    supportedTransactions: [.qidoRS, .wadoRS, .stowRS]
)

let statement = generator.generate()
print(statement.asJSON())
```

## See Also

- ``DICOMwebClient``
- ``QIDOQuery``
- ``DICOMwebConfiguration``
- ``ConformanceStatement``
