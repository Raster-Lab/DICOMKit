# Research Adoption Execution Plan — Performance, Memory, Streaming & Codec Hand-off

**Status:** Proposed — awaiting human approval per milestone. No milestone starts until approved.
**Date:** 2026-08-10
**Governing docs:** `Documentation/ResearchAdoption/` (instructions v0.1.0, shared benchmark
baseline, evidence register) · evidence base:
`Documentation/ResearchAdoption/Current_State_Reconciliation_and_Gap_Report_v0.1.0.md` (gap
report; all file:line claims below are substantiated there) · `ECOSYSTEM_COMPARISON.md` §4.1/§5.

**Ground rules (apply to every milestone):**
- One controlled change at a time; release-build measurement before/after; raw benchmark
  output committed as a versioned artefact under `Tests/Benchmarks/Artifacts/`.
- No speed-up claim without commit, device, dataset, iteration count and median+tail statistic.
  Never multiply layer speed-ups.
- Lossless output must be byte/sample-exact vs. baseline; round-trip suite
  (`swift test --filter DICOMRoundTripTests`) green at every merge.
- Public API compatibility preserved; new capability lands as additive API.
- All work local until explicitly told to commit/push.

---

## M0 — Parser & protocol hardening (safety, not performance) ✅ DONE 2026-08-10

*Delivered: `maxSequenceDepth` (default 64) / `maxElementLength` / `maxTotalElements` /
`maxFragmentCount` in `ParsingOptions`; `DICOMError.limitExceeded`; limit violations
rethrown past skip-recovery; `PDUDecoder.maximumPDULength` (128 MB) guard;
`ParserLimitTests` incl. seeded mutation fuzz (100 000-input acceptance run clean —
after fixing two real out-of-bounds crashes the fuzzer found: oversized explicit
sequence/item lengths advancing `offset` past `data.count`, and the unclamped
raw-span `subdata` in `parseSequenceElement`). Round-trip suite green; the 5
pre-existing Metal-environment test failures reproduce on unmodified HEAD.*

*Rationale: live crash/DoS risks; explicitly P0 in both the instructions (§17) and
ECOSYSTEM_COMPARISON (§4.1). Needs no benchmark gate — correctness only.*

Scope:
1. `ParsingOptions` gains `maxSequenceDepth` (default ~64), `maxElementLength`,
   `maxTotalAllocation`, `maxFragmentCount`; `maxElements` enforced inside sequence items,
   not just the top-level loop (`DICOMParser.swift:94`).
2. Depth counter threaded through the mutually recursive sequence path
   (`parseSequenceElement` → `parseUndefinedLengthSequence` → `parseSequenceItem` →
   `parseUndefinedLengthItem` → element parsers); violation → structured
   `DICOMError.limitExceeded`, never a crash.
3. Guard the `length == 0xFFFFFFFF` non-SQ recursion hole (`DICOMParser.swift:698-706`).
4. Mirror depth/size limits in `PDUDecoder`.
5. Corpus-driven mutation fuzz test (round-trip corpus + random byte mutation) over
   `DICOMParser.parse`, `PDUDecoder.decode`, each codec `decode` — must not crash, only throw.

Exit criteria: nested-sequence bomb and 4 GB-length files fail closed with
`limitExceeded`; fuzz run (≥10⁵ mutated inputs) crash-free; all existing tests green;
defaults do not reject any file in the round-trip corpus.

## M0.1 — Fuzz scope completion (closes M0 scope item 5) ✅ DONE 2026-08-11

M0 shipped the *limits* in full but fuzzed only `DICOMParser.parse`. Scope item 5 also
named `PDUDecoder.decode` and "each codec `decode`"; those two surfaces are now covered.

*Delivered:*
- `Tests/DICOMNetworkTests/PDUFuzzTests.swift` — mutation fuzz over a valid A-ASSOCIATE-RQ
  (reaching every sub-item parser: Application Context, Presentation Context, Abstract/
  Transfer Syntax, User Information) and P-DATA-TF; all 256 PDU type bytes against
  truncated bodies; sub-item length overrun; and the `maximumPDULength` rejection asserted
  rather than merely survived. **Result: clean at 4 × 10⁵ inputs — no defects found.**
- `Tests/DICOMCoreTests/CodecFuzzTests.swift` — RLE header/segment fuzz (the RLE header is
  wholly attacker-controlled: segment count + 15 offsets), adversarial segment offsets
  including `0xFFFFFFFF`, truncation at every length, and §17 "invalid character-set
  transitions" over 10 Specific Character Sets with ESC-biased random bytes.
- **One real defect found and fixed** — see below.

### Defect: `RLECodec` trapped on a non-zero-`startIndex` `Data` (SIGTRAP)

`decodeSegments` (and the older `decodeFrame`) read the RLE header with
`readUInt32LE(at:)`, which is **slice-relative**, then sliced the segment payload with
`subdata(in:)`, which indexes **absolutely**. Given a `Data` whose `startIndex` is not 0,
the two index spaces are mixed and the decoder traps — `EXC_BREAKPOINT` in
`Data._Representation.subscript.getter`, not a thrown error. Fixed by rebasing on
`frameData.startIndex` in both paths; regression guards assert that decoding a slice is
byte-identical to decoding the equivalent contiguous buffer, on both the `Data`-returning
and the caller-owned (WP-F) path.

**Reachability, stated precisely:** *not* reachable through `DICOMFile.read` today, because
`DICOMParser` builds fragments with `data.subdata(in:)`, which copies and rebases to
`startIndex == 0`. It *is* reachable through the public API — `RLECodec` and
`EncapsulatedPixelData.init(offsetTable:fragments:descriptor:)` are both public and accept
caller-supplied `[Data]`, and slicing a buffer is the natural zero-copy idiom. It becomes
reachable on the main path the moment WP-A/WP-D land, since the entire point of
`DICOMByteSource` and `BulkDataHandle` is to stop copying. Fixing it before that work is
sequencing, not luck.

### Follow-up raised (not actioned — needs the §19 copy map first)

The same relative-offset-into-`subdata(in:)` pattern appears at ~35 further sites
(`TransferSyntaxConverter`, `NativeJPEG2000Codec`, `StorageService`, `QueryService`,
`CommandSet`, `StorageCommitment{SCP,Service}`, `ModalityWorklistService`,
`SiemensCSAHeaderParser`, `JP3DCodec`, `MessageAssembler`, …). Two files already carry
comments showing someone hit this before; `J2KCodestreamInspector` has the correct pattern
in an `absolute(data:_:)` helper. Instruction §1.4 requires the source→parser→codec→renderer
copy map before a broad refactor, so this is logged rather than swept. **Recommended as a
precondition for M3/WP-D, not as independent cleanup** — the copy map has to identify which
of those sites a `BulkDataHandle` slice can actually reach.

*Verification:* full suite **7,312 tests / 730 suites**, green apart from the two items
below. Deep fuzz (`DICOM_FUZZ_ITERATIONS=200000`) clean across all three harnesses. No
benchmark gate — correctness only, per the M0 precedent.

*Two non-blocking test issues, both pre-existing:*
1. `NativeJPEG2000Codec` 12-bit encode carries a `withKnownIssue`; reproduces on
   unmodified HEAD.
2. `PrintSCPScreenTests` "a film sent by a Print SCU is received, composed and listed"
   fails intermittently under full-suite load (≈3 runs in 6), and passes 3/3 in isolation
   (0.045 s). Cause is in the test, not the product: `PrintSCPScreenTests.swift:595`
   polls `viewModel.films.isEmpty` for at most 100 × 50 ms, so a real SCU→SCP socket
   round-trip that exceeds 5 s under parallel load fails the poll and then the
   `filmCount == 1` assertion. Load-dependent, not caused by the RLE or JPIP changes
   (neither touches the print path). **Recommend raising the budget or making the wait
   event-driven on `.filmPrinted`** — a bounded sleep-poll in an end-to-end socket test
   will keep flaking in CI.

## F1 — JPIP is advertised as working but has no functional retrieval path ⚠️ OPEN 2026-08-11

Raised under instruction §4 (documentation correction) and shared-baseline §9 ("do not
silently exclude failures or unsupported data"). Found while auditing the M5 deferred
JPIP items.

**Finding.** Every retrieval entry point in the upstream J2KSwift `JPIP` module (pinned at
11.0.2, revision `b194908`) is an unimplemented stub that throws
`J2KError.notImplemented`: `requestImage`, `requestRegion`, `requestProgressiveQuality`,
`requestResolutionLevel`, `requestComponents`. `DICOMJPIPClient` wraps four of these and
presents them as working public API, and `dicom-jpip` calls all four — so the tool fails at
runtime for every real invocation.

The 39 tests in `JPIPTests.swift` all pass, and none of them exercises a retrieval call:
they cover URI parsing, transfer-syntax flags, enum storage and error-description strings.
Green tests around a non-functional feature are precisely the failure mode §9 warns about.

**Actioned now (documentation honesty only):**
- README: the JPIP bullet, the transfer-syntax compliance table (`.94`/`.95` → "⚠️ URI
  only") and the feature list now state that URI extraction works and retrieval does not.
- `DICOMJPIPClient.fetchRegion` no longer reports `quality`'s layer count as the fetched
  fidelity. The upstream `requestRegion` takes no quality argument, so the value was never
  sent; labelling the result with an unrequested fidelity violates §12's requirement that
  refinement state be explicit *and* true. Reports 0 ("unknown") until upstream carries it.
- `ECOSYSTEM_COMPARISON.md` §1 credited JPIP as shipped capability; corrected there too.

**Decision (user, 2026-08-11): option 2 — mark the DICOMKit API unavailable until JPIP
lands upstream.** Implemented same day:

- The four retrieval methods on `DICOMJPIPClient` (`fetchImage`, `fetchRegion`,
  `fetchProgressiveQuality`, `fetchResolutionLevel`) and the two JPIP-backed volume APIs
  (`DICOMFile.openVolume(from:jpipServerURL:)`, `DICOMFile.openVolumeProgressively`) are
  `@available(*, unavailable, message:)` naming the upstream cause and this finding.
  Six APIs, not four — the volume audit found the extra two, and `openVolumeProgressively`
  was the worst variant: it swallowed the upstream error per-slice (`try?` + skip) and
  finished as an *empty stream*, indistinguishable from "no data".
- New `DICOMJPIPError.retrievalUnavailable`, distinct from `.jpipModuleUnavailable`
  (module linked but no implemented request path vs. module absent).
- Unavailable bodies stubbed (Swift forbids an unavailable function calling another
  unavailable function); originals recoverable at git `de67c39`, to be restored when
  upstream lands.
- Callers updated to fail loudly instead of at runtime: `dicom-jpip fetch` exits 1 with
  the cause and the resolved target URI (`uri`/`serve`/`info` untouched and working);
  `dicom-viewer --jpip` errors with pointers to `dicom-wado`/`dicom-retrieve`;
  DICOMStudio's `loadFromJPIP` sets `.failed(reason:)` with the real cause instead of a
  spinner that never resolves. CLI `--help`/abstracts state fetch is unavailable.
- The two `JPIPTests` that asserted the *silent-empty-stream* behaviour are replaced by
  tests of the new error's contract (message names the upstream cause; distinct from
  `.jpipModuleUnavailable`). JPIP suite 39 tests green; full suite 7,312 green.

Option 1 (implement JPIP response parsing in J2KSwift) remains the real fix and now has a
clean landing site: delete the annotations, restore the stubbed bodies from `de67c39`.

The second JPIP defect named in M5 ("unused `resolutionLevel`") is **not** a defect:
`DICOMJPIPQuality.resolutionLevel(Int)` is a legitimate enum case and
`fetchResolutionLevel` passes `level` through correctly. Removing it from the M5 list.

## M0.2 — Copy-path map (§1.4 / §19 deliverable 5, static half) ✅ DONE 2026-08-11

*Delivered: `Documentation/ResearchAdoption/Copy_Path_Map_v0.1.0.md` — all 74
`subdata(in:)` sites classified (A correct-absolute / B rebase-at-entry / C
safe-fresh-internal / D latent-via-parser-rebase), selected-frame copy counts per codec
family at file:line, and the gated fix/keep checklist. Producing it found **two more
publicly-reachable slice crashes** of the RLE class, both proven by a failing test first:
`DICOMFile.read(from: Data)` (parser mixes relative reads with absolute `subdata`;
`hasDICMPrefix` silently misreads) and `TransferSyntaxConverter.transcode(dataSetData:)`.
Both fixed with a boundary rebase (copy only when input is genuinely a slice) +
`SliceIndependenceTests` (new, in the DICOMKitTests allowlist). Class-D sites (17) are
deliberately NOT swept — gated on WP-D/M3 per the checklist. Full suite 7,312 green.
Dynamic copy-count telemetry remains for M3, which this map baselines.*

## F2–F8 — Ecosystem-study open items, fixed one by one ✅ 2026-08-11

Batch closing the open findings from `ECOSYSTEM_COMPARISON.md` §4–§5, each verified by test.

- **F2 Modality LUT Sequence precedence (PS3.3 C.11.1).** The main pixel pipeline applied
  Rescale Slope/Intercept unconditionally; no consumer checked (0028,3000) — the fo-dicom
  #1986 analogue, a silent wrong-pixels bug. `DataSet.modalityLUT()` added; `rescaleSlope()`/
  `rescaleIntercept()` return identity and `rescale(_:)` maps through the LUT (with PS3.3
  clamping) when the sequence is present; malformed sequences fail open to linear.
  `ModalityLUTPrecedenceTests` (5).
- **F3 README limitations table.** Removed provably-wrong rows ("JPEG-LS not supported",
  "Storage Commitment not implemented", "7+ Transfer Syntaxes"); corrected to 29 TS, JPEG-LS
  supported, Storage Commitment SCU+SCP, Modality LUT; added the *real* open items (JPIP F1,
  MWL SCP, IPv6, PS3.15 coverage-in-progress).
- **F4 Print SCP flake.** Two independent async signals (`films` array vs `filmCount`
  counter); the test polled the first and asserted the second → fast, misleading
  `filmCount == 0` failures under load. Poll now waits on both. (An earlier budget bump
  addressed the wrong race; this is the actual fix.)
- **F5 PDU structured limit error.** New `DICOMNetworkError.limitExceeded`, distinct from
  `.decodingFailed`; both `PDUDecoder` PDU-length guards throw it; all exhaustive switches
  updated; fuzz test asserts it.
- **F6 NativeJPEG2000 12-bit "known issue".** Probed the real behaviour: ImageIO does NOT
  throw on 12-bit grayscale JPEG 2000 — it decodes and *silently collapses samples to the
  8-bit range* (the note claimed a decode failure). Replaced the permanent `withKnownIssue`
  with a real test pinning both the ImageIO corruption and the exact `J2KSwiftCodec`
  round-trip. **Suite now has zero known issues.**
- **F7 PS3.15 Annex E de-identification engine** — the largest §4.2 gap. New
  `ConfidentialityProfile` (Table E.1-1 action codes D/Z/X/K/C/U + a curated
  direct-identifier table, ≥60 rows) and `ConfidentialityEngine` (recursive sequence
  descent; VR sweeps — all residual PN removed, all instance UIDs consistently
  regenerated, all private tags removed; E.3 retention options; records (0012,0062)/
  (0012,0063)). Exposed as `Anonymizer.deidentify(file:options:uidMap:)` and
  `dicom-anon --profile ps315` with `--retain-dates/-characteristics/-device/-institution/
  -uids` and `--clean-descriptors`. Legacy profiles untouched. `ConfidentialityProfileTests`
  (11). **Honest coverage note:** the explicit table is the direct-identifier core, not all
  ~530 Table E.1-1 rows; the VR sweeps are the safety net for the remainder. Full-table
  expansion and a term-safe descriptor cleaner (the C action currently fails safe by
  zeroing) are follow-ups.
- **F8 §5 cross-toolkit test matrix.** `CrossToolkitMatrixTests` (8) turns the shipped-bug
  scenarios from other toolkits into regressions against our code: window width < 1 stays
  finite (fo-dicom #1905), unit-width window still discriminates (dcm4che #1513), empty
  rescale is identity (fo-dicom #1975), tiny Rescale Slope does not size an allocation
  (dcm4che #1499 — architecturally immune, our rescale is arithmetic not a LUT), trailing
  delimiter items still parse (fo-dicom #1958), empty Pixel Spacing does not trap
  (fo-dicom #2043), ISO 2022 decode does not leak escape state (dcm4che #1503). **All pass
  as written** — the only real bug in the §5 set was Modality LUT precedence (F2); the rest
  confirm DICOMKit was already correct, now pinned.

**Verification for F2–F8:** full suite **7,312 tests / 730 suites green, 3 consecutive runs**
(the Print SCP flake that failed 2/4 before F4 now passes 3/3). Zero known issues.

## M1 — Benchmark baseline (measurement before optimisation) ✅ DONE 2026-08-10

*Delivered: `DICOMBenchmark.measureDetailed` (monotonic clock, per-iteration
samples, median/P90/P95/min/max/stddev, concurrent `ResidentMemorySampler`
high-water tracking, cold-run capture) — legacy API untouched;
`BenchmarkBaselineTests` runner (gated by `DICOM_BENCHMARK_BASELINE=1`, release
build, deterministic seeded synthetic instances + optional local corpus files);
first release-build artifact recorded at `Tests/Benchmarks/Artifacts/`
(Mac16,13, 10 cores, macOS 26.6, commit de67c39-dirty). Headline baseline: on the
C09-class synthetic (256×256×40 RLE), decode-all is median 183 ms and
selected-frame-via-current-path is median 186 ms — i.e. selecting one frame costs
the same as decoding all 40. That 186 ms (and its whole-volume resident
footprint) is the number M2 must beat.*

*Rationale: shared baseline §6 forbids claiming improvements without a reproducible
baseline; `DICOMBenchmark` today is mean-only wall clock with post-hoc memory sampling.*

Scope:
1. Extend `DICOMBenchmark`: `ContinuousClock`, per-iteration samples, median/P90/P95/min/max,
   true high-water resident sampling (background sampler thread), cold vs. warm modes.
2. Benchmark targets per instructions §18.1/§18.2 over the round-trip corpus plus one large
   multi-frame compressed instance (C09-class): full parse, metadata-only, index-only,
   selected-value latency, full pixel decode, per-frame decode, allocations/copies counted.
3. Record environment manifest (commit, toolchain, device, OS) with each artefact; commit
   raw results under `Tests/Benchmarks/Artifacts/`.

Exit criteria: baseline artefact committed for macOS arm64; report documents current
first-frame latency and peak memory for the C09-class file (the numbers M2/M3 must beat).

## M2 — Byte source + selected-frame access (WP-A + WP-E) ✅ DONE 2026-08-10

*Delivered: `DICOMByteSource` protocol + `InMemoryByteSource`/`FileByteSource`
(mapped `.mappedIfSafe` or plain read; `useMemoryMapping` now functional); dead
`DataSource`/`MemoryMappedDataSource`/`LazyPixelDataLoader` deleted;
`EncapsulatedPixelData.makeFrameIndex` (EOT → BOT → 1:1 → single-frame, fail
closed on mid-fragment/non-monotonic/ambiguous mappings, no payload copies) +
`frameData(at:using:)`; public `DICOMFile.pixelFrameCount` and
`pixelData(frame:)` (native slice or single-fragment-set decode, single-frame
descriptor, JPEG-baseline photometric correction preserved); `.lazyPixelData`
deprecated with honest wording. Measured (release, Mac16,13, C09 synthetic
256×256×40 RLE): selected frame 182.9 ms → **4.56 ms median (40×)**, transient
memory growth ~10 MB → unmeasurable; output byte-identical (FrameAccessTests, 9
tests). Full suite green except the 5 pre-existing Metal-env failures.
Follow-ups deferred: OV VR enum case (EOT parses via UN today), per-frame decode
reuse in `pixelData()`, viewer adoption of the new API.*

*Rationale: the decode-all-frames path is the single largest measured cost; a selected-frame
API is the highest-leverage change in the package.*

Scope:
1. `DICOMByteSource` protocol (instructions §5) with two implementations: in-memory bytes
   and local file (mapped-window or pooled reads — chosen by M1 evidence, deterministic
   override for tests). Delete dead `DataSource`/`MemoryMappedDataSource`/
   `LazyPixelDataLoader`; make `ParsingOptions.useMemoryMapping` either functional or
   deprecated-with-warning (no silent no-op).
2. Validated, cached encapsulated frame/fragment index (WP-E): BOT + **Extended Offset
   Table** (7FE0,0001/0002 — currently unreachable because parsing stops at PixelData),
   multi-fragment frames, malformed tables fail closed; built once, reused; no fragment
   payload copies during index build.
3. New public API: `DICOMFile.pixelData(frame:)` / `frameCount` that decodes exactly one
   frame via the index; existing `pixelData()` unchanged in behaviour (may reserveCapacity).
4. `.lazyPixelData` re-implemented honestly on top of the byte source: retains offsets, can
   materialise later; or removed if review prefers.

Exit criteria: selected-frame decode of frame k touches only frame k's fragments
(verified by copy counters); C09 first-selected-frame latency and peak memory materially
better than M1 baseline (target: peak memory bounded by ~1 frame + compressed size, not
whole decoded volume); decoded output byte-identical to the all-frames path; no
small-file regression beyond noise; round-trip preservation (fragment order, BOT/EOT)
intact.

## M3 — Caller-owned codec output (WP-F) ✅ DONE 2026-08-10 (bulk-data handle deferred)

*Delivered: `ImageCodec.decodeFrame(into:)` caller-owned contract (default =
decode + one bounded copy; RLE overrides to interleave segments directly into
the destination — one full-frame intermediate buffer eliminated);
`DICOMFile.alignedPixelData(frame:)` decodes straight into page-aligned
`AlignedPixelBuffer` storage that Metal wraps via `bytesNoCopy` — removing the
render path's separate `pageAligned()` re-copy. Selected-frame aligned decode:
median 4.55 ms (≈ unaligned 4.50 ms) with GPU-ready output. Byte-identity and
undersized-destination safety asserted in FrameAccessTests. **Deferred:**
`BulkDataHandle` as internal representation — requires parser offset tracking
threaded through `DataElement` (Equatable/round-trip implications); revisit with
WP-B/C parser internals.*

## M4 — Bounded decode scheduler + cancellation (WP-G) ✅ DONE 2026-08-10 (J2K bridge deferred)

*Delivered: `DICOMFile.pixelData(frames:maxInFlightBytes:aligned:)` and
`pixelDataParallel(maxInFlightBytes:)` — window = min(cores, budget/bytesPerFrame),
never below 1, `Task.checkCancellation()` before every frame; the
`HTTPRequestPipeline` task group is now windowed at the per-host connection
limit instead of unbounded. Measured (release, Mac16,13/10-core, C09 RLE):
decode-all 181.6 ms serial → **34.1 ms parallel (5.3×)**, byte-identical.
Budget/window unit-tested; tiny-budget and cancellation integration-tested.
**Deferred:** replacing `J2KSwiftCodec.awaitJ2KResult`'s semaphore bridge needs
an async `ImageCodec` variant — an API-design change to propose alongside OV VR.*

## M6 (out of order) — Cache pass ✅ core DONE 2026-08-10

*Delivered: `ImageCache` LRU is O(1) per hit (monotonic access tick; O(n) only
on eviction) + `trim(toFraction:)` staged eviction for memory pressure;
`FrameSourceCache` key now includes file size+mtime (stale-pixels bug fixed) and
an aggregate 192 MB byte ceiling joins the per-entry cap. **Deferred:**
Span/InlineArray parser micro-optimisations — each requires its own M1-protocol
measurement.*

## Historical M3 scope (for reference)

Scope:
1. `BulkDataHandle` (source identity, offset, length, VR, fragment index) as internal
   representation for Pixel Data / Waveform / encapsulated documents; existing `Data`
   accessors become explicit materialisation.
2. Shared native buffer contract (sample type, strides, ownership, capacity); adopt for
   **J2K/HTJ2K decode first**: decode into caller-owned (page-aligned) destination,
   eliminating `packPixels` plane-concat/interleave extra buffers where safe; wire to
   `AlignedPixelBuffer` so the Metal `bytesNoCopy` path starts from the codec output.
3. Copy-count telemetry on the selected-frame path (bytes copied per stage).

Exit criteria: ≥1 fewer full-frame copy on the selected-frame J2K path (counted, not
estimated); decoded samples byte-identical; source-disposed-before-write fails with a
clear error (never truncated/zero-filled output).

## M4 — Bounded decode scheduler + cancellation (WP-G)

Scope:
1. Replace the per-frame `DispatchSemaphore` block in `J2KSwiftCodec.awaitJ2KResult` with a
   properly async codec path; `Task.checkCancellation()` at frame boundaries in all decode
   loops.
2. Memory-budgeted scheduler (actor): concurrent frame decodes bounded by estimated decoded
   bytes + scratch, not task count; current/near frames outrank prefetch; obsolete work
   cancelled. Bound `HTTPRequestPipeline`'s task group with the same discipline.
3. Adopt in `DICOMFile.pixelData()` (parallel bounded decode) and DICOMStudio's
   `FrameSourceCache`/viewer prefetch.

Exit criteria: N-frame decode never exceeds the configured byte budget (asserted in tests);
cancellation of a scrolling workload stops obsolete decodes (obsolete-work % reported); no
allocation growth after repeated study cycling; multi-frame decode wall-clock improves on
≥2-core machines without exceeding budget.

## M5 — Progressive decode contract (WP-H) ✅ core DONE 2026-08-10

*Delivered: J2KSwift's true partial-resolution decode (`decodeResolution`,
v10.5+ code-block filtering + truncated iDWT) surfaced as
`J2KSwiftCodec.decodeFrameAtResolution` and wrapped in
`DICOMFile.pixelDataProgressive(frame:coarseLevels:)` — an
`AsyncThrowingStream<ProgressiveFrameUpdate>` emitting reduced-resolution
previews (explicit `isFinal == false` + level + reduced dims) then the exact
full-fidelity frame; §12 gate asserted: **progressive final ≡ direct full decode
byte-identical**; non-J2K syntaxes fall back cleanly to a single final update.
Bonus: the M2 fail-closed index caught a real shipped writer bug — 
`CompressionManager.buildBasicOffsetTable` computed offsets from *unpadded*
fragment lengths, so every BOT after an odd-length fragment pointed 1 byte
short; fixed. **Deferred:** quality-layer refinement stream, DICOMweb q-value
Accept lists, non-buffered multipart retrieval (`URLSession.bytes`), JPIP
session reuse + the two JPIP defects.*

## Historical M5 scope (for reference)

Scope: capability flags (subresolution/quality-layer/resumable state) surfaced from
J2KSwift; `AsyncSequence` refinement API (resolution level, final/non-final, dirty region);
fix the two JPIP defects (unsent `quality:` argument; unused `resolutionLevel`); DICOMweb
selected-frame + Accept q-value fallback list; streaming (non-buffered) multipart retrieval
via `URLSession.bytes`.

Exit criteria: progressive final decode byte-identical to direct full decode; time to first
(coarse) image on a constrained-network trace beats full-fidelity baseline; full-fidelity
state explicit in the API; falls back cleanly when server/codec lacks capability.

## M6 — Cache & data-structure pass (WP-J + WP-K)

Scope: O(1) LRU for `ImageCache` (dictionary + intrusive list); aggregate byte ceiling and
SOP-UID+mtime keys for `FrameSourceCache`; memory-warning staged eviction hook; then
measured `Span`/`InlineArray`/`ContiguousArray` adoption in the parser hot path (byte
cursor, VR decode without per-element `String` allocation) — each micro-change gated on an
M1-protocol measurement.

Exit criteria: cache hit cost O(1); memory-warning test evicts staged tiers; parser
allocations-per-element reduced with identical parse output on the whole corpus.

---

## Dependencies & order

M0 → M1 → M2 → M3 → M4 are strictly sequential. M5 needs M2 (frame index) + J2KSwift
support and can overlap M4. M6 is independent after M1. Each milestone ends with: benchmark
artefact + report per shared baseline §8, round-trip suite green, and a stop for human
review before the next begins.

## Explicitly out of scope (instructions §20)

New private transfer syntaxes; dicom.js in the native stack; universal mmap rules;
lossy-by-default anything; a second public DICOM object model; weakening malformed-input
handling for speed.
