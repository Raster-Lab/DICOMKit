# dicom-ups

_CLI binary:_ `dicom-wado` · _subcommand:_ `ups` · _category:_ NETWORK_OPERATIONS · _wired in Studio:_ yes · _network:_ yes

**Input-contract parity:** 23/35 CLI flags matched · 12 missing in UI · status **INCOMPLETE** (66%)

**Output behavior:** no golden scenarios yet (offline output not exercised; e.g. network tool or not-yet-templated).

## Verified App↔CLI parity

- **Shared DICOMKit engine:** `DICOMwebClient (UPS-RS)` (`DICOMWeb`) — both the CLI and DICOMStudio call it (all logic shared); flags with no golden still produce identical output **by construction**.
- **Verdict:** create/retrieve/search/subscribe via the shared client; change-state echoes the raw HTTP request/response (educational). Live network → no goldens.

> Full per-subcommand/flag detail: [`APP_CLI_PARITY_MATRIX.md`](../../APP_CLI_PARITY_MATRIX.md) · architecture: [`APP_CLI_SHARED_API.md`](../../APP_CLI_SHARED_API.md).

## Flags

| Flag | Kind | Input (UI ↔ CLI) | Type/Default | Output (UI vs CLI) |
|---|---|---|---|---|
| `--accession-number` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--admission-id` | option | ⚠️ missing in UI | — | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--aet` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--comments` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--create` | option | ⚠️ missing in UI | — | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--create-workitem` | flag | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--expected-completion` | option | ⚠️ missing in UI | — | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--filter-state` | option | ⚠️ missing in UI | — | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--format` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--get` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--label` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--patient-birth-date` | option | ⚠️ missing in UI | — | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--patient-id` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--patient-name` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--patient-sex` | option | ⚠️ missing in UI | — | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--performer-name` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--performer-organization` | option | ⚠️ missing in UI | — | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--priority` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--procedure-id` | option | ⚠️ missing in UI | — | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--referring-physician` | option | ⚠️ missing in UI | — | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--scheduled-start` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--scheduled-station` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--search` | flag | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--state` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--station-name` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--step-id` | option | ⚠️ missing in UI | — | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--study-uid` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--subscribe` | flag | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--token` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--transaction-uid` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--unsubscribe` | flag | ⚠️ missing in UI | — | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--update` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--verbose` | flag | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--workitem-uid` | option | ✅ match | ✓ | ⊘ not covered (network — needs a live PACS/DICOMweb server) |
| `--worklist-label` | option | ⚠️ missing in UI | — | ⊘ not covered (network — needs a live PACS/DICOMweb server) |

---
_Legend — Input:_ ✅ match · ⚠️ missing in UI · ➕ extra in UI (drift). _Output:_ ✅ success · ❌ drift · ⊘ not covered *(reason: network · non-deterministic · coverage gap · no-write preview)* · — not wired. The **Verified App↔CLI parity** block above is the durable verdict for ALL flags (incl. uncovered). Generated by `swift run cli-parity-docs` (in-process, from bundled contracts + goldens)._
