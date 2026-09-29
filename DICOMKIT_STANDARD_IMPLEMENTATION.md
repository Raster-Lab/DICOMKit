# DICOMKit — DICOM Standard Implementation Report

Generated 2026-09-29, last updated 2026-09-29. Covers all 156 Swift files in `Sources/DICOMKit/`
(about 64,000 lines): the file reader and writer, DICOMDIR, the Structured Reporting builders,
parsers and extractors, presentation states, hanging protocols, segmentation, parametric maps,
real world value maps, radiotherapy objects, secondary capture, multi-frame conversion, video,
waveforms, encapsulated documents, de-identification, compression and validation.

**Status: complete for this pass, with owner decisions open.** Every file is bucketed and carries
a `NEMA-verified` marker (`Scripts/check_nema_markers.py Sources/DICOMKit` exits 0: 156 of 156).
Every constant table the module carries is diffed by script against the frozen 2026a DocBook
(`Scripts/diff_kit.py`: 41 checks, 0 failing, 14 pending owner approval). The nine deferred rows
for this module from the earlier reports (D5, D12, D14–D19, D24) and the nineteen findings of the
Presentation State audit (NC-1–NC-19) are closed, carried to their owning module, or listed as
pending decisions below. Every behaviour fix has a test; `swift build` and the full `swift test`
pass. The work is committed on `feature/dicom-tag-modality-audit`, locally, for review.

Method: [DICOMCORE_STANDARD_IMPLEMENTATION.md → Verification method](DICOMCORE_STANDARD_IMPLEMENTATION.md#verification-method-reuse-for-every-module),
used unchanged. Package target: **DICOM 2026a** (`dicomStandardEdition = "2026a"`,
[DICOMKit.swift](Sources/DICOMKit/DICOMKit.swift)).

**Scope note.** DICOMKit is the largest module and the one closest to the wire: it writes whole
IODs (SR, GSPS/PCSPS, SEG, SC, video, waveform, encapsulated document, DICOMDIR). Its tables are
SOP Class and Transfer Syntax UIDs, coded concepts (DCM, SCT, UCUM …), the VRs it writes and reads
elements with, enumerated and defined terms of a dozen modules, the PS3.15 E.1-1 de-identification
actions, and the video transfer-syntax constraints. All of those are extracted from the Swift by
regex and diffed against PS3.3, PS3.5, PS3.6, PS3.10, PS3.15 and PS3.16 2026a by
[Scripts/diff_kit.py](Scripts/diff_kit.py). Behaviour (what an IOD builder writes, what a parser
reads, how pixels are packed) was read clause by clause against the text named in each finding.
The internals of the codecs (JPEG, JPEG 2000, HTJ2K, JPEG-LS, JPEG XL, RLE) and of the video
bitstreams and containers (ITU-T H.262/H.264/H.265, ISO/IEC 13818-1, 14496-12) are not DICOM and
are not scored; only the DICOM boundary is (transfer syntax UIDs, encapsulation, Photometric
Interpretation, profile/level constraints).

Template conformance of the SR builders (whether a Mammography CAD document has every TID 4000 row
in the right place) was verified only for the rows that were found wrong; a full row-by-row
template diff of each builder is a follow-up (P-CAD, P-TID1500).

---

## Summary

| Bucket | Files | Meaning | Status |
|---|---|---|---|
| A — cites 2026a | 1 (`DICOMKit.swift`) | The package target | ✅ |
| B1 — cites a Supplement | 4 (Sup 59, Sup 65, Sup 157 ×2) | Provenance kept; content diffed against 2026a | ✅ |
| B2 — no citation, data or behaviour differed from 2026a, or a decision is pending | 82 | See the bucket table; every finding verified against the frozen text | ✅ Fixed where no public API changes; 14 pending items listed under Priority action list |
| C1 — plumbing | 35 | Confirmed to carry no standard data | ✅ |
| C2 — standard-derived, edition-stable | 34 | Diffed all the same; all constants match | ✅ |

### Baseline diff, before any change (2026-09-29, `Scripts/diff_kit.py` against the HEAD sources)

40 scripted checks against PS3.3, PS3.5, PS3.6, PS3.15 and PS3.16 2026a; 22 failed (the check
count grew to 41 as checks were added for the de-identification table, the video constraints,
the CS literals, the waveform terms and the KOS titles):

| Check | Standard | Result before |
|---|---|---|
| Every `1.2.840.10008` literal registered | PS3.6 Table A-1 | **FAIL:** `…5.1.4.1.1.200.9` does not exist; (`…1.2.4.20` is a `hasPrefix` prefix, not a UID) |
| UID names next to literals | PS3.6 Table A-1 | **FAIL:** 90 / 92; `91.1` labelled Content Assessment Results (it is Microscopy Bulk Simple Annotations; Content Assessment is `90.1`), `200.8` labelled XA Defined (it is XA Performed; Defined is `200.7`) |
| Coded concept literals (value, scheme, meaning) | PS3.16 Table D-1, CID tables | **FAIL:** 50 / 108; 58 wrong — wrong code for the meaning (T1/T2/T2*, ve/Vp, CBF/CBV/MTT, KOS titles 113020/113030/113040, Chest CAD title 111037 and root 113701, 126010 as PET report, 121074/121071) or wrong meaning for the code (111005, 111030, 111034, 111047, 113878, 111001, 121206, 130488, 121233, SUV names) |
| SRT-style SNOMED codes | PS3.16 Table 8-1, O-1 | **FAIL:** 15 SRT literals; 11 of them map (Table O-1) to concepts other than their meaning (F-01796 is breast density, not Mass; M-03000 is Mass, not Lesion; G-D785 is Depth, not Diameter; G-A220 is Width, not Area; R-00339 is "No" …) and 4 ids are not in O-1 |
| VR of every element written with `vr:` | PS3.6 Table 6-1 | **FAIL:** 455 / 460; Document Title LO (ST), Hanging Protocol Name LO (SH), Description ST (LO), Abstract Prior Value SH (SS), Unformatted Text Value UT (ST) |
| Typed reads match the VR | PS3.6 Table 6-1 | **FAIL:** 115 / 119; Instance Number (IS) as uint16, Shutter Presentation Value / Overlay Group (US) as IS, Frame Acquisition Number (US) as uint32 |
| Names next to `Tag(group:element:)` literals | PS3.6 Table 6-1 | **FAIL:** 91 / 99 (abbreviated comments) |
| Section, table, TID and CID citations | PS3.3/3.5/3.6/3.10/3.15/3.16 2026a | **FAIL:** 136 / 144; PS3.5 8.7.4 and Table C.17.2.5-1 do not exist; "PS3.3 8 - Code Sequence Macro" |
| SR IOD value-type sets (DICOMCore) | PS3.3 Tables A.35.x-2 | **FAIL:** 17 / 20 (2 were a parsing artifact; Colon CAD SR lists TCOORD, not WAVEFORM → D26) |
| Conversion Type | PS3.3 Table C.8-24 | **FAIL:** `""` written for `.unknown`; DRW missing |
| Color Space terms | PS3.3 C.11.15.1.2 | **FAIL:** DISPLAYP3 not recognised (`P3` was) |
| Segmentation Type | PS3.3 C.8.20.2 | LABELMAP missing |
| Contour Geometric Type | PS3.3 Table C.8-42 | **FAIL:** CLOSED_NONPLANAR is not a term; CLOSEDPLANAR_XOR missing |
| RT ROI Interpreted Type | PS3.3 Table C.8-44 | **FAIL:** IRRADIATED_VOLUME, FIXATION_DEVICE are not terms (IRRAD_VOLUME, FIXATION); 9 terms missing |
| Image Box Layout Type, Reformatting Operation Type, 3D Rendering Type | PS3.3 Table C.23.3-1 | **FAIL:** TILED_ALL, CPR, MIP, MinIP, AvgIP, VOLUME_RENDERING, SURFACE_RENDERING are not terms |
| Sort-by Category, Sorting Direction, Filter-by Operator, Image Set Selector Category, Hanging Protocol Level | PS3.3 Tables C.23.1-1, C.23.3-1 | **FAIL:** 0 / 5, 0 / 2, 2 / 9, 0 / 3, 1 / 3 — the enumerations were largely invented (ASCENDING for INCREASING, GROUP for USER_GROUP, EQUAL, CONTAINS, PRESENT …) |
| Photometric Interpretation literals | PS3.3 C.7.6.3.1.2 | 40 / 44 (4 were false positives: an ICC signature and prefix checks) |
| Display flags, Pixel Presentation and other CS literals | PS3.3 module tables | (check added later) **FAIL:** Show Grayscale Inverted and the four Show … Flags written as `Y`/`N`; Table C.23.3-1 enumerates YES/NO |
| De-identification actions | PS3.15 Table E.1-1 | (added later) **FAIL:** 59 / 62; Device UID removed (U), Placer/Filler Order Number removed (Z) |
| Video profile, level, BD flag | PS3.6 Table A-1 names | (added later) 9 / 9 |
| Waveform Sample Interpretation | PS3.3 Table C.10-10 | (added later) **FAIL:** SB treated as unsigned and US as signed; SL, UL, SV, UV missing |
| Presentation Size Mode, Graphic Type (PR), Scroll Direction, Relative Time Units, Completion/Verification/Preliminary Flag, Segment Algorithm Type, Waveform Originality, CID 42 qualifiers, CID 7010 titles | PS3.3 / PS3.16 | match |

Tests at the start (HEAD, `swift test --filter DICOMKitTests` in a clean worktree): 1,159 XCTest
cases and 674 swift-testing tests pass, 0 failures.

Tests at the end (2026-09-29, full `swift test`): DICOMKitTests 1,160 XCTest cases (11 skipped)
and 677 swift-testing tests pass; every other target passes (Verification notes).

---

## Progress log

| Date | Item | What was compared | What changed | Tests |
|---|---|---|---|---|
| 2026-09-29 | Baseline | All 156 files read in full and bucketed (nine parallel read-only inventories, one per directory group). PS3.3, 3.4, 3.5, 3.6, 3.10, 3.11, 3.15, 3.16 2026a fetched, subtitles checked. `Scripts/diff_kit.py` written: 40 checks, 22 failed (table above). | Script only | 674 swift-testing, 1,159 XCTest pass |
| 2026-09-29 | D14, D15, D16, D17, D18, D19 | PS3.3 Table F.3-3, F.4-1, F.6.1 (record types); Tables A.35.1-2, A.35.4-2, A.35.5-2, A.35.6-2 (value types); C.18.6.1.2 (SCOORD graphic types); PS3.16 Table D-1, TID 4017, TID 4019 (111005 is "Assessment Category", 122405 is the manufacturer row); PS3.5 Table 6.2-1 (OV) | `DICOMDIRReader` skips unknown and PRIVATE records; `SRDocumentType.allowsValueType` deprecated onto DICOMCore `allows(_:)`; Mammography and Chest CAD builders no longer emit DATETIME and name the manufacturer `(122405, DCM)`; `addPolygon`/`polygon` write a closed POLYLINE; `SpatialCoordinates.isClosed`; OV comment | 4 new swift-testing tests, 1 corrected (Comprehensive SR with SCOORD3D now builds a Comprehensive 3D SR) |
| 2026-09-29 | Coded concepts, VRs, typed reads, UIDs, citations | PS3.16 Table D-1, CID 6015/6017/6104/7010/7021/7470-7472, Table O-1; PS3.6 Tables 6-1 and A-1; the 2026a tables of contents | `RealWorldValueLUT`, `ParametricMap` quantity codes; KOS titles; Chest CAD title/root `(112000, DCM)`; TID 4006/4104 concept names (`111059`, `111047 Probability of cancer`, `111012 Certainty of Finding` in percent, `111010 Center`, `111030 Image Region`, `111034`, `111017`); CID 6015/6017/6104 SCT finding codes; Enhanced SR measurement concepts (CID 7470-7472); `AIInferenceResult` SCT codes; 5 VRs; 4 typed reads; `nonImageSOPClasses` UIDs; 3 citations; `CADFindingsExtractor` reads the new and the old codes | 24 test pins updated; `CADSRBuilderValueTypeTests` |
| 2026-09-29 | Enumerations | PS3.3 Tables C.23.1-1, C.23.3-1, C.8-44, C.10-10, C.11.15.1.2 | Hanging Protocol Level `USER_GROUP`/`SINGLE_USER`, Sorting Direction `INCREASING`/`DECREASING`, `LESS_OR_EQUAL`/`GREATER_OR_EQUAL`, 3D Rendering `VOLUME`/`SURFACE`, display flags `YES`/`NO` (parser still reads `Y`/`N`); `IRRAD_VOLUME`, `FIXATION`; `WaveformSampleInterpretation.isSigned` follows Table C.10-10; `DISPLAYP3` read | 9 test pins updated |
| 2026-09-29 | D5, D12 | PS3.5 Table 6.2-1; PS3.3 C.7.6.3.1.2 ("Images in XYB transcoded … will use RGB") | `ComparisonReport` treats OB/OD/OF/OL/OV/OW/UN as binary; `CompressionManager` relabels XYB to RGB after JPEG XL decode | `CompressionManagerXYBTests` |
| 2026-09-29 | Presentation State NC-1, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 19; MF-3, MF-10 | PS3.3 A.33.1–A.33.4, C.7.6.11, C.10.4–C.10.7, C.10.7.1.1, C.11.1, C.11.6, C.11.8, C.11.15.1.1, Table 10-12; PS3.4 N.2, N.2.4.2 | GSPS builder writes the Modality LUT, table-valued VOI and Presentation LUTs, the Display Shutter module, a conditional Graphic Filled, the CIELab layer colour (0070,0401), a Type 2 Content Creator's Name; parser reads shutters row/column, CIELab first, LUT data as binary, skips MATRIX objects; applicator masks outside every shutter before rotating then flipping, normalises the no-VOI range; PCSPS palette without a baked window; ICC profile class `scnr` | `GrayscalePresentationStateBuilderTests` (2), one DICOMPrintKit fixture updated (it had been writing the shutter attributes as text) |
| 2026-09-29 | File meta, DICOMDIR, validator, SR series, SCOORD3D, segmentation bits, de-identification, MIME | PS3.10 Table 7.1-1; PS3.5 9.1, Table 6.2-1 (DA, TM), 8.1.1 and D.1; PS3.3 Table C.18.9-1, C.17.6.1, A.85, C.12.1.1.2; PS3.15 Table E.1-1 | `DICOMFile.write()` computes (0002,0000); one Implementation Class UID constant (the DICOMDIR writer had used the Deflated TS UID); VR lists gain OV/SV/UV; validator requires the Type 1 file meta elements, accepts HH/HHMM, drops the 1900 bound, names ISO_IR 192, detects every SR class; SCOORD3D uses (3006,0024); KOS Modality `KO`; 1-bit segmentation frames packed least-significant-bit first; Device UID → U, order numbers → Z; STL MIME `model/stl` | 8 test pins updated |
| 2026-09-29 | Markers, report | `check_nema_markers.py`: 156 / 156; `diff_kit.py`: 41 ok, 0 fail, 14 pending | CHANGELOG `[Unreleased]`; DICOMCore status table | Full `swift test` below |

---

## Priority action list

Items marked **PEND** change public API or need a design decision and wait for the owner; the
diff script reports them as `pending`, not `FAIL`. Everything else is done.

| # | What | Standard | Impact | Status |
|---|---|---|---|---|
| P1 | D14: a DICOMDIR with an unknown or PRIVATE record type could not be opened | PS3.3 Table F.3-3, F.6.1 | High | ✅ |
| P2 | D16, D17, D18: SR value-type rules, DATETIME in CAD SRs, 2D POLYGON | PS3.3 A.35.x-2, C.18.6.1.2 | Medium | ✅ |
| P3 | Wrong coded concepts throughout the SR, RWV, parametric map and AI code (58 pairs) | PS3.16 Table D-1, CID tables | **High:** every such document carried a code that means something else | ✅ (6 pairs pending, below) |
| P4 | 1-bit Segmentation frames packed MSB first | PS3.5 8.1.1, D.1 | **High:** every conformant reader mirrored each byte of a DICOMKit SEG; DICOMKit read its own | ✅ both directions; old DICOMKit objects are now read mirrored (see Verification notes) |
| P5 | Presentation State audit NC-1, NC-5–NC-15, NC-19 | PS3.3 A.33, C.7.6.11, C.10.x, C.11.x; PS3.4 N.2 | Critical/High | ✅ (NC-2, NC-3, NC-4 are DICOMStudio/DICOMPrintKit: D27, D28; NC-16, NC-18 need model changes: P-PS) |
| P6 | SCOORD3D frame of reference written and read as (0020,0052) | PS3.3 Table C.18.9-1 | **High:** Type 1 attribute missing, wrong one present | ✅ |
| P7 | Hanging Protocol terms written with invented values | PS3.3 Tables C.23.1-1, C.23.3-1 | High | ✅ for the one-to-one terms; the rest is P-HP |
| P8 | Wrong VRs and typed reads (9 sites) | PS3.6 Table 6-1 | Medium | ✅ (Abstract Prior Value: P-HP) |
| P9 | Waveform SB/US signedness inverted | PS3.3 Table C.10-10 | High for 8-bit signed and 16-bit unsigned waveforms | ✅ |
| P10 | File Meta group length absent from DICOMDIR and from any `DICOMFile` built without `create()`; implementation UID was the Deflated TS UID | PS3.10 Table 7.1-1 | Medium | ✅ |
| P-HP | Hanging Protocol: `FilterOperator` (EQUAL, NOT_EQUAL, CONTAINS, PRESENT, NOT_PRESENT are not terms; RANGE_INCL, RANGE_EXCL, MEMBER_OF, NOT_MEMBER_OF, TRANSVERSE, CORONAL, SAGITTAL, OBLIQUE missing), `SortByCategory` (only ALONG_AXIS and BY_ACQ_TIME exist; attribute sorting uses the Selector Attribute), `ImageSetSelectorCategory` (RELATIVE_TIME, ABSTRACT_PRIOR), `ImageBoxLayoutType` (TILED_ALL → SINGLE/CINE/PROCESSED/VOLUME_VIEW/VOLUME_CINE), `ReformattingType` (MPR, 3D_RENDERING, SLAB; MIP/MinIP/AvgIP belong to 3D Rendering Type), `HangingProtocolLevel.manufacturer`, `abstractPriorValue` typed `Int16` (SS) | PS3.3 Tables C.23.1-1, C.23.3-1 | High: these values go on the wire | **PEND** — enum cases are public API |
| P-RT | `RTROIInterpretedType`: add OAR, BRACHY_CHANNEL, BRACHY_ACCESSORY, BRACHY_SRC_APP, BRACHY_CHNL_SHLD, DOSE_MEASUREMENT, DEVICE; `ContourGeometricType.closedNonplanar` → `closedPlanarXOR` ("CLOSEDPLANAR_XOR"); Dose Units/Type/Summation, Beam Type and Radiation Type are bare strings | PS3.3 Tables C.8-42, C.8-44, C.8-39, C.8-51 | Medium | **PEND** |
| P-SEG | `SegmentationType.labelmap` ("LABELMAP", C.8.20.2.3) | PS3.3 C.8.20.2 | Medium | **PEND** |
| P-SC | `ConversionType.drawing` ("DRW"); `.unknown` writes an empty Type 1 value; `SecondaryCaptureBuilder`/`ImageConverter` omit Conversion Type (Type 1), Burned In Annotation, Presentation LUT Shape and the Type 2 patient/study attributes; `FrameMerger` the same for SC multi-frame targets | PS3.3 Table C.8-24, C.8.6.1–C.8.6.4, A.8 | Medium | **PEND** |
| P-AI | `AIDetectionType`: calcification, fracture and pneumonia have no concept in any 2026a CID (the SRT ids were wrong); `anatomicalStructure(name:)` emits (T-D0050, SRT) with a caller-supplied meaning; `ConfidenceScore.toCodedConcept` emits SRT ids that mean "No" and "Normal wall contractility"; Chest CAD `consolidation` (3128005 is not in Table O-1). Proposal: SCT concept ids verified outside NEMA (say so in the marker), `anatomicalStructure(CodedConcept)`, a `99DICOMKIT` private scheme for confidence | PS3.16 8.1, Table O-1 | Medium | **PEND** |
| P-CONST | `CodedConcept.regionOfInterest` (130488 is Region in Space), `.measurementLocation` (121233 is Source image for segmentation), `.temporalExtent` (128178 does not exist), `.comparison` (121071 is Finding): no DCM concept carries these meanings; deprecate | PS3.16 Table D-1 | Medium | **PEND** |
| P-TITLE | `MeasurementReportDocumentTitle.lesionMeasurementReport` (126002 is Dynamic Contrast MR Measurement Report) and `.ctPerfusionReport` (126003 is PET Measurement Report): CID 7021 has 126000, 126001 Oncology, 126002, 126003 only; deprecate and add `oncologyMeasurementReport`, `dynamicContrastMRMeasurementReport` | PS3.16 CID 7021 | Medium | **PEND** |
| P-WAVE | `WaveformSampleInterpretation`: add SL, UL, SV, UV; the case names `unsignedInteger` (SB) and `signedShort` (US) contradict their raw values — rename; `WaveformBuilder` omits Waveform Originality, Channel Source Sequence and Waveform Bits Stored (Type 1); `WaveformParser` reads Referenced Sample Positions (UL) via `uint16Values` | PS3.3 Table C.10-10, C.10.9 | Medium | **PEND** |
| P-PS | `AnnotationUnits.matrix` (MF-7; MATRIX objects are skipped meanwhile); `DisplayShutter` CIELab colour (NC-16, needed for CSPS/PCSPS); `DisplayedArea` pixel spacing / magnification for TRUE SIZE and MAGNIFY (NC-18); a `ColorPresentationStateBuilder` (MF-1); `GrayscalePresentationState.displayedArea` non-optional (NC-4 at the source) | PS3.3 C.10.4, C.10.5, C.11.12, A.33.2 | Medium | **PEND** |
| P-PRINT | D24: `DICOMKit.PrintColorMode` duplicates `DICOMNetwork.PrintColorMode`; neither module imports the other. Proposal: move it to DICOMCore with `typealias` in both | — | Low | **PEND** |
| P-UID | Implementation Class UID `1.2.276.0.7230010.3.0.3.6.5` (DCMTK 3.6.5's own) and `UIDGenerator.defaultRoot` are under the OFFIS root; PS3.5 9.1 expects a root the organisation owns. Proposal: a project root (the JP3D UIDs already use `1.2.826.0.1.3680043.10.511`) | PS3.5 9.1 | Medium | **PEND** |
| P-CAD | Mammography and Chest CAD builders follow TID 4000/4100 loosely (no Image Library, no Summary of Detections/Analyses, findings under a bespoke container, `processingDateTime` no longer written); a row-by-row template rebuild changes the builder API | PS3.16 TID 4000, 4100, 4015–4020 | Medium | **PEND** |
| P-TID1500 | `MeasurementReportBuilder`: Image Library without the Image Library Group container; Finding Site relationship; Country of Language placement; IMAGE INFERRED FROM directly under the group | PS3.16 TID 1500, 1501, 1600–1602, 1204 | Medium | **PEND** |
| P-SRSER | `SRDocumentSerializer`: writes the General Series module instead of SR Document Series (Referenced Performed Procedure Step Sequence Type 2 absent); TABLE integer cells always IS; empty Code Value when only Long Code Value exists; Type 1 flags written from optionals | PS3.3 C.17.1, C.17.2, C.18.10, Table 8.8-1 | Medium | **PEND** |
| P-VALID | `DICOMValidator` per-IOD required lists omit most module Type 1 attributes; GSPS Modality PR only warns | PS3.3 A.x-1 tables, C.11.9 | Low | **PEND** |
| P-VOL, P-RENDER, P-JPIP, P-ENCAP, P-VIDEO, P-SUV, P-ANON | Recorded behaviour findings: `DICOMKit+Volume` hard-codes MONOCHROME2/High Bit and uses Slice Thickness as spacing; `PixelDataRenderer` applies the full-range YBR formula to YBR_PARTIAL/ICT/RCT and `SIMDImageProcessor` uses c±w/2; `DICOMJPIPClient` reads the URL from Pixel Data instead of (0028,7FE0); `EncapsulatedDocumentBuilder`/`JP3DVolumeDocument` omit Type 1/2 Encapsulated Document attributes; `VideoBuilder` Cine module and "no audio"; `SUVCalculator` formulas and CID citation; `ConfidentialityEngine` never writes De-identification Method Code Sequence (0012,0064) | see the bucket table | Low–Medium | **PEND** |

### Decisions taken without asking (all within "fix behaviour that contradicts the standard")

- Every wrong code/meaning pair was replaced by the 2026a pair (Table D-1 or the CID) rather than
  deprecated: the constants keep their names; only their values changed. Where the CID carries a
  variant meaning (CID 7180 "SUVbw"), that meaning is used.
- Chest CAD probability is written as `(111012, DCM, "Certainty of Finding")` in percent (TID 4104
  row 12); the extractor divides by 100 so `probability` stays 0…1.
- Mammography finding types map onto CID 6015/6017: `.mass` → (129793001, SCT, "Mammography
  breast density"), `.calcification` → (129770007, "Individual Calcification"),
  `.architecturalDistortion` → (129792006), `.asymmetry` → (129790003, "Asymmetric breast tissue").
- Hanging Protocol raw values with a one-to-one standard term were changed (`GROUP` → `USER_GROUP`
  …); the parser still accepts the old display-flag spellings `Y`/`N`.
- The 1-bit segmentation bit order was fixed in both directions; a SEG written by an earlier
  DICOMKit is therefore now read with each byte mirrored. No compatibility shim was added because
  such objects were never readable by anything else either (recorded).
- The PCSPS palette no longer bakes the window (NC-8); Weasis's stored-pixel indexing is recorded
  as that viewer's limitation.
- A DICOMPrintKit test fixture that wrote Shutter Presentation Value (US) as the text "0" was
  changed to let the builder write the module; the layer-colour assertion became a tolerance
  (CIELab is a 16-bit encoding).

### Explicitly out of scope — do not chase

- Codec and bitstream internals (see the scope note).
- ICC profile structure beyond the device class and the Color Space term (ICC.1).
- The CIELab reference white: C.10.7.1.1 defines only the encoding; `ColorTransform` uses D65
  and the encoder/decoder are each other's inverse.

---

## Deferred findings

Rows for this module from the earlier reports come first.

| ID | Module | Where | Problem | Standard | Severity | Status |
|---|---|---|---|---|---|---|
| D5 | DICOMKit | `ComparisonReport.formatValue` | OV shown as text | PS3.5 Table 6.2-1 | Low | ✅ 2026-09-29: OB/OD/OF/OL/OV/OW/UN are binary (the DICOMStudio half stays open, see D28) |
| D12 | DICOMKit | `CompressionManager.decodePixelDataInPlace` | No XYB → RGB relabel | PS3.3 C.7.6.3.1.2 | Medium | ✅ 2026-09-29, `CompressionManagerXYBTests` |
| D14 | DICOMKit | `DICOMDIRReader.parseDirectoryRecord` | Unknown record type fatal | PS3.3 Table F.3-3, F.6.1 | High | ✅ 2026-09-29, `DICOMDIRReaderRecordTypeTests` |
| D15 | DICOMKit (+ dicom-dcmdir, DICOMStudio) | `DICOMDIRReader.parse` | Profile reported as fact | PS3.11 | Low | ✅ DICOMKit half 2026-09-29 (documented assumption; no attribute carries it). The help texts are D29 |
| D16 | DICOMKit | `SRDocumentType.allowsValueType` | Second value-type table | PS3.3 A.35 | Medium | ✅ 2026-09-29: deprecated, forwards to DICOMCore |
| D17 | DICOMKit | Mammography / Chest CAD builders | DATETIME items | PS3.3 A.35.5-2, A.35.6-2 | Medium | ✅ 2026-09-29; the code was also wrong (111005 is Assessment Category) |
| D18 | DICOMKit | `ComprehensiveSRBuilder` | 2D POLYGON | PS3.3 C.18.6.1.2 | Medium | ✅ 2026-09-29: closed POLYLINE |
| D19 | DICOMKit | `DICOMFile+FrameAccess` | Stale OV comment | — | Low | ✅ 2026-09-29 |
| D24 | DICOMKit | `ImagePreprocessor.PrintColorMode` | Duplicate type | — | Low | ⏳ P-PRINT (needs a DICOMCore home) |
| NC-1…NC-19 | DICOMKit | `PresentationState/` | Presentation State audit | PS3.3 A.33, C.7.6.11, C.10, C.11; PS3.4 N.2 | Critical–Low | ✅ NC-1, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17 (documented as a Standard Extended attribute), 19 fixed 2026-09-29; NC-2 → D28; NC-3, NC-4 → D27; NC-16, NC-18 → P-PS |

New findings for other modules:

| ID | Module | Where | Problem | Standard | Severity | Status |
|---|---|---|---|---|---|---|
| D26 | DICOMCore | [SRDocumentType.swift](Sources/DICOMCore/StructuredReporting/SRDocumentType.swift) `allowedValueTypes` `.colonCADSR` | Includes TCOORD, which Table A.35.10-2 lists only as a source, and lacks WAVEFORM, a TCOORD SELECTED FROM target | PS3.3 Table A.35.10-2 | Low | ⏳ Open |
| D27 | DICOMPrintKit | `ViewerPresentationStateBridge.capture`, `PresentationStateStore.save` | Displayed Area Selection Sequence (Type 1) omitted for fit views (NC-4); no Modality LUT passed into the state (S-1b); GSPS written for colour images (NC-3, needs P-PS's CSPS builder) | PS3.3 C.10.4, A.33.1.1; PS3.4 N.2.1.1 | High | ⏳ Open |
| D28 | DICOMStudio | `ImageViewerViewModel+PresentationStates` (~L1057); `DICOMInspectorView.swift:41` | Falls back to the image's rescale when the PR has no Modality LUT (NC-2; now that DICOMKit writes it, S-2 can ship with a migration rule for older DICOMKit PRs); the "is binary" check omits OV (D5's other half) | PS3.4 N.2.1.1; PS3.5 Table 6.2-1 | Medium | ⏳ Open |
| D29 | dicom-dcmdir, DICOMStudio | `main.swift:58,103`, `CLIWorkshopViewModel.swift:1730`, `CLIWorkshopHelpers.swift:3128` | `--profile` help text lists STD-GEN-DVD / STD-GEN-USB, which PS3.11 uses only as family headings (the identifiers are …-DVD-JPEG/-J2K, …-USB-JPEG/-J2K) | PS3.11 Annex H | Low | ⏳ Open (D15 remainder) |
| D30 | DICOMPrintKit | `PrintJobRequest.preprocessColorMode`, `PrintImagePreparer` | Map between the two `PrintColorMode` types; collapse when P-PRINT lands | — | Low | ⏳ Open |

---

<!-- bucket tables follow -->
## Bucket A — Cites 2026a (1 file)

| File | Confirmed | Result |
|---|---|---|
| [DICOMKit.swift](Sources/DICOMKit/DICOMKit.swift) | — | ✅ the four supported Transfer Syntax UIDs and their names match PS3.6 2026a Table A-1; dicomStandardEdition is the package target. Marked. |

## Bucket B1 — Cites a Supplement (4 files)

| File | Before | After |
|---|---|---|
| [Multiframe/FunctionalGroupBuilder.swift](Sources/DICOMKit/Multiframe/FunctionalGroupBuilder.swift) | Frame Acquisition Number written as UL (US); tag comments | ✅ Frame Acquisition Number written as US per PS3.6 2026a Table 6-1; macro membership per PS3.3 C.7.6.16 recorded; Sup 157 kept as provenance. Marked. |
| [Multiframe/MultiframeSOPClassMap.swift](Sources/DICOMKit/Multiframe/MultiframeSOPClassMap.swift) | — | ✅ 37 SOP Class UIDs and names match PS3.6 2026a Table A-1; Sup 157 kept as provenance. Marked. |
| [StructuredReporting/ChestCADSRBuilder.swift](Sources/DICOMKit/StructuredReporting/ChestCADSRBuilder.swift) | title 111037 (Margins), root 113701 (X-Ray Radiation Dose Report), DATETIME, same code errors as Mammography, SRT ids not in Table O-1 | ✅ concept names and finding codes diffed by Scripts/diff_kit.py against PS3.16 2026a Table D-1, TID 4100/4104/4019 and CID 6104; no DATETIME (Table A.35.6-2); the consolidation code is pending P-AI; Sup 65 (before 2014a) kept as provenance. Marked. |
| [StructuredReporting/KeyObjectSelectionBuilder.swift](Sources/DICOMKit/StructuredReporting/KeyObjectSelectionBuilder.swift) | 113020/113030/113040 were For Report Attachment/Manifest/Lossy Compression; Modality SR | ✅ document titles diffed by Scripts/diff_kit.py against PS3.16 2026a CID 7010; Modality KO (C.17.6.1); value types per Table A.35.4-2 (D17); Sup 59 (before 2014a) kept as provenance. Marked. |

## Bucket B2 — No citation, data or behaviour differed from 2026a or is pending (82 files)

| File | Before | After |
|---|---|---|
| [AI/AIInferenceResult.swift](Sources/DICOMKit/AI/AIInferenceResult.swift) | SRT ids that meant other concepts (M-03010 Nodule ok; F-01796 is breast density, M-03000 is Mass, M-37000 Hemorrhage, D3-81004) -> SCT ids of CID 6104 | ✅ coded concepts diffed by Scripts/diff_kit.py against PS3.16 2026a CID 6104 (SCT concept ids); the calcification, fracture, pneumonia, confidence and anatomy codes are pending P-AI. Marked. |
| [Anonymization/ConfidentialityEngine.swift](Sources/DICOMKit/Anonymization/ConfidentialityEngine.swift) | — | ✅ applies the PS3.15 2026a Table E.1-1 actions; the De-identification Method Code Sequence gap is recorded (P-ANON). Marked. |
| [Anonymization/ConfidentialityProfile.swift](Sources/DICOMKit/Anonymization/ConfidentialityProfile.swift) | Device UID X (U); order numbers X (Z); tag comments | ✅ the Basic Profile action of every row diffed by Scripts/diff_kit.py against PS3.15 2026a Table E.1-1 (62 rows; Device UID U and the order numbers Z corrected). Marked. |
| [Anonymization/PixelRedactor.swift](Sources/DICOMKit/Anonymization/PixelRedactor.swift) | — | ✅ Burned In Annotation and Code Sequence Macro citations checked against PS3.3 2026a. Marked. |
| [Comparison/ComparisonReport.swift](Sources/DICOMKit/Comparison/ComparisonReport.swift) | binary VR check omitted OV, OL, UN (D5) | ✅ binary VRs are the Other VRs of PS3.5 2026a Table 6.2-1 plus UN (D5). Marked. |
| [Compression/CompressionManager.swift](Sources/DICOMKit/Compression/CompressionManager.swift) | no XYB relabel (D12) | ✅ XYB relabelled RGB after JPEG XL decode per PS3.3 2026a C.7.6.3.1.2 (D12); encapsulation per PS3.5 A.4; Lossy Image Compression attributes per C.7.6.1.1.5. Marked. |
| [DICOMConverter.swift](Sources/DICOMKit/DICOMConverter.swift) | — | ✅ transfer syntax capabilities via DICOMCore; UID literals, names and PS3.5 citations diffed by Scripts/diff_kit.py against PS3.6 2026a Table A-1 and the PS3.5 text. Marked. |
| [DICOMDIRReader.swift](Sources/DICOMKit/DICOMDIRReader.swift) | unknown record type was fatal (D14); profile comment (D15) | ✅ PS3.3 2026a Table F.3-3, Table F.4-1 and F.6.1: unknown and PRIVATE record types are skipped, not fatal (D14); the profile is an assumption, no attribute carries it (D15). Marked. |
| [DICOMDIRWriter.swift](Sources/DICOMKit/DICOMDIRWriter.swift) | Implementation Class UID was 1.2.840.10008.1.2.1.99 (the Deflated TS UID); no (0002,0000) | ✅ PS3.3 2026a F.3.2.2 offsets and Table F.3-3 record keys; Implementation Class UID is no longer the Deflated Transfer Syntax UID; (0002,0000) is computed by DICOMFile.write() (PS3.10 Table 7.1-1). Marked. |
| [DICOMFile+FrameAccess.swift](Sources/DICOMKit/DICOMFile+FrameAccess.swift) | stale OV comment (D19) | ✅ PS3.5 2026a A.4 Basic and Extended Offset Table frame location; (7FE0,0001) is OV (D19); Extended Offset Table Lengths are not read (recorded). Marked. |
| [DICOMFile+PixelData.swift](Sources/DICOMKit/DICOMFile+PixelData.swift) | 91.1 mislabelled Content Assessment Results (it is 90.1); 200.8/200.9 mislabelled (XA Defined is 200.7) | ✅ the non-image SOP Class list diffed by Scripts/diff_kit.py against PS3.6 2026a Table A-1 (two UIDs and two names corrected); JPEG YBR relabel per PS3.5 Table 8.2.1-1. Marked. |
| [DICOMFile+Write.swift](Sources/DICOMKit/DICOMFile+Write.swift) | write() did not compute (0002,0000); implementation UID literal duplicated | ✅ PS3.10 2026a Table 7.1-1: the Type 1 File Meta elements are written and (0002,0000) is computed in write(); the Implementation Class UID root is pending P-UID. Marked. |
| [DICOMJPIPClient.swift](Sources/DICOMKit/DICOMJPIPClient.swift) | — | ✅ JPIP Referenced transfer syntax UIDs match PS3.6 2026a Table A-1; the Pixel Data Provider URL (0028,7FE0) finding of PS3.5 A.6 is recorded (P-JPIP). Marked. |
| [DICOMKit+Volume.swift](Sources/DICOMKit/DICOMKit+Volume.swift) | — | ✅ PS3.3 2026a C.7.6.2 Pixel Spacing and Image Position reads; the hard-coded MONOCHROME2 descriptor, High Bit and Slice Thickness used as spacing are recorded findings (P-VOL). Marked. |
| [EncapsulatedDocument/EncapsulatedDocument.swift](Sources/DICOMKit/EncapsulatedDocument/EncapsulatedDocument.swift) | STL MIME application/sla (model/stl) | ✅ SOP Class UIDs match PS3.6 2026a Table A-1; MIME types are the Enumerated Values of PS3.3 A.85 (model/stl). Marked. |
| [EncapsulatedDocument/EncapsulatedDocumentBuilder.swift](Sources/DICOMKit/EncapsulatedDocument/EncapsulatedDocumentBuilder.swift) | — | ✅ Encapsulated Document module per PS3.3 2026a C.24.2; the Type 1/2 gaps are recorded (P-ENCAP). Marked. |
| [GrayscaleLUT.swift](Sources/DICOMKit/GrayscaleLUT.swift) | — | ✅ PS3.3 2026a C.11.1.1 and C.11.2.1.1 LUT Descriptor semantics; the 8...16 bits-per-entry tolerance and output normalisation are recorded. Marked. |
| [HangingProtocol/DisplaySet.swift](Sources/DICOMKit/HangingProtocol/DisplaySet.swift) | VOLUME_RENDERING / SURFACE_RENDERING | ✅ 3D Rendering Type terms match PS3.3 2026a Table C.23.3-1; Image Box Layout and Reformatting terms are pending P-HP. Marked. |
| [HangingProtocol/HangingProtocol.swift](Sources/DICOMKit/HangingProtocol/HangingProtocol.swift) | GROUP / USER | ✅ Hanging Protocol Level terms match PS3.3 2026a Table C.23.1-1 (MANUFACTURER pending P-HP). Marked. |
| [HangingProtocol/HangingProtocolMatcher.swift](Sources/DICOMKit/HangingProtocol/HangingProtocolMatcher.swift) | — | ✅ matching logic over the ImageSetDefinition terms (P-HP). Marked. |
| [HangingProtocol/HangingProtocolParser.swift](Sources/DICOMKit/HangingProtocol/HangingProtocolParser.swift) | flags read as Y/N | ✅ display flags read as YES/NO per PS3.3 2026a Table C.23.3-1 (legacy Y/N still accepted). Marked. |
| [HangingProtocol/HangingProtocolSerializer.swift](Sources/DICOMKit/HangingProtocol/HangingProtocolSerializer.swift) | name LO (SH), description ST (LO), flags Y/N (YES/NO) | ✅ VRs per PS3.6 2026a Table 6-1 (SH name, LO description); display flags YES/NO per Table C.23.3-1; Abstract Prior Value as SS is pending P-HP. Marked. |
| [HangingProtocol/ImageSetDefinition.swift](Sources/DICOMKit/HangingProtocol/ImageSetDefinition.swift) | ASCENDING/DESCENDING, LESS/GREATER_THAN_OR_EQUAL | ✅ Filter-by Operator and Sorting Direction terms match PS3.3 2026a Table C.23.3-1 where one-to-one; the rest is pending P-HP. Marked. |
| [HexDumper.swift](Sources/DICOMKit/HexDumper.swift) | VR sets lacked OV, SV, UV | ✅ the VR lists are the 34 VRs of PS3.5 2026a Table 6.2-1 and the 4-byte-length VRs of Table 7.1-1 (OV, SV, UV added). Marked. |
| [ImagePreprocessor.swift](Sources/DICOMKit/ImagePreprocessor.swift) | cited PS3.5 8.7.4 (does not exist) | ✅ PS3.3 2026a C.7.6.3.1.2 YBR conversions and C.13 image box citations checked; the PrintColorMode duplicate is pending P-PRINT (D24). Marked. |
| [JP3DVolumeDocument.swift](Sources/DICOMKit/JP3DVolumeDocument.swift) | Document Title written as LO (ST) | ✅ Document Title (0042,0010) written as ST per PS3.6 2026a Table 6-1; the missing Type 1/2 Encapsulated Document attributes are recorded (P-ENCAP). Marked. |
| [Merging/FrameMerger.swift](Sources/DICOMKit/Merging/FrameMerger.swift) | — | ✅ Image Type, Pixel Presentation and Acquisition Contrast literals checked against the PS3.3 2026a module tables; the Type 1 multi-frame SC gaps are recorded (P-SC). Marked. |
| [MetadataPresenter.swift](Sources/DICOMKit/MetadataPresenter.swift) | — | ✅ UID prefixes and names checked against PS3.6 2026a Table A-1; the .20x prefix also covers JPIP HTJ2K .204/.205 (recorded). Marked. |
| [Multiframe/FunctionalGroupFlattener.swift](Sources/DICOMKit/Multiframe/FunctionalGroupFlattener.swift) | — | ✅ functional-group flattening per PS3.3 2026a C.7.6.16; the Magnetization Transfer and Partial Fourier literals are recorded. Marked. |
| [Multiframe/LegacyVectorResolver.swift](Sources/DICOMKit/Multiframe/LegacyVectorResolver.swift) | — | ✅ backslash multiplicity per PS3.5 2026a 6.4 (the LT, ST, UT, UR exception is recorded). Marked. |
| [ParametricMap/ParametricMap.swift](Sources/DICOMKit/ParametricMap/ParametricMap.swift) | T1/T2 (113054/113055 are Negative Enhancement Integral / rCBF), ve/Vp (126313/126314), SUV meanings | ✅ quantity codes diffed by Scripts/diff_kit.py against PS3.16 2026a Table D-1 (T1, T2, ve, Vp and SUV corrected). Marked. |
| [ParametricMap/ParametricMapPixelDataExtractor.swift](Sources/DICOMKit/ParametricMap/ParametricMapPixelDataExtractor.swift) | — | ✅ float pixel data per PS3.5 2026a 8.1.1 (findings recorded). Marked. |
| [Performance/SIMDImageProcessor.swift](Sources/DICOMKit/Performance/SIMDImageProcessor.swift) | — | ✅ the window approximation differs from PS3.3 2026a C.11.2.1.2 (recorded, P-RENDER). Marked. |
| [PixelDataRenderer.swift](Sources/DICOMKit/PixelDataRenderer.swift) | — | ✅ Photometric Interpretation literals are PS3.3 2026a C.7.6.3.1.2 terms; the YBR_PARTIAL, ICT and RCT conversion finding is recorded (P-RENDER). Marked. |
| [PresentationState/ColorManagement.swift](Sources/DICOMKit/PresentationState/ColorManagement.swift) | DISPLAYP3 not recognised (P3 was) | ✅ Color Space terms of PS3.3 2026a C.11.15.1.2 are read (DISPLAYP3 added); the ColorSpace enum is a display model, not (0028,2002) terms. Marked. |
| [PresentationState/DisplayFeatures.swift](Sources/DICOMKit/PresentationState/DisplayFeatures.swift) | — | ✅ IlluminationType strings are not DICOM terms (recorded); PS3.3 2026a citations checked. Marked. |
| [PresentationState/DisplayShutter.swift](Sources/DICOMKit/PresentationState/DisplayShutter.swift) | doc said the shape is the masked region | ✅ PS3.3 2026a C.7.6.11: the shape is the visible region, origin 1,1; the CIELab shutter colour is pending P-PS. Marked. |
| [PresentationState/GraphicAnnotation.swift](Sources/DICOMKit/PresentationState/GraphicAnnotation.swift) | ELLIPSE doc; units coercion | ✅ Graphic Type terms match PS3.3 2026a Table C.10-5; ELLIPSE points per C.10.5.1.2; MATRIX units are pending P-PS. Marked. |
| [PresentationState/GrayscalePresentationStateBuilder.swift](Sources/DICOMKit/PresentationState/GrayscalePresentationStateBuilder.swift) | NC-1, NC-11, NC-12, NC-14, NC-15, NC-19, MF-3, MF-10 | ✅ PS3.3 2026a A.33.1: Modality LUT (C.11.1), LUT sequences (C.11.6, C.11.8), Display Shutter (C.7.6.11), conditional Graphic Filled (C.10.5), CIELab layer colour (C.10.7.1.1), Type 2 Content Creator Name (Table 10-12). Marked. |
| [PresentationState/GrayscalePresentationStateParser.swift](Sources/DICOMKit/PresentationState/GrayscalePresentationStateParser.swift) | NC-7, NC-13, NC-14, NC-19; LUT data read as IS | ✅ shutter row/column order (C.7.6.11), CIELab layer colour (C.10.7.1.1), LUT Descriptor and Data VRs (C.11.1.1) and MATRIX units per PS3.3 2026a. Marked. |
| [PresentationState/LUTTransformation.swift](Sources/DICOMKit/PresentationState/LUTTransformation.swift) | NC-19 citation | ✅ PS3.3 2026a C.11.1.1 (65536 entries written as 0), C.11.4 and C.11.6 citations; table-valued VOI output is normalised by the applicator. Marked. |
| [PresentationState/PresentationState.swift](Sources/DICOMKit/PresentationState/PresentationState.swift) | NC-19 citations A.34/A.35/A.36 | ✅ the four presentation state SOP Class UIDs match PS3.6 2026a Table A-1; IOD citations are A.33.1-A.33.4. Marked. |
| [PresentationState/PresentationStateApplicator.swift](Sources/DICOMKit/PresentationState/PresentationStateApplicator.swift) | NC-6, NC-9, NC-10 | ✅ PS3.4 2026a N.2 pipeline: shutters mask outside every shape before the C.10.6 rotate-then-flip transform; the no-VOI range follows C.11.6.1. Marked. |
| [PresentationState/PseudoColorPresentationStateBuilder.swift](Sources/DICOMKit/PresentationState/PseudoColorPresentationStateBuilder.swift) | NC-8, NC-19 | ✅ PS3.3 2026a A.33.3: the palette carries no baked window (PS3.4 N.2, N.2.4.2); Palette Color LUT module (C.7.9) and ICC Profile module (C.11.15). Marked. |
| [PresentationState/SRGBICCProfileWriter.swift](Sources/DICOMKit/PresentationState/SRGBICCProfileWriter.swift) | NC-5 (mntr) | ✅ Input Device class scnr per PS3.3 2026a C.11.15.1.1; Color Space SRGB per C.11.15.1.2; the profile bytes themselves are ICC.1. Marked. |
| [RadiationTherapy/RTBeam.swift](Sources/DICOMKit/RadiationTherapy/RTBeam.swift) | — | ✅ beam and radiation type terms are carried as strings (recorded, P-RT); tags per PS3.6 2026a Table 6-1. Marked. |
| [RadiationTherapy/RTDose.swift](Sources/DICOMKit/RadiationTherapy/RTDose.swift) | — | ✅ Dose Units, Dose Type and Summation Type terms recorded against PS3.3 2026a C.8.8.3 (P-RT). Marked. |
| [RadiationTherapy/RTDoseParser.swift](Sources/DICOMKit/RadiationTherapy/RTDoseParser.swift) | — | ✅ RT Dose module reads per PS3.3 2026a C.8.8.3. Marked. |
| [RadiationTherapy/RTPlan.swift](Sources/DICOMKit/RadiationTherapy/RTPlan.swift) | — | ✅ RT Plan model per PS3.3 2026a C.8.8.x; term findings recorded (P-RT). Marked. |
| [RadiationTherapy/RTPlanParser.swift](Sources/DICOMKit/RadiationTherapy/RTPlanParser.swift) | — | ✅ RT Plan module reads per PS3.3 2026a C.8.8.x; the Fraction Pattern finding is recorded (P-RT). Marked. |
| [RadiationTherapy/RTStructureSet.swift](Sources/DICOMKit/RadiationTherapy/RTStructureSet.swift) | IRRADIATED_VOLUME, FIXATION_DEVICE spellings | ✅ RT ROI Interpreted Type terms match PS3.3 2026a Table C.8-44 (IRRAD_VOLUME, FIXATION corrected; seven terms pending P-RT); Contour Geometric Type is pending P-RT. Marked. |
| [RealWorldValue/RealWorldValueLUT.swift](Sources/DICOMKit/RealWorldValue/RealWorldValueLUT.swift) | as ParametricMap plus T2*, CBF/CBV/MTT (126370-126372 are other concepts) | ✅ quantity codes diffed by Scripts/diff_kit.py against PS3.16 2026a Table D-1 (T1, T2, T2*, ve, Vp, rCBF, rCBV, MTT and SUV corrected). Marked. |
| [RealWorldValue/RealWorldValueLUTParser.swift](Sources/DICOMKit/RealWorldValue/RealWorldValueLUTParser.swift) | — | ✅ Real World Value Mapping reads per PS3.3 2026a C.7.6.16.2.11. Marked. |
| [RealWorldValue/SUVCalculator.swift](Sources/DICOMKit/RealWorldValue/SUVCalculator.swift) | — | ✅ SUV formulas against PS3.16 2026a (findings recorded, P-SUV). Marked. |
| [SecondaryCapture/ImageConverter.swift](Sources/DICOMKit/SecondaryCapture/ImageConverter.swift) | — | ✅ SC modules per PS3.3 2026a A.8; the missing Conversion Type (Type 1) and Type 2 attributes are recorded (P-SC). Marked. |
| [SecondaryCapture/SecondaryCaptureBuilder.swift](Sources/DICOMKit/SecondaryCapture/SecondaryCaptureBuilder.swift) | — | ✅ SC IOD modules per PS3.3 2026a A.8; Image Type DERIVED\SECONDARY; the Type 1 multi-frame gaps are recorded (P-SC). Marked. |
| [SecondaryCapture/SecondaryCaptureImage.swift](Sources/DICOMKit/SecondaryCapture/SecondaryCaptureImage.swift) | — | ✅ SOP Class UIDs match PS3.6 2026a Table A-1; Conversion Type terms per PS3.3 Table C.8-24 (DRW and the empty value pending P-SC). Marked. |
| [Segmentation/Segmentation.swift](Sources/DICOMKit/Segmentation/Segmentation.swift) | — | ✅ Segmentation Type, Fractional Type and Algorithm Type terms match PS3.3 2026a C.8.20.2 (LABELMAP pending P-SEG). Marked. |
| [Segmentation/SegmentationBuilder.swift](Sources/DICOMKit/Segmentation/SegmentationBuilder.swift) | 1-bit frames packed MSB first; doc codes | ✅ 1-bit frames packed least-significant-bit first per PS3.5 2026a 8.1.1 and D.1; category and type codes per PS3.16 CID 7150/7151. Marked. |
| [Segmentation/SegmentationParser.swift](Sources/DICOMKit/Segmentation/SegmentationParser.swift) | — | ✅ Segmentation module reads per PS3.3 2026a C.8.20; the Dimension Index Values finding is recorded. Marked. |
| [Segmentation/SegmentationPixelDataExtractor.swift](Sources/DICOMKit/Segmentation/SegmentationPixelDataExtractor.swift) | 1-bit frames unpacked MSB first | ✅ 1-bit frames unpacked least-significant-bit first per PS3.5 2026a 8.1.1 and D.1. Marked. |
| [Segmentation/SegmentationRenderer.swift](Sources/DICOMKit/Segmentation/SegmentationRenderer.swift) | — | ✅ CIELab decoding per PS3.3 2026a C.10.7.1.1 (recorded). Marked. |
| [StructuredReporting/BasicTextSRBuilder.swift](Sources/DICOMKit/StructuredReporting/BasicTextSRBuilder.swift) | 121074 meaning "Recommendation" (Table D-1: Recommendations) | ✅ DCM section concepts diffed by Scripts/diff_kit.py against PS3.16 2026a Table D-1 (121074 Recommendations); the comparison constant is pending P-CONST. Marked. |
| [StructuredReporting/CADFindingsExtractor.swift](Sources/DICOMKit/StructuredReporting/CADFindingsExtractor.swift) | read only the pre-check codes | ✅ reads the TID 4006/4104/4019 concepts of PS3.16 2026a that the builders write, and the codes written before the check. Marked. |
| [StructuredReporting/ComprehensiveSRBuilder.swift](Sources/DICOMKit/StructuredReporting/ComprehensiveSRBuilder.swift) | 2D POLYGON (D18) | ✅ 2D SCOORD closed shapes are POLYLINE with the first vertex repeated, per PS3.3 2026a C.18.6.1.2 (D18); three concept constants are pending P-CONST. Marked. |
| [StructuredReporting/EnhancedSRBuilder.swift](Sources/DICOMKit/StructuredReporting/EnhancedSRBuilder.swift) | 121206 "Measurements" (D-1: Distance); SRT G-D785/G-A220 meant Depth/Width | ✅ measurement concepts are the SCT codes of PS3.16 2026a CID 7470-7472 and (126010, DCM, Imaging Measurements). Marked. |
| [StructuredReporting/MammographyCADSRBuilder.swift](Sources/DICOMKit/StructuredReporting/MammographyCADSRBuilder.swift) | DATETIME item (D17); 111005 "Processing Date Time" (Assessment Category), 113878, 111001 as container, 111047 "Probability", 111030 "Center", 111034 "ROI"/"CAD Finding", SRT finding ids meaning other concepts | ✅ concept names and finding codes diffed by Scripts/diff_kit.py against PS3.16 2026a Table D-1, TID 4006/4019 and CID 6015/6017; no DATETIME (Table A.35.5-2, D17); the template structure is pending P-CAD. Marked. |
| [StructuredReporting/MeasurementExtractor.swift](Sources/DICOMKit/StructuredReporting/MeasurementExtractor.swift) | closed POLYLINE had no area | ✅ CID 42 qualifier meanings match PS3.16 2026a; closed POLYLINE handled per PS3.3 C.18.6.1.2; DerivationMethod is library-local. Marked. |
| [StructuredReporting/MeasurementReportBuilder.swift](Sources/DICOMKit/StructuredReporting/MeasurementReportBuilder.swift) | 126010 as "PET Measurement Report" (it is Imaging Measurements; PET is 126003) | ✅ CID 7021 titles diffed by Scripts/diff_kit.py against PS3.16 2026a (126003); two title constants are pending P-TITLE; TID 1500 placement findings are recorded (P-TID1500). Marked. |
| [StructuredReporting/MeasurementReportExtractor.swift](Sources/DICOMKit/StructuredReporting/MeasurementReportExtractor.swift) | — | ✅ TID 1500/1501/1600 concept codes diffed by Scripts/diff_kit.py against PS3.16 2026a Table D-1 and the CID tables. Marked. |
| [StructuredReporting/SRDocumentBuilder.swift](Sources/DICOMKit/StructuredReporting/SRDocumentBuilder.swift) | second value-type table (D16) | ✅ value-type rules delegate to DICOMCore allows(_:), which reproduces PS3.3 2026a Tables A.35.x-2 (D16). Marked. |
| [StructuredReporting/SRDocumentParser.swift](Sources/DICOMKit/StructuredReporting/SRDocumentParser.swift) | SCOORD3D frame of reference read from (0020,0052) | ✅ SCOORD3D reads Referenced Frame of Reference UID (3006,0024) per PS3.3 2026a Table C.18.9-1; content module tags per PS3.6 Table 6-1; the TABLE and NUM qualifier gaps are recorded. Marked. |
| [StructuredReporting/SRDocumentSerializer.swift](Sources/DICOMKit/StructuredReporting/SRDocumentSerializer.swift) | SCOORD3D frame of reference written as (0020,0052) | ✅ SCOORD3D writes (3006,0024) per PS3.3 2026a Table C.18.9-1; VR literals per PS3.6 Table 6-1; series module and TABLE cell findings are recorded (P-SRSER). Marked. |
| [UIDManagement/UIDManager.swift](Sources/DICOMKit/UIDManagement/UIDManager.swift) | — | ✅ PS3.5 2026a 9.1 UID syntax (at most 64 characters, numeric components, no leading zeros); UIDType labels via DICOMDictionary. Marked. |
| [Validation/DICOMValidator.swift](Sources/DICOMKit/Validation/DICOMValidator.swift) | File Meta Type 1 list, TM/DA formats, "UTF-8", SR detection | ✅ PS3.10 2026a Table 7.1-1 Type 1 File Meta elements; PS3.5 Table 6.2-1 DA and TM formats; ISO_IR 192; SR classes via DICOMCore; the per-IOD required lists are partial (recorded, P-VALID). Marked. |
| [Video/MP4ContainerParser.swift](Sources/DICOMKit/Video/MP4ContainerParser.swift) | — | ✅ container syntax is ISO/IEC 14496-12 (out of scope); the no-audio claim is recorded (P-VIDEO). Marked. |
| [Video/Video.swift](Sources/DICOMKit/Video/Video.swift) | — | ✅ video transfer syntax UIDs and names match PS3.6 2026a Table A-1; Lossy Image Compression Method terms recorded (P-VIDEO). Marked. |
| [Video/VideoBuilder.swift](Sources/DICOMKit/Video/VideoBuilder.swift) | — | ✅ video IOD modules per PS3.3 2026a A.32; Cine module gaps recorded (P-VIDEO). Marked. |
| [Video/VideoConformanceValidator.swift](Sources/DICOMKit/Video/VideoConformanceValidator.swift) | — | ✅ profile, level and BD flag of every video transfer syntax diffed by Scripts/diff_kit.py against the PS3.6 2026a Table A-1 names; BD formats per PS3.5 Table 8-4. Marked. |
| [Waveform/Waveform.swift](Sources/DICOMKit/Waveform/Waveform.swift) | SB/US signedness inverted | ✅ Waveform Sample Interpretation terms and signedness match PS3.3 2026a Table C.10-10 (SL, UL, SV, UV pending P-WAVE); waveform SOP Class UIDs per PS3.6 Table A-1. Marked. |
| [Waveform/WaveformBuilder.swift](Sources/DICOMKit/Waveform/WaveformBuilder.swift) | (0070,0006) written as UT (ST) | ✅ (0070,0006) Unformatted Text Value written as ST per PS3.6 2026a Table 6-1; the Type 1 waveform module gaps are recorded (P-WAVE). Marked. |
| [Waveform/WaveformParser.swift](Sources/DICOMKit/Waveform/WaveformParser.swift) | — | ✅ waveform module reads per PS3.3 2026a C.10.9; the Referenced Sample Positions VR finding is recorded (P-WAVE). Marked. |

## Bucket C1 — Plumbing (35 files)

| File | Confirmed | Result |
|---|---|---|
| [AnnotationRenderer.swift](Sources/DICOMKit/AnnotationRenderer.swift) | — | ✅ carries no DICOM-standard data (Core Graphics overlay drawing). Marked. |
| [Archive/ArchiveStore.swift](Sources/DICOMKit/Archive/ArchiveStore.swift) | — | ✅ carries no DICOM-standard data (SQLite-backed index). Marked. |
| [Comparison/DICOMComparer.swift](Sources/DICOMKit/Comparison/DICOMComparer.swift) | — | ✅ carries no DICOM-standard data (element comparison). Marked. |
| [ConvertConsole.swift](Sources/DICOMKit/ConvertConsole.swift) | — | ✅ carries no DICOM-standard data (console output). Marked. |
| [DICOMDIRDumpFormatter.swift](Sources/DICOMKit/DICOMDIRDumpFormatter.swift) | — | ✅ carries no DICOM-standard data (text, tree and JSON presentation of a DICOMDirectory). Marked. |
| [DICOMDIRWorkflow.swift](Sources/DICOMKit/DICOMDIRWorkflow.swift) | — | ✅ carries no DICOM-standard data (file discovery, build loop and report text; only the DICOMDIR file name of PS3.10 8.6). Marked. |
| [DICOMFile+ParallelDecode.swift](Sources/DICOMKit/DICOMFile+ParallelDecode.swift) | — | ✅ carries no DICOM-standard data (task-group scheduling and byte budgets). Marked. |
| [DICOMVolume.swift](Sources/DICOMKit/DICOMVolume.swift) | — | ✅ carries no DICOM-standard data (in-memory voxel container; its defaults are API defaults, not standard claims). Marked. |
| [DataSet.swift](Sources/DICOMKit/DataSet.swift) | — | ✅ carries no DICOM-standard data (element container and typed accessors delegating to DICOMCore value types). Marked. |
| [FileGathering.swift](Sources/DICOMKit/FileGathering.swift) | — | ✅ carries no DICOM-standard data (directory walk). Marked. |
| [ImageResizer.swift](Sources/DICOMKit/ImageResizer.swift) | — | ✅ carries no DICOM-standard data (resampling). Marked. |
| [Merging/MergeConsole.swift](Sources/DICOMKit/Merging/MergeConsole.swift) | — | ✅ carries no DICOM-standard data (console output). Marked. |
| [OutputPathResolver.swift](Sources/DICOMKit/OutputPathResolver.swift) | — | ✅ carries no DICOM-standard data (output path composition). Marked. |
| [ParametricMap/ParametricMapRenderer.swift](Sources/DICOMKit/ParametricMap/ParametricMapRenderer.swift) | — | ✅ carries no DICOM-standard data (rendering). Marked. |
| [Performance/DICOMBenchmark.swift](Sources/DICOMKit/Performance/DICOMBenchmark.swift) | — | ✅ carries no DICOM-standard data (timing harness). Marked. |
| [Performance/DICOMByteSource.swift](Sources/DICOMKit/Performance/DICOMByteSource.swift) | — | ✅ carries no DICOM-standard data (byte source abstraction). Marked. |
| [Performance/ImageCache.swift](Sources/DICOMKit/Performance/ImageCache.swift) | — | ✅ carries no DICOM-standard data (LRU cache). Marked. |
| [Performance/ParsingOptions.swift](Sources/DICOMKit/Performance/ParsingOptions.swift) | — | ✅ carries no DICOM-standard data (parser limits). Marked. |
| [PresentationState/ICCProfileParser.swift](Sources/DICOMKit/PresentationState/ICCProfileParser.swift) | — | ✅ carries no DICOM-standard data (ICC.1 profile parsing). Marked. |
| [PresentationState/LUTColorTransform.swift](Sources/DICOMKit/PresentationState/LUTColorTransform.swift) | — | ✅ carries no DICOM-standard data (ICC lut8, lut16, mAB and mBA transforms). Marked. |
| [RealWorldValue/RealWorldValueRenderer.swift](Sources/DICOMKit/RealWorldValue/RealWorldValueRenderer.swift) | — | ✅ carries no DICOM-standard data (rendering). Marked. |
| [Scripting/ScriptConsole.swift](Sources/DICOMKit/Scripting/ScriptConsole.swift) | — | ✅ carries no DICOM-standard data (console output). Marked. |
| [Scripting/ScriptEngine.swift](Sources/DICOMKit/Scripting/ScriptEngine.swift) | — | ✅ carries no DICOM-standard data (script interpreter). Marked. |
| [SecondaryCapture/ImageConsole.swift](Sources/DICOMKit/SecondaryCapture/ImageConsole.swift) | — | ✅ carries no DICOM-standard data (console output). Marked. |
| [StructuredReporting/ContentTreeNavigator.swift](Sources/DICOMKit/StructuredReporting/ContentTreeNavigator.swift) | — | ✅ carries no DICOM-standard data (content tree traversal; relationship types are DICOMCore enums). Marked. |
| [Study/StudyManager.swift](Sources/DICOMKit/Study/StudyManager.swift) | — | ✅ carries no DICOM-standard data (study grouping). Marked. |
| [Study/StudyOrganizer.swift](Sources/DICOMKit/Study/StudyOrganizer.swift) | — | ✅ carries no DICOM-standard data (file organisation; Modality via DICOMCore). Marked. |
| [TagEditing/TagEditor.swift](Sources/DICOMKit/TagEditing/TagEditor.swift) | — | ✅ carries no DICOM-standard data (element editing plumbing). Marked. |
| [Validation/ValidationReport.swift](Sources/DICOMKit/Validation/ValidationReport.swift) | — | ✅ carries no DICOM-standard data (report formatting). Marked. |
| [Video/BitstreamReader.swift](Sources/DICOMKit/Video/BitstreamReader.swift) | — | ✅ carries no DICOM-standard data (bit reader; ITU-T bitstream syntax is out of scope). Marked. |
| [Video/H264Parser.swift](Sources/DICOMKit/Video/H264Parser.swift) | — | ✅ carries no DICOM-standard data (ITU-T H.264 bitstream syntax, out of scope). Marked. |
| [Video/HEVCParser.swift](Sources/DICOMKit/Video/HEVCParser.swift) | — | ✅ carries no DICOM-standard data (ITU-T H.265 bitstream syntax, out of scope). Marked. |
| [Video/TransportStreamScanner.swift](Sources/DICOMKit/Video/TransportStreamScanner.swift) | — | ✅ carries no DICOM-standard data (ISO/IEC 13818-1 transport stream, out of scope). Marked. |
| [Video/VideoProbe.swift](Sources/DICOMKit/Video/VideoProbe.swift) | — | ✅ carries no DICOM-standard data (container probing). Marked. |
| [Video/VideoWorkflow.swift](Sources/DICOMKit/Video/VideoWorkflow.swift) | — | ✅ carries no DICOM-standard data (workflow orchestration). Marked. |

## Bucket C2 — Standard-derived, edition-stable (34 files)

| File | Confirmed | Result |
|---|---|---|
| [Anonymization/Anonymizer.swift](Sources/DICOMKit/Anonymization/Anonymizer.swift) | — | ✅ legacy profiles; de-identification method attributes per PS3.3 2026a C.7.1.1. Marked. |
| [Anonymization/DeviceRedactionTemplates.swift](Sources/DICOMKit/Anonymization/DeviceRedactionTemplates.swift) | — | ✅ pixel redaction geometry only; Burned In Annotation per PS3.3 2026a C.7.6.1. Marked. |
| [Anonymization/PixelRedactionPlan.swift](Sources/DICOMKit/Anonymization/PixelRedactionPlan.swift) | — | ✅ pixel redaction geometry only; Burned In Annotation per PS3.3 2026a C.7.6.1. Marked. |
| [Compression/CompressionConsole.swift](Sources/DICOMKit/Compression/CompressionConsole.swift) | — | ✅ transfer syntax names via DICOMCore. Marked. |
| [DICOMFile+ProgressiveDecode.swift](Sources/DICOMKit/DICOMFile+ProgressiveDecode.swift) | — | ✅ the JPEG 2000 / HTJ2K family is named through DICOMCore TransferSyntax constants verified in the DICOMCore pass; resolution levels are JPEG 2000, not DICOM. Marked. |
| [DICOMFile.swift](Sources/DICOMKit/DICOMFile.swift) | VR sniff list lacked OV, SV, UV | ✅ PS3.10 2026a 7.1 preamble and prefix rules; the VR sniff list is the 34 VRs of PS3.5 2026a Table 6.2-1 (OV, SV, UV added). Marked. |
| [DICOMParser.swift](Sources/DICOMKit/DICOMParser.swift) | — | ✅ PS3.5 2026a 7.1.2, 7.1.3, 7.5, A.4 and A.5 encoding rules read clause by clause (item and delimiter tags, undefined length, Basic Offset Table, fragments, raw DEFLATE); the multi-VR first-VR heuristic is recorded. Marked. |
| [DataSet+DictionaryVR.swift](Sources/DICOMKit/DataSet+DictionaryVR.swift) | — | ✅ the 17 string VRs are the character-string VRs of PS3.5 2026a Table 6.2-1; DS is at most 16 bytes; the VR of written elements comes from the DICOMDictionary. Marked. |
| [DataSet+PixelData.swift](Sources/DICOMKit/DataSet+PixelData.swift) | — | ✅ Image Pixel (C.7.6.3), Modality LUT (C.11.1), VOI (C.11.2), Palette (C.7.9) and functional-group (C.7.6.16) reads checked against PS3.3 2026a; defaults for absent Type 1 attributes are recorded as robustness choices. Marked. |
| [DeflatedDataSet.swift](Sources/DICOMKit/DeflatedDataSet.swift) | — | ✅ PS3.5 2026a A.5: the data set is one raw DEFLATE stream and the File Meta Information is not deflated; strict end-of-stream handling recorded. Marked. |
| [EncapsulatedDocument/EncapsulatedDocumentParser.swift](Sources/DICOMKit/EncapsulatedDocument/EncapsulatedDocumentParser.swift) | — | ✅ Encapsulated Document module reads per PS3.3 2026a C.24.2. Marked. |
| [EncapsulatedDocument/EncapsulatedDocumentWorkflow.swift](Sources/DICOMKit/EncapsulatedDocument/EncapsulatedDocumentWorkflow.swift) | — | ✅ workflow over the builder and parser; MIME types via EncapsulatedDocument. Marked. |
| [HangingProtocol/SelectorAttributeValueCoding.swift](Sources/DICOMKit/HangingProtocol/SelectorAttributeValueCoding.swift) | — | ✅ Selector Attribute value attributes per PS3.3 2026a C.23.4. Marked. |
| [ImageExport/DICOMImageExporter.swift](Sources/DICOMKit/ImageExport/DICOMImageExporter.swift) | — | ✅ window and rescale per PS3.3 2026a C.11.2.1.2 and C.11.1.1.2. Marked. |
| [JP3DVolumeBridge.swift](Sources/DICOMKit/JP3DVolumeBridge.swift) | Instance Number (IS) read as uint16 | ✅ Instance Number read as IS per PS3.6 2026a Table 6-1; Pixel Data VR rule per PS3.5 8.1.1; the JP3D UIDs are private. Marked. |
| [Multiframe/MultiframeConcatenation.swift](Sources/DICOMKit/Multiframe/MultiframeConcatenation.swift) | — | ✅ Concatenation attributes per PS3.3 2026a C.7.6.16.2.2. Marked. |
| [Multiframe/MultiframePixelAssembler.swift](Sources/DICOMKit/Multiframe/MultiframePixelAssembler.swift) | — | ✅ frame assembly per PS3.5 2026a 8.1.1. Marked. |
| [OverlayPlaneRenderer.swift](Sources/DICOMKit/OverlayPlaneRenderer.swift) | — | ✅ 60xx overlay attributes and VRs match PS3.6 2026a Table 6-1; the PS3.3 C.9 multi-frame overlay rule is recorded. Marked. |
| [ParametricMap/ParametricMapParser.swift](Sources/DICOMKit/ParametricMap/ParametricMapParser.swift) | — | ✅ Parametric Map module reads per PS3.3 2026a C.8.32. Marked. |
| [PixelEditing/PixelEditor.swift](Sources/DICOMKit/PixelEditing/PixelEditor.swift) | — | ✅ the C.11.2.1.2 window formula matches PS3.3 2026a; DS is at most 16 bytes; File Meta group length per PS3.10 7.1. Marked. |
| [PresentationState/ColorTransform.swift](Sources/DICOMKit/PresentationState/ColorTransform.swift) | — | ✅ carries no DICOM-standard data beyond the CIELab maths used for C.10.7.1.1 encoding (D65 reference, recorded). Marked. |
| [PresentationState/SpatialTransformation.swift](Sources/DICOMKit/PresentationState/SpatialTransformation.swift) | — | ✅ rotation, flip and Presentation Size Mode terms match PS3.3 2026a C.10.4 and C.10.6. Marked. |
| [RadiationTherapy/RTStructureSetParser.swift](Sources/DICOMKit/RadiationTherapy/RTStructureSetParser.swift) | — | ✅ RT Structure Set module reads per PS3.3 2026a C.8.8.5-C.8.8.8. Marked. |
| [SecondaryCapture/SecondaryCaptureParser.swift](Sources/DICOMKit/SecondaryCapture/SecondaryCaptureParser.swift) | — | ✅ SC attribute reads per PS3.3 2026a C.8.6. Marked. |
| [Splitting/FrameSplitter.swift](Sources/DICOMKit/Splitting/FrameSplitter.swift) | — | ✅ concatenation and Number of Frames rules per PS3.3 2026a C.7.6.16 and C.7.6.6. Marked. |
| [Splitting/SplitConsole.swift](Sources/DICOMKit/Splitting/SplitConsole.swift) | — | ✅ SOP Class names match PS3.6 2026a Table A-1. Marked. |
| [StructuredReporting/Comprehensive3DSRBuilder.swift](Sources/DICOMKit/StructuredReporting/Comprehensive3DSRBuilder.swift) | — | ✅ SCOORD3D graphic types match PS3.3 2026a C.18.9.1.2; Referenced Frame of Reference UID per Table C.18.9-1. Marked. |
| [StructuredReporting/KeyObjectExtractor.swift](Sources/DICOMKit/StructuredReporting/KeyObjectExtractor.swift) | — | ✅ SOP Class gate and value-type walk per PS3.3 2026a A.35.4. Marked. |
| [StructuredReporting/SRDocument.swift](Sources/DICOMKit/StructuredReporting/SRDocument.swift) | cited Table C.17.2.5-1 (does not exist) | ✅ Completion, Verification and Preliminary Flag terms match PS3.3 2026a Table C.17-2. Marked. |
| [Video/MPEG2Parser.swift](Sources/DICOMKit/Video/MPEG2Parser.swift) | — | ✅ MPEG2 transfer syntax UIDs .100/.101 match PS3.6 2026a Table A-1; the bitstream syntax is ITU-T H.262 (out of scope). Marked. |
| [Video/VideoConsole.swift](Sources/DICOMKit/Video/VideoConsole.swift) | — | ✅ SOP Class names match PS3.6 2026a Table A-1. Marked. |
| [Video/VideoExtractor.swift](Sources/DICOMKit/Video/VideoExtractor.swift) | — | ✅ one fragment per frame per PS3.5 2026a A.4 and 8.2.x. Marked. |
| [Video/VideoParser.swift](Sources/DICOMKit/Video/VideoParser.swift) | — | ✅ transfer syntax detection via DICOMCore; UIDs per PS3.6 2026a Table A-1. Marked. |
| [Video/VideoStreamInfo.swift](Sources/DICOMKit/Video/VideoStreamInfo.swift) | — | ✅ carries codec parameters only; the DICOM constraints are checked in VideoConformanceValidator. Marked. |

## Verification notes

- **Scripted checks** ([Scripts/diff_kit.py](Scripts/diff_kit.py), 41 checks): UID literals and
  the names beside them (PS3.6 Table A-1); coded concept literals by value, scheme and meaning
  (PS3.16 Table D-1 and every CID table, with `Include CID` resolved; SRT ids through Table O-1);
  the VR of every element written with an explicit `vr:` and of every typed read (PS3.6 Table
  6-1); names and keywords beside `Tag(group:element:)` literals; section, table, TID and CID
  citations against the 2026a tables of contents; the SR IOD value-type sets DICOMCore carries;
  string enumerations and the CS literals written to attributes whose module table lists terms
  (an attribute's terms are the union over every module table that lists it, following "See …"
  cross-references, because the same attribute is restricted differently per IOD — hence the
  informational "missing" terms such as FRAME/VOLUME for Presentation Size Mode); the Basic
  Profile action of every `ConfidentialityProfile` row (PS3.15 Table E.1-1); the video profile,
  level and BD flag of every video transfer syntax (PS3.6 Table A-1 names); the Waveform Sample
  Interpretation terms and signedness (PS3.3 Table C.10-10); Photometric Interpretation literals.
- **Read against the text, not scripted:** the DICOMDIR record hierarchy (F.3–F.6), the File Meta
  Information rules (PS3.10 7.1), the encoding rules of `DICOMParser` (PS3.5 7.1–7.5, A.4, A.5),
  the Presentation State modules listed in the Progress log, the 1-bit packing order (PS3.5 8.1.1,
  D.1), the SCOORD3D macro (Table C.18.9-1), the KOS series module (C.17.6.1), the STL MIME type
  (A.85.1), the DA/TM formats (Table 6.2-1), TID 4006/4017/4019/4104 rows.
- **Not verified in this pass (recorded, see the P-items):** row-by-row template conformance of
  the SR builders (TID 1500, 4000, 4100 families); the Type 1/2 completeness of the SC, video,
  waveform and encapsulated-document builders against their IOD tables; the RT Plan/Dose/Beam
  term strings; the SUV formulas; the JPIP URL attribute; the `DICOMKit+Volume` geometry; the
  completeness of `nonImageSOPClasses` (only its wrong entries were corrected); the
  `ConfidentialityProfile` coverage of Table E.1-1 (62 of ~530 rows are carried by design, the
  rest by VR sweeps — the check verifies the 62 carried rows, not coverage).
- **DICOMCore data relied on** (verified in the DICOMCore pass, 2026-09-25): `TransferSyntax`,
  `PhotometricInterpretation`, `DirectoryRecordType`, `DICOMDIRProfile`, `SRDocumentType`,
  `GraphicType`, the data dictionary and UID registry. One divergence found (D26).
- **Compatibility consequences of the fixes:** Segmentation objects written by DICOMKit before
  this pass are read with each byte of their 1-bit frames mirrored (they were never readable by
  conformant readers); presentation states written before this pass carry the retired RGB layer
  colour and `Y`/`N` flags, both still read; CAD SRs written before this pass carry the old codes,
  which `CADFindingsExtractor` still reads.
- **Tests at the end (2026-09-29, full `swift test`):** all XCTest bundles pass (DICOMKitTests
  1,160 cases, 11 skipped, 0 failures; DICOMPrintKitTests 323; DICOMCore, DICOMDictionary,
  DICOMNetwork, DICOMNetworkSecurity, DICOMRenderKit, DICOMRoundTrip, DICOMStudio, DICOMViewer,
  DICOMWeb) and every swift-testing run passes (5,165 + 1,505 + 677 + 630 + 474 + 226 + 84 + 53 +
  30 + 20 tests), exit 0. Baseline on an untouched HEAD worktree: 1,159 XCTest cases and 674
  swift-testing tests, 0 failures, so no pre-existing failures had to be logged.
