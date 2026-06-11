# App ↔ CLI Shared DICOMKit API

How the `dicom-*` command-line tools **and** DICOMStudio's *CLI Workshop* run the
**same** processing code from the DICOMKit Swift package, instead of each
mirror-implementing the logic.

> **Status (2026-06-09):** 21 tools migrated to shared engines across Waves 1–4.
> Tier‑2 output parity is **MATCH=266, DIFFERS=0** with an empty allowlist and a
> green `PARITY_STRICT=1` gate. The remaining differences between App and CLI are
> **intentional adapter concerns** (sandbox write-redirect notes, emoji vs ASCII,
> educational/verbose extras) or **genuinely non-deterministic** output (freshly
> generated UIDs/timestamps, live network responses) — never duplicated logic.
> See [`APP_CLI_PARITY_MATRIX.md`](APP_CLI_PARITY_MATRIX.md) for the per‑tool,
> per‑flag verdict.

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
(enforced by code review and the parity harness) are:

> **The shared library must not import `ArgumentParser`, spawn `Process`, import
> `SwiftUI`, or print to stdout/stderr.** Those are adapter concerns. Engines emit
> output by **returning strings/structs** or via an **injected closure**
> (`log:`/`CommandRunner`).

---

## 3. Engine inventory

Each tool's processing engine and the library module it lives in. "Golden" =
number of committed Tier‑2 parity scenarios that machine‑verify byte‑exact output
(see §6).

| Tool | Subcommands | Shared engine | Module | Goldens |
|---|---|---|---|---:|
| `dicom-info` | (default) | `MetadataPresenter` | `DICOMKit` | 9 |
| `dicom-dump` | default · `--tag` | `HexDumper` | `DICOMKit` | 9 |
| `dicom-validate` | (default) | `DICOMValidator` / `ValidationReport` | `DICOMKit/Validation` | 8 |
| `dicom-diff` | text · json · summary | `DICOMComparer` / `ComparisonReport` | `DICOMKit/Comparison` | 11 |
| `dicom-tags` | (default) | `TagEditor` | `DICOMKit/TagEditing` | 4 |
| `dicom-anon` | profile · remove · replace · keep · … | `Anonymizer` | `DICOMKit/Anonymization` | 9 |
| `dicom-json` | default · `--reverse` | `DICOMJSONEncoder` / `DICOMJSONDecoder` | `DICOMWeb` | 11 |
| `dicom-xml` | (default) | `DICOMXMLEncoder` / `DICOMXMLDecoder` | `DICOMWeb` | 8 |
| `dicom-convert` | (default) | `TransferSyntaxConverter` + `DICOMFile` rendering | `DICOMCore` + `DICOMKit` | 1 |
| `dicom-split` | (default) | `FrameSplitter` | `DICOMKit/Splitting` | 0 |
| `dicom-merge` | (default) | `FrameMerger` | `DICOMKit/Merging` | 0 |
| `dicom-study` | summary · check · stats · compare · organize | `StudyScanner` / `StudyReport` / `StudyOrganizer` | `DICOMKit/Study` | 12 |
| `dicom-archive` | init · import · query · list · export · check · stats | `ArchiveStore` | `DICOMKit/Archive` | 0 |
| `dicom-pixedit` | (default) | `PixelEditor` | `DICOMKit/PixelEditing` | 3 |
| `dicom-script` | template · run · validate | `ScriptParser`/`Executor`/`Validator`/`TemplateGenerator` | `DICOMKit/Scripting` | 2 |
| `dicom-image` | single · batch · multipage‑TIFF | `ImageConverter` | `DICOMKit/SecondaryCapture` | 0 |
| `dicom-uid` | generate · validate · lookup · regenerate | `UIDManager` | `DICOMKit/UIDManagement` | 6 |
| `dicom-compress` | info · compress · decompress · batch · backends | `CompressionManager` | `DICOMKit/Compression` | 4 |
| `dicom-export` | single · contact‑sheet · animate · bulk | `DICOMImageExporter` | `DICOMKit/ImageExport` | 0 |
| `dicom-pdf` | extract · encapsulate | `EncapsulatedDocumentParser` / `…Builder` | `DICOMKit` + `DICOMCore` | 0 |
| `dicom-dcmdir` | create · validate · dump · update | `DICOMDirectory` / `DICOMDIRReader` / `…Writer` | `DICOMKit` + `DICOMCore` | 0 |
| `dicom-echo` | (default) | `DICOMVerificationService` | `DICOMNetwork` | 0 |
| `dicom-send` | (default) | `DICOMStorageService` | `DICOMNetwork` | 0 |
| `dicom-query` | (default) | `DICOMQueryService` | `DICOMNetwork` | 0 |
| `dicom-retrieve` | study · series · instance · c‑move · c‑get | `DICOMRetrieveService` | `DICOMNetwork` | 0 |
| `dicom-qr` | query · resume | `DICOMQueryService` / `DICOMRetrieveService` | `DICOMNetwork` | 0 |
| `dicom-mwl` | query · create | `DICOMModalityWorklistService` | `DICOMNetwork` | 0 |
| `dicom-mpps` | create · update | `DICOMMPPSService` | `DICOMNetwork` | 0 |
| `dicom-wado` | WADO‑RS · WADO‑URI · QIDO‑RS · STOW‑RS · UPS‑RS | `DICOMwebClient` / `WADOURIClient` | `DICOMWeb` | 0 |

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
   bytes differ run‑to‑run by design, which is why these tools have no goldens.
6. **App‑only enhancements** — the app exposes capability the CLI doesn't:
   `dicom-mwl create` (REST + HL7), `dicom-query` two‑step SERIES/IMAGE fallback,
   `dicom-retrieve` server‑side Study‑UID auto‑resolution.

Anything **not** in these buckets is a bug. The audit found two and one is fixed:
`dicom-archive --skip-duplicates` (app toggle was ignored → **fixed**, `b418bfc`)
and `dicom-qr` patient‑name case (CLI uppercases the C‑FIND key, app sends as‑is —
documented in the matrix).

---

## 6. How parity is verified

A **Tier‑2 parity harness** drives the app's in‑process reimplementations against
committed CLI "goldens" and asserts byte‑exact output:

- **Goldens:** `Sources/DICOMStudio/Resources/CLIParity/goldens.synthetic.json`
  — 97 scenarios across 14 deterministic tools (tool + subcommand + flags →
  expected stdout/stderr/exit‑code, or the produced DICOM artifact).
- **Driver:** `StudioParityTests.testWave1OutputParity` runs each scenario through
  the app engine and reports `MATCH / DIFFERS / UNAVAILABLE / ERROR`.
- **Gate:** with `PARITY_STRICT=1`, any `DIFFERS` not in
  `parity-allowlist.json` fails CI. The allowlist is currently **empty** — every
  covered scenario is byte‑exact (**MATCH=266, DIFFERS=0**).
- **Regenerate goldens:** `swift run cli-parity-gen`.

**What goldens prove and what they don't.** For file‑producing tools the harness
compares the **produced DICOM artifact** (`artifactKind: dicom`), so a console
message difference (e.g. an app summary line) doesn't fail the gate even though it
exists. Tools with non‑deterministic or network output (§5.5) **cannot** have
stable goldens and are therefore verified by **shared‑engine construction +
smoke tests** rather than the harness. The matrix marks these explicitly.

**Network (DIMSE) tools — live‑PACS parity.** The golden harness can't cover
network output, so the *CLI Parity* screen has a separate **Network mode** that
runs the `dicom-*` binary against a user‑supplied PACS and compares it,
flag‑by‑flag, to a reference that drives the **same DICOMKit package API directly**
(SDK ↔ CLI conformance, timing ignored). `dicom-echo` is covered today. See
[`APP_CLI_NETWORK_PARITY.md`](APP_CLI_NETWORK_PARITY.md).

---

## 7. Reproducing / extending

- **Build everything:** `swift build`
- **Run the parity gate:** `PARITY_STRICT=1 swift test --filter StudioParityTests`
- **Add a tool to the shared model:** lift its engine into `Sources/DICOMKit/<Group>/`,
  make the entry points `public`, strip ArgumentParser/Process/printing (use
  `log:`/`CommandRunner`/return‑strings), add an in‑memory variant if it writes
  files, thin the CLI `main.swift`, repoint `executeDicom<Tool>` at the engine, and
  confirm goldens still MATCH (or smoke‑test if non‑deterministic).

See [`CLI_WORKSHOP_SHARED_API_PLAN.md`](CLI_WORKSHOP_SHARED_API_PLAN.md) for the
full wave‑by‑wave migration log and [`CLI_TOOL_MODULE_CLASSIFICATION.md`](CLI_TOOL_MODULE_CLASSIFICATION.md)
for the per‑tool module classification.
