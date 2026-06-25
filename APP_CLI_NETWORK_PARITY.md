# App ↔ CLI Network Parity (live PACS)

How the *CLI Parity* screen verifies the **network (DIMSE) tools** against a live
PACS — the part the offline golden harness explicitly can't cover (network output
is non‑deterministic, so it has no stable golden; see
[`APP_CLI_SHARED_API.md`](APP_CLI_SHARED_API.md) §5.5/§6).

> **Status:** `dicom-echo` (flag‑wise C‑ECHO), `dicom-query` (read‑only C‑FIND,
> result‑set parity), `dicom-send` (C‑STORE outcome parity), `dicom-retrieve`
> (C‑MOVE / C‑GET sub‑operation‑count parity, per level), `dicom-qr` (the integrated
> query‑retrieve tool's read‑only `--review` C‑FIND **plus its `--interactive`
> select‑all retrieve**, matched‑study + retrieve‑outcome parity),
> `dicom-mwl` / `dicom-mpps`, and `dicom-wado` (the **DICOMweb** binary — QIDO‑RS /
> WADO‑RS / STOW‑RS / UPS‑RS, swept as subcommands) are covered against a
> user‑supplied PACS (selectable: DCM4CHEE2 / DCM4CHEE5). The DIMSE tools plus the
> single `dicom-wado` DICOMweb binary are listed in the network picker; the catalog's
> DICOMweb subcommand aliases (`dicom-qido` / `dicom-stow` / `dicom-ups`) are **not**
> separate binaries, so they're collapsed into `dicom-wado` and hidden from the picker.
> The pattern extends to the rest — see
> [`APP_CLI_NETWORK_PARITY_PLAN.md`](APP_CLI_NETWORK_PARITY_PLAN.md).

> **dicom-retrieve — C‑MOVE / C‑GET, on the shared package API.** The reference drives
> `DICOMRetrieveService.move*/get*` — the same calls the CLI's `RetrieveExecutor` makes
> — and reduces the outcome to a timing‑independent `RetrieveSemantics` (method · level ·
> success · completed / failed sub‑operations · received‑file count for C‑GET · warning
> count for C‑MOVE). **Input — user‑supplied:** a Study UID (required) plus optional
> Series / Instance UIDs (which widen the sweep to those levels), a Move Destination AE
> (required only for the C‑MOVE rows; C‑GET needs none and is skipped with guidance when
> a destination is missing), an **output folder** (where the C‑GET files are kept; a
> temporary scratch folder is used and removed when none is chosen), and a **transfer
> syntax** dropdown populated from **`TransferSyntax.allKnown` (DICOMKit)** — every
> DICOMKit‑supported syntax — requested by the C‑GET rows (by UID, which round‑trips
> through the same `TransferSyntax.parse` the CLI/reference use; advisory for C‑MOVE, so
> it isn't passed there). Every scenario passes `--verbose` because dicom-retrieve prints
> its result block only when verbose (or the op failed) — without it a successful
> retrieve emits nothing to parse. C‑MOVE asks the PACS to forward instances to the
> destination AE. Scenarios: c‑get / c‑move at the study level (always shown), and
> c‑get / c‑move at the series / instance levels once the matching UID is supplied.

> **dicom-qr — integrated query‑retrieve: read‑only review + interactive select‑all
> retrieve.** dicom-qr builds its OWN study‑level `QueryKeys` (uppercasing the patient
> name) rather than going through `DICOMQueryService.buildQueryKeys`, so the reference
> (`qrQueryKeys`) replicates that key‑building EXACTLY. The `QRSemantics` record carries
> *matched study count + sorted Study UIDs* (order‑independent) plus an optional
> *retrieval* tally (Total / Success / Failed) for the interactive rows. Two kinds of
> scenario:
>
> - **Review (read‑only).** The query‑half sweep mirrors the dicom-query study matrix
>   (broad query, per‑filter, combined), reusing the shared Query Keys form. Each runs
>   `query … --review --method c-get` so the tool never demands a `--move-dest` it
>   doesn't use, and the reference is `qrReview` (C‑FIND only, no retrieve, no stdin).
> - **Interactive (full query→select→retrieve).** Two rows run `query … --interactive`:
>   the study‑selection prompt is **auto‑answered `all`** — fed to the CLI's stdin
>   (newline‑terminated, via `CLIToolTerminalCompare.run(stdin:)`) and replicated by the
>   reference (`qrInteractive`) — so every matched study is retrieved, once by **C‑GET**
>   (pulls files to a scratch folder) and once by **C‑MOVE** (forwards to the
>   user‑supplied **Move Destination AE**). The reference mirrors dicom-qr's per‑study
>   loop exactly (a missing Study UID counts as a failure; C‑MOVE/C‑GET count as success
>   unless the op throws), so the *retrieval* tally lines up. To avoid moving the whole
>   PACS, the interactive rows are **skipped unless a Query Key bounds the match set**,
>   and C‑MOVE additionally needs the Move Destination AE.

> **dicom-send — C‑STORE, on the shared package API.** The app's in‑app send, the
> `dicom-send` CLI, and the parity reference all call the same
> `DICOMStorageService.store`. Unification fixed a real divergence: the CLI's
> `--verify` was a no‑op stub — it now does a real `DICOMVerificationService.echo`,
> matching the app. **Input — user‑selectable (file OR directory):** the end user may
> pick a **single DICOM file** or a **DICOM directory** to transmit; when left empty the
> parity falls back to the bundled synthetic CT (`syn-ct.dcm`). The path is enumerated
> by the **shared `DICOMSendFileGatherer` (DICOMNetwork)** that the `dicom-send` CLI
> itself uses (a file is taken as‑is; a directory is scanned), so the reference's file
> set can never drift from the binary's (the dry‑run "Found N" and the real‑send counts
> both depend on identical enumeration). Every scenario passes `--recursive` so a picked
> directory is scanned in full (a no‑op for a single file); an empty / non‑DICOM
> directory yields an honest *Skipped* row, not a false result. The parity compares the
> outcome counts (sent / succeeded / failed; success = success‑or‑warning so a
> duplicate‑store warning isn't a false drift). **It WRITES to the server** — the screen
> shows a warning; a `--dry-run` scenario writes nothing. Scenarios: dry-run, default,
> `--priority high`, `--verify`.
>
> **Security‑scope fix (file actually transmitted).** The network run now holds
> security‑scoped access to the picked send file/dir for the whole run — like the
> in‑app Workshop send and the offline corpus branch already do. Previously the network
> branch held no scope, so the reference's `Data(contentsOf:)` (and the forked CLI)
> couldn't read a user‑selected file and silently sent **nothing** — the "works in the
> CLI Workshop but not in CLI Parity" bug. The transfer‑syntax scenario was removed from
> the matrix (the file's own TS is negotiated).

> **dicom-query — unified on the shared package API.** The app's in‑app query, the
> `dicom-query` CLI, **and** the parity reference all call the *same* DICOMNetwork
> code for every stage, so their pipelines cannot drift:
> - **Input:** `DICOMQueryService.buildQueryKeys(level:filters:)` — one PS3.4‑correct
>   filters→`QueryKeys` mapping (study‑level `--modality` → ModalitiesInStudy 0008,0061).
> - **Process:** `DICOMQueryService.find`.
> - **Output:** `DICOMQueryResultFormatter` (table/json/csv/compact).
>
> The app's query is now a thin adapter (no app‑only two‑step/parent‑enrichment, no
> xml/hl7), identical to the CLI. The parity runner reduces both sides to a
> `QuerySemantics` record (level · success · count · matched results as sorted
> `tag=value;…`), compared **order‑independently** (json full attribute parity;
> table/csv/compact validated by result count). Inputs: query‑key fields (patient
> name/ID, study date, modality, accession, study description, study/series UID);
> the matrix sweeps a broad study query, each provided filter individually, the four
> `--format`s, the patient level, and series/instance when the scoping UID(s) are given.

> **dicom-wado — DICOMweb, one binary with four subcommands.** Unlike the DIMSE tools
> (each its own `dicom-*` binary), QIDO‑RS / WADO‑RS / STOW‑RS / UPS‑RS are **subcommands**
> of the single `dicom-wado` binary. The Studio catalog splits them into separate IDs
> (`dicom-qido` / `dicom-stow` / `dicom-ups`) for the Workshop's per‑operation forms, but
> those are not separate binaries — so CLI Parity **collapses them into one `dicom-wado`
> tool** whose argv begins with the subcommand under test (`query` / `retrieve` / `store`
> / `ups`), exactly like dicom-qr's `query` and dicom-mpps's `create`. Both sides drive the
> same **`DICOMwebClient`** (the reference directly, the CLI internally) over a separate
> **DICOMweb Base URL** (HTTP — dcm4chee exposes it under `/dcm4chee-arc/aets/<AET>/rs`;
> pre‑filled per server preset, editable, with an optional bearer token). Coverage:
> - **query (QIDO‑RS, read):** mirrors the dicom-query study sweep — broad query, per‑filter,
>   combined, `--format` csv/table (count) + json (full result‑set parity), and the
>   series / instance levels once the scoping UID(s) are supplied. Reuses the Query Keys form.
> - **retrieve (WADO‑RS, pull):** study (always) + series / instance once their UIDs are set,
>   plus a `--metadata` row. The reference counts pulled instances / metadata objects in
>   memory; the runner counts the `.dcm` files the CLI wrote to a temporary `--output` dir.
> - **store (STOW‑RS, WRITES):** uploads the **Send Source** (a picked file/dir, or the bundled
>   synthetic CT) — the runner expands it via the shared `DICOMSendFileGatherer` into the
>   explicit file list both sides POST. Compares sent / succeeded / failed counts.
> - **ups (UPS‑RS):** `--search` (read‑only, matched‑Workitem‑UID parity) always; a
>   create → claim **lifecycle** (N‑CREATE SCHEDULED → state change IN PROGRESS, WRITES) when a
>   Procedure Step Label is supplied. Each side mints its own Workitem / Transaction UID
>   (never compared) — parity is on the create / claim outcome and final state, like dicom-mpps.
>   (Completion needs server‑specific final‑state attributes, so the lifecycle stops at the claim.)

> **Hang backstop.** A DICOM SCU can block indefinitely if the PACS accepts the TCP
> connection but never answers the DIMSE request — `--timeout` bounds only the
> *connect*, not the post‑connect PDU receives. Each network scenario therefore runs
> under a wall‑clock deadline (`timeout × ops + 60 s`): past it the reference op is
> abandoned and the forked CLI is terminated (then `SIGKILL`‑ed), so one unresponsive
> endpoint yields a *timed‑out* row instead of freezing the whole run. On a healthy
> PACS the deadline never fires (operations finish in well under it).

> ⚠️ **Testing‑only.** Like the rest of the CLI Parity screen, the live‑CLI path
> forks the real `dicom-*` binary and needs the **App Sandbox disabled**. Remove
> before production (project memory `dicom-info-terminal-compare-testonly`).

---

## 1. Why network tools are handled differently

For **offline** tools the parity "reference" is the app's own in‑process
reimplementation (`CLIWorkshopViewModel.executeCommand`), because those methods
already fully mirror each CLI. For **network** tools the app's in‑app execution
(`executeDicomEcho`, …) is an intentionally lighter, UI‑focused path, and we do
**not** want the parity test to bend or depend on that production UI code.

So the network parity test has its **own, self‑contained reference** that drives
the **DICOMKit package API directly** — exactly the way the `dicom-*` CLIs do
internally. The CLI Workshop's network code is never invoked by the parity run.

This makes the network parity an **SDK ↔ CLI conformance** test:

```
        dicom-echo binary  ─┐
                            ├─ both call DICOMVerificationService.echo (DICOMNetwork)
   CLIParityNetworkReference ┘
```

It answers *"is the `dicom-echo` binary a faithful, regression‑free wrapper over
the DICOMKit package API?"* — **not** *"does the app's echo screen match the CLI?"*
(That's deliberate: the app UI is decoupled.)

---

## 2. The CLI Parity screen — Network mode

A segmented **Offline / Network** toggle (`ParityMode`) switches the screen's tool
pool, controls and runner.

- **Offline** — unchanged: file tools swept against bundled/corpus fixtures.
- **Network** — an editable **PACS Endpoint** card plus the network tool list.

The endpoint card exposes **only the connection credentials** — the test flags are
**never** shown as controls; they're applied internally by the flag‑wise matrix:

| Field | Default | Maps to |
|---|---|---|
| Host | `172.17.1.200` | positional `host` |
| Port | `11112` | `--port` |
| Calling AE | `DICOMSTUDIO` | `--aet` (required by the CLI) |
| Called AE | `TEAMPACS` | `--called-aet` |
| Timeout (s) | `30` | `--timeout` |

The DIMSE tools plus the single `dicom-wado` DICOMweb binary are listed. Tools in
`CLIParityNetworkScenarios.supportedToolIDs` (`dicom-echo`, `dicom-query`,
`dicom-send`, `dicom-retrieve`, `dicom-qr`, `dicom-mwl`, `dicom-mpps`, `dicom-wado`)
are selectable and run; any without a parity reference yet show a greyed *coming
soon* badge and can't be selected. The catalog's DICOMweb subcommand **aliases**
(`dicom-qido` / `dicom-stow` / `dicom-ups`) are hidden — they're `dicom-wado query` /
`store` / `ups`, not separate binaries (only `dicom-wado` has a build product), so the
runner collapses them into the one `dicom-wado` tool. A per‑tool input card appears
for the selected tool(s): the Query Keys form (dicom-query / dicom-qr / dicom-wado
QIDO‑RS), the **Query‑Retrieve Scope** card (dicom-qr — Move Destination AE for the
interactive C‑MOVE), the Send Source picker (dicom-send / dicom-wado STOW‑RS), the
Retrieve Scope form (dicom-retrieve), and the **DICOMweb Endpoint** card (dicom-wado —
base URL, bearer token, WADO‑RS instance UID, and the UPS‑RS lifecycle inputs).

> **dicom-mpps is pinned to one server.** Performed‑procedure‑step state (N‑CREATE →
> N‑SET) is only accepted and advanced by the **DCM4CHEE5 MWL** worklist AE
> (`172.17.1.111` · `WORKLIST`), so selecting `dicom-mpps` **locks the server picker**
> to that preset (auto‑applying its endpoint); the `run()` guard rejects any other
> server. The pin is data‑driven (`toolRequiredServer`), so other tools could be pinned
> the same way. Its **MPPS Scope** card drives the full create → update lifecycle: the
> N‑CREATE starts the step `IN PROGRESS`, then the N‑SET (`dicom-mpps update --mpps-uid
> <UID>`) transitions it to `COMPLETED` / `DISCONTINUED` using the SOP Instance UID each
> side minted from its own create (never compared — parity is on the create/update
> outcome, final status and referenced‑image count).

---

## 3. The flag‑wise scenario matrix

`CLIParityNetworkScenarios` generates one scenario per valid `dicom-echo` flag (and
the meaningful combinations) — the end user supplies only credentials:

| Scenario | Effective `dicom-echo` args (beyond host/AE) |
|---|---|
| echo (default) | — |
| echo --timeout | `--timeout <t>` |
| echo --verbose | `--verbose` |
| echo --count 3 | `--count 3` |
| echo --count 3 --stats | `--count 3 --stats` |
| echo --stats | `--stats` |
| echo --count 3 --verbose | `--count 3 --verbose` |
| echo --diagnose | `--diagnose` |

---

## 4. Reference side — `CLIParityNetworkReference`

`Sources/DICOMStudio/Components/CLIParityNetworkReference.swift` drives the package
API and builds a **timing‑independent semantic record** (`EchoSemantics`) directly
from the results — no text rendering.

- `echo(host:port:callingAET:calledAET:timeout:count:verbose:diagnose:)` — loops
  `DICOMVerificationService.echo` for `--count`, or runs the 3‑test `--diagnose`
  flow, then delegates to a **pure, testable** record builder.
- `echoRecord(_:verbose:)` / `diagnoseRecord(...)` — pure functions that replicate
  the CLI's **output gating** so the structured record equals what `parse()`
  extracts from the CLI text:
  - per‑echo Status/Remote‑AE shown only for `--verbose` or a single echo;
  - a DIMSE failure always carries its Status; a thrown error carries neither;
  - `--diagnose` early‑exits (no stability/result) when basic connectivity throws.

The record:

| Field | Echo mode | Diagnose mode |
|---|---|---|
| `mode` | `"echo"` | `"diagnose"` |
| `sent` / `succeeded` / `failed` | counts | — |
| `statusCodes` | distinct DIMSE codes (e.g. `0x0000`) | — |
| `remoteAEs` | distinct remote AE titles | — |
| `diagBasicOK` / `diagStability` / `diagResult` | — | basic pass · `x/5` · `PASSED`/`PARTIAL`/`FAILED` |

Round‑trip time and stats are **never** part of the record (volatile by design).

---

## 5. CLI side & comparison

- **CLI side:** the real `dicom-echo` binary is forked via `CLIToolTerminalCompare`
  (stdout **and** stderr captured — `dicom-echo` prints to stderr), then
  `CLIParityEchoComparator.parse(...)` reduces the text to the same `EchoSemantics`.
- **Compare:** `CLIParityEchoComparator.compare(reference:cli:)` diffs the canonical
  rendering of the two records.

### Row verdicts

| Status | Meaning |
|---|---|
| **Pass** | CLI matches the package‑API reference (success/failure, DIMSE status, remote AE). |
| **Output Drift** | Both ran but the records differ — the CLI diverged from the SDK. |
| **App Error** | Reference and CLI disagree on overall success/failure (process divergence). |
| **Both Failed** | Both failed *identically* (e.g. server unreachable / AE rejected). Parity held on the failure path but no successful C‑ECHO occurred — **excluded from the score** so a down server can't inflate the rate. |
| **CLI Error** | The `dicom-echo` binary could not launch. |

The success denominator excludes **Skipped**, **Non‑deterministic** and **Both
Failed** rows. A green board therefore means *the CLI matches the SDK reference*
— it does **not** by itself prove the PACS is reachable (watch the *Both Failed*
count for that).

---

## 6. What this run does **not** touch

- **`executeDicomEcho` (CLI Workshop)** is **not** used by the parity run. It was,
  however, independently extended to honor `--count` / `--stats` / `--verbose` /
  `--diagnose` (those catalog params previously did nothing in the Workshop) — a
  standalone Workshop improvement, not a parity dependency.

---

## 7. Related offline‑harness fix

While exercising the offline tools, image‑artifact scenarios whose tool produced
no file (e.g. `dicom-export bulk` fed a single file when it needs a directory)
made ImageIO log noisy `IIOImageSource … can't open … (fileExists == false)` lines.
Fixed in two places:

- `CLIParityEngine.imageRasterHash` now returns `nil` for a missing path or a
  directory instead of handing it to `CGImageSourceCreateWithURL`.
- `CLIParityRunnerViewModel.runScenario` now **skips** any artifact scenario whose
  reference CLI produced no artifact (nothing to compare) rather than hashing a
  non‑existent path — an honest *Skipped* instead of a false pass. A genuine
  app‑side miss (CLI wrote the artifact, app didn't) still surfaces as drift.

---

## 8. Files & tests

| Concern | File |
|---|---|
| Screen mode enum | `Models/CLIParityRunnerModel.swift` (`ParityMode`, `BatchRowStatus.failureAgreement`) |
| Endpoint state + network runner | `ViewModels/CLIParityRunnerViewModel.swift` (`runNetworkScenario`) |
| Segmented toggle + per‑tool input forms | `Views/CLIParityRunnerView.swift` |
| Flag/level scenarios (all tools) | `Components/CLIParityNetworkScenarios.swift` |
| SDK reference (echo/query/send/retrieve/qr/mwl/mpps/wado) | `Components/CLIParityNetworkReference.swift` |
| Semantic parse/compare — echo | `Components/CLIParityEchoComparator.swift` |
| Semantic parse/compare — query | `Components/CLIParityQueryComparator.swift` |
| Semantic parse/compare — send | `Components/CLIParitySendComparator.swift` |
| Semantic parse/compare — retrieve | `Components/CLIParityRetrieveComparator.swift` |
| Semantic parse/compare — qr review + interactive retrieve | `Components/CLIParityQRComparator.swift` |
| Semantic parse/compare — mwl / mpps | `Components/CLIParityMWLComparator.swift` · `Components/CLIParityMPPSComparator.swift` |
| Semantic parse/compare — wado (QIDO/WADO/STOW/UPS) | `Components/CLIParityWADOComparator.swift` |

Tests (`Tests/DICOMStudioTests/`):

- `CLIParityNetworkReferenceTests` — locks the reference‑record ⇄ CLI‑parse
  alignment for every flag combo (single, multi ±verbose, connection error,
  diagnose pass/early‑exit/partial).
- `CLIParityEchoComparatorTests` — the text parser / canonical / compare.
- `CLIParityQueryParityTests` / `CLIParitySendParityTests` — query result‑set /
  send outcome parse + scenario matrix.
- `CLIParityRetrieveParityTests` — C‑MOVE / C‑GET summary parse (progress lines not
  mistaken for the summary), count/file/success drift, and the method/level matrix.
- `CLIParityQRParityTests` — `--review` "Found N" + Study‑UID parse, the `--interactive`
  "Retrieval Summary" (Total / Success / Failed) parse, order‑independent match (incl.
  the retrieve tally), and both the read‑only `--review --method c-get` and the
  `--interactive` select‑all C‑GET / C‑MOVE scenario matrices.
- `CLIParityMWLParityTests` / `CLIParityMPPSParityTests` — worklist item‑set parse and
  the MPPS create/update lifecycle parse + matrix.
- `CLIParityWADOParityTests` — QIDO‑RS query JSON / csv / table reduction, WADO‑RS
  metadata + retrieve count compare, STOW‑RS summary parse, UPS‑RS search + create/claim
  parse, and the four‑subcommand scenario matrix (subcommand‑prefixed argv, gated rows).
- `CLIParityArtifactReductionTests` — the `imageRasterHash` missing/dir guard.

---

## 9. Extending to other network tools

1. Add the tool id to `CLIParityNetworkScenarios.supportedToolIDs` and a scenario
   builder for its flags.
2. Add a reference function in `CLIParityNetworkReference` that drives the tool's
   package API (`DICOMQueryService`, `DICOMStorageService`, `DICOMRetrieveService`, …)
   and builds a structured record.
3. Add a comparator (or reuse the echo one if the record shape fits) and wire it in
   `runNetworkScenario`.

The UI (segmented toggle, endpoint form, badge, scoring) needs no change.
