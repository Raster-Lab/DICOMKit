# CLI ↔ DICOMStudio parity matrix

Per-tool success-vs-drift for **input flags** (does the UI emit what the CLI accepts) and **output behavior** (does the UI's output match the CLI's). One row per tool; click through for the full flag-by-flag table.

The tables below are **machine-generated** by `swift run cli-parity-docs` — in-process from the bundled `CLIContracts.json` (CLI side) + `buildCommand()` (UI side) + goldens (output side). No binaries are run. They report **input-contract parity** and **golden-tested output**; flags with no golden show `⊘ not covered` (coverage gap, not a known mismatch).

### Verified parity verdict (read this first)

Each per-tool page also carries a **`## Verified App↔CLI parity`** block — a manual,
code-level audit (2026-06-09) that covers **every** flag, including the `⊘ not covered`
ones. It records the **shared DICOMKit engine** both adapters call (so uncovered flags
still produce identical output *by construction*), the verified same/differ verdict, the
**intentional** divergences (sandbox `OutputAccess` notes, emoji vs ASCII, educational
extras, non-deterministic UIDs/timestamps, live-network output), and any known bug.

> ⚠️ **Regeneration caveat:** `cli-parity-docs` **overwrites** these pages, so it will
> wipe the `## Verified App↔CLI parity` blocks. The durable, regeneration-proof copy of
> the verdict lives in the repo-root [`APP_CLI_PARITY_MATRIX.md`](../../APP_CLI_PARITY_MATRIX.md)
> (per tool/subcommand/flag) and [`APP_CLI_SHARED_API.md`](../../APP_CLI_SHARED_API.md)
> (the shared-engine architecture). Re-apply the blocks after any regen, or teach the
> generator to emit them.

| Tool | Wired | Input parity | Input status | Output (success/drift/covered flags) |
|---|---|---|---|---|
| [dicom-anon](dicom-anon.md) | yes | 13/13 (100%) | OK | 20✅ / 0❌ · 10/13 flags |
| [dicom-archive](dicom-archive.md) | yes | 17/17 (100%) | OK | 8✅ / 0❌ · 6/17 flags |
| [dicom-compress](dicom-compress.md) | yes | 9/9 (100%) | OK | 9✅ / 0❌ · 3/9 flags |
| [dicom-convert](dicom-convert.md) | yes | 12/12 (100%) | OK | 24✅ / 0❌ · 11/12 flags |
| [dicom-dcmdir](dicom-dcmdir.md) | yes | 0/0 (0%) | NO_CLI_DATA | no scenarios |
| [dicom-diff](dicom-diff.md) | yes | 8/8 (100%) | OK | 11✅ / 0❌ · 8/8 flags |
| [dicom-dump](dicom-dump.md) | yes | 9/9 (100%) | OK | 17✅ / 0❌ · 9/9 flags |
| [dicom-echo](dicom-echo.md) | yes | 7/8 (88%) | INCOMPLETE | no scenarios |
| [dicom-export](dicom-export.md) | yes | 21/21 (100%) | OK | 60✅ / 0❌ · 20/21 flags |
| [dicom-image](dicom-image.md) | yes | 14/14 (100%) | OK | no scenarios |
| [dicom-info](dicom-info.md) | yes | 5/5 (100%) | OK | 16✅ / 0❌ · 5/5 flags |
| [dicom-json](dicom-json.md) | yes | 12/12 (100%) | OK | 22✅ / 0❌ · 11/12 flags |
| [dicom-merge](dicom-merge.md) | yes | 8/8 (100%) | OK | 1✅ / 0❌ · 1/8 flags |
| [dicom-mpps](dicom-mpps.md) | yes | 12/14 (86%) | INCOMPLETE | no scenarios |
| [dicom-mwl](dicom-mwl.md) | yes | 12/13 (92%) | INCOMPLETE | no scenarios |
| [dicom-pdf](dicom-pdf.md) | yes | 14/14 (100%) | OK | 1✅ / 0❌ · 5/14 flags |
| [dicom-pixedit](dicom-pixedit.md) | yes | 8/9 (89%) | INCOMPLETE | 6✅ / 0❌ · 5/9 flags |
| [dicom-qido](dicom-qido.md) | yes | 11/14 (79%) | INCOMPLETE | no scenarios |
| [dicom-qr](dicom-qr.md) | yes | 19/24 (79%) | INCOMPLETE | no scenarios |
| [dicom-query](dicom-query.md) | yes | 15/16 (94%) | INCOMPLETE | no scenarios |
| [dicom-retrieve](dicom-retrieve.md) | yes | 14/15 (93%) | INCOMPLETE | no scenarios |
| [dicom-script](dicom-script.md) | yes | 5/5 (100%) | OK | 2✅ / 0❌ · 0/5 flags |
| [dicom-send](dicom-send.md) | yes | 10/11 (91%) | INCOMPLETE | no scenarios |
| [dicom-split](dicom-split.md) | yes | 9/9 (100%) | OK | 11✅ / 0❌ · 8/9 flags |
| [dicom-stow](dicom-stow.md) | yes | 6/6 (100%) | OK | no scenarios |
| [dicom-study](dicom-study.md) | yes | 9/9 (100%) | OK | 12✅ / 0❌ · 5/9 flags |
| [dicom-tags](dicom-tags.md) | yes | 8/8 (100%) | OK | 8✅ / 0❌ · 4/8 flags |
| [dicom-uid](dicom-uid.md) | yes | 12/13 (92%) | INCOMPLETE | 7✅ / 0❌ · 3/13 flags |
| [dicom-ups](dicom-ups.md) | yes | 23/35 (66%) | INCOMPLETE | no scenarios |
| [dicom-validate](dicom-validate.md) | yes | 8/8 (100%) | OK | 15✅ / 0❌ · 6/8 flags |
| [dicom-wado](dicom-wado.md) | yes | 14/14 (100%) | OK | no scenarios |
| [dicom-xml](dicom-xml.md) | yes | 10/10 (100%) | OK | 16✅ / 0❌ · 9/10 flags |

> **Output coverage caveat:** a flag counts as output-tested only if a golden scenario exercises it. Flags marked `⊘ not covered` are a known gap (the silent-coverage issue) — contract-driven auto-generation (plan Phase 2) drives this to zero.

> **Not-wired CLI tools** (e.g. `dicom-3d`, `dicom-measure`, `dicom-gateway`, `dicom-jpip`, `dicom-report`, `dicom-j2k`, `dicom-viewer`) have no DICOMStudio reimplementation, so output parity is undefined for them; they are out of scope here.

## Output-flag coverage ledger

**129 / 383 CLI flags (33.7%)** are exercised by ≥1 output scenario across 32 wired tools. The rest are the silent-coverage gap (the `⊘ not covered` flags above) — contract-driven auto-generation (plan Phase 2) drives this toward 100%. Machine-readable per-tool detail (incl. each tool's `uncoveredFlags`) is in `coverage.json`.
