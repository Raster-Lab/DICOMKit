# Round-Trip Tests Plan V2 — Non-Network Tools

**Date:** 2026-07-04 · **Input:** `CLI_TOOLS_SHARED_CORE_VERIFICATION.md` (three-axis audit of all 40 tools) · **Scope: non-network `dicom-*` tools only** (user decision 2026-07-04).

> **STATUS UPDATE (2026-07-04, remediation batch):** user triage HELD 11 tools
> (measure, viewer, 3d, ai, report, gateway, cloud, server, j2k, jpip, print) — Tiers 1.1, 1.2,
> 2.1–2.4, 2.7, 2.8 are **on hold** with them. Executed from this plan so far:
> **Tier 3 fixes + same-change oracles** — N2 merge enhanced (2 oracles), N3 script `--parallel`
> (2 oracles), N14 dcmdir `update` (2 oracles) all implemented and tested; N5 json
> `--format`/`--stream` REMOVED (no oracle needed); N7 image `--use-exif` fixed (per-page EXIF
> oracle still pending — needs an EXIF-bearing multi-page TIFF fixture, CoreGraphics-gated);
> N4 compress `--backend` implemented (no RT oracle — GPU-vs-CPU byte identity is
> hardware-dependent; covered by codec unit tests). Tier 2.5 (json/xml workflow) was pulled
> forward and DONE — `DataExchangeWorkflow` now owns the pipeline on both surfaces (workflow-level
> oracles remain a follow-up). Tier 1.3 remains with the user's convert/compress branch.

**Baseline:** 387 passing oracle tests across 23 suites (`Tests/DICOMRoundTripTest/` — the
suites themselves are the catalogue; the `ROUND_TRIP_TEST_CASES.md` doc was removed
2026‑07‑17 for embedding real-corpus PHI-derived excerpts), incl. the 40-test coverage
pass. This plan covers what the
three-axis verification newly exposed: shared APIs that exist but have no round-trip suite,
suites that test a **re-implementation instead of the shipping engine**, and engines that must
move into a shared target before a real round-trip test is even possible.

## Scope

**In (27 tools):** info, dump, tags, diff, json, xml, anon, uid, pixedit, merge, split,
validate, image, export, measure, viewer, 3d, ai, convert, compress, j2k, pdf, report, study,
dcmdir, archive, script.

**Out (13 — network/integration; no round-trip tests will be written):** echo, query, retrieve,
qr, send, mwl, mpps, wado, jpip, print, server, gateway, cloud. Their offline seams are already
covered elsewhere (`DICOMNetworkTests` message-encode layer, `CLIParity*ParityTests` formatter
diffs). *(dicom-gateway's local file converters could join Tier 2 later if its engine is ever
extracted — out of scope for now.)*

**Ground rules (unchanged from V1):**
- A test drives the **same shared library API** the CLI and app call — never the binary, never a
  re-implementation of the pipeline under test.
- The oracle asserts a **mathematical or semantic invariant** (byte identity, PSNR bound,
  geometry, grammar/format validity, differential behavior), not agreement with a second
  implementation of the same logic.
- Inert flags are **not testable** — they go to the fix-first list (Tier 3), then get a
  differential oracle after the fix.

---

## Tier 1 — Writable now (shared API already exists, no code changes needed)

### 1.1 dicom-3d · JP3D subcommands → NEW suite `JP3DRoundTripTests.swift`

The only dicom-3d functionality in a shared target: `JP3DVolumeDocument`, `JP3DCodec`,
`CodecBackendProbe` (used by `encode-volume` / `decode-volume` / `inspect` / `backends`).

| # | Test case | Oracle |
|---|---|---|
| 1 | encode-volume → decode-volume, lossless | decoded voxels byte-identical to the synthetic source volume |
| 2 | encode-volume lossy → decode | PSNR ≥ threshold vs source; dims/bit-depth preserved |
| 3 | inspect on encoded output | `JP3DVolumeDocument.isJP3DVolumeDocument` true; false for a plain Part-10 file |
| 4 | decode of truncated/corrupted stream | throws (no silent partial volume) |

Fixture: synthetic gradient volume built in-test (rows×cols×slices, deterministic fill) — no
corpus addition needed.

### 1.2 dicom-report · SR parsing (partial) → NEW suite `ReportRoundTripTests.swift`

Only `SRDocumentParser` (DICOMKit) is shared; the generator is Tier 2 (E5). Still worth locking
the shared half now:

| # | Test case | Oracle |
|---|---|---|
| 1 | build minimal SR dataset (Basic Text SR: container + text + code items) → parse | parsed content tree reproduces the node types/values/relationships put in |
| 2 | SR with measurement (NUM item + units) → parse | numeric value + unit code survive exactly |
| 3 | non-SR file → parse | fails cleanly (documented error, no crash) |

### 1.3 dicom-convert / dicom-compress (in-flight branch — land with the user's current work)

These were deferred while under active edit; the verification found the branch itself introduces
the one cross-tool risk. When the branch settles:

| # | Test case | Oracle | Guards |
|---|---|---|---|
| 1 | codec-token map consistency | `dicom-compress` and `dicom-convert` resolve `jpeg-xl`/`jxl`/`jxl-lossless` tokens to the **documented** TS UIDs; single assertion table for both maps | D8 (today convert=lossless .110, compress=lossy .112 — encode the *decided* policy, not the accident) |
| 2 | compress batch discovery contract | `CompressionManager.findDICOMFiles` finds extensionless-DICM + nested + skips non-DICOM; deterministic order | D6 (app must adopt the same finder; test pins the shared contract) |
| 3 | JPEG-XL VarDCT grayscale fallback | grayscale source + lossy jxl → output TS is the **lossless** syntax (documented silent fallback becomes an asserted contract) | memory: JXLSwift VarDCT is RGB-only |
| 4 | convert JPEGXLRecompression (.4.111) | already covered in ConvertRoundTripTests — keep; add decode-identity assertion if missing | new target in DICOMConverter.targets |

### 1.4 Small deferred items now confirmed shared (optional batch)

From the V1 gaps doc, re-validated as shared by the audit — cheap to add:
`dcmdir validate --check-files/--detailed` (DICOMDIRWorkflow.renderValidationReport contains
per-file section iff checkFiles), `dcmdir create --strict` (strict failure differential),
`archive` default renderers (query→table / list→tree / stats→text non-empty grammar), `info
--force` (malformed file parses with force, errors without).

---

## Tier 2 — Blocked on extraction (engine must move to a shared target first)

Order = leverage. Each entry: the move, then the oracles that become possible.

### 2.1 dicom-measure (E1) — HIGHEST VALUE
**Move:** `MeasurementEngine` + `formatResult`/`formatROIResult`/`formatValue` from
`Sources/dicom-measure/` → `Sources/DICOMKit/Measurement/`.
**Why first:** `MeasureRoundTripTests` currently re-implements the math (its own header admits
it) — the **shipping engine has zero test coverage**. This is the audit's clearest case of a
green suite that proves nothing about the product.
**Then:** re-point all 12 existing measure tests at the real engine (delete the parallel math);
add: `roi --polygon` (shoelace-area oracle), `--histogram --bins N` (bin count + sum==pixel
count), `--format json/csv` (valid JSON / RFC-4180 row count), `hu --rect` unit handling (after
N11 fix).

### 2.2 dicom-j2k (E9)
**Move:** transcode/reduce/roi pipelines incl. the DICOM re-wrap (pixel element + FMI patch)
→ shared `J2KToolWorkflow` in DICOMKit.
**Then:** `roi` — crop of a marked region decodes to exactly the source sub-rectangle (the
audit flagged the inline ceil-based subsampling math as an untested correctness hotspot);
`reduce --levels k` — decoded dims = ⌈orig/2^k⌉; `transcode` — J2K↔HTJ2K decoded-pixel identity
**through the tool workflow** (today only the J2KSwift primitives are covered); output file FMI
transfer-syntax tag matches the codestream.

### 2.3 dicom-report generator (E5)
**Move:** `ReportGenerator` + `ReportOptions`/`ReportLanguage`/`ReportTemplate`/`ReportFormat`
→ `Sources/DICOMKit/StructuredReporting/`.
**Then:** text/markdown deterministic + contains SR content values; html parses (XML-wellformed
body); json valid + round-trips the content tree; `--language` differential (labels change,
values don't); `--include-measurements`/`--include-summary` differentials; `--format pdf` after
N10 is fixed or the case removed.

### 2.4 dicom-3d reconstruction (E3)
**Move:** `VolumeLoader`/`VolumeData`/`MPRGenerator`/`ProjectionRenderer`/`SurfaceExtractor`.
**Then (pure-math oracles, synthetic geometric volume):** axial MPR slice k == source slice k;
sagittal/coronal slice == transposed gather (exact index math); MIP pixel == max over slices;
minIP == min; average == mean (±rounding); surface extraction on a synthetic sphere — all
vertices within ε of the iso-surface radius. `mpr --format dcm` and `--planes oblique` only
after N8 fixes.

### 2.5 json/xml orchestration (P1)
**Move:** create `JSONConversionWorkflow`/`XMLConversionWorkflow` in DICOMKit owning
read→filter→(metadata-only)→encode→write + default output-path derivation + verbose lines; CLI
and app both call it (resolves divergence D4 by construction).
**Then:** default output path = `<input>.json`/`.xml`; write-vs-console behavior contract;
filter/metadata-only **through the workflow** (current tests cover primitives only); reverse
round-trip through the workflow produces a readable Part-10 file.

### 2.6 Shared gatherer + console builders (P2/P3, enables console oracles)
**Move:** adopt the split/send pattern — one shared directory-gatherer and per-tool console
builder for anon, merge, validate, convert, image, pdf, export. This is primarily the fix for
divergences D1/D2/D3; the round-trip payoff:
gatherer contract test (sorted order, hidden-file policy, extensionless DICM detection — one
suite, reused by every tool that adopts it); `ValidationReport.renderText` regression-lock
(exact grammar; **no** `Exit code:` block — pins D1's fix).

### 2.7 dicom-viewer (E2) — LOWEST PRIORITY
Only if `TerminalRenderer` is ever extracted: ASCII render dims == requested WxH; `--invert`
reverses luminance ordering; deterministic output for a fixed fixture. Otherwise skip.

### 2.8 dicom-ai (E4) — RECOMMEND SKIP
Real inference needs CoreML models and is environment-dependent — not oracle-testable in this
suite. If ever needed: registry CRUD round-trip only (add→list→info→remove).

---

## Tier 3 — Fix first, then test (inert surfaces from the N-register)

No test can be written against these until the code is fixed (or the surface removed); each
line names the differential oracle to add *after* the fix:

| Finding | Post-fix oracle |
|---|---|
| N2 merge `--format enhanced-ct/mr/xa` | output SOP Class == Enhanced CT/MR/XA Image Storage; functional-group sequences present; `standard` unchanged |
| N3 script `--parallel` | injected runner records overlapping execution windows (or documented removal) |
| N4 compress `--backend` | forced scalar vs metal produce identical bytes (lossless) / both decode (lossy); backend actually reaches the codec |
| N5 json `--format dicomweb` | dicomweb output uses DICOMweb JSON model semantics vs standard |
| N7 image `--use-exif` + `--split-pages` | EXIF-bearing multi-page TIFF propagates EXIF into each SC frame |
| N8 3d `volume`/`mpr --format dcm`/oblique | see 2.4 |
| N10 report `--format pdf` | output starts `%PDF-` |
| N11 measure `hu --rect --unit` | unit conversion applied (see 2.1) |
| N14 dcmdir `update` | added file appears in directory record set; validate passes |

(N1/N6/N16 are app/network-side or excluded-tool items — tracked in the verification doc, not
this plan.)

---

## Corpus / fixture additions

| Fixture | For | How |
|---|---|---|
| Synthetic geometric volume (e.g. 16×16×8, slice-indexed gradient + one landmark voxel per slice) | 3d MPR/MIP/JP3D | built in-test (`RoundTripFixture.makeVolume`) — deterministic, no files |
| Minimal SR documents (text SR, NUM measurement SR) | report | built in-test from DataSet (no corpus file needed) |
| Synthetic sphere volume | 3d surface | built in-test |
| Existing 5-file anonymized corpus + multi-frame/ct8 fixtures | everything else | unchanged |

## Execution order & doc upkeep

1. **Tier 1.1 + 1.2** (new suites, no code moves) → ~9 tests.
2. **Tier 1.3** with the convert/compress branch landing (token-map policy decided first).
3. **Tier 2.1 measure extraction** — highest-value correction to the existing suite.
4. **Tier 2.2 j2k**, then **2.3 report**, then **2.5 json/xml workflow**, then **2.4 3d recon**, then **2.6 gatherer/console**, interleaved with the D-register fixes they enable.
5. Tier 3 items ride along with their code fixes (same-change rule: fix + oracle together).

After each batch: run `swift test --filter DICOMRoundTripTests` (expect current 387 + new, 0
skips), and update the status column in `ROUND_TRIP_COVERAGE_GAPS.md`. Do **not** re-create a
prose case catalogue that pastes corpus output — that is why `ROUND_TRIP_TEST_CASES.md` was
removed; document new cases in the test files themselves.
Per the wire-parity rule, any CLI-visible change (Tier 3 fixes)
also regenerates `CLIContracts.json`/goldens and rebuilds both binaries.
