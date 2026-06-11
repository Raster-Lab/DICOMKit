# App ↔ CLI Network Parity (live PACS)

How the *CLI Parity* screen verifies the **network (DIMSE) tools** against a live
PACS — the part the offline golden harness explicitly can't cover (network output
is non‑deterministic, so it has no stable golden; see
[`APP_CLI_SHARED_API.md`](APP_CLI_SHARED_API.md) §5.5/§6).

> **Status (2026‑06‑11):** `dicom-echo` covered, flag‑wise, against a user‑supplied
> PACS. The pattern is built to extend to `dicom-query` / `send` / `retrieve` / … .

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

Only tools in `CLIParityNetworkScenarios.supportedToolIDs` appear (today:
`dicom-echo`); the rest of the DIMSE tools are listed as "coming soon".

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
| Segmented toggle + endpoint form | `Views/CLIParityRunnerView.swift` |
| Flag‑wise scenarios | `Components/CLIParityNetworkScenarios.swift` |
| SDK reference | `Components/CLIParityNetworkReference.swift` |
| Semantic parse/compare | `Components/CLIParityEchoComparator.swift` |

Tests (`Tests/DICOMStudioTests/`):

- `CLIParityNetworkReferenceTests` — locks the reference‑record ⇄ CLI‑parse
  alignment for every flag combo (single, multi ±verbose, connection error,
  diagnose pass/early‑exit/partial).
- `CLIParityEchoComparatorTests` — the text parser / canonical / compare.
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
