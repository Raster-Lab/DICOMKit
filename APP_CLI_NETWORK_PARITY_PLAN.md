# CLI Parity (UI) for Network Tools — Implementation Plan

Plan to extend the *CLI Parity* screen's **Network mode** from `dicom-echo` to the
rest of the DIMSE + DICOMweb tools. Companion to the shipped architecture doc
[`APP_CLI_NETWORK_PARITY.md`](APP_CLI_NETWORK_PARITY.md) and the offline harness
docs ([`APP_CLI_SHARED_API.md`](APP_CLI_SHARED_API.md),
[`Scripts/CLI-PARITY-TIER2-PLAN.md`](Scripts/CLI-PARITY-TIER2-PLAN.md)).

> ⚠️ Testing‑only feature (forks the real binaries; App Sandbox must be disabled).

---

## 0. TL;DR

- **Shipped:** `dicom-echo`, flag‑wise, via a self‑contained **SDK reference**
  (`CLIParityNetworkReference` → `DICOMVerificationService.echo`) compared to the
  forked CLI binary, semantically (timing masked). The CLI Workshop's network UI
  code is *not* touched.
- **This plan:** add `dicom-query`, `dicom-send`, `dicom-retrieve`, `dicom-qr`,
  `dicom-mwl`, `dicom-mpps` (DIMSE) and `dicom-wado` (DICOMweb, incl. the
  `query`/`store`/`ups` subcommands) using the **same** reference‑vs‑CLI pattern.
- **Three new problems** echo didn't have: (1) **inputs beyond the endpoint**
  (files, query keys, UIDs, a destination AE); (2) **side effects** — `send`,
  `mpps`, and DICOMweb `store`/`ups` *write to the server*; (3) **non‑determinism**
  — `query`/`mwl`/`retrieve` results depend on server contents.
- **Key decision to make:** for stateful/destructive tools, run against a
  **loopback PACS** (the repo's `dicom-server`, seeded with bundled synthetic
  instances) for a deterministic, side‑effect‑free test — and keep the external
  PACS (TEAMPACS) for read‑only tools / opt‑in destructive runs.
- **Out of scope:** no standalone `dicom-qido`/`dicom-stow`/`dicom-ups` binaries
  exist to fork — they're covered as `dicom-wado` subcommands or not at all.

---

## 1. The established pattern (echo) — what we reuse verbatim

Per tool we add four things; the screen, scoring, and runner skeleton already exist.

| Layer | Echo today | Reuse |
|---|---|---|
| Scenario matrix | `CLIParityNetworkScenarios.echoScenarios()` | one builder per tool |
| Reference (drives package API) | `CLIParityNetworkReference.echo()` → `EchoSemantics` | one reference fn per tool |
| Comparator | `CLIParityEchoComparator` (parse CLI text → record; canonical diff) | one record + parser per tool |
| Runner routing | `runNetworkScenario` (reference vs forked CLI, semantic compare) | dispatch by `toolId` |

Unchanged: the **segmented Offline/Network toggle**, the editable endpoint card,
the per‑row verdicts (`Pass` / `Output Drift` / `App Error` / **Both Failed**
(excluded) / `CLI Error`), and the "exclude non‑deterministic & both‑failed from
the score" rule.

---

## 2. Why the other tools are harder — the three new problems

### 2.1 Inputs beyond the endpoint
Echo needs only credentials. The others need *content*:

| Tool | Extra input |
|---|---|
| query, mwl | query keys (patient name, study date, modality, UIDs, accession, level) |
| send | **DICOM file(s)** to transmit + called‑AE + priority/transfer‑syntax |
| retrieve, qr | study/series/SOP **UID(s)** + method (`c-move`/`c-get`) + **move‑dest AE** (C‑MOVE) or output dir (C‑GET) |
| mpps | study UID + status + scheduled‑step ID (create); MPPS UID + new status (update) |
| wado | DICOMweb **base URL** + study/series/instance UIDs (+ token) |

The echo screen shows "only PACS credentials". For these tools the matrix must
supply the content **internally** from **bundled synthetic fixtures** and a
**seeded study UID** — the user still supplies only the endpoint.

### 2.2 Side effects (the big one)
`dicom-send` (C‑STORE), `dicom-mpps` (N‑CREATE/N‑SET), and DICOMweb `store`/`ups`
**mutate the server** — instances/worklist‑state persist with no rollback. Running
these against the team's live TEAMPACS pollutes it. `dicom-retrieve --method c-move`
additionally needs a **listening destination SCP**; `c-get` writes files locally.

### 2.3 Non‑determinism
`query`/`mwl`/`retrieve` results depend on **what's on the server right now** —
match counts, generated UIDs, timestamps. A fixed golden is impossible (this is
exactly the floor §5.5 of `APP_CLI_SHARED_API.md` calls out). The record must
compare **stable semantics** (did it succeed, the result *shape*, DIMSE status,
masked counts/UIDs) — never raw counts/values against the live server.

---

## 3. Locked design decisions

1. **Reference drives the package API directly** (never the CLI Workshop's
   `executeDicom*`). SDK ↔ CLI conformance, decoupled from the app UI — as shipped
   for echo.
2. **Structured record, volatile masked.** Each tool gets a small `…Semantics`
   record built directly on the reference side and parsed from text on the CLI
   side; round‑trip time, fresh UIDs, timestamps and (where server‑dependent)
   counts are excluded — extend `maskUIDs`/`maskVolatileDumpTags` semantics.
3. **Determinism via a loopback PACS for stateful tools (recommended).** Spin up
   the repo's `dicom-server` on `127.0.0.1` as a subprocess, **seed** it with
   bundled synthetic instances, run query/send/retrieve/mpps against it, tear it
   down. Deterministic, side‑effect‑free, CI‑capable. External PACS remains an
   option for read‑only tools and explicit opt‑in destructive runs.
4. **Read‑only before write.** Ship query/mwl/wado‑retrieve (no mutation) first;
   gate send/mpps/store/ups behind an explicit **"allow write operations"** opt‑in
   plus a dedicated test AE/data namespace.
5. **No new dependency on goldens.** Network scenarios stay code‑generated, like
   echo; the loopback‑PACS seed data is the only fixture.

---

## 4. Architecture changes

### 4.1 Endpoint config — two transports
`CLIParityRunnerViewModel` gains a DICOMweb endpoint alongside the DIMSE one:

- **DIMSE** (existing): host, port, calling AE, called AE, timeout.
- **DICOMweb** (new): base URL, bearer token (optional). Shown only when a
  DICOMweb tool (`dicom-wado`) is selected.
- **Loopback toggle** (new, recommended default for stateful tools): "Run against
  a built‑in server seeded with synthetic data" vs "Use the endpoint above".

### 4.2 Per‑tool record + reference + parser
Add, mirroring echo:
- `CLIParityNetworkReference.query(...) -> QuerySemantics`, `.send(...)`,
  `.retrieve(...)`, `.mwl(...)`, `.mpps(...)`, `.wado(...)` — each driving the
  package service (`DICOMQueryService`, `DICOMStorageService`,
  `DICOMRetrieveService`, `DICOMModalityWorklistService`, `DICOMMPPSService`,
  `DICOMwebClient`) and building a structured record with the CLI's output gating
  replicated.
- A parser + canonical per record (echo's comparator generalizes; consider a
  small `NetworkSemantics` protocol so `runNetworkScenario` stays uniform).

### 4.3 Runner routing
`runNetworkScenario` switches on `s.toolId` to pick the reference fn + parser, then
runs the same reference‑vs‑CLI semantic compare and verdict logic already in place.

### 4.4 Loopback PACS harness (new component)
`CLIParityLoopbackPACS` (testing‑only): start `dicom-server` on a free port, seed
via `DICOMStorageService.store` of bundled synthetic instances, expose host/port/AE,
and stop on teardown. Used when the loopback toggle is on.

---

## 5. Per‑tool plan

> Legend: **RO** read‑only · **W** writes to server · **L** writes local files.

### 5.1 `dicom-query` — C‑FIND (RO) — Wave 1
- **Package API:** `DICOMQueryService.find(host:port:configuration:queryKeys:) async throws -> [GenericQueryResult]`.
- **Inputs (internal):** level (`patient/study/series/instance`), query keys
  (patient‑name, patient‑id, study‑date, modality, study/series UID, accession,
  study‑description, referring‑physician), output format (`table/json/csv/compact`).
- **Record (`QuerySemantics`):** level, active‑filter set, success/exit, DIMSE
  status, `resultCount` **(masked vs live server; exact only on loopback)**,
  per‑result **field presence** (which tags returned, not values).
- **Scenarios:** default study‑level; each level; each filter; each `--format`;
  empty‑result filter; verbose.
- **Non‑det:** result count/UIDs/dates → compare field *shape* live, exact counts
  only on loopback. **No side effects.**

### 5.2 `dicom-mwl` — C‑FIND on MWL (RO) — Wave 1
- **Package API:** `DICOMModalityWorklistService.find(host:port:callingAE:calledAE:matching:timeout:) async throws -> [WorklistItem]`.
- **Inputs:** date/range, station, patient, patient‑id, modality, sps‑status,
  accession, `--json`.
- **Record (`WorklistSemantics`):** success/exit, status, `itemCount` (masked
  live / exact on loopback), unique sets of {patient‑id, accession, modality,
  sps‑status} to confirm filters honored, output format valid‑JSON check.
- **Note:** CLI is query‑only (RO). The app's MWL *create* path (REST/HL7) is
  out of scope for CLI parity (no CLI counterpart).

### 5.3 `dicom-wado` — DICOMweb WADO‑RS/URI (RO for retrieve/query) — Wave 1
- **Package API:** `DICOMwebClient.retrieveStudy/Series/Instance/Frames/…Metadata/Rendered/Thumbnail`; `WADOURIClient.retrieve`.
- **Inputs:** **base URL** + study/series/instance UIDs, `--frames`, `--metadata`,
  `--rendered`, `--thumbnail`, `--uri`, `--content-type`, `--format`, token.
- **Record (`WebRetrieveSemantics`):** instanceCount, total bytes (bucketed/masked),
  SOP class set, metadata JSON **key structure** (VR types, ignore timestamp
  values), frame count, HTTP outcome.
- **Subcommands:** `dicom-wado query` (QIDO, RO), `store` (STOW, **W**), `ups`
  (**W**) ride the same binary — schedule `query` in Wave 1, `store`/`ups` in
  Wave 3 (write). There is **no** `dicom-qido`/`stow`/`ups` binary to fork.

### 5.4 `dicom-send` — C‑STORE (**W**) — Wave 2 (loopback) / opt‑in (external)
- **Package API:** `DICOMStorageService.store(fileData:[preferredTransferSyntaxUID:]to:port:callingAE:calledAE:priority:timeout:) async throws -> StoreResult` (`success`, `status`, `affectedSOPClassUID/InstanceUID`, `roundTripTime`, `remoteAETitle`).
- **Inputs:** **bundled synthetic .dcm files**, called‑aet, `--priority`,
  `--transfer-syntax`, `--retry`, `--verify`, `--recursive`, `--dry-run`.
- **Record (`StoreSemantics`):** fileCount, success/failure/warning counts,
  per‑file DIMSE status, affected SOP **class** set (UIDs are file‑deterministic),
  `allSucceeded`. Mask RTT/throughput. (`--dry-run` → "no transfer" record on both
  sides — a clean non‑mutating scenario worth shipping first.)
- **Side effects:** instances persist. **Run on loopback PACS** (seed target),
  or external only behind opt‑in with a dedicated test AE; document no auto‑cleanup.

### 5.5 `dicom-retrieve` — C‑MOVE / C‑GET (**W**/**L**) — Wave 2 (loopback)
- **Package API:** `DICOMRetrieveService.moveStudy(...) -> RetrieveResult`;
  `getStudy(...) -> AsyncStream<GetEvent>`.
- **Inputs:** study/series/sop UID (from the **seeded** study), `--method`,
  `--move-dest` (C‑MOVE), `--output` (C‑GET), `--transfer-syntax`, `--hierarchical`.
- **Record (`RetrieveSemantics`):** method, success/exit, status, sub‑operations
  completed/failed/warning, files‑received count (C‑GET). Mask UIDs, paths, bytes.
- **Side effects:** C‑MOVE needs a **listening dest SCP** (use the embedded
  `DICOMStorageServer` as the move target); C‑GET writes to a temp dir (cleaned
  up). Strongly prefers loopback (seed → retrieve the known study).

### 5.6 `dicom-qr` — C‑FIND + C‑MOVE/C‑GET (RO in `--review`, else **W**/**L**) — Wave 2
- Composition of query + retrieve. **Ship `--review` (query‑only) first** (RO),
  then `--auto` C‑GET/C‑MOVE on loopback. **Never `--interactive`** (needs stdin).
- **Record:** query part (`QuerySemantics`) + retrieval part (`RetrieveSemantics`).

### 5.7 `dicom-mpps` — N‑CREATE / N‑SET (**W**, stateful) — Wave 3 (loopback/opt‑in)
- **Subcommands:** `create` (N‑CREATE), `update` (N‑SET) via `DICOMMPPSService`.
- **Inputs:** study UID, patient, status, sps‑id, accession (create); MPPS UID,
  new status, image refs (update — needs the UID returned by create).
- **Record (`MPPSSemantics`):** operation, success/exit, status, returned MPPS
  **UID presence** (value masked/threaded create→update). Two‑step (create then
  update) → run as a small stateful sequence on loopback.
- **Side effects:** writes workflow state. Loopback (`dicom-server` MPPS) or
  explicit opt‑in.

---

## 6. Rollout waves (each ships independently)

| Wave | Tools | Risk | Endpoint |
|---|---|---|---|
| **1 — Read‑only** | query, mwl, wado‑retrieve (+wado `query`/QIDO) | none (no mutation) | external (TEAMPACS) or loopback |
| **2 — Retrieve/seeded** | retrieve, qr (`--review` then `--auto`), send `--dry-run` | local writes / needs seeded data | **loopback PACS** |
| **3 — Write/stateful** | send (real C‑STORE), mpps, wado `store`/`ups` | **mutates server** | **loopback** default; external = opt‑in |

Each wave = add the tool id to `supportedToolIDs` + a scenario builder + reference
fn + parser; the UI/scoring need no change beyond the endpoint/loopback controls
(built once in Wave 1–2).

---

## 7. Safety / guardrails

- **Loopback PACS by default** for Wave 2–3 → zero external side effects.
- **External writes are opt‑in:** a checkbox "Allow write operations against the
  external PACS (C‑STORE/MPPS/STOW)" defaulting **off**; write scenarios are
  skipped (clearly, not silently) when off and the endpoint is external.
- **Dedicated test identity:** a distinct calling AE (e.g. `DICOMKIT-PARITY`) and
  synthetic patient namespace (`PARITY^TEST`, IDs `PARITY-*`) so any external
  writes are isolated and findable.
- **No silent truncation:** every skipped write scenario logs *why* (matches the
  existing "loud skip" rule).
- **Cleanup:** loopback server + C‑GET output dirs are temp and torn down per run;
  external C‑STORE is documented as **not** auto‑cleaned.

---

## 8. UI changes (small, built in Wave 1)

- DICOMweb endpoint fields (base URL, token), shown when a DICOMweb tool is selected.
- "Run against built‑in seeded server (loopback)" toggle.
- "Allow external write operations" opt‑in (off by default).
- Network tool list grows as `supportedToolIDs` does (badge + grid already handle it).
- Still **no per‑flag controls** — flags stay internal to the matrix (the echo rule).

---

## 9. Testing strategy

- **Pure record builders** (like `echoRecord`/`diagnoseRecord`): each tool's
  record built from a lightweight outcome type → unit‑testable without a server,
  locking the **reference‑record ⇄ CLI‑parse** alignment per flag combo.
- **Loopback integration smoke test:** seed `dicom-server`, run query/send/retrieve
  end‑to‑end, assert parity — runnable in CI (no external PACS).
- Reuse `CLIParityNetworkReferenceTests` style; add one test file per tool.

---

## 10. File‑change index

| Change | File |
|---|---|
| Records + reference fns | `Components/CLIParityNetworkReference.swift` (extend) |
| Parsers + canonical/compare per record | `Components/CLIParityEchoComparator.swift` → generalize, or `CLIParityNetworkComparators.swift` |
| Scenario builders per tool + `supportedToolIDs` | `Components/CLIParityNetworkScenarios.swift` |
| Loopback PACS harness | `Components/CLIParityLoopbackPACS.swift` (new) |
| Endpoint state (DICOMweb + loopback + write opt‑in), runner routing | `ViewModels/CLIParityRunnerViewModel.swift` |
| Endpoint/loopback/opt‑in controls | `Views/CLIParityRunnerView.swift` |
| Synthetic seed instances | `Resources/CLIParity/synthetic/` (reuse `syn-ct`, `syn-studyset`) |
| Tests | `Tests/DICOMStudioTests/CLIParity*Tests.swift` (one per tool) |
| Docs | update `APP_CLI_NETWORK_PARITY.md` per wave |

---

## 11. Open questions (decide before Wave 2)

1. **Loopback vs external for stateful tools** — adopt the `dicom-server` loopback
   harness (recommended), or restrict to external‑with‑opt‑in only?
2. **Seed data** — reuse `syn-studyset`/`syn-ct`, or mint a dedicated parity study
   with fixed UIDs (better determinism for query/retrieve)?
3. **C‑MOVE destination** — use the embedded `DICOMStorageServer` as the move
   target, or require the user to configure one?
4. **DICOMweb base URL** — does TEAMPACS expose a DICOMweb endpoint, or is wado
   loopback‑only for now?
5. **Scope of `qr`/`wado` subcommands** — cover `resume` / `ups` now or defer?

---

## 12. Out of scope

- `dicom-qido` / `dicom-stow` / `dicom-ups` as standalone tools — **no CLI binary
  exists** to fork; they're reachable only as `dicom-wado` subcommands.
- MWL *create*, and any app‑only network enhancement with no CLI counterpart
  (§5.6 of `APP_CLI_SHARED_API.md`).
- Interactive modes (`dicom-qr --interactive`) — need stdin; not automatable.
