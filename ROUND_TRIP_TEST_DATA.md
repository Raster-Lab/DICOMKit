# Round-Trip Test Data & Results

Companion to [`ROUND_TRIP_TESTS_PLAN.md`](ROUND_TRIP_TESTS_PLAN.md). The plan is the
**design** (per-tool oracles); this document is the **data + results** tracker:
what fixtures exist, which test case each covers, and the latest pass/fail.

- Target: `DICOMRoundTripTests` — `swift test --filter DICOMRoundTripTests`
- Sources: [Tests/DICOMRoundTripTest/](Tests/DICOMRoundTripTest/) (note singular "Test")
- Every assertion is an **oracle** (a math/semantic fact), never a comparison to
  another code surface — that is what lets these catch bugs both the CLI and Studio
  share (the `dicom-pixedit --invert` VOI bug is the canonical example).

---

## Part A — Test Corpus (Tier 2: real, anonymized)

Five de-identified real DICOM files under
[Tests/DICOMRoundTripTest/Corpus/](Tests/DICOMRoundTripTest/Corpus/). All have
`(0012,0062) Patient Identity Removed = YES`, hashed `PatientID`, no clear-text
names/physicians, dates shifted. Resolved at runtime via `#filePath`; tests
**skip cleanly** (`XCTSkipIf`) when the corpus is absent (e.g. CI).

| Fixture (`Corpus` case) | File | Modality / SOP | Transfer Syntax | Dims | Bits (alloc/stored) | Samples / PI | Frames | Notable | Exercises |
|---|---|---|---|---|---|---|---|---|---|
| `.ct` | `CT.dcm` | CT · 1.1.2 | Explicit VR LE `1.2.840.10008.1.2.1` | 512×512 | 16/16 unsigned | 1 / MONOCHROME2 | 1 | WC 40 / WW 300 · Rescale slope 1 / int −8192 (HU) · PixSpacing 0.7299 | HU measure, window export, anon, info/dump, tags, validate |
| `.mr` | `MR.dcm` | MR · 1.1.4 | **Implicit VR LE** `1.2.840.10008.1.2` | 384×384 | 16/12 unsigned | 1 / MONOCHROME2 | 1 | WC 538 / WW 1131 · PixSpacing 0.8333 | Implicit→Explicit convert, non-CT HU path, diff |
| `.us` | `US.dcm` | US · 1.1.3.1 | **JPEG Baseline** `1.2.840.10008.1.2.4.50` | 758×1016 | 8/8 | 3 / YBR_FULL_422 | **92** | color, lossy-compressed source | decompress, multi-frame split/export, colour handling |
| `.j2kLossless` | `j2klossless.dcm` | CT · 1.1.2 | **J2K Lossless** `1.2.840.10008.1.2.4.90` | 512×512 | 16/16 unsigned | 1 / MONOCHROME2 | 1 | WC 40 / WW 300 (HU) | j2k info/validate/transcode/reduce/roi, decompress identity |
| `.ctMultiframe` | `CT_Multiframe` | Enhanced MR · 1.1.4.1 | Explicit VR LE `1.2.840.10008.1.2.1` | 192×192 | 16/12 unsigned | 1 / MONOCHROME2 | **12** | *(filename has no extension)* WC 2048 / WW 4096 | multi-frame compress/split/animate, frame-index oracles |

Re-anonymize a newly added corpus file with:
`dicom-anon --profile clinical-trial --regenerate-uids --shift-dates 365 <file>`
then explicit `--remove` for residual physician/ID tags and `--replace "0012,0062=YES"`.

---

## Part B — Synthetic Fixtures (Tier 1: built in `RoundTripFixture.swift`)

Deterministic, pixel-exact, CI-safe. ~85% of cases use these because the oracle
can be exact (e.g. `pixel[i]` is known by construction).

| Builder | Produces | Used for |
|---|---|---|
| `makeGrayscale8(rows:cols:fillPattern:)` | 8-bit MONOCHROME2, `pixel[i]=fillPattern(i)` | invert/mask/crop, tags, diff, info |
| `makeGrayscale16(rows:cols:fillPattern:signed:)` | 16-bit MONOCHROME2, unsigned or signed | invert VOI, window bake, HU, lossless codecs |
| `makeRGB8(rows:cols:)` | 3-sample RGB 8-bit | colour export/image, RGB codecs |
| `makeMultiFrame(rows:cols:frames:fill:)` | multi-frame 8-bit, `frame f` filled `fill(f)` | split, merge, animate, frame index |

---

## Part C — How to Run

```bash
swift test --filter DICOMRoundTripTests                          # whole suite
swift test --filter DICOMRoundTripTests.PixelEditRoundTripTests  # one tool
swift test --filter "DICOMRoundTripTests.PixelEditRoundTripTests/testInvertVOIWindowUpdated"
```

Requires the DICOMKit package to resolve (J2K/JLS/JLI/JXL SPM deps). Corpus-backed
cases skip if `Tests/DICOMRoundTripTest/Corpus/` is absent.

---

## Part D — Per-Tool Test Cases & Results

Status legend: ✅ all pass · ❌ fail (records a real bug) · ⏭️ skipped (corpus absent) ·
🕓 not yet implemented.

**Latest run:** 23 tools, **340 tool cases (+3 scaffold smoke) = 343 executed,
0 failures, 0 skipped** (corpus present). `swift test --filter DICOMRoundTripTests`.
Every assertion is an oracle; the suite found and fixed **2 real bugs** (see Part E).

`dicom-compress` and `dicom-convert` were implemented **last** (they are under
active development); pin was taken against their current committed API — **re-run
this suite after any further compress/convert changes** and update the rows below.

| # | Tool | File | Cases | Status | Representative oracles |
|---|---|---|---|---|---|
| 3.1 | dicom-pixedit | `PixelEditRoundTripTests` | 14 | ✅ | `invert∘invert==x`; signed `out==-(in+1)`; **invert updates VOI center to 65535−C** (the canonical shared-bug guard); crop updates Rows/Columns; mask fills only region; window bake endpoints |
| 3.4 | dicom-anon | `AnonRoundTripTests` | 14 | ✅ | PHI removed/replaced; SOPInstanceUID regenerated; non-PHI + pixels byte-identical; `--shift-dates` shifts; `--keep`/`--regenerate-uids` honored |
| 3.5 | dicom-tags | `TagsRoundTripTests` | 13 | ✅ | set/delete/numeric round-trip; `--delete-private` removes odd groups; `--copy-from` copies value; read-only `--tags` non-mutating |
| 3.6 | dicom-merge | `MergeRoundTripTests` | 11 | ✅ | NumberOfFrames==N; pixels == exact concatenation; **sortBy InstanceNumber asc/desc** (caught real bug); InstanceNumber→1 + fresh SOP UID; validate throws on size mismatch |
| 3.7 | dicom-split | `SplitRoundTripTests` | 11 | ✅ | multiframe→N singles, per-frame pixels match; merge→split→merge pixel-exact; frame index respected |
| 3.8 | dicom-json | `JSONRoundTripTests` | 18 | ✅ | DICOM-JSON model keys/VR; JSON→DICOM→JSON preserves tags; `--filter-tag`, `--metadata-only`, `--inline-threshold` |
| 3.9 | dicom-xml | `XMLRoundTripTests` | 11 | ✅ | valid Native XML model; XML→DICOM→XML round-trip; `--filter-tag`, `--metadata-only`, `--no-keywords` |
| 3.10 | dicom-info | `InfoRoundTripTests` | 14 | ✅ | values match independent `DICOMFile.read`; `-t/--tag` filter; `--statistics`; `--show-private` |
| 3.10 | dicom-dump | `DumpRoundTripTests` | 12 | ✅ | every tag hex `(GGGG,EEEE)` present; `--tag` filter; annotate; hex/byte layout |
| 3.11 | dicom-diff | `DiffRoundTripTests` | 16 | ✅ | A vs A → 0 diffs; single change → 1 diff naming tag; add/remove detected; `--ignore-tag`, `--compare-pixels`, `--tolerance` |
| 3.12 | dicom-validate | `ValidateRoundTripTests` | 12 | ✅ | conformant → no errors; missing SOPClassUID → error names it; broken length detected |
| 3.13 | dicom-dcmdir | `DcmdirRoundTripTests` | 20 | ✅ | create→dump lists all SOP UIDs; create→validate clean; record hierarchy; round-trip |
| 3.14 | dicom-uid | `UIDRoundTripTests` | 14 | ✅ | UID regex + ≤64; 100 unique; validate accepts/rejects; lookup known roots; regenerate changes UIDs |
| 3.15 | dicom-pdf | `PDFRoundTripTests` | 15 | ✅ | wrap → SOPClass 104.1, payload starts `%PDF`; extract == original bytes; metadata report |
| 3.16 | dicom-archive | `ArchiveRoundTripTests` | 17 | ✅ | import→list count/UIDs; dedup; query by name-wildcard/modality; export by StudyUID pixel-exact; integrity check flags corruption; stats |
| 3.17 | dicom-export | `ExportRoundTripTests` | 17 | ✅ | PNG dims == Rows/Columns; JPEG quality→size; apply-window differs from raw; bulk count; contact-sheet dims; animate GIF frame count; frame index |
| 3.18 | dicom-image | `ImageRoundTripTests` | 14 | ✅ | PNG→SC SOPClass 7 + dims; metadata flags→tags; batch N→N; UIDs unique; multi-page TIFF split |
| 3.19 | dicom-j2k | `J2KRoundTripTests` | 16 | ✅ | codestream props match dims; validate conformant/truncated; transcode J2K↔HTJ2K lossless pixel-identity; reduce levels; roi dims; compare identical MSE==0 |
| 3.20 | dicom-measure | `MeasureRoundTripTests` | 17 | ✅ | distance Pythagoras (mm/px/cm); rectangle/triangle area; angle 90°/180°; ROI mean/min/max/σ; HU slope·x+intercept; pixel raw |
| 3.21 | dicom-script | `ScriptRoundTripTests` | 17 | ✅ | validate well-formed/syntax-error; **template re-validates cleanly** (caught real bug); var substitution; step order; failure stops; `--var` override |
| 3.22 | dicom-study | `StudyRoundTripTests` | 27 | ✅ | organize hierarchy (descriptive/uid); copy vs move; summary counts; missing-series detected; stats; compare added/removed |
| 3.2 | dicom-compress | `CompressRoundTripTests` | 12 | ✅ | **lossless JPEG-LS/J2K/RLE decompress==original bit-exact**; lossy JPEG-baseline/J2K PSNR≥40 + dims preserved; decompress removes encapsulation (TS→Explicit LE, native pixels); non-pixel tags preserved; batch each output correct TS; `getCompressionInfo` |
| 3.3 | dicom-convert | `ConvertRoundTripTests` | 8 | ✅ | **Implicit→Explicit LE pixel bytes unchanged** (uses `MR.dcm` corpus); Explicit→DEFLATE re-readable + pixels stable; lossless TS round-trip pixel-exact; PNG dims==Columns/Rows; window settings honored in export |

---

## Part E — Real Bugs Found (the payoff)

These are bugs that **parity tests could not catch** because the CLI and Studio
share the same code — exactly the case this suite exists for. Both were fixed and
are now guarded by a passing oracle.

### E1. `dicom-merge --sort-by instance-number` was a silent no-op
[`FrameMerger.swift`](Sources/DICOMKit/Merging/FrameMerger.swift) sorted frames by
`dataSet.int32(for: .instanceNumber)`, but `int32Value` only decodes binary **SL**
and `InstanceNumber (0020,0013)` is **IS** (integer *string*) — so it returned nil
for every file, collapsed all keys to 0, and the sort did nothing. Multi-frame
merges silently kept input (path) order regardless of `--sort-by`.
**Caught by** `testMergeSortByInstanceNumberAscending/Descending`.
**Fix:** parse the IS string (`string(for:).flatMap(Int.init)`).

### E2. `dicom-script template pipeline|query` generated scripts that fail their own validator
The `pipeline`/`query` templates emitted `\`-continued multi-line commands, but the
script language ([`ScriptEngine.swift`](Sources/DICOMKit/Scripting/ScriptEngine.swift)
`parse`) splits strictly on newlines with **no continuation support** — so each
continuation line (`--called-aet …`) parsed as a command named `--called-aet`
("Unknown DICOM tool"). `dicom-script template pipeline | dicom-script validate`
reported errors, and the scripts would not execute.
**Caught by** `testTemplateGeneratesAndRevalidatesCleanly`.
**Fix:** emit each command on a single line (matching the `archive` template).

Neither bug is captured by any CLI-parity golden, so no golden regeneration was
needed; the release `dicom-merge` / `dicom-script` binaries were rebuilt.

---

## Part F — Known Coverage Gaps / Follow-ups

Recorded for transparency (no silent caps). `--dry-run` is excluded per request
throughout. Highlights the drafting agents flagged but did not assert:

- **dicom-validate** — level-5 (J2K/HTJ2K codestream conformance) path not exercised.
- **dicom-dcmdir** — `update` subcommand is not yet implemented in the tool.
- **dicom-image** — RGB source → `SamplesPerPixel==3`/RGB photometric not asserted as
  a passing oracle (worth a closer look at `ImageConverter.extractPixelData`).
- **dicom-archive** — plan's "second import without `--skip-duplicates` throws" does
  not hold as written (import is idempotent/dedupes); covered by the dedup oracle instead.
- **dicom-j2k** — lossy `compare` PSNR>30 & MSE>0 not asserted (no stable synthetic
  oracle); lossless transcode identity is asserted.
- **dicom-uid / dicom-json / dicom-xml** — pure CLI-adapter JSON/`--stream` formatting
  has no library-level oracle (same encode path as covered cases).
- **dicom-compress** — the plan named a distinct `JPEGLI` lossy case, but there is no
  separate `jpegli` codec name in `CompressionManager.codecMap` (JLISwift/`JLICodec`
  backs the JPEG-baseline path); covered via `jpeg-baseline` instead.
- **dicom-convert** — the plan cited `DICOMConverter.supportedTransferSyntaxes` for an
  "all TS lossless sweep"; the actual catalog symbol differs (`DICOMConverter.targets…`),
  so the sweep uses the verified per-syntax round-trips rather than that enumeration.

---

## Part G — Real CLI commands & output

The suite tests the DICOMKit *library*; this section shows the equivalent **real
CLI commands** and their **actual captured output**, so each oracle can be
reproduced from a terminal. Run against the anonymized corpus with the release
binaries (`.build/release/dicom-*`). Output is verbatim (trimmed with `…`).
Inputs: the 5 corpus files, plus `frames/` = the 12-frame `CT_Multiframe` split
into single frames, `photo.png` (16×16), `valid.pdf`.

> This section shows **one representative command per tool**. For the **complete
> per-case catalog — all 348 cases with a real CLI reproduction for 273 of them**
> — see [`ROUND_TRIP_TEST_CASES.md`](ROUND_TRIP_TEST_CASES.md).

### dicom-info — values match an independent parse (§3.10)
```console
$ dicom-info CT.dcm --tag 0008,0060 --tag 0028,0010 --tag 0028,0011 --tag 0002,0010
=== File Meta Information ===
(0002,0010) Transfer Syntax UID                      VR=UI 1.2.840.10008.1.2.1
=== Main Data Set ===
(0008,0060) Modality                                 VR=CS CT
(0028,0010) Rows                                     VR=US 512
(0028,0011) Columns                                  VR=US 512
```

### dicom-dump — tag hex/VR/length + hex bytes (§3.10)
```console
$ dicom-dump CT.dcm --tag 0028,0010 --no-color
Tag: (0028,0010)  Rows  VR=US  Length=2
00000000  00 02                                            |..|      # 0x0200 = 512
```

### dicom-validate — conformant file → VALID (§3.12)
```console
$ dicom-validate CT.dcm
DICOM Validation Report
Status: ✓ VALID
Warnings (1):
  • Unexpected VR OW for tag (7FE0,0010) (expected: OB) [(7FE0,0010)]
```

### dicom-diff — identical → 0 diffs; different → diffs (§3.11)
```console
$ dicom-diff CT.dcm CT.dcm          # identical
Total tags compared: 151
Differences found: 0

$ dicom-diff CT.dcm MR.dcm          # different files
Total tags compared: 217
Differences found: 205
```

### dicom-tags — set a tag, read it back (§3.5)
```console
$ dicom-tags CT.dcm --set 0010,0010=ROUND^TRIP^TEST --output tagged.dcm && dicom-info tagged.dcm --tag 0010,0010
(0010,0010) Patient's Name                           VR=PN ROUND^TRIP^TEST
```

### dicom-anon — PHI removed / hashed, identity flag set (§3.4)
```console
$ dicom-anon CT.dcm --output anon.dcm --profile clinical-trial --regenerate-uids && dicom-info anon.dcm --tag 0010,0010 --tag 0010,0020
(0010,0010) Patient's Name                           VR=PN ANONYMOUS
(0010,0020) Patient ID                               VR=LO FCCACBCE93F9CE711ACE6D10FDE5E9B0
```

### dicom-uid — valid, unique; validator accepts a known UID (§3.14)
```console
$ dicom-uid generate --count 3
1.2.276.0.7230010.3.1782902314801056.203660
1.2.276.0.7230010.3.1782902314801681.909734
1.2.276.0.7230010.3.1782902314801694.181368
$ dicom-uid validate 1.2.840.10008.1.2.1
✅ 1.2.840.10008.1.2.1
```

### dicom-json — DICOM-JSON model carries Modality under key 00080060 (§3.8)
```console
$ dicom-json CT.dcm --metadata-only --output ct.json && python3 -m json.tool ct.json | grep -A3 '"00080060"'
    "00080060": {
        "Value": [
            "CT"
        ],
```

### dicom-xml — Native DICOM XML model, Modality element (§3.9)
```console
$ dicom-xml CT.dcm --metadata-only --output ct.xml && grep -m1 -A1 00080060 ct.xml
<DicomAttribute tag="00080060" vr="CS" keyword="Modality">
  <Value number="1">CT</Value>
```

### dicom-merge — 3 frames → NumberOfFrames=3, sorted by InstanceNumber (§3.6) ⭐ *fixed-bug demo*
```console
$ dicom-merge frame_0 frame_1 frame_2 --output merged.dcm --sort-by InstanceNumber && dicom-info merged.dcm --tag 0028,0008
(0028,0008) Number of Frames                         VR=IS 3
```
*(Before the fix, `--sort-by InstanceNumber` was a silent no-op — see Part E1.)*

### dicom-split — 12-frame → 12 single-frame files (§3.7)
```console
$ dicom-split CT_Multiframe.dcm --output frames/
frames produced: 12
$ dicom-info frames/CT_Multiframe_frame_0000.dcm --tag 0020,0013 --tag 0028,0008
(0020,0013) Instance Number                          VR=IS 1
(0028,0008) Number of Frames                         VR=IS 1
```

### dicom-measure — distance / HU / ROI stats (§3.20)
```console
$ dicom-measure distance CT.dcm --p1 0,0 --p2 3,4 --unit pixels
Distance: 5.0 px                     # √(3²+4²) = 5, oracle-exact
$ dicom-measure hu CT.dcm --point 256,256
Hounsfield Unit: -3.0 HU
$ dicom-measure roi CT.dcm --rect 100,100,16,16 --statistics
ROI Analysis: Rectangle (100,100 16x16)
  Pixel count: 256
  Mean: -999.6602    Std Dev: 3.8858    Min: -1009.0    Max: -989.0
```

### dicom-compress — lossless compress → info; decompress restores Explicit LE (§3.2)
```console
$ dicom-compress compress CT.dcm --output ct_jls.dcm --codec jpeg-ls-lossless && dicom-compress info ct_jls.dcm
Transfer Syntax: JPEG-LS Lossless
Transfer Syntax UID: 1.2.840.10008.1.2.4.80
Compressed: Yes   Lossless: Yes   Codec: JPEG-LS
Image Dimensions: 512 x 512
$ dicom-compress decompress ct_jls.dcm --output ct_dec.dcm && dicom-info ct_dec.dcm --tag 0002,0010
(0002,0010) Transfer Syntax UID                      VR=UI 1.2.840.10008.1.2.1
```

### dicom-convert — Implicit VR → Explicit VR LE; PNG export dims (§3.3)
```console
$ dicom-convert MR.dcm --output mr_explicit.dcm --transfer-syntax ExplicitVRLittleEndian
MR.dcm (source) TS: 1.2.840.10008.1.2       # Implicit VR LE
converted   TS: 1.2.840.10008.1.2.1         # Explicit VR LE
$ dicom-convert CT.dcm --output ct_conv.png --format png
  pixelWidth: 512
  pixelHeight: 512
```

### dicom-export — single-frame PNG, dims == Rows/Columns (§3.17)
```console
$ dicom-export single CT.dcm --output ct_export.png --format png
  pixelWidth: 512
  pixelHeight: 512
```

### dicom-image — PNG → Secondary Capture (SOP 1.1.7), dims + metadata (§3.18)
```console
$ dicom-image photo.png --output sc.dcm --patient-name ROUND^TRIP --patient-id RT001 && dicom-info sc.dcm --tag 0008,0016 --tag 0028,0010 --tag 0010,0010
(0008,0016) SOP Class UID                            VR=UI 1.2.840.10008.5.1.4.1.1.7
(0010,0010) Patient's Name                           VR=PN ROUND^TRIP
(0028,0010) Rows                                     VR=US 16
```

### dicom-pdf — wrap PDF → SOP 104.1; extract is byte-identical (§3.15)
```console
$ dicom-pdf valid.pdf --output pdf.dcm --patient-id RTDOC01 --title 'RT Report' && dicom-pdf pdf.dcm --output extracted.pdf --extract
SOP Class: 1.2.840.10008.5.1.4.1.1.104.1
payload magic: %PDF
extract byte-identical: YES
```

### dicom-dcmdir — create from a directory, dump the record tree (§3.13)
```console
$ dicom-dcmdir create frames/ --output frames/DICOMDIR && dicom-dcmdir dump frames/DICOMDIR
DICOMDIR: frames
├─ Profile: STD-GEN-CD
├─ Consistent: true
└─ Records:
    └── PATIENT - ANONYMOUS (ID: 35665E3D6A2007CA7AC094224C7E63EE)
        └── STUDY - MRI CARDIAC [20270603]
            └── SERIES - MR - localizer_tfl_db_heart
                └── IMAGE #1 (CT_Multiframe_frame_0000.dcm)
```

### dicom-archive — init → import → stats/query by modality (§3.16)
```console
$ dicom-archive init --path arch && dicom-archive import frames/*.dcm --archive arch && dicom-archive query --archive arch --modality MR
Patient Name  | Patient ID       | Study Date | Modality | Description | Series | Images
ANONYMOUS     | 35665E3D6A2007…  | 20270603   | MR       | MRI CARDIAC | 1      | 12
Found 1 matching study(ies)
```

### dicom-j2k — codestream info matches DICOM geometry (§3.19)
```console
$ dicom-j2k info j2klossless.dcm
Transfer Syntax:  JPEG 2000 Lossless (1.2.840.10008.1.2.4.90)
Width:            512 px
Height:           512 px
Components:       1
Grayscale:        Yes
```

### dicom-script — generated template re-validates cleanly (§3.21) ⭐ *fixed-bug demo*
```console
$ dicom-script template pipeline > pipeline.dcmscript && dicom-script validate pipeline.dcmscript
# DICOM Pipeline Script
# Pipeline: query -> retrieve -> validate -> anonymize -> archive
PACS_HOST=pacs.example.com
--- dicom-script validate pipeline.dcmscript ---
✓ Script is valid
```
*(Before the fix, this reported "Unknown DICOM tool '--called-aet'" — see Part E2.)*

### dicom-study — summary counts series/instances (§3.22)
```console
$ dicom-study summary frames/ --format table
Study UID: 1.2.276.0.7230010.3.1782891683260515.969693
Patient Name: ANONYMOUS
Description: MRI CARDIAC
Series Count: 1
Total Instances: 12
```
