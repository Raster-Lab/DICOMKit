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
| B2 — Stale or incorrect, no citation | 10 | Data gap or bug relative to 2026a, undocumented | ✅ **Complete** — all 10 files text-diffed against 2026a and fixed (P1, P3, P5, P6) |
| C1 — Pure plumbing | 25 | No DICOM-standard data at all | ✅ **Complete** — 23 confirmed as plumbing and marked; 2 (`SRTemplate`, `PrivateTagDictionary`) turned out to carry data, were verified and fixed |
| C2 — Standard-derived, edition-stable | 59 | Carries PS3.x data that hasn't materially changed across recent editions | ✅ **Complete** — all 59 text-diffed against 2026a; 2 behaviour bugs, 1 heuristic and ~40 doc/data errors fixed; SR template structure deferred as P10 |

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
| 2026-09-24 | B2 / P3 | Adding XYB approved. Added `PhotometricInterpretation.xyb`, plus the RGB relabel after JPEG XL XYB decode in `TransferSyntaxConverter` (PS3.3 2026a C.7.6.3.1.2). 4 new tests; 7,284 Swift Testing tests plus all XCTest suites pass. CHANGELOG updated, which also resolves D8. Deferred D10–D12 added (DICOMStudio thumbnails and label, CompressionManager). |
| 2026-09-24 | B2 / P5 | `CharacterSetHandler.swift` text-diffed against PS3.3 2026a C.12-2 to C.12-5. Part 1 fixed the wrong decoders for 9 character sets and added the `ISO 2022 IR 6` alias, with 11 tests; DICOMCore, DICOMKit and DICOMWeb tests pass. Part 2 (4 new public enum cases) is paused for approval. |
| 2026-09-24 | B2 / P5 | Part 2 approved: added `isoIR203`, `isoIR58`, `gb18030` and `gbk`. The ISO 2022 engine was rewritten to follow PS3.5 §6.1.2.5.3, and it reproduces the Annex H and I examples byte for byte. An empty Value 1 is now kept. 29 new tests. DICOMCore, DICOMKit, DICOMWeb and DICOMNetwork tests pass, except 8 DICOMNetwork failures that already exist on HEAD (deferred as D13). **`CharacterSetHandler.swift` done.** |
| 2026-09-24 | B2 / P5 | `DirectoryRecord.swift` text-diffed against PS3.3 2026a Tables F.3-3 and F.4-1: 8 current record types are missing, and the hierarchy validation is too narrow. DICOMDIRReader's hard failure on unknown types is deferred as D14. Paused for approval because the fix adds public enum cases. |
| 2026-09-24 | B2 / P5 | Approved: added 7 current and 5 retired record types (PRIVATE was already present, so the earlier count of 8 is corrected to 7). `DICOMDirectory.validate` rewritten to follow Table F.4-1. DICOMCore, DICOMKit, tools and round-trip tests pass. **`DirectoryRecord.swift` done.** |
| 2026-09-24 | B2 / P5 | `DICOMDirectory.swift` (`DICOMDIRProfile`) text-diffed against PS3.11 2026a: 5 of 8 identifiers are not real profile IDs, and 61 of the 64 in 2026a are missing. Paused: the fix needs a public API design choice, because the Ultrasound identifiers are templated by media, which an enum cannot express. |
| 2026-09-25 | B2 / P5 | Approved: `DICOMDIRProfile` rewritten as a struct with all 64 PS3.11 2026a identifiers, generated from the extracted text. Old names deprecated, old strings still parse. 7,321 tests pass across DICOMCore, DICOMKit, tools, round-trip and DICOMStudio. Deferred D15 (CLI help text, reader default). **`DICOMDirectory.swift` done; P5 complete.** |
| 2026-09-25 | B2 / P6 | `SRDocumentType.swift` text-diffed against PS3.6 Table A-1 and PS3.3 A.35. 18 UIDs match; Procedure Log (P6) and Waveform Annotation SR are missing; 16 of 18 `allowedValueTypes` sets are wrong. Deferred D16 (duplicate rules in DICOMKit) and D17 (builders emit DATETIME where not permitted). Paused for approval. |
| 2026-09-25 | B2 / P6 | Approved (without the retired Trial classes): added `.procedureLog` and `.waveformAnnotationSR`, corrected all `allowedValueTypes` sets from PS3.3 A.35, and made `isSRDocument` recognise the Trial UIDs. TABLE deferred as P8. **`SRDocumentType.swift` done.** |
| 2026-09-25 | B2 / P6 | `ContextGroup.swift` text-diffed against PS3.16 2026a: 1 of 9 groups correct, 1 has wrong meanings, 7 carry the wrong CID number and mostly invented members. Paused: fixing it renames or removes public static groups. |
| 2026-09-25 | B2 / P6 | Option 1 approved: all 10 `ContextGroup` groups regenerated from PS3.16 2026a CID tables; 5 old names deprecated, `imagingObservations` removed. `ContextGroupTests` rewritten to assert the standard's rows. **`ContextGroup.swift` done.** |
| 2026-09-25 | B2 / P6 | `DICOMCode.swift` text-diffed against PS3.16 2026a Annex D: 29 of 93 codes correct, 18 renumberable, 13 are SCT/NCIt concepts a DCM-only type cannot hold, 7 are relationship types not codes, ~24 have no standard code. Paused: fixing it removes or renames public constants. |
| 2026-09-25 | B2 / P6 | Option 1 approved: 21 `DICOMCode` constants corrected, 43 removed as `unavailable` with the correct reference, `imagingMeasurementReport` added, tests assert every constant against Annex D. P9 logged. **`DICOMCode.swift` done.** |
| 2026-09-25 | B2 / P6 | `ContentItem.swift` text-diffed: POLYGON is not a 2D SCOORD type, MULTISEGMENT is missing from TCOORD, and `NumericValueQualifier` has 5 of 12 CID 42 values. Deferred D18 (builders write 2D POLYGON). Paused: the fix changes public enums. |
| 2026-09-25 | B2 / P6 | Approved: `multisegment` added, 2D `polygon` deprecated, `NumericValueQualifier` completed to CID 42 with codes. **`ContentItem.swift` done. Bucket B2 complete: 10 of 10.** |
| 2026-09-25 | C1 | Loop started. All 25 files read in full and grepped for UIDs, tag literals, VR names, defined terms and PS3 citations. 19 hold no standard data and got a "classification confirmed" marker. 4 more hold only citations or names, all checked against PS3.5/PS3.6/PS3.10 2026a and fixed where wrong: `ByteOrder.swift` cited §7.1.1/§7.1.2 for byte ordering (it is §7.3; Big Endian left PS3.5 in 2016b), `J2KCodestreamInspector.swift` cited A.4.6 for HTJ2K (A.4.4), `DICOMError.swift` had a "v0.1 supports…" comment, `PixelDataError.swift` listed JPEG-LS/HTJ2K as unsupported and hard-coded a stale "supported formats" sentence, now read from `CodecRegistry`. `UIDGenerator.swift` matches §9.1; 5 tests added. 2 files are **not** plumbing after all: `SRTemplate.swift` (requirement types and TID names disagree with PS3.16 2026a) and `PrivateTagDictionary.swift` (8 of 15 vendor entries disagree with the DCMTK and GDCM private dictionaries). Both fixes change public API, so the loop paused for approval. |
| 2026-09-25 | C1 | Approved: `SRTemplate.swift` requirement types aligned with PS3.16 §6.1.7 (U = User Option, UC added, C deprecated), TID constants corrected (320 → Image or Spatial Coordinates, Image Library Entry → 1601, 4000/4019 renamed), `TID320ImageLibraryEntry` renamed `TID1601ImageLibraryEntry`. `PrivateTagDictionary.swift`: 8 vendor entries corrected to DCMTK/GDCM values, 2 reference tests added. DICOMCore and DICOMKit test targets pass. **Bucket C1 complete: 25 of 25.** |
| 2026-09-25 | C2 | Loop started with the 21 Tag files. A script extracted all 971 `Tag` constants with their doc comments and compared each with PS3.6 2026a Tables 6-1, 7-1 and 8-1. Every tag exists and every (group, element) is right. 16 doc-level issues fixed: 5 retired elements now say so (incl. Ethnic Group, retired in 2025a), 4 wrong VR/VM notes, 3 wrong names, and 3 constants whose Swift name differs from the PS3.6 keyword now note the keyword. Markers on all 21 files. 3 possible renames recorded as an open question (Q1). |
| 2026-09-25 | C2 | VR value types (11 files) checked against PS3.5 2026a Table 6.2-1. All formats and limits match. `DICOMUniqueIdentifier.isSOPClass`/`isTransferSyntax` replaced by exact Table A-1 sets (311 SOP Classes, 63 Transfer Syntaxes): the old heuristic missed Verification and all Print classes and matched well-known instances. Read-side leniencies documented in the markers. 341 VR tests pass. |
| 2026-09-25 | C2 | Encoding / pixel data (7 files) checked against PS3.5 §6.2/7.1/7.5/8/A.4/Annex G and PS3.3 C.7.6.3. Two real bugs: Extended Offset Table offsets were treated as header-less (every conformant EOT failed closed), and the RLE encoder let runs cross rows (G.3.1). Both fixed with 6 new tests; citation fixes in PixelDataDescriptor and PaletteColorLUT. Deferred D19. |
| 2026-09-25 | C2 | Codecs (7 files): UIDs via `TransferSyntax`; `canEncode` limits checked against PS3.5 §8.2 tables (all subsets). Five wrong A.4 subsection citations fixed (HTJ2K in A.4.4, not A.4.6; JPEG in A.4.1; JPEG-LS in A.4.3). Markers on all 7. |
| 2026-09-25 | C2 | Private tags (3) and SR support (5): PS3.5 §7.8.1 rules match; `icd10CM`/`ICD10CM` designator corrected from "I10" (WHO ICD-10) to "I10C" per PS3.16 Table 8-1, `icd10` added, `acr` UID added; ContentItemTypes' 15 non-existent section citations replaced. |
| 2026-09-25 | C2 | External terminologies (4) checked against all 15,696 codes PS3.16 2026a uses: 4 wrong LOINC concepts corrected; SNOMED/UCUM mostly match; RadLex unverifiable. SR templates (2 files, 13 TIDs): 10 wrong concept codes corrected; row structures compared with the 2026a tables and found to diverge (30 of 142 standard rows present) — deferred as P10. DICOMCore and DICOMKit test targets pass. **Bucket C2 complete: 59 of 59. All 104 DICOMCore files verified against 2026a.** |

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

### P3 — `PhotometricInterpretation.swift`: add `XYB` — **DONE 2026-09-24**

Missing the `XYB` defined term, which shipped with the same Supplement 232 / JPEG XL work that
`TransferSyntax.swift` and `JXLCodec.swift` already claim to support. Internally inconsistent within
the module: a JPEG XL frame using XYB color cannot be correctly labeled today.

**Done:** `case xyb` was added, together with the RGB relabel on decode in `TransferSyntaxConverter`. Tests are in `PhotometricInterpretationTests` and `XYBTranscodeTests`. **Open question** (the standard is ambiguous): Table 8.2.15-1 allows XYB with .111 (JPEG Recompression). When .111 is unwrapped back to JPEG (`transcodeJXLRecompression`, reverse direction), which Photometric Interpretation the reconstructed JPEG should carry is not specified. That path is left unchanged.

### P4 — `VR.swift`: fix the edition citation — **DONE 2026-09-24**

The 2026d edition is real: NEMA released it on 2026-09-21, so the edition citation is valid and was
kept. The CP citation was wrong. The file credited OV/SV/UV to CP-1818, which is actually the
Extended Offset Table CP. NEMA's 2019a release notes show the 64-bit VRs came from **CP 1819, "Add
64 bit binary VRs"**. The file now cites CP 1819. See Bucket B1 below.

### P5 — Stale defined-term lists — **DONE 2026-09-25**

- **`CharacterSetHandler.swift:313-351`** — missing GB18030, GBK, ISO_IR 203 (Latin-9), ISO 2022 IR
  58. Affects real-world files from regional PACS deployments using these character sets.
  *Checked 2026-09-24 against 2026a:* confirmed. Also missing are ISO 2022 IR 203 and ISO 2022 IR 6, and 9 existing sets were being decoded with the wrong encoding (now fixed). See B2. **Fixed 2026-09-24:** all 20 Defined Terms, correct decoders, and ISO 2022 per PS3.5 §6.1.2.5.
- **`DirectoryRecord.swift:9-126`** — ✅ **Fixed 2026-09-24** (see B2). 39 record types; missing PLAN, TRACT, ASSESSMENT,
  RADIOTHERAPY, ANNOTATION, INVENTORY (roughly a mid-2010s snapshot).
- **`DICOMDirectory.swift:9-33`** — ✅ **Fixed 2026-09-25** (see B2). Media application profile names appear wrong (e.g. "STD-GEN-DVD"
  vs. the real "STD-GEN-DVD-JPEG"); BD (Blu-ray) profiles absent entirely.

### P6 — Structured Reporting data-integrity bugs — **DONE 2026-09-25**

Not edition drift — internally contradictory data that will produce wrong output regardless of
which edition is targeted. Recommend fixing before P5, since these actively corrupt SR documents
that exercise the affected codes:

- **`StructuredReporting/DICOMCode.swift`** — ✅ **Fixed 2026-09-25** (see B2). Duplicate code values with conflicting meanings:
  `121060` ("Report" at :64 vs. "Clinical History" at :103), `121401` ("Mean Value" at :213 vs.
  "Derivation" at :245), `126000` ("Basic Diagnostic Imaging Report" at :337 vs. "Measurement
  Report"). Line 285 uses a UMLS identifier (`C0034375`) where a DCM code belongs.
- **`StructuredReporting/ContextGroup.swift`** — ✅ **Fixed 2026-09-25** (see B2). CID 6147 (:211-216) and CID 7021 (:232-235) both
  reuse the DCM code range 126000–126005 with different meanings. CID 218 (:126-130) and CID 6051
  (:315-317) use legacy SNOMED-RT (SRT) codes where current DICOM expects SNOMED CT (SCT) — predates
  the ~2017–2019 terminology switch.
- **`StructuredReporting/SRDocumentType.swift`** — ✅ **Fixed 2026-09-25** (see B2). vs. **`DICOMCode.swift`** — inconsistent with each
  other: `DICOMCode.swift:342` defines the Procedure Log Storage code, but `SRDocumentType.swift`
  (18 SR SOP classes, :13-143) lacks the corresponding SOP class.
- **`StructuredReporting/ContentItem.swift`** — ✅ **Fixed 2026-09-25** (see B2). :69 allows `POLYGON` as a 2D SCOORD graphic type
  (should be SCOORD3D-only, per reviewer recollection); :135-147 is missing the `MULTISEGMENT` TCOORD
  range type.

### P7 — JPEG XL: one fragment per frame (Bucket C2)

PS3.5 2026a §A.4.12 says "each Frame shall be encoded separately as a single Fragment". The Bucket B1 files do not enforce this; the encapsulation code does. That code is `EncapsulatedPixelData.swift`, `DICOMWriter.swift` and the fragment-level JPEG XL recompression path in `TransferSyntaxConverter.swift`, all in Bucket C2. When auditing C2:
1. Confirm that each JPEG XL frame (.110, .111, .112) is written as exactly one fragment and never split.
2. Add a multi-frame test that checks the fragment count equals the frame count.

### P8 — TABLE Value Type (Bucket B2 follow-up)

PS3.3 2026a Table C.17.3-7 defines the TABLE Value Type, and two SR IODs permit it: Extensible SR (A.35.15) and Enhanced X-Ray Radiation Dose SR (A.35.22). `ContentItemValueType` has no `.table` case, so `SRDocumentType.allowedValueTypes` omits it for those two IODs, and a TABLE content item cannot be parsed or written. Adding the case breaks 6 exhaustive switches in DICOMCore (`ContentItemValueType.swift`, `AnyContentItem.swift`) and 2 in DICOMKit (`SRDocumentSerializer.swift:402`, `SRDocumentParser.swift:236`), and needs a TABLE content-item type behind it. Do this as one feature, then remove the "omitted until P8" notes in `SRDocumentType.allowedValueTypes`.

### P9 — A code type for non-DCM measurement concepts (Bucket B2 follow-up)

`DICOMCode` is DCM-only, so the SNOMED measurement concepts the SR builders need (Diameter 81827009, Long Axis 103339001, Short Axis 103340004, Area 42798000, Volume 118565006, Length 410668003, Width 103355008, Circumference 74551000, Perimeter 131191004, Perpendicular Axis 131189007, Mode 373100007, No change 260388006) have no home now that their invented DCM constants are removed. Add either an `SCTCode` type or a scheme-agnostic `WellKnownCodes` namespace of `CodedConcept` constants, generated from the PS3.16 CID tables, and have the DICOMKit builders use it.

### P10 — Rebuild the SR templates from the PS3.16 2026a TID tables (Bucket C2 follow-up)

`SRCoreTemplates.swift` and `SRMeasurementTemplates.swift` define 13 `SRTemplate` types whose rows were written from memory. Compared row by row with the 2026a tables (relationship, value type, concept, requirement): 30 of the 142 standard rows have a counterpart, 77 Swift rows have none, and every template except TID 1204 omits its INCLUDE rows (TID 300D, 301, 310, 315, 1000, 1003–1006, 1015, 1502, 1602, 4019, 4108 are not modelled at all). The concept codes were corrected on 2026-09-25; the structures were not, because the fix is a public-API redesign (new template types for the sub-templates, `$parameter` support in `TemplateRow`, `R-` by-reference relationships). Generate the rows from the DocBook TID tables, as `ContextGroup` and `DICOMCode` were.

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
| D8 | Repo docs | [CHANGELOG.md:191](CHANGELOG.md#L191) (2.2.16 entry) | Credits the 64-bit VRs to CP-1818; the correct CP is 1819. That entry is already released, so add an erratum note rather than rewriting it. | Release notes 2019a | Low: docs | ✅ Done 2026-09-24: erratum added to `[Unreleased]` in CHANGELOG |
| D9 | DICOMStudio, dicom-compress | [J2KTestBenchModels.swift:123,392](Sources/DICOMStudio/Models/J2KTestBenchModels.swift#L123), [dicom-compress/main.swift:62](Sources/dicom-compress/main.swift#L62) | Still call .4.110 "JPEG XL Lossless Only". The PS3.6 name is "JPEG XL Lossless". Leave the `jpeg-xl-lossless-only` flag alias alone. | PS3.6 Table A-1 | Low: text | ⏳ Open |
| D10 | DICOMStudio | [ThumbnailHelpers.swift:107](Sources/DICOMStudio/Components/ThumbnailHelpers.swift#L107) `supportedPhotometricInterpretations` | Omits XYB, YBR_PARTIAL_420, YBR_ICT and YBR_RCT, so those files get no thumbnail. Consider building the list from `PhotometricInterpretation` instead of hard-coded strings. | PS3.3 C.7.6.3.1.2 | Medium: user-visible | ⏳ Open |
| D11 | DICOMStudio | [ImageMetadataHelpers.swift:62](Sources/DICOMStudio/Components/ImageMetadataHelpers.swift#L62) `photometricLabel` | No label for XYB, so the raw "XYB" is shown. Add something like "XYB (JPEG XL)". | PS3.3 C.7.6.3.1.2 | Low: display | ⏳ Open |
| D12 | DICOMKit | [CompressionManager.swift:669](Sources/DICOMKit/Compression/CompressionManager.swift#L669) | Relabels JPEG Baseline YBR to RGB after decode, but not JPEG XL XYB. It should match `TransferSyntaxConverter`, which now does. Also, [:734](Sources/DICOMKit/Compression/CompressionManager.swift#L734) treats unknown values as RGB when Samples per Pixel is 3; XYB is now known, so check that path too. | PS3.3 C.7.6.3.1.2 | Medium: a mislabelled output file | ⏳ Open |
| D13 | DICOMNetwork tests | `MPPSDataSetConformanceTests` (2), `MWLKeySetConformanceTests`, `QueryIdentifierCharacterSetTests` (2), `RetrieveConformanceTests`, `StorageCommitmentConformanceTests` (2) | 8 XCTest failures that also fail on HEAD without this work, confirmed 2026-09-24 by stashing it. Six are off-by-one value-padding assertions: UTF-8 or ASCII values arrive with one byte more or less than the test expects, so either the even-length padding in identifier building or the test expectations are wrong. Two are Storage Commitment loopback tests that hit the ARTIM timeout. | PS3.5 §6.2 (even-length padding); PS3.8 ARTIM | Medium: the test suite is red | ⏳ Open |
| D14 | DICOMKit | [DICOMDIRReader.swift:186](Sources/DICOMKit/DICOMDIRReader.swift#L186) `parseDirectoryRecord` | Throws "Missing or invalid Directory Record Type" for any (0004,1430) value that `DirectoryRecordType` doesn't know, so a DICOMDIR containing one such record cannot be opened. It should keep or skip unknown and private records. Adding the missing cases in DICOMCore reduces the problem but doesn't remove it: vendors write private types too. | PS3.3 Table F.3-3, F.4-1 | **High:** a valid DICOMDIR fails to open | ⏳ Open |
| D15 | dicom-dcmdir, DICOMStudio, DICOMKit | [main.swift:58,103](Sources/dicom-dcmdir/main.swift#L58), [CLIWorkshopViewModel.swift:1730](Sources/DICOMStudio/ViewModels/CLIWorkshopViewModel.swift#L1730), [DICOMDIRReader.swift:60](Sources/DICOMKit/DICOMDIRReader.swift#L60) | The `--profile` help and error text still list `STD-GEN-DVD` and `STD-GEN-USB`, which are not PS3.11 identifiers (they still parse, as deprecated aliases). `DICOMDIRReader` always reports `.standardGeneralCD` regardless of content; since no attribute carries the profile, it should probably report `.none` or be documented as an assumption. `DcmdirRoundTripTests` and `DICOMDcmdirTests` use the deprecated names. | PS3.11 2026a | Low: text and metadata | ⏳ Open |
| D16 | DICOMKit | [SRDocumentBuilder.swift:920-953](Sources/DICOMKit/StructuredReporting/SRDocumentBuilder.swift#L920) `SRDocumentType.allowsValueType(_:)` | A second, conflicting copy of the value-type rules, defined as an extension in DICOMKit next to DICOMCore's `allows(_:)`. It disagrees with both DICOMCore and PS3.3 (e.g. it denies IMAGE and COMPOSITE for Basic Text SR, and allows everything for the CAD SRs). Delete it and call `allows(_:)`. | PS3.3 A.35 | Medium: two sources of truth | ⏳ Open |
| D17 | DICOMKit | [MammographyCADSRBuilder.swift](Sources/DICOMKit/StructuredReporting/MammographyCADSRBuilder.swift), [KeyObjectSelectionBuilder.swift](Sources/DICOMKit/StructuredReporting/KeyObjectSelectionBuilder.swift) | Both emit DATETIME content items. PS3.3 A.35.5 (Mammography CAD SR) and A.35.4 (Key Object Selection) do not list DATETIME among the permitted Value Types. Check whether the items are really DATETIME (Mammography CAD SR allows DATE and TIME separately) and correct the builders. Once DICOMCore's sets are corrected, `validateOnBuild` will flag these. | PS3.3 A.35.4, A.35.5 | Medium: non-conformant output | ⏳ Open |
| D18 | DICOMKit | [ComprehensiveSRBuilder.swift:540,1268](Sources/DICOMKit/StructuredReporting/ComprehensiveSRBuilder.swift#L540) | Emit 2D SCOORD content items with Graphic Type POLYGON, which PS3.3 C.18.6.1.2 does not define for SCOORD (only SCOORD3D has POLYGON). Write a closed POLYLINE (first vertex repeated last) instead. `MeasurementExtractorTests`, `ComprehensiveSRBuilderTests` and `SRHelpersTests` build the same non-conformant items. | PS3.3 C.18.6.1.2 | Medium: non-conformant output | ⏳ Open |
| D19 | DICOMKit | `DICOMFile+FrameAccess.swift:187` says "the OV VR is not yet in the `VR` enum, so explicit-VR files carry this element as UN". OV has been in `VR` since P1 (2026-09-24); the comment is stale, and the reader should now expect `.OV`. Low. | Open |

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
| [PhotometricInterpretation.swift](Sources/DICOMCore/PhotometricInterpretation.swift#L1) | ✅ **Fixed 2026-09-24.** Text-diffed against PS3.3 2026a C.7.6.3.1.2 and PS3.5 2026a Table 8.2.15-1. Added `case xyb`, which has 3 samples per pixel and is not YBR. `TransferSyntaxConverter` now relabels a decoded JPEG XL XYB dataset to RGB, as PS3.3 requires; before, it also read XYB as MONOCHROME2. Adding the case was approved as a public API change and is noted in the CHANGELOG. The other 9 current terms match. See P3 |
| [TransferSyntaxConverter.swift:1300](Sources/DICOMCore/TransferSyntaxConverter.swift#L1300) | ✅ **Fixed 2026-09-24:** OV/SV/UV are now byte-swapped per PS3.5 2026a §7.3. See P1 |
| [DataElement.swift:295-298,389-392](Sources/DICOMCore/DataElement.swift#L295) | ✅ **Fixed 2026-09-24:** UInt64/Int64 accessors added per PS3.5 2026a Table 6.2-1. See P1 |
| [CharacterSetHandler.swift](Sources/DICOMCore/CharacterSetHandler.swift#L1) | ✅ **Fixed 2026-09-24.** Text-diffed against PS3.3 2026a Tables C.12-2 to C.12-5 (20 Defined Terms, and every escape sequence byte for byte) and PS3.5 2026a §6.1.2.5.3. (1) 9 character sets were decoded with the wrong encoding; each now uses its ISO 8859 part, EUC-KR or TIS-620. (2) Added `isoIR203`, `isoIR58`, `gb18030` and `gbk` and their escapes; this public API change was approved. (3) The ISO 2022 engine was rewritten: G0 in GL and G1 in GR, Value 1 restored after control characters, unknown escapes skipped, JIS X 0212 decoded through ISO-2022-JP-1, and the encoder designates sets only when needed and restores Value 1 before delimiters and at the end. (4) An empty Value 1 is kept (PS3.3 C.12.1.1.2); before, it was dropped. Decoding and encoding reproduce PS3.5 Annex H.3.1, H.3.2 and I.2 byte for byte. 29 new tests. One legacy test, which asserted non-standard output for an invalid IR 87 Value 1, was corrected. See P5 |
| [DirectoryRecord.swift](Sources/DICOMCore/DirectoryRecord.swift#L1) | ✅ **Fixed 2026-09-24.** Text-diffed against PS3.3 2026a Table F.3-3 (the (0004,1430) Enumerated Values) and Table F.4-1 (hierarchy). **P5 is confirmed:** 7 current values were missing (PLAN, TRACT, ASSESSMENT, RADIOTHERAPY, ANNOTATION, INVENTORY and WF PRESENTATION). The first pass also listed PRIVATE, which was wrong: it was already present as `` `private` ``. Added the 7 current values and the 5 missing retired ones (PRINT QUEUE, FILM SESSION, FILM BOX, IMAGE BOX, MRDR; approved). All 16 retired values are now labelled with the edition that retired them. `ROOT` is documented as an internal placeholder. `DICOMDirectory.validate` now follows Table F.4-1: 25 SERIES child types, 8 root-level types, PRIVATE allowed anywhere, and retired types tolerated. A scripted diff shows 35 of 35 current and 16 of 16 retired values present. 7 new test functions cover all 51 values. |
| [DICOMDirectory.swift](Sources/DICOMCore/DICOMDirectory.swift#L1) `DICOMDIRProfile` | ✅ **Fixed 2026-09-25.** Text-diffed against PS3.11 2026a Annexes A–N: 64 identifiers (58 fixed, 6 Ultrasound templates × 4 media classes from Table C.3-3). **P5 confirmed and understated:** only 3 of the enum's 8 values existed; STD-GEN-DVD/-USB/-SEC were incomplete names, STD-CTMR-xxxx and STD-US-xxxx placeholders, and STD-MAM-xxxx does not exist. Approved change: `DICOMDIRProfile` is now a struct like `Modality`, with the 58 constants generated from the extracted PS3.11 text, `ultrasound(_:frames:media:)` for the 24 Ultrasound identifiers, `isStandard`, `isSecure`, and deprecated aliases for the 6 old names. `init(rawValue:)` still accepts the 5 old strings, so `dicom-dcmdir --profile` and DICOMStudio keep working. 8 new test functions; the constants are asserted equal to the standard's list. |
| [StructuredReporting/SRDocumentType.swift](Sources/DICOMCore/StructuredReporting/SRDocumentType.swift#L1) | ✅ **Fixed 2026-09-25.** Text-diffed against PS3.6 2026a Table A-1 (the 24 `…88.*` SOP Classes) and PS3.3 2026a A.35.1–A.35.23. All 18 existing UIDs and names match. **P6 confirmed:** Procedure Log (.88.40) was missing; Waveform Annotation SR (.88.77) was missing too. Both added (approved). The 4 retired "Trial" classes are recognised by `isSRDocument` only, by decision. **Larger finding:** `allowedValueTypes` was wrong for 16 of 18 types; all 20 sets are now generated from each IOD's Enumerated Values list and asserted equal to it in tests. **Scope note:** TABLE (permitted by Extensible SR and Enhanced X-Ray Dose SR) is omitted because `ContentItemValueType` has no case for it; adding one breaks 6 exhaustive switches in DICOMCore and 2 in DICOMKit and needs a TABLE content-item implementation. Logged as P8. Two DICOMKit tests (`EnhancedSRBuilderTests`) asserted that Enhanced SR rejects SCOORD and TCOORD; A.35.2 permits both, so the expectations were corrected. |
| [StructuredReporting/ContextGroup.swift](Sources/DICOMCore/StructuredReporting/ContextGroup.swift#L1) | ✅ **Fixed 2026-09-25 (option 1 approved).** Text-diffed against PS3.16 2026a, all CID tables by `xml:id`. Only CID 244 was right; CID 7021 had 2 wrong meanings; the other 7 carried the wrong CID number and mostly invented members (see the Progress log entry for the detail). All 10 groups are now generated from the PS3.16 tables with "Include CID" rows expanded, carrying the standard's name, Type, Version and members: 244, 7021, 3600 Relative Time, 4031 Common Anatomic Region (119), 6144 RECIST Defined Lesion Response, 7460/7461/7462 measurement units, 6054 Breast Imaging Finding (47), 3627 Measurement Type. Old names are deprecated aliases; `imagingObservations` is removed because PS3.16 has no such group. Tests assert each group equals the extracted standard rows. |
| [StructuredReporting/DICOMCode.swift](Sources/DICOMCore/StructuredReporting/DICOMCode.swift#L1) | ✅ **Fixed 2026-09-25 (option 1 approved).** Text-diffed against PS3.16 2026a Annex D Table D-1 (5,116 codes) and, for non-DCM meanings, every CID table. 29 of 93 were right. 21 corrected in place (18 renumbered, 2 capitalisation, `clinicalHistory` meaning "History"). 43 removed as `unavailable`, each message naming the correct SCT/NCIt code (13), `RelationshipType` (7), or stating that Annex D has no such DCM code (23). `imagingMeasurementReport` (126000) added. Only `DICOMCodeTests` used the constants; it now asserts every remaining constant's value and meaning against Annex D. The P6 duplicates (121060, 121401, 126000) are resolved by the removals. Follow-up P9: a code type for the SCT measurement concepts. |
| [StructuredReporting/ContentItem.swift](Sources/DICOMCore/StructuredReporting/ContentItem.swift#L1) | ✅ **Fixed 2026-09-25 (recommendation approved).** Text-diffed against PS3.3 2026a C.18.6.1.2, C.18.9.1.2, C.18.7.1.1, Table C.18.8-1 and PS3.16 CID 42 (with CIDs 43/44 expanded). **Both P6 claims confirmed.** `TemporalRangeType.multisegment` added. `GraphicType.polygon` deprecated (not a 2D SCOORD type; `allCases` now lists the 5 standard values). `NumericValueQualifier` completed to the 12 CID 42 values with `code` (DCM 114000-114011) and `init?(code:)`. `GraphicType3D` and `ContinuityOfContent` already matched. DICOMKit's mirror enum in `MeasurementExtractor` was extended with the 7 new cases so the package compiles (mapping only). D18 covers the builders that still write 2D POLYGON. |

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

### Verification — ✅ complete (25 of 25)

**Method.** The claim for this bucket is "no standard data", so the check is different from B2:
every file was read in full and grepped for UIDs (`1.2.840.10008`), tag literals, VR names,
defined terms and PS3.x citations. Where nothing turned up, the file gets a marker that says so
("C1 classification confirmed"). Where a citation or a name did turn up, it was checked against
the frozen 2026a DocBook text (PS3.3, PS3.5, PS3.6, PS3.10, PS3.16, all with the 2026a subtitle).
Vendor private-tag data is outside NEMA's scope and was checked against the DCMTK
(`dcmdata/data/private.dic`) and GDCM (`privatedicts.xml`) private dictionaries instead.

| File | Standard content found | Result |
|---|---|---|
| AlignedPixelBuffer, CodecBackend, ColorSampleLUT, WindowLUT, PerceptualColormaps, DataElement+NumericTolerant | None | ✅ Classification confirmed; marker added. |
| CLICodecSupport, DjpegCLICodec, DjxlCLICodec, GrokCLICodec, KakaduCLICodec | None beyond Planar Configuration 0/1 sample order | ✅ Matches PS3.3 2026a C.7.6.3.1.3 (0 = colour-by-pixel, 1 = colour-by-plane). Markers added. |
| PixelInterleaveSupport | Planar Configuration 0/1 | ✅ Same check; marker added. |
| JPEGCodecEngine | Names of the four JPEG syntaxes (.50, .51, .57, .70) | ✅ Match PS3.6 2026a Table A-1. Marker added. |
| J2KRoutePlanner | UID family grouping (.90/.91, .92/.93, .201/.202/.203) and the .202 RPCL note | ✅ Match PS3.6 2026a Table A-1 and PS3.5 2026a A.4.4. Marker added. |
| J2KCodestreamInspector | ISO/IEC 15444 marker codes (out of DICOM scope); one PS3.5 citation | ⚠️ Fixed: it cited "A.4.6" for the HTJ2K syntaxes. In 2026a A.4.6 is MPEG-4 AVC/H.264 HP/L4.1; all five JPEG 2000 and HTJ2K syntaxes are defined in **A.4.4**. Marker added. |
| JP3DCodec | Two private UIDs (1.2.826.0.1.3680043.10.511.x) | ✅ Not in PS3.6 Table A-1, as the file says. Marker added. |
| SiemensCSAHeaderParser, SRTemplateValidator | None | ✅ Classification confirmed; markers added. |
| AnyContentItem | The 15 wrapped value types | ✅ Match PS3.3 2026a Table C.17.3-7 except TABLE, already tracked as P8. Marker added. |
| ByteOrder | Section citations for byte ordering; the retired Big Endian syntax | ⚠️ Fixed: cited "§7.1.1 Little Endian Byte Ordering" and "§7.1.2 Big Endian Byte Ordering". In PS3.5 2026a those sections are "Data Element Fields" and "Data Element Structure with Explicit VR"; byte ordering is **§7.3**, and it says Big Endian "has been retired. See PS3.5 2016b." All 9 citations corrected. The readers themselves are right. Marker added. |
| DICOMError | PS3.10 §7.1 (preamble, DICM prefix) | ✅ §7.1 is "DICOM File Meta Information" in PS3.10 2026a. A stale "v0.1 supports Explicit/Implicit VR LE" comment was replaced. Marker added. |
| PixelDataError | Names of transfer syntaxes in comments and user-facing text | ⚠️ Fixed: the doc comment listed JPEG-LS, JPEG 2000 Part 2 and HTJ2K as "common unsupported" syntaxes (the module has codecs for all of them, and "HTJPEG 2000" is not the PS3.6 name), and `explanation` hard-coded a five-item "supported formats" sentence that omitted JPEG-LS, HTJ2K, JPEG XL and JP3D. The explanation now names the offending syntax from `TransferSyntax.displayName` and lists the decoders actually in `CodecRegistry`. 1 test added. Marker added. |
| UIDGenerator | PS3.5 §9 UID encoding rules | ✅ Generated UIDs satisfy every §9.1 rule (digit components, no leading zero except "0", "." separators, ≤ 64 characters) and pass `DICOMUniqueIdentifier.parse`. Noted: §9.2.2 requires a privately defined UID to use the organisation's own root, and the default root `1.2.276.0.7230010.3` is OFFIS DCMTK's; the doc comment now says so. 5 tests added. Marker added. |
| **SRTemplate** | `RequirementLevel` symbols; 15 named TIDs; three section citations | ⚠️ **Not plumbing; fixed with approval 2026-09-25.** PS3.16 2026a §6.1.7 defines four Requirement Type symbols: **M**, **MC**, **U** (User Option) and **UC** (User Option Conditional). The enum has `M`, `MC`, `U` (labelled "User Conditional") and **`C`**, which does not exist; `UC` is missing. Of the 15 `TemplateIdentifier` constants, 3 name the wrong template: TID 320 is "Image or Spatial Coordinates" (not "Image Library Entry", which is TID 1601), TID 4000 is "Mammography CAD Document Root" (not "CAD Analysis"), TID 4019 is "Algorithm Identification" (not "CAD Finding"). 4 more have shortened titles (1400 "Linear Measurement", 1410/1411 "… and Qualitative Evaluations", 1501 "Measurement and Qualitative Evaluation Group"). The citations "Section 5", "5.1" and "5.3" are Chapter 6, §6.1 and §6.1.7 in 2026a. **Fix:** `userOption` (U) and `userOptionConditional` (UC) added, `userConditional` kept as a deprecated alias, `conditional` (C) deprecated and dropped from `allCases`; `imageOrSpatialCoordinates` (320) added and `imageLibraryEntry` renumbered to 1601; `mammographyCADDocumentRoot` and `algorithmIdentification` added, `cadAnalysis`/`cadFinding` made unavailable; citations corrected. `TID320ImageLibraryEntry` (SRCoreTemplates, C2) always modelled TID 1601's rows, so it is renamed `TID1601ImageLibraryEntry` with a deprecated alias and registers under 1601. 1 table test added. |
| **PrivateTagDictionary** | PS3.5 §7.8 citation (correct); 15 vendor tag definitions | ⚠️ **Not plumbing; fixed with approval 2026-09-25.** The vendor data is outside NEMA's scope, so it was checked against DCMTK's and GDCM's private dictionaries. **8 of 15 entries disagree:** Siemens CSA (0029,xx09) and (0029,xx19) are **LO** not CS; Siemens MR (0019,xx0D) is **CS "Diffusion Directionality"** and (0019,xx0E) is **FD "Diffusion Gradient Direction"** (the file shifts both by one; Gradient Mode is xx0F, SH); GE (0009,xx01) "Full Fidelity" is **LO** not CS; GE (0019,xx0F) is **DS "Horizontal Frame of Reference"**, not "Protocol Data Block" (that is (0025,xx1B) under GEMS_SERS_01); Philips (2001,xx03) is **FL "Diffusion B-Factor"** (Chemical Shift is xx01) and (2001,xx08) is **IS "Phase Number"**, not "Stack Radial Angle". The 7 others match. **Fix:** all 8 corrected to the DCMTK/GDCM values (Gradient Mode added at xx0F, Chemical Shift moved to xx01, so the dictionary now has 17 entries); a test asserts every entry against the reference list and that no stray entries exist. The marker names DCMTK/GDCM, not NEMA, as the source for the vendor rows. |

**Findings from the check.**

1. **Four citation or comment errors were fixed in place** (ByteOrder, J2KCodestreamInspector, DICOMError, PixelDataError). None changed behaviour except the PixelDataError explanation text, which is now derived from the registry.
2. **Two files were misclassified as plumbing.** `SRTemplate.swift` carries PS3.16 data (requirement types, TID names) and `PrivateTagDictionary.swift` carries vendor dictionary data. Both had wrong values and both were fixed with approval on 2026-09-25 (see the table). Public API impact: deprecated aliases for `RequirementLevel.userConditional`, `RequirementLevel.conditional` and `TID320ImageLibraryEntry`; `cadAnalysis` and `cadFinding` are unavailable with the correct names in the message.
3. **Default UID root.** `UIDGenerator.defaultRoot` is DCMTK's OID. That is a convention, not a standard violation, but PS3.5 §9.2.2 expects a registered root of one's own. Documented; not changed.

---

## Bucket C2 — Standard-derived, edition-stable (59 files)

Carries PS3.x data, but the data has not materially changed across recent DICOM editions, so no
edition label applies.

### Verification — ✅ complete (59 of 59)

Same method as B2: extract the standard's table by script from the frozen 2026a DocBook, strip
U+200B, compare row by row, fix what is wrong, mark the file.

| Group | Files | Compared against | Result |
|---|---|---|---|
| Tags | Tag.swift + 20 `Tag+*.swift` (971 constants) | PS3.6 2026a Table 6-1 (5,305 rows incl. masked `xx` tags), Table 7-1 (file meta), Table 8-1 (directory) | ✅ **All 971 tags exist with the right (group, element).** 26 apparent duplicates across files are commented-out lines. 16 doc-comment issues fixed: **retired but unmarked** — Number of References (0004,1600) RET 2004, Ethnic Group (0010,2160) **RET 2025a** (replaced by Ethnic Group Code Sequence (0010,2161) and Ethnic Groups (0010,2162)), Graphic Layer Recommended Display RGB Value (0070,0067) RET 2004, Contour Slab Thickness (3006,0044) and Contour Offset Vector (3006,0045) RET 2020e; **wrong VR/VM notes** — Data Collection Center (Patient) VM 3 not 2, Transducer Frequency VM 1 not 1-n, the three Large Palette Color LUT Data elements are OW not "OW or OB"; **wrong names** — (300A,0230) is "Application Setup Sequence", (0062,000E) "Maximum Fractional Value", (0008,1072) "Operator Identification Sequence"; **Swift name ≠ keyword** — `exposureInMicroAs` (ExposureInuAs, acceptable), `brachyApplicationSetupSequence`, `maxFractionalValue`, `verticesOfPolygonalShutter` (noted in the doc; see Q1). Tag.swift's §7.1 citation retitled "Data Elements". Markers on all 21. |
| VR value types | DICOMAgeString, DICOMApplicationEntity, DICOMCodeString, DICOMDate, DICOMTime, DICOMDateTime, DICOMDecimalString, DICOMIntegerString, DICOMPersonName, DICOMUniqueIdentifier, DICOMUniversalResource | PS3.5 2026a Table 6.2-1 (AS, AE, CS, DA, TM, DT, DS, IS, PN, UI, UR rows: definition, repertoire, length); §9.1; PS3.6 2026a Table A-1 | ✅ Formats, repertoires and length limits match for all 11. Fixed: **`DICOMUniqueIdentifier.isSOPClass`** was a prefix heuristic that missed 28 of the 311 SOP Classes in Table A-1 (Verification, Storage Commitment, all Print Management classes, Substance Administration Logging, 1.2.840.10008.10.x) and matched 10 non-classes (Meta SOP Classes, Service Classes, Well-known SOP Instances); its comment also called 1.2.840.10008.1.3 "Basic Film Session" (it is Media Storage Directory Storage). **`isTransferSyntax`** missed the retired Papyrus 3 syntax (1.2.840.10008.1.20). Both now test membership in `sopClassUIDs` (311) and `transferSyntaxUIDs` (63), generated from Table A-1. DICOMTime's doc said 16 characters max; the row says 14 bytes. Documented, not changed (read-side leniencies): AE accepts a spaces-only value as empty; DA/TM accept the ACR-NEMA dotted/colon forms; DT accepts offsets to -1400 and -0000; DS accepts hexadecimal floats via `Double(_:)`; PN does not enforce 64 characters per group or reject 5CH; UR trims leading spaces. 1 test added. Markers on all 11. |
| Encoding / pixel data | DICOMWriter, SequenceItem, EncapsulatedPixelData, PixelData, PixelDataDescriptor, PaletteColorLUT, RLECodec | PS3.5 2026a §6.2 (padding), §7.1, §7.5, §8.1.1, §8.2, §A.4, Annex G (G.2–G.5); PS3.3 2026a Table C.7-11c, C.7.6.3.1.1–.3, C.7.6.3.1.5–.6, C.7.6.3.1.8 | ⚠️ Two behaviour bugs fixed. **`EncapsulatedPixelData.makeFrameIndex` read Extended Offset Table values as header-less offsets.** C.7.6.3.1.8 says each value is the offset of the frame's *Item Tag* measured from the first Item Tag after the Basic Offset Table, i.e. the same convention as the BOT, headers included. Every conformant table therefore failed the consistency check and the index fell back to nil (fail closed), so a multi-frame file with an EOT could not be read by frame. Fixed; a DICOMKit test that encoded the wrong convention was corrected. **`RLECodec.encodeFrame` let PackBits runs cross image rows**, which G.3.1 forbids ("Each row of the image shall be encoded separately and not cross a row boundary"); the encoder now packetises each row on its own (still lossless, decoder unchanged). Everything else matches: header padding and the 13 32-bit-length VRs (DICOMWriter), delimiter tags (SequenceItem), Pixel Cell extraction (PixelData), RLE header/segments/decoder (G.2, G.3.2, G.5), palette descriptor clamping and 8-bit scaling (C.7.6.3.1.5/6). Doc fixes: `PixelDataDescriptor` cited C.7.6.3.1.1 ("Samples per Pixel") for Rows, Columns, Bits Allocated, Bits Stored, High Bit and Pixel Representation, now Table C.7-11c / PS3.5 §8.1.1; `PaletteColorLUT` named C.7.6.3.1.5 "…Module" (it is "…Descriptor"). 6 tests added. Markers on all 7. |
| Codecs | HTJ2KCodec, ImageCodec, J2KSwiftCodec, JLICodec, JPEGLSCodec, NativeJPEG2000Codec, NativeJPEGCodec | PS3.6 2026a Table A-1 (UIDs, via `TransferSyntax`); PS3.5 2026a §A.4.1, A.4.3, A.4.4 and Tables 8.2.1-1/2, 8.2.3-1, 8.2.4-1, 8.2.14-1 | ✅ UIDs are all `TransferSyntax` constants, so they match Table A-1 by construction. Every `canEncode` constraint is a subset of the §8.2 tables (JPEG Baseline 8/8; Extended 8/8 or 16/12; Lossless and JPEG-LS 8-or-16 allocated with 2–16 stored, the tables allow 1–16; JPEG 2000 8 or 16 allocated where the table allows up to 40). None contradicts the standard. **Five wrong section citations fixed:** HTJ2KCodec and J2KSwiftCodec cited A.4.6 (MPEG-4 AVC/H.264) for the HTJ2K syntaxes, which are in A.4.4; JLICodec and NativeJPEGCodec cited "A.4.1–A.4.3" for JPEG (A.4.2 is RLE, A.4.3 JPEG-LS); JPEGLSCodec cited A.4.5 (MPEG2) instead of A.4.3. The compression algorithms themselves are ISO/ITU standards outside DICOM's scope. Markers on all 7. |
| Private tags | PrivateCreator, PrivateDataElement, PrivateTagAllocator | PS3.5 2026a §7.8.1, §7.8.2 | ✅ Block rules match (odd groups, creator elements 0010–00FF, data elements bb00–bbFF). Doc fixes: PrivateCreator cited a "§6.1.4 Private Creator Data Element" section that does not exist (now §7.8.1); `geProtocol`'s doc called GEMS_ACQU_01 the "Protocol Data Block" (that is GEMS_SERS_01); PrivateDataElement's offset range said 0x10–0xFF (0x00–0xFF). Markers on all 3. |
| SR support | CodingScheme, CodedConcept, ContentItemValueType, ContentItemTypes, CodeMapper | PS3.16 2026a Table 8-1 (Coding Schemes); PS3.3 2026a Table 8.8-1a, Table C.17.3-7, C.18.1–C.18.10 | ⚠️ **`CodingScheme.icd10CM` and `CodingSchemeDesignator.ICD10CM` used designator "I10"**, which Table 8-1 defines as WHO ICD-10 (2.16.840.1.113883.6.3); ICD-10-CM is **I10C** (…6.90). Both now say I10C, and `icd10` / `ICD10` were added for I10. `acr` gained its Table 8-1 UID (…6.76). "HL7" is not a registered designator and is documented as such. CodedConcept's length limits (16/16/64, Long/URN Code Value) match Table 8.8-1a. ContentItemValueType has 15 of 16 value types (TABLE, P8) and cited "Table C.17.3-1" (it is C.17.3-7); ContentItemTypes cited fifteen sections C.17.3.2.1–.15, of which only .1–.5 exist and none describes the type — all 15 now point at the C.18.x macro or the Table C.17-5 attribute. CodeMapper's DCM/SCT concepts all match PS3.16; its three SRT laterality codes are retired-designator legacy. 2 tests added. Markers on all 5. |
| External terminologies | LOINCCode, RadLexCode, SNOMEDCode, UCUMUnit | Outside NEMA's scope. Checked against every code of that scheme used in PS3.16 2026a CID tables and Annex D (15,696 distinct codes) | ⚠️ Partially verifiable. **LOINC** (53): 5 match PS3.16's meaning, 12 differ in wording, 36 unused by PS3.16; **four were wrong LOINC concepts and were corrected** — 18748-4 is "Diagnostic imaging study" (was "Radiology Report"), 55111-9 "Current imaging procedure descriptions" (was "Technique"), 24590-2 "MR Brain" (was "MRI report"), 18750-0 "Cardiac electrophysiology study" (was "Ultrasound report"). **SNOMED** (89): 56 match, 9 are PS3.16 synonyms, 24 unused; `tumor`/`neoplasm` share 108369006. **UCUM** (50): 24 match, 7 where PS3.16's meaning is the symbol, 19 unused; `beatsPerMinute` and `breathsPerMinute` share the bare code "/min". **RadLex** (70): none of the 70 RIDs appears in PS3.16, so nothing could be verified. 1 test added. Markers state exactly what was and was not checked. |
| SR templates | SRCoreTemplates, SRMeasurementTemplates (13 TID types) | PS3.16 2026a TID tables 300, 1001, 1002, 1204, 1400, 1410, 1411, 1419, 1420, 1500, 1501, 1600, 1601 (rows: NL, relationship, VT, concept, VM, requirement) | ⚠️ **Concept literals fixed, structure deferred (P10).** All 107 coded concept literals were checked against PS3.16: 10 were wrong and are corrected — DCM 121191 is "Referenced Segment" (a row called it "Referenced Image"); Subject UID is 121028, not 121030 ("Subject ID"); "Referenced Segment" was coded 121233 ("Source image for segmentation") twice; "Source of Measurement" was 121405 ("Population description"), it is 121112; "Maximum 3D Diameter" was 121217 (a volume-estimation method), now IBSI L0JK; mm2/mm3 meanings; SCT 373098007 is "Mean". The **row structures diverge from 2026a**: of 142 standard rows across the 13 tables, 30 have a Swift counterpart; 77 Swift rows have none. Every template omits the INCLUDE rows for sub-templates (TID 300D, 301, 310, 315, 1000, 1003–1006, 1015, 1502, 1602, 4019, 4108) and several add rows the standard does not have. Only TID 1204 matches exactly. Rebuilding them is a public-API redesign; logged as P10. Markers state this. |

**Open questions for C2 (public API, need approval).**

- **Q1.** Rename `brachyApplicationSetupSequence` → `applicationSetupSequence`, `maxFractionalValue` → `maximumFractionalValue`, `verticesOfPolygonalShutter` → `verticesOfThePolygonalShutter` to match the PS3.6 keywords, keeping the old names as deprecated aliases? Doc comments already carry the keyword, so this is cosmetic.

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
