# dicom-export

_CLI binary:_ `dicom-export` · _category:_ DATA_EXPORT · _wired in Studio:_ yes · _network:_ no

**Input-contract parity:** 21/21 CLI flags matched · status **OK** (100%)

**Output behavior:** 48 scenario(s) — 48 success / 0 drift.

## Flags

| Flag | Kind | Input (UI ↔ CLI) | Output (UI vs CLI) |
|---|---|---|---|
| `--apply-window` | flag | ✅ match | ✅ success |
| `--columns` | option | ✅ match | ✅ success |
| `--embed-metadata` | flag | ✅ match | ✅ success |
| `--end-frame` | option | ✅ match | ✅ success |
| `--exif-fields` | option | ✅ match | ⊘ not covered |
| `--format` | option | ✅ match | ✅ success |
| `--fps` | option | ✅ match | ⊘ not covered |
| `--frame` | option | ✅ match | ✅ success |
| `--labels` | flag | ✅ match | ✅ success |
| `--loop-count` | option | ✅ match | ✅ success |
| `--organize-by` | option | ✅ match | ✅ success |
| `--output` | option | ✅ match | ✅ success |
| `--quality` | option | ✅ match | ✅ success |
| `--recursive` | flag | ✅ match | ✅ success |
| `--scale` | option | ✅ match | ⊘ not covered |
| `--spacing` | option | ✅ match | ✅ success |
| `--start-frame` | option | ✅ match | ✅ success |
| `--thumbnail-size` | option | ✅ match | ✅ success |
| `--verbose` | flag | ✅ match | ✅ success |
| `--window-center` | option | ✅ match | ⊘ not covered |
| `--window-width` | option | ✅ match | ⊘ not covered |

## Output scenarios

| Scenario | CLI args | Result |
|---|---|---|
| CT.dcm · auto-animate-apply-window | `animate FIXTURE --output OUTPUT --apply-window` | ✅ success |
| CT.dcm · auto-animate-end-frame | `animate FIXTURE --output OUTPUT --end-frame 0` | ✅ success |
| CT.dcm · auto-animate-loop-count | `animate FIXTURE --output OUTPUT --loop-count 0` | ✅ success |
| CT.dcm · auto-animate-start-frame | `animate FIXTURE --output OUTPUT --start-frame 0` | ✅ success |
| CT.dcm · auto-bulk-apply-window | `bulk FIXTURE --output OUTPUT --apply-window` | ✅ success |
| CT.dcm · auto-bulk-embed-metadata | `bulk FIXTURE --output OUTPUT --embed-metadata` | ✅ success |
| CT.dcm · auto-bulk-organize-by-flat | `bulk FIXTURE --output OUTPUT --organize-by flat` | ✅ success |
| CT.dcm · auto-bulk-organize-by-patient | `bulk FIXTURE --output OUTPUT --organize-by patient` | ✅ success |
| CT.dcm · auto-bulk-organize-by-series | `bulk FIXTURE --output OUTPUT --organize-by series` | ✅ success |
| CT.dcm · auto-bulk-organize-by-study | `bulk FIXTURE --output OUTPUT --organize-by study` | ✅ success |
| CT.dcm · auto-bulk-quality | `bulk FIXTURE --output OUTPUT --quality 1` | ✅ success |
| CT.dcm · auto-bulk-recursive | `bulk FIXTURE --output OUTPUT --recursive` | ✅ success |
| CT.dcm · auto-bulk-verbose | `bulk FIXTURE --output OUTPUT --verbose` | ✅ success |
| CT.dcm · auto-contact-sheet-apply-window | `contact-sheet FIXTURE --output OUTPUT --apply-window` | ✅ success |
| CT.dcm · auto-contact-sheet-columns | `contact-sheet FIXTURE --output OUTPUT --columns 1` | ✅ success |
| CT.dcm · auto-contact-sheet-labels | `contact-sheet FIXTURE --output OUTPUT --labels` | ✅ success |
| CT.dcm · auto-contact-sheet-quality | `contact-sheet FIXTURE --output OUTPUT --quality 1` | ✅ success |
| CT.dcm · auto-contact-sheet-spacing | `contact-sheet FIXTURE --output OUTPUT --spacing 0` | ✅ success |
| CT.dcm · auto-contact-sheet-thumbnail-size | `contact-sheet FIXTURE --output OUTPUT --thumbnail-size 16` | ✅ success |
| CT.dcm · auto-single-apply-window | `single FIXTURE --output OUTPUT --format png --apply-window` | ✅ success |
| CT.dcm · auto-single-embed-metadata | `single FIXTURE --output OUTPUT --format png --embed-metadata` | ✅ success |
| CT.dcm · auto-single-frame | `single FIXTURE --output OUTPUT --format png --frame 0` | ✅ success |
| CT.dcm · auto-single-quality | `single FIXTURE --output OUTPUT --format png --quality 1` | ✅ success |
| CT.dcm · single-png | `single FIXTURE --format png --output OUTPUT` | ✅ success |
| syn-ct.dcm · auto-animate-apply-window | `animate FIXTURE --output OUTPUT --apply-window` | ✅ success |
| syn-ct.dcm · auto-animate-end-frame | `animate FIXTURE --output OUTPUT --end-frame 0` | ✅ success |
| syn-ct.dcm · auto-animate-loop-count | `animate FIXTURE --output OUTPUT --loop-count 0` | ✅ success |
| syn-ct.dcm · auto-animate-start-frame | `animate FIXTURE --output OUTPUT --start-frame 0` | ✅ success |
| syn-ct.dcm · auto-bulk-apply-window | `bulk FIXTURE --output OUTPUT --apply-window` | ✅ success |
| syn-ct.dcm · auto-bulk-embed-metadata | `bulk FIXTURE --output OUTPUT --embed-metadata` | ✅ success |
| syn-ct.dcm · auto-bulk-organize-by-flat | `bulk FIXTURE --output OUTPUT --organize-by flat` | ✅ success |
| syn-ct.dcm · auto-bulk-organize-by-patient | `bulk FIXTURE --output OUTPUT --organize-by patient` | ✅ success |
| syn-ct.dcm · auto-bulk-organize-by-series | `bulk FIXTURE --output OUTPUT --organize-by series` | ✅ success |
| syn-ct.dcm · auto-bulk-organize-by-study | `bulk FIXTURE --output OUTPUT --organize-by study` | ✅ success |
| syn-ct.dcm · auto-bulk-quality | `bulk FIXTURE --output OUTPUT --quality 1` | ✅ success |
| syn-ct.dcm · auto-bulk-recursive | `bulk FIXTURE --output OUTPUT --recursive` | ✅ success |
| syn-ct.dcm · auto-bulk-verbose | `bulk FIXTURE --output OUTPUT --verbose` | ✅ success |
| syn-ct.dcm · auto-contact-sheet-apply-window | `contact-sheet FIXTURE --output OUTPUT --apply-window` | ✅ success |
| syn-ct.dcm · auto-contact-sheet-columns | `contact-sheet FIXTURE --output OUTPUT --columns 1` | ✅ success |
| syn-ct.dcm · auto-contact-sheet-labels | `contact-sheet FIXTURE --output OUTPUT --labels` | ✅ success |
| syn-ct.dcm · auto-contact-sheet-quality | `contact-sheet FIXTURE --output OUTPUT --quality 1` | ✅ success |
| syn-ct.dcm · auto-contact-sheet-spacing | `contact-sheet FIXTURE --output OUTPUT --spacing 0` | ✅ success |
| syn-ct.dcm · auto-contact-sheet-thumbnail-size | `contact-sheet FIXTURE --output OUTPUT --thumbnail-size 16` | ✅ success |
| syn-ct.dcm · auto-single-apply-window | `single FIXTURE --output OUTPUT --format png --apply-window` | ✅ success |
| syn-ct.dcm · auto-single-embed-metadata | `single FIXTURE --output OUTPUT --format png --embed-metadata` | ✅ success |
| syn-ct.dcm · auto-single-frame | `single FIXTURE --output OUTPUT --format png --frame 0` | ✅ success |
| syn-ct.dcm · auto-single-quality | `single FIXTURE --output OUTPUT --format png --quality 1` | ✅ success |
| syn-ct.dcm · single-png | `single FIXTURE --format png --output OUTPUT` | ✅ success |

---
_Legend — Input:_ ✅ match · ⚠️ missing in UI · ➕ extra in UI (drift). _Output:_ ✅ success · ❌ drift · ⊘ not covered · — not wired. Generated by `swift run cli-parity-docs` (in-process, from bundled contracts + goldens)._
