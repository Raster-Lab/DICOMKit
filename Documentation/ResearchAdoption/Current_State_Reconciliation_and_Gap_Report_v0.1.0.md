---
title: "DICOMKit — Current-State Reconciliation and Gap Report"
version: "0.1.0"
status: "Deliverable 1 of the Research Adoption Instructions — evidence collected from source; human review required before implementation"
controlled_date: "2026-08-10"
organisation: "Raster Images"
project: "DICOMKit"
language: "en-GB"
companion:
  - "DICOMKit_Performance_Memory_Streaming_and_Codec_Research_Adoption_Instructions_v0.1.0.md"
  - "Shared_Performance_Memory_and_Progressive_Delivery_Benchmark_Baseline_v0.1.0.md"
  - "Research_Evidence_Register_v0.1.0.yaml"
  - "../../ECOSYSTEM_COMPARISON.md"
---

# DICOMKit — Current-State Reconciliation and Gap Report v0.1.0

This is the gap-and-benchmark-precursor report required by §1 and §19.1 of the
Research Adoption Instructions. Every claim below was verified against the source
tree at the commit current on 2026-08-10 (post-`de67c39`), with file:line evidence.
No implementation change is made by this report. Benchmarks (§18 of the
instructions) have **not** yet been run; this report establishes what to measure
and why.

Modules in scope: `DICOMCore`, `DICOMKit`, `DICOMWeb`, `DICOMRenderKit`
(libraries: DICOMKit, DICOMCore, DICOMDictionary, DICOMNetwork, DICOMWeb,
DICOMToolbox, DICOMRenderKit, DICOMPrintKit, DICOMStudio; 31 CLI tools).

---

## 1. Existing source abstractions (WP-A baseline)

**Finding: the parser has exactly one ingestion strategy — whole-file `Data` in memory.**

- `DICOMFile.read(from:)` does `Data(contentsOf: url)` with no options
  (`Sources/DICOMKit/DICOMFile.swift:106-110`). `ParsingOptions.useMemoryMapping`
  (`Sources/DICOMKit/Performance/ParsingOptions.swift:44`) is stored and **read by
  nothing** — `.memoryMapped` is a no-op. There is no `.mappedIfSafe` anywhere in
  `Sources/`.
- A byte-source abstraction already exists but is **dead code**:
  `DataSource`/`MemoryDataSource`/`MemoryMappedDataSource`
  (`Sources/DICOMKit/Performance/DataSource.swift:5,23,49` — the "mapped" variant is
  FileHandle-seek, not mmap) have zero references outside their own file. Ditto
  `LazyPixelDataLoader` (`Sources/DICOMKit/Performance/LazyPixelDataLoader.swift:8`);
  its `DataElement.lazyPixelData(...)` factory **discards the loader** and stores
  `valueData: Data()` (`:102-118`).
- `.lazyPixelData` mode therefore does not defer pixels — it **loses** them:
  `parsePixelDataMetadataOnly` returns an element with empty `valueData` and retains
  no offset/length handle (`Sources/DICOMKit/DICOMParser.swift:352-444`).
- Parsing stops unconditionally at (7FE0,0010) (`DICOMParser.swift:161`), so the
  Extended Offset Table tags and any trailing elements are never parsed.
- Deflated transfer syntax costs three whole-file-sized allocations before parsing
  begins (`DICOMParser.swift:911-925`).

**WP-A status: not started; the dead `DataSource`/`LazyPixelDataLoader` types should
be replaced (not resurrected as-is) by the `DICOMByteSource` contract.**

## 2. Parser copies and allocations (WP-B/C baseline)

Copy map for a compressed multi-frame instance, source → screen (instructions §1.4):

| # | Stage | Site | Cost |
|---|---|---|---|
| 1 | File → `Data` | `DICOMFile.swift:108` | whole file, heap |
| 2 | Fragment → element | `DICOMParser.swift:337` `subdata` per fragment | whole compressed stream duplicated |
| 3 | Sequences double-stored | `DICOMParser.swift:770` raw span kept **and** parsed items | sequence bytes held once per nesting level |
| 4 | `EncapsulatedPixelData` rebuilt **per access**, BOT frame extraction is a linear fragment scan | `DataSet+PixelData.swift:233-252`; `Sources/DICOMCore/EncapsulatedPixelData.swift:109-155` | O(frames×fragments); descriptor tags re-decoded per call |
| 5 | Codec input | RLE `RLECodec.swift:138`, JPEG `JLICodec.swift:78` `[UInt8](frameData)` | full compressed-frame copy (J2K passes `Data` through) |
| 6 | Codec output pack | `J2KSwiftCodec.swift:649-761` subdata/byte-swap/plane-concat/`interleaveRGB` | 1–2 extra full-frame buffers per frame |
| 7 | **All frames decoded eagerly** | `DICOMFile+PixelData.swift:44-65` `decompressedData.append(...)`, no `reserveCapacity` | full uncompressed volume materialised to read one frame |
| 8 | Frame back out | `Sources/DICOMCore/PixelData.swift:60` `Data(data[start..<end])` | copy per render |
| 9 | Display | `PixelDataRenderer.swift:158,261` RGBA `[UInt8]`; `:320,342-347` `Data(bytes) as CFData` | 4 B/px buffer + one more full copy |

Net: rendering frame 3 of a 100-frame J2K study decodes and materialises all 100
frames, then copies the one frame twice more. **This single fact dominates every
other optimisation opportunity in the package** and is the primary benchmark target
(§18.2 "complete object read versus fragment handle").

Other hot-path allocation facts:

- Every element value is an eagerly copied `Data` slice (`DataElement.swift:23`;
  `DICOMParser.swift:622,704`). No lazy materialisation, no bulk-data handles
  (WP-C/WP-D: not started).
- Strings are decoded on access but **uncached**, so repeated access re-decodes
  (`DataElement.swift:156-176`). `DataSet` is `[Tag: DataElement]`
  (`Sources/DICOMKit/DataSet.swift:9`), losing element order.
- Per-element `String(bytes:encoding:)` + string-keyed `VR(rawValue:)` allocation
  for **every element parsed** (`DICOMParser.swift:653` et al.).
- Scalar reads go byte-at-a-time through Foundation `Data` subscripting
  (`Sources/DICOMCore/ByteOrder.swift:13-37`). No `Span`/`RawSpan`/`InlineArray`/
  `ContiguousArray` anywhere in DICOMCore/DICOMKit (WP-K: not started).

## 3. Safety limits (instructions §17; ECOSYSTEM_COMPARISON §4.1)

- `ParsingOptions` has only `mode`, `stopAfterTag`, `maxElements`,
  `useMemoryMapping`. `maxElements` applies to the **top-level loop only**
  (`DICOMParser.swift:94-96`); sequence items are unbounded.
- Sequence parsing is mutually recursive with **no depth cap**
  (`parseSequenceElement:757` → `parseUndefinedLengthSequence:825` →
  `parseSequenceItem:872` → `parseUndefinedLengthItem:918` →
  `parseExplicitVRElement:628` → recurse). A crafted file with deeply nested
  undefined-length items is an uncatchable stack-overflow crash — the exact bug
  fo-dicom fixed in 5.2.3 (#1977).
- Any non-SQ element with length `0xFFFFFFFF` is recursed into as a sequence
  (`DICOMParser.swift:698-706`).
- No max declared element length, no total-allocation ceiling, no fragment/frame
  count limits. Both this report's companions independently flag this as P0.

## 4. Codec buffer ownership (WP-F baseline)

- `ImageCodec` is allocate-and-return only: `decode(_:descriptor:) -> Data`,
  `decodeFrame(...) -> Data` (`Sources/DICOMCore/ImageCodec.swift:239-259`). **No
  caller-owned destination exists anywhere.** All adapters conform to that shape.
- CPU display always converts to 8-bit gray/RGBA inside `PixelDataRenderer` with a
  further `[UInt8]`→`Data`→`CFData` copy (`PixelDataRenderer.swift:158,261,320,342-347`).
- The GPU path is materially better: `PixelData.alignedStorage` +
  `AlignedPixelBuffer` (page-aligned, `Sources/DICOMCore/AlignedPixelBuffer.swift:29-60`)
  feed Metal via `makeBuffer(bytesNoCopy:)`
  (`Sources/DICOMRenderKit/Metal/MetalFrameRenderer.swift:480-499`). This is the
  pattern WP-F generalises to codecs.
- `CompressionManager.decodePixelDataInPlace` constructs a fresh `J2KSwiftCodec`
  per call instead of using `CodecRegistry` (`Compression/CompressionManager.swift:595-608`).
- JXL reversible-JPEG path double-decodes (reconstruct JPEG, then `JLICodec`)
  (`Sources/DICOMCore/JXLCodec.swift:213-220`).

## 5. Concurrency and cancellation (WP-G baseline)

- **Frame decode is entirely serial** (`DICOMFile+PixelData.swift:46-65`;
  `CompressionManager.swift:632-640`). There is no decode scheduler of any kind —
  neither task-count-bounded nor byte-budgeted.
- **No cancellation reaches a codec.** No `Task.checkCancellation()` in
  DICOMCore/DICOMKit. `J2KSwiftCodec.awaitJ2KResult` blocks a thread on a
  `DispatchSemaphore` around `Task.detached` with a 60 s timeout
  (`J2KSwiftCodec.swift:387-414`); the calling task's cancellation cannot interrupt
  it, and the frame loop pays this bridge once per frame.
- The single task group in the codec/network surface is **unbounded**:
  `HTTPRequestPipeline` adds one task per queued request and holds every response
  in memory (`Sources/DICOMWeb/HTTPRequestPipeline.swift:284-303`).
- No memory-budget input anywhere (`os_proc_available_memory` unused). The only
  size-driven decision is `J2KRoutePlanner.planDecode` (pixel count → CPU/GPU).

## 6. Progressive delivery (WP-H baseline)

- No resolution-level / quality-layer / region parameter exists on `ImageCodec` or
  any `DICOMFile` API. HTJ2K support is whole-codestream only.
- `DICOMJPIPClient` is the sole progressive surface and is a thin passthrough to
  J2KSwift's JPIP client; each call returns one finished image (no AsyncSequence of
  refinements, no session reuse across quality levels). Defects: `fetchRegion`'s
  `quality:` argument is **never sent to the server**
  (`Sources/DICOMKit/DICOMJPIPClient.swift:220-236`), and
  `DICOMJPIPQuality.resolutionLevel` is consumed by nothing.
- DICOMweb: QIDO metadata-only ✅; WADO-RS selected frames ✅ (`DICOMwebClient.swift:357-427`);
  single-syntax Accept negotiation (no q-value fallback list, `:643-652`); Range
  requests on bulk data only (`:596-607`). **All retrieval is fully buffered** —
  `session.data(for:)` (`Sources/DICOMWeb/HTTPClient.swift:379`);
  `retrieveDICOMStream` downloads and parses the entire multipart body before
  yielding parts, so peak memory ≈ whole study.

## 7. Caches (WP-J baseline)

| Cache | Scope | Key | Bound | Issues |
|---|---|---|---|---|
| `ImageCache` (`Performance/ImageCache.swift`) | rendered `CGImage` | SOP+frame+window+PI+prState | 100 items **and** 500 MB (estimated) | O(n) LRU array per hit (`:231-234`); size estimate ignores row padding; oversized entries silently dropped |
| `FrameSourceCache` (DICOMStudio) | decoded files | **file path string** (no mtime/size) | 3 items; 96 MB per-entry admission | no aggregate byte ceiling (≈288 MB reachable) |
| `InMemoryCache` (DICOMWeb) | HTTP responses | URL | 1000 items / 100 MB + TTL/ETag | the healthiest of the three |

**No memory-warning handling exists anywhere in the package** — no
`didReceiveMemoryWarning` observer, no `NSCache`, no staged eviction. The
PERFORMANCE_GUIDE's iOS memory-warning example does not correspond to any shipped
hook. Cache keys carry no decode-fidelity dimension (irrelevant today — there is no
partial fidelity — but required by WP-H/WP-J together).

## 8. Existing benchmark claims requiring reproduction (§1.2, §4)

`DICOMBenchmark` measures wall-clock via `CFAbsoluteTimeGetCurrent`, mean-only, no
median/percentiles, and its "peak memory" is a resident-size delta sampled **after**
each iteration returns — intra-iteration peaks are invisible
(`Performance/DICOMBenchmark.swift:90-104,147-151,170-196`). It does not currently
satisfy the shared baseline's §6 protocol (median + tails, high-water marks).

Claims in PERFORMANCE_GUIDE.md audited against code:

| Claim | Verdict |
|---|---|
| "`ParsingOptions.memoryMapped` → 50% less memory >100 MB" | **False** — flag is a no-op (§1). Number unattributed. |
| "`lazyPixelData` defers loading until accessed" | **False** — pixels are discarded, not deferred (§1). |
| "Metadata-only 2–10×, up to 90% memory" | Plausible direction, **unmeasured**, no environment named; also `.metadataOnly` silently drops post-pixel elements. |
| "Backend multipliers are additive → HTJ2K+Metal ~40–50×" | **Prohibited reasoning** (shared baseline §2.2, instructions §20). Never measured end-to-end. |
| Unbounded `withTaskGroup` multi-frame example | **Prohibited pattern** (instructions §11); also misleading — the library itself decodes serially. |
| HTJ2K 5.4× decode vs J2K (`instance_003317.dcm`, macOS arm64, J2KSwift 11.0.0) | Properly attributed **measured fact** — the model to follow. |
| JPIP "first tile <200 ms, 1–3 s convergence"; JP3D round-trip tables | Unattributed; no environment/corpus hash. Reproduce or relabel as hypothesis. |
| Connection pooling "3–10×", combined "10–50x overall" | Unattributed compound estimates — remove or reproduce. |

PERFORMANCE_GUIDE.md has been corrected in-tree per instructions §4/§19.7 (see the
guide's changelog); claims were relabelled as *measured fact / configuration
example / heuristic default / hypothesis requiring a benchmark / not implemented*,
and the two prohibited patterns (additive multipliers, unbounded task group) were
removed.

## 9. Gap → work-package matrix

| Work package | Status today | Priority evidence |
|---|---|---|
| A `DICOMByteSource` | Dead prototypes only; parser is whole-file `Data` | §1 |
| B Borrowed parser windows | Absent; byte-wise `Data` subscript hot path | §2 |
| C Compact index + lazy values | Absent; eager `Data` per element, sequences double-stored | §2 |
| D `BulkDataHandle` | Absent; `lazyPixelData` actively loses pixels | §1 |
| E Frame/fragment index | Partial: BOT parsed once, but no EOT, index rebuilt per access, linear scans, **no public selected-frame decode API** | §2 #4, §6 |
| F Caller-owned codec buffers | Absent at codec boundary; GPU path shows the working pattern | §4 |
| G Memory-budgeted scheduler | Absent; serial decode + one unbounded network task group | §5 |
| H Progressive HTJ2K | Absent at codec API; JPIP passthrough with two defects | §6 |
| I Metadata/frame-first retrieval | Halfway: QIDO/frames endpoints exist; transport fully buffered | §6 |
| J Cache redesign | Three inconsistent caches; no memory-warning path | §7 |
| K Swift data structures | Not started | §2 |
| §17 Safety limits | **Live crash risk** (recursion depth), allocation DoS | §3 |

## 10. Recommended sequencing (requires human acceptance)

1. **Parser hardening (instructions §17 + ECOSYSTEM_COMPARISON §4.1)** — depth,
   declared-length and allocation ceilings + structured `limitExceeded` error.
   Small, self-contained, correctness/safety not performance, no benchmark gate.
2. **Benchmark baseline** — extend `DICOMBenchmark` to median/percentiles and true
   high-water sampling; run §18.1/§18.2 matrix on the round-trip corpus; commit raw
   artefacts. Nothing else may claim a speed-up before this exists.
3. **P0 slice (§19.6)** — file-backed `DICOMByteSource` + selected-frame public API
   over a cached fragment index (WP-A + WP-E first: they unlock the single largest
   measured cost, the decode-all-frames path), then WP-D handle, WP-F caller-owned
   output for one codec (J2K), WP-G bounded scheduler.
4. WP-B/C/K parser internals, WP-H progressive contract with J2KSwift, WP-I/J.

Items 3–4 are large implementation changes and are **not** started pending review
of this report.
