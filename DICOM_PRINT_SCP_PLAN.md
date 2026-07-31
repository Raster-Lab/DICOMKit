# DICOM Print SCP (Printer Emulator) — Implementation Plan

Goal: make DICOMKit act as a **DICOM printer emulator**. We listen as a Print SCP; any Print
SCU (modality, workstation, third-party tool) associates, sends film sessions, film boxes and
image boxes, and issues N-ACTION *print*. We compose the film and **display the finished film
on screen** — the primary output. Emitting to a paper laser printer (CUPS/`lp`), PDF, or PNG
is a secondary sink off the same composed film.

**Verdict: yes, this is feasible, and most of the hard parts already exist.** It is additive —
no changes to the SCU are required. Estimated ~2,900 new lines (library + viewer + CLI +
tests), the single genuinely new piece being film composition → bitmap.

> **Primary use case (confirmed with the user): on-screen emulator.** The SCP is a *listener*
> that receives print jobs from any SCU and shows the resulting film on screen — this is what
> the product is for. Paper output is opt-in. Milestone ordering below reflects that: the
> viewer is a first-class milestone, not a Studio nicety, and `PaperPrinterSink` is optional.

---

## Status (2026-07-29)

### Interoperability hardening (done)

Before the UI, both directions were hardened for arbitrary peers and verified against
**DCMTK 3.7.0** (`Tests/DICOMPrintKitTests/DCMTKInteropTests.swift`, auto-skipped when DCMTK
is absent). Conformance statement: `PRINT_CONFORMANCE.md`.

| Fix | Why |
|---|---|
| SCU proposes the meta **and** individual SOP Classes, routing each N-service to an accepted context (`PrintPresentationContexts`) | A printer that rejects the meta class was previously unusable — the SCU proposed one context and gave up |
| Configuration Information (2010,0150) threaded end to end | Studio and the CLI collected it; `PrintOptions` had no field and the workflow never sent it. Several vendors require it |
| 0x0106 reclassified as a failure (`DIMSEStatus`) | It was treated as a warning, so a job sailed past a printer's rejection and failed later with a misleading code. Found by running our SCU against `dcmprscp` |
| Trim (2010,0140) omitted when NO; Requested Decimate/Crop Behavior (2020,0040) omitted when DECIMATE | Printers that do not implement these reject the box for merely carrying them |
| SCP idle-association timeout (default 300 s) | A peer that vanished held its slot forever; `maxConcurrentAssociations` dead peers wedged the printer |
| SCP answers A-ASSOCIATE-RJ at capacity | Dropping the socket reads as "connection reset" to a modality; a transient rejection is actionable |

Verified against DCMTK: `dcmpsprt`/`dcmprscu` → our SCP composes the film; our SCU →
`dcmprscp` (IHE Full profile) completes film session, film box, image box, N-ACTION and
N-DELETE.

Suite state (2026-07-29): `swift build` clean; `PrintSCPTests.swift` 74 tests and
`DICOMPrintKitTests` 63 tests green (the DCMTK cases skip when DCMTK is absent).

**Where the Studio surface stands.** Milestone E below is the *emulator* screen and is still
unbuilt. The Studio print work that has landed is the **SCU** side — mark in the viewer, print
settings, execution, printer management and job history — tracked separately in
`DICOM_PRINT_STUDIO_PLAN.md`. `FilmPreviewView` (Milestone E's second precedent) now renders
real frame thumbnails, so generalizing it to a `ComposedFilm` is still the intended path.

## Status (2026-07-28)

**Checkpoint 2 of §3 is done and green: the emulator composes what it receives.** Point any
Print SCU at `DICOMPrintServer`, and the finished film lands on a sink — screen, PDF, PNG/TIFF,
or a real CUPS queue. Only the Studio screen (E) and the CLI (F) remain.

| Milestone | State | Files |
|---|---|---|
| A — protocol machine | ✅ done | `Sources/DICOMNetwork/PrintSCP.swift`, `PrintSCPTypes.swift`, `PrintSCPEncoder.swift` |
| B — SCP-direction parser | ✅ done | `Sources/DICOMNetwork/PrintDatasetReader.swift`, `PrintSCPParser.swift` |
| C — `FilmComposer` | ✅ done | `Sources/DICOMPrintKit/Printing/FilmGeometry.swift`, `ComposedFilm.swift`, `FilmComposer.swift` |
| D — `PrintOutputSink` | ✅ done | `Sources/DICOMPrintKit/Printing/PrintOutputSink.swift`, `FilmComposingPrintHandler.swift` |
| G — loopback, status matrix, composer, sinks, end-to-end | ✅ partial | `Tests/DICOMNetworkTests/PrintSCPTests.swift` (74), `Tests/DICOMPrintKitTests/` (63) |
| E — emulator screen | ✅ done | `Sources/DICOMStudio/Views/Print/PrintSCPView.swift`, `ViewModels/PrintSCPViewModel.swift` |
| F — `dicom-printscp` CLI | ✅ done | `Sources/dicom-printscp/` (4 files + README), shared core in `Sources/DICOMPrintKit/Printing/PrintSCPSettings.swift`, `PrintSCPService.swift`, `PrintSCPConsole.swift`, `PrintSCPSimulator.swift` |

### Milestone F as built (2026-07-31)

Subcommands: `serve` (default), `simulate`, `status`, `queues`. The plan sketched
`simulate <film.json>`; it takes **DICOM files** instead — the composer needs pixels, and going
through `PrintImagePreparer` means a simulated sheet is prepared by the same code an SCU
prepares a real one with. A `film.json` descriptor would have been a third, untested path.

The shared-API rule drove the shape: everything both surfaces need moved *out* of DICOMStudio
into DICOMPrintKit, and Studio now consumes it rather than owning it.

| Shared type | What it owns | Used by |
|---|---|---|
| `PrintSCPSettings` (+ `PrintSCPSettingsFile`) | every knob, the `PrintSCPConfiguration` / `FilmComposerConfiguration` mapping, the JSON document | Studio's settings sheet, `--config` |
| `PrintSCPService` | sink stack, delegate, server assembly, thumbnails, paper queues | Studio's view model, `serve` / `simulate` / `queues` |
| `PrintSCPConsole` (+ `PrintSCPLogEntry`, `PrintSCPSessionCounters`) | the wording of every event, film line, startup echo and total | Studio's event log, the CLI's stdout |
| `PrintSCPSimulator` | film assembly from prepared images, no network | `simulate` |

Two defects the live SCU→SCP run caught, both fixed:

- `--max-films` counted films off the **screen stream** (delivered the moment a sheet is
  composed), so the listener stopped mid-N-ACTION: the SCU saw "Association aborted" and the
  PNG was never written. It now counts `.filmPrinted` — emitted after the sinks have written —
  and waits for the association to release (5 s grace) before stopping.
- The association line rendered `127.0.0.1:53167:0`: the Print SCP reports the whole endpoint in
  `AssociationInfo.remoteHost` and leaves `remotePort` at 0. Fixed in the shared console, so
  Studio's log was fixed with it.

### Layering decision

Everything print-related lives under one hood: the DIMSE machine in `DICOMNetwork` (where the
other SCPs are), and **all** composition and output in **`DICOMPrintKit`**, alongside the
existing SCU-side `PrintImagePreparer` / `PrintWorkflow` / `PrintOptionCatalog`. The plan's
original `Sources/DICOMKit/Printing/` location is not viable — the composer consumes
`ReceivedFilm`, and `DICOMKit` must not gain a networking dependency. `DICOMPrintKit` already
sits above both.

### Notes from the implementation

- **The SCU's Image Display Format order was a real conformance bug and is now fixed.**
  PS3.3 C.13.3 defines `STANDARD\C,R` as columns-first; `PrintLayout.imageDisplayFormat`
  emitted rows-first, so every non-square layout printed transposed on a conformant printer.
  `PrintLayout` is now the single source for the string, every template and the print workflow
  derive from it, and both parse paths share `PrintImageDisplayFormat`.
- `PrintImageDisplayFormat` (new) parses `STANDARD` / `ROW` / `COL` / `SLIDE` / `SUPERSLIDE` /
  `CUSTOM`. It drives image-box allocation on the SCP, cell layout in the composer, and the
  SCU's own box-count maths.
- `MockPrintSCP` was **not** deleted. It stays as the SCU's failure-injection harness (silence,
  reject-all-contexts, omitted job UID); the real SCP is a separate, stateful implementation.
- Annotation boxes follow the standard flow: a film box that carries an Annotation Display
  Format ID gets `annotationBoxesPerFilm` Basic Annotation Boxes back in the N-CREATE response
  for the SCU to N-SET.
- Presentation LUT instances are accepted and their *shape* is honored during composition
  (INVERSE / LIN OD invert); LUT data tables remain the documented gap.
- Density: `.paperDirect` is the default, `.filmEmulation` inverts the whole sheet. Four
  inversions compose — MONOCHROME1, Polarity REVERSE, INVERSE/LIN OD LUT, film emulation.
- Composer goldens are expressed as *determinism + sensitivity + pixel probes* rather than
  committed bitmap hashes, which would churn with every CoreGraphics release.
- Colour films are drawn into a 32 bpp RGBX context and compacted to 24 bpp: a bitmap
  `CGContext` cannot be 24 bpp RGB, though a `CGImage` can.
- Error Comment (0000,0902) is transliterated to ASCII before transmission — `CommandSet`
  encodes as ASCII and silently drops a value containing so much as an "×", which would throw
  away the only diagnostic an SCU developer gets.

---

## 0. What already exists (verified in this repo)

| Need | Already there | Where |
|---|---|---|
| Print SOP Class UIDs | ✅ all 11, public constants | [PrintService.swift:29-52](Sources/DICOMNetwork/PrintService.swift#L29-L52) |
| Print domain model (`FilmSession`, `FilmBox`, `ImageBoxContent`, `PrintLayout`, `FilmSize`, `MagnificationType`, `PresentationLUTShape`, `PrinterStatus`, `PrintJobStatus`, `PrintEvent`) | ✅ complete, `Sendable` | [PrintService.swift:157-950](Sources/DICOMNetwork/PrintService.swift#L157-L950) |
| `PrintLayout.layout(fromImageDisplayFormat:)` — parses `STANDARD\r,c` | ✅ | [PrintService.swift:4149](Sources/DICOMNetwork/PrintService.swift#L4149) |
| N-CREATE/N-SET/N-ACTION/N-DELETE/N-GET/N-EVENT-REPORT **request *and* response** message types | ✅ both directions already modelled | [DIMSEMessages.swift:720-1440](Sources/DICOMNetwork/DIMSEMessages.swift#L720-L1440) |
| SCP listener skeleton: `NWListener`, association accept/reject, AE whitelist/blacklist, presentation-context negotiation, max-concurrent-associations, `AsyncStream` events, delegate protocol | ✅ **directly reusable pattern** | [StorageSCP.swift:388-1105](Sources/DICOMNetwork/StorageSCP.swift#L388-L1105) |
| A second SCP already built on that pattern (proof it generalizes) | ✅ | [StorageCommitmentSCP.swift](Sources/DICOMNetwork/StorageCommitmentSCP.swift) (1,222 lines) |
| PDU/PDV plumbing: `MessageAssembler`, `MessageFragmenter`, `PDUDecoder` | ✅ | `MessageAssembler.swift`, `PDUDecoder.swift` |
| A working, *scriptable* Print SCP already answering every N-service | ✅ **574 lines, test-only** | [MockPrintSCP.swift](Tests/DICOMNetworkTests/MockPrintSCP.swift) |
| Pixel rendering to `CGImage` | ✅ | [PixelDataRenderer.swift](Sources/DICOMKit/PixelDataRenderer.swift), [DICOMImageExporter.swift](Sources/DICOMKit/ImageExport/DICOMImageExporter.swift) |
| Annotation/overlay drawing on a `CGContext` | ✅ | [AnnotationRenderer.swift](Sources/DICOMKit/AnnotationRenderer.swift) |

**The key insight:** `MockPrintSCP` is already a functioning Print SCP protocol machine — it
accepts associations, negotiates contexts, answers N-GET/N-CREATE/N-SET/N-ACTION/N-DELETE,
returns a Referenced Image Box Sequence sized from Image Display Format, and pushes
N-EVENT-REPORTs. It is deliberately stateless (it discards datasets). **Milestone 1 is
promoting that machine to `Sources/DICOMNetwork/PrintSCP.swift` and giving it state.**

### What is genuinely missing

1. **Server-side dataset parsing** — the SCU serializes film-session/film-box/image-box
   attributes; the SCP must parse them back. `MockPrintSCP` has only a 35-line
   `extractString` hack ([MockPrintSCP.swift:492](Tests/DICOMNetworkTests/MockPrintSCP.swift#L492)).
   We need a real element walk that handles both negotiated VRs and the encapsulated
   `PixelData` inside a Basic Grayscale/Color Image Box N-SET.
2. **Print job state machine** — film session → N film boxes → M image boxes each, with the
   PS3.4 Annex H lifecycle (created / printing / done / failure) and N-DELETE cleanup.
3. **Film composition → paper** — lay out the image boxes on the film per Image Display
   Format / Film Orientation / Film Size / Magnification / Border Density / Trim, rasterize,
   then hand to CUPS. This is the only part with no precedent in the repo.

---

## 1. Architecture

```
DICOMPrintServer (actor)                  ← mirrors DICOMStorageServer
 └─ PrintSCPAssociation (actor, one per connection)
     ├─ PrintSCPSession  — N-service state machine (film session/boxes/image boxes)
     ├─ PrintSCPParser   — dataset → FilmSession / FilmBox / ImageBoxContent + PrintImageData
     └─ PrintSCPEncoder  — PrinterStatus / PrintJobStatus / Referenced*Sequence → dataset
                    ↓ on N-ACTION (print)
            FilmComposer        — image boxes → one page bitmap (CGImage)  [DICOMKit]
                    ↓
            PrintOutputSink (protocol)
              ├─ ScreenSink  ★ PRIMARY — publishes ComposedFilm to the live viewer
              ├─ PDFSink            — CGPDFContext → .pdf
              ├─ ImageSink          — .png/.tiff per film
              └─ PaperPrinterSink   — CUPS `lp` / NSPrintOperation → laser printer (opt-in)
```

Sinks compose: the emulator normally runs `ScreenSink` alone, or `ScreenSink` + `PDFSink` to
keep an archive of everything received.

Layering rule (matches the project's shared-API rule, see `APP_CLI_SHARED_API.md`):

- **`Sources/DICOMNetwork/PrintSCP.swift`** — protocol machine only. No CoreGraphics, no
  printing. Produces `ReceivedFilm` values (already-decoded `PrintImageData` per box) and
  hands them to a `PrintSCPDelegate`.
- **`Sources/DICOMKit/Printing/FilmComposer.swift`** — pure composition/rasterization.
  Testable without a network.
- **`Sources/DICOMKit/Printing/PrintOutputSink.swift`** — output backends.
- **`Sources/dicom-printscp/`** — thin CLI over the above; Studio later reuses the same types.

This keeps `DICOMNetwork` free of imaging deps, exactly as `StorageSCP` is free of them today.

---

## 2. Milestones

### Milestone A — `PrintSCP.swift`: the protocol machine (~700 lines)

Promote `MockPrintSCP` into the library and make it stateful.

- `PrintSCPConfiguration` — model `StorageSCPConfiguration`
  ([StorageSCP.swift:12-165](Sources/DICOMNetwork/StorageSCP.swift#L12-L165)) field-for-field:
  `aeTitle`, `port`, `maxPDUSize`, `implementationClassUID`, `maxConcurrentAssociations`,
  AE whitelist/blacklist — **plus** print-specific: `supportsColor`, `supportedFilmSizes`,
  `supportedMediumTypes`, `maxImageBoxesPerFilm`, `printerName`, `manufacturer`,
  `acceptPresentationLUT`, `acceptAnnotationBox`.
- `DICOMPrintServer` actor — copy the lifecycle of `DICOMStorageServer`
  ([StorageSCP.swift:447-673](Sources/DICOMNetwork/StorageSCP.swift#L447-L673)) verbatim,
  including the `.waiting`-vs-`.ready` listener race and the 10s start timeout (those were
  hard-won; do not re-derive them).
- Presentation contexts to accept: the two **meta** SOP classes (`…5.1.1.9`, `…5.1.1.18`) plus
  the individual ones (`…1.1`, `…1.2`, `…1.4`, `…1.4.1`, `…1.14`, `…1.16`, `…1.23`, `…1.15`)
  and Verification. Transfer syntaxes: Explicit VR LE **and Implicit VR LE** — the SCU already
  handles both ([`acceptOnlyImplicitVR`](Tests/DICOMNetworkTests/MockPrintSCP.swift#L51)), and
  real modalities frequently propose implicit-only.
- `PrintSCPSession` state machine per association:
  - N-CREATE Film Session → allocate UID, store attributes, enforce one-session-per-association.
  - N-CREATE Film Box → parse Image Display Format, allocate `rows×columns` image-box UIDs,
    return **Referenced Image Box Sequence (2010,0510)** and **Referenced Film Session
    Sequence (2010,0500)**. The encoder already exists at
    [MockPrintSCP.swift:448](Tests/DICOMNetworkTests/MockPrintSCP.swift#L448).
  - N-SET Image Box → parse `ImageBoxContent` + `PrintImageData`; reject unknown box UIDs with
    `0x0112` (no such SOP Instance).
  - N-SET Film Box → attribute update on an existing box.
  - N-ACTION (action type 1 on Film Box = print film, on Film Session = print session) →
    compose + emit, return a Print Job SOP Instance UID.
  - N-DELETE Film Box / Film Session → cascade-delete children.
  - N-GET on Printer SOP Instance → Printer Status/Status Info/Name/Manufacturer/Model/serial/
    software version/date/time.
  - N-GET on Print Job → Execution Status, Execution Status Info, Print Priority, creation
    date/time, Printer Name.
- **Status codes must be right** (PS3.4 H.4 / PS3.7 C): `0x0000` success, `0xB600` memory
  allocation warning, `0xB605` requested min density out of range, `0xC000` unable to process,
  `0xC600` film session printing (retry), `0xC603` image size larger than image box,
  `0x0110` processing failure, `0x0112` no such SOP instance, `0x0117` invalid object instance,
  `0x0119` class-instance conflict, `0x0120` missing attribute, `0x0121` missing attribute
  value, `0x0122` SOP class not supported, `0x0106` invalid attribute value. Add a
  `PrintSCPStatus` enum next to `DIMSEStatus`.
- **N-EVENT-REPORT push** — on printer state change (e.g. out of film/paper), push to any SCU
  that negotiated the Printer SOP Class, reusing `PrinterEventType`
  ([PrintService.swift:467](Sources/DICOMNetwork/PrintService.swift#L467)). Push logic already
  demonstrated at [MockPrintSCP.swift:432](Tests/DICOMNetworkTests/MockPrintSCP.swift#L432).

### Milestone B — `PrintSCPParser` (~350 lines)

A real dataset reader for the SCP direction, honoring the negotiated VR.

- Walk elements (explicit **and** implicit VR LE), including SQ with both defined and
  undefined length, and `PixelData` with a length up to the film-box byte budget.
- Map to the existing model types — no new value enums; `FilmSize`, `MediumType`,
  `MagnificationType`, `FilmOrientation`, `TrimOption`, `ImagePolarity`,
  `DecimateCropBehavior`, `PresentationLUTShape` all already have raw-value inits.
- Produce `PrintImageData` from the image-box item (0028 group + 7FE0,0010). That struct is
  already exactly the right shape
  ([PrintService.swift:586](Sources/DICOMNetwork/PrintService.swift#L586)) — the SCU builds it,
  the SCP now reads it back. Round-trip symmetry is a free test.
- Validate: reject unsupported `FilmSize`, `bitsAllocated ∉ {8,16}`, samples≠1 on the
  *grayscale* image box SOP class, missing `Rows`/`Columns`, and image larger than the box
  → `0xC603`.

> Consider extracting the walk as `DICOMDatasetWalker` in `DICOMKit` — the same ad-hoc walking
> already appears in `PrintService.parseReferencedSOPInstanceUIDs`
> ([PrintService.swift:2623](Sources/DICOMNetwork/PrintService.swift#L2623)) and in
> `MockPrintSCP.extractString`. One shared walker retires all three.

### Milestone C — `FilmComposer` (~450 lines, `Sources/DICOMKit/Printing/`)

The new work. Input: a `ReceivedFilm` (film box attributes + ordered image boxes). Output: a
page bitmap.

- Page geometry from `FilmSize` (14INX17IN → 355.6×431.8 mm, A4, etc.) at a configurable DPI
  (default 300; 150 for drafts).
- `FilmOrientation` PORTRAIT/LANDSCAPE.
- Grid from Image Display Format: `STANDARD\c,r`, plus `ROW\`, `COL\`, `SLIDE`, `SUPERSLIDE`,
  `CUSTOM\i`. Reuse `PrintLayout.layout(fromImageDisplayFormat:)` and extend it for the
  non-STANDARD forms (currently it defaults them to 1×1).
- Per box: window/level via `PresentationLUTShape` (IDENTITY vs INVERSE — inverse is the
  common film case), `ImagePolarity` NORMAL/REVERSE, `MagnificationType`
  (NONE/REPLICATE/BILINEAR/CUBIC — `ImageResizer` already has the kernels),
  `DecimateCropBehavior`, `RequestedImageSize` in mm.
- Border/empty density, `TrimOption` crop marks, and `PrintAnnotation` text (patient/study
  headers) via `AnnotationRenderer`.
- **Density mapping** — DICOM film assumes optical density on transparency; on *paper* the
  sensible default is to render MONOCHROME2 directly and let min/max density act as a
  black/white clamp. Expose `DensityMapping.filmEmulation` vs `.paperDirect` (default
  `.paperDirect`) rather than silently guessing.

### Milestone D — `PrintOutputSink` (~250 lines)

```swift
public protocol PrintOutputSink: Sendable {
    func emit(film: ComposedFilm, job: PrintJobInfo) async throws
}
```

- **`ScreenSink`** ★ — the emulator's default. Holds an `AsyncStream<ComposedFilm>` (plus a
  bounded ring buffer of the last N films for scrollback) that the viewer subscribes to. The
  SCP must never block on a viewer that isn't draining: buffer, drop-oldest, and report the
  drop in the event log.
- `PDFSink` — `CGPDFContext`, one page per film box; multi-film jobs → one PDF.
- `ImageSink` — PNG/TIFF per film, path pattern with job/session/box tokens.
- `PaperPrinterSink` (opt-in) — write the PDF to a temp file, then `lp -d <queue> -o media=A4
  -o fit-to-page -n <copies>`. Enumerate queues with `lpstat -a`. `NumberOfCopies` (2000,0010)
  maps to `-n`. Guard behind `--allow-paper` so a misconfigured emulator can't spool 500 pages
  by accident; on Linux the same `lp` path works unchanged.

### Milestone E — The emulator screen ★ (~500 lines, `Sources/DICOMStudio/Views/Print/`)

This is the deliverable the emulator exists for. **Two precedents already in the repo make it
mostly assembly, not invention:**

- [LocalListenerView.swift](Sources/DICOMStudio/Views/LocalListenerView.swift) (227 lines) —
  an existing **SCP listener panel**: start/stop toggle, running indicator, config sheet
  locked while running, live event log, "connect from another DICOM application" empty state.
  Copy this structure wholesale for the Print SCP listener half.
- [FilmPreviewView.swift](Sources/DICOMStudio/Views/Print/FilmPreviewView.swift) (118 lines) —
  already renders a **film sheet with a rows×columns cell grid**. It currently previews the
  SCU-side selection; generalize it to take a `ComposedFilm` so both the outgoing preview and
  the incoming emulated film use one view.

`PrintEmulatorView` = listener panel (top) + received-films list (left) + film display (right):

- **Listener panel** — AE title, port, status dot, start/stop, calling-AE log, association
  count. Mirrors `LocalListenerView` exactly.
- **Job list** — one row per received film: timestamp, calling AE, film size, layout, image
  count, status. Newest first, auto-selects on arrival so an incoming job appears immediately.
- **Film display** — the composed film at fit-to-window, zoom/pan, 1:1 toggle, and a
  side-by-side "film attributes" inspector (density, magnification, polarity, LUT shape,
  annotations) so it doubles as a **debugging tool for SCU implementers** — the real value of
  an emulator over a printer.
- **Actions** — Save as PDF/PNG, Send to paper printer, Copy attributes as JSON, Clear.
- Subscribes to `ScreenSink`'s stream on a `PrintEmulatorViewModel` actor; the view never
  touches `DICOMNetwork` types directly.

**Headless variant for the CLI** — `dicom-printscp serve --output png --open` writes each film
and opens it, so the emulator is usable without Studio. Full screen UI is Studio-only.

### Milestone F — `dicom-printscp` CLI (~400 lines)

```
dicom-printscp serve --port 11112 --ae-title DCMPRINT \
    --output png --open \
    --output-dir ~/Films \
    [--paper-queue HP_LaserJet --allow-paper] \
    [--dpi 300] [--color] [--film-size A4] [--max-associations 4] \
    [--allow-ae MOD1 --allow-ae MOD2] [--json]
dicom-printscp queues            # list CUPS queues
dicom-printscp simulate <film.json>   # compose without a network (composer dev loop)
```

Follow `NetworkConsoleFormatter` for output so terminal-vs-app comparison stays clean (see the
`network-console-shared-output` project rule); add `PrintSCPConsole` to `DICOMKit` if the
formatter doesn't cover the new lines. Register in `Package.swift` next to `dicom-print`
([Package.swift:655](Package.swift#L655)) — both the product and the target.

### Milestone G — Tests

- **Loopback end-to-end** — the strongest test available and nearly free: point the existing
  `DICOMPrintService` SCU at our new SCP in-process and assert the film that comes out.
  `PrintServiceTests`/`PrintSCPIntegrationTests` already own that harness shape.
- Parser round-trip: SCU serialize → SCP parse → identical `FilmSession`/`FilmBox`/
  `ImageBoxContent`/`PrintImageData`. Both VRs.
- Status-code matrix: unknown box UID, oversized image, unsupported film size, N-ACTION with
  no image boxes set, N-DELETE of an already-deleted box, second film session on one
  association.
- Composer goldens: 1×1, 2×2, 1×2 landscape, inverse LUT, magnification variants — hash the
  bitmap (mirrors the decoded-pixel-hash approach in `dicom-compress` parity).
- Interop smoke test with `dcmtk`'s `dcmprscu` if available; otherwise document the manual step.

---

## 3. Sequencing

**A → B → G-partial (loopback green) → C → D(`ScreenSink` only) → E → F → D(rest) → G-full.**

Two checkpoints worth stopping at:

1. **A + B + loopback** — a conformant Print SCP that accepts jobs from any SCU and dumps them
   as JSON, before a single pixel is rasterized. Proves the protocol half.
2. **C + D(`ScreenSink`) + E** — **the emulator is done and demoable**: point any Print SCU at
   it and watch the film appear on screen. Everything after this (PDF/PNG/paper sinks, CLI
   polish) is additive.

Milestone F (CLI) can slip after E without blocking anything — Studio is the primary surface
for an emulator. If you'd rather demo without building Studio UI, do
`F` before `E` with `--output png --open` as a stand-in screen.

## 4. Risks / decisions to make

1. **Screen ≠ film.** Optical density (min 20 / max 300 in the model) has no direct screen or
   paper analogue. Decided above: default `.paperDirect` (render MONOCHROME2 straight), film
   emulation opt-in. For an *emulator* this matters more than for a printer — users will
   compare our screen output against a real film printer, so make the mode visible in the UI
   rather than a hidden default.
2. **Screen fidelity.** Composing at 300 DPI for a 14×17in film is a ~4200×5100 bitmap per
   film. Compose once at full resolution (so PDF/paper stay sharp), display a downsampled
   copy, and keep only the last N full-res films in memory — otherwise a busy emulator will
   balloon. Make N configurable, default ~10.
3. **`lp` shell-out vs `NSPrintOperation`.** `lp` is cross-platform, testable, and keeps
   `DICOMKit` AppKit-free. `NSPrintOperation` gives the macOS print panel, which is what Studio
   will want later. Plan: `lp` in the library, panel in the app.
4. **Sandbox.** Spawning `lp` from a sandboxed Studio needs an entitlement; the CLI is fine.
   Listening on a port from a sandboxed app needs the network-server entitlement — check
   whether Studio already has it for `LocalListenerView`, which faces the same requirement.
5. **Presentation LUT SOP Class** — real SCUs (esp. Agfa/Fuji) create a Presentation LUT
   instance and reference it from the film box. Milestone A accepts and stores it;
   applying an actual LUT *table* (not just a shape) is deferred — note it as a known gap in
   the conformance statement.
6. **Colour print** — `basicColorImageBoxSOPClassUID` carries RGB/YBR_FULL_422 pixels.
   `PixelDataRenderer` handles both, but confirm packed 4:2:2 (the SCU side gained that in
   commit `e3e6e61`).
7. **Conformance statement** — ship `PRINT_SCP_CONFORMANCE.md` listing SOP classes, transfer
   syntaxes, film sizes, and the deferred items. Modality vendors will ask for it.

## 5. Out of scope (explicitly)

Basic Print Image Overlay Box (`…1.24.1`), Pull print (Print Job SOP Class as *initiator*),
Presentation LUT *data* tables, Image Overlay Box, and stored-print SOP classes.
