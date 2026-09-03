# Enhanced Multiframe Split/Merge Plan

**Status:** Section 0, P0, P1, P2 (incl. viewer per-frame VOI) and P3-1/P3-3 landed 2026-09-01 (uncommitted); open: real-corpus fixtures, P3-2 console-parity oracles
**Tools:** `dicom-split`, `dicom-merge` (CLI) · Studio CLI Workshop split/merge screens · Toolbox forms
**Engines:** `Sources/DICOMKit/Splitting/FrameSplitter.swift`, `Sources/DICOMKit/Merging/FrameMerger.swift`,
`Sources/DICOMKit/Multiframe/` (shared)

## Progress log

| Date | What landed | Verified by |
|---|---|---|
| 2026-09-01 | Section 0 shared engine: `Sources/DICOMKit/Multiframe/{MultiframeSOPClassMap, FunctionalGroupFlattener, FunctionalGroupBuilder, MultiframePixelAssembler, LegacyVectorResolver}.swift` + `Tag+MultiframeFunctionalGroups.swift` (DICOMCore); `SplitOptions` / `MergeOptions`; `SplitConsole` / `MergeConsole` new lines; CLI flags; Workshop `parameterDefinitions` + executors; Toolbox `ToolRegistry` | `swift build` (all targets) |
| 2026-09-01 | P0-1 … P0-4 (compressed split/merge, dimension module, source gate + always-on Image Pixel / TS / duplicate-UID checks, `standard` warning) | `EnhancedMultiframeRoundTripTests` (encapsulated preserve, mixed TS, gate, warning) |
| 2026-09-01 | P1-1 … P1-4 (SOP-class map, FG flattening + typed clean-up incl. MR derivations, ordering/identity/`--split-by`, cine + NM vectors) | `EnhancedMultiframeRoundTripTests` (Enhanced CT → CT, `--target same`, stacks, US cine, NM) |
| 2026-09-01 | P1-5 … P1-7 (attribute-equality factoring, all formats incl. `auto`/Legacy Converted/SC/US, stacks/temporal/sort-by-normal) | `EnhancedMultiframeRoundTripTests` (factoring, Legacy Converted evidence, `auto`, make-stacks, sort-by-normal, split→merge→split identity) |
| 2026-09-01 | P3-1 synthetic oracles (18 new + 37 existing green); P3-3 help text, `ROUND_TRIP_COVERAGE_GAPS.md`, `APP_CLI_SHARED_API.md`, CHANGELOG | `swift test --filter DICOMRoundTripTests.(Split\|Merge\|Enhanced\|SharedConsole)` |
| 2026-09-02 | Merge format×modality matrix: `MergeFormatMatrixTests` (16 oracles) — every MergeFormat × its admitted source class (CT/MR/PET/XA/XRF/US/SC), SC byte/word/true-colour/single-bit refinement, `auto` picks, gate refusals for all targets, Enhanced chunk re-merge; found + fixed single-bit (BitsAllocated=1) frame extraction (descriptor rounds 1 bit → 1 byte; assembler now slices bit-packed frames, refusing non-byte-aligned frames); also fixed validateImagePixelModule/validateConsistency comparing binary VRs via string(for:) (nil==nil, checks were inert) with file-naming diagnostics | `MergeFormatMatrixTests`, real-corpus round-trip (72 series × 3 formats, byte-identical), full suite green |
| 2026-09-01 | CLI smoke: `dicom-merge --format enhanced-ct` on two classic CT slices → `dicom-split` back to CT Image Storage, debug binaries | manual (`dicom-info` on the outputs) |
| 2026-09-01 | P2-1 concatenations: `MultiframeConcatenation` (parts / reassembly, DCMTK ConcatenationCreator/Loader parity), `dicom-split --frames-per N` (SOP class kept, SEG/PMap allowed, OPT refused, legacy vectors sliced per part), merge auto-detects parts and reassembles (source SOP UID restored) | `testConcatenationSplitAndReassembly`, `…PolicyPerIOD`, `…SlicesLegacyVectors` |
| 2026-09-01 | P2-2 provenance: `MultiframeInstanceUIDs` derived `2.25.<sha256>` SOP/Series UIDs (default; `--random-uids` opts out), `ProvenanceRewriter` expands Referenced/Source Image references with Referenced Frame Number into per-frame references (dcm4che `adjustReferencedImages`) | `testDeterministicUIDsAreReproducible`, `testSplitExpandsFrameReferencesToDerivedInstances` |
| 2026-09-01 | P2-3 volume classes + multi-frame inputs: `FrameInfo` reads Plane Position/Orientation (Volume); merge expands multi-frame inputs (Enhanced chunks, cine loops) into all their frames and re-factors them; `standard` keeps Per-frame items of Enhanced inputs | `testMergeMultiframeInputsContributeAllFrames`, `testFrameInfoReadsVolumeGeometry` |
| 2026-09-01 | P2-4 viewer/export adoption: `DataSet.windowSettings()` / `rescaleSlope()` / `rescaleIntercept()` fall back to the Frame VOI LUT / Pixel Value Transformation functional groups; `DataSet.flattenedFrame(_:)` for per-frame access | `testWindowAndRescaleFallBackToFunctionalGroups` |
| 2026-09-01 | P2-4 viewer per-frame VOI: `windowSettings` / `allWindowSettings` / `rescaleSlope` / `rescaleIntercept` take `frameIndex:` (that frame's Per-frame item, else Shared); `DICOMImageExporter.determineWindowSettings` honours `frameIndex` at the rescale and VOI rungs, so the GPU/CPU tile path, film, export and convert all use the frame's own window; `ImageViewerViewModel` re-derives an *untouched* default window and adopts the rescale pair on every frame change (`hasPerFrameWindow`, `adoptFrameWindow`), a dragged window survives paging, reset lands on the frame on screen | `testPerFrameWindowAndRescaleFollowTheFrame`; `ViewerPerFrameWindowTests` (3, DICOMStudioTests); viewer/export/split/merge regression suites green |

**Deliberate deviations from the original plan**
- Split keeps the source Series Instance UID by default (`--new-series` opts in) and merge keeps the template series; the existing round-trip oracles pin that behaviour and emf2sf's "always new series" default is available as a flag.
- `--format standard` on a classic IOD still merges (with an always-on warning) instead of refusing — existing users/tests rely on it; `--format auto` is the conformant path.
- `--validate` remains the opt-in *identity* check (Study/Series/Modality/FoR); the Image Pixel module, transfer-syntax equality and duplicate SOP Instance UIDs are now checked on every run.
- Same-class Enhanced targets (Tomo, X-Ray 3D, OPT, US Volume …) keep their functional groups with the Per-frame sequence trimmed to the frame's item, rather than flattening — a one-frame Enhanced instance must still carry the module to be conformant.

**Still open:** P3-1 committed real-corpus fixtures (a full real-data round-trip was run 2026-09-02 on a 1973-file / 72-series classic-MR study: merge (enhanced-mr, legacy-converted-mr, auto) → split → byte-identical pixels + IPP for every frame, all 216 merged files ✓ VALID under dicom-validate — but the study is not committed as a fixture) and P3-2 console parity oracles for the new lines. Provenance rewriting only expands references that carry Referenced Frame Number — a reference to a whole multi-frame instance is left as is because the frame count of the other instance is unknown.

## Goal

Make `dicom-split` and `dicom-merge` real Enhanced-multiframe converters for **all** modalities
(CT, MR, PET, XA, XRF, US, NM, SC, RT, Tomo, OPT, US Volume, …) in both directions, with every
capability living **once** in DICOMKit so the CLI and the Studio app share the same engine and
console output — the same pattern already used by `dicom-compress` (`CompressionConsole`),
`dicom-convert` (`DICOMConverter`), `dicom-dcmdir` (`DICOMDIRWorkflow`), `dicom-pdf`
(`EncapsulatedDocumentWorkflow`) and the print SCP (`DICOMPrintKit`).

## Where we are today

| Area | dicom-split | dicom-merge |
|---|---|---|
| Modality / SOP-class awareness | none — anything with NumberOfFrames>1 splits identically | none — `--format enhanced-ct` accepted for MR/US input; `standard` emits CT Image Storage with NumberOfFrames>1 |
| SOP class conversion | no — outputs keep the Enhanced SOP class | ct / mr / xa only |
| Functional groups | copied verbatim (full N-item Per-Frame sequence in every file) | Shared: PixelMeasures only. Per-frame: FrameContent (StackID=1), PlanePosition |
| Dimension organization | ignored | DimensionIndexValues written with no DimensionOrganizationSequence / DimensionIndexSequence |
| Legacy MF vectors (NM / US / XA-RF) | ignored | n/a |
| InstanceNumber / SeriesInstanceUID | not renumbered, same series | IN=1, series UID reused |
| Frame sorting | none | IN / IPP-Z / AcquisitionTime (Z only) |
| Compressed input | **corrupt** (native pixels under compressed TS UID) | **corrupt** (raw fragment concatenation) |
| Concatenations / provenance | no | no |
| Tests | synthetic 8-bit grayscale only | synthetic 8-bit grayscale only |

Both `--help` texts already promise "Enhanced CT/MR/XA with proper functional groups".

## Reference implementations (verified from source)

| Project | What to borrow |
|---|---|
| dcm4che `emf2sf` / `MultiframeExtractor` | SOP-class map (17 classes), generic Shared→Per-Frame flatten, FrameType→ImageType, MR EchoTime/ScanningSequence/SequenceVariant/ScanOptions derivation, `--inst-no` / `--not-chseries`, referenced-image expansion |
| highdicom `legacy.sop` | attribute-equality shared-vs-per-frame rule (whole macro), 3D dimension index on IPP, Legacy Converted CT/MR/PET modules, Unassigned Converted Attributes |
| dicom3tools `dcmulti` / `dcuncat` | option set: `-sortby`, `-makestack`, `-temporalposition`, `-dimension`, `-addreferenced`, `-framesper`, `-noprivateseq` |
| DCMTK `dcmfg` | typed FG classes + FGUnknown, ONLYSHARED/ONLYPERFRAME rules, `FrameSorterIPP`, `ConcatenationCreator` / `ConcatenationLoader` |
| Weasis | 12-macro whitelist for per-frame attributes, NM per-frame IPP from DetectorInformationSequence + SliceVector |
| Horos | PlanePositionVolume / OphthalmicFrameLocation handling; issue #543 (sort by position, not storage order) |

## SOP class map (split targets)

| Multiframe SOP class | Split target |
|---|---|
| Enhanced CT / MR / PET | CT / MR / PET Image Storage |
| Legacy Converted Enhanced CT / MR / PET | CT / MR / PET Image Storage |
| Enhanced XA / XRF | XA / XRF Image Storage |
| US Multi-frame · MF Secondary Capture (byte / word / true colour) | US Image · SC Image Storage |
| NM · RT Image · legacy XA/RF MF | same class, NumberOfFrames=1, vectors sliced |
| Breast Tomo · X-Ray 3D · OPT · Breast Projection · Enhanced US Volume · Enhanced MR Colour · IVOCT | same class, NumberOfFrames=1, FGs flattened (optional `--fallback-sc`) |
| Segmentation · Parametric Map · MR Spectroscopy | refuse (concatenation split only) |

---

## Work items

### 0. Shared library / API (do first — everything below builds on it)

Every item in this plan is implemented in **DICOMKit**, never in the CLI target or the Studio
view model. The CLI and the Workshop screen are thin front-ends over the same objects, exactly
as the other tools are structured (see `APP_CLI_SHARED_API.md`).

- [x] **`MultiframeSOPClassMap`** (`Sources/DICOMKit/Multiframe/`) — the single table of
      multiframe SOP class → split target / merge source, refuse-list, "same-UID" classes.
      Used by split, merge, validation and the Workshop pickers. Never re-hardcode
      (same rule as `StorageSOPClass.allUIDs`).
- [x] **`FunctionalGroupFlattener`** — Shared + Per-Frame[i] → top-level dataset
      (generic pass + typed clean-up pass + private-group policy). Used by split, and by the
      viewer's per-frame model so display and split agree.
- [x] **`FunctionalGroupBuilder`** — per-frame source datasets → Shared / Per-Frame FG
      sequences + Multi-frame Dimension module (attribute-equality factoring). Used by merge.
- [x] **`MultiframePixelAssembler`** — per-frame pixel extraction / assembly that handles
      native and encapsulated data (BOT, multi-fragment frames), VR, PI and
      PlanarConfiguration. Used by split, merge and concatenation code.
- [x] **`LegacyVectorResolver`** — FrameIncrementPointer / FrameTimeVector / NM vectors →
      per-frame scalars (and the reverse for `us-multiframe` merge).
- [x] Extend **`FrameSplitter` / `FrameMerger`** options (`SplitOptions`, `MergeOptions`)
      with every new flag so CLI `ParsableCommand` and Workshop `parameterDefinitions` map 1:1.
- [x] Extend **`SplitConsole` / `MergeConsole`** with all new console lines (SOP conversion,
      stack detection, FG factoring summary, warnings). CLI and app must never inline text.
- [x] Workshop: split/merge screens call the same `FrameSplitter` / `FrameMerger` entry points
      with the same option structs; add the new parameters to `parameterDefinitions`.
- [x] Update `APP_CLI_SHARED_API.md` ownership table (no `CLIContracts.json` exists in the repo any more — nothing to regenerate).

### 1. P0 — correctness bugs in what ships today

- [x] **P0-1 Split, compressed input** — pass encapsulated fragments through per frame (rebuild
      BOT, reassemble multi-fragment frames) or decode and rewrite TransferSyntaxUID to
      Explicit VR LE. Use `pixelData(frame:)` (today O(N²) full decode per output). PixelData VR
      OB/OW from BitsAllocated; fix PhotometricInterpretation / PlanarConfiguration after
      YBR→RGB decode. `FrameSplitter.swift:209,:242,:248`.
- [x] **P0-2 Merge, compressed input** — decode or re-encapsulate with BOT, never concatenate
      raw fragments; add TransferSyntaxUID to the consistency check; pad odd lengths; correct
      VR. `FrameMerger.swift:251-267,:282`.
- [x] **P0-3 Merge, dimension module** — emit DimensionOrganizationSequence (fresh UID),
      DimensionIndexSequence (→ PlanePositionSequence/ImagePositionPatient for 3D, else
      FrameContent/InStackPositionNumber) and DimensionOrganizationType whenever
      DimensionIndexValues is written.
- [x] **P0-4 Merge, gating** — `enhanced-ct` only from CT Image Storage etc.; refuse
      `standard` for SOP classes that are not multiframe IODs; make core consistency checks
      default-on (FoR, Study, Rows/Columns, bit depth, PI, TS, duplicate SOP UIDs).
      `FrameMerger.swift:242-348,:406-457`.

### 2. P1 — Split: Enhanced → classic

- [x] **P1-1 SOP class conversion** via `MultiframeSOPClassMap`; `--target auto|same|classic|sc`.
- [x] **P1-2 Functional-group flattening** — (a) generic: copy dataset minus
      {Shared/Per-Frame FG, NumberOfFrames, DimensionIndex/Organization sequences, evidence
      sequences, Concatenation*, PixelData}; dump Shared item[0] then Per-Frame[i] item[0] of
      every nested sequence to top level, per-frame wins; keep ReferencedImageSequence /
      DerivationImageSequence as sequences. (b) typed clean-up: FrameType→ImageType,
      FrameLaterality→ImageLaterality, FrameAcquisitionDateTime→AcquisitionDateTime,
      EffectiveEchoTime→EchoTime, MR ScanningSequence / SequenceVariant / ScanOptions
      derivation; drop StackID / InStackPositionNumber / DimensionIndexValues /
      TemporalPositionIndex for classic targets, keep them for same-UID targets.
      `--private-groups keep|flatten|drop`.
- [x] **P1-3 Ordering and identity** — order by DimensionIndexValues / StackID +
      InStackPositionNumber (fallback: IPP projected on the orientation normal, then storage
      order); `--split-by stack|temporal|none` (one series per stack / temporal position);
      new SeriesInstanceUID by default, `--keep-series`; deterministic `<mapped>.N` SOP UIDs;
      `--instance-number frame|instack|format:"%s%04d"`.
- [x] **P1-4 Legacy vectors** — FrameIncrementPointer / FrameTimeVector → FrameTime
      (US / XA / RF / SC); NM: per-frame ImagePositionPatient from DetectorInformationSequence
      IOP/IPP + SpacingBetweenSlices along the normal indexed by SliceVector; slice
      EnergyWindowVector / DetectorVector / PhaseVector / RotationVector to scalars; RT Image.

### 3. P1 — Merge: classic → Enhanced

- [x] **P1-5 Shared-vs-per-frame factoring** — attribute equal in every input → Shared; any
      varying attribute → whole macro Per-Frame; FrameContent always per-frame; lift **and
      remove** the top-level single-frame attributes. Macros: PixelMeasures, PlanePosition,
      PlaneOrientation, FrameVOILUT (VOILUTFunction, explanation, MONOCHROME1),
      PixelValueTransformation (RescaleType HU/US, omitted for MR), FrameAnatomy, CT/MR/PET/XA
      ImageFrameType (MIXED when inconsistent), IrradiationEventIdentification,
      DerivationImage / ReferencedImage, RealWorldValueMapping, MR timing/echo/FOV/coil,
      Unassigned Shared/Per-Frame Converted Attributes (Legacy Converted).
      `FrameMerger.swift:283-339`.
- [x] **P1-6 Formats** — add `enhanced-pet`, `enhanced-xrf`, `legacy-converted-ct|mr|pet`
      (default for classic series?), `sc-multiframe` (byte / word / true colour by bit depth
      and samples), `us-multiframe` (FrameTimeVector). Each with its mandatory modules:
      Enhanced/Legacy series, Frame of Reference, Enhanced General Equipment, Common Instance
      Reference, Acquisition Context, ContentDate/Time, ImageType rewrite,
      SpacingBetweenSlices, Largest/Smallest pixel value, lossy-compression aggregation.
- [x] **P1-7 Sort and group** — IPP projected on the orientation normal (not Z);
      `--make-stacks` (multiple orientations/positions → StackIDs); `--temporal-position`
      (TriggerTime / AcquisitionTime → TemporalPositionIndex); regular-spacing check → 3D vs
      stacked dimension organization; stable descending sort; new SeriesInstanceUID.
      `FrameMerger.swift:351-395`.

### 4. P2 — beyond the ecosystem

- [x] **P2-1 Concatenations** — split `--frames-per N` (ConcatenationUID,
      InConcatenationNumber/TotalNumber, ConcatenationFrameOffsetNumber,
      SOPInstanceUIDOfConcatenationSource, Per-Frame items distributed); merge detects and
      reassembles a concatenation directory. Only legal "split" for SEG / Parametric Map.
      *(`Multiframe/MultiframeConcatenation.swift`)*
- [x] **P2-2 Provenance** — split: expand ReferencedImageSequence / SourceImageSequence
      entries that point at a multiframe instance into per-frame references
      (ReferencedFrameNumber honoured) using derived, reproducible UIDs; merge:
      ConversionSourceAttributes + Common Instance Reference (Legacy Converted).
- [x] **P2-3 Volume-type classes** — PlanePositionVolume / PlaneOrientationVolume feed the
      frame geometry (ordering, stacks); OphthalmicFrameLocation / US Image Description
      travel in the retained Per-frame item of same-class targets.

### 5. P3 — verification and hygiene

- [ ] **P3-1 Round-trip oracles per modality** in `Tests/DICOMRoundTripTest/` — real corpus
      files for Enhanced CT, Enhanced MR (multi-echo, multi-stack), Enhanced PET, Enhanced XA,
      NM SPECT, US MF cine, MF-SC true colour, JPEG/J2K/RLE-compressed Enhanced CT, 16-bit
      signed; assert per-frame IPP/IOP/VOI/rescale after split, FG factoring after merge,
      split → merge → split identity, validator-clean output.
- [x] **P3-2 App-vs-terminal parity** — `Tests/DICOMStudioTests/SplitMergeWorkshopCLIParityTests.swift`
      (2026-09-03) drives every dicom-split / dicom-merge option combination (32 + 30 cases, each
      with and without `--verbose`) through the Studio Workshop executor AND the real release
      binary (tokens taken from the Workshop's own command preview) and asserts identical console
      lines, exit outcome and output files (DICOM fingerprint minus minted UIDs/dates, byte-equal
      images). Caught and fixed five app-side drifts: non-verbose engine warnings dropped,
      `--frames` parsed before the banner, ArgumentParser's `<value-name>` + `Help:` line missing
      from bad-value errors (now `SplitConsole.invalidValueLines` + shared help constants),
      merge's "Found 0 DICOM files" line skipped, and a missing merge root reported as
      "No DICOM files found" instead of "Input path does not exist".
- [x] **P3-3 Docs / help honesty** — `{number:04d}` in split help is not implemented; the
      "proper functional groups" claim in both tools; `ROUND_TRIP_COVERAGE_GAPS.md` marks
      `enhanced-*` as fully implemented; regenerate `CLIContracts.json`.

## Suggested order

1. Section 0 skeleton types + P0-1 / P0-2 (`MultiframePixelAssembler`) — unblocks everything.
2. P0-3 / P0-4, then P1-1 … P1-4 (split) with Enhanced CT + MR fixtures.
3. P1-5 … P1-7 (merge) with round-trip against the split output.
4. P1-4 / P1-6 modality sweep (US, NM, XA/XRF, PET, SC).
5. P2, then P3 sweep and doc regeneration.
