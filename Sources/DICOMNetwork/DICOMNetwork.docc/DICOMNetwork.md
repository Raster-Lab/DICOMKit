# ``DICOMNetwork``

DICOM network protocol support for C-ECHO, C-STORE, C-FIND, C-MOVE, and C-GET operations.

## Overview

DICOMNetwork provides a complete implementation of the DICOM Upper Layer Protocol for network communication. It enables your application to connect to PACS servers, query for studies, and retrieve images.

### Key Features

- **DIMSE Services**: C-ECHO, C-STORE, C-FIND, C-MOVE, C-GET
- **Association Management**: Full state machine implementation
- **Security**: TLS/SSL support with certificate validation
- **Reliability**: Connection pooling, retry policies, circuit breakers
- **Storage SCP**: Receive images from modalities
- **Storage Commitment**: Verify storage transactions

## Topics

### Getting Started

- <doc:NetworkingGuide>

### DICOM Client

- ``DICOMClient``
- ``DICOMConnection``
- ``Association``

### Query Services

- ``QueryService``
- ``QueryKeys``
- ``QueryLevel``
- ``QueryResults``
- ``QueryRetrieveInformationModel``

### Retrieve Services

- ``RetrieveService``

### Storage Services

- ``StorageService``
- ``DICOMStorageClient``
- ``StorageSCP``

### Verification Service

- ``VerificationService``

### Storage Commitment

- ``StorageCommitmentService``
- ``StorageCommitmentSCP``

### Store and Forward

- ``StoreAndForwardQueue``

### DIMSE Protocol

- ``DIMSECommand``
- ``DIMSEStatus``
- ``DIMSEPriority``
- ``CommandSet``
- ``CommandTag``

### PDU Types

- ``AssociateRequestPDU``
- ``AssociateAcceptPDU``
- ``AssociateRejectPDU``
- ``DataTransferPDU``
- ``ReleasePDU``
- ``AbortPDU``
- ``PDU``
- ``PDUType``
- ``PDUDecoder``

### Association Management

- ``AssociationStateMachine``
- ``PresentationContext``
- ``AETitle``

### Message Assembly

- ``MessageAssembler``

### Security

- ``TLSConfiguration``
- ``UserIdentity``

### Reliability

- ``ConnectionPool``
- ``RetryPolicy``
- ``CircuitBreaker``
- ``BandwidthLimiter``
- ``TransferPriorityQueue``

### Logging and Audit

- ``DICOMLogger``
- ``AuditLogger``
- ``DICOMValidator``

### Error Handling

- ``DICOMNetworkError``
