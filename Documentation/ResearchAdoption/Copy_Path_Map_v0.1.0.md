---
title: "DICOMKit — Source→Parser→Codec→Renderer Copy-Path Map"
version: "0.1.0"
status: "§19 deliverable 5 (Benchmark and Copy-Path Report, static half) — produced 2026-08-11"
governing: "DICOMKit_Performance_Memory_Streaming_and_Codec_Research_Adoption_Instructions_v0.1.0.md §1.4, §19"
language: "en-GB"
---

# Copy-Path Map v0.1.0

**What this is.** The copy map required by instruction §1.4 before any broad refactor, and
the static half of §19 deliverable 5. It (a) traces one frame's bytes from source to
renderer and counts every copy at file:line, (b) classifies all 74 `subdata(in:)` sites in
`Sources/` by slice-safety, and (c) turns the resulting fix list into a gated checklist.
Runtime byte-count instrumentation (the dynamic half) is deferred to M3, which this map
now baselines.

**The invariant this map enforces** (established by the RLE fix, 2026-08-11):

> Any function that accepts `Data` must produce identical results for a contiguous buffer
> and for a slice of a larger buffer (non-zero `startIndex`). `Data`'s subscripts,
> ranges and `subdata(in:)` index **absolutely**; the `readUIntXX(at:)` helpers in
> `ByteOrder.swift` index **slice-relatively** (they add `startIndex`). Mixing the two on
> a slice silently misreads or traps.

Regression pattern: decode/parse a slice, compare byte-identical against the contiguous
equivalent — `CodecFuzzTests` (RLE), `SliceIndependenceTests` (parser, transcode).

## 1. Findings from producing this map

Producing the map found **two further publicly-reachable crashes** of the RLE class, both
confirmed by a failing test before the fix and green after:

| # | Entry point | Defect | Fix |
|---|---|---|---|
| 1 | `DICOMFile.read(from: Data)` (all overloads) | `hasDICMPrefix` reads `data[128..<132]` absolutely (silent misread on a slice); `DICOMParser` mixes `readUInt16LE` (relative) with `subdata` (absolute) → trap | Rebase once at the public boundary, [DICOMFile.swift:77](../../Sources/DICOMKit/DICOMFile.swift#L77) |
| 2 | `TransferSyntaxConverter.transcode(dataSetData:)` | Private element walkers use 0-based `subdata`/`data[offset]` on public input → trap | Rebase once at the public boundary, [TransferSyntaxConverter.swift:306](../../Sources/DICOMCore/TransferSyntaxConverter.swift#L306) |

With RLE (found by fuzz the day before), that is **three public entry points** that
crashed on sliced input. All three now hold the invariant under test. The rebase costs
nothing when `startIndex == 0` (the overwhelmingly common case today) and one copy when
the caller passes a genuine slice — correctness first; the zero-copy replacement is WP-B
borrowed windows.

## 2. Pipeline hand-off map (selected-frame request)

```
stage                         hand-off                                  copy?
─────                         ────────                                  ─────
source → memory               Data(contentsOf:) / byte source           C-src: whole file
parser → element              DICOMParser subdata (fragments/values)    C-elem: whole PixelData
element → frame               EncapsulatedPixelData.frameData(using:)   0 (single-fragment: returns
                                                                          fragments[i] unwrapped)
                                                                        1 frame (multi-fragment: append)
                              native: Data(valueData[start..<end])      1 frame (rebased copy)
frame → codec input           RLE segment subdata / J2K passthrough     ≤1 compressed frame
codec → decoded               decode output                             (product, not a copy)
decoded → packed              interleave / plane-concat / byte-swap     0–1 frame (path-dependent)
packed → GPU                  AlignedPixelBuffer + bytesNoCopy          0 (caller-owned path)
                              Data-returning path                       1 frame (staging)
```

### Static copy counts per family (each copy identified at file:line)

**Native (uncompressed), `pixelData(frame:)`** — [DICOMFile+FrameAccess.swift:158](../../Sources/DICOMKit/DICOMFile+FrameAccess.swift#L158)
1. C-src: whole file (`DICOMFile.read`)
2. C-elem: whole PixelData value — `DICOMParser.swift:308/664` `subdata`
3. C-frame: `Data(element.valueData[start..<end])` — FrameAccess:179 (1 frame, rebases)
4. C-swap (BE 16-bit only): `nativePixelBytesLittleEndian` — DataSet+PixelData.swift:216
→ **2 whole-object + 1 frame (+1 conditional)**. `alignedPixelData(frame:)` replaces 3–4
with a direct `withUnsafeBytes` copy into aligned storage (still 1 frame, but GPU-final).

**RLE encapsulated, `pixelData(frame:)`**
1. C-src: whole file
2. C-frag: every fragment — `DICOMParser.swift:378` `subdata` (whole PixelData)
3. C-frame: 0 (single-fragment frame: `EncapsulatedPixelData.swift:188` returns the
   fragment unwrapped) or 1 frame (multi-fragment append, :189-190)
4. C-seg: compressed segment `subdata` — `RLECodec.swift:77/138` (≈1 compressed frame)
5. decode products: per-segment PackBits output + interleave output. The caller-owned
   `decodeFrame(into:)` (M3/WP-F) eliminates the separate interleave staging buffer —
   the "≥1 fewer full-frame copy" M3 gate, now countable against this baseline.

**J2K/HTJ2K encapsulated**
1–3. as RLE
4. codec input: passthrough (no copy in DICOMKit; J2KSwift internals opaque — marked
   out-of-scope boundary, revisit under the J2KSwift companion instruction)
5. component → packed: `J2KSwiftCodec.swift:701/722` `subdata` **only when** the decoded
   component over-runs the expected byte count; plane append into output = 1 frame.

## 3. Site classification (all 74 `subdata(in:)` sites)

Classes:
- **A — CORRECT-ABSOLUTE**: arithmetic already based on `startIndex`; slice-safe as-is.
- **B — REBASE-AT-ENTRY**: input normalised to `startIndex == 0` at the function/API
  boundary (the SiemensCSA pattern); interior 0-based math then safe.
- **C — SAFE-FRESH-INTERNAL**: private/internal call sites whose input provably has
  `startIndex == 0` (built by `Data()`+append, `Data(contentsOf:)`, FileHandle reads, or
  decoder output). Safe **by provenance, not by construction** — fragile under refactor.
- **D — LATENT-VIA-PARSER-REBASE**: safe today *only* because `DICOMParser` copies element
  values (class-B upstream); becomes live the moment `BulkDataHandle`/byte-source slices
  reach it (WP-D). Must be fixed **before or with** M3.

| Class | Sites | Files |
|---|---|---|
| **A** | 9 | `J2KCodestreamInspector:114` (`absolute()` helper), `J2KSwiftCodec:586/609/701/722`, `PrintDatasetReader:226`, `DICOMByteSource:47/82`, `RLECodec` (fixed 2026-08-11) |
| **B** | 12 | `SiemensCSAHeaderParser` (5, rebases at :55), `JXLCodec:314` (rebases), `DICOMParser` (7 sites — all safe since the read() boundary rebase), `TransferSyntaxConverter` (5 sites — safe since the transcode() boundary rebase) |
| **C** | 31 | `NativeJPEG2000Codec` (6: CGImage/ImageDestination output), `JP3DCodec:178` (decode output), `MessageAssembler:295` (serializer output), `CommandSet:408`, `QueryService:763`, `ModalityWorklistService:819`, `StorageService` (3: file reads + PDV buffers), `StorageCommitmentSCP` (3) / `StorageCommitmentService` (3) (PDV-assembled `Data()`+append), `ServerSession` (2: `Data(contentsOf:)`), `StudyManager:209` / `StudyOrganizer:168` / `CompressionManager:868` (FileHandle reads), `DICOMVolume:127/149`, `JP3DVolumeBridge:203/206`, `JP3DMPRSliceExtractor:130` (assembled volumes) |
| **D** | 17 | `ImageCodec:349` (encode frame split), `SegmentationPixelDataExtractor:60/127`, `ParametricMapPixelDataExtractor:59/131/181`, `ICCProfileParser:169`, `JP3DVolumeDocument` (5), `dicom-3d/main.swift` (3: element payload walk), `DICOMFile+FrameAccess` native slice (uses `startIndex` arithmetic — actually class A; listed here for the C-elem dependency it shares) |

## 4. Fix/keep checklist

**Done (this map + the day before):**
- [x] `RLECodec` — rebased segment slicing, both paths (+ slice-equality tests)
- [x] `DICOMFile.read(from: Data)` — boundary rebase (+ tests)
- [x] `TransferSyntaxConverter.transcode` — boundary rebase (+ test)

**Gated on WP-D / M3 (class D — do when handles make slices reachable, not before):**
- [ ] `SegmentationPixelDataExtractor`, `ParametricMapPixelDataExtractor` — boundary
  rebase or `startIndex` arithmetic + slice-equality test each
- [ ] `ImageCodec.encodeFrames` frame split — `startIndex` arithmetic
- [ ] `ICCProfileParser`, `JP3DVolumeDocument`, `dicom-3d` payload walkers — boundary rebase
- [ ] Runtime copy-count telemetry on the selected-frame path (dynamic half of §19-5)

**Keep as-is, annotate only (class C):** provenance-guaranteed fresh today. Rule for
reviewers: *a class-C function's `Data` parameter must not be re-plumbed to accept
caller-supplied or sliced input without adding the class-B rebase or class-A arithmetic
plus a slice-equality test.*

**No action (class A/B):** already correct; protected by existing tests where public.

## 5. Verification

- `SliceIndependenceTests` (3 tests) + `CodecFuzzTests` slice guards: green.
- Both new fixes were demonstrated as traps (signal 5) by a failing test *before* the fix.
- Full suite after all changes: 7,312 tests / 730 suites green (1 pre-existing known
  issue, NativeJPEG2000Codec 12-bit encode; Print SCP e2e flake is pre-existing and
  load-dependent — measured 2/4 failing on unmodified HEAD, see plan M0.1 note).
