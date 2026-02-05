# DICOMKit Conformance Statement

## Introduction

This document describes the DICOM conformance of DICOMKit, a pure Swift DICOM toolkit for Apple platforms.

### Conformance Statement Template

This Conformance Statement follows the template defined in DICOM PS3.2 (Conformance).

### Document Information

| Field | Value |
|-------|-------|
| Product Name | DICOMKit |
| Version | 1.0.13 |
| DICOM Standard Version | 2025e |
| Document Date | February 2026 |

## Implementation Model

### Application Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    User Application                          │
├─────────────────────────────────────────────────────────────┤
│                        DICOMKit                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  DICOMCore  │  │ DICOMNetwork│  │     DICOMWeb        │  │
│  │  (Parser)   │  │  (DIMSE)    │  │  (REST Services)    │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│            Local Storage / PACS / DICOMweb Server           │
└─────────────────────────────────────────────────────────────┘
```

### Functional Definitions

DICOMKit provides the following DICOM functions:

| Function | Description |
|----------|-------------|
| File Reading | Parse DICOM Part 10 files |
| File Writing | Create DICOM Part 10 files |
| Image Rendering | Display pixel data with windowing |
| Network SCU | Query, retrieve, and store via network |
| Network SCP | Receive and serve DICOM objects |
| DICOMweb Client | QIDO-RS, WADO-RS, STOW-RS |

## AE Specifications

### Application Entity (AE) Support

DICOMKit supports configurable AE Titles for network operations:

| Parameter | Description | Default |
|-----------|-------------|---------|
| AE Title | Calling AE Title | Configurable |
| Called AE Title | Remote AE Title | Configurable |
| Maximum PDU Size | Maximum PDU receive size | 16384 |
| Implementation Class UID | 1.2.826.0.1.3680043.10.1165 | Fixed |
| Implementation Version Name | DICOMKIT_1_0 | Version-specific |

## SOP Classes

### Supported Storage SOP Classes

DICOMKit supports reading and writing the following Storage SOP Classes:

| SOP Class | UID | Role |
|-----------|-----|------|
| CT Image Storage | 1.2.840.10008.5.1.4.1.1.2 | SCU/SCP |
| MR Image Storage | 1.2.840.10008.5.1.4.1.1.4 | SCU/SCP |
| Enhanced MR Image Storage | 1.2.840.10008.5.1.4.1.1.4.1 | SCU/SCP |
| CR Image Storage | 1.2.840.10008.5.1.4.1.1.1 | SCU/SCP |
| DX Image Storage | 1.2.840.10008.5.1.4.1.1.1.1 | SCU/SCP |
| Digital Mammography X-Ray Image Storage | 1.2.840.10008.5.1.4.1.1.1.2 | SCU/SCP |
| Secondary Capture Image Storage | 1.2.840.10008.5.1.4.1.1.7 | SCU/SCP |
| Multi-frame True Color Secondary Capture | 1.2.840.10008.5.1.4.1.1.7.4 | SCU/SCP |
| Ultrasound Multi-frame Image Storage | 1.2.840.10008.5.1.4.1.1.3.1 | SCU/SCP |
| X-Ray Angiographic Image Storage | 1.2.840.10008.5.1.4.1.1.12.1 | SCU/SCP |
| Nuclear Medicine Image Storage | 1.2.840.10008.5.1.4.1.1.20 | SCU/SCP |
| PET Image Storage | 1.2.840.10008.5.1.4.1.1.128 | SCU/SCP |
| RT Structure Set Storage | 1.2.840.10008.5.1.4.1.1.481.3 | SCU/SCP |
| RT Plan Storage | 1.2.840.10008.5.1.4.1.1.481.5 | SCU/SCP |
| RT Dose Storage | 1.2.840.10008.5.1.4.1.1.481.2 | SCU/SCP |
| Segmentation Storage | 1.2.840.10008.5.1.4.1.1.66.4 | SCU/SCP |
| Parametric Map Storage | 1.2.840.10008.5.1.4.1.1.30 | SCU/SCP |
| Grayscale Softcopy Presentation State | 1.2.840.10008.5.1.4.1.1.11.1 | SCU/SCP |
| Color Softcopy Presentation State | 1.2.840.10008.5.1.4.1.1.11.2 | SCU/SCP |
| Pseudo-Color Softcopy Presentation State | 1.2.840.10008.5.1.4.1.1.11.3 | SCU/SCP |
| Basic Text SR | 1.2.840.10008.5.1.4.1.1.88.11 | SCU/SCP |
| Enhanced SR | 1.2.840.10008.5.1.4.1.1.88.22 | SCU/SCP |
| Comprehensive SR | 1.2.840.10008.5.1.4.1.1.88.33 | SCU/SCP |
| Comprehensive 3D SR | 1.2.840.10008.5.1.4.1.1.88.34 | SCU/SCP |

### Query/Retrieve SOP Classes

| SOP Class | UID | Role |
|-----------|-----|------|
| Patient Root Q/R Find | 1.2.840.10008.5.1.4.1.2.1.1 | SCU |
| Patient Root Q/R Move | 1.2.840.10008.5.1.4.1.2.1.2 | SCU |
| Patient Root Q/R Get | 1.2.840.10008.5.1.4.1.2.1.3 | SCU |
| Study Root Q/R Find | 1.2.840.10008.5.1.4.1.2.2.1 | SCU |
| Study Root Q/R Move | 1.2.840.10008.5.1.4.1.2.2.2 | SCU |
| Study Root Q/R Get | 1.2.840.10008.5.1.4.1.2.2.3 | SCU |

### Verification SOP Class

| SOP Class | UID | Role |
|-----------|-----|------|
| Verification | 1.2.840.10008.1.1 | SCU/SCP |

## Transfer Syntax Support

### Supported Transfer Syntaxes

| Transfer Syntax | UID | Read | Write |
|-----------------|-----|------|-------|
| Implicit VR Little Endian | 1.2.840.10008.1.2 | ✅ | ✅ |
| Explicit VR Little Endian | 1.2.840.10008.1.2.1 | ✅ | ✅ |
| Explicit VR Big Endian (Retired) | 1.2.840.10008.1.2.2 | ✅ | ✅ |
| Deflated Explicit VR LE | 1.2.840.10008.1.2.1.99 | ✅ | ✅ |
| JPEG Baseline (Process 1) | 1.2.840.10008.1.2.4.50 | ✅ | ✅ |
| JPEG Extended (Process 2 & 4) | 1.2.840.10008.1.2.4.51 | ✅ | ⚠️ |
| JPEG Lossless (Process 14) | 1.2.840.10008.1.2.4.57 | ✅ | ⚠️ |
| JPEG Lossless (Process 14, SV1) | 1.2.840.10008.1.2.4.70 | ✅ | ✅ |
| JPEG 2000 Lossless | 1.2.840.10008.1.2.4.90 | ✅ | ✅ |
| JPEG 2000 Lossy | 1.2.840.10008.1.2.4.91 | ✅ | ✅ |
| RLE Lossless | 1.2.840.10008.1.2.5 | ✅ | ✅ |

**Legend**: ✅ Full support, ⚠️ Partial support

## Character Set Support

### Supported Specific Character Sets

| Character Set | ISO Registration | Support |
|---------------|------------------|---------|
| Default (ASCII) | ISO IR 6 | ✅ |
| Latin-1 | ISO IR 100 | ✅ |
| Latin-2 (Central European) | ISO IR 101 | ✅ |
| Latin-3 | ISO IR 109 | ✅ |
| Latin-4 (Baltic) | ISO IR 110 | ✅ |
| Latin-5 (Turkish) | ISO IR 148 | ✅ |
| Cyrillic | ISO IR 144 | ✅ |
| Greek | ISO IR 126 | ✅ |
| Arabic | ISO IR 127 | ✅ |
| Hebrew | ISO IR 138 | ✅ |
| Thai | ISO IR 166 | ✅ |
| Japanese Katakana | ISO IR 13 | ✅ |
| Japanese Romaji | ISO IR 14 | ✅ |
| Japanese Kanji | ISO IR 87 | ✅ |
| Japanese Supplementary Kanji | ISO IR 159 | ✅ |
| Korean | ISO IR 149 | ✅ |
| UTF-8 | ISO IR 192 | ✅ |

### ISO 2022 Escape Sequences

DICOMKit supports ISO 2022 escape sequences for character set switching within strings.

## DICOMweb Support

### QIDO-RS (Query)

| Level | Supported |
|-------|-----------|
| All Studies | ✅ |
| Study | ✅ |
| All Series | ✅ |
| Study's Series | ✅ |
| All Instances | ✅ |
| Study's Instances | ✅ |
| Series' Instances | ✅ |

### WADO-RS (Retrieve)

| Retrieval | Supported |
|-----------|-----------|
| Study | ✅ |
| Series | ✅ |
| Instance | ✅ |
| Frames | ✅ |
| Rendered (JPEG/PNG) | ✅ |
| Metadata | ✅ |
| Bulkdata | ✅ |

### STOW-RS (Store)

| Feature | Supported |
|---------|-----------|
| Single Instance | ✅ |
| Multiple Instances | ✅ |
| Multipart Request | ✅ |

### UPS-RS (Worklist)

| Operation | Supported |
|-----------|-----------|
| Create | ✅ |
| Update | ✅ |
| Change State | ✅ |
| Query | ✅ |
| Retrieve | ✅ |

## Communication Profiles

### Supported Network Protocols

| Protocol | Support |
|----------|---------|
| TCP/IP | ✅ |
| TLS 1.2 | ✅ |
| TLS 1.3 | ✅ |
| HTTP/HTTPS | ✅ |

### Port Configuration

Default ports are configurable:
- DICOM Upper Layer: 104 or 11112 (configurable)
- DICOMweb: 80 (HTTP) or 443 (HTTPS)

## Security

### Authentication

| Method | Support |
|--------|---------|
| None (Unsecured) | ✅ |
| User Identity Negotiation | ✅ |
| TLS Client Certificates | ✅ |
| OAuth2 (DICOMweb) | ✅ |

### Encryption

| Feature | Support |
|---------|---------|
| TLS 1.2+ | ✅ |
| AES-256 | ✅ |
| Certificate Validation | ✅ |

### Audit Logging

DICOMKit supports IHE ATNA audit logging for security events.

## Annexes

### A. Private Tags

DICOMKit includes dictionaries for common vendor private tags:

- Siemens (including CSA headers)
- GE Healthcare
- Philips
- Canon/Toshiba

### B. Platform Support

| Platform | Minimum Version |
|----------|-----------------|
| iOS | 17.0 |
| macOS | 14.0 |
| visionOS | 1.0 |
| Swift | 6.2 |

### C. Known Limitations

1. **Deflated Transfer Syntax**: Requires Apple platforms (uses Compression framework)
2. **JPEG-LS**: Not supported
3. **MPEG-2/4 Video**: Not supported
4. **Network SCP**: Limited concurrent connections (configurable)

### D. References

- DICOM Standard 2025e: https://www.dicomstandard.org/current
- PS3.2: Conformance
- PS3.3: Information Object Definitions
- PS3.4: Service Class Specifications
- PS3.5: Data Structures and Encoding
- PS3.6: Data Dictionary
- PS3.7: Message Exchange
- PS3.10: Media Storage and File Format
- PS3.18: Web Services
