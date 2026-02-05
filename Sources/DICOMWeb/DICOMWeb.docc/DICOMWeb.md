# ``DICOMWeb``

RESTful DICOMweb client and server implementations for WADO-RS, STOW-RS, and QIDO-RS.

## Overview

DICOMWeb provides HTTP-based access to DICOM data using the DICOMweb standard. It supports querying, retrieving, and storing DICOM objects through RESTful APIs.

### Key Features

- **QIDO-RS**: Query for studies, series, and instances
- **WADO-RS**: Retrieve DICOM objects and rendered images
- **STOW-RS**: Store DICOM objects
- **UPS-RS**: Unified Procedure Step support
- **OAuth2**: Secure authentication support
- **Caching**: Response caching with LRU eviction
- **Server**: Lightweight DICOMweb server implementation

## Topics

### Getting Started

- <doc:DICOMwebGuide>

### DICOMweb Client

- ``DICOMwebClient``
- ``DICOMwebConfiguration``
- ``DICOMwebCapabilities``
- ``DICOMwebURLBuilder``

### QIDO Query

- ``QIDOQuery``
- ``QIDOResults``

### STOW Storage

- ``STOWResponse``

### Unified Procedure Step

- ``UPSClient``
- ``UPSQuery``
- ``UPSResults``
- ``Workitem``
- ``UPSStorageProvider``

### JSON Encoding

- ``DICOMJSONDecoder``
- ``DICOMJSONEncoder``

### Media Types

- ``DICOMMediaType``
- ``MultipartMIME``

### HTTP Client

- ``HTTPClient``

### Conformance

- ``ConformanceStatement``
- ``ConformanceStatementGenerator``

### Server

- ``DICOMwebServer``
- ``DICOMwebServerConfiguration``
- ``DICOMwebStorageProvider``
- ``InMemoryStorageProvider``

### Caching

- ``InMemoryCache``

### OAuth2

- ``OAuth2Client``
- ``OAuth2Configuration``
- ``TokenStore``

### Logging

- ``DICOMwebLogger``

### Error Handling

- ``DICOMwebError``
