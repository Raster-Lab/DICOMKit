# DICOMKit CLI Parity Harness

Automatically compares the **DICOMStudio "CLI Tools Workshop"** view of each
command against the **real `dicom-*` CLI binaries**, and writes a colour-coded
Excel report of every mismatch — so you stop hand-checking input/output in a
terminal.

## Why this exists

DICOMStudio does **not** shell out to the `dicom-*` binaries. Instead it keeps
two independent, hand-maintained definitions per tool that must track the real
CLI by hand:

1. **Input contract** — `ToolCatalogHelpers.allTools()` /
   `parameterDefinitions(for:)` in
   `Sources/DICOMStudio/Components/CLIWorkshopHelpers.swift` declare each tool's
   flags; `CommandBuilderHelpers.buildCommand()` turns them into the preview.
2. **Output** — `CLIWorkshopViewModel.executeCommand()` re-implements each
   command against the DICOMCore/DICOMKit libraries and formats its own console
   text (only ~18 of the catalog tools are wired up).

Both drift silently from the real swift-argument-parser commands. This harness
catches that drift mechanically.

## What it checks

**Tier 1 — input-contract parity (implemented).** For every CLI command:

- **Real side:** `<binary> --experimental-dump-help` → swift-argument-parser
  `ToolInfoV0` JSON (the authoritative list of arguments/options/flags).
- **Studio side:** `studio-cli-introspect` (a dev-only executable target) dumps
  the live `ToolCatalogHelpers` catalog to JSON.
- Joins by command name (`dicom-wado query` → binary `dicom-wado`, subcommand
  `query`) and diffs the flag sets, defaults, and tool coverage.

**Tier 2 — output parity (not yet implemented; see roadmap).**

## Usage

```bash
# Full run: build, dump both sides, generate report.
Scripts/cli-parity.sh

# Reuse existing .build binaries (fast iteration).
SKIP_BUILD=1 Scripts/cli-parity.sh

# Open the report when done (macOS).
OPEN=1 Scripts/cli-parity.sh
```

Output: `build/cli-parity/cli-parity-report.xlsx`
(intermediates: `build/cli-parity/cli/<binary>.json`,
`build/cli-parity/studio-catalog.json`).

The script creates a throwaway venv at `.venv-cli-parity/` for `openpyxl`.

## The report (4 sheets)

| Sheet | Contents |
|-------|----------|
| **Summary** | One row per Studio tool + every CLI-only binary: flag counts, parity %, and overall status. |
| **Input Parity** | One row per `(tool, flag)`: in CLI? in Studio? defaults, help text, MATCH/mismatch status. Auto-filtered. |
| **Tool Coverage** | One row per CLI binary: has a Studio catalog entry? does `executeCommand()` support it? |
| **About** | Status legend + caveats. |

### Status meanings

- `OK` — Studio flags exactly match the CLI's accepted flags.
- `DRIFT` *(red)* — Studio declares a flag the CLI **rejects** → the generated
  command would fail. Fix first.
- `INCOMPLETE` *(amber)* — Studio is missing flags the CLI accepts.
- `NO_PARAMS_DEFINED` — catalog entry exists but no parameters wired up.
- `MISSING_TOOL` *(red)* — CLI binary has no Studio entry at all.

## Components

| File | Role |
|------|------|
| `Sources/studio-cli-introspect/main.swift` | Dev executable; dumps Studio catalog to JSON. |
| `Scripts/cli-parity.sh` | Orchestrator (build → dump → report). |
| `Scripts/cli_parity_report.py` | Parser + Excel writer (needs `openpyxl`). |

`studio-cli-introspect` is a `.executableTarget` in `Package.swift`. It is a
developer tool and is **not** bundled in DICOMStudio.app.

## CI

Add to a workflow (`.github/workflows/dicom-studio-ci.yml`) to fail on new
drift, e.g.:

```yaml
- name: CLI parity
  run: Scripts/cli-parity.sh
- uses: actions/upload-artifact@v4
  with:
    name: cli-parity-report
    path: build/cli-parity/cli-parity-report.xlsx
```

(You can make it gate by having `cli_parity_report.py` exit non-zero when any
`DRIFT` rows exist — currently it always exits 0 and just reports.)

## Roadmap — Tier 2 (output parity)

For local-file tools (info, dump, tags, diff, convert, validate, anon):

1. Run the real binary on fixture `.dcm` files across a parameter matrix
   (`--format text|json|csv`, etc.); capture stdout/exit code.
2. Drive `CLIWorkshopViewModel.executeCommand()` headlessly from a `@MainActor`
   test (inject plain file URLs in place of `securityScopedURLs`); read
   `consoleOutput`.
3. Normalise both (strip the `$ cmd` echo + status emoji `✅❌⚠️`, sort JSON
   keys, normalise number precision/locale) and diff.

Network tools (echo/query/send/retrieve/qr/mwl/mpps/wado) need a live PACS, so
they stay input-contract-only unless pointed at a test SCP.
