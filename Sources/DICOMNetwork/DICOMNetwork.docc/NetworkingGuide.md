# Networking Guide

Learn how to use DICOM network services to query PACS servers and retrieve images.

## Overview

DICOMNetwork provides complete DICOM Upper Layer Protocol support for connecting to PACS servers, querying for studies, and retrieving images.

## Establishing a Connection

Create a DICOM client and connect to a server:

```swift
import DICOMNetwork

// Configure the connection
let client = DICOMClient(
    host: "pacs.hospital.com",
    port: 11112,
    callingAETitle: "MY_APP",
    calledAETitle: "PACS"
)

// Establish an association
try await client.associate()
defer {
    try? await client.release()
}
```

## C-ECHO Verification

Test connectivity with a C-ECHO request:

```swift
let verificationService = VerificationService(client: client)

do {
    let success = try await verificationService.verify()
    print("DICOM connectivity: \(success ? "OK" : "Failed")")
} catch {
    print("Connection error: \(error)")
}
```

## Querying Studies (C-FIND)

Query for studies matching specific criteria:

```swift
let queryService = QueryService(client: client)

// Build query keys
let queryKeys = QueryKeys.study(
    patientID: "12345*",
    patientName: "SMITH^*",
    studyDate: "20240101-20241231",
    modality: "CT"
)

// Execute the query
let results = try await queryService.findStudies(queryKeys)

for study in results {
    print("Study: \(study.studyDescription ?? "Unknown")")
    print("Patient: \(study.patientName ?? "Unknown")")
    print("Date: \(study.studyDate ?? "Unknown")")
}
```

### Query Levels

DICOMNetwork supports all query levels:

```swift
// Patient level
let patientResults = try await queryService.findPatients(patientKeys)

// Study level
let studyResults = try await queryService.findStudies(studyKeys)

// Series level
let seriesResults = try await queryService.findSeries(seriesKeys)

// Instance level
let instanceResults = try await queryService.findInstances(instanceKeys)
```

## Retrieving Images (C-MOVE / C-GET)

Retrieve images after querying:

```swift
let retrieveService = RetrieveService(client: client)

// C-MOVE: Retrieve to a destination AE
try await retrieveService.moveStudy(
    studyInstanceUID: "1.2.3.4.5",
    destinationAE: "MY_WORKSTATION"
)

// C-GET: Retrieve to the requesting application
let images = try await retrieveService.getStudy(
    studyInstanceUID: "1.2.3.4.5"
)

for dicomFile in images {
    // Process retrieved images
    print("Retrieved: \(dicomFile.dataSet.sopInstanceUID ?? "")")
}
```

## Storing Images (C-STORE)

Send images to a PACS server:

```swift
let storageClient = DICOMStorageClient(
    host: "pacs.hospital.com",
    port: 11112,
    callingAETitle: "MY_APP",
    calledAETitle: "PACS"
)

// Store a single image
try await storageClient.store(dicomFile: dicomFile)

// Store multiple images
try await storageClient.store(dicomFiles: [file1, file2, file3])
```

## Storage SCP (Receiving Images)

Set up a server to receive images from modalities:

```swift
let storageSCP = StorageSCP(
    port: 11112,
    aeTitle: "MY_SCP"
)

storageSCP.onImageReceived = { dicomFile in
    // Handle received image
    print("Received: \(dicomFile.dataSet.sopInstanceUID ?? "")")
    // Save to disk, process, etc.
}

try await storageSCP.start()
```

## Security with TLS

Configure TLS for secure connections:

```swift
let tlsConfig = TLSConfiguration(
    certificatePath: "/path/to/client.crt",
    keyPath: "/path/to/client.key",
    caCertificatePath: "/path/to/ca.crt",
    verifyPeer: true
)

let client = DICOMClient(
    host: "secure-pacs.hospital.com",
    port: 11112,
    callingAETitle: "MY_APP",
    calledAETitle: "PACS",
    tlsConfiguration: tlsConfig
)
```

## Connection Pooling

Use connection pooling for better performance:

```swift
let pool = ConnectionPool(
    host: "pacs.hospital.com",
    port: 11112,
    callingAETitle: "MY_APP",
    calledAETitle: "PACS",
    maxConnections: 5
)

// Acquire a connection from the pool
let client = try await pool.acquire()
defer {
    pool.release(client)
}

// Use the client
let results = try await queryService.findStudies(queryKeys)
```

## Retry Policy

Configure automatic retries for reliability:

```swift
let retryPolicy = RetryPolicy(
    maxRetries: 3,
    initialDelay: 1.0,
    maxDelay: 30.0,
    multiplier: 2.0
)

let client = DICOMClient(
    host: "pacs.hospital.com",
    port: 11112,
    callingAETitle: "MY_APP",
    calledAETitle: "PACS",
    retryPolicy: retryPolicy
)
```

## Error Handling

Handle network errors appropriately:

```swift
do {
    try await client.associate()
} catch let error as DICOMNetworkError {
    switch error {
    case .connectionFailed(let reason):
        print("Connection failed: \(reason)")
    case .associationRejected(let result, let source, let reason):
        print("Association rejected: \(reason)")
    case .timeout:
        print("Request timed out")
    case .dimseError(let status):
        print("DIMSE error: \(status)")
    default:
        print("Network error: \(error)")
    }
}
```

## See Also

- ``DICOMClient``
- ``QueryService``
- ``RetrieveService``
- ``StorageService``
- ``VerificationService``
