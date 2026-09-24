# DICOMCore — DICOM Standard Implementation Report

Generated 2026-09-24. Covers all 104 Swift files in `Sources/DICOMCore/`. Read file-by-file; no
README/CHANGELOG/CONTRIBUTING claims were used as evidence, only source doc comments and the
actual data each file carries.

**Scope note.** DICOMCore wraps external codec libraries (J2KSwift, JLSwift, JLISwift, JXLSwift)
for JPEG / JPEG 2000 / HTJ2K / JPEG-LS / JPEG XL / RLE. The compression algorithms themselves are
governed by ISO/IEC and ITU-T, not DICOM — "which DICOM edition" does not apply to that code. DICOM
only governs the *boundary*: which Transfer Syntax UID names a codec and when it was registered
(PS3.5 registry, edition-specific), and how the compressed bytes are framed as a DICOM element (VR,
length field, encapsulation — PS3.5 core rules). This report scores files against that boundary, not
against the codecs' own internal correctness.

Package target: **DICOM 2026a** (`dicomStandardEdition = "2026a"`, `Sources/DICOMKit/DICOMKit.swift:47`).

---

## Verification method (reuse for every module)

### Policy

| The file cites… | Verify against | Then |
|---|---|---|
| An edition **later** than 2026a (e.g. 2026d) | That edition's NEMA source | Keep the citation once it is confirmed; it becomes a candidate target for the next DICOMKit version |
| An edition **earlier** than 2026a (e.g. 2024d), or a Sup/CP | The originating edition, plus every edition's release notes up to 2026a | Keep it as provenance, and mark the file verified against 2026a |
| 2026a, or no edition | 2026a | Mark it verified against 2026a |

When DICOMKit moves to a newer target edition, run the same procedure against that edition.

### Marker

A marker goes on each verified file or section:

```
NEMA-verified: <edition>, checked <yyyy-mm-dd> — <what was compared>; <provenance CP/Sup (edition)>
```

### Sources

- **Release notes for each edition.** These list, per PS3.x part, every CP and Supplement applied relative to the previous edition.
  - Editions 2014a–2026c: the GitHub mirror `celeron533/DICOM-Release-Notes`, at `downloaded/releasenotes_<edition>.xml`. It copies NEMA's DocBook release notes.
    `gh api repos/celeron533/DICOM-Release-Notes/contents/downloaded/releasenotes_<ed>.xml --jq .content | base64 -d`
  - The newest edition, not yet mirrored: `https://dicom.nema.org/medical/dicom/current/source/docbook/releasenotes/releasenotes_<ed>.xml`
- **Standard text for a specific edition.** Use `https://dicom.nema.org/medical/dicom/<edition>/source/docbook/partNN/partNN.xml`, for example `/2026a/`. PDFs are under `/<edition>/output/pdf/`.
  - Confirmed on 2026-09-24: the 2026a copies of PS3.3, PS3.5, PS3.6 and PS3.16 each carry the subtitle "DICOM PS3.x **2026a**". **Always verify against this frozen edition.**
  - `/current/` is a rolling alias; on 2026-09-24 it pointed at **2026d**. Use it only for claims that cite a later edition.
  - As of 2026-09-24, NEMA has not published a frozen `/2026d/` DocBook copy (`/2026d/` only links to `/current/`). For 2026d, use `/current/` and confirm its subtitle says 2026d.
  - Zero-width spaces (U+200B) must be stripped before comparing keywords or UIDs.
- **Finding the edition that introduced something.** Grep all the release notes for `xml:id="cp_NNNN"` or `sup_NNN`. The release notes start at 2014a, so anything older is dated only as "before 2014a".

---

## Summary

| Bucket | Count | Meaning | Status |
|---|---|---|---|
| A — Implements 2026a | 6 | Explicit 2026a citation and/or verified-current data | ✅ **Complete** — text-diffed against 2026a, markers added |
| B1 — Explicit other edition/CP/Supplement | 4 | Deliberate citation to a specific correction, not 2026a | ✅ **Complete** — text-diffed against 2026a (and 2026d for VR.swift), markers added |
| B2 — Stale or incorrect, no citation | 10 | Data gap or bug relative to 2026a, undocumented | 🔄 In progress — 2 of 10 fixed (P1) |
| C1 — Pure plumbing | 25 | No DICOM-standard data at all | ⏳ Not started |
| C2 — Standard-derived, edition-stable | 59 | Carries PS3.x data that hasn't materially changed across recent editions | ⏳ Not started |

**104 files total.**

### Progress log

| Date | Bucket | Work done |
|---|---|---|
| 2026-09-24 | A | Stage 1: checked the source data for internal consistency (counts, duplicates, agreement between files, test assertions). Stage 2: checked it against the NEMA 2026a release notes. No 2026a CP touches any Bucket A table. |
| 2026-09-24 | B1 | All 4 files checked against the NEMA release notes (2014a–2026d) and against PS3.5 and PS3.6 2026d. `VR.swift` CP citation corrected (CP-1818 → CP 1819). `NEMA-verified` markers added to all 4. DICOMCore still builds. |
| 2026-09-24 | A | `NEMA-verified` markers added to all 6 files. Each marker is limited to what was actually checked. DICOMCore still builds. |
| 2026-09-24 | A | Stage 3: every table compared row by row with the frozen NEMA **2026a** text (PS3.3, PS3.6 and PS3.16 downloaded from `/2026a/`). All six files match. Markers upgraded to "text-diffed". **Bucket A complete.** |
| 2026-09-24 | B1 | Redone as a Stage 3 text diff: PS3.3, PS3.5 and PS3.6 from `/2026a/`, plus PS3.5 2026d from `/current/`, because NEMA has no frozen `/2026d/` copy (404). All 4 files match. CP 1819 confirmed from the 2019a release notes, and Sup 232 from the 2024d notes. Markers upgraded to "text-diffed". Two cosmetic findings (the .110 display name and a padding comment) were fixed later the same day with approval. DICOMCore still builds. **Bucket B1 complete.** |
| 2026-09-24 | B2 / P1 | Fixed 64-bit VR support after checking PS3.5 2026a (Table 6.2-1, §7.3) and PS3.18 2026a (F.2.2, Table F.2.3-1). `DataElement.swift` and `TransferSyntaxConverter.swift` fixed, plus the DICOMWeb JSON encoder and decoder. 12 new tests; the full DICOMCore, DICOMWeb and round-trip test runs pass. Found 5 related gaps outside DICOMCore (see P1), not fixed yet. |
| 2026-09-24 | — | Decision: bugs found outside DICOMCore are deferred until their module is audited. Added a [Deferred findings](#deferred-findings--outside-dicomcore) section (D1–D9). D1, the DICOMNetwork length bug, is rated High. Added P7 (JPEG XL one fragment per frame) for the C2 audit. |
| 2026-09-24 | B2 | Loop started. `PhotometricInterpretation.swift`: text-diffed against PS3.3 2026a C.7.6.3.1.2 and PS3.5 2026a Table 8.2.15-1. XYB is confirmed missing. Paused for approval because the fix adds a public enum case. |

---

## Priority action list

Ordered by real-world impact, not file count.

### P1 — 64-bit VR (OV/SV/UV) support is functionally incomplete — **DONE 2026-09-24**

VR.swift declared `.OV`, `.SV` and `.UV`, but the code that encodes and decodes them was never finished. Each fix was checked against the frozen 2026a text before editing:

| Gap | Standard (2026a) | Fix |
|---|---|---|
| `DataElement.swift`: no 64-bit value accessors, so a UV or SV value could not be read | PS3.5 Table 6.2-1: SV is a signed 64-bit integer, UV an unsigned 64-bit integer (8 bytes each), OV a stream of 64-bit words | Added `uint64Value`, `int64Value`, `uint64Values` and `int64Values`. They follow the byte order of the element, like the existing 16- and 32-bit accessors. As with `uint32Value`, the unsigned accessors also accept SV, UN and OV. |
| `TransferSyntaxConverter.swift`: OV/SV/UV missing from `numericVRs` and the byte-swap switch, so values were left unswapped on LE↔BE conversion | PS3.5 §7.3 lists the 8-byte VRs that are byte-swapped as "OD, OV, FD, SV and UV" | Added all three to `numericVRs` and to the 64-bit swap case |
| `DICOMWeb/DICOMJSONEncoder.swift` and `DICOMJSONDecoder.swift` (outside DICOMCore): OV/SV/UV not handled | PS3.18 Table F.2.3-1: OV is a Base64 octet-stream; SV and UV are "Number or String". The note to F.2.3 allows a String "to avoid losing precision" | OV is now encoded as InlineBinary. SV and UV are written as JSON Numbers when the magnitude is at most 2^53 − 1, and as decimal Strings above that, because larger values lose precision in IEEE-754 double parsers such as JavaScript's. The decoder accepts either form. |

Tests: `Tests/DICOMCoreTests/SixtyFourBitVRTests.swift` (6) and `Tests/DICOMWebTests/DICOMJSON64BitVRTests.swift` (6). They cover the accessors, a big-endian element, an LE→BE→LE round trip with a byte-exact check, and a JSON round trip. The full DICOMCore, DICOMWeb and round-trip test runs pass.

**Related bugs outside DICOMCore:** five were found while fixing P1. By decision (2026-09-24) they are deferred until their module is audited. See [Deferred findings](#deferred-findings--outside-dicomcore) (D1–D5).

### P2 — `TransferSyntax.swift`: verify and close the UID registry gap

Reviewer flagged (from memory — **must be checked against the actual PS3.5 2026a table before
acting**) that the following may be missing from `from(uid:)` / `allKnown`:

- Encapsulated Uncompressed Explicit VR LE — `1.2.840.10008.1.2.1.98`
- JPIP HTJ2K Referenced / Deflated — `1.2.840.10008.1.2.4.204`, `.205`
- SMPTE ST 2110 — `1.2.840.10008.1.2.7.x`
- Deflated Image Frame Compression — `1.2.840.10008.1.2.8.1`

This file is legitimately in-scope for an edition citation — it is the DICOM-facing UID registry
boundary, not codec math. Once verified, either add the missing syntaxes or correct the file's
"Supplement 232, DICOM 2024d" citation to reflect what it actually implements.

### P3 — `PhotometricInterpretation.swift`: add `XYB`

Missing the `XYB` defined term, which shipped with the same Supplement 232 / JPEG XL work that
`TransferSyntax.swift` and `JXLCodec.swift` already claim to support. Internally inconsistent within
the module: a JPEG XL frame using XYB color cannot be correctly labeled today.

### P4 — `VR.swift`: fix the edition citation — **DONE 2026-09-24**

The 2026d edition is real: NEMA released it on 2026-09-21, so the edition citation is valid and was
kept. The CP citation was wrong. The file credited OV/SV/UV to CP-1818, which is actually the
Extended Offset Table CP. NEMA's 2019a release notes show the 64-bit VRs came from **CP 1819, "Add
64 bit binary VRs"**. The file now cites CP 1819. See Bucket B1 below.

### P5 — Stale defined-term lists

- **`CharacterSetHandler.swift:313-351`** — missing GB18030, GBK, ISO_IR 203 (Latin-9), ISO 2022 IR
  58. Affects real-world files from regional PACS deployments using these character sets.
- **`DirectoryRecord.swift:9-126`** — 39 record types; missing PLAN, TRACT, ASSESSMENT,
  RADIOTHERAPY, ANNOTATION, INVENTORY (roughly a mid-2010s snapshot).
- **`DICOMDirectory.swift:9-33`** — media application profile names appear wrong (e.g. "STD-GEN-DVD"
  vs. the real "STD-GEN-DVD-JPEG"); BD (Blu-ray) profiles absent entirely.

### P6 — Structured Reporting data-integrity bugs

Not edition drift — internally contradictory data that will produce wrong output regardless of
which edition is targeted. Recommend fixing before P5, since these actively corrupt SR documents
that exercise the affected codes:

- **`StructuredReporting/DICOMCode.swift`** — duplicate code values with conflicting meanings:
  `121060` ("Report" at :64 vs. "Clinical History" at :103), `121401` ("Mean Value" at :213 vs.
  "Derivation" at :245), `126000` ("Basic Diagnostic Imaging Report" at :337 vs. "Measurement
  Report"). Line 285 uses a UMLS identifier (`C0034375`) where a DCM code belongs.
- **`StructuredReporting/ContextGroup.swift`** — CID 6147 (:211-216) and CID 7021 (:232-235) both
  reuse the DCM code range 126000–126005 with different meanings. CID 218 (:126-130) and CID 6051
  (:315-317) use legacy SNOMED-RT (SRT) codes where current DICOM expects SNOMED CT (SCT) — predates
  the ~2017–2019 terminology switch.
- **`StructuredReporting/SRDocumentType.swift`** vs. **`DICOMCode.swift`** — inconsistent with each
  other: `DICOMCode.swift:342` defines the Procedure Log Storage code, but `SRDocumentType.swift`
  (18 SR SOP classes, :13-143) lacks the corresponding SOP class.
- **`StructuredReporting/ContentItem.swift`** — :69 allows `POLYGON` as a 2D SCOORD graphic type
  (should be SCOORD3D-only, per reviewer recollection); :135-147 is missing the `MULTISEGMENT` TCOORD
  range type.

### P7 — JPEG XL: one fragment per frame (Bucket C2)

PS3.5 2026a §A.4.12 says "each Frame shall be encoded separately as a single Fragment". The Bucket B1 files do not enforce this; the encapsulation code does. That code is `EncapsulatedPixelData.swift`, `DICOMWriter.swift` and the fragment-level JPEG XL recompression path in `TransferSyntaxConverter.swift`, all in Bucket C2. When auditing C2:
1. Confirm that each JPEG XL frame (.110, .111, .112) is written as exactly one fragment and never split.
2. Add a multi-frame test that checks the fragment count equals the frame count.

### Explicitly out of scope — do not chase

Codec wrapper files (`HTJ2KCodec`, `J2KSwiftCodec`, `JLICodec`, `JPEGLSCodec`,
`NativeJPEG2000Codec`, `NativeJPEGCodec`, `RLECodec`) and all Bucket C1/C2 plumbing files below.
Adding DICOM edition labels to these would be noise: the algorithms they wrap are ISO/IEC/ITU-T
territory, not DICOM's.

---

## Deferred findings — outside DICOMCore

**Decision (2026-09-24):** bugs found in other modules while auditing DICOMCore are recorded here, not fixed now. Each one is fixed when its module is audited. When starting a module, work through its rows first, then mark each one ✅ with the date and commit.

| ID | Module | Location | Problem | Standard (2026a) | Severity | Status |
|---|---|---|---|---|---|---|
| D1 | DICOMNetwork | [QueryService.swift:1000](Sources/DICOMNetwork/QueryService.swift#L1000) `VR.uses4ByteLength` | A second copy of `VR.uses32BitLength` that omits OV, SV and UV. The Explicit VR encode and parse code in Query, Retrieve, Storage, MPPS, Modality Worklist and Storage Commitment calls it, so an SV or UV element gets a 2-byte length header and is corrupted on the wire. Fix: return `uses32BitLength`, and delete the duplicate if possible. | PS3.5 §7.1.2, Tables 7.1-1 and 7.1-2 | **High:** data corruption on the wire. Rare in practice, since SV/UV mostly appear in Hanging Protocol selectors and a few UV counters | ⏳ Open |
| D2 | DICOMWeb | [DICOMJSONEncoder.swift](Sources/DICOMWeb/DICOMJSONEncoder.swift) `encodeValue`, `encodeBulkData`; matching [DICOMJSONDecoder.swift](Sources/DICOMWeb/DICOMJSONDecoder.swift) `decodeValue` | `InlineBinary` and `BulkDataURI` are placed inside the `Value` array (`"Value": [{"InlineBinary": …}]`) instead of as sibling keys of `vr`. DICOMKit round-trips with itself but not with other DICOMweb servers. Affects OB, OD, OF, OL, OV, OW and UN. Fixing it also means updating `DICOMJSONEncoderTests.testEncodeInlineBinary` and `DICOMJSON64BitVRTests.testEncodeOVInlineBinary`, which assert the current layout. | PS3.18 §F.2.2 ("At most one of: Value / BulkDataURI / InlineBinary") | **Medium:** interoperability | ⏳ Open |
| D3 | DICOMWeb | [DICOMJSONEncoder.swift](Sources/DICOMWeb/DICOMJSONEncoder.swift) `encodeNumericValues`, case `.AT` | AT is read with `uint32Values`, which returns nil for VR AT, so it falls through to the string fallback and emits garbage. Fix: use `attributeTagValues` and format each value as `%04X%04X`. | PS3.18 Table F.2.3-1 (AT is a String) | **Medium** | ⏳ Open |
| D4 | DICOMWeb | [DICOMXMLEncoder.swift:233](Sources/DICOMWeb/DICOMXMLEncoder.swift#L233) `isBinaryVR` | Omits OV. SV and UV numeric handling in the XML encoder has not been checked either. | PS3.19 Native DICOM Model; PS3.5 Table 6.2-1 | Low | ⏳ Open |
| D5 | DICOMStudio, DICOMKit | [DICOMInspectorView.swift:41](Sources/DICOMStudio/Views/DICOMInspectorView.swift#L41), [ComparisonReport.swift:169](Sources/DICOMKit/Comparison/ComparisonReport.swift#L169) | The "is binary" checks omit OV, so OV values are shown as text. | PS3.5 Table 6.2-1 | Low: display only | ⏳ Open |
| D6 | DICOMDictionary | [DataElementDictionary.txt](Sources/DICOMDictionary/Resources/DataElementDictionary.txt) | The VR and VM columns have not been text-diffed. Only (0020,9170)–(9172) were checked, during B1. Run the full PS3.6 Table 6-1 diff. | PS3.6 Table 6-1 | Audit task | ⏳ Open |
| D7 | DICOMDictionary tests | [DictionaryTests.swift:59](Tests/DICOMDictionaryTests/DictionaryTests.swift#L59) | The test is labelled "CP-1818 elements", which fits only the Extended Offset Table rows. The (0072,008x) and (0008,04xx) rows come from CP 1819. | Release notes 2019a | Low: label | ⏳ Open |
| D8 | Repo docs | [CHANGELOG.md:191](CHANGELOG.md#L191) (2.2.16 entry) | Credits the 64-bit VRs to CP-1818; the correct CP is 1819. That entry is already released, so add an erratum note rather than rewriting it. | Release notes 2019a | Low: docs | ⏳ Open |
| D9 | DICOMStudio, dicom-compress | [J2KTestBenchModels.swift:123,392](Sources/DICOMStudio/Models/J2KTestBenchModels.swift#L123), [dicom-compress/main.swift:62](Sources/dicom-compress/main.swift#L62) | Still call .4.110 "JPEG XL Lossless Only". The PS3.6 name is "JPEG XL Lossless". Leave the `jpeg-xl-lossless-only` flag alias alone. | PS3.6 Table A-1 | Low: text | ⏳ Open |

---

## Bucket A — Implements DICOM 2026a (6 files)

**Status: ✅ COMPLETE (2026-09-24).** All 6 files were compared row by row with the frozen NEMA 2026a text, and all match. Each file carries a "text-diffed" `NEMA-verified` marker.

| File | Where the marker is |
|---|---|
| Modality.swift | Doc comment on `currentEntries` |
| ModalityOptionValidator.swift | Doc comment on `listing()` |
| DICOMWellKnownPalettes.swift | File header comment |
| PseudoColorPalette.swift | Doc comment on `provenance` |
| WindowSettings.swift | Doc comment on `VOILUTFunction` |
| RelationshipType.swift | File header doc comment |

**Open item: DICOMWellKnownPalettes.swift has no generator.** Its header says it is generated and must not be hand-edited, but the repo contains no generator script. Its marker is therefore in the header comment. If a generator is added later, move the marker, including the half-to-even rounding note, into the generator.

The palette RGB values were compared as part of Stage 3 below.

### Stage 1: Internal consistency (source data)

| File | What was checked | Result |
|---|---|---|
| [Modality.swift](Sources/DICOMCore/Modality.swift) | Parsed the `currentEntries` and `retiredEntries` arrays directly | 79 current Defined Terms, plus SC and VL (recognized but not offered), plus 18 retired. No duplicates, and no overlap between current and retired. Matches `ModalityTests.swift:93` (`allCases.count == 79`) and `:107` (`allIncludingRetired.count == 99`). |
| [ModalityOptionValidator.swift](Sources/DICOMCore/ModalityOptionValidator.swift) | Whether it keeps its own list | It keeps none. Every lookup (:72, :95, :184) goes through `Modality.normalized`, `.allCases` or `.groupedByCategory`, so it cannot drift from Modality.swift. |
| [DICOMWellKnownPalettes.swift](Sources/DICOMCore/DICOMWellKnownPalettes.swift) | Palette labels and UIDs | All 8 are present: HOT_IRON, PET, HOT_METAL_BLUE, PET_20_STEP, SPRING, SUMMER, FALL, WINTER (`1.2.840.10008.1.5.1`–`.5.8`). |
| [PseudoColorPalette.swift](Sources/DICOMCore/PseudoColorPalette.swift) | Cross-checked against DICOMWellKnownPalettes.swift (:188-202) | Labels and UIDs are identical in both files. |
| [WindowSettings.swift](Sources/DICOMCore/WindowSettings.swift) | VOI LUT Function cases (:112-120) | LINEAR, LINEAR_EXACT and SIGMOID. This is the complete PS3.3 C.11.2.1.3 set. |
| [StructuredReporting/RelationshipType.swift](Sources/DICOMCore/StructuredReporting/RelationshipType.swift) | Relationship Type cases (:16-46) | All 7 are present: CONTAINS, HAS PROPERTIES, HAS OBS CONTEXT, HAS ACQ CONTEXT, HAS CONCEPT MOD, INFERRED FROM, SELECTED FROM. |

### Stage 2: NEMA 2026a release notes

Source: `releasenotes_2026a.xml`, published 2026-02-02, which lists changes relative to 2025e.

2026a applied 10 CPs and no Supplements, in these parts:

| Part | CPs |
|---|---|
| PS3.3 | 1982, 2516, 2528, 2531, 2535 |
| PS3.4 | 1982, 2500, 2528 |
| PS3.5 | *none* |
| PS3.6 | spelling of (0014,6051), 1982, 2163, 2531, 2535 |
| PS3.16 | TID 10003B reference fix, 1982, 2163, 2531, 2535 |
| PS3.17 | Global Crop attribute, 1982 |
| PS3.18 | 2395, 2473 |

The CP titles:
- CP 1982: sensitive images
- CP 2163: audit destinations
- CP 2395: UPS-RS Requesting AE
- CP 2473: zero-result search response
- CP 2500: Final State requirement
- CP 2516: RT Beams Delivery Instructions
- CP 2528: MPPS protocol code attributes
- CP 2531: Exposure Modulation Type
- CP 2535: RT Dose Type terms

None of them touches the Modality Defined Terms (C.7.3.1.1.1, CID 29/32), the Well-Known Color Palettes (PS3.6 Annex B), VOI LUT Function (C.11.2.1.3) or SR Relationship Types.

### Stage 3: Row-by-row text diff against NEMA 2026a — ✅ complete

Source: the frozen 2026a DocBook files at `https://dicom.nema.org/medical/dicom/2026a/source/docbook/`. Each file's subtitle reads "DICOM PS3.x 2026a". Every table was extracted by script and compared entry by entry with the code. Zero-width spaces were stripped first.

| File | Compared against (2026a) | Result |
|---|---|---|
| Modality.swift | PS3.3 C.7.3.1.1.1 "Defined Terms" (79) and "Retired Defined Terms" (18) | ✅ Both sets match code for code. None missing, none extra. SC and VL are absent from the standard, and the code already treats them as non-standard. |
| Modality.swift | PS3.16 CID 29 Acquisition Modality (43) and CID 32 Non-Acquisition Modality (23) | ✅ Every CID code is present. The code has 13 more (ANN, ECG, EEG, EMG, EOG, EPS, HD, POS, RESP, RTINTENT, RTRAD, RTSEGANN, XAPROTOCOL). All 13 are PS3.3 Defined Terms, and the CIDs are subsets, so this is correct. CID 33 is built from other groups and has no literal rows. |
| ModalityOptionValidator.swift | — | ✅ Holds no data of its own; it inherits the Modality.swift result. |
| DICOMWellKnownPalettes.swift | PS3.6 Annex B Tables B.1.N.2-1 (descriptor) and B.1.N.2-2 (data), for all 8 palettes | ✅ All 8 × 256 RGB entries match, and every descriptor is (256, 0, 8). Hot Iron, PET, Hot Metal Blue and PET 20 Step are compared directly. Spring, Summer, Fall and Winter are expanded from their segmented opcode streams (PS3.3 C.7.9.2) and then compared. |
| PseudoColorPalette.swift | PS3.6 Table B.1-1 | ✅ All 8 labels and UIDs match. |
| WindowSettings.swift | PS3.3 Tables C.11-2b and C.7.6.16-11, the (0028,1056) Defined Terms | ✅ LINEAR, LINEAR_EXACT and SIGMOID match exactly. |
| RelationshipType.swift | PS3.3 Table C.17.3-8 | ✅ All 7 values match exactly. Only the order differs, and order has no meaning here. |

**Findings from the text diff.** None of these affects conformance.

1. **Modality display names.** Six of the code's human-readable names are worded differently from the standard's. The codes themselves, which are what gets written to (0008,0060), all match.

   | Code | Code's name | 2026a name |
   |---|---|---|
   | HD | Hemodynamic Waveform | Hemodynamic |
   | PT | Positron Emission Tomography | Positron emission tomography (PET) |
   | RESP | Respiratory Waveform | Respiratory |
   | RF | Radiofluoroscopy | Radio Fluoroscopy |
   | RG | Radiographic Imaging | Radiographic imaging (conventional film/screen) |
   | ST (retired) | Single-Photon Emission Computed Tomography | Single-photon emission computed tomography (SPECT) |

   These names appear only in the UI. Aligning them with the standard is optional.

2. **Rounding in segmented palettes.** PS3.3 2026a §C.7.9.2.2 says only to connect a linear segment's endpoints "using a straight line". It does not say how to round. Summer entry 223 (blue) lands exactly on 190.5:
   - Round half to even gives 190. That is what the code has.
   - Round half up gives 191.

   Round half to even reproduces all four segmented palettes exactly. The choice is now recorded in the file's marker, so a future regeneration keeps it.

---

## Bucket B1 — Explicit citation to another edition, CP, or Supplement (4 files)

**Status: ✅ COMPLETE (2026-09-24).** All 4 files were compared row by row with the NEMA text, the same way as Bucket A Stage 3. All match. Each file carries a "text-diffed" `NEMA-verified` marker. The only code change is the .110 display string (finding 1).

| File | Cites | Where the marker is |
|---|---|---|
| [VR.swift](Sources/DICOMCore/VR.swift#L7) | PS3.5 2026d; CP 1819 (2019a) | Doc comment on `enum VR` |
| [TransferSyntax.swift](Sources/DICOMCore/TransferSyntax.swift#L301) (JPEG XL block only) | Sup 232 (2024d) | `// MARK: - JPEG XL Transfer Syntaxes` comment |
| [JXLCodec.swift](Sources/DICOMCore/JXLCodec.swift#L7) | Sup 232 (2024d) | Doc comment on `struct JXLCodec` |
| [Tag+MultiframeFunctionalGroups.swift](Sources/DICOMCore/Tag+MultiframeFunctionalGroups.swift#L117) (Sup 157 block only) | Sup 157 | `// MARK: - Legacy Converted Enhanced (Sup 157)` comment |

**Earlier pass (superseded).** The first B1 pass on 2026-09-24 relied on the release notes and on PS3.5/PS3.6 2026d. It corrected the `VR.swift` CP citation from CP-1818 to CP 1819. The text diff below confirms that correction and replaces the rest of that pass.

### Stage 3: Row-by-row text diff — ✅ complete

**Sources.**
- **2026a:** the frozen DocBook files at `https://dicom.nema.org/medical/dicom/2026a/source/docbook/` for PS3.3, PS3.5 and PS3.6. Each subtitle reads "DICOM PS3.x 2026a".
- **2026d:** NEMA has **not published a frozen 2026d copy**. `/2026d/source/docbook/part05/part05.xml` returns 404, and `/2026d/` is only a link to `/current/`. The 2026d check therefore used `/current/` PS3.5. Its subtitle reads "DICOM PS3.5 2026d" (checked 2026-09-24). Once `/2026d/` is published, re-check against it.
- **Release notes:** 2019a (CP 1819) and 2024d (Sup 232), both from the GitHub mirror.

Each table was extracted by script, with U+200B stripped, and compared entry by entry with the code.

| File | Compared against | Result |
|---|---|---|
| VR.swift | PS3.5 **2026a** and **2026d** Table 6.2-1 (34 rows) | ✅ The 34 cases match code for code in both editions: none missing, none extra, no duplicates. The case doc comments match the table's names. Table 6.2-1 is identical in the two editions. |
| VR.swift | PS3.5 **2026a** and **2026d** §7.1.2, Tables 7.1-1 and 7.1-2 | ✅ §7.1.2 and the caption of Table 7.1-2 give 21 VRs a 16-bit length: AE AS AT CS DA DS DT FL FD IS LO LT PN SH SL SS ST TM UI UL US. Every other VR has 2 reserved bytes and a 32-bit length (Table 7.1-1). That leaves 13 VRs: OB OD OF OL OV OW SQ SV UC UN UR UT UV, exactly the set in `uses32BitLength`. The text is the same in both editions. |
| VR.swift | Release notes 2019a | ✅ CP 1819 is "Add 64 bit binary VRs" and is listed under PS3.3 and PS3.5. CP 1818 is "Large compressed images may have more frames than fit in the Basic Offset Table" (PS3.3, PS3.5 and PS3.6). **CP 1819 is the right source for OV/SV/UV.** |
| TransferSyntax.swift | PS3.6 2026a Table A-1 | ✅ All three UIDs match on name, keyword and type: .4.110 is "JPEG XL Lossless" / `JPEGXLLossless`, .4.111 is "JPEG XL JPEG Recompression" / `JPEGXLJPEGRecompression`, and .4.112 is "JPEG XL" / `JPEGXL`. All three are of type Transfer Syntax, and none is retired. |
| TransferSyntax.swift | PS3.5 2026a §10.19 and §A.4.12 | ✅ Both sections are present: §10.19 "Transfer Syntaxes for Lossless and Lossy JPEG XL Compression" and §A.4.12 "JPEG XL Image Compression". §A.4.12 defines .110 as JPEG XL's lossless mode, .111 as reversible JPEG transcoding, and .112 as any JPEG XL mode (lossy, lossless or JPEG recompression). The code agrees: `isLossless` is true for .110 and .111, and `losslessCapability` is `.both` for .112. |
| TransferSyntax.swift | PS3.5 2026a §A.4 | ✅ Encapsulated syntaxes use Explicit VR and Little Endian, which matches `isExplicitVR: true`, `byteOrder: .littleEndian` and `isEncapsulated: true` on all three. |
| TransferSyntax.swift | PS3.3 2026a C.7.6.1.1.5 | ✅ `lossyImageCompressionMethod` for .112 is `ISO_18181_1`, which is a Defined Term for (0028,2114) ("JPEG XL Image Coding System - Part 1 Core Coding System"). |
| TransferSyntax.swift | Release notes 2024d | ✅ Sup 232 "JPEG XL Transfer Syntaxes" is listed. It is kept as provenance. |
| JXLCodec.swift | PS3.6 2026a Table A-1; PS3.5 2026a §10.19 and §A.4.12 | ✅ The same three UIDs, and the role given to each matches §A.4.12. Encoding only to .110 or .112, and never producing .111 from pixels, is consistent with .111 being defined as transcoding existing JPEG data (§10.19). |
| Tag+MultiframeFunctionalGroups.swift | PS3.6 2026a Table 6-1 | ✅ (0020,9170) Unassigned Shared Converted Attributes Sequence, (0020,9171) Unassigned Per-Frame Converted Attributes Sequence and (0020,9172) Conversion Source Attributes Sequence all match on name and keyword; the Swift property names are the keywords in lowerCamelCase. None is retired. VR SQ and VM 1 match `Sources/DICOMDictionary/Resources/DataElementDictionary.txt:1716-1718`. The Swift file itself holds only the tag and name. |

**Findings from the text diff.** No code values disagree with the standard. Findings 1 and 2 were fixed with approval.

1. **Display name for .4.110.** `TransferSyntax.swift:1024` returns "JPEG XL Lossless **Only**", but the PS3.6 2026a name is "JPEG XL Lossless". The JPEG 2000 and HTJ2K syntaxes really are named "... Lossless Only"; JPEG XL is not. This affects only the display string, not the UID. **Fixed 2026-09-24:** now returns "JPEG XL Lossless". No test asserted the old string. Comments in `DICOMStudio/Models/J2KTestBenchModels.swift:123,392` and the `dicom-compress/main.swift:62` help text still say "Lossless Only"; they are outside DICOMCore.
2. **The padding comment in JXLCodec is looser than the standard.** `JXLCodec.swift:236-237` says DICOM pads an odd-length fragment "with a trailing 0x00 byte (PS3.5 §A.4)". §A.4 only requires every fragment to have an even length and says the last fragment "may be padded". A single trailing NULL is specified only for deflate-based streams. Stripping one trailing 0x00 is still a reasonable way to tolerate that padding. Only the citation's wording is loose. **Fixed 2026-09-24:** the comment now states the §A.4 rule accurately. The behavior is unchanged.
3. **The earlier pass overstated the Sup 157 marker.** It said "VR (SQ) and VM (1) match" as if `Tag+MultiframeFunctionalGroups.swift` held that data. It doesn't; the VR and VM live in DICOMDictionary. The new marker says so.
4. **No frozen 2026d text.** See Sources above. The 2026d half of the VR.swift check rests on `/current/`, whose subtitle was confirmed as 2026d on 2026-09-24.
5. **Not covered.** §A.4.12 requires that "each Frame shall be encoded separately as a single Fragment". That is enforced in the encapsulation and writer code, not in these four files, so it was not checked here.

Out of scope for DICOMCore: the CP-1818 mislabels in `CHANGELOG.md` and `DictionaryTests.swift`, the unaudited VR and VM columns of the dictionary, and the leftover "Lossless Only" strings. These are deferred as D6–D9 in [Deferred findings](#deferred-findings--outside-dicomcore).

---

## Bucket B2 — No citation, data doesn't match 2026a (10 files)

| File | Gap |
|---|---|
| [PhotometricInterpretation.swift:9-47](Sources/DICOMCore/PhotometricInterpretation.swift#L9) | Missing `XYB` — see P3. **Confirmed 2026-09-24 against 2026a:** XYB is a Defined Term in PS3.3 C.7.6.3.1.2. PS3.5 Table 8.2.15-1 allows it only with JPEG XL: .110/.112 (with RGB and YBR_RCT) and .111 (with RGB and YBR_FULL_422), always with Samples per Pixel 3 and Planar Configuration 0. The other 9 current terms match. HSV, ARGB, CMYK and YBR_PARTIAL_422 are retired; only YBR_PARTIAL_422 is in the enum, and it is documented as retired. ⏸ **Awaiting approval:** adding a case to a public enum breaks consumers' exhaustive switches. |
| [TransferSyntaxConverter.swift:1300](Sources/DICOMCore/TransferSyntaxConverter.swift#L1300) | ✅ **Fixed 2026-09-24:** OV/SV/UV are now byte-swapped per PS3.5 2026a §7.3. See P1 |
| [DataElement.swift:295-298,389-392](Sources/DICOMCore/DataElement.swift#L295) | ✅ **Fixed 2026-09-24:** UInt64/Int64 accessors added per PS3.5 2026a Table 6.2-1. See P1 |
| [CharacterSetHandler.swift:313-351](Sources/DICOMCore/CharacterSetHandler.swift#L313) | Missing GB18030, GBK, ISO_IR 203, ISO 2022 IR 58 — see P5 |
| [DirectoryRecord.swift:9-126](Sources/DICOMCore/DirectoryRecord.swift#L9) | Missing PLAN, TRACT, ASSESSMENT, RADIOTHERAPY, ANNOTATION, INVENTORY — see P5 |
| [DICOMDirectory.swift:9-33](Sources/DICOMCore/DICOMDirectory.swift#L9) | Wrong/incomplete media application profile names — see P5 |
| [StructuredReporting/SRDocumentType.swift:13-143](Sources/DICOMCore/StructuredReporting/SRDocumentType.swift#L13) | Missing Procedure Log Storage SOP class — see P6 |
| [StructuredReporting/ContextGroup.swift](Sources/DICOMCore/StructuredReporting/ContextGroup.swift) | Legacy SNOMED-RT codes; conflicting CID code reuse — see P6 |
| [StructuredReporting/DICOMCode.swift](Sources/DICOMCore/StructuredReporting/DICOMCode.swift) | Duplicate/conflicting code values, one UMLS ID mistaken for a DCM code — see P6 |
| [StructuredReporting/ContentItem.swift:69,135-147](Sources/DICOMCore/StructuredReporting/ContentItem.swift#L69) | POLYGON allowed on 2D SCOORD; TCOORD missing MULTISEGMENT — see P6 |

---

## Bucket C1 — Pure plumbing, no DICOM-derived data (25 files)

No DICOM standard data of any kind — endianness, generic codec backend selection, CLI wrapper
scaffolding, generic pixel-buffer math, generic error types.

AlignedPixelBuffer.swift, ByteOrder.swift, CLICodecSupport.swift, CodecBackend.swift,
ColorSampleLUT.swift, DjpegCLICodec.swift, DjxlCLICodec.swift, GrokCLICodec.swift,
KakaduCLICodec.swift, JPEGCodecEngine.swift, PixelInterleaveSupport.swift,
DataElement+NumericTolerant.swift, J2KRoutePlanner.swift, J2KCodestreamInspector.swift (implements
ISO/IEC 15444, not DICOM), JP3DCodec.swift (private non-DICOM UIDs), PerceptualColormaps.swift,
WindowLUT.swift, DICOMError.swift, PixelDataError.swift, PrivateTag/PrivateTagDictionary.swift,
PrivateTag/SiemensCSAHeaderParser.swift, UIDGenerator.swift, StructuredReporting/SRTemplate.swift,
StructuredReporting/SRTemplateValidator.swift, StructuredReporting/AnyContentItem.swift.

---

## Bucket C2 — Standard-derived, edition-stable (59 files)

Carries PS3.x data, but the data has not materially changed across recent DICOM editions, so no
edition label applies.

- **VR value types** (PS3.5 §6.2, unchanged for years): DICOMAgeString, DICOMApplicationEntity,
  DICOMCodeString, DICOMDate, DICOMDateTime, DICOMDecimalString, DICOMIntegerString,
  DICOMPersonName, DICOMTime, DICOMUniqueIdentifier, DICOMUniversalResource.
- **Encoding / pixel data**: DICOMWriter, SequenceItem (PS3.5 §7), EncapsulatedPixelData (PS3.5
  A.4), PixelData (PS3.5 §8.2), PixelDataDescriptor (PS3.3 C.7.6.3), PaletteColorLUT (PS3.3 C.7.9),
  RLECodec (PS3.5 Annex G).
- **Codecs, keyed to Transfer Syntax UIDs** (out of DICOM's jurisdiction per the scope note above):
  HTJ2KCodec, ImageCodec, J2KSwiftCodec, JLICodec, JPEGLSCodec, NativeJPEG2000Codec,
  NativeJPEGCodec.
- **Private tags** (PS3.5 §7.8): PrivateTag/PrivateCreator, PrivateTag/PrivateDataElement,
  PrivateTag/PrivateTagAllocator.
- **SR support types**: CodeMapper, CodingScheme, CodedConcept, ContentItemTypes,
  ContentItemValueType (15 value types — unverified whether 2026a adds more), LOINCCode, RadLexCode,
  SNOMEDCode (has one duplicate concept ID, `108369006` — worth a follow-up check), UCUMUnit,
  SRCoreTemplates, SRMeasurementTemplates.
- **Tags** — all 20 `Tag+*.swift` files plus `Tag.swift`, individually grepped, zero edition/CP/
  Supplement citations in any of them: Tag.swift, Tag+DICOMDIR, Tag+EncapsulatedDocument,
  Tag+FileMetaInformation, Tag+HangingProtocol, Tag+ImageInformation, Tag+ModalitySpecific,
  Tag+MultiframeFunctionalGroups (see B1 for its one Sup-157 mark), Tag+OverlayInformation,
  Tag+ParametricMap, Tag+PatientInformation, Tag+PixelData, Tag+PresentationState,
  Tag+RadiationTherapy, Tag+SecondaryCapture, Tag+Segmentation, Tag+SeriesInformation,
  Tag+StructuredReporting, Tag+StudyInformation, Tag+Video, Tag+Waveforms.

---

## Verification notes

Several findings in P2 and P6 are marked "from memory" by the reviewing pass — i.e. based on general
knowledge of the DICOM standard rather than a line the repo itself contains. Before acting on those
specific items (missing transfer syntax UIDs in P2; SCOORD/TCOORD rules in P6's ContentItem.swift
item), cross-check against the actual PS3.3/PS3.5 2026a text. Everything else in this report is
grounded directly in repo source (file:line cited throughout).

Buckets A and B1 have now been verified against NEMA sources (see their sections and the Progress
log). The "from memory" caveat still applies to the B2 items listed above, which have not been
verified yet.
