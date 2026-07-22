# DICOM Print SCU — Enhancement Plan

**Date:** 2026-07-20 (revised 2026-07-21; execution status updated 2026-07-22)
**Basis:** Feature-completeness audit of `dicom-print` + `DICOMPrintService`
**Reference:** DICOM PS3.4 Annex H (Print Management), PS3.3 C.11/C.13, PS3.7 (DIMSE-N)
**Related docs:** [DICOM_PRINT_TOOL_ANALYSIS.md](DICOM_PRINT_TOOL_ANALYSIS.md)

## Status at a Glance (2026-07-22)

**19 of 20 items done.** All of P0, P1, and P3 are complete, P2 lacks only P2-7 — the SCU
is past the plan's "production-grade for common printers" bar and integration-tested against
an in-process mock Print SCP. Work landed as local commits on
`fix/bug-review-crash-and-hardening-2026-07-18` (not pushed):

| Commit | Scope |
|---|---|
| `f8e6d42`, `49f5ab0` | Milestone 0 — housekeeping (YBR decode fix; prior print features + docs) |
| `9afa860` | Milestone A — P0-3, P0-5 (library) |
| `9452a92` | Milestone B — P0-1, P0-2, P0-4, P0-6, P1-5, P2-6 |
| `9ed14b3` | Milestone C — P1-1, P1-2, P1-3, P1-4 |
| `e7aad5f` | Milestone E (partial) — P2-1, P2-2, P2-4, P2-5, P3-1, P3-3 |
| *(pending commit)* | Milestone D — `dicom-print` target enabled (owner approved), MockPrintSCP + 10 integration tests, P2-3, P3-2 |

**Verified:** 236 tests green across `PrintServiceTests` / `PrintSCPIntegrationTests` /
`CommandSetTests` / `DICOMFilePixelDataYBRDecodeTests`; `dicom-print` builds with zero
warnings as an enabled Package.swift product.

**Open items:** P2-7 (N-EVENT-REPORT during the release window) and the spawn-based CLI
end-to-end tests (see test matrix). The `dicom-print`-target decision was made 2026-07-22:
enabled, owner approved.

This plan turns the audit findings into a prioritized, implementable backlog. Each item lists
the problem, the target files, the change, and acceptance criteria + tests. Current SCU
completeness is ~55%; completing P0–P1 brings it to production-grade for common printers.

> **Layering constraint (applies to P0-1, P0-2, P0-6, P1-5):** `DICOMNetwork` depends only on
> `DICOMCore` + `DICOMDictionary` (`Package.swift`) — it **cannot** see `ImagePreprocessor` or
> `DICOMFile.pixelData()`, which live in `DICOMKit`. All pixel preprocessing, decompression, and
> color conversion must therefore happen in the **CLI layer** (`Sources/dicom-print`, which does
> depend on `DICOMKit`) — or the needed helpers must be moved down a layer. Do not start these
> items inside `PrintService.swift`.

> **Process note (✅ resolved 2026-07-21):** the previously uncommitted print work was split
> into two logical commits (`f8e6d42` YBR decode fix, `49f5ab0` print features + docs) before
> Milestone A began.

---

## Priority Legend

| Tier | Meaning |
|---|---|
| **P0** | Correctness/safety — produces wrong output or silent failure. Fix first. |
| **P1** | Interoperability — fails against real/strict Print SCPs. |
| **P2** | Robustness / conformance hardening. |
| **P3** | CLI ergonomics & coverage. |

---

## P0 — Correctness & Safety

### ✅ P0-1. Wire the pixel-rendering pipeline into the print path — **done 2026-07-21**
*(Implemented in the CLI layer per the layering constraint: `send` runs every frame through
`ImagePreprocessor.prepareForPrint(pixelData:dataSet:frameIndex:colorMode:)` by default, with a
`--raw` escape hatch. The two quarantined MONOCHROME1 tests were rewritten to the decided
behavior — windowed 8-bit MONOCHROME2, inverted exactly once — and re-enabled.)*
**Problem:** The print path forwards raw *stored* pixel values. `ImagePreprocessor`
(rescale, VOI/window, MONOCHROME1 inversion, 8-bit conversion, RGB→gray) exists but is
**never called** — it is dead code w.r.t. printing. Windowed CT/MR and MONOCHROME1 images
print with clinically incorrect grayscale/polarity.
**Files:** `Sources/dicom-print/main.swift` (SendCommand.run ~L350–447),
`Sources/DICOMKit/ImagePreprocessor.swift`. **Not** `PrintService.swift` — see the layering
constraint above; `DICOMNetwork` cannot import `ImagePreprocessor`, so the wiring lives in the CLI.
**Change:**
- Before building `PrintImageData`, run each frame through `ImagePreprocessor.prepareForPrint(dataSet:colorMode:)`.
- Apply Modality LUT / Rescale Slope&Intercept → VOI LUT / Window Center&Width → MONOCHROME1 inversion → output MONOCHROME2 8-bit (or 16-bit if the printer supports it and no window is applied).
- Update the descriptor (`bitsAllocated`, `photometricInterpretation`, `pixelRepresentation`) to match the *processed* bytes, not the source.
- Provide a `--no-preprocess` / `--raw` escape hatch for callers who deliberately want stored values.
- Resolve the pending MONOCHROME1 8-bit-vs-16-bit product decision: the two `XCTSkip`-quarantined
  `ImagePreprocessor` MONOCHROME1 tests encode the old expectation — this item's acceptance
  criteria *are* the decision, so update and **un-skip** those tests as part of this work.
**Acceptance:** A CT with Window Center/Width prints the windowed 8-bit image; a MONOCHROME1 image is inverted exactly once; output PI is MONOCHROME2; the quarantined MONOCHROME1 tests are re-enabled and pass.
**Tests:** windowed CT golden-image, MONOCHROME1 inversion, 16-bit→8-bit, rescale slope/intercept, signed pixel normalization.

### ✅ P0-2. Decompress encapsulated pixel data before N-SET — **done 2026-07-21**
*(`send` now decodes via `DICOMFile.tryPixelData()`, which also applies the JPEG-Baseline
YBR→RGB descriptor correction.)*
**Problem:** `dataSet[.pixelData]?.valueData` returns raw encapsulated fragments for
compressed transfer syntaxes (JPEG/JPEG2000/JPEG-LS/RLE). These are shipped verbatim →
malformed image box.
**Files:** `Sources/dicom-print/main.swift` (pixel extraction). CLI layer only — `DICOMFile.pixelData()`
lives in `DICOMKit`, which `DICOMNetwork` cannot import (see layering constraint).
**Change:** Detect the source transfer syntax; when encapsulated, decode via the existing
pixel-decode path (`DICOMFile.pixelData()` / `PixelData` frame accessors) to native
uncompressed frames before printing. Basic Grayscale/Color Image Boxes require native
uncompressed pixel data. Note: routing through `DICOMFile.pixelData()` also picks up the
JPEG Baseline/Extended YBR→RGB descriptor correction (`correctedDescriptorForDecodedBytes`),
so compressed-YBR color sources come out correctly labeled RGB for free — see P1-5.
**Acceptance:** JPEG Baseline, J2K, and RLE inputs print correctly.
**Tests:** compressed-input round-trip per codec asserting decoded byte length = rows×cols×samples×(bits/8).

### ✅ P0-3. Implement `parsePrinterStatus` (remove the stub) — **done 2026-07-21**
**Problem:** `parsePrinterStatus` (PrintService.swift ~L2165) is a stub that **always returns
`NORMAL`**, ignoring the N-GET response. `isNormal` is therefore always true.
**Files:** `Sources/DICOMNetwork/PrintService.swift`.
**Change:** Parse the N-GET response data set for Printer Status (2110,0010), Printer Status
Info (2110,0020), Printer Name (2110,0030), and (if returned) Manufacturer/Model. Reuse the
byte-scanning `extractStringValue` helper already used by `parsePrintJobStatus`. Optionally
request an Attribute Identifier List in the N-GET.
**Acceptance:** `dicom-print status` reports the printer's real NORMAL/WARNING/FAILURE + info text.
**Tests:** feed a synthetic N-GET response data set (NORMAL, WARNING+info, FAILURE) and assert parsed fields.

### ✅ P0-4. Non-zero exit code on print failure — **done 2026-07-21**
**Problem:** A returned failed `PrintResult` (`success == false`) prints `✗ Print failed` but
`run()` returns normally → process **exits 0**. Automation cannot detect failure.
**Files:** `Sources/dicom-print/main.swift` (SendCommand.run / printResult).
**Change:** After `printResult`, `throw` a `PrintFailure`/`ExitCode.failure` when `!result.success`
so ArgumentParser sets a non-zero exit. Keep the human-readable message.
**Acceptance:** failed print → exit code ≠ 0; success → 0; validation error → non-zero.
**Tests:** CLI exit-code tests (once the target is built in CI, see P3-4).

### ✅ P0-5. Surface DIMSE Error Comment / Error ID — **done 2026-07-21**
**Problem:** Error Comment (0000,0902), Error ID (0000,0903), Offending Element (0000,0901)
are defined in `CommandTag.swift` but never decoded. `printOperationFailed(DIMSEStatus)`
carries only the numeric code → users see generic messages, no printer diagnostic text.
**Files:** `Sources/DICOMNetwork/CommandSet.swift` (add accessors),
`Sources/DICOMNetwork/DICOMNetworkError.swift` (carry the text),
`Sources/DICOMNetwork/PrintService.swift` (populate on failure).
**Change:** Add `errorComment`/`errorID`/`offendingElement` accessors to `CommandSet`; thread
the text into `printOperationFailed` (or populate `PrintError.info`) and print it in the CLI.
Keep the scope minimal — accessors + error-enum threading is enough; exposing the fields on the
`DIMSEMessages.swift` N-response structs is optional and can be skipped to keep Milestone A small.
**Acceptance:** an SCP failure carrying "OUT OF FILM" shows that text to the user.
**Tests:** synthetic failure command set with Error Comment → assert text propagates to the thrown error.

### ✅ P0-6. Multi-frame pixel data handling — **done 2026-07-21**
*(`--frame N` (1-based, default 1) and `--all-frames` added; per-frame bytes and descriptors
are sent, with a clear out-of-range validation error.)*
**Problem:** The CLI sends the **entire** Pixel Data value as one image
(`dataSet[.pixelData]?.valueData`). For a multi-frame file (cine US, NM), that ships
rows×cols×frames bytes into an image box whose descriptor declares a single frame's
dimensions — malformed, same severity class as P0-2.
**Files:** `Sources/dicom-print/main.swift` (pixel extraction — same code path as P0-2).
**Change:** Use the `PixelData` frame accessors (already required by P0-2) to extract
individual frames. Add `--frame N` (default: first frame) and optionally `--all-frames`
(one image box per frame, subject to layout capacity). Implement together with P0-2 —
the decode path provides per-frame access for free.
**Acceptance:** a multi-frame file prints exactly the selected frame with a matching descriptor; `--frame` out of range → clear validation error.
**Tests:** multi-frame fixture → asserted frame byte length = rows×cols×samples×(bits/8); frame index bounds test.

---

## P1 — Interoperability

### ✅ P1-1. Always send image-box pixel attributes (unconditional descriptor) — **done 2026-07-22**
*(Implemented as "descriptor required": `executePrintWorkflow` validates one `PrintImageData`
per image up front and the Preformatted Image Sequence attributes are emitted unconditionally;
the discrete `setImageBox` throws a clear `encodingFailed` when called without a descriptor.
Signatures stay source-compatible; missing descriptors fail fast before any network activity.)*
**Problem:** Rows/Columns/Bits/PI etc. are emitted only `if let desc = imageDescriptor`.
`printImage` and `printWithTemplate` call `setImageBox` **without** a descriptor → image box
with pixel data but no dimensions → rejected by strict SCPs. (CLI `send` is OK — it builds descriptors.)
**Files:** `Sources/DICOMNetwork/PrintService.swift` (setImageBox, executePrintWorkflow, printWithTemplate).
**Change:** Derive a descriptor from the pixel data + a required minimal attribute set whenever
one is not supplied, or make the descriptor non-optional on the print entry points. Never emit
a Preformatted Image Sequence item without Rows/Columns/BitsAllocated/PhotometricInterpretation.
**Acceptance:** every image box N-SET includes the pixel-module attributes.
**Tests:** assert serialized N-SET always contains (0028,0010)/(0028,0011)/(0028,0100)/(0028,0004).

### ✅ P1-2. Rework `printWithTemplate` onto a single association — **done 2026-07-22**
*(Both `printWithTemplate` and `printImagesWithProgress` now run on `executePrintWorkflow`
(one association, PS3.4 H.4). The workflow gained an optional `progressHandler` so the
progress stream keeps its phase/percent updates; the template's layout is derived from its
Image Display Format via the new `layout(fromImageDisplayFormat:)`. Both methods gained
`imageDescriptors:`/`eventHandler:` parameters; the progress variant no longer performs the
extra printer-status N-GET on a separate association. The discrete public functions remain
for advanced callers, each documented as using its own association.)*
**Problem:** `printWithTemplate` (and `printImagesWithProgress`) call the discrete functions
(`createFilmSession`/`createFilmBox`/`setImageBox`/`printFilmBox`/`deleteFilmSession`), each of
which opens **its own association** — a PS3.4 H.4 violation; the Film Session UID is invalid in
later associations.
**Files:** `Sources/DICOMNetwork/PrintService.swift`.
**Change:** Reimplement `printWithTemplate` and `printImagesWithProgress` on top of the
single-association `executePrintWorkflow` core (or extract a shared inner routine that takes an
open association). Keep the discrete public functions for advanced callers but document that
they each use a separate association.
**Acceptance:** template + progress prints complete within one association (verify with mock SCP association count = 1).
**Tests:** mock SCP asserts a single A-ASSOCIATE per print job.

### ✅ P1-3. Honor the negotiated transfer syntax — **resolved 2026-07-22 (Explicit-VR-only decision)**
*(Took the documented-limitation route: all print presentation contexts now propose
**Explicit VR LE only**, so an implicit-only SCP cleanly rejects negotiation instead of
receiving mis-encoded data, and the Explicit-VR byte-scanning response parsers are always
valid. Full Implicit-VR support (serialize + parse) remains possible future work if a real
printer requires it.)*
**Problem:** Data sets are always serialized Explicit VR LE regardless of what the SCP accepted.
A printer that accepts only Implicit VR LE gets mis-encoded data. **The gap is two-sided:** all
response parsing (`parsePrinterStatus` once implemented, `parsePrintJobStatus`,
`parseImageBoxUIDs`, and the sequence-scoped `parseReferencedSOPInstanceUIDs`) is byte-scanning
that *assumes Explicit VR LE* — honoring a negotiated Implicit VR syntax on send while leaving
the parsers untouched silently breaks every response decode.
**Files:** `Sources/DICOMNetwork/PrintService.swift` (serializeElements + call sites + all response parsers).
**Change:** Read `negotiated.acceptedTransferSyntax(forContextID:)` and serialize with the
matching VR mode (`DICOMWriter` implicit vs explicit), **and** make the response parsers
VR-mode-aware (or replace byte-scanning with a proper `DICOMParser` decode). Alternatively, make
the deliberate decision to propose **only** Explicit VR LE in the presentation contexts and fail
association negotiation otherwise — that makes this item mostly moot, but it must be documented
as a conformance limitation, not left implicit.
**Acceptance:** against an Implicit-VR-only SCP, data sets encode *and* responses decode correctly (or the association is cleanly rejected with a documented reason).
**Tests:** mock SCP that accepts only Implicit VR LE; assert successful N-CREATE/N-SET **and** correct parsing of its responses (printer status, image-box UIDs).

### ✅ P1-4. DIMSE-response timeout — **done 2026-07-22**
*(New `receiveWithTimeout` races `association.receive()` against `configuration.timeout`;
the network read is not cancellation-aware, so on expiry the association is aborted to
unblock it and `operationTimeout` is thrown. Wired through `sendAndReceive` (workflow) and
every discrete receive loop. Live-timeout integration test blocked on the P3-4 mock SCP.)*
**Problem:** `association.receive()` for N-responses has no timer; a silent SCP hangs the tool.
**Files:** `Sources/DICOMNetwork/Association.swift` / `DICOMConnection.swift`, applied in `PrintService.swift`.
**Change:** Wrap DIMSE-response reads in an operation timeout (reuse `TimeoutConfiguration.operation`),
racing receive against a `Task.sleep`; on expiry, abort + throw a timeout error.
**Acceptance:** an SCP that accepts then stalls → tool errors within the timeout, no hang.
**Tests:** mock SCP that never answers N-CREATE → assert timeout error.

### ✅ P1-5. Color-space conversion + color/mode validation — **done 2026-07-21** *(with one carve-out)*
*(YBR_FULL→RGB conversion implemented in `ImagePreprocessor`; RGB→grayscale for grayscale mode
already existed and is now wired via the default preprocessing path. Carve-out: uncompressed
**subsampled** YBR (YBR_FULL_422 etc.) is explicitly rejected with a clear error rather than
mis-converted, because `PixelDataDescriptor.bytesPerFrame` does not yet model packed 4:2:2
layouts — fixing that is a DICOMCore change, tracked as remaining work below.)*
**Problem:** YBR_FULL/YBR_FULL_422 sources are sent with stored PI (no YBR→RGB); an RGB image
with `--color grayscale` is silently sent mismatched.
**Scope update:** the compressed-YBR half is **overtaken by P0-2** — `DICOMFile.pixelData()` now
applies `correctedDescriptorForDecodedBytes` (JPEG Baseline/Extended decodes come out correctly
labeled RGB), so once P0-2 routes the CLI through that path, compressed color sources are handled.
What remains here:
- **Uncompressed** YBR_FULL / YBR_FULL_422 sources: explicit YBR→RGB conversion, including
  4:2:2 chroma upsampling for YBR_FULL_422.
- RGB→grayscale conversion for `--color grayscale`.
- Color/mode mismatch validation (reject or auto-correct with a clear message).
**Files:** `Sources/dicom-print/main.swift`, `Sources/DICOMKit/ImagePreprocessor.swift` (existing helpers). CLI layer only (layering constraint).
**Acceptance:** uncompressed YBR ultrasound prints correct colors; RGB-with-grayscale is converted or rejected.
**Tests:** uncompressed YBR→RGB (incl. 422 upsampling) unit test; mismatch validation test.

---

## P2 — Robustness & Conformance Hardening

### ✅ P2-1. Optional pre-print printer-status check — **done 2026-07-22**
`--check-status` N-GETs printer status before printing; aborts (non-zero exit) on FAILURE,
warns on WARNING. Opt-in — not default (extra round-trip).

### ✅ P2-2. Bound `parseImageBoxUIDs` to the Referenced Image Box Sequence — **done 2026-07-22**
`parseImageBoxUIDs` scans the whole data set for (0008,1155) and can mis-attribute UIDs. Replace
its body with the existing scoped `parseReferencedSOPInstanceUIDs(from:withinSequence: .referencedImageBoxSequence)`.
**Tests:** a film-box response containing both image-box and annotation-box sequences → only image-box UIDs returned.

### ✅ P2-3. Explicit cleanup on failure (defensive N-DELETE) — **done 2026-07-22**
*(The workflow catch now attempts a best-effort in-association Film Session N-DELETE
before aborting whenever the session was created; the inner guards no longer abort
pre-throw so the association is still alive for the cleanup. Integration-tested.)*
`executePrintWorkflow`'s catch only aborts. While abort discards the hierarchy, add a best-effort
in-association Film Box N-DELETE / Film Session N-DELETE before abort where the association is still alive,
to be friendly to SCPs that persist state.

### ✅ P2-4. Reject empty Print Job UID from N-ACTION — **done 2026-07-22** (workflow no longer records empty job UIDs)
The workflow appends an empty Job UID if the N-ACTION response lacks one; the discrete `printFilmBox`
correctly rejects it. Make the workflow consistent (warn or error).

### ✅ P2-5. Port bounds guard — **done 2026-07-22** (`UInt16(exactly:)` + ValidationError)
`UInt16(urlPort)` in `parseServerURL` traps on port > 65535. Validate and throw a `ValidationError`.

### ✅ P2-6. Signed pixel data handling — **done 2026-07-21** (via P0-1)
`ImagePreprocessor.extractPixelValues` sign-extends Pixel Representation = 1 sources and the
pipeline outputs unsigned 8-bit P-Values, so signed values are never sent to an Image Box
(except with the explicit `--raw` bypass).

### P2-7. Late N-EVENT-REPORT during association release
The SCU now handles N-EVENT-REPORT-RQs interleaved *before* its own awaited response, but an
event arriving between the last DIMSE response and `release()` collides with release processing.
Tolerate (decode + acknowledge, or at minimum discard cleanly) an event received during the
release window instead of failing the release.
**Tests:** mock SCP pushes an N-EVENT-REPORT immediately before A-RELEASE-RP → release still succeeds (blocked on the P3-4 mock SCP).

---

## P3 — CLI & Coverage

### ✅ P3-1. Add missing CLI options — **done 2026-07-22**
- `--magnification replicate|bilinear|cubic` (library enum has no NONE case; add if a printer needs it).
- `--film-destination magazine|processor|bin-1|bin-2`.
- Full `FilmSize` set exposed (`8.5x11`, `24x24cm`, `24x30cm` added).

### ✅ P3-2. Machine-readable output contract — **done 2026-07-22**
`send` gained `--format json` (result object `{success, printJobUID?, filmSessionUID?,
filmBoxUID?, error?}` on stdout). Contract documented in the CLI README: stdout = JSON only,
stderr = all human-readable text, exit code 0/non-zero.

### ✅ P3-3. C-ECHO / verification pre-flight (optional) — **done 2026-07-22**
`--verify` on `send` performs C-ECHO (`DICOMVerificationService.verify`) against the printer AE
before printing and fails with a clear message when the AE does not respond correctly.

### ✅ P3-4. Build & test the CLI in CI + integration tests — **done 2026-07-22**
- ~~Re-enable the `DICOMNetworkTests` target~~ — done (`PACSIntegrationTests` quarantined).
- ~~Re-enable the `dicom-print` executable target~~ — done (owner approved; product + target
  active in `Package.swift`, builds with **zero warnings**).
- ~~Build a mock Print SCP~~ — done: `Tests/DICOMNetworkTests/MockPrintSCP.swift`, an
  in-process NWListener-based SCP handling A-ASSOCIATE accept/reject, N-GET, N-CREATE
  (session/film box with Referenced Image Box Sequence sized from the Image Display Format),
  N-SET, N-ACTION, N-DELETE, A-RELEASE — with scriptable failure injection (status + Error
  Comment/ID), silence-after-accept, context rejection, omitted job UID, and a pushed
  N-EVENT-REPORT. 10 integration tests in `PrintSCPIntegrationTests.swift`.

---

## Test Matrix (updated 2026-07-22)

| Area | Test | Status |
|---|---|---|
| Printer status | NORMAL / WARNING / FAILURE / UNKNOWN parsed | ✅ unit tests done |
| Error detail | Error Comment / Error ID surfaced, offending elements decoded | ✅ unit tests done |
| Pixels | MONOCHROME1 inversion (8-bit + 16-bit, un-quarantined), windowed output | ✅ unit tests done |
| Multi-frame | frame selection, out-of-range rejection | ✅ unit tests done |
| Color | uncompressed YBR_FULL→RGB, subsampled-YBR rejection | ✅ unit tests done |
| Descriptors | workflow + setImageBox refuse missing descriptors before network | ✅ unit tests done |
| Layout | template Image Display Format → PrintLayout (incl. malformed fallback) | ✅ unit tests done |
| Scoped UIDs | annotation-box vs image-box UID separation | ✅ unit tests done |
| Compression | JPEG/J2K/RLE decoded before send (decode path) | ✅ covered by `DICOMFilePixelDataYBRDecodeTests` + codec suites; end-to-end send blocked on mock SCP |
| Association | accept / zero-context rejection | ✅ integration tests done (abort-source variants still open) |
| Workflow | happy path: session→box→image-box→N-ACTION→delete→release, single A-ASSOCIATE per job | ✅ integration tests done |
| Failure | failure at N-CREATE/N-SET/N-ACTION → error detail + defensive N-DELETE + abort | ✅ integration tests done |
| Timeout | SCP accepts then goes silent → `operationTimeout` within the configured window | ✅ integration test done |
| Events | interleaved N-EVENT-REPORT delivered + acknowledged mid-workflow | ✅ integration test done (release-window case still open — P2-7) |
| Multi-film | 3 images on 2×1 → 2 film boxes, one association | ✅ integration test done |
| Job UID | omitted Print Job UID not recorded (P2-4) | ✅ integration test done |
| CLI | exit codes end-to-end via a spawned binary; JSON contract assertions | ⏳ open (target now builds in CI; spawn-based CLI tests not yet written) |

> Note: full `DICOMNetworkTests` runs currently stall in a pre-existing
> `StorageCommitmentServiceTests` hang (see Out of Scope) — run print suites with
> `swift test --filter 'PrintServiceTests|CommandSetTests|DICOMFilePixelDataYBRDecodeTests'`
> until that suite is fixed or quarantined.

---

## Suggested Sequencing

0. ✅ **Milestone 0 (housekeeping)** — done 2026-07-21: the pending print work was committed in
   two logical commits (YBR descriptor fix; print enhancements + docs).
1. ✅ **Milestone A (safety)** — done 2026-07-21: P0-3 (status parse), P0-4 (exit code), P0-5 (error detail, minimal scope).
2. ✅ **Milestone B (image fidelity)** — done 2026-07-21: P0-1 (preprocess) + P0-2 (decompress) + P0-6 (multi-frame) + P1-5 (color, subsampled-YBR carve-out) + P2-6 (signed) — implemented in the CLI layer per the layering constraint. Remaining from B: uncompressed subsampled-YBR support needs `bytesPerFrame` 4:2:2 modeling in DICOMCore.
3. ✅ **Milestone C (interop)** — done 2026-07-22: P1-1 (descriptor required + unconditional attrs), P1-2 (single-association template/progress printing), P1-3 (Explicit-VR-LE-only decision, documented), P1-4 (DIMSE-response timeout).
4. ✅ **Milestone D (coverage)** — done 2026-07-22: `dicom-print` target enabled (owner
   approved, zero warnings), MockPrintSCP harness + 10 integration tests covering the
   previously blocked matrix rows (happy path, single association, multi-film, failure
   injection with error detail, defensive cleanup, timeout, zero-context rejection,
   interleaved events, omitted job UID, printer status). Still open from D's wish list:
   spawn-based CLI end-to-end tests; fixing/quarantining the hanging
   `StorageCommitmentServiceTests` case so the *full* `DICOMNetworkTests` suite can gate CI.
5. ✅ **Milestone E (polish)** — done 2026-07-22 except **P2-7**: P2-1/2/3/4/5 + P3-1/2/3
   all landed (P2-3 and P3-2 in the Milestone D commit).

---

## Out of Scope (tracked separately)

- Print SCP (provider) role.
- Uncompressed subsampled YBR (YBR_FULL_422/PARTIAL) print support — needs packed-4:2:2
  `bytesPerFrame` modeling in `DICOMCore.PixelDataDescriptor` first (currently rejected
  with a clear error in the print path).
- Known CI hazard (found 2026-07-21): a `StorageCommitmentServiceTests` case hangs
  indefinitely when run in this environment — full `DICOMNetworkTests` runs stall after
  ~880 green tests. Investigate/quarantine before wiring the suite into a CI gate (P3-4).
- VOI LUT *Box* and full Overlay Box (overlay-plane extraction from 60xx groups).
- Presentation LUT *Data* variant (only LUT Shape is implemented).
- `PrintQueue` / `PrinterRegistry` CLI surface.
