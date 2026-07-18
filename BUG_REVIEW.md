# DICOMKit — Bug Review

**Scope:** `DICOMKit`, `DICOMCore`, `DICOMNetwork`, `DICOMWeb`, `DICOMDictionary` (+ codec pass over the compression files in `DICOMCore`).
**Date:** 2026-07-18
**Method:** Per-module source review. Each finding below was confirmed by reading the surrounding code (several were reproduced empirically). Line numbers are from the current working tree.

**Tally:** 1 critical · 4 high · 5 medium · 4 low/hardening. Codec/RLE/J2K hot paths reviewed and found clean.

> The "DICOMStudio impact" column maps each bug to the app flow / view model where it can surface, so you can reproduce it from the UI.

---

## Fix status — all applied ✅ (2026-07-18)

All 14 findings have been fixed on the working tree. The five library targets
(`DICOMCore`, `DICOMDictionary`, `DICOMKit`, `DICOMNetwork`, `DICOMWeb`) build cleanly.

| ID | Fix | File |
|----|-----|------|
| C1 | STOW server now uses the byte-scanning `MultipartMIME.parse`; broken UTF-8 parser removed | `DICOMwebServer.swift` |
| H1 | Negated the window/level offset scalar (`Float(-minValue)`) | `SIMDImageProcessor.swift` |
| H2 | Bounds-check the encapsulated fragment slice before `subdata(in:)` | `TransferSyntaxConverter.swift` |
| H3 | Keep empty subsequences + empty-array guard when splitting TM | `DICOMTime.swift` |
| H4 | `LockedFlag` resume-once guard on `SCPAssociation.start()` | `StorageSCP.swift` |
| M1 | Corrected `allowMissingVR` to infer VR from dictionary (+ `import DICOMDictionary`) | `DICOMJSONDecoder.swift` |
| M2 | AT transcoded as two UInt16; added `.OL`/`.OD` to numeric VRs | `TransferSyntaxConverter.swift` |
| M3 | `Dictionary(uniquingKeysWith:)` tolerates duplicate tags | `SequenceItem.swift` |
| M4 | `omittingEmptySubsequences: false` when parsing dictionary rows | `DataElementDictionary.swift` |
| M5 | Rebase CSA input to 0-based storage so index spaces agree | `SiemensCSAHeaderParser.swift` |
| L1 | Wrap palette index into range (guards `segmentNumber == 0`) | `SegmentationRenderer.swift` |
| L2 | Index reads from `startIndex` (30 sites in `ByteOrder`, + LUT byte read) | `ByteOrder.swift`, `PaletteColorLUT.swift` |
| L3 | UID validation restricted to ASCII `0-9` | `DICOMUniqueIdentifier.swift` |
| L4 | Split 3-byte G1 escapes from 4-byte so end-of-buffer escapes are recognized | `CharacterSetHandler.swift` |

Verify each per the **"How to verify the fixes in DICOMStudio"** section below.

### Test infrastructure (uncovered while verifying H1)

The `SIMDImageProcessorTests` suite was **excluded from the build** — `Tests/DICOMKitTests/PerformanceTests` was in the `DICOMKitTests` target's `exclude` list — which is *why* H1 shipped: its regression test never compiled or ran. While wiring it back in:
- `Package.swift` — removed `PerformanceTests` from `exclude` and added `PerformanceTests/SIMDImageProcessorTests.swift` to the target's `sources` allowlist.
- `SIMDImageProcessorTests.swift` — fixed two typo'd assertions (`XCTAssertLess`/`XCTAssertGreater` → `…Than`) that had never been compiled, and corrected a wrong threshold in `testWindowLevelClinicalScenario` (soft tissue at 50 HU in a 400-wide window centered at 40 HU maps to ≈134, not >155).

Result: **14/14 SIMD tests pass**, including `testWindowLevelTransformation`, which now guards H1. The other four PerformanceTests files remain out of the build (not added to the allowlist).

### Regression tests added

New tests reproduce each fixed bug's exact malformed input and assert the fixed behavior. All green.

| File | Covers | Tests |
|------|--------|-------|
| `Tests/DICOMCoreTests/BugRegressionTests.swift` | H2 (oversized fragment length), H3 (empty/dot-only TM), M3 (duplicate seq tags), M2 (AT LE→BE) | 4 ✅ |
| `Tests/DICOMWebTests/STOWBinaryMultipartRegressionTests.swift` | C1 (binary body round-trip, multi-part, non-UTF-8 body) | 3 ✅ |
| `Tests/DICOMDictionaryTests/EmptyNameEntryRegressionTests.swift` | M4 (empty-Name rows present) | 1 ✅ |
| `Tests/DICOMKitTests/PerformanceTests/SIMDImageProcessorTests.swift` | H1 (re-enabled + fixed) | 14 ✅ |

Run them with:
```
swift test --filter BugRegressionTests
swift test --filter STOWBinaryMultipartRegressionTests
swift test --filter EmptyNameEntryRegressionTests
swift test --filter SIMDImageProcessorTests
```

The crash-trio tests (H2/H3/M3) are the important ones: a trap can't be caught, so before the fixes these tests would have aborted the test process rather than failed — reaching the assertion *is* the pass condition.

---

## 🔴 Critical

### C1 — STOW-RS server multipart parser destroys all binary DICOM uploads
- **Module:** DICOMWeb
- **Location:** [`DICOMwebServer.swift:1856-1904`](Sources/DICOMWeb/Server/DICOMwebServer.swift#L1856-L1904) (`MultipartMIMEParser.parse`), invoked by the STOW-RS handler at [`:468`](Sources/DICOMWeb/Server/DICOMwebServer.swift#L468).
- **Defect:** The parser runs `String(data: body, encoding: .utf8)` over the entire multipart body, splits with `String` operations, then re-encodes each part with `bodyPart.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8)`.
- **Why it breaks:** A real STOW-RS request carries `application/dicom` Part-10 files (128-byte zero preamble + binary VRs + pixel data). That byte stream is almost never valid UTF-8, so `String(data:encoding:.utf8)` returns `nil` and `parse` returns `[]`.
- **Failure process:**
  1. Client POSTs a valid `multipart/related; type="application/dicom"` body.
  2. `String(data:encoding:.utf8)` → `nil` → parser yields **zero parts**.
  3. Server stores **nothing** and returns a success-shaped response.
  4. (Rare case where the bytes *do* decode) the body is round-tripped through UTF-8 and whitespace-trimmed — `0x20/0x09/0x0A/0x0D` stripped from head/tail of binary data — **silently corrupting the stored object**.
- **Note:** The *client* path uses the correct byte-scanning `MultipartMIME`; only the server ingestion path uses this broken parser.
- **DICOMStudio impact:** Any flow that pushes into the built-in DICOMweb/STOW server — **DICOMwebViewModel** (STOW upload), **GatewayViewModel**, and the server started from **MainViewModel / ShellServerConfig**. Symptom in-app: "upload succeeded" but the study never appears / can't be retrieved, or a retrieved object is corrupt.
- **Severity rationale:** Silent data loss on every real upload through the server.

---

## 🟠 High

### H1 — Window/level SIMD transform has a sign error (images blown out)
- **Module:** DICOMKit
- **Location:** [`SIMDImageProcessor.swift:54`](Sources/DICOMKit/Performance/SIMDImageProcessor.swift#L54) (`applyWindowLevel`)
- **Defect:** Intends `output = (pixel − minValue) · scale` but passes a **positive** `minValueFloat` to `vDSP_vsadd`, computing `(pixel + minValue) · scale`. The scalar needs to be `Float(-minValue)` (compare the correct `normalize()` in the same file at [`:116`](Sources/DICOMKit/Performance/SIMDImageProcessor.swift#L116), which uses `offset = -minValue*scale`).
- **Failure process (reproduced):** center=50, width=50, pixels 0–99 →
  - Correct: `[0]=0, [24]=0, [50]=127, [99]=255`
  - Actual: `[0]=127, [24]=249, [50]=255, [99]=255`
  - Every windowed image comes out drastically too bright with the dark end blown out.
- **Test status:** `SIMDImageProcessorTests.testWindowLevelTransformation` asserts the correct values and *would* fail, but that XCTest class is not being discovered by `swift test` (filter matched 0 tests), so the defect is **latent in CI**.
- **DICOMStudio impact:** The fast-path window/level used by image rendering — reachable from **ImageViewerViewModel**, **MultiViewportViewModel**, and the **JP3D / VolumeViewer** view models (all reference `windowCenter/windowWidth`). Symptom: wash-out / incorrect brightness when window/level is applied via the SIMD path. *(Confirm whether the live viewer uses this fast path or a scalar fallback — either way the public API is wrong.)*

### H2 — Crash on malformed encapsulated pixel data
- **Module:** DICOMCore
- **Location:** [`TransferSyntaxConverter.swift:1254`](Sources/DICOMCore/TransferSyntaxConverter.swift#L1254) (`parseEncapsulatedPixelData`)
- **Defect:** Reads a file-controlled `itemLength` (UInt32), advances `currentOffset += 8`, then `data.subdata(in: currentOffset..<currentOffset+Int(itemLength))` **with no check against `data.count`**. `Data.subdata(in:)` traps on an out-of-range upper bound.
- **Failure process:** A truncated/corrupt compressed Pixel Data element whose fragment length exceeds the remaining bytes (e.g. a stray `0xFFFFFFFF`) → hard crash.
- **Inconsistency:** Sibling paths `parseDataElement` ([`:1131`](Sources/DICOMCore/TransferSyntaxConverter.swift#L1131)) and `parseSequence` ([`:1208`](Sources/DICOMCore/TransferSyntaxConverter.swift#L1208)) both bounds-check; this one doesn't.
- **DICOMStudio impact:** Opening/transcoding a compressed file with corrupt fragmentation — **CodecInspectorViewModel**, **ImageViewerViewModel** (decode-on-open), any transcode flow. Symptom: app crash on a bad file instead of a handled error.

### H3 — Crash parsing an empty / dot-only TM (time) value
- **Module:** DICOMCore
- **Location:** [`DICOMTime.swift:69`](Sources/DICOMCore/DICOMTime.swift#L69)
- **Defect:** `let parts = normalized.split(separator: ".")` uses the default `omittingEmptySubsequences: true`, then immediately does `String(parts[0])`. For an empty TM (`""`, a valid zero-length DICOM value) or a dots-only value, `parts == []` → `parts[0]` index-out-of-range trap. The `guard mainPart.count >= 2` at [`:72`](Sources/DICOMCore/DICOMTime.swift#L72) runs too late.
- **Failure process:** Parse any dataset containing a zero-length TM element (very common) via `DataElement.timeValue` → crash.
- **DICOMStudio impact:** Metadata display and SR rendering — **StructuredReportModel / SRTreeHelpers / StructuredReportView** call `timeValue`; also **MetadataViewModel**. Symptom: crash when browsing a study whose TM field is empty.

### H4 — Double-resume of `CheckedContinuation` crashes the SCP server
- **Module:** DICOMNetwork
- **Location:** [`StorageSCP.swift:699-712`](Sources/DICOMNetwork/StorageSCP.swift#L699-L712) (`SCPAssociation.start()`)
- **Defect:** `connection.stateUpdateHandler` fires on Network.framework's global queue and resumes the continuation on `.ready` / `.failed` / `.cancelled`, but the handler is **not cleared until line 712**, which runs on the actor only after the awaiting task is rescheduled. In the window between the `.ready` resume and the actor niling the handler, a terminal transition invokes the handler again → second `continuation.resume()` → `fatal error: continuation resumed more than once`.
- **Failure process:** SCU connects → `.ready` (resume) → peer sends TCP RST immediately (`.cancelled`/`.failed`) → second resume → **whole server process crashes**. Remotely (timing-)triggerable.
- **Inconsistency:** Every other continuation-over-state-handler site in the module uses a resume-once guard (`ContinuationResumeOnce`, `LockedFlag`); this one uses a raw multi-case `withCheckedContinuation`.
- **DICOMStudio impact:** Running the C-STORE SCP / storage server — **GatewayViewModel**, **NetworkingViewModel**, **MainViewModel** (start server). Symptom: server dies on a flaky/hostile client connection.

---

## 🟡 Medium

### M1 — `allowMissingVR` logic inverted → feature is dead
- **Module:** DICOMWeb
- **Location:** [`DICOMJSONDecoder.swift:115-120`](Sources/DICOMWeb/DICOMJSONDecoder.swift#L115-L120)
- **Defect:** Both branches of the `else` `throw`, and the condition is backwards: when `allowMissingVR == true` (the flag whose documented purpose is "infer VR from dictionary") it throws instead of inferring. The XML decoder implements the same feature correctly at [`DICOMXMLDecoder.swift:157-165`](Sources/DICOMWeb/DICOMXMLDecoder.swift#L157-L165).
- **Failure process:** Decode DICOM JSON metadata where a tag omits `"vr"` (permitted by PS3.18 when the VR is known from the dictionary) with `allowMissingVR: true` → throws rather than inferring.
- **DICOMStudio impact:** **DICOMwebViewModel** QIDO/WADO metadata parsing against servers that omit VR. Symptom: metadata load fails instead of tolerating the missing VR.

### M2 — VR `AT` corrupted on cross-endian transcode
- **Module:** DICOMCore
- **Location:** [`TransferSyntaxConverter.swift:1289`](Sources/DICOMCore/TransferSyntaxConverter.swift#L1289) & [`:1316`](Sources/DICOMCore/TransferSyntaxConverter.swift#L1316) (`transcodeElementByteOrder`)
- **Defect:** `.AT` is grouped with the 32-bit VRs and byte-reversed as a single UInt32. Per PS3.5, AT is an *ordered pair* of two independent UInt16 (group, then element). `(0010,0020)` LE (`10 00 20 00`) → should be BE `00 10 00 20`, but emits `00 20 00 10` — group/element swapped and mangled.
- **Related gap:** `.OD / .OL / .SV / .UV` are absent from `numericVRs`, so they pass through **unswapped** on transcode.
- **Failure process:** Any AT-valued element is silently corrupted on LE↔BE transcode.
- **DICOMStudio impact:** **CodecInspectorViewModel** / transcode flows that change byte order. Symptom: attribute-tag values (e.g. FrameIncrementPointer) wrong after conversion.

### M3 — Crash on duplicate tags within a sequence item
- **Module:** DICOMCore
- **Location:** [`SequenceItem.swift:28`](Sources/DICOMCore/SequenceItem.swift#L28)
- **Defect:** `init(elements:)` builds its dictionary with `Dictionary(uniqueKeysWithValues:)`, which **traps on duplicate keys**. `TransferSyntaxConverter.parseSequence` ([`:1203`](Sources/DICOMCore/TransferSyntaxConverter.swift#L1203), [`:1216`](Sources/DICOMCore/TransferSyntaxConverter.swift#L1216)) feeds parsed `[DataElement]` straight in without deduping.
- **Failure process:** Malformed DICOM with the same tag twice inside one sequence item → crash.
- **DICOMStudio impact:** Any open/parse of such a file — **MetadataViewModel**, **ImageViewerViewModel**. Symptom: crash instead of a tolerated/repaired parse.

### M4 — Dictionary silently drops elements with an empty Name field
- **Module:** DICOMDictionary
- **Location:** [`DataElementDictionary.swift:22`](Sources/DICOMDictionary/DataElementDictionary.swift#L22)
- **Defect:** `line.split(separator: "|", maxSplits: 5)` omits empty subsequences, so a row with a blank **Name** collapses to 5 fields and fails the `guard fields.count == 6` check. Currently drops `0018,0061`, `0400,0315`, `300A,0782`.
- **Failure process:** `DataElementDictionary.lookup(tag:)` returns `nil` for elements that *are* in the source dictionary. Also a latent field-misalignment hazard if a future regeneration blanks a different column.
- **Fix:** `split(separator: "|", maxSplits: 5, omittingEmptySubsequences: false)`.
- **DICOMStudio impact:** **MetadataViewModel** shows those tags as "unknown"; **ValidationViewModel** may mis-flag them.

### M5 — Siemens CSA parser mixes `Data`-index and 0-based reads
- **Module:** DICOMCore
- **Location:** [`SiemensCSAHeaderParser.swift`](Sources/DICOMCore/PrivateTag/SiemensCSAHeaderParser.swift) (e.g. lines 49/66, 90/98, 105/111)
- **Defect:** Mixes `data.subdata(in: offset..<...)` (uses `Data`'s own index space) with `data.withUnsafeBytes { loadUnaligned(fromByteOffset: offset) }` (0-based). For a `Data` slice with non-zero `startIndex` the two disagree → trap or garbage.
- **Status:** No in-repo callers today → **latent**, but a defect in a public API.
- **DICOMStudio impact:** None currently (unused path); would affect any future Siemens CSA private-tag inspection.

---

## 🟢 Low / hardening

- **L1 — Segment palette underflow.** [`SegmentationRenderer.swift:324`](Sources/DICOMKit/Segmentation/SegmentationRenderer.swift#L324): `(segmentNumber - 1) % palette.count` with a malformed `segmentNumber == 0` → `palette[-1]` crash. Guard with `max(0, …)`. *(Segmentation overlay rendering.)*
- **L2 — Slice-unsafe LUT read.** [`PaletteColorLUT.swift:174`](Sources/DICOMCore/PaletteColorLUT.swift#L174): raw `data[i]` (absolute index) after a count-based guard; traps on a sliced `Data`. Latent — internal callers all pass 0-based `subdata`. Shares a root cause with the `ByteOrder.readUInt16LE/readUInt32LE` length-relative-guard-then-absolute-index pattern ([`ByteOrder.swift:13-38`](Sources/DICOMCore/ByteOrder.swift#L13-L38)); worth fixing once by basing the index on `startIndex`.
- **L3 — UID accepts non-ASCII digits.** [`DICOMUniqueIdentifier.swift:79`](Sources/DICOMCore/DICOMUniqueIdentifier.swift#L79): validation uses `CharacterSet.decimalDigits` / `Character.isNumber`, accepting non-ASCII Unicode digits; DICOM UIDs must be ASCII `0-9`. *(ValidationViewModel under-reports.)*
- **L4 — G1 escape at end-of-buffer.** [`CharacterSetHandler.swift:215-254`](Sources/DICOMCore/CharacterSetHandler.swift#L215-L254): a 3-byte G1 escape sequence at the very end of the buffer isn't recognized (needs a 4th byte). Harmless in practice.

---

## ✅ Reviewed and found clean

- **Codec / compression** (JPEG, JPEG2000, JLS, JXL, HTJ2K, JP3D, J2K, **RLE**): no high-confidence correctness bugs. RLE encode/decode are a true inverse; PackBits run/literal caps and padding are correct; `J2KCodestreamInspector` is deliberately slice-safe and its Part-2 marker handling matches ISO/IEC 15444-2.
- **DICOMNetwork PDU/DIMSE:** `PDUDecoder` length parsing is bounds-guarded throughout; `DICOMConnection` framing and its send/receive/connect continuations use resume-once guards; association negotiation and transfer-syntax selection are correct. (H4 is the one exception.)
- **DICOMWeb client:** `MultipartMIME` (client), `DICOMMediaType.parse`, `DICOMwebURLBuilder`, `WADOURIClient`, `QIDOQuery`, `HTTPClient`, and the WADO-RS Range header are correct.
- **DICOMDictionary:** tag/UID hash lookups, hex parsing, VR fallback, duplicate checks all correct (M4 is the one exception).

---

## Suggested fix order

1. **C1** — STOW-RS parser: replace the UTF-8 `String` parse with byte-scanning (reuse the client-side `MultipartMIME`). *Silent data loss.*
2. **H1** — negate the window/level scalar; also un-skip `SIMDImageProcessorTests` so CI catches it. *Every fast-path image is wrong.*
3. **H2 / H3 / M3** — the "bounds-check before slice / guard before index" trio (encapsulated pixel data, empty TM, duplicate sequence tags). Crash-on-malformed-input hardening.
4. **H4** — add a resume-once guard to `SCPAssociation.start()`.
5. **M1, M2, M4** — correctness fixes (inverted flag, AT endianness, dictionary split).
6. **L1–L4 / M5** — hardening, including the shared `startIndex`-relative read fix.

---

## How to verify the fixes in DICOMStudio

Organized by **app screen** so several fixes can be checked in one sitting. For each: what to do → what a passing result looks like.

### 1. Image Viewer (ImageViewerViewModel / MultiViewport)
**Verifies: H1, H2, M3**

- **H1 (window/level sign error)** — Open a CT/MR image, drag window/level or apply a preset (lung/bone). ✅ Pass: brightness tracks correctly; a narrow window centered mid-range shows proper contrast, **not** a washed-out / blown-out image. Compare against a reference viewer if available. Also confirm via a volume/MPR view.
- **H2 (corrupt compressed crash)** — Open a deliberately truncated/corrupt JPEG/J2K DICOM file. ✅ Pass: handled "failed to decode" error, **no app crash**.
- **M3 (duplicate seq-tag crash)** — Open a file with a duplicate tag inside a sequence item. ✅ Pass: opens or errors gracefully, no crash.

> Quick way to craft test files: hex-edit a valid file's fragment length to `FFFFFFFF` (H2), or duplicate an element inside a sequence (M3).

### 2. Metadata / Structured Report browser (MetadataViewModel, StructuredReportView)
**Verifies: H3, M4**

- **H3 (empty TM crash)** — Open a study whose TM element (e.g. StudyTime/ContentTime) is empty/zero-length. ✅ Pass: metadata panel renders, no crash; SR view opens fine.
- **M4 (dictionary drops tags)** — Browse a file containing tags `(0018,0061)`, `(0400,0315)`, or `(300A,0782)`. ✅ Pass: shown with their real names, **not** "unknown."

### 3. DICOMweb / STOW server (DICOMwebViewModel, GatewayViewModel, server from MainViewModel)
**Verifies: C1, M1**

- **C1 (STOW upload data loss)** — Start the built-in DICOMweb server, STOW-upload a real `application/dicom` study, then **retrieve it back** (WADO) or query (QIDO). ✅ Pass: instance count matches what was sent and the retrieved object is byte-intact / opens correctly. ❌ Bug's tell: "upload succeeded" but nothing stored / retrieval empty. Round-tripping is the real test — don't trust the success response alone.
- **M1 (allowMissingVR)** — Point QIDO/WADO metadata parsing at a response that omits `"vr"` on a tag, with `allowMissingVR` enabled. ✅ Pass: metadata loads with VR inferred from the dictionary, no error.

### 4. Storage SCP / network server (GatewayViewModel, NetworkingViewModel)
**Verifies: H4**

- **H4 (double-resume crash)** — Start the C-STORE SCP, then fire rapid connect/disconnect churn at it (a client that opens the socket and immediately drops/RSTs). ✅ Pass: server stays up across many flaky connections; **no `continuation resumed more than once` crash**. Timing-dependent — run the loop many times.

### 5. Codec Inspector / transcode (CodecInspectorViewModel)
**Verifies: M2 (and re-confirms H2)**

- **M2 (AT endianness)** — Take a file with an AT-valued element (e.g. FrameIncrementPointer `(0028,0009)`), transcode across a byte-order boundary (Explicit VR LE ↔ Big Endian), then inspect that element. ✅ Pass: the tag value is preserved (group/element intact), not swapped/mangled.

### Beyond the app
- **H1 regression test** — un-skip `SIMDImageProcessorTests.testWindowLevelTransformation` and run `swift test`. It already asserts the correct pixel values; it currently isn't being discovered, which is why this shipped. A green run is the most reliable H1 check.
- **Crash trio (H2/H3/M3)** — fastest verified via unit tests feeding the malformed bytes directly, since UI repro depends on crafting files.

---

## CLI / DICOMStudio Workshop hardening (2026-07-18)

Found and fixed alongside the library review above, while auditing the CLI tools and the
`CLIWorkshopViewModel` code that mirrors them in-app. These are argument-validation traps
and app/CLI parity gaps rather than dictionary/codec-layer defects, so they're tracked
separately from the numbered findings.

| Fix | File(s) | Defect |
|-----|---------|--------|
| Negative/zero `--frame` no longer traps | `DICOMConvert.swift`, `CLIWorkshopViewModel.swift` (dicom-convert) | `frameIndex < numberOfFrames` guard let a negative frame index through to the pixel-data indexer instead of rejecting it. |
| Non-DICOM output formats keep the wrong extension in directory converts | `DICOMConvert.swift`, `CLIWorkshopViewModel.swift` (dicom-convert) | Directory conversion reused the source path's `.dcm` extension for PNG/JPEG/TIFF output; only the single-file path retagged via `OutputPathResolver`. Now every non-`dicom` format extension is corrected per file. |
| `dicom-anon` single-file run with no `--output` silently did nothing | `main.swift` (dicom-anon), `CLIWorkshopViewModel.swift` | Without `--output` (and not `--dry-run`), the tool ran anonymization and reported success on a file that was never written. Now rejected up front with a clear error; `--dry-run` still previews without writing. |
| Reversed `--select` range (e.g. `5-1`) trapped | `DICOMQR.swift` | `for i in start...end` traps when `start > end`; now normalized with `min...max` so either order works. |
| `--parallel 0` / negative trapped | `DICOMRetrieve.swift` | Feeds a `stride(by:)`/chunking call that requires a positive stride; now validated with a `ValidationError` before use. |
| `--batch 0` / negative trapped (dicom-stow, dicom-wado store) | `CLIWorkshopViewModel.swift`, `DICOMWado.swift` | Same non-positive-stride trap as above; both call sites now guard first. |
| `--retry` negative trapped | `DICOMSend.swift`, `CLIWorkshopViewModel.swift` (dicom-send) | Retry count feeds `0...retryCount`, which traps for a negative bound; now validated. |
| Study-level C-GET with `--hierarchical` collapsed to a flat/study-only layout | `RetrieveExecutor.swift`, `CLIWorkshopViewModel.swift` | A study-level C-GET has no per-instance series UID from the caller, so `--hierarchical` never nested files under `seriesUID/`. Added `extractSeriesUID(fromDataSet:transferSyntaxUID:)`, a bounds-checked Explicit/Implicit-VR-LE scanner for tag `(0020,000E)`, used as a fallback when the caller doesn't already know the series; falls back to the prior flat layout if it can't confidently parse. |
| `dicom-split` always reported "Split complete!" and exit 0, even on real per-file failures | `DICOMSplit.swift` | The result of `processFile`/`processDirectory` was discarded (`_ = try await ...`). Now the counts are surfaced in the summary line and a nonzero `failed` count exits with `ExitCode.failure` (skips of non-DICOM/single-frame files are not failures and keep exit 0). |

### Regression coverage
These are exercised by the existing CLI/app parity test suites and manual CLI runs; no
new dedicated unit test file was added for this batch (unlike the library findings above,
which have crash-reproduction regression tests in `Tests/DICOMCoreTests/BugRegressionTests.swift`,
`Tests/DICOMWebTests/STOWBinaryMultipartRegressionTests.swift`, and
`Tests/DICOMDictionaryTests/EmptyNameEntryRegressionTests.swift`).
