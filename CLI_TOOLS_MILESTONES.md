# DICOMKit CLI Tools - Milestone Plan

**Created**: February 2026  
**Last Updated**: February 2026  
**Purpose**: Comprehensive milestone plan for all DICOMKit CLI utilities  
**Inspiration**: dcm4che utilities suite

---

## Overview

This document provides a comprehensive milestone-based roadmap for developing CLI tools for DICOMKit, inspired by the extensive dcm4che utilities suite. The plan builds upon existing Phase 1 and Phase 2 work to create a complete, production-ready command-line toolkit for DICOM workflows.

### Current Status

**Phase 1**: ✅ Complete (7 tools, 160+ tests)  
**Phase 2**: 🚧 In Progress (1 of 4 priority tools complete)  
**Phase 3-6**: 📋 Planned (20+ additional utilities)

**Total Planned Tools**: 32 utilities across 6 phases

---

## Milestone Structure

Each milestone represents a logical grouping of related CLI tools with:
- **Priority Level**: Critical, High, Medium, or Low
- **Complexity**: Low, Medium, High, or Very High
- **Dependencies**: Other milestones or DICOMKit features required
- **Timeline**: Estimated developer effort
- **Test Coverage**: Target number of test cases

---

## Phase 1: Core Tools (✅ COMPLETE)

**Status**: ✅ Released in v1.0.14  
**Tools**: 7  
**Tests**: 160+  
**Timeline**: 3 weeks (Complete)

### Tools Included
1. ✅ **dicom-info** - Display DICOM metadata (15 tests)
2. ✅ **dicom-convert** - Transfer syntax conversion & image export (22 tests)
3. ✅ **dicom-validate** - DICOM conformance validation (30 tests)
4. ✅ **dicom-anon** - Anonymization & de-identification (28 tests)
5. ✅ **dicom-dump** - Hexadecimal inspection (18 tests)
6. ✅ **dicom-query** - PACS C-FIND queries (20 tests)
7. ✅ **dicom-send** - PACS C-STORE operations (27 tests)

**Reference**: See `CLI_TOOLS_PLAN.md` for complete specifications

---

## Phase 2: Enhanced Workflow Tools (🚧 IN PROGRESS)

**Status**: 🚧 In Progress  
**Target Version**: v1.0.15-v1.1.2  
**Priority**: High  
**Timeline**: 3-4 weeks

### Milestone 2.1: File Comparison (✅ COMPLETE)

**Tool**: `dicom-diff`  
**Status**: ✅ Complete  
**Priority**: High  
**Complexity**: Medium  
**Tests**: 20+ (planned)  
**Dependencies**: None

#### Features
- Side-by-side DICOM file comparison
- Tag-level diff reporting
- Value change detection
- Sequence comparison
- Ignore pixel data option
- JSON/text output formats

#### Usage Examples
```bash
# Compare two DICOM files
dicom-diff file1.dcm file2.dcm

# Compare ignoring pixel data
dicom-diff file1.dcm file2.dcm --ignore-pixel-data

# JSON output for programmatic use
dicom-diff file1.dcm file2.dcm --format json
```

---

### Milestone 2.2: PACS Retrieval

**Tool**: `dicom-retrieve`  
**Status**: 📋 Planned  
**Priority**: Critical  
**Complexity**: High  
**Timeline**: 1 week  
**Tests**: 30+ (planned)  
**Dependencies**: DICOMNetwork C-MOVE/C-GET support

#### Features
- C-MOVE retrieval from PACS
- C-GET direct retrieval
- Study/Series/Instance level operations
- Bulk retrieval from UID lists
- Progress tracking
- Automatic retry on failures
- Output organization (hierarchical/flat)
- Integration with dicom-query

#### Deliverables
- [ ] C-MOVE implementation
- [ ] C-GET implementation
- [ ] C-STORE SCP for receiving
- [ ] Query integration
- [ ] Bulk retrieval support
- [ ] Progress reporter
- [ ] Output organizer
- [ ] Network error handling
- [ ] 30+ unit tests
- [ ] Integration tests with mock PACS
- [ ] Documentation and examples

#### Test Cases
- C-MOVE at Patient/Study/Series/Instance levels
- C-GET operations
- Network failure and retry logic
- UID list parsing
- Output directory organization
- Progress reporting accuracy
- Connection verification
- Timeout handling

#### Usage Examples
```bash
# Retrieve study using C-MOVE
dicom-retrieve pacs://server:11112 \
  --aet MY_SCU \
  --move-dest MY_SCP \
  --study-uid 1.2.840.113619.2.xxx \
  --output study_dir/

# Retrieve using C-GET (simpler, no move destination)
dicom-retrieve pacs://server:11112 \
  --aet MY_SCU \
  --study-uid 1.2.840.113619.2.xxx \
  --method c-get \
  --output study_dir/

# Bulk retrieve from UID list
dicom-retrieve pacs://server:11112 \
  --aet MY_SCU \
  --move-dest MY_SCP \
  --uid-list study_uids.txt \
  --output studies/ \
  --parallel 4
```

**Lines of Code Estimate**: 650-750

---

### Milestone 2.3: Multi-Frame Splitting

**Tool**: `dicom-split`  
**Status**: 📋 Planned  
**Priority**: High  
**Complexity**: Medium  
**Timeline**: 4 days  
**Tests**: 25+ (planned)  
**Dependencies**: DICOMKit multi-frame support

#### Features
- Extract individual frames from multi-frame DICOM
- Support Enhanced CT/MR/XA formats
- Support legacy multi-frame formats (US, etc.)
- Frame range selection
- DICOM or image output (PNG, JPEG, TIFF)
- Metadata preservation
- Per-frame functional groups handling
- Custom naming patterns
- Batch processing

#### Deliverables
- [ ] Multi-frame detection
- [ ] Frame extraction logic
- [ ] Shared functional groups handling
- [ ] Per-frame functional groups handling
- [ ] DICOM file creation per frame
- [ ] Image export per frame
- [ ] SOP Instance UID generation
- [ ] Metadata inheritance
- [ ] Batch processor
- [ ] 25+ unit tests
- [ ] Documentation and examples

#### Test Cases
- Enhanced multi-frame CT/MR/XA extraction
- Legacy multi-frame US extraction
- Frame range selection
- DICOM output format
- Image output formats (PNG, JPEG, TIFF)
- Metadata preservation validation
- UID uniqueness verification
- Batch processing
- Error handling for invalid frames

#### Usage Examples
```bash
# Extract all frames to DICOM files
dicom-split multiframe.dcm --output frames/

# Extract specific frames
dicom-split multiframe.dcm --frames 1,5,10-15 --output selected/

# Extract as PNG images with windowing
dicom-split ct-multiframe.dcm \
  --format png \
  --apply-window \
  --window-center 40 \
  --window-width 400 \
  --output images/

# Batch processing with custom naming
dicom-split studies/ \
  --output split_studies/ \
  --pattern "frame_{number:04d}_{modality}.dcm" \
  --recursive
```

**Lines of Code Estimate**: 450-550

---

### Milestone 2.4: Multi-Frame Merging

**Tool**: `dicom-merge`  
**Status**: 📋 Planned  
**Priority**: Medium  
**Complexity**: High  
**Timeline**: 5 days  
**Tests**: 30+ (planned)  
**Dependencies**: DICOMKit multi-frame writing support

#### Features
- Combine single-frame images into multi-frame
- Support Enhanced MR/CT/XA formats
- Support legacy multi-frame creation
- Series combining into study
- Metadata consolidation
- Shared/per-frame functional groups
- Frame sorting and ordering
- UID generation
- Validation and consistency checks

#### Deliverables
- [ ] Single-to-multi-frame converter
- [ ] Enhanced multi-frame builder
- [ ] Functional groups creator
- [ ] Series combiner
- [ ] Study organizer
- [ ] Metadata validator
- [ ] Frame sorter
- [ ] UID generator
- [ ] 30+ unit tests
- [ ] Documentation and examples

#### Test Cases
- Single-frame to multi-frame conversion
- Enhanced CT/MR/XA creation
- Series combining
- Metadata consistency validation
- Frame ordering
- Functional groups creation
- UID generation and uniqueness
- Large dataset handling
- Error handling for incompatible files

#### Usage Examples
```bash
# Combine single frames into multi-frame
dicom-merge frame_*.dcm --output multiframe.dcm

# Create enhanced multi-frame CT
dicom-merge ct_slices/*.dcm \
  --output enhanced_ct.dcm \
  --format enhanced-ct

# Combine series into single study
dicom-merge series1/ series2/ \
  --output combined_study/ \
  --level study

# Custom frame ordering
dicom-merge slices/*.dcm \
  --output volume.dcm \
  --sort-by ImagePositionPatient \
  --order ascending
```

**Lines of Code Estimate**: 550-650

---

## Phase 3: Format Conversion Tools

**Status**: ✅ Complete (4 of 4 tools complete)  
**Target Version**: v1.1.3-v1.1.6  
**Priority**: Medium  
**Timeline**: 2-3 weeks (Completed February 2026)

### Milestone 3.1: JSON Conversion

**Tool**: `dicom-json`  
**Status**: ✅ Completed (February 2026)  
**Priority**: Medium  
**Complexity**: Medium  
**Timeline**: Completed in 1 day  
**Tests**: 20 tests implemented  
**Dependencies**: None

#### Features
- DICOM to JSON conversion (DICOM JSON Model)
- JSON to DICOM conversion
- DICOMweb JSON format support
- Bulk data URI handling
- Pretty-print and compact modes
- Streaming for large files
- Metadata filtering
- Schema validation (via DICOMJSONEncoder/Decoder)

#### Deliverables
- [x] DICOM to JSON serializer
- [x] JSON to DICOM deserializer
- [x] DICOMweb JSON format support
- [x] Bulk data handler
- [x] Streaming processor (basic implementation)
- [x] Schema validator (built-in with encoder/decoder)
- [x] 20 unit tests
- [x] Documentation and examples

#### Usage Examples
```bash
# Convert DICOM to JSON
dicom-json file.dcm --output file.json

# Convert JSON back to DICOM
dicom-json file.json --output file.dcm --reverse

# DICOMweb JSON format
dicom-json file.dcm --output file.json --format dicomweb

# Streaming for large files
dicom-json large.dcm --output large.json --stream
```

**Lines of Code**: 280 (main.swift)

---

### Milestone 3.2: XML Conversion

**Tool**: `dicom-xml`  
**Status**: ✅ Completed (February 2026)  
**Priority**: Low  
**Complexity**: Medium  
**Timeline**: Completed in 2 days  
**Tests**: 20 tests implemented  
**Dependencies**: None

#### Features
- DICOM to XML conversion (Native DICOM Model)
- XML to DICOM conversion
- DICOM Standard Part 19 format
- XPath query support
- XSLT transformation
- Pretty-print formatting
- Schema validation

#### Deliverables
- [x] DICOM to XML serializer
- [x] XML to DICOM deserializer
- [x] Part 19 format support
- [x] XPath query engine (filtering support)
- [x] XSLT processor (not implemented - not required for basic conversion)
- [x] Schema validator (built-in with encoder/decoder)
- [x] 20 unit tests
- [x] Documentation and examples

#### Usage Examples
```bash
# Convert DICOM to XML
dicom-xml file.dcm --output file.xml

# Convert XML back to DICOM
dicom-xml file.xml --output file.dcm --reverse

# Query with XPath
dicom-xml file.dcm --xpath "//PatientName" --output results.txt

# Apply XSLT transformation
dicom-xml file.dcm --xslt transform.xsl --output transformed.xml
```

**Lines of Code**: 268 (main.swift)

---

### Milestone 3.3: PDF/Document Handling

**Tool**: `dicom-pdf`  
**Status**: ✅ Completed (February 2026)  
**Priority**: Medium  
**Complexity**: Low  
**Timeline**: Completed in 2 days  
**Tests**: 16 tests implemented  
**Dependencies**: Milestone 11.1 (Encapsulated Document Support) ✅

#### Features
- Extract PDF from Encapsulated PDF DICOM
- Create Encapsulated PDF DICOM from PDF
- Support for CDA (Clinical Document Architecture)
- Support for STL/OBJ 3D models
- Metadata embedding
- Batch processing
- Document verification

#### Deliverables
- [x] PDF extraction
- [x] PDF encapsulation
- [x] CDA support
- [x] 3D model support (STL, OBJ, MTL)
- [x] Metadata handler
- [x] Batch processor
- [x] 16 unit tests
- [x] Documentation and examples

#### Usage Examples
```bash
# Extract PDF from DICOM
dicom-pdf report.dcm --output report.pdf --extract

# Create Encapsulated PDF DICOM
dicom-pdf report.pdf \
  --output report.dcm \
  --patient-name "DOE^JOHN" \
  --patient-id "12345" \
  --title "Radiology Report"

# Extract CDA document
dicom-pdf cda.dcm --output cda.xml --extract --format cda

# Batch extract all PDFs from directory
dicom-pdf study/*.dcm --output pdfs/ --extract --recursive
```

**Lines of Code**: 593 (main.swift)

---

### Milestone 3.4: Image Format Conversion

**Tool**: `dicom-image`  
**Status**: ✅ Completed (February 2026)  
**Priority**: Low  
**Complexity**: Medium  
**Timeline**: Completed in 3 days  
**Tests**: 19 tests implemented  
**Dependencies**: None

#### Features
- Enhanced image format support beyond dicom-convert
- DICOM creation from standard images (JPEG, PNG, TIFF)
- Secondary Capture SOP Class creation
- Metadata embedding from EXIF/IPTC
- Batch image-to-DICOM conversion
- Advanced color management
- Multi-page TIFF handling
- Raw image format support

#### Deliverables
- [x] Image to DICOM converter
- [x] Secondary Capture builder
- [x] EXIF/IPTC metadata importer
- [x] Color profile handler
- [x] Multi-page processor
- [x] Raw format support (platform dependent)
- [x] 19 unit tests
- [x] Documentation and examples

#### Usage Examples
```bash
# Convert JPEG to DICOM Secondary Capture
dicom-image photo.jpg \
  --output capture.dcm \
  --patient-name "DOE^JOHN" \
  --study-description "Photography"

# Batch convert with EXIF metadata
dicom-image photos/*.jpg \
  --output dicoms/ \
  --use-exif \
  --series-description "Clinical Photography"

# Convert multi-page TIFF
dicom-image multipage.tiff \
  --output frames/ \
  --split-pages

# Raw format with camera metadata
dicom-image raw_photo.cr2 \
  --output dicom_photo.dcm \
  --patient-id "12345"
```

**Lines of Code**: 660 (main.swift)

---

## Phase 4: DICOMDIR and Archive Tools

**Status**: ✅ Complete  
**Target Version**: v1.2.0-v1.2.2  
**Priority**: Medium  
**Timeline**: 2 weeks

### Milestone 4.1: DICOMDIR Management

**Tool**: `dicom-dcmdir`  
**Status**: 📋 Planned  
**Priority**: Medium  
**Complexity**: High  
**Timeline**: 5 days  
**Tests**: 30+ (planned)  
**Dependencies**: DICOMKit DICOMDIR support

#### Features
- Create DICOMDIR from DICOM files
- Update existing DICOMDIR
- Validate DICOMDIR structure
- Dump DICOMDIR contents
- Extract files from DICOMDIR media
- Profile support (STD-GEN-CD, STD-GEN-DVD)
- Directory record manipulation
- Icon image support

#### Deliverables
- [ ] DICOMDIR creator
- [ ] DICOMDIR updater
- [ ] DICOMDIR validator
- [ ] DICOMDIR dumper
- [ ] File extractor
- [ ] Profile handler
- [ ] Record manipulator
- [ ] Icon processor
- [ ] 30+ unit tests
- [ ] Documentation and examples

#### Usage Examples
```bash
# Create DICOMDIR for CD/DVD
dicom-dcmdir create study/ --output DICOMDIR --profile STD-GEN-CD

# Update DICOMDIR with new files
dicom-dcmdir update DICOMDIR --add new_series/

# Validate DICOMDIR
dicom-dcmdir validate DICOMDIR --detailed

# Dump DICOMDIR contents
dicom-dcmdir dump DICOMDIR --format tree

# Extract files from DICOMDIR media
dicom-dcmdir extract /media/cdrom/DICOMDIR --output extracted/
```

**Lines of Code Estimate**: 600-700

---

### Milestone 4.2: Archive Management

**Tool**: `dicom-archive`  
**Status**: ✅ Complete  
**Priority**: Low  
**Complexity**: Very High  
**Timeline**: 7 days  
**Tests**: 45 (complete)  
**Dependencies**: DICOMKit, DICOMCore, DICOMDictionary

#### Features
- Local DICOM archive creation with JSON-based metadata index
- Patient/Study/Series directory organization
- Query interface with wildcard matching (* and ?)
- Multiple output formats (table, json, text, tree)
- Deduplication by SOP Instance UID
- Integrity checking (file existence, size validation, DICOM readability)
- Orphaned file detection
- File import from directories (recursive)
- File export with filtering (by study/series/patient)
- Archive statistics with modality and SOP Class breakdown

#### Deliverables
- [x] Archive creator (init subcommand)
- [x] File organizer (Patient/Study/Series hierarchy)
- [x] JSON metadata index (archive_index.json)
- [x] Query engine with wildcard matching
- [x] Import engine with deduplication
- [x] Export engine with filtering
- [x] Integrity checker with orphan detection
- [x] Statistics reporter
- [x] 45 unit tests
- [x] README documentation with examples

#### Subcommands
- `init` - Initialize a new archive
- `import` - Import DICOM files (with recursive and duplicate skip support)
- `query` - Query archive metadata (patient name, ID, modality, study date, study UID)
- `list` - List archive contents (tree, table, JSON formats)
- `export` - Export files from archive (by study/series/patient, flat or hierarchical)
- `check` - Check archive integrity (file existence, size, DICOM readability, orphans)
- `stats` - Show archive statistics (text or JSON)

#### Usage Examples
```bash
# Initialize archive
dicom-archive init --path /data/dicom_archive

# Import DICOM files
dicom-archive import file1.dcm dir/ --archive /data/archive --recursive

# Query archive
dicom-archive query --archive /data/archive --patient-name "DOE*" --format table

# List archive contents
dicom-archive list --archive /data/archive --format tree

# Export study from archive
dicom-archive export --archive /data/archive --study-uid 1.2.3... --output /tmp/export/

# Check archive integrity
dicom-archive check --archive /data/archive --verify-files

# Show archive statistics
dicom-archive stats --archive /data/archive --format json
```

**Lines of Code**: 1,235 (main.swift) + 1,082 (tests)

---

### Milestone 4.3: Export Tool

**Tool**: `dicom-export`  
**Status**: ✅ Complete  
**Priority**: Medium  
**Complexity**: Medium  
**Timeline**: 4 days  
**Tests**: 40+ (implemented)  
**Dependencies**: None

#### Features
- Advanced image export beyond dicom-convert
- Export with embedded metadata (EXIF, TIFF tags)
- Contact sheet generation (grid layout with configurable columns, spacing, labels)
- Animated GIF for multi-frame (configurable FPS, loop count, scale, frame range)
- Bulk export with directory organization (flat, patient, study, series)
- Windowing support for all export modes
- DICOM to TIFF with tags

#### Deliverables
- [x] Image exporter with metadata (EXIF/TIFF embedding via ImageIO)
- [x] Contact sheet generator (grid layout with CGContext compositing)
- [x] Animation creator (GIF with CGImageDestination)
- [x] TIFF with DICOM tags (via EXIF metadata embedding)
- [ ] SVG overlay generator (deferred to future version)
- [x] Bulk processor (recursive directory scanning, organization schemes)
- [ ] Template engine (deferred to future version)
- [ ] Pipeline builder (deferred to future version)
- [x] 40+ unit tests (export formats, EXIF mapping, layout, animation, organization, DICOM I/O)
- [x] Documentation and examples (README.md with all subcommands)

#### Usage Examples
```bash
# Export single DICOM file with EXIF metadata
dicom-export single study.dcm \
  --output study.jpg \
  --embed-metadata \
  --exif-fields PatientName,StudyDate

# Create contact sheet for series
dicom-export contact-sheet file1.dcm file2.dcm file3.dcm \
  --output contact_sheet.png \
  --columns 4 \
  --thumbnail-size 256

# Export multi-frame as animated GIF
dicom-export animate multiframe.dcm --output animation.gif --fps 10

# Bulk export with organization
dicom-export bulk study/ \
  --output export/ \
  --organize-by series \
  --format png \
  --recursive
```

**Lines of Code**: 866 (main.swift) + 602 (tests)

---

## Phase 5: Network and Workflow Tools

**Status**: 📋 Planned  
**Target Version**: v1.2.3-v1.2.7  
**Priority**: Medium  
**Timeline**: 3-4 weeks

### Milestone 5.1: Integrated Query-Retrieve

**Tool**: `dicom-qr`  
**Status**: 📋 Planned  
**Priority**: High  
**Complexity**: Medium  
**Timeline**: 4 days  
**Tests**: 25+ (planned)  
**Dependencies**: dicom-query, dicom-retrieve

#### Features
- Integrated query-retrieve workflow
- Interactive study selection
- Automatic C-FIND → C-MOVE pipeline
- Query filters and presets
- Progress tracking across operations
- Resume interrupted retrievals
- Selective series retrieval
- Post-retrieval validation

#### Deliverables
- [ ] Query-retrieve orchestrator
- [ ] Interactive CLI interface
- [ ] Study selector
- [ ] Progress tracker
- [ ] Resume capability
- [ ] Validator
- [ ] 25+ unit tests
- [ ] Documentation and examples

#### Usage Examples
```bash
# Query and retrieve interactively
dicom-qr pacs://server:11112 \
  --aet MY_AET \
  --move-dest MY_SCP \
  --patient-name "DOE*" \
  --interactive

# Automatic query and retrieve
dicom-qr pacs://server:11112 \
  --aet MY_AET \
  --move-dest MY_SCP \
  --study-date "20240101-20240131" \
  --modality CT \
  --output studies/ \
  --auto

# Resume interrupted retrieval
dicom-qr resume --state retrieval.state

# Query, review, then retrieve
dicom-qr pacs://server:11112 \
  --aet MY_AET \
  --patient-id "12345" \
  --review \
  --save-state query.state
```

**Lines of Code Estimate**: 450-550

---

### Milestone 5.2: DICOMweb Client Wrapper

**Tool**: `dicom-wado`  
**Status**: 📋 Planned  
**Priority**: High  
**Complexity**: Medium  
**Timeline**: 4 days  
**Tests**: 30+ (planned)  
**Dependencies**: DICOMWeb support

#### Features
- WADO-RS retrieve operations
- QIDO-RS query operations
- STOW-RS store operations
- UPS-RS workflow operations
- OAuth2 authentication
- Multipart handling
- Batch operations
- Response caching

#### Deliverables
- [ ] WADO-RS client
- [ ] QIDO-RS client
- [ ] STOW-RS client
- [ ] UPS-RS client
- [ ] OAuth2 handler
- [ ] Multipart processor
- [ ] Batch controller
- [ ] Cache manager
- [ ] 30+ unit tests
- [ ] Documentation and examples

#### Usage Examples
```bash
# WADO-RS retrieve study
dicom-wado retrieve \
  --url https://dicomweb.server.com \
  --study-uid 1.2.840.113619.2.xxx \
  --output study/

# QIDO-RS query
dicom-wado query \
  --url https://dicomweb.server.com \
  --patient-name "DOE*" \
  --format json

# STOW-RS store
dicom-wado store \
  --url https://dicomweb.server.com \
  --input study/*.dcm

# UPS-RS workflow
dicom-wado ups \
  --url https://dicomweb.server.com \
  --create workflow.json
```

**Lines of Code Estimate**: 500-600

---

### Milestone 5.3: Modality Worklist Management

**Tool**: `dicom-mwl`  
**Status**: 📋 Planned  
**Priority**: Medium  
**Complexity**: High  
**Timeline**: 5 days  
**Tests**: 30+ (planned)  
**Dependencies**: DICOMNetwork MWL support

#### Features
- Query Modality Worklist (C-FIND)
- Create worklist entries
- Update worklist entries
- Delete worklist entries
- Worklist SCP server
- HL7 ORM integration
- Scheduled Procedure Step management
- Request validation

#### Deliverables
- [ ] MWL query client
- [ ] Worklist entry creator
- [ ] Worklist entry updater
- [ ] Worklist SCP server
- [ ] HL7 ORM parser
- [ ] SPS manager
- [ ] Validator
- [ ] 30+ unit tests
- [ ] Documentation and examples

#### Usage Examples
```bash
# Query worklist
dicom-mwl query pacs://server:11112 \
  --aet MODALITY \
  --date today \
  --station "CT1"

# Start MWL SCP server
dicom-mwl scp \
  --aet WORKLIST_SCP \
  --port 11112 \
  --worklist-dir /data/worklist/

# Create worklist entry from HL7 ORM
dicom-mwl create \
  --hl7 order.hl7 \
  --output worklist_entry.dcm

# Update worklist entry
dicom-mwl update worklist_entry.dcm \
  --status "IN PROGRESS" \
  --output updated.dcm
```

**Lines of Code Estimate**: 550-650

---

### Milestone 5.4: MPPS Operations

**Tool**: `dicom-mpps`  
**Status**: 📋 Planned  
**Priority**: Low  
**Complexity**: High  
**Timeline**: 5 days  
**Tests**: 25+ (planned)  
**Dependencies**: DICOMNetwork MPPS support

#### Features
- Create MPPS N-CREATE
- Update MPPS N-SET
- Query MPPS N-GET
- MPPS SCP server
- Procedure step tracking
- Status management
- Integration with worklist
- Automatic notifications

#### Deliverables
- [ ] MPPS creator (N-CREATE)
- [ ] MPPS updater (N-SET)
- [ ] MPPS query (N-GET)
- [ ] MPPS SCP server
- [ ] Status manager
- [ ] Notification handler
- [ ] 25+ unit tests
- [ ] Documentation and examples

#### Usage Examples
```bash
# Create MPPS (procedure started)
dicom-mpps create pacs://server:11112 \
  --aet MODALITY \
  --worklist worklist_entry.dcm \
  --status "IN PROGRESS"

# Update MPPS (procedure completed)
dicom-mpps update pacs://server:11112 \
  --aet MODALITY \
  --mpps-uid 1.2.840.113619.2.xxx \
  --status "COMPLETED" \
  --images study/*.dcm

# Start MPPS SCP server
dicom-mpps scp \
  --aet MPPS_SCP \
  --port 11112 \
  --notify-url http://ris.server.com/mpps
```

**Lines of Code Estimate**: 500-600

---

### Milestone 5.5: Network Testing and Simulation

**Tool**: `dicom-echo`  
**Status**: 📋 Planned  
**Priority**: High  
**Complexity**: Low  
**Timeline**: 2 days  
**Tests**: 15+ (planned)  
**Dependencies**: DICOMNetwork

#### Features
- C-ECHO verification
- Association testing
- Transfer syntax negotiation test
- Presentation context testing
- Network diagnostics
- Latency measurement
- Connection pooling test
- SCP simulation

#### Deliverables
- [ ] C-ECHO client
- [ ] Association tester
- [ ] Transfer syntax tester
- [ ] Presentation context tester
- [ ] Network diagnostics
- [ ] Performance profiler
- [ ] SCP simulator
- [ ] 15+ unit tests
- [ ] Documentation and examples

#### Usage Examples
```bash
# Test PACS connection
dicom-echo pacs://server:11112 --aet TEST_SCU

# Test with specific transfer syntax
dicom-echo pacs://server:11112 \
  --aet TEST_SCU \
  --transfer-syntax ExplicitVRLittleEndian

# Network diagnostics
dicom-echo pacs://server:11112 \
  --aet TEST_SCU \
  --diagnose \
  --verbose

# Measure latency
dicom-echo pacs://server:11112 \
  --aet TEST_SCU \
  --count 10 \
  --stats
```

**Lines of Code Estimate**: 300-400

---

## Phase 6: Advanced and Specialized Tools

**Status**: 📋 Planned  
**Target Version**: v1.3.0-v1.3.5  
**Priority**: Low  
**Timeline**: 3-4 weeks

### Milestone 6.1: Pixel Data Manipulation

**Tool**: `dicom-pixedit`  
**Status**: 📋 Planned  
**Priority**: Medium  
**Complexity**: High  
**Timeline**: 5 days  
**Tests**: 30+ (planned)  
**Dependencies**: None

#### Features
- Mask burned-in annotations
- Crop image regions
- Apply filters (smooth, sharpen, etc.)
- Adjust window/level
- Convert photometric interpretation
- Overlay text/graphics
- De-identification of pixel data
- Region-based processing

#### Deliverables
- [ ] Pixel data editor
- [ ] Masking tools
- [ ] Crop tools
- [ ] Filter engine
- [ ] Window/level adjuster
- [ ] Photometric converter
- [ ] Overlay renderer
- [ ] Region processor
- [ ] 30+ unit tests
- [ ] Documentation and examples

#### Usage Examples
```bash
# Mask burned-in text
dicom-pixedit file.dcm \
  --output masked.dcm \
  --mask-region 0,0,200,50

# Crop to region of interest
dicom-pixedit file.dcm \
  --output cropped.dcm \
  --crop 100,100,400,400

# Apply smoothing filter
dicom-pixedit file.dcm \
  --output smooth.dcm \
  --filter gaussian \
  --sigma 1.5

# Adjust window/level permanently
dicom-pixedit ct.dcm \
  --output windowed.dcm \
  --window-center 40 \
  --window-width 400 \
  --apply
```

**Lines of Code Estimate**: 550-650

---

### Milestone 6.2: Tag Manipulation

**Tool**: `dicom-tags`  
**Status**: 📋 Planned  
**Priority**: Medium  
**Complexity**: Medium  
**Timeline**: 3 days  
**Tests**: 25+ (planned)  
**Dependencies**: None

#### Features
- Add/modify/delete tags
- Bulk tag operations
- Tag templates
- CSV-based batch updates
- Tag value formatting
- Private tag handling
- Sequence manipulation
- Tag copying between files

#### Deliverables
- [ ] Tag editor
- [ ] Bulk operations engine
- [ ] Template processor
- [ ] CSV importer
- [ ] Value formatter
- [ ] Private tag handler
- [ ] Sequence editor
- [ ] Tag copier
- [ ] 25+ unit tests
- [ ] Documentation and examples

#### Usage Examples
```bash
# Add/modify tags
dicom-tags file.dcm \
  --output modified.dcm \
  --set PatientName="DOE^JOHN" \
  --set PatientID="12345"

# Delete tags
dicom-tags file.dcm \
  --output cleaned.dcm \
  --delete 0010,0010 \
  --delete-private

# Bulk update from CSV
dicom-tags study/*.dcm \
  --output updated/ \
  --csv updates.csv \
  --key StudyInstanceUID

# Copy tags between files
dicom-tags source.dcm \
  --copy-to target.dcm \
  --tags PatientName,PatientID,StudyDate
```

**Lines of Code Estimate**: 450-550

---

### Milestone 6.3: UID Operations

**Tool**: `dicom-uid`  
**Status**: 📋 Planned  
**Priority**: Low  
**Complexity**: Low  
**Timeline**: 2 days  
**Tests**: 15+ (planned)  
**Dependencies**: None

#### Features
- Generate new UIDs
- Regenerate UIDs in files
- Maintain UID relationships
- UID root management
- UID validation
- UID registry lookup
- Batch UID regeneration
- UID mapping export

#### Deliverables
- [ ] UID generator
- [ ] UID regenerator
- [ ] Relationship maintainer
- [ ] Root manager
- [ ] UID validator
- [ ] Registry lookup
- [ ] Batch processor
- [ ] Mapping exporter
- [ ] 15+ unit tests
- [ ] Documentation and examples

#### Usage Examples
```bash
# Generate new UIDs
dicom-uid generate --count 10

# Regenerate UIDs in file
dicom-uid regenerate file.dcm \
  --output new.dcm \
  --maintain-relationships

# Batch regeneration for study
dicom-uid regenerate study/*.dcm \
  --output new_study/ \
  --export-map uid_mapping.json

# Validate UIDs
dicom-uid validate file.dcm --check-registry
```

**Lines of Code Estimate**: 300-400

---

### Milestone 6.4: Compression Tools

**Tool**: `dicom-compress`  
**Status**: 📋 Planned  
**Priority**: Medium  
**Complexity**: High  
**Timeline**: 4 days  
**Tests**: 25+ (planned)  
**Dependencies**: DICOMKit compression support

#### Features
- Compress uncompressed images
- Decompress compressed images
- Transfer syntax conversion
- Multiple codec support (JPEG, JPEG-LS, JPEG 2000, RLE)
- Quality settings
- Lossless/lossy options
- Batch compression
- Size optimization

#### Deliverables
- [ ] Image compressor
- [ ] Image decompressor
- [ ] Codec selector
- [ ] Quality controller
- [ ] Batch processor
- [ ] Size optimizer
- [ ] 25+ unit tests
- [ ] Documentation and examples

#### Usage Examples
```bash
# Compress to JPEG Lossless
dicom-compress ct.dcm \
  --output ct_compressed.dcm \
  --codec jpeg-lossless

# Decompress to uncompressed
dicom-compress compressed.dcm \
  --output uncompressed.dcm \
  --decompress

# Batch compress with size target
dicom-compress study/*.dcm \
  --output compressed_study/ \
  --codec jpeg2000 \
  --quality 0.9 \
  --target-ratio 10:1
```

**Lines of Code Estimate**: 500-600

---

### Milestone 6.5: Study/Series Tools

**Tool**: `dicom-study`  
**Status**: 📋 Planned  
**Priority**: Low  
**Complexity**: Medium  
**Timeline**: 3 days  
**Tests**: 20+ (planned)  
**Dependencies**: None

#### Features
- Study/Series organization
- Metadata summary
- Study completeness check
- Series sorting
- Instance counting
- Missing slice detection
- Study comparison
- Study statistics

#### Deliverables
- [ ] Study organizer
- [ ] Metadata summarizer
- [ ] Completeness checker
- [ ] Series sorter
- [ ] Instance counter
- [ ] Slice detector
- [ ] Study comparator
- [ ] Statistics calculator
- [ ] 20+ unit tests
- [ ] Documentation and examples

#### Usage Examples
```bash
# Organize files by study/series
dicom-study organize files/ --output organized/

# Study summary
dicom-study summary study/ --format table

# Check study completeness
dicom-study check study/ \
  --expected-series 5 \
  --report missing.txt

# Study statistics
dicom-study stats study/ --detailed

# Compare studies
dicom-study compare study1/ study2/ --format json
```

**Lines of Code Estimate**: 400-500

---

### Milestone 6.6: Scripting Support

**Tool**: `dicom-script`  
**Status**: 📋 Planned  
**Priority**: Low  
**Complexity**: Medium  
**Timeline**: 4 days  
**Tests**: 20+ (planned)  
**Dependencies**: All other tools

#### Features
- Workflow scripting DSL
- Pipeline creation
- Conditional operations
- Error handling
- Logging and reporting
- Parallel execution
- Variable substitution
- Script templates

#### Deliverables
- [ ] Script parser
- [ ] Pipeline executor
- [ ] Condition evaluator
- [ ] Error handler
- [ ] Logger/reporter
- [ ] Parallel controller
- [ ] Variable engine
- [ ] Template library
- [ ] 20+ unit tests
- [ ] Documentation and examples

#### Usage Examples
```bash
# Run workflow script
dicom-script run workflow.dcmscript

# Example script:
# workflow.dcmscript
query pacs://server:11112 --patient "DOE*" | \
retrieve --output studies/ | \
validate --level 2 | \
anonymize --profile basic --output anon/ | \
convert --format png --output images/

# Pipeline with conditions
dicom-script run pipeline.dcmscript --var PATIENT_ID=12345
```

**Lines of Code Estimate**: 500-600

---

## Summary Tables

### Tools by Phase

| Phase | Tools | Priority | Status | Timeline |
|-------|-------|----------|--------|----------|
| Phase 1 | 7 | Critical | ✅ Complete | 3 weeks |
| Phase 2 | 4 | High | 🚧 25% Complete | 3-4 weeks |
| Phase 3 | 4 | Medium | ✅ Complete | 2-3 weeks |
| Phase 4 | 3 | Medium | 🚧 67% Complete | 2 weeks |
| Phase 5 | 5 | Medium | 📋 Planned | 3-4 weeks |
| Phase 6 | 6 | Low | 📋 Planned | 3-4 weeks |
| **Total** | **29** | - | - | **16-21 weeks** |

### Tools by Priority

| Priority | Count | Status |
|----------|-------|--------|
| Critical | 1 | 📋 Planned |
| High | 7 | ✅ 7/7 Complete |
| Medium | 14 | ✅ 6/14 Complete |
| Low | 7 | ✅ 1/7 Complete |
| **Total** | **29** | **48% Complete** |

### Test Coverage Target

| Phase | Tools | Est. Tests | Actual Tests |
|-------|-------|------------|--------------|
| Phase 1 | 7 | 160+ | 160+ ✅ |
| Phase 2 | 4 | 105+ | 20+ (19%) |
| Phase 3 | 4 | 75 | 75 (100%) ✅ |
| Phase 4 | 3 | 95+ | 63 (66%) |
| Phase 5 | 5 | 125+ | 0 |
| Phase 6 | 6 | 130+ | 0 |
| **Total** | **29** | **695+** | **318+ (46%)** |

### Lines of Code Estimate

| Phase | Est. LOC | Complexity |
|-------|----------|------------|
| Phase 1 | 4,338 | Medium-High |
| Phase 2 | 2,100-2,550 | High |
| Phase 3 | 1,801 | Completed |
| Phase 4 | 1,700-2,100 | High-Very High |
| Phase 5 | 2,300-2,800 | Medium-High |
| Phase 6 | 2,700-3,300 | Medium-High |
| **Total** | **14,688-17,138** | - |

---

## Development Guidelines

### Implementation Order
1. ✅ Complete Phase 1 (Done)
2. 🚧 Complete Phase 2 Priority 1 tools (In Progress)
3. Focus on high-priority tools first
4. Implement within phases based on dependencies
5. Parallel development possible for independent tools

### Testing Strategy
- Write tests before implementation (TDD)
- Minimum 15 test cases per tool
- Include unit, integration, and error handling tests
- Test with real DICOM files from multiple modalities
- Mock PACS servers for network tools
- Performance benchmarks for large files

### Documentation Requirements
- README.md per tool with examples
- Man pages for all tools
- Integration guides
- Video tutorials for complex workflows
- API documentation if libraries exposed

### Quality Standards
- Swift 6 strict concurrency compliance
- Zero compiler warnings
- SwiftLint passing
- Code coverage >80%
- Performance benchmarks met
- Cross-platform compatibility (macOS, Linux)

---

## Integration with Main Milestones

### Relation to MILESTONES.md

These CLI tool milestones complement the main DICOMKit milestones:

- **Milestone 10.14** (Example Applications): Phase 1 complete
- **Milestone 10.15** (Production Release): Phase 2 completion target
- **Milestone 11.x** (Post-v1.0): Phases 3-6 implementation

### Versioning Strategy

- **Phase 1**: v1.0.14 (Released)
- **Phase 2**: v1.0.15-v1.1.2
- **Phase 3**: v1.1.3-v1.1.6
- **Phase 4**: v1.2.0-v1.2.2
- **Phase 5**: v1.2.3-v1.2.7
- **Phase 6**: v1.3.0-v1.3.5

---

## Future Considerations

### Potential Additional Tools
- **dicom-report**: Generate reports from DICOM SR
- **dicom-measure**: Measurement tools (distance, area, volume)
- **dicom-3d**: 3D reconstruction and MPR
- **dicom-viewer**: Terminal-based image viewer
- **dicom-server**: Full-featured PACS server
- **dicom-gateway**: Protocol gateway (HL7, FHIR)
- **dicom-ai**: AI/ML integration tools
- **dicom-cloud**: Cloud storage integration

### GUI Wrappers
Consider creating GUI applications that wrap CLI tools:
- macOS GUI using SwiftUI
- Cross-platform GUI using Electron
- Web interface for remote CLI access

### Package Managers
- Homebrew formula (already planned)
- APT repository for Debian/Ubuntu
- RPM repository for Red Hat/CentOS
- Docker Hub images
- Snap package

---

## Contributing

We welcome contributions to CLI tool development! Priority areas:
1. Phase 2 tools (in progress)
2. Test coverage improvements
3. Documentation enhancements
4. Bug fixes and optimizations
5. Cross-platform compatibility

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## References

### DICOM Standards
- PS3.3: Information Object Definitions
- PS3.4: Service Class Specifications
- PS3.5: Data Structures and Encoding
- PS3.7: Message Exchange (DIMSE)
- PS3.10: Media Storage and File Format
- PS3.18: Web Services (DICOMweb)
- PS3.19: Application Hosting

### Similar Toolkits
- dcm4che utilities: https://web.dcm4che.org/dcm4che-utilities
- DCMTK tools: https://support.dcm4che.org/docs/dcmtk/
- PyDICOM examples: https://pydicom.github.io/

---

*Last Updated: February 2026*  
*Document Version: 1.0*  
*Status: Living Document - Updated as milestones are completed*
