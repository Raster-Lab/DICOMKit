# DICOM Print in DICOMStudio — Implementation Plan

> **Status (2026-07-29): Milestones 1–4 are implemented and green; Milestone 5 is held**
> at the user's request pending a UI review. See §7 for what landed in Milestones 1–4 and
> §8 for the work that followed them — the viewer's tile grid and series pane, and the
> viewer's presentation (window, zoom/pan, orientation, invert) baked into film pixels,
> which closes the deferral in "Suggested additions" item 4.
>
> Verified 2026-07-29: `swift build` clean; `DICOMStudioTests` 4,185 tests green.

Goal: bring the finished `dicom-print` capability into the DICOMStudio app as a clinical
workflow: **Library → Viewer → mark images → Print icon → Print settings → PrintSCU job**.

Status of the underlying stack (verified):

- `Sources/DICOMNetwork/PrintService.swift` (4228 lines) — full Basic Grayscale/Color Print
  Management SCU: `DICOMPrintService.getPrinterStatus / createFilmSession / createFilmBox /
  setImageBox / printFilmBox / deleteFilmSession / getPrintJobStatus`, plus `PrintConfiguration`,
  `FilmSession`, `FilmBox`, `ImageBoxContent`, `PrintImageData`, `PrintLayout.optimalLayout(for:)`,
  `PresentationLUTShape`, `PrintAnnotation`, N-EVENT-REPORT `PrintEvent` handling.
- `Sources/dicom-print/main.swift` (1458 lines) — CLI: `status`, `send`, `job`,
  `list-printers`, `add-printer`, `remove-printer`.
- DICOMStudio has **no** print surface today (no `NavigationDestination.print`, no
  `PrintService`/`PrintViewModel` references anywhere in `Sources/DICOMStudio`).

---

## 0. The blocking architectural issue (read this first)

Per the project rule that Studio and the CLIs must share one pipeline (see
`APP_CLI_SHARED_API.md`, `CLI_WORKSHOP_SHARED_API_PLAN.md`, and the parity harness in
`Scripts/cli-parity.sh`), the app must **not** re-implement print orchestration. But two pieces
that the app needs are currently **private to the CLI's `main.swift`**
(the printer registry is deliberately *not* one of them — see §0.1):

1. **Image preparation** — [main.swift:520-605](Sources/dicom-print/main.swift#L520-L605):
   decode → `ImagePreprocessor.prepareForPrint` → `PrintImageData` (frame selection, `--raw`,
   explicit window, `--bit-depth`). Not callable from the app.
2. **Console output** — the `send`/`status`/`job` text and JSON emitters are inline in the CLI,
   so the app cannot render identical output (compare `NetworkConsoleFormatter.swift`, which is
   the pattern to follow).

**Therefore Milestone 1 is an extraction, not app work.** Everything after it is cheap.

### 0.1 Printer registry — decided: store it exactly like PACS server profiles

The app keeps its **own** printer store, mirroring
[ServerProfileStorageService.swift](Sources/DICOMStudio/Services/ServerProfileStorageService.swift)
one-for-one. This matches how PACS server profiles already work (the `dicom-*` CLIs do not read
them either), and it sidesteps the sandbox problem: the CLI's `PrinterConfigManager` writes
`~/.config/dicomkit/printers.json` ([main.swift:1347](Sources/dicom-print/main.swift#L1347)),
which a sandboxed DICOMStudio cannot reach.

- `Sources/DICOMStudio/Models/PrinterProfile.swift` — `struct PrinterProfile: Sendable,
  Identifiable, Equatable, Hashable, Codable { id: UUID, name, host, port: UInt16,
  remoteAETitle, localAETitle, colorMode, timeoutSeconds, isDefault, status }` — same shape and
  conformances as `PACSServerProfile` ([NetworkingModel.swift:121](Sources/DICOMStudio/Models/NetworkingModel.swift#L121)).
- `Sources/DICOMStudio/Services/PrinterProfileStorageService.swift` — copy of
  `ServerProfileStorageService`: `filename = "printer-profiles.json"`,
  `fileURL = storageService.baseDirectory/printer-profiles.json`, same `save(_:)` /`load()`
  (pretty-printed, sorted keys, ISO-8601 dates, atomic write, empty array on any read failure).

Consequence: the CLI's `PrinterConfigManager`/`SavedPrinterConfig` stay in `main.swift`
untouched, and `dicom-print list-printers` and the app's printer list are **independent** by
design. Note this explicitly in the parity docs so it is not later filed as a defect.

---

## Milestone 1 — Shared print core in DICOMKit/DICOMNetwork

**Module placement (decided during implementation).** The shared core cannot live in
DICOMKit: `DICOMNetwork` depends on `DICOMCore`/`DICOMDictionary` only, and `DICOMKit` does not
depend on `DICOMNetwork`, so code needing *both* `ImagePreprocessor` (DICOMKit) and
`PrintImageData` (DICOMNetwork) has no home in either. Putting networking into DICOMKit would
force it on all ~30 CLIs. It is therefore its own target, **`DICOMPrintKit`**, depending on
DICOMCore + DICOMDictionary + DICOMKit + DICOMNetwork, consumed by `dicom-print` and
`DICOMStudio`. The app target still builds from the `DICOMStudio` SPM product, so no
`project.pbxproj` change was needed.

New files:

| File | Contents |
|---|---|
| `Sources/DICOMPrintKit/PrintImagePreparer.swift` | `prepareImages(files:frameSelection:raw:colorMode:window:bitDepth:) async throws -> [PrintImageData]`; lifted verbatim from the CLI's closure. Also a `prepare(dataSet:pixelData:frameIndex:...)` overload so the app can feed already-open `DICOMFile`s from the viewer without re-reading from disk. |
| `Sources/DICOMPrintKit/PrintJobRequest.swift` | One value type carrying every knob the CLI exposes (copies, film size, orientation, layout/template, priority, medium, magnification, destination, trim, border/empty density, polarity, decimate/crop, presentation LUT, annotations, config info, verify/status-check, retries, dry-run). This is the single source of truth for both arg surfaces. |
| `Sources/DICOMPrintKit/PrintWorkflow.swift` | `execute(request:images:config:onEvent:onProgress:)` — the *outer* orchestration only: status pre-check, retries, dry-run, result mapping. The DIMSE sequence itself already exists as `DICOMPrintService.executePrintWorkflow` and is **not** to be reimplemented; this delegates to `printImages` / `printImagesWithProgress`. |
| `Sources/DICOMPrintKit/PrintConsoleFormatter.swift` | Text + JSON emitters for status / send / job / printer-list, mirroring `NetworkConsoleFormatter`. |

Then rewrite `Sources/dicom-print/main.swift` to be a thin ArgumentParser shell over the above.
**Acceptance:** `swift test --filter PrintCLIEndToEndTests` and `PrintSCPIntegrationTests` stay
green with zero behavioural change; `dicom-print` text/JSON output byte-identical to today.

---

## Milestone 2 — Selection in the Viewer

The viewer today is single-image + series-array based: `ImageViewerViewModel` holds `filePath`,
`dicomFile`, `sopInstanceUID`, `seriesFiles: [String]`, `currentFileIndex`, `currentFrameIndex`,
`numberOfFrames`. There is **no multi-select** yet.

Add:

- `Sources/DICOMStudio/Models/PrintSelectionModel.swift`
  - `struct PrintSelectionItem: Identifiable, Hashable { filePath, sopInstanceUID, frameIndex,
    seriesDescription, instanceNumber, thumbnail }` — frame-level, so multi-frame/cine marks a
    specific frame (matches the CLI's `--frame` / `--all-frames`).
  - `@Observable final class PrintSelectionModel` — ordered `[PrintSelectionItem]`, `toggle`,
    `add(currentFrame:)`, `addAllFramesOfCurrent()`, `addWholeSeries()`, `move` (reorder — image
    box position is order-significant), `clear`. **Ordered**, not a `Set`.
- `ImageViewerViewModel` gains `printSelection: PrintSelectionModel` and
  `isCurrentFrameMarked`.
- UI in [ImageViewerView.swift](Sources/DICOMStudio/Views/ImageViewerView.swift):
  - toolbar toggle **Mark for Print** (`checkmark.rectangle.stack`), keyboard `M`;
  - badge on the print toolbar button showing selection count;
  - a mark indicator drawn on the image corner + on the cine/series strip;
  - context-menu items: *Mark this frame*, *Mark all frames*, *Mark whole series*, *Clear marks*.
- `StudyBrowserView`: a **Print…** action on a selected study/series that marks everything and
  jumps straight to the print sheet (skips step 2 for the "print the whole series" case).

---

## Milestone 3 — Print settings UI

- `NavigationDestination.print = "Print"` (icon `printer`) in
  [NavigationService.swift:23](Sources/DICOMStudio/Services/NavigationService.swift#L23) — for
  the standalone/printer-management entry point.
- Primary entry is a **sheet** launched from the viewer's print toolbar icon, so the workflow
  stays in the viewer.

`Sources/DICOMStudio/Views/Print/PrintSettingsView.swift` — two zones as specified:

**Visible (basic):**
- Printer picker (from `PrinterProfileStorageService`, §0.1) + **Manage Printers…** (add/edit/remove/set-default,
  Test Connection = C-ECHO, Query Status = N-GET printer status with live status pill).
- Layout: `1x1 … 4x5` picker, plus the `single / comparison / grid / multi-phase` presets, plus
  **Auto** (`PrintLayout.optimalLayout(for:)`).
- Orientation: portrait / landscape.
- Film size: `8x10 … a3`.
- Copies.
- Live **film preview** (grid of the marked thumbnails laid into the chosen layout/orientation,
  showing spillover: N images ÷ cells = M films).

**Advanced (disclosure group):**
priority, medium type, film destination, magnification, trim, border/empty density, polarity,
decimate/crop, colour mode, grayscale bit depth (8/12/16), presentation LUT shape, explicit
window centre/width (default: inherit the viewer's current W/L — the natural app behaviour and
what makes app output match what the user sees), raw (no preprocessing), annotations
(text + annotation-format ID), configuration information, timeout, retries, dry-run.

Every control binds to one field of the shared `PrintJobRequest`.

**Settings persistence:** last-used `PrintJobRequest` + default printer via the existing
`SettingsService`, so repeat printing is one click.

---

## Milestone 4 — Execution

- `Sources/DICOMStudio/Services/PrintService.swift` — thin actor wrapping
  `PrintImagePreparer` + `PrintWorkflow`; no DIMSE logic of its own.
- `Sources/DICOMStudio/ViewModels/PrintViewModel.swift` — `@Observable @MainActor`; owns the
  request, printer list, preview, `isPrinting`, progress (per image box), console lines, result.
- `Sources/DICOMStudio/Views/Print/PrintProgressView.swift` — determinate progress
  ("Image box 3 of 12"), live N-EVENT-REPORT feed (`PrintEvent.summary`, faults highlighted),
  **Cancel** (task cancellation + `deleteFilmSession` cleanup), and on completion the print job
  UID with a **Check Job Status** button (`getPrintJobStatus`, pollable).
- Console pane rendered through `PrintConsoleFormatter` so it matches `dicom-print` verbatim.

---

## Milestone 5 — Parity & tests — **HELD**

Held at the user's request pending a UI review of Milestones 2–4. Note the standing rule this
milestone discharges: CLI changes normally land *with* their parity touchpoints, so this debt
is deliberate and tracked, not forgotten.

**Still outstanding (the parity half): items 1–3 below** — CLI Workshop registration,
`CLIContracts.json` / `goldens.json` regeneration, and the offline picker scenarios. Nothing
of the parity harness has been touched.

**Already landed (part of item 4), with the feature work rather than after it:**
`PrintSelectionModelTests`, `PrintPresentationTransformTests`, `ViewerPresentationTests`,
`PrintViewerPresentationEndToEndTests`, `PrintThumbnailCacheTests`, `ViewerTileLayoutTests`,
`ViewerSeriesPaneTests` (§8.4). `PrintImagePreparerTests`, `PrinterProfileStorageServiceTests`,
`PrintFilmSpilloverTests` and `StudioPrintParityTests` are not written.

Per the standing rule that CLI changes must land with their parity touchpoints:

1. Register `dicom-print` in the CLI Workshop (`CLIWorkshopModel` + `ParameterBuilderModel`) so
   both arg surfaces exist.
2. Regenerate `CLIContracts.json` and `goldens.json` (`Scripts/cli-parity.sh`, `cli-parity-gen`)
   — the Milestone 1 refactor touches help text.
3. Add print scenarios to the offline picker; the DIMSE-dependent ones run against
   `MockPrintSCP` / the `docker-compose-print-test.yml` Orthanc, matching how
   `PrintSCPIntegrationTests` already work.
4. New tests: `PrintImagePreparerTests` (frame selection, bit depth, raw, window),
   `PrinterProfileStorageServiceTests` (mirroring the PACS profile storage tests),
   `PrintFilmSpilloverTests` (image count × layout → film count / per-film job UIDs, against
   `MockPrintSCP`), `PrintSelectionModelTests`
   (ordering, frame-level marks), `StudioPrintParityTests` (app request → same PrintWorkflow
   calls as the equivalent CLI invocation).

---

## Suggested additions beyond the stated workflow

Things the four steps don't cover but this workflow needs in practice:

1. **Frame-level marking** (folded into Milestone 2) — without it, cine/multi-frame studies
   can't be printed selectively, and the CLI already supports `--frame`/`--all-frames`.
2. **Ordering and reordering of marks** — image box position is order-significant on film; a
   `Set` would randomise the film. Ship a drag-to-reorder tray. *(Superseded in §9.3: the
   ordered model stayed, but film order is taken from the viewer's tile order — the arrangement
   the film is meant to reproduce — instead of being dragged in a separate tray.)*
3. **Multi-film spillover** — already implemented in DICOMNetwork; the app only has to *show*
   it. See §6 below for the confirmed behaviour and the one gap it leaves.
4. **Burn in the viewer's current presentation.** Users expect the film to look like the screen:
   window/level, invert, zoom/pan, rotate/flip, and ideally annotations/measurement overlays.
   `prepareForPrint` today applies rescale/VOI/inversion only. **Scope for now:** pass the
   viewer's W/L and inversion. Baked-in overlays/annotations/geometry are **deferred to future
   work** by decision — they need a render-to-`PrintImageData` path, not just preprocessing.
   *(Update 2026-07-28 — geometry is no longer deferred: window/level, the zoom/pan crop,
   90° rotation, flips and inversion are all baked into film pixels by
   `PrintPresentationTransform`; see §8.1. Only measurement/annotation **overlays** remain
   future work.)*
5. **Printer management is a first-class screen**, not a picker afterthought — add, edit,
   remove, set default, C-ECHO test, live status. Shared registry keeps it in sync with the CLI.
6. **Pre-flight status check** before every job (`--check-status` equivalent), on by default:
   abort on FAILURE, warn on WARNING. Cheap, prevents wasted film.
7. **Dry run** exposed in the UI — shows the film plan without an association. Best QA affordance
   you have.
8. **Job history** — persist recent jobs (printer, film count, UID, result, timestamp) so
   "did that print?" is answerable. Backed by `getPrintJobStatus`.
9. **Colour mode auto-detection** — pick grayscale vs colour from the marked images'
   photometric interpretation rather than making the user choose; keep the manual override.
10. **Failure cleanup guarantee** — on any mid-job error or cancel, always `deleteFilmSession`;
    a leaked session ties up the printer.
11. **Print a whole study/series from the Library** without opening the viewer (Milestone 2).
12. **Accessibility/keyboard**: `M` to mark, `⌘P` to open print settings, `⌘⇧P` to reprint last.

---

## Sequencing

| # | Milestone | Depends on | Notes |
|---|---|---|---|
| 1 | Shared print core + CLI refactor | — | **Blocking**; pure refactor, tests must stay green |
| 2 | Viewer selection model + marking UI | — | Can run in parallel with 1 |
| 3 | Print settings + printer management UI | 1, 2 | |
| 4 | Execution, progress, events, job status | 1, 3 | |
| 5 | Parity registration + tests + goldens | 1–4 | Lands with the change, not after |

---

## 6. Multi-film spillover — CONFIRMED, already implemented

**Answer: no new code is needed in the print core. Spillover works today.**

`DICOMPrintService.executePrintWorkflow`
([PrintService.swift:3559](Sources/DICOMNetwork/PrintService.swift#L3559)) chunks the images
across as many film boxes as the layout requires, all inside **one association and one film
session** (PS3.4 H.4):

```swift
let imagesPerFilm = layout.rows * layout.columns
let filmBoxCount = max(1, (images.count + imagesPerFilm - 1) / imagesPerFilm)   // ceil
for filmIndex in 0..<filmBoxCount {
    // N-CREATE Film Box (Referenced Film Session Sequence → the one session UID)
    let startIndex = filmIndex * imagesPerFilm
    let endIndex   = min(startIndex + imagesPerFilm, images.count)
    for (imageIndex, globalIndex) in (startIndex..<endIndex).enumerated() { /* N-SET Image Box */ }
    // N-ACTION Print Film Box  → one print job per film
}
```

So 12 marked images at `2x2` ⇒ 3 film boxes, 3 N-ACTIONs, 3 print jobs, one film session.
Images are assigned to cells in array order; the last film is partially filled (remaining image
boxes are simply not set, which is conformant — the printer applies Empty Image Density).
`printImages` ([:4044](Sources/DICOMNetwork/PrintService.swift#L4044)),
`printWithTemplate` ([:4097](Sources/DICOMNetwork/PrintService.swift#L4097)) and
`printImagesWithProgress` ([:4178](Sources/DICOMNetwork/PrintService.swift#L4178)) all route
through it, so every entry point gets the same behaviour.

Two consequences the app must handle:

1. **Auto-layout never spills for ≤ 25 images.** `PrintLayout.optimalLayout(for:)`
   ([:844](Sources/DICOMNetwork/PrintService.swift#L844)) grows the grid with the image count
   and caps at `5x5`; beyond 25 images it spills at 25/film. Spillover is therefore mostly a
   *manually-chosen-layout* phenomenon — exactly the case the preview must make obvious.
2. **Gap: `PrintResult` reports only the last film.** It returns
   `filmBoxUID: lastFilmBoxUID` and `printJobUID: allPrintJobUIDs.last` — the earlier film
   boxes' print job UIDs are collected in `allPrintJobUIDs` and then **discarded**. That breaks
   per-film job-status polling and job history (suggestions 8 and 10) for any multi-film job.
   **Fix in Milestone 1:** add `filmBoxUIDs: [String]` and `printJobUIDs: [String]` to
   `PrintResult` (keep the existing singular fields as the last-element accessors for source
   compatibility), and surface each film's job UID in `PrintProgress`.

**Milestone 3 preview requirements (now designable):**
- Compute `filmCount = ceil(markedImages.count / (rows * columns))` and render one page thumbnail
  per film, in order, with the last one partially filled.
- Label it plainly: *"12 images → 3 films (2×2, 14×17, portrait)"*.
- Recompute live as layout / orientation / marks change.
- Warn when a manual layout produces an unexpectedly large film count.
- Multiply by copies for the film-consumption estimate: `films × copies`.

---

## Open questions

- *(Resolved — see §6)* Multi-film spillover is already implemented in `executePrintWorkflow`.
- *(Resolved — see §0.1)* Printer registry stores like PACS server profiles, app-local.
- *(Resolved — see §8.1)* Baking the viewer's **presentation** (window, zoom/pan region,
  rotation, flips, inversion) into film pixels. Done exactly, by cropping and permuting the
  full-resolution frame — no resampling, no screenshot.
- *(Deferred by decision)* Baked-in annotation / measurement **overlays** on film pixels —
  **future work**. Milestones 1–5 use the printer's `BasicAnnotationBox` only (text +
  printer-configured annotation-format ID), matching the CLI's `--annotate` /
  `--annotation-format`.

---

## 7. What landed (2026-07-28)

Milestones 1–4 are implemented; `swift build` is clean and the print + Studio test suites pass.
Milestone 5 is held.

### Milestone 1 — shared print core

- **New target `DICOMPrintKit`** (`Package.swift`: library product + target, added to
  `dicom-print` and `DICOMStudio`).
  - [PrintJobRequest.swift](Sources/DICOMPrintKit/PrintJobRequest.swift) — the whole job as one
    value type, plus `validate()` (CLI wording preserved verbatim), `printOptions`,
    `effectiveFilmSize/Orientation`, `filmCount(forImageCount:)` and `PrintPlan` (per-film image
    ranges, `totalSheets`).
  - [PrintOptionCatalog.swift](Sources/DICOMPrintKit/PrintOptionCatalog.swift) — one table of
    selectable values per option (`PrintLayoutOption`, `PrintTemplatePreset`, film sizes,
    orientations, priorities, media, destinations, magnification, polarity, trim, LUT shapes,
    colour modes, bit depths). UI pickers and the CLI's arg enums both derive from it.
  - [PrintImagePreparer.swift](Sources/DICOMPrintKit/PrintImagePreparer.swift) — the CLI's
    decode → `ImagePreprocessor.prepareForPrint` → `PrintImageData` path, lifted intact, with a
    `prepare(pixelData:dataSet:…)` overload for already-open data sets.
  - [PrintWorkflow.swift](Sources/DICOMPrintKit/PrintWorkflow.swift) — `preflight` (C-ECHO,
    printer status), `execute` (retries, events, progress), `jobStatus`, `printerStatus`. The
    DIMSE sequence is untouched in `DICOMPrintService`.
  - [PrintConsoleFormatter.swift](Sources/DICOMPrintKit/PrintConsoleFormatter.swift) — printer
    status / print result / job status / film plan, text and JSON.
- **`dicom-print` refactored** onto all of the above ([main.swift](Sources/dicom-print/main.swift)):
  arg declarations and help text untouched, dead local emitters removed, `LayoutOption` /
  `TemplateOption` now map to the shared enums. `PrintCLIEndToEndTests` (incl. the JSON contract
  and exit codes), `PrintServiceTests`, `PrintSCPIntegrationTests` — 220 tests, all green.
- **Multi-film gap fixed** ([PrintService.swift](Sources/DICOMNetwork/PrintService.swift)):
  `PrintResult` now carries `filmBoxUIDs` and `printJobUIDs` (singular properties kept as
  last-element accessors), `printImages` gained an optional `progressHandler` that reports
  progress *and* returns the result, and the print-command progress message names the film.

### Milestone 2 — marking in the viewer

- [PrintSelectionModel.swift](Sources/DICOMStudio/Models/PrintSelectionModel.swift) — ordered,
  frame-level marks (`PrintSelectionItem` carries file, frame, series/instance labels and the
  viewer's window/level); toggle, add-all-frames, reorder, delete, clear.
- [ImageViewerViewModel+Print.swift](Sources/DICOMStudio/ViewModels/ImageViewerViewModel+Print.swift)
  — mark current frame / all frames / whole series, plus mark state and film position.
- [ImageViewerView.swift](Sources/DICOMStudio/Views/ImageViewerView.swift) — **M** toggles the
  mark, **⌘P** opens the sheet, a badge shows the mark count, a capsule on the image shows the
  film position, and the context menu carries the same actions.
- Library path: `printStudy` / `printSeries` on
  [StudyBrowserViewModel](Sources/DICOMStudio/ViewModels/StudyBrowserViewModel.swift) with a
  **Print…** context-menu item, wired in `MainViewModel` to mark the files, open them, and raise
  the sheet.

### Milestone 3 — printers and print settings

- [PrinterProfile.swift](Sources/DICOMStudio/Models/PrinterProfile.swift) +
  [PrinterProfileStorageService.swift](Sources/DICOMStudio/Services/PrinterProfileStorageService.swift)
  — modelled on `PACSServerProfile` / `ServerProfileStorageService`, stored as
  `printer-profiles.json` (§0.1).
- [PrintSettingsView.swift](Sources/DICOMStudio/Views/Print/PrintSettingsView.swift) — printer
  picker with Test / Status, layout (auto | grid | preset), film size, orientation, copies, the
  film preview, the marks tray, and an Advanced disclosure covering the rest of the
  CLI surface. (Relaid out in §9.3; marks now follow viewer order rather than being dragged.)
- [FilmPreviewView.swift](Sources/DICOMStudio/Views/Print/FilmPreviewView.swift) — one sheet per
  film with filled/empty cells, so spillover is visible before printing.
- [PrinterManagementView.swift](Sources/DICOMStudio/Views/Print/PrinterManagementView.swift) —
  add / edit / remove / make-default / test / query.
- [PrintCenterView.swift](Sources/DICOMStudio/Views/Print/PrintCenterView.swift) — the
  standalone **Print** destination (`NavigationDestination.printing`): printers and job history.

### Milestone 4 — execution

- [PrintService.swift](Sources/DICOMStudio/Services/PrintService.swift) — adapter over
  DICOMPrintKit; prepares each mark under its own frame index and captured window.
- [PrintViewModel.swift](Sources/DICOMStudio/ViewModels/PrintViewModel.swift) — settings state,
  printer management, validation, plan, run/cancel, levelled console lines, progress, result,
  job-status polling, and job history.
- [PrintProgressView.swift](Sources/DICOMStudio/Views/Print/PrintProgressView.swift) — progress
  bar, live console (printer N-EVENT-REPORTs included), per-film **Check Status** buttons.
- [PrintJobHistoryEntry.swift](Sources/DICOMStudio/Models/PrintJobHistoryEntry.swift) — job
  history persisted to `print-job-history.json` (100 most recent).

### Behaviour notes worth reviewing in the UI

- **Colour mode auto-detects** from the selected printer's profile by default; the manual
  override is in Advanced.
- **The film matches the screen**: a mark captures the viewer's window/level and that window is
  used at print time unless an explicit window is set or Raw is on.
- **Status pre-check is on by default** (abort on FAILURE, warn on WARNING).
- **Two tests updated** for the new navigation destination: the destination-catalog test and the
  case-count test (23 → 24).

---

## 8. What landed after Milestone 4 (2026-07-28 → 29)

Milestone 4 left two things unsatisfying in use: the film only matched the screen's *window*,
not the arrangement the reader had actually made, and the film preview showed numbered grey
boxes. Both are now fixed, and fixing the second properly turned the viewer into a
film-shaped surface: a tile grid whose cells are the film's cells, fed by a series pane.

### 8.1 The viewer's presentation, baked into film pixels

This closes the deferral in "Suggested additions" item 4 for *geometry*; overlays stay
future work.

| File | Contents |
|---|---|
| [ViewerPresentation.swift](Sources/DICOMPrintKit/ViewerPresentation.swift) | The on-screen arrangement of one frame as **geometry over the source image**, not a screenshot: zoom, pan, viewport size, quarter turns, flips, invert — plus `visibleRegion(imageWidth:imageHeight:)`, which resolves zoom/pan/viewport into an integer `PixelRegion`. Rotation is quarter turns only, because an arbitrary angle would force a resampling rotation and blur film pixels for no clinical gain. |
| [PrintPresentationTransform.swift](Sources/DICOMPrintKit/PrintPresentationTransform.swift) | Applies a presentation to already-prepared `PrintImageData`: crop → rotate → flip → invert P-values. Every step is exact — pixels are selected, permuted or negated, never resampled — so a zoomed print carries the modality's real detail rather than an upscaled copy of what the monitor showed. Planar or sub-byte layouts (which the preparer never emits) fall through untransformed rather than being mangled. |
| [PrintSelectionModel.swift](Sources/DICOMStudio/Models/PrintSelectionModel.swift) | `PrintSelectionItem` now carries the `ViewerPresentation` alongside the captured window, so a mark records *how* the frame looked, not just *which* frame it was. |
| [PrintService.swift](Sources/DICOMStudio/Services/PrintService.swift) | Applies each mark's presentation to its prepared image before it becomes an image box; an identity presentation short-circuits. |
| [ImageInversion.swift](Sources/DICOMStudio/Components/ImageInversion.swift) | Screen-side inversion of a rendered frame (difference blend against white). The renderer has no invert option and negating the VOI window is *not* equivalent once Rescale Slope/Intercept or a signed representation are involved — so the screen inverts the rendered image and the print path inverts P-values directly. Same result, both exact. |

### 8.2 The film preview shows the actual frames

| File | Contents |
|---|---|
| [FrameRenderer.swift](Sources/DICOMStudio/Services/FrameRenderer.swift) | "This frame, windowed and arranged as the user left it, at a size that suits the box it goes in." Arranges at full resolution and scales last. Its cache key includes the whole arrangement — keying on file+frame alone is exactly how a preview ends up disagreeing with the viewer. |
| [FrameImageStore.swift](Sources/DICOMStudio/Services/FrameImageStore.swift) | The caching half: holds rendered images, tracks what is in flight, drops what left the screen. One implementation shared by film cells, viewer tiles and series thumbnails, which is what keeps them agreeing. |
| [PrintThumbnailCache.swift](Sources/DICOMStudio/Services/PrintThumbnailCache.swift) | One thumbnail per mark (≤256 px), rendered through `FrameRenderer`, so every preview cell shows the frame as it will print. |
| [FilmPreviewView.swift](Sources/DICOMStudio/Views/Print/FilmPreviewView.swift) | Draws those thumbnails into the film's cells, spillover and partially-filled last sheet included. |

### 8.3 Viewer tile grid and series pane

The grid is the same shape as a film — what you arrange in the viewer's cells is what lands
in the film's cells, in the same order.

| File | Contents |
|---|---|
| [ViewerTileLayout.swift](Sources/DICOMStudio/Models/ViewerTileLayout.swift) | `ViewerTileLayout` (1×1 … 4×4) and `ViewerCellState` — per-tile file, series, frame, window, zoom/pan, rotation, flips, invert and viewport, with a `presentation` accessor feeding §8.1. |
| [ImageViewerViewModel+Layout.swift](Sources/DICOMStudio/ViewModels/ImageViewerViewModel+Layout.swift) | One tile is *focused* and the focused tile **is** the live view model, so gestures, W/L, cine and rendering work at any layout without N copies of the rendering machinery. Changing focus writes the outgoing tile's arrangement back and loads the incoming one's. Growing the grid fills from the series and preserves existing tiles' arrangements. |
| [ViewerTileGridView.swift](Sources/DICOMStudio/Views/ViewerTileGridView.swift) | The grid: live focused tile, rendered stills elsewhere, a per-tile print checkbox, and drop highlighting for series drags. |
| [ViewerTileImageCache.swift](Sources/DICOMStudio/Services/ViewerTileImageCache.swift) | Unfocused tiles' images (≤1024 px), keyed on full tile state so panning tile 2 does not re-decode tiles 1, 3 and 4. |
| [ViewerSeriesEntry.swift](Sources/DICOMStudio/Models/ViewerSeriesEntry.swift), [ViewerSeriesCatalog.swift](Sources/DICOMStudio/Services/ViewerSeriesCatalog.swift) | The study's series flattened from the library so the viewer never reaches back into it while rendering. Built from indexed metadata (instant), with orientation — the one thing the library does not index — read from one file per series afterwards and folded in. |
| [ImageViewerViewModel+Series.swift](Sources/DICOMStudio/ViewModels/ImageViewerViewModel+Series.swift) | Hanging a series in a tile, current-series tracking, and visited-series tracking (the reading-completeness cue). |
| [ViewerSeriesPaneView.swift](Sources/DICOMStudio/Views/ViewerSeriesPaneView.swift) | One card per series — thumbnail, what it is, how much of it there is (objects *and* frames: a 1-object 358-frame cine and a 358-object stack read very differently), and whether it has been looked at. Drag a card onto a tile, or select a tile and double-click. |
| [ImageViewerViewModel+ImageNavigation.swift](Sources/DICOMStudio/ViewModels/ImageViewerViewModel+ImageNavigation.swift) | Arrow-key traversal by *image* rather than by file: frames first, rolling onto the neighbouring file, stopping at the series end. Wrapping stays cine behaviour. |

Viewer surface (in [ImageViewerView.swift](Sources/DICOMStudio/Views/ImageViewerView.swift)):
series-pane toggle, layout menu, per-tile mark checkbox, **M** to mark, **⌘P** for the print
sheet, a mark badge with the selection count, a film-position capsule, and context-menu items
including **Mark All Tiles for Print**.

Library entry point ([MainViewModel.swift](Sources/DICOMStudio/ViewModels/MainViewModel.swift)):
"Print…" *adds* to the selection rather than replacing it — frames ticked in the viewer are
deliberate choices and keep their captured window and film position — then opens the series and
raises the sheet. Opening a study now loads the whole first series (the viewer needs a
navigation list, the pane needs the study) and populates the pane.

### 8.4 Tests

New, all green (`swift build` clean; `DICOMStudioTests` 4,185 tests pass, 2026-07-29):

| Suite | Covers |
|---|---|
| `ViewerPresentationTests` | Zoom/pan/viewport → visible region, identity detection, clamping |
| `PrintPresentationTransformTests` | Crop / rotate / flip / invert on 8- and 16-bit, 1- and 3-sample pixels; untransformable layouts pass through |
| `PrintViewerPresentationEndToEndTests` | Mark in the viewer → prepared image box carries that arrangement |
| `PrintThumbnailCacheTests` | Preview matches the viewer; a re-arranged mark re-renders instead of being served from the old cache |
| `PrintSelectionModelTests` | Ordering, frame-level marks, presentation capture |
| `ViewerTileLayoutTests` | Layout changes, per-tile state, focus hand-off, fill-from-series |
| `ViewerSeriesPaneTests` | Catalog building, hanging a series in a tile, current/visited tracking |

---

## 9. Reading-surface corrections (2026-07-29)

Using §8 against real studies turned up three things that only show once a grid holds images
from more than one series, plus a print sheet whose settings column was taking room the film
needed.

### 9.1 One window policy, and a window that stays where it belongs

The viewer, the tile cache, the film preview and export must not disagree about how an image
is presented, and a window belonging to one image must not be applied to another.

| File | Change |
|---|---|
| [DICOMImageExporter.swift](Sources/DICOMKit/ImageExport/DICOMImageExporter.swift) | `determineWindowSettings` reads `allWindowSettings().first` before `windowSettings()`. A CT routinely carries a lung and a soft-tissue window in one multi-valued element (`-600\50` / `1200\350`); `windowSettings()` parses a *single* DS and returns nil for those files, so a perfectly good VOI was dropped and the frame auto-stretched over the full pixel range. |
| [ImageViewerViewModel.swift](Sources/DICOMStudio/ViewModels/ImageViewerViewModel.swift) | `applyDefaultWindow(for:slope:intercept:)` — the load path now resolves the default window through `determineWindowSettings` instead of its own copy of the rescale maths, so the viewport and a tile showing the same image cannot differ. `resetWindowToFileDefault()` re-adopts it. |
| [FrameRenderer.swift](Sources/DICOMStudio/Services/FrameRenderer.swift) | The no-window rung of the ladder now goes through `determineWindowSettings` as well. `tryRenderFrameWithStoredWindow` is gone from the ladder: it hands the raw Window Center to a renderer that reads *stored* pixels, so on a CT with a large Rescale Intercept (−1024, −8192) a −615 HU centre sits below every stored value and the frame washes out to white. |
| [ViewerTileLayout.swift](Sources/DICOMStudio/Models/ViewerTileLayout.swift) | `ViewerCellState.windowCenter/windowWidth` are `Double?`. `nil` means "whatever this image's own VOI says" — the old defaults (128/256) were a stock window belonging to no image in particular. |
| [ImageViewerViewModel+Layout.swift](Sources/DICOMStudio/ViewModels/ImageViewerViewModel+Layout.swift) | A new tile inherits the viewer's window only when it is in the anchor tile's series (`windowTravels(to:)`). The viewer's window is held in stored-value space — divided through *this* image's rescale pair — and may be an adjustment made for this reconstruction; a grid filled from a flat file list can span a lung kernel, a soft-tissue kernel and an MPR. Focusing a tile with no window of its own calls `resetWindowToFileDefault()` rather than leaving the previous tile's window in place. |

### 9.2 Series pane order

| File | Change |
|---|---|
| [ViewerSeriesCatalog.swift](Sources/DICOMStudio/Services/ViewerSeriesCatalog.swift) | `isOrderedBefore` — ascending Series Number, unnumbered series *last*. The library's ordering treats a missing number as 0, which files unnumbered series ahead of series 1. Ties and missing numbers fall back to title then UID, so the pane cannot reshuffle between two reads of the same study. Orientation refinement preserves the order. |
| [ViewerSeriesEntry.swift](Sources/DICOMStudio/Models/ViewerSeriesEntry.swift), [ViewerSeriesPaneView.swift](Sources/DICOMStudio/Views/ViewerSeriesPaneView.swift) | `seriesNumberLabel` (nil when the series has no number — an invented one would imply an ordering the study does not assert) drawn as a badge on the thumbnail, and `spokenLabel` so VoiceOver announces "Series 4, …": the number is how a reader refers to a series aloud and in a report. |

### 9.3 The print sheet is the film

| File | Change |
|---|---|
| [PrintSettingsView.swift](Sources/DICOMStudio/Views/Print/PrintSettingsView.swift) | Options moved out of the 320 pt left column into a horizontal band across the top, so the preview — the thing actually being judged — owns the whole centre. The sheet opens at the size of the window it was raised from (`parentSize`, captured while the viewer is still key). Advanced expands into four side-by-side columns under a 300 pt cap rather than pushing the film off the bottom. The marks tray became a "Show List…" popover. |
| [ImageViewerViewModel+Layout.swift](Sources/DICOMStudio/ViewModels/ImageViewerViewModel+Layout.swift) | `syncPrintOrderToViewer()` — film order follows tile order, not the order the boxes were ticked, so the preview reads like the screen. Marks with no tile on screen keep their relative order behind those that have one. The list is therefore reported, not dragged: reordering happens by arranging the tiles the film reproduces. |

### 9.4 Tests

| Suite | Added |
|---|---|
| `ExportWindowParityTests` | The first of several VOI pairs is the one used |
| `ViewerSeriesPaneTests` | Numeric (not textual) series ordering, unnumbered-last, stable ties, order preserved across orientation refinement, the number badge, and four window-inheritance cases: a newly hung tile keeps its image's VOI, a windowless tile imposes no stock window on focus, the window does not travel across series, and does travel within one |
