# DICOMKit CLI Tools - Phase 2 Enhancement Plan

**Status**: ✅ Complete  
**Target Version**: v1.0.15  
**Created**: February 2026  
**Completed**: February 2026  
**Dependencies**: DICOMKit v1.0.14 (Phase 1 CLI Tools), DICOMNetwork

---

## Overview

This document outlines Phase 2 of the DICOMKit CLI Tools suite, adding advanced functionality to complement the 7 core tools completed in Phase 1. Phase 2 focuses on workflow automation, file manipulation, and advanced PACS integration.

### Phase 1 Recap (✅ Complete)
- ✅ dicom-info - Metadata display
- ✅ dicom-convert - Transfer syntax conversion & image export
- ✅ dicom-validate - Conformance validation
- ✅ dicom-anon - Anonymization
- ✅ dicom-dump - Hexadecimal inspection
- ✅ dicom-query - PACS C-FIND queries
- ✅ dicom-send - PACS C-STORE operations

**Phase 1 Stats**: 7 tools, 4,338 LOC, 160+ tests

---

## Phase 2 Goals

### Primary Objectives
1. **Complete PACS Workflow**: Add C-MOVE/C-GET retrieve capabilities
2. **File Manipulation**: Enable multi-frame splitting and file merging
3. **Comparison Tools**: Provide DICOM file diff functionality
4. **Enhanced Automation**: Support complex medical imaging workflows

### Secondary Objectives
- Improve batch processing with parallelization
- Add configuration file support
- Enhance progress reporting
- Maintain backward compatibility

---

## New Tools (Phase 2)

### Priority 1: Core Workflow Tools

#### 1. dicom-retrieve

**Purpose**: Retrieve DICOM studies/series from PACS servers using C-MOVE or C-GET

**Features**:
- **C-MOVE Support**:
  - Query and retrieve at Patient/Study/Series/Instance levels
  - Support for Move Destination AE Title
  - Progress tracking with file count
  - Automatic retry on network failures
  
- **C-GET Support** (Alternative to C-MOVE):
  - Direct retrieval without additional C-STORE SCP
  - Simpler deployment for testing
  - Same level support as C-MOVE

- **Query Integration**:
  - Use C-FIND to locate studies before retrieval
  - Support for Study/Series Instance UIDs
  - Bulk retrieval with UID lists from file
  
- **Output Options**:
  - Organize by Patient/Study/Series hierarchy
  - Flat directory structure
  - Custom naming patterns
  - Preserve or anonymize on retrieve

**Usage Examples**:
```bash
# Retrieve study by Study Instance UID
dicom-retrieve pacs://server:11112 \
  --aet MY_SCU \
  --move-dest MY_SCP \
  --study-uid 1.2.840.113619.2.xxx \
  --output study_dir/

# Retrieve all studies for patient
dicom-retrieve pacs://server:11112 \
  --aet MY_SCU \
  --move-dest MY_SCP \
  --patient-id "12345" \
  --output patient_studies/

# Retrieve using C-GET (no move destination needed)
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
  --output studies/
```

**Implementation Notes**:
- Requires DICOMNetwork C-MOVE/C-GET support
- Must implement C-STORE SCP to receive files from C-MOVE
- C-GET is simpler (no SCP needed) but less commonly supported
- Progress reporting via callback mechanism
- Network timeout and retry logic

**Test Cases** (30+ planned):
- C-MOVE at all query levels
- C-GET operations
- Network failure and retry
- UID list parsing
- Output directory organization
- Progress reporting
- Connection verification

**Lines of Code Estimate**: 650-750

---

#### 2. dicom-split

**Purpose**: Extract individual frames from multi-frame DICOM images

**Features**:
- **Frame Extraction**:
  - Extract all frames or specific frame ranges
  - Support for Enhanced CT/MR/XA multi-frame images
  - Support for legacy multi-frame modalities (US, etc.)
  - Preserve per-frame functional groups

- **Output Options**:
  - Create individual DICOM files per frame
  - Export frames as images (PNG, JPEG, TIFF)
  - Configurable naming patterns
  - Metadata inheritance from source

- **Frame Metadata**:
  - Update Frame Number tag
  - Preserve Frame-specific tags
  - Update Image Position/Orientation if present
  - Recalculate SOP Instance UID

- **Batch Processing**:
  - Process multiple multi-frame files
  - Recursive directory support
  - Progress reporting

**Usage Examples**:
```bash
# Extract all frames to DICOM files
dicom-split multiframe.dcm --output frames/

# Extract specific frames
dicom-split multiframe.dcm --frames 1,5,10-15 --output selected/

# Extract as PNG images
dicom-split multiframe.dcm --format png --output images/

# Batch processing
dicom-split multiframe_dir/ --output split_dir/ --recursive

# Custom naming pattern
dicom-split multiframe.dcm \
  --output frames/ \
  --pattern "frame_{number:04d}_{modality}.dcm"
```

**Implementation Notes**:
- Check Number of Frames tag (0028,0008)
- Handle Shared and Per-Frame Functional Groups
- Support both legacy and Enhanced multi-frame formats
- Validate frame indices
- Generate unique SOP Instance UIDs

**Test Cases** (25+ planned):
- Multi-frame CT/MR/US/XA extraction
- Frame range selection
- DICOM and image output formats
- Metadata preservation
- UID generation
- Batch processing
- Enhanced multi-frame support

**Lines of Code Estimate**: 450-550

---

#### 3. dicom-merge

**Purpose**: Combine multiple DICOM files into a single multi-frame image or organized series/study

**Features**:
- **Multi-Frame Creation**:
  - Combine single-frame images into multi-frame
  - Support Enhanced MR/CT/XA formats
  - Create Shared and Per-Frame Functional Groups
  - Validate frame compatibility (dimensions, VR, etc.)

- **Series Organization**:
  - Combine files into organized series
  - Update Series/Instance relationships
  - Renumber Instance Numbers
  - Generate new Series Instance UID

- **Study Organization**:
  - Merge series into common study
  - Update Study-level metadata
  - Preserve Patient-level information
  - Generate new Study Instance UID (optional)

- **Validation**:
  - Check compatible Transfer Syntaxes
  - Verify matching image dimensions
  - Validate consistent Patient/Study data
  - Warn on metadata mismatches

**Usage Examples**:
```bash
# Create multi-frame from single frames
dicom-merge frame_*.dcm \
  --output multiframe.dcm \
  --multi-frame

# Organize files into series
dicom-merge scattered_files/*.dcm \
  --output organized/ \
  --organize series \
  --series-uid 1.2.840.113619.2.xxx

# Merge series into study
dicom-merge series1/ series2/ series3/ \
  --output merged_study/ \
  --organize study \
  --study-uid 1.2.840.113619.2.yyy

# Validate before merge
dicom-merge frame_*.dcm \
  --validate \
  --dry-run
```

**Implementation Notes**:
- Requires frame compatibility checks
- Must handle Enhanced vs. Legacy formats
- SOP Class UID changes for multi-frame
- Functional Group Sequence construction
- UID generation and consistency

**Test Cases** (25+ planned):
- Single to multi-frame conversion
- Series organization
- Study merging
- Compatibility validation
- UID generation
- Metadata consistency
- Enhanced format creation

**Lines of Code Estimate**: 500-600

---

#### 4. dicom-diff

**Purpose**: Compare two DICOM files and report differences

**Features**:
- **Comparison Modes**:
  - Tag-by-tag comparison
  - Pixel data comparison (with tolerance)
  - Structural comparison (sequences, items)
  - Quick mode (metadata only, skip pixel data)

- **Output Formats**:
  - Human-readable text
  - JSON for programmatic parsing
  - Summary mode (counts only)
  - Detailed mode (show values)

- **Filtering**:
  - Ignore specific tags (e.g., timestamps)
  - Ignore private tags
  - Focus on specific tag groups
  - Pixel data tolerance threshold

- **Batch Comparison**:
  - Compare entire directories
  - Match files by SOP Instance UID
  - Generate comparison reports

**Usage Examples**:
```bash
# Basic comparison
dicom-diff file1.dcm file2.dcm

# Ignore timestamps and UIDs
dicom-diff file1.dcm file2.dcm \
  --ignore 0008,0012 \
  --ignore 0008,0013 \
  --ignore SOPInstanceUID

# Compare pixel data with tolerance
dicom-diff original.dcm processed.dcm \
  --compare-pixels \
  --tolerance 5

# JSON output for automation
dicom-diff file1.dcm file2.dcm --format json

# Batch directory comparison
dicom-diff dir1/ dir2/ \
  --recursive \
  --match-by-uid \
  --output report.txt

# Quick metadata-only comparison
dicom-diff file1.dcm file2.dcm --quick
```

**Implementation Notes**:
- Tag-by-tag iteration and comparison
- Pixel data numerical comparison with tolerance
- Handle missing tags gracefully
- Support for nested sequences
- Efficient large file handling

**Test Cases** (20+ planned):
- Identical files (baseline)
- Metadata differences
- Pixel data differences
- Sequence comparison
- Filtering options
- Batch comparison
- Various output formats

**Lines of Code Estimate**: 400-500

---

### Priority 2: Advanced Network Tools (Future)

#### 5. dicom-worklist

**Purpose**: Query Modality Worklist (MWL) servers for scheduled procedures

**Status**: Deferred to Phase 3 (requires MWL protocol implementation in DICOMNetwork)

**Planned Features**:
- C-FIND for MWL
- Filter by scheduled date, modality, AE title
- Patient and procedure information
- Output scheduled work items

---

#### 6. dicom-print

**Purpose**: Send images to DICOM Print servers

**Status**: Deferred to Phase 3 (requires Print protocol implementation)

**Planned Features**:
- Basic Grayscale Print
- Film size and layout options
- Multiple images per film
- Print queue management

---

## Implementation Roadmap

### Week 1-2: dicom-retrieve
- [ ] Implement C-MOVE protocol support in DICOMNetwork (if not present)
- [ ] Implement C-GET protocol support
- [ ] Create C-STORE SCP for receiving files
- [ ] Implement CLI argument parsing
- [ ] Add progress reporting
- [ ] Write 30+ unit tests
- [ ] Create README documentation

### Week 3: dicom-split
- [ ] Implement multi-frame detection
- [ ] Create frame extraction logic
- [ ] Handle Enhanced multi-frame formats
- [ ] Implement output naming patterns
- [ ] Add image export options
- [ ] Write 25+ unit tests
- [ ] Document usage

### Week 4: dicom-merge
- [ ] Implement frame compatibility checks
- [ ] Create multi-frame assembly logic
- [ ] Handle Series/Study organization
- [ ] Implement UID generation
- [ ] Add validation and dry-run mode
- [ ] Write 25+ unit tests
- [ ] Document usage

### Week 5: dicom-diff
- [ ] Implement tag comparison logic
- [ ] Add pixel data comparison
- [ ] Create output formatters
- [ ] Handle batch directory comparison
- [ ] Write 20+ unit tests
- [ ] Document usage

### Week 6: Integration & Polish
- [ ] Integration testing across all tools
- [ ] Performance optimization
- [ ] Documentation updates (README, MILESTONES)
- [ ] Build verification on all platforms
- [ ] Update Package.swift dependencies

---

## Testing Strategy

### Unit Tests (100+ total)
- Each tool: 20-30 focused unit tests
- Mock PACS responses for network tools
- Test edge cases and error conditions
- Validate output formats

### Integration Tests (Deferred)
- Live PACS testing (requires infrastructure)
- End-to-end workflow validation
- Performance benchmarking
- Network failure scenarios

### Manual Testing
- Build and run each tool
- Test with real DICOM files
- Verify help text and error messages
- Cross-platform validation (macOS, Linux)

---

## Dependencies

### Existing DICOMKit Modules
- **DICOMCore**: File parsing, data structures
- **DICOMKit**: High-level operations
- **DICOMDictionary**: Tag lookups
- **DICOMNetwork**: C-FIND, C-STORE (existing), C-MOVE, C-GET (new)

### New Requirements
- **C-MOVE Protocol**: Implement in DICOMNetwork
- **C-GET Protocol**: Implement in DICOMNetwork
- **C-STORE SCP**: Receive files (Storage Service Provider)

### External Dependencies
- **ArgumentParser**: CLI parsing (already used)

---

## Build Configuration

### Package.swift Updates

Add new executable targets:

```swift
.executable(
    name: "dicom-retrieve",
    targets: ["dicom-retrieve"]
),
.executable(
    name: "dicom-split",
    targets: ["dicom-split"]
),
.executable(
    name: "dicom-merge",
    targets: ["dicom-merge"]
),
.executable(
    name: "dicom-diff",
    targets: ["dicom-diff"]
)
```

Add target definitions:

```swift
.executableTarget(
    name: "dicom-retrieve",
    dependencies: [
        "DICOMCore",
        "DICOMNetwork",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
    ],
    path: "Sources/dicom-retrieve"
),
// ... similar for other tools
```

---

## Documentation Updates

### README.md
- Add Phase 2 tools to CLI Tools section
- Update feature list
- Add usage examples for new tools

### MILESTONES.md
- Update Milestone 10.14 status
- Add Phase 2 deliverables
- Update completion statistics

### CLI_TOOLS_COMPLETION_SUMMARY.md
- Update with Phase 2 progress
- Revise future enhancements list
- Update tool count and statistics

---

## Quality Metrics

### Code Quality
- Swift 6 strict concurrency
- Zero compiler warnings
- Comprehensive error handling
- Production-ready code

### Test Coverage
- 100+ new unit tests
- Core functionality coverage
- Edge case validation
- Error condition handling

### Documentation
- Comprehensive README per tool
- Usage examples
- Error message documentation
- Troubleshooting guides

---

## Success Criteria

### Phase 2 Complete When:
- ✅ All 4 priority 1 tools implemented
- ✅ 100+ unit tests passing
- ✅ All tools build successfully
- ✅ Documentation complete
- ✅ Integration with existing Phase 1 tools
- ✅ Cross-platform verified (macOS, Linux)

### Statistics (Projected)
- **Total CLI Tools**: 11 (7 Phase 1 + 4 Phase 2)
- **Total Code**: ~6,500 lines
- **Total Tests**: 260+ tests
- **Implementation Time**: 6 weeks

---

## Future Phases

### Phase 3: Advanced Features
- dicom-worklist (MWL queries)
- dicom-print (DICOM Print)
- TLS/SSL encryption support
- QIDO-RS/STOW-RS (DICOMweb HTTP)

### Phase 4: Distribution
- Homebrew formula
- Binary releases (Intel, Apple Silicon, Linux)
- Man pages
- Docker containers

---

## References

### DICOM Standards
- **PS3.4**: Service Classes (C-MOVE, C-GET)
- **PS3.3**: IOD Specifications (Multi-frame formats)
- **PS3.7**: Message Exchange (DIMSE protocols)

### Internal Documentation
- [CLI_TOOLS_PLAN.md](CLI_TOOLS_PLAN.md) - Phase 1 specification
- [CLI_TOOLS_COMPLETION_SUMMARY.md](CLI_TOOLS_COMPLETION_SUMMARY.md) - Phase 1 results
- [MILESTONES.md](MILESTONES.md) - Project milestones

---

## Conclusion

Phase 2 of the DICOMKit CLI Tools suite expands functionality with critical workflow tools: retrieve, split, merge, and diff. These additions complete the essential DICOM file manipulation and PACS integration capabilities, making DICOMKit a comprehensive solution for medical imaging automation.

**Status**: Ready for implementation  
**Priority**: dicom-retrieve → dicom-split → dicom-merge → dicom-diff  
**Target Completion**: 6 weeks from start date

---

*This document will be updated as implementation progresses.*
