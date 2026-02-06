# Network Operations Playgrounds

This directory contains comprehensive examples for DICOM network operations using DICOMKit.

## Files

### 3.1_PACSQuery.swift
**PACS Query (C-FIND) Examples**
- Patient, study, series, and instance queries
- Query filters and wildcards
- Date range queries
- Modality filters
- Patient Root and Study Root information models
- Error handling patterns
- **10+ test cases**

### 3.2_PACSRetrieve.swift
**PACS Retrieve (C-MOVE/C-GET) Examples**
- C-MOVE operations (retrieve to third-party destination)
- C-GET operations (direct retrieval)
- Progress monitoring
- Priority settings (HIGH, MEDIUM, LOW)
- Error handling and retry logic
- Batch retrieve operations
- **27+ test cases**

### 3.3_PACSSend.swift
**PACS Send (C-STORE) Examples**
- Single instance storage
- Batch storage operations
- Progress monitoring
- Storage verification
- Presentation context negotiation
- Transfer syntax preferences
- Error handling and retry
- Compression support
- **28+ test cases**

### 3.4_DICOMweb.swift
**DICOMweb (QIDO-RS, WADO-RS, STOW-RS) Examples**
- QIDO-RS: Search for studies, series, instances
- WADO-RS: Retrieve DICOM objects, metadata, rendered images
- STOW-RS: Store instances over HTTP
- RESTful patterns with async/await
- Authentication (Bearer, Basic, Custom headers)
- Streaming retrieval
- Frame retrieval
- Thumbnail generation
- **38+ test cases**

### 3.5_ModalityWorklist.swift
**Modality Worklist (C-FIND MWL) Examples**
- Query scheduled procedures
- Filter by date/time range
- Filter by station AE Title
- Filter by patient ID or accession number
- Complete worklist processing
- Integration with modality workflow
- MPPS workflow patterns
- **20+ test cases**

## Usage

Each file contains:
1. **9 comprehensive examples** demonstrating core functionality
2. **Complete test suite** with 20-38 test cases
3. **Detailed usage notes** explaining:
   - Setup requirements
   - DICOM protocol details
   - Common issues and solutions
   - Production considerations
   - DICOM standard references

## Requirements

- Network operations require `#if canImport(Network)` guards
- Access to DICOM PACS server or test environment
- Valid AE titles and network configuration
- For DICOMweb: HTTP/HTTPS connectivity to DICOMweb server

## Testing

To test locally:
1. Set up a test PACS server (DCM4CHEE, Orthanc, etc.)
2. Update host/port/AE titles in examples
3. Run examples individually or as test suite

## Documentation

Each file includes comprehensive documentation:
- DICOM protocol explanations
- Tag definitions and usage
- Configuration options
- Error handling strategies
- Performance considerations
- Security best practices
- References to PS3.x specifications

## Total Coverage

- **5 files**
- **45 examples total** (9 per file)
- **123+ test cases total**
- All major DICOM network operations covered
- Both traditional DICOM networking and DICOMweb

## References

- PS3.4: Service Class Specifications
- PS3.7: Message Exchange
- PS3.18: Web Services (DICOMweb)
- IHE Radiology Technical Framework
