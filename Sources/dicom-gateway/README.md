# dicom-gateway

Bridge DICOM with other healthcare standards (HL7 v2, HL7 FHIR, IHE profiles) for interoperability and integration with broader healthcare IT systems.

## Features

### Protocol Support
- **HL7 v2**: Parse and generate HL7 v2 messages (ADT, ORM, ORU)
- **HL7 FHIR**: Convert DICOM to FHIR resources (ImagingStudy, Patient, Practitioner, DiagnosticReport)
- **Bidirectional Conversion**: DICOM ↔ HL7, DICOM ↔ FHIR
- **Batch Processing**: Convert multiple files at once

### Conversion Modes

#### DICOM to HL7
- Extract demographics, study info for HL7 messages
- Support ADT (Admission/Discharge/Transfer) messages
- Support ORM (Order Message) for imaging orders
- Support ORU (Observation Result) for study results

#### HL7 to DICOM
- Populate DICOM tags from HL7 messages
- Support patient demographics (PID segment)
- Support order information (ORC, OBR segments)
- Template-based conversion for existing DICOM files

#### DICOM to FHIR
- Create FHIR ImagingStudy from DICOM studies
- Generate Patient resources from demographics
- Create Practitioner resources from referring physicians
- Generate DiagnosticReport resources

#### FHIR to DICOM
- Populate DICOM from FHIR ImagingStudy
- Extract patient data from FHIR Patient resources
- Template-based conversion

## Installation

```bash
# Build from source
swift build -c release

# Or use with Swift Package Manager
swift package install
```

## Usage

### DICOM to HL7 Conversion

```bash
# Convert DICOM to HL7 ADT message
dicom-gateway dicom-to-hl7 study.dcm --output study.hl7 --message-type ADT

# Convert to ORM (Order Message)
dicom-gateway dicom-to-hl7 study.dcm --output order.hl7 --message-type ORM

# Convert to ORU (Observation Result)
dicom-gateway dicom-to-hl7 study.dcm --output result.hl7 --message-type ORU

# Specify ADT event type
dicom-gateway dicom-to-hl7 study.dcm --output admit.hl7 --message-type ADT --event-type A01

# Verbose output
dicom-gateway dicom-to-hl7 study.dcm --output study.hl7 -v
```

### HL7 to DICOM Conversion

```bash
# Convert HL7 to DICOM
dicom-gateway hl7-to-dicom message.hl7 --output study.dcm

# Use template DICOM file
dicom-gateway hl7-to-dicom message.hl7 --template template.dcm --output study.dcm

# Verbose output
dicom-gateway hl7-to-dicom message.hl7 --output study.dcm -v
```

### DICOM to FHIR Conversion

```bash
# Convert to FHIR ImagingStudy (default)
dicom-gateway dicom-to-fhir study.dcm --output study.json

# Convert to Patient resource
dicom-gateway dicom-to-fhir study.dcm --output patient.json --resource Patient

# Convert to Practitioner resource
dicom-gateway dicom-to-fhir study.dcm --output practitioner.json --resource Practitioner

# Convert to DiagnosticReport
dicom-gateway dicom-to-fhir study.dcm --output report.json --resource DiagnosticReport

# Pretty-print JSON
dicom-gateway dicom-to-fhir study.dcm --output study.json --pretty

# Output to stdout
dicom-gateway dicom-to-fhir study.dcm --resource ImagingStudy
```

### FHIR to DICOM Conversion

```bash
# Convert FHIR ImagingStudy to DICOM
dicom-gateway fhir-to-dicom imaging-study.json --output study.dcm

# Use template
dicom-gateway fhir-to-dicom patient.json --template template.dcm --output study.dcm

# Verbose output
dicom-gateway fhir-to-dicom imaging-study.json --output study.dcm -v
```

### Batch Conversion

```bash
# Batch convert DICOM to HL7
dicom-gateway batch dicom-to-hl7 "studies/*.dcm" --output hl7-messages/

# Batch convert DICOM to FHIR ImagingStudy
dicom-gateway batch dicom-to-fhir "studies/*.dcm" --output fhir-resources/

# Batch convert to FHIR Patient resources
dicom-gateway batch dicom-to-fhir "studies/*.dcm" --output patients/ --type Patient

# Verbose batch conversion
dicom-gateway batch dicom-to-fhir "studies/*.dcm" --output fhir/ -v
```

## HL7 v2 Message Types

### ADT (Admission/Discharge/Transfer)
- **A01**: Admit/visit notification
- **A02**: Transfer a patient
- **A03**: Discharge/end visit
- **A04**: Register a patient
- **A05**: Pre-admit a patient

### ORM (Order Message)
- New imaging orders
- Includes patient demographics, order details, procedure information

### ORU (Observation Result)
- Imaging study results
- Includes observations, measurements, image counts

## FHIR Resource Types

### ImagingStudy
- Study-level information from DICOM
- Study UID, date, time, modality
- Number of series and instances
- Patient reference

### Patient
- Patient demographics from DICOM
- Patient ID, name, birth date, gender
- Identifier mappings

### Practitioner
- Referring physician information
- Name extracted from DICOM

### DiagnosticReport
- Study as a diagnostic report
- Code, effective date/time
- Patient reference

## Data Mapping

### DICOM to HL7 ADT
```
DICOM Tag                    → HL7 Segment.Field
─────────────────────────────────────────────────
Patient ID (0010,0020)       → PID-2
Patient Name (0010,0010)     → PID-5
Birth Date (0010,0030)       → PID-7
Sex (0010,0040)              → PID-8
Accession Number (0008,0050) → PV1-19
```

### DICOM to HL7 ORM
```
DICOM Tag                    → HL7 Segment.Field
─────────────────────────────────────────────────
Accession Number (0008,0050) → ORC-2, OBR-2
Study Instance UID           → ORC-3, OBR-3
Study Description (0008,1030)→ OBR-4
Modality (0008,0060)         → OBR-4
Study Date/Time              → OBR-7
```

### DICOM to FHIR ImagingStudy
```
DICOM Tag                      → FHIR Element
───────────────────────────────────────────────
Study Instance UID (0020,000D) → identifier.value
Study Date/Time (0008,0020/30) → started
Modality (0008,0060)           → modality.code
Study Description (0008,1030)  → description
Number of Series (0020,1206)   → numberOfSeries
Number of Instances (0020,1208)→ numberOfInstances
Patient ID (0010,0020)         → subject.reference
```

## Examples

### Complete HL7 ADT Message

```hl7
MSH|^~\&|DICOMKit|IMAGING|HIS|HOSPITAL|20260215120000||ADT^A01|MSG001|P|2.5
EVN|A01|20260215120000
PID||12345||DOE^JOHN^MICHAEL||19800115|M
PV1||O|||||||||||||||||||ACC12345
```

### Complete FHIR ImagingStudy Resource

```json
{
  "resourceType": "ImagingStudy",
  "status": "available",
  "identifier": [
    {
      "system": "urn:dicom:uid",
      "value": "urn:oid:1.2.840.113619.2.62.994044785528.114289542805"
    }
  ],
  "started": "2026-02-15T12:00:00",
  "modality": [
    {
      "system": "http://dicom.nema.org/resources/ontology/DCM",
      "code": "CT"
    }
  ],
  "description": "CT Chest with Contrast",
  "numberOfSeries": 3,
  "numberOfInstances": 150,
  "subject": {
    "reference": "Patient/12345"
  }
}
```

## Error Handling

The tool provides clear error messages for common issues:

- **Invalid input file**: File not found or unreadable
- **Parsing failed**: Malformed HL7 or FHIR data
- **Conversion failed**: Missing required DICOM tags
- **Invalid protocol**: Unsupported message or resource type

Use `--verbose` flag for detailed error information and conversion progress.

## Development

### Building

```bash
# Debug build
swift build

# Release build
swift build -c release

# Run tests
swift test
```

### File Structure

```
dicom-gateway/
├── main.swift                   # CLI interface
├── GatewayTypes.swift           # Common types and errors
├── HL7Parser.swift              # HL7 v2 parsing and generation
├── DICOMToHL7Converter.swift    # DICOM → HL7 conversion
├── HL7ToDICOMConverter.swift    # HL7 → DICOM conversion
├── FHIRConverter.swift          # DICOM ↔ FHIR conversion
└── README.md                    # This file
```

## Standards Compliance

- **DICOM**: Compliant with DICOM PS3 standard
- **HL7 v2.5**: Supports HL7 v2.5 message structure
- **FHIR R4**: Generates FHIR R4 resources
- **IHE**: Foundation for IHE profile support (future)

## Limitations

### Current Implementation

- **HL7 v2**: Basic support for ADT, ORM, ORU messages
- **FHIR**: Core resources only (ImagingStudy, Patient, Practitioner, DiagnosticReport)
- **IHE Profiles**: Not yet implemented (planned for future releases)
- **Listener/Forwarder Modes**: Not yet implemented (planned for future releases)

### Future Enhancements

- Real-time HL7 message listener
- DICOM event forwarder
- Bidirectional synchronization
- IHE profile support (PDI, XDS-I, PIX, etc.)
- Custom mapping configuration files
- Additional HL7 message types (DFT, SIU, etc.)
- Additional FHIR resources (Observation, Procedure, etc.)

## License

Part of DICOMKit - See main repository license.

## Version

1.0.0 - Initial implementation with HL7 v2 and FHIR R4 support
