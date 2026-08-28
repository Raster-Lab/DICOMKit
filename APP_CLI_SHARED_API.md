# App ↔ CLI Shared DICOMKit API

How the `dicom-*` command-line tools **and** DICOMStudio's *CLI Workshop* run the
**same** processing code from the DICOMKit Swift package, instead of each
mirror-implementing the logic.

> **Status (2026-08-03):** every file-processing tool shares its engine, and the
> **console/text layer is shared too** — not just the processing core. The
> remaining differences between App and CLI are **intentional adapter concerns**
> (sandbox write-redirect notes, emoji vs ASCII, educational/verbose extras) or
> **genuinely non-deterministic** output (freshly generated UIDs/timestamps, live
> network responses) — never duplicated logic.
>
> The Tier-2 golden-file parity harness (goldens, `CLIContracts.json`,
> `cli-parity-gen`, `StudioParityTests`, the CLI Parity screen, `APP_CLI_PARITY_MATRIX.md`)
> was **removed on 2026-08-03** — 103 files, ~14,400 lines of code and fixtures.
> Verification now rests on two things: the **oracle-based round-trip suite**
> (`swift test --filter DICOMRoundTripTests`, see `ROUND_TRIP_TESTS_PLAN.md`) and,
> for tools whose console output previously drifted between App and CLI, a
> **shared console/formatter type per tool** (§6) pinned by targeted tests. The
> in-process `CLIToolTerminalCompare` comparator (§6) was kept for future
> ad-hoc use but is reachable only from code, not the UI.

---

## 1. The pattern

Every tool has **one engine** and **two thin adapters**:

```
                ┌───────────────────────────────────────────┐
                │          DICOMKit Swift package            │
                │  (the single source of truth — the engine) │
                │                                            │
                │  DICOMValidator · DICOMComparer · Anonymizer│
                │  TagEditor · FrameMerger · FrameSplitter   │
                │  StudyScanner/Report · ArchiveStore        │
                │  PixelEditor · ScriptEngine · ImageConverter│
                │  UIDManager · CompressionManager           │
                │  DICOMImageExporter · MetadataPresenter …  │
                └───────────────▲───────────────▲───────────┘
                                │               │
              parse argv,       │               │   read params, sandbox,
              print stdout/stderr               │   write via OutputAccess,
                                │               │   render to SwiftUI console
                ┌───────────────┴────┐   ┌──────┴───────────────────────┐
                │  CLI adapter        │   │  App adapter                 │
                │  Sources/dicom-<t>/ │   │  CLIWorkshopViewModel        │
                │  main.swift         │   │  .executeDicom<Tool>()       │
                │  (ArgumentParser)   │   │  (CLI Workshop)              │
                └─────────────────────┘   └──────────────────────────────┘
```

The engine does **all** the real work — parsing DICOM, transforming pixels,
building reports, rendering text/JSON — and returns **values, structs, or
formatted strings**. The adapters only translate between their host environment
and the engine.

### Why this matters

Before the migration, DICOMStudio re‑implemented each tool's logic inline (a
parallel ~11 k‑line copy in `CLIWorkshopViewModel.swift`). The two copies drifted:
the same input produced subtly different output in the app vs the CLI. Sharing
the engine makes drift **structurally impossible** for the processing core — the
only differences left are the adapter concerns enumerated in §5.

> **Core principle — text‑exact output via one shared renderer.** Because the CLI
> and DICOMStudio call the **same engine *and* the same output renderer**, they
> emit **byte/text‑exact** output for the same input (subcommand + flags) — not
> two formatters that happen to agree. This holds for results *and* errors: e.g.
> `dicom-study organize --copy` run twice raises the identical
> `"… already exists"` error in both, because both run the shared `StudyOrganizer`
> (neither pre‑deletes the destination). **This invariant must be maintained for
> every tool:** when adding or changing a tool, route both adapters through one
> shared engine/renderer (return strings/structs or an injected `log` closure —
> never re‑format in the adapter). The only sanctioned exceptions are the
> adapter‑specific items in §5 (sandbox path/notes, emoji, intentional educational
> extras, genuinely non‑deterministic UID/timestamp/network output).

---

## 2. Adapter responsibilities

| Concern | CLI adapter (`Sources/dicom-<tool>/`) | App adapter (`CLIWorkshopViewModel.executeDicom<Tool>`) |
|---|---|---|
| **Argument parsing** | `ArgumentParser` (`@Option`/`@Flag`/`@Argument`) | `paramValue("flag")` from the Workshop form |
| **Input access** | direct `Data(contentsOf:)` on a path | macOS **security‑scoped URLs** (`startAccessingSecurityScopedResource`) |
| **Output write** | direct `Data.write(to:)` | **`OutputAccess`** — sandbox/TCC‑resilient (falls back to `~/Downloads/DICOMStudio/<subfolder>/` and prints a redirect note) |
| **Result display** | `print()` → stdout, `fprintln()` → stderr | append to the SwiftUI console + history; status flags |
| **Concurrency** | synchronous `run()` | `await Task.detached { … }` off the main actor |
| **Errors** | `throw` → ArgumentParser exit code | caught → console message + `.error` status |

The engine itself contains **none** of the above. The architectural rules
(enforced by code review and the round-trip/console-parity tests) are:

> **The shared library must not import `ArgumentParser`, spawn `Process`, import
> `SwiftUI`, or print to stdout/stderr.** Those are adapter concerns. Engines emit
> output by **returning strings/structs** or via an **injected closure**
> (`log:`/`CommandRunner`).

---

## 3. Engine inventory

Each tool's processing engine and the library module it lives in. "Console" marks
tools where the app and CLI previously duplicated the *text* layer on top of a
shared engine; those now also share a `*Console` formatter (see §6).

| Tool | Subcommands | Shared engine | Module | Console |
|---|---|---|---|---|
| `dicom-info` | (default) | `MetadataPresenter` | `DICOMKit` | |
| `dicom-dump` | default · `--tag` | `HexDumper` | `DICOMKit` | |
| `dicom-validate` | (default) | `DICOMValidator` / `ValidationReport` | `DICOMKit/Validation` | |
| `dicom-diff` | text · json · summary | `DICOMComparer` / `ComparisonReport` | `DICOMKit/Comparison` | |
| `dicom-tags` | (default) | `TagEditor` | `DICOMKit/TagEditing` | |
| `dicom-anon` | profile · remove · replace · keep · … | `Anonymizer` | `DICOMKit/Anonymization` | |
| `dicom-json` | default · `--reverse` | `DICOMJSONEncoder` / `DICOMJSONDecoder` | `DICOMWeb` | |
| `dicom-xml` | (default) | `DICOMXMLEncoder` / `DICOMXMLDecoder` | `DICOMWeb` | |
| `dicom-convert` | (default) | `TransferSyntaxConverter` + `DICOMFile` rendering | `DICOMCore` + `DICOMKit` | |
| `dicom-split` | (default) | `FrameSplitter` | `DICOMKit/Splitting` | `SplitConsole` |
| `dicom-merge` | (default) | `FrameMerger` | `DICOMKit/Merging` | `MergeConsole` |
| `dicom-study` | summary · check · stats · compare · organize | `StudyScanner` / `StudyReport` / `StudyOrganizer` | `DICOMKit/Study` | |
| `dicom-archive` | init · import · query · list · export · check · stats | `ArchiveStore` | `DICOMKit/Archive` | |
| `dicom-pixedit` | (default) | `PixelEditor` | `DICOMKit/PixelEditing` | |
| `dicom-script` | template · run · validate | `ScriptParser`/`Executor`/`Validator`/`TemplateGenerator` | `DICOMKit/Scripting` | `ScriptConsole` |
| `dicom-image` | single · batch · multipage‑TIFF | `ImageConverter` | `DICOMKit/SecondaryCapture` | |
| `dicom-uid` | generate · validate · lookup · regenerate | `UIDManager` | `DICOMKit/UIDManagement` | |
| `dicom-compress` | info · compress · decompress · batch · backends | `CompressionManager` | `DICOMKit/Compression` | `CompressionConsole` |
| `dicom-export` | single · contact‑sheet · animate · bulk | `DICOMImageExporter` | `DICOMKit/ImageExport` | |
| `dicom-pdf` | extract · encapsulate | `EncapsulatedDocumentParser` / `…Builder` | `DICOMKit` + `DICOMCore` | |
| `dicom-dcmdir` | create · validate · dump · update | `DICOMDirectory` / `DICOMDIRReader` / `…Writer` | `DICOMKit` + `DICOMCore` | `DICOMDIRDumpFormatter` / `DICOMDIRWorkflow` |
| `dicom-echo` | (default) | `DICOMVerificationService` | `DICOMNetwork` | |
| `dicom-send` | (default) | `DICOMStorageService` | `DICOMNetwork` | `NetworkConsole` |
| `dicom-query` | (default) | `DICOMQueryService` | `DICOMNetwork` | `NetworkConsole` |
| `dicom-retrieve` | study · series · instance · c‑move · c‑get | `DICOMRetrieveService` | `DICOMNetwork` | `NetworkConsole` |
| `dicom-qr` | query · resume | `DICOMQueryService` / `DICOMRetrieveService` | `DICOMNetwork` | `NetworkConsole` |
| `dicom-mwl` | query · create | `DICOMModalityWorklistService` | `DICOMNetwork` | `NetworkConsole` |
| `dicom-mpps` | create · update | `DICOMMPPSService` | `DICOMNetwork` | `NetworkConsole` |
| `dicom-wado` | WADO‑RS · WADO‑URI · QIDO‑RS · STOW‑RS · UPS‑RS | `DICOMwebClient` / `WADOURIClient` | `DICOMWeb` | |
| `dicom-print` | status · send · job · list‑printers · add‑printer · remove‑printer | `PrintImagePreparer` / `PrintJobRequest` / `PrintWorkflow` / `PrintConsoleFormatter` | `DICOMPrintKit` | `PrintConsoleFormatter` |
| `dicom-printscp` | serve · simulate · status · queues | `PrintSCPSettings` / `PrintSCPService` / `PrintSCPConsole` / `PrintSCPSimulator` | `DICOMPrintKit` | `PrintSCPConsole` |

The two print tools are the clearest instance of the pattern in both directions: the SCU's
engines are shared with Studio's print sheet, and the SCP's with Studio's Print SCP screen. On
the SCP side the app surface came first, so the sharing was done by **moving** the settings
type, the assembly and the wording out of `DICOMStudio` into `DICOMPrintKit` — the view model
now owns only what a window owns (retained films, selection, button state). Their equivalence
is covered by tests — `Tests/DICOMPrintKitTests/PrintSCPSharedCoreTests.swift` runs a real SCU
into a listener assembled exactly as both surfaces assemble one.

Two helper engines are reused across several tools: `UIDGenerator` (DICOMCore) and
`UIDDictionary` (DICOMDictionary) back both `dicom-uid` and `dicom-image`;
`DICOMFile.tryRenderFrame` (DICOMKit rendering) backs `dicom-export` and
`dicom-convert`.

---

## 4. The sandbox‑aware "in‑memory variant" pattern

The CLI writes output straight to a path; the **sandboxed app** must write through
`OutputAccess` (which may redirect to `~/Downloads/DICOMStudio/`). A file‑writing
engine method like `processFile(input:output:)` doesn't fit the app — it writes
to disk itself. So engines that produce files expose a **pure in‑memory variant**
that returns the bytes, and a thin file convenience that wraps it:

| Engine | In‑memory variant (app uses) | File convenience (CLI uses) |
|---|---|---|
| `PixelEditor` | `processData(_:operations:) -> (Data, PixelEditInfo)` | `processFile(inputPath:outputPath:operations:)` |
| `CompressionManager` | `compressData(_:codec:quality:) -> Data` · `decompressData(_:syntax:)` · `getCompressionInfo(data:)` | `compressFile(…)` · `decompressFile(…)` · `getCompressionInfo(path:)` |
| `UIDManager` | `regenerateData(_:root:…) -> (Data, [UIDMapping])` | `regenerateUIDs(inputPath:outputPath:…)` |
| `ImageConverter` | `secondaryCaptureData(imageURL:pageIndex:metadata:useExif:) -> Data` | (adapters write the returned bytes) |
| `FrameSplitter` | `SplitResult` of written paths / extracted data | `processDirectory(…) -> SplitResult` |

The CLI then does `let data = try engine.xData(...); try data.write(to: url)`,
while the app does `let data = try engine.xData(...); OutputAccess.write(data, …)`.
**Same bytes, different write path.**

### Injected output for engines that "log"

Engines that emit progress (verbose mode) take an injected **`log:` closure** so
the CLI routes it to stderr and the app accumulates it into the console string —
e.g. `PixelEditor(verbose:log:)`, `FrameMerger(log:)`, `ScriptExecutor(log:)`,
`ScriptValidator(log:)`.

### Injected execution for engines that would shell out

`ScriptExecutor` would run nested `dicom-*` tools via `Process`. Because the
library must not spawn processes, it takes an injected
**`CommandRunner` closure** `(_ tool, _ args) -> (output, exitCode)`. The CLI
supplies a real `/usr/bin/env` runner; the sandboxed app supplies a plan/dry‑run
runner (and the executor short‑circuits before the runner in dry‑run anyway).

---

## 5. Categories of remaining App↔CLI difference

With the engine shared, every remaining difference falls into one of these
**intentional** buckets (none is duplicated logic):

1. **Sandbox write‑redirect note** — the app's `OutputAccess` may append
   `Could not write to <path> … Redirected to: ~/Downloads/DICOMStudio/<sub>/`
   when the typed path is blocked by macOS TCC. The CLI has no sandbox.
   *(archive import/export, compress, export, uid regenerate, json, xml, pdf, anon, …)*
2. **Emoji vs ASCII** — the app substitutes plain symbols for some CLI emoji for
   SwiftUI‑console legibility/portability. *(dcmdir ✅→plain, echo/send ✓→✅, study `→`→`->`)*
3. **Educational / verbose extras** — the app adds explanatory lines the CLI
   omits: `dicom-validate` exit‑code annotation, `dicom-split` extracted‑path
   listing, `dicom-pixedit` "N operation(s) applied" summary, `dicom-script`
   "in‑app shows the plan only" note, `dicom-wado`/`ups` curl + raw HTTP echo,
   `dicom-query` parent‑study context columns.
4. **Latency units** — network tools print ms (app) vs s (CLI).
5. **Genuinely non‑deterministic output** — freshly generated SOP/Study/Series
   UIDs and current date/time (`dicom-image`, `dicom-merge`, `dicom-pdf`
   encapsulate, `dicom-uid generate/regenerate`), and live PACS/DICOMweb responses
   (all `DICOMNetwork`/`DICOMWeb` tools). The **engine logic is identical**; the
   bytes differ run‑to‑run by design, which is why these tools rely on the
   round-trip oracle suite (§6) rather than any byte-exact comparison.
6. **App‑only enhancements** — the app exposes capability the CLI doesn't:
   `dicom-mwl create` (REST + HL7), `dicom-query` two‑step SERIES/IMAGE fallback,
   `dicom-retrieve` server‑side Study‑UID auto‑resolution.

Anything **not** in these buckets is a bug. The audit found two and one is fixed:
`dicom-archive --skip-duplicates` (app toggle was ignored → **fixed**, `b418bfc`)
and `dicom-qr` patient‑name case (CLI uppercases the C‑FIND key, app sends as‑is —
documented in the matrix).

---

## 6. How parity is verified

The Tier‑2 golden-file harness described in earlier revisions of this doc (committed
per-scenario stdout/stderr/exit-code goldens, `StudioParityTests`, a `PARITY_STRICT=1`
CI gate) was **removed on 2026‑08‑03** — the app's reimplementations it was built to
catch drift in no longer exist for engines; what's left to verify is engine-sharing
(structural, checked by code review + build) and, for a handful of tools, a shared
*console/text* layer. Verification today rests on three legs:

1. **Shared console types, for tools where text previously drifted.** Some tools
   share the engine but had kept separate console/summary rendering in the CLI and
   the Workshop, and the two copies drifted (wrong labels, dropped version strings,
   different parsers for the same flag). Those tools now have a `*Console` enum in
   DICOMKit that owns every banner/summary/parser line — see the **Console** column
   in §3 — pinned by targeted tests, e.g.
   `Tests/DICOMRoundTripTest/SharedConsoleParityTests.swift` for split/merge/script.
2. **The oracle-based round-trip suite** (`swift test --filter DICOMRoundTripTests`)
   is the main automated app/CLI cross-check today: each oracle asserts a math or
   semantic fact (e.g. decoded-pixel-hash equality across a compress→decompress
   round trip) against a small corpus of anonymized real files, rather than
   byte-comparing a golden. See `ROUND_TRIP_TESTS_PLAN.md` and `ROUND_TRIP_TEST_DATA.md`.
3. **`CLIToolTerminalCompare` + `CLIToolBuilder`** (kept from the deleted harness,
   "may be useful for future testing") spawn the real `dicom-*` binary and diff its
   output against the app's in-process rendering after `normalize()` (ANSI/timestamp/
   duration/rate/path masking). They're reachable only from code — the Workshop UI
   panel that drove them was removed — so use them ad hoc, not as a gate.

**What this doesn't cover.** There is currently no automated sweep that runs every
tool's CLI and app adapter side by side and diffs raw text; drift in an *unshared*
adapter concern (an app-only educational line, a sandbox note) would only be caught
by manual testing or a future targeted test. Network (DIMSE) tools have no live-PACS
comparison harness either — `APP_CLI_NETWORK_PARITY.md` was deleted along with the
rest of the CLI Parity screen.

---

## 7. Reproducing / extending

- **Build everything:** `swift build`
- **Run the round-trip cross-check:** `swift test --filter DICOMRoundTripTests`
- **Add a tool to the shared model:** lift its engine into `Sources/DICOMKit/<Group>/`,
  make the entry points `public`, strip ArgumentParser/Process/printing (use
  `log:`/`CommandRunner`/return‑strings), add an in‑memory variant if it writes
  files, thin the CLI `main.swift`, repoint `executeDicom<Tool>` at the engine, and
  add or extend a round-trip oracle for it.
- **If the CLI and app still duplicate console/summary text on top of a shared
  engine** (see §6.1), lift that text — banners, summaries, flag parsers — into a
  `*Console` enum in DICOMKit next to the engine, and pin it with a targeted test
  (model on `Tests/DICOMRoundTripTest/SharedConsoleParityTests.swift`).

See [`CLI_WORKSHOP_SHARED_API_PLAN.md`](CLI_WORKSHOP_SHARED_API_PLAN.md) for the
full wave‑by‑wave migration log (note: its parity numbers predate the 2026‑08‑03
harness removal and are historical) and
[`CLI_TOOL_MODULE_CLASSIFICATION.md`](CLI_TOOL_MODULE_CLASSIFICATION.md) for the
per‑tool module classification.
