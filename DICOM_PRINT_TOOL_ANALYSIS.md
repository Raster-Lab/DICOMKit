# DICOM Print Tool — Implementation Analysis

**Date:** 2026-07-20
**Scope:** `dicom-print` CLI + `DICOMPrintService` library
**Reference:** DICOM PS3.4 Annex H — Print Management Service Class

DICOM print in DICOMKit spans two layers:

- **Library** — [`Sources/DICOMNetwork/PrintService.swift`](Sources/DICOMNetwork/PrintService.swift) (3,718 lines) — the `DICOMPrintService` SCU + supporting models.
- **CLI** — [`Sources/dicom-print/main.swift`](Sources/dicom-print/main.swift) (1,048 lines) — the `dicom-print` tool, v1.4.5.

---

## ✅ What's Implemented

### Library — SCU workflow (PS3.4 Annex H)

| Operation | DIMSE | Function |
|---|---|---|
| Query printer status | N-GET | [`getPrinterStatus`](Sources/DICOMNetwork/PrintService.swift#L1880) |
| Create film session | N-CREATE | [`createFilmSession`](Sources/DICOMNetwork/PrintService.swift#L2041) |
| Create film box | N-CREATE | [`createFilmBox`](Sources/DICOMNetwork/PrintService.swift#L2178) |
| Set image content | N-SET | [`setImageBox`](Sources/DICOMNetwork/PrintService.swift#L2409) |
| Print | N-ACTION | [`printFilmBox`](Sources/DICOMNetwork/PrintService.swift#L2606) |
| Cleanup | N-DELETE | [`deleteFilmSession`](Sources/DICOMNetwork/PrintService.swift#L2705) |
| Print job status | N-GET | [`getPrintJobStatus`](Sources/DICOMNetwork/PrintService.swift#L2793) |

**High-level orchestration:** `printImage`, `printImages` (auto-layout), `printWithTemplate`, `printImagesWithProgress` (AsyncThrowingStream).

**Supporting infrastructure:**
- `PrintOptions` with `.default` / `.highQuality` / `.draft` / `.mammography` presets
- `PrintLayout.optimalLayout` layout calculation
- Templates: `SingleImageTemplate`, `ComparisonTemplate`, `GridTemplate`, `MultiPhaseTemplate`
- `PrintRetryPolicy` (exponential backoff)
- `PrintQueue` actor (enqueue/cancel/history)
- `PrinterRegistry` actor with load balancing
- `PrinterCapabilities`
- Both **Basic Grayscale** and **Basic Color** Image Box SOP classes

### CLI — `dicom-print`

- Subcommands: `status`, `send`, `job`, `list-printers`, `add-printer`, `remove-printer`
- `send` supports single/multi files, glob patterns, recursive directory scan, `--dry-run`
- Text/JSON output formats
- Local printer config at `~/.config/dicomkit/printers.json`

---

## 🛠️ Recently Fixed (2026-07-20)

### ✅ 1. CLI `--layout` now honored (was a silent no-op)
`printImages` gained an optional `layout:` override (nil = existing auto-layout). `LayoutOption.printLayout` maps each `RxC` to a `PrintLayout`, threaded through `SendCommand`. A single image with an explicit `--layout` now routes through `printImages`.

### ✅ 2. CLI color printing now reachable
Added `--color grayscale|color` to `send`, mapped to `DICOMNetwork.PrintColorMode`, and passed into `PrintConfiguration`. Previously always grayscale.

### ✅ 7. CLI now sends `PrintImageData` descriptors
`send` builds a per-image descriptor (rows, columns, bits allocated/stored, high bit, samples per pixel, pixel representation, photometric interpretation) from each parsed dataset and passes it to `printImage`/`printImages`. The N-SET Preformatted Image Sequence is now DICOM-conformant (PS3.3 C.13.5.1) instead of omitting required image attributes.

### ✅ 3. N-EVENT-REPORT reception in the Print SCU
Added `PrintEvent` + `PrinterEventType`/`PrintJobEventType` models (with `summary`/`isFault`) and a `PrintEventHandler` callback. The shared `sendAndReceive` helper now detects an interleaved N-EVENT-REPORT-RQ pushed by the SCP, decodes it (Printer Status Info 2110,0020 / Execution Status Info 2100,0030), invokes the handler, and sends the mandatory N-EVENT-REPORT-RSP — then keeps waiting for the response to the SCU's own request. This is also a **correctness fix**: previously an interleaved event would have been mis-parsed as the awaited response. Wired an optional `eventHandler:` through `printImage`/`printImages`/`executePrintWorkflow`; the CLI's `send` prints faults always and routine progress in `--verbose`. Unit tests added in `PrintServiceTests.swift` (and verified via a temporary harness — 12/12 pass) covering event decoding, fault classification, and summaries.

### ✅ 6. CLI ↔ library mismatch — templates + retry now exposed
`send` gained `--template` (single/comparison/grid/multi-phase — sets layout + film size + orientation) routed through the **conformant single-association** `printImages` path (note: the library's `printWithTemplate` opens a separate association per step, violating PS3.4 H.4, so the CLI deliberately does not use it), and `--retries N` (retry on connection/setup failure with exponential backoff via `PrintRetryPolicy`; a submitted job is never retried → no duplicate prints). `PrintQueue`/`PrinterRegistry` remain library-only.

### ✅ 5. Presentation LUT + Annotation Box now wired
- **Presentation LUT:** `PresentationLUTShape` + `presentationLUTShape` option. The workflow N-CREATEs a Presentation LUT SOP Instance (covered by the Grayscale/Color Meta SOP Class, no extra context) and references it from each film box (2050,0500). CLI: `--presentation-lut identity|inverse|lin-od`.
- **Annotation Box:** `PrintAnnotation` + `annotations`/`annotationDisplayFormatID` options. The workflow sets Annotation Display Format ID (2010,0030) and N-SETs each Basic Annotation Box (position 2030,0010 + text 2030,0020), using a new **sequence-scoped** UID parser (`parseReferencedSOPInstanceUIDs(from:withinSequence:)`) so annotation-box UIDs aren't confused with image-box UIDs. CLI: `--annotate` (repeatable) + `--annotation-format`. The format ID is printer-specific.
- **Overlay Box:** SOP class UID + tag added (scaffolding); full overlay-plane extraction is a follow-up. VOI LUT box also remains a follow-up.

### 🔧 Bit-rot repaired + tests re-enabled
The `dicom-print` target had drifted out of compilability (`DICOMParser`/`data(for:)` gone, `@Sendable` capture errors); fixed to use `DICOMFile.read(from:force:).dataSet` + `dataSet[.pixelData]?.valueData`. The **`DICOMNetworkTests` target is re-enabled** so print logic is covered in CI; the live-PACS `PACSIntegrationTests` is quarantined via `exclude:` (heavy API drift). Update 2026-07-22: the `dicom-print` product/target is **permanently enabled** in `Package.swift` (owner approved). Update 2026-07-27: the long-standing `StorageCommitmentServiceTests` hang was fixed, so the full `DICOMNetworkTests` suite (1086 XCTest + 192 swift-testing tests) now completes green in ~15 s and can gate CI.

---

## ⚠️ Gaps — What's Left To Implement

### 4. No Print SCP (provider) side
DICOMKit implements only the SCU/client. There's no print-server role to receive film sessions — relevant for acting as a virtual printer or round-trip testing.

### 5b. Remaining rendering attributes
VOI LUT box and full Overlay Box (overlay-plane extraction from 60xx groups) are not yet wired; the Overlay Box SOP class UID/tag scaffolding is in place.

### ✅ 8. `printWithTemplate` uses multiple associations — fixed (P1-2, Milestone C)
~~The library's `printWithTemplate` opens a separate association for each of createFilmSession/createFilmBox/setImageBox/printFilmBox, violating PS3.4 H.4.~~ Both `printWithTemplate` and `printImagesWithProgress` were reimplemented on top of the single-association `executePrintWorkflow`, gaining `imageDescriptors:`/`eventHandler:` in the process.

---

## Recommended Priority

- ✅ ~~Fix `--layout` and add `--color` on `send`~~ — **done**
- ✅ ~~Wire `PrintImageData` descriptors in the CLI~~ — **done**
- ✅ ~~N-EVENT-REPORT reception in the SCU~~ — **done**
- ✅ ~~Expose templates + retry via CLI~~ — **done**
- ✅ ~~Re-enable `DICOMNetworkTests`~~ — **done**
- ✅ ~~Presentation LUT + Annotation Box~~ — **done**

**Done 2026-07-21 (Milestone A of the enhancement plan):**
- ✅ `parsePrinterStatus` implemented (was a stub always returning NORMAL) — decodes
  Printer Status/Status Info/Printer Name + Manufacturer/Model; `status` CLI shows them.
- ✅ `dicom-print send` exits non-zero on print failure.
- ✅ DIMSE Error Comment (0000,0902) / Error ID (0000,0903) / Offending Element
  (0000,0901) decoded via new `CommandSet` accessors and carried in
  `DICOMNetworkError.printOperationFailed(_, detail:)` on all print failure paths.

**Done 2026-07-21/22 (Milestone B — image fidelity):**
- ✅ Preprocessing pipeline wired into `send` (rescale → window → MONOCHROME1
  inversion → 8-bit MONOCHROME2/RGB), with `--raw` bypass; quarantined MONOCHROME1
  tests re-enabled against the decided behavior.
- ✅ Encapsulated sources decoded before N-SET via `DICOMFile.tryPixelData()`.
- ✅ Multi-frame: `--frame N` / `--all-frames` with bounds validation.
- ✅ Uncompressed YBR_FULL→RGB conversion; subsampled YBR initially rejected —
  superseded 2026-07-24: packed YBR_FULL_422/YBR_PARTIAL_422 now converted to RGB
  inside `ImagePreprocessor` (4:2:0/ICT/RCT remain rejected; never occur uncompressed).
- ✅ Signed sources emitted as unsigned 8-bit P-Values via the pipeline.

**Done 2026-07-22 (Milestones C–E + Milestone D test harness):**
- ✅ Milestone C (interop): unconditional image-box attributes, single-association
  `printWithTemplate` rework (PS3.4 H.4), Explicit-VR-only negotiation (later
  superseded by full Implicit VR support), DIMSE receive timeout with abort-to-unblock.
- ✅ Milestone D: `dicom-print` target permanently enabled; `MockPrintSCP` harness +
  integration tests (happy path, multi-film, failure injection with error detail,
  defensive Film Session N-DELETE, timeout, zero-context rejection, interleaved and
  release-window events, omitted job UID, printer status).
- ✅ Milestone E: P2/P3 hardening + CLI ergonomics (`--check-status`, `--verify`,
  `--film-destination`, extra film sizes, JSON result contract, port validation).

**Done 2026-07-24 (post-plan items 1–7):** palette color printing, packed 4:2:2 YBR,
explicit `--window-center`/`--window-width`, `--bit-depth 8|12|16`, full Implicit VR LE
(serialize + parse per negotiated syntax), `--magnification none`, spawn-based CLI
end-to-end tests (`PrintCLIEndToEndTests`).

**Done 2026-07-27:** fixed the pre-existing `CommitmentNotificationListener.waitForResult`
hang (plus two unmasked failures: keychain identity label matching, store-and-forward
drain-race test) — full `DICOMNetworkTests` now gates green.

**Remaining (out of scope, tracked in DICOM_PRINT_ENHANCEMENT_PLAN.md):**
1. **VOI LUT box + full Overlay Box** (overlay-plane extraction from 60xx groups).
2. **Print SCP** (provider role) if server-side is needed.
3. Presentation LUT *Data* variant (only LUT Shape is implemented).
4. Optionally surface `PrintQueue` / `PrinterRegistry` via CLI commands.
5. Real-hardware printer validation.
