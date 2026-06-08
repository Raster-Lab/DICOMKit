# Plan: DICOMStudio CLI Workshop Calls the DICOMKit Package API

> **Decision (settled):** DICOMStudio's CLI Workshop runs each tool by **calling
> the DICOMKit package libraries in-process** — the same library code the
> `dicom-*` CLI tools call. We are **not** launching the CLI binaries, and we are
> **not** building a new "common" layer above the package. The existing package
> libraries (`DICOMCore`, `DICOMKit`, `DICOMDictionary`, `DICOMNetwork`,
> `DICOMWeb`) are the shared API. Where a tool's real engine isn't in a library
> yet, we **move it into one** so both the CLI and the app can call it.
>
> **Status (2026-06-08):** All 32 execute-supported tools have been classified
> against the actual source and each "copy" verdict independently re-checked.
> Result: **15 already share the library, 6 partly share it, 11 are full copies.**
> The 11 full copies are the bulk of the work — their engine lives only inside
> `Sources/dicom-<tool>/` and must be extracted into a package library first.
>
> **Wave 1 ✅ COMPLETE:** `dicom-validate`, `dicom-diff`, `dicom-anon`, `dicom-tags`.
>
> **Wave 2 ✅ COMPLETE:** `dicom-split`, `dicom-merge`, `dicom-study`, `dicom-archive`
> — each engine extracted into DICOMKit, CLI + DICOMStudio share it (see Progress
> Log).
>
> **Tier-2 parity: MATCH=266, DIFFERS=0** 🎉 — the last two DIFFERS (`dicom-compress`
> backends hint, `dicom-uid` lookup footer) are resolved, the `parity-allowlist.json`
> is now **empty**, and the `PARITY_STRICT=1` gate is green. Next up: **Wave 3**
> (`dicom-image`, `dicom-pixedit`, `dicom-script`).

## Progress Log

| Date | Tool | What changed | Verified |
|------|------|--------------|----------|
| 2026-06-08 | **Wave 3** `dicom-pixedit` | Moved `PixelEditor` (+ `PixelOperation`, `PixelEditError`, new `PixelEditInfo`) out of `Sources/dicom-pixedit/` into `Sources/DICOMKit/PixelEditing/`. Added a `processData(_:operations:) -> (Data, PixelEditInfo)` core (so DICOMStudio writes via its sandbox-aware `OutputAccess`) alongside the direct-write `processFile`; verbose output via injected `log` closure. App `executeDicomPixedit` deleted its ~190-line inline pixel reimplementation (mask/crop/window-level/invert + sample accessors) and calls the shared engine. Kept the descriptor internal+renamed (`PixelEditDescriptor`) to avoid colliding with `DICOMCore.PixelDataDescriptor`. | `swift build` green; `dicom-pixedit` release build + smoke (invert); regenerated goldens **unchanged**; **all 3 pixedit parity scenarios stay MATCH** — MATCH=266, DIFFERS=0, strict gate green. |
| 2026-06-08 | **Parity → 0 DIFFERS** (`dicom-compress`, `dicom-uid`) | Retired the last 2 allowlisted DIFFERS. `dicom-uid`: the `N UIDs found` lookup footer moved stderr→stdout (it's a result summary, belongs with the listing — matches DICOMStudio). `dicom-compress`: aligned the app's `backends` hint wording to the CLI (`Use --backend <name>…`). Emptied `parity-allowlist.json` — all prior entries (F4/F5/F9/F10/F14) now retired since their tools call the shared engines and MATCH. | Regenerated goldens; **Tier-2 `StudioParityTests`: MATCH=266, DIFFERS=0**; `PARITY_STRICT=1` gate green with an empty allowlist. |
| 2026-06-08 | **Wave 2** `dicom-archive` | Extracted the entire archive engine — index model (`ArchiveIndex`/`ArchivePatient`/`ArchiveStudy`/`ArchiveSeries`/`ArchiveInstance`), helpers (wildcard/sanitize/load/save/count), and all 7 operations (init/import/query/list/export/check/stats) — out of `Sources/dicom-archive/main.swift` into `Sources/DICOMKit/Archive/ArchiveStore.swift`. Operations **return rendered strings** (no `print`); `ArgumentParser.ValidationError` → library `ArchiveError`. CLI `main.swift` shrank **1236→~270 lines** (thin subcommand dispatch). App `executeDicomArchive` deleted its **~628-line** inline reimplementation (`A*` model + helpers + 7 subcommands) and dispatches to `ArchiveStore`, keeping only param parsing + sandbox path resolution. | `swift build` green; `dicom-archive` release build + full smoke (init→import→list/query/check/stats); **Tier-2 parity: all 8 archive scenarios still MATCH** (byte-exact preserved); overall MATCH=264, DIFFERS=2. |
| 2026-06-08 | **Wave 2** `dicom-study` | Extracted the study analysis engine into `Sources/DICOMKit/Study/` — public models (`StudyMetadata`/`SeriesMetadata`/`InstanceMetadata`/`Statistics`/`StudyComparison`/`SeriesDifference`/`StudyError`), `StudyScanner` (scan; series sorted by UID), and `StudyReport` (summary/stats/compare/completeness renderers, returning strings — no `print`). The CLI's summary/check/stats/compare engines became thin adapters; `StudyOrganizer` (file moves) stays CLI-local. The app deleted its parallel `StudyStudio*` model + `studyScan` + `studyFormatBytes` and the inline renderers in its 4 study methods, calling the shared engine. **Reconciled in the engine:** series sorted within a study (deterministic), renderers use `✓`/`✗` (app had `[OK]`/`[FAIL]`/`[DIFF]`), and `check` output moved stderr→stdout (it's the command's primary result, consistent with summary/stats/compare and the app). | `swift build` green; `dicom-study` release build + smoke (summary/check/stats/compare); **Tier-2 parity: all 6 `dicom-study` scenarios now MATCH** (overall DIFFERS 8→2). |
| 2026-06-08 | **Wave 2** `dicom-split` | Moved `FrameSplitter` (+ `SplitError`, `SplitOutputFormat`, new `SplitResult`) out of `Sources/dicom-split/` into `Sources/DICOMKit/Splitting/`. The engine now returns a `SplitResult` (extracted/failed/written paths) and logs via an injected closure; image export (CoreGraphics/ImageIO) moved with it. App `executeDicomSplit` deleted its ~150-line inline reimplementation (DICOM-frame + PNG/JPEG/TIFF export) and calls the shared engine, mapping `SplitResult` into its written-paths summary. Renamed `OutputFormat`→`SplitOutputFormat`. | `swift build` green; `dicom-split` release build + smoke (4-frame multiframe → 4 DICOM frames; PNG export). No parity golden (split is non-deterministic — UID regen + image encoding — so excluded from goldens); no regression (MATCH=258). |
| 2026-06-08 | **Wave 2** `dicom-merge` | Moved `FrameMerger` (+ `MergeError`, `MergeFormat`, `MergeLevel`, `MergeSortCriteria`, `MergeSortOrder`) out of `Sources/dicom-merge/` into `Sources/DICOMKit/Merging/`. Verbose output now flows through an injected `log` closure (CLI→stderr, app→console) so wording comes from one place. App `executeDicomMerge` deleted its ~200-line inline engine (sort/validate/createMultiFrame/load + `MergeRuntimeError`) and calls the shared `FrameMerger`. **Reconciled in the engine:** group iteration sorted by UID, and input file paths sorted, so multi-output and template selection are deterministic (fixed the merge parity DIFFERS, which was a Series-Number tie-break). Renamed `SortOrder`→`MergeSortOrder` (collided with `Foundation.SortOrder`). | `swift build` green; `dicom-merge` release build + smoke (series merge); **Tier-2 parity: `dicom-merge` now MATCHES** (was DIFFERS). |
| 2026-06-08 | **Wave 1 parity check** | Regenerated goldens (`swift run cli-parity-gen`): committed `goldens.synthetic.json` (97 scenarios) came back **byte-identical** — CLI output unchanged by the refactor. Ran Tier-2 `StudioParityTests` (app reimplementations vs CLI goldens): **all 54 scenarios for the 4 migrated tools MATCH** (validate 15, diff 11, anon 20, tags 8). | app == CLI confirmed for every Wave 1 tool; the only 9 DIFFERS are pre-existing drift in **unmigrated** tools (study ×6, compress/merge/uid ×1) — i.e. Wave 2+ work, not a regression. |
| 2026-06-08 | `dicom-validate` | Moved `DICOMValidator` (engine + IOD validators + `ValidationIssue`/`ValidationResult` + Level-5 J2K checks) and `ValidationReport` (+ `ValidationOutputFormat`) out of `Sources/dicom-validate/` into `Sources/DICOMKit/Validation/`. Added `J2KCore` to the DICOMKit target. CLI shrunk to argv→engine→print (keeps `ExpressibleByArgument` conformance locally). App `ValidationViewModel` deleted its entire inline engine (which had **drifted**: different IOD map, a fake Level-5 stub, an extra `.info` severity) and now calls `DICOMKit.DICOMValidator`, mapping results to its display model. | `swift build` (full debug) green; `dicom-validate` release build green + smoke-tested (text/json, levels 3 & 5); `DICOMStudio` target builds. |
| 2026-06-08 | `dicom-diff` | Moved the comparison engine (`DICOMComparer` + `ComparisonResult` + `TagModification` + `PixelDifference`) **and** the renderer (`ComparisonReport` + `ComparisonOutputFormat`) out of `Sources/dicom-diff/main.swift` into `Sources/DICOMKit/Comparison/`. CLI shrunk to argv→engine→render→print. App `executeDicomDiff()` deleted its parallel `DiffResult`/`diffCompare`/`diffElementsEqual` engine **and** its `diffFormat*` renderers (~165 lines) and now calls the shared `DICOMComparer` + `ComparisonReport` — so output is now byte-identical to the CLI, not just hand-synced. | `swift build` (full debug) green; `dicom-diff` release build green + smoke-tested (identical→exit 0, RLE-vs-raw→1 modified tag exit 1, text/summary); `DICOMStudio` builds. |
| 2026-06-08 | `dicom-tags` | Extracted the tag-editing engine into `Sources/DICOMKit/TagEditing/TagEditor.swift` (`TagEditor` + `TagEditorError`, both public); removed the old `Sources/dicom-tags/TagEditor.swift`. CLI `main.swift` is now a thin adapter (read → `applyChanges` → print → write). App `executeDicomTags()` deleted its inline reimplementation (~70 lines) plus the dead `tagsLabel`/`tagsDefaultVR` helpers and now calls the shared `TagEditor`. **Drift reconciled in the engine:** it resolves tag names/VRs through the full `DataElementDictionary` and **skips** unknown specifiers with a note (the app's behavior) instead of the CLI's old hardcoded 31-entry table + throw-on-unknown — so the CLI gains full-dictionary support and never aborts a whole edit over one bad tag. App output is unchanged (it already used the dictionary). | `swift build` (full debug) green; `dicom-tags` release build green + smoke-tested: set/delete/dry-run, `(0008,103E)` resolved via dictionary, unknown tag skipped (not fatal); `DICOMStudio` builds. |
| 2026-06-08 | `dicom-anon` | Moved the `Anonymizer` engine (+ `AnonymizationProfile`/`Action`/`Result`/`AuditLogEntry`) out of `Sources/dicom-anon/Anonymizer.swift` into `Sources/DICOMKit/Anonymization/`; the CLI-only `AnonymizationError` stayed in the CLI. App `SecurityViewModel.executeAnonymization` deleted its inline reimplementation (profile tag sets, `pseudonymize`, `shiftDICOMDate`) and now delegates the whole per-file transform to the shared `DICOMKit.Anonymizer`, keeping only its file-walking / sandbox-write / summary shell. The app's UI `AnonymizationProfile` (5 cases) stays for the picker and maps to the engine profile. **Drift reconciled in the shared engine:** (a) the F19 fix — `--remove`/`--replace` now honor *any* tag, not just profile tags (`tagsToProcess` unions `customActions.keys`); (b) the app now actually regenerates UIDs and runs PHI scanning, which its old copy skipped. | `swift build` (full debug) green; `dicom-anon` release build green + smoke-tested: PatientID→SHA-256 hash, `--remove 0008,0060` (non-profile) removed, `--replace` applied, `--regenerate-uids` rewrote dataset UIDs; `DICOMStudio` builds. |

## The Goal (one sentence)

When CLI Workshop runs `dicom-anon` (or any tool), it should execute the **same
DICOMKit library function** the terminal tool executes — so that exercising the
app is really exercising DICOMKit, exactly as a third-party app importing the
package would.

## Why

DICOMKit is a **library**. Any application can import it and do DICOM work. The
`dicom-*` command-line tools are thin programs on top of it. DICOMStudio is our
"real third-party app," used to confirm:

> Does each tool behave the same whether you run it in the terminal **or** call
> it from an app that imports DICOMKit?

That confirmation only means something if the app and the CLI run the **same
code**. Where the app re-implemented a tool's processing, "app vs CLI" stops
testing DICOMKit and just compares two look-alike copies that can drift. The fix
is to delete the copies and call the real package API.

## The Model: Three Stages, One Shared Middle

Every tool has three stages:

1. **Input read** — collect values (paths, host/port, options).
2. **Process** — the actual DICOM work.
3. **Output render** — show the result (CLI text vs app UI).

**Only stage 2 must be shared.** Input and output are *adapter* concerns: the CLI
parses argv and prints text; the app reads UI fields and renders to its console.
That difference is fine and expected. What must be identical is the **processing
engine** in the middle — one function, `input values → result data`, living in a
package library, called by both.

**"App matches CLI" means same result data, not same text.** Compare the result
(did it succeed, what did it produce, what are the values), not the wording. The
only tools where text is *also* shared today are `dicom-info` and `dicom-dump`,
because their renderer (`MetadataPresenter`, `HexDumper`) lives in the library
too — a nice bonus, not the requirement.

## Verified Classification of All 32 Tools

Three buckets, decided from the real source and re-checked. The "Shared engine"
column is the package-library type both sides should call.

### Bucket A — Already shared ✅ (15 tools — call the same library engine today)

No extraction needed. The app and CLI already route core processing through the
same package type. Remaining differences are input defaults / output wording only
(optional to unify later).

| Tool | Shared engine (module) |
|------|------------------------|
| `dicom-info` | `MetadataPresenter` (DICOMKit) — renderer shared too |
| `dicom-dump` | `HexDumper` (DICOMKit) — renderer shared too |
| `dicom-echo` | `DICOMVerificationService.echo` (DICOMNetwork) |
| `dicom-json` | `DICOMJSONEncoder` / `DICOMJSONDecoder` (DICOMWeb) |
| `dicom-xml` | `DICOMXMLEncoder` / `DICOMXMLDecoder` (DICOMWeb) |
| `dicom-convert` | `TransferSyntaxConverter` (DICOMCore) |
| `dicom-dcmdir` | `DICOMDirectory` / `DICOMDIRWriter` / `DICOMDIRReader` (DICOMKit) |
| `dicom-pdf` | `EncapsulatedDocumentParser` / `Builder` (DICOMKit) |
| `dicom-send` | `DICOMStorageService.store` (DICOMNetwork) |
| `dicom-qr` | `DICOMQueryService` + `DICOMRetrieveService` (DICOMNetwork) |
| `dicom-mwl` | `DICOMModalityWorklistService` (DICOMNetwork) |
| `dicom-mpps` | `DICOMMPPSService` (DICOMNetwork) |
| `dicom-qido` | `DICOMwebClient` search (DICOMWeb) |
| `dicom-wado` | `DICOMwebClient` / `WADOURIClient` retrieve (DICOMWeb) |
| `dicom-stow` | `DICOMwebClient.storeInstances` (DICOMWeb) |

### Bucket B — Partly copied ⚠️ (6 tools — core shared, workflow re-implemented)

A shared low-level API exists and is used for the core step, but the app
re-implements the surrounding **workflow** (orchestration, batching, formatting).
Fix: route the app through the existing shared API where one exists, and extract
the small workflow piece where it doesn't.

| Tool | What's already shared | What's still copied → action |
|------|-----------------------|------------------------------|
| `dicom-uid` | `UIDGenerator` (DICOMCore), `UIDDictionary` (DICOMDictionary) | The `UIDManager` workflow (validate/lookup/regenerate) lives only in `Sources/dicom-uid/UIDManager.swift`; app re-implements it inline. **Extract `UIDManager` → DICOMKit.** ✅ Output now parity-verified (DIFFERS=0); engine extraction still pending. |
| `dicom-compress` | `CodecRegistry` (DICOMCore) | `CompressionManager` workflow lives only in `Sources/dicom-compress/`; app re-implements via `dcCompress*` helpers. **Extract `CompressionManager` → DICOMKit/DICOMCore.** ✅ Output now parity-verified (DIFFERS=0); engine extraction still pending. |
| `dicom-export` | render primitives (`DICOMFile.tryRenderFrame`, DICOMKit) | EXIF / contact-sheet / GIF / bulk export engine inlined in both. **Extract a `DICOMImageExporter` → DICOMKit.** |
| `dicom-query` | `DICOMQueryService.find` (DICOMNetwork) | Query-key building, multi-step orchestration, and result formatters are app-local. **Extract a `QueryWorkflow` + shared formatter → DICOMNetwork.** |
| `dicom-retrieve` | `DICOMRetrieveService` C-MOVE/C-GET (DICOMNetwork) | Part 10 wrapper + received-instance save loop reimplemented on each side. **Extract a `Part10Writer` (+ retrieve coordinator) → DICOMCore/DICOMNetwork.** |
| `dicom-ups` | `DICOMwebClient` UPS-RS (DICOMWeb) | App's change-state branch bypasses the shared `DICOMwebClient.changeWorkitemState` and hand-builds the request. **No new library — route the app through the existing API**; optionally lift state-machine validation into `UPSClient`. |

### Bucket C — Fully copied ❌ (11 tools — engine lives only in the executable; the real work)

The tool's processing engine exists **only** inside `Sources/dicom-<tool>/`, and
the app maintains a separate re-implementation. There is no shared API to point
at yet. For each: **extract the engine into a package library (DICOMKit), make
the CLI call the extracted library, then point the app at the same library and
delete the app's copy.**

| Tool | Engine to extract | Currently in | New shared type → module |
|------|-------------------|--------------|--------------------------|
| `dicom-validate` ✅ **DONE** | `DICOMValidator` + IOD validators + `ValidationIssue/Result` + `Report` renderer | ~~`Sources/dicom-validate/`~~ → now `Sources/DICOMKit/Validation/` | `DICOMValidator` + `ValidationReport` (shared by CLI + app) |
| `dicom-anon` ✅ **DONE** | `Anonymizer` + `AnonymizationProfile/Action/Result/AuditLogEntry` | ~~`Sources/dicom-anon/Anonymizer.swift`~~ → now `Sources/DICOMKit/Anonymization/` | `Anonymizer` shared by CLI + app; F19 (`--remove`/`--replace` any tag) reconciled in the engine |
| `dicom-diff` ✅ **DONE** | `DICOMComparer` + `ComparisonResult` + `PixelDifference` + `TagModification` + formatters | ~~`Sources/dicom-diff/main.swift`~~ → now `Sources/DICOMKit/Comparison/` | `DICOMComparer` + `ComparisonReport` (shared by CLI + app; byte-identical output) |
| `dicom-tags` ✅ **DONE** | `TagEditor` + `TagEditorError` | ~~`Sources/dicom-tags/TagEditor.swift`~~ → now `Sources/DICOMKit/TagEditing/` | `TagEditor` shared by CLI + app; resolution unified on `DataElementDictionary` + skip-on-unknown |
| `dicom-split` ✅ **DONE** | `FrameSplitter` (frame extract + image export) | ~~`Sources/dicom-split/FrameSplitter.swift`~~ → now `Sources/DICOMKit/Splitting/` | `FrameSplitter` shared (returns `SplitResult` + log closure) |
| `dicom-merge` ✅ **DONE** | `FrameMerger` + `MergeFormat/Level/SortCriteria/Order/Error` | ~~`Sources/dicom-merge/FrameMerger.swift`~~ → now `Sources/DICOMKit/Merging/` | `FrameMerger` shared (log closure + deterministic sort); parity MATCHES |
| `dicom-archive` ✅ **DONE** | `ArchiveIndex` model + init/import/query/list/export/check/stats ops | ~~`Sources/dicom-archive/main.swift`~~ → now `Sources/DICOMKit/Archive/` | `ArchiveStore` (model + 7 string-returning ops) shared; parity MATCHES |
| `dicom-study` ✅ **DONE** | `StudyAnalyzer` / `CompletenessChecker` / `StatsCalculator` / `StudyComparator` + models | ~~`Sources/dicom-study/StudyManager.swift`~~ → now `Sources/DICOMKit/Study/` | `StudyScanner` + `StudyReport` + models shared (sorted series, `✓`); parity MATCHES. (`StudyOrganizer` stays CLI-local for now.) |
| `dicom-image` | image→Secondary-Capture converter (CGImage/ImageIO pixel extract + EXIF) | `Sources/dicom-image/main.swift` | `ImageToSecondaryCaptureConverter` → DICOMKit (route SC assembly through existing `SecondaryCaptureBuilder`) |
| `dicom-pixedit` ✅ **DONE** | `PixelEditor` + `PixelDataDescriptor` + `PixelOperation` + `PixelEditError` | ~~`Sources/dicom-pixedit/PixelEditor.swift`~~ → now `Sources/DICOMKit/PixelEditing/` | `PixelEditor` shared (`processData`/`processFile` + log closure); parity MATCHES |
| `dicom-script` | `ScriptParser` / `ScriptExecutor` / `ScriptValidator` / `TemplateGenerator` + models | `Sources/dicom-script/ScriptEngine.swift` | `DICOMScriptEngine` → DICOMKit (executor needs an injectable command runner so the sandboxed app can run dry-run/plan mode) |

## The Repeatable Extraction Recipe (Bucket C, and Bucket B where noted)

Do the same five steps for every tool that needs an engine moved:

1. **Lift the engine.** Move the engine type(s) and their result/model/error
   types out of `Sources/dicom-<tool>/` into the target package library
   (DICOMKit for file/workflow engines; DICOMCore for low-level; the network/web
   engines are already in DICOMNetwork/DICOMWeb). Make them `public`. Keep them
   **UI-free and process-free** — they take input values and return result data;
   they do not print, do not touch SwiftUI, do not shell out, and (where the app
   needs sandbox-scoped writes) return bytes/results rather than writing to disk
   so the caller controls output.
2. **Repoint the CLI.** The `dicom-<tool>` program shrinks to: parse argv → call
   the shared engine → print text / write files. Delete its now-duplicated local
   engine.
3. **Repoint the app.** `CLIWorkshopViewModel.executeDicom<Tool>()` calls the
   **same** shared engine → renders the result to the console / history. Delete
   the app's re-implementation (the inline helpers or the parallel ViewModel
   logic).
4. **Reconcile the drift the move exposes.** Several tools have two engines that
   diverged (e.g. `dicom-image` OB-vs-OW PixelData VR; `dicom-tags` hardcoded
   VR table vs dictionary lookups; `dicom-anon` two different
   `AnonymizationProfile` enums). Pick the correct behavior once, in the shared
   engine.
5. **Verify parity by result.** Same input → same result data from both the CLI
   and the app (see Verification).

For Bucket B tools whose **core** is already shared (`dicom-ups`, the network
core of `dicom-query`/`dicom-retrieve`), step 1 is smaller or skipped — the work
is mostly steps 2–3 (stop the app bypassing the existing API) plus extracting one
small workflow helper.

## Migration Order

Sequenced by value and risk. Each wave is independently shippable.

- **Wave 0 — lock in the wins (Bucket A).** No engine work. Optionally move
  input defaults (e.g. `dicom-echo` calling-AE default, query timeouts) into the
  shared layer so app and CLI stop disagreeing on defaults. Add result-level
  parity assertions for these 15 so they can't regress.
- **Wave 1 ✅ DONE — the high-value local copies (Bucket C, read/compare/transform):**
  `dicom-validate` ✅, `dicom-diff` ✅, `dicom-anon` ✅, `dicom-tags` ✅. The most
  visible "two copies that drift" cases — all migrated and verified.
- **Wave 2 ✅ DONE — file-organization copies (Bucket C):** `dicom-split` ✅,
  `dicom-merge` ✅, `dicom-study` ✅, `dicom-archive` ✅ — all migrated and verified
  (parity DIFFERS for this cohort all resolved; merge + study moved to MATCH).
- **Wave 3 (in progress) — image/pixel + scripting copies (Bucket C):** `dicom-pixedit` ✅,
  then `dicom-image`, `dicom-script`. These touch CoreGraphics/ImageIO and (script)
  process execution — give `dicom-script` an injectable command runner so the
  sandboxed app gets a plan/dry-run runner.
- **Wave 4 — partly-copied cleanups (Bucket B):** `dicom-uid`, `dicom-compress`,
  `dicom-export` (extract the workflow engine), then `dicom-query`,
  `dicom-retrieve`, `dicom-ups` (route through existing shared APIs + small
  extractions).

## Where Extracted Engines Live

- **DICOMKit** — file/document/workflow engines (validate, anon, diff, tags,
  split, merge, archive, study, image, pixedit, compress, uid, export). It
  already owns `DICOMFile`, `MetadataPresenter`, `HexDumper`,
  `OutputPathResolver`, `SecondaryCaptureBuilder`, and depends on
  DICOMCore/DICOMDictionary — the natural home.
- **DICOMCore** — low-level primitives only (codecs, transcode, UID generation,
  Part 10 byte layout). Already shared; add the `Part10Writer` here.
- **DICOMNetwork / DICOMWeb** — DIMSE and DICOMweb engines are **already** here
  and already shared; Bucket B network work is small helpers + routing, not new
  modules.
- **`dicom-script`** may warrant its own small `DICOMScripting` target if you
  prefer to keep the script interpreter out of DICOMKit; either is fine as long
  as it's a library both sides import.

Keep extracted engines free of SwiftUI, `Process`, and `ArgumentParser` — those
belong in the adapters (the app and the CLI program), never in the shared engine.
Do **not** put shared engines in `DICOMToolbox`; that module mixes in UI and
process-launching.

## Verification

- **Result-level parity (primary).** For each migrated tool, assert the same
  input yields the same **result data** whether invoked through the CLI adapter
  or `CLIWorkshopViewModel.executeDicom<Tool>()`. Extend parity coverage from the
  current input-contract checks (flag presence / type / defaults, via
  `Scripts/cli-parity.sh`) to result data and produced artifacts (files,
  directories, JSON/XML, DICOM output).
- **Release-mode smoke.** Keep building and smoke-running the `dicom-*` binaries
  for migrated tools so the CLI adapter itself stays healthy.
- **Retire the testing-only text compare.** The sandbox-disabled
  `CLIToolTerminalCompare` (runs the real binary side-by-side) stays only as a
  development cross-check; once result-level parity exists, remove it and turn the
  App Sandbox back on.

## Definition of Done (per tool)

- The processing engine lives in a package library, not in `Sources/dicom-<tool>/`
  and not duplicated in the app.
- `dicom-<tool>` = parse args → call the shared engine → print/write.
- `executeDicom<Tool>()` = read UI fields → call the **same** shared engine →
  render to UI. No re-implemented processing remains in the app.
- A result-level parity test confirms identical result data for the same input.

When all 32 are done, running a tool in CLI Workshop and running it in the
terminal are two thin adapters over one library call — which is the whole point:
proof that DICOMKit behaves identically for the app and for any third party that
imports it.

## Appendix — Per-Tool Detail

| Tool | Bucket | App entry | Shared/target engine | CLI engine today |
|------|--------|-----------|----------------------|------------------|
| `dicom-info` | A | `executeDicomInfo` | `MetadataPresenter` (DICOMKit) | shared (DICOMKit) |
| `dicom-dump` | A | `executeDicomDump` | `HexDumper` (DICOMKit) | shared (DICOMKit) |
| `dicom-echo` | A | `executeDicomEcho` | `DICOMVerificationService` (DICOMNetwork) | shared (DICOMNetwork) |
| `dicom-json` | A | `executeDicomJSON` | `DICOMJSONEncoder/Decoder` (DICOMWeb) | shared (DICOMWeb) |
| `dicom-xml` | A | `executeDicomXML` | `DICOMXMLEncoder/Decoder` (DICOMWeb) | shared (DICOMWeb) |
| `dicom-convert` | A | `executeDicomConvert` | `TransferSyntaxConverter` (DICOMCore) | shared (DICOMCore) |
| `dicom-dcmdir` | A | `executeDicomDcmdir` | `DICOMDirectory`/`DICOMDIRWriter`/`Reader` (DICOMKit) | shared (DICOMKit) |
| `dicom-pdf` | A | `executeDicomPdf` | `EncapsulatedDocumentParser/Builder` (DICOMKit) | shared (DICOMKit) |
| `dicom-send` | A | `executeDicomSend` | `DICOMStorageService` (DICOMNetwork) | thin wrapper → shared |
| `dicom-qr` | A | `executeDicomQr` | `DICOMQueryService`+`DICOMRetrieveService` (DICOMNetwork) | thin wrapper → shared |
| `dicom-mwl` | A | `executeDicomMwl` | `DICOMModalityWorklistService` (DICOMNetwork) | shared (DICOMNetwork) |
| `dicom-mpps` | A | `executeDicomMpps` | `DICOMMPPSService` (DICOMNetwork) | shared (DICOMNetwork) |
| `dicom-qido` | A | `executeDicomQido` | `DICOMwebClient` (DICOMWeb) | shared (`dicom-wado query`) |
| `dicom-wado` | A | `executeDicomWado` | `DICOMwebClient`/`WADOURIClient` (DICOMWeb) | shared (DICOMWeb) |
| `dicom-stow` | A | `executeDicomStow` | `DICOMwebClient.storeInstances` (DICOMWeb) | shared (`dicom-wado store`) |
| `dicom-uid` | B | `executeDicomUID*` | extract `UIDManager` → DICOMKit | `Sources/dicom-uid/UIDManager.swift` |
| `dicom-compress` | B | `executeDicomCompress*` | extract `CompressionManager` → DICOMKit/DICOMCore | `Sources/dicom-compress/CompressionManager.swift` |
| `dicom-export` | B | `executeDicomExport` | extract `DICOMImageExporter` → DICOMKit | `Sources/dicom-export/main.swift` |
| `dicom-query` | B | `executeDicomQuery` | core shared; extract `QueryWorkflow`+formatter → DICOMNetwork | `QueryExecutor` → shared `DICOMQueryService` |
| `dicom-retrieve` | B | `executeDicomRetrieve` | core shared; extract `Part10Writer`+coordinator | `RetrieveExecutor` → shared `DICOMRetrieveService` |
| `dicom-ups` | B | `executeDicomUps*` | route app through existing `DICOMwebClient.changeWorkitemState` | shared (`dicom-wado` UPS) |
| `dicom-validate` ✅ | C→done | `ValidationViewModel` → `DICOMKit.DICOMValidator` | **done:** `DICOMValidator`+`ValidationReport` now in DICOMKit | `Sources/DICOMKit/Validation/` (shared) |
| `dicom-anon` ✅ | C→done | `SecurityViewModel` → shared engine | **done:** `Anonymizer` now in DICOMKit (F19 reconciled) | `Sources/DICOMKit/Anonymization/` (shared) |
| `dicom-diff` ✅ | C→done | `executeDicomDiff` → shared engine | **done:** `DICOMComparer`+`ComparisonReport` now in DICOMKit | `Sources/DICOMKit/Comparison/` (shared) |
| `dicom-tags` ✅ | C→done | `executeDicomTags` → shared engine | **done:** `TagEditor` now in DICOMKit (dictionary + skip reconciled) | `Sources/DICOMKit/TagEditing/` (shared) |
| `dicom-split` ✅ | C→done | `executeDicomSplit` → shared engine | **done:** `FrameSplitter` now in DICOMKit | `Sources/DICOMKit/Splitting/` (shared) |
| `dicom-merge` ✅ | C→done | `executeDicomMerge` → shared engine | **done:** `FrameMerger` now in DICOMKit | `Sources/DICOMKit/Merging/` (shared) |
| `dicom-archive` ✅ | C→done | `executeDicomArchive` → shared engine | **done:** `ArchiveStore` now in DICOMKit | `Sources/DICOMKit/Archive/` (shared) |
| `dicom-study` ✅ | C→done | `executeDicomStudy*` → shared engine | **done:** `StudyScanner`+`StudyReport`+models in DICOMKit | `Sources/DICOMKit/Study/` (shared) |
| `dicom-image` | C | `executeDicomImage` | extract `ImageToSecondaryCaptureConverter` → DICOMKit | `Sources/dicom-image/main.swift` |
| `dicom-pixedit` ✅ | C→done | `executeDicomPixedit` → shared engine | **done:** `PixelEditor` now in DICOMKit | `Sources/DICOMKit/PixelEditing/` (shared) |
| `dicom-script` | C | `executeDicomScript` | extract `DICOMScriptEngine` → DICOMKit/new target | `Sources/dicom-script/ScriptEngine.swift` |

*Source: `CLIParityEngine.executeSupported` (32 tools) cross-referenced against
`CLIWorkshopViewModel.swift`, each `Sources/dicom-<tool>/`, and the package
libraries. Every Bucket B/C "needs extraction" verdict was independently
re-checked to confirm no existing shared library type already covers the work.*
