# App ↔ CLI Parity Matrix

Per‑tool, per‑subcommand, per‑flag verdict on whether DICOMStudio's *CLI Workshop*
produces **bit/text‑exact** the same output as the `dicom-*` CLI for the same input.

Derived from a code‑level audit of all 29 CLI‑Workshop tools (engine call sites,
golden coverage, and concrete output diffs) plus the Tier‑2 parity harness
(committed CI gate: `MATCH=160, DIFFERS=0`). Companion to
[`APP_CLI_SHARED_API.md`](APP_CLI_SHARED_API.md).

> Generated 2026‑06‑09; golden counts, the `dicom-convert` engine rating, and the
> JPEG 2000 Part 2 rows re‑verified 2026‑07‑17 against `goldens.synthetic.json`
> and a live `PARITY_STRICT=1` run.

**Golden counts below are per‑tool scenario counts in the committed, CI‑authoritative
`goldens.synthetic.json` (160 scenarios total).** A dev machine that also has the
git‑ignored `goldens.json` superset (real fixtures) runs a larger set — 423 scenarios,
`MATCH=422, DIFFERS=1`, the one DIFFERS being `dicom-dcmdir-create`, which is excluded
from the committed gate as non‑deterministic. Host‑dependent scenarios (e.g.
`dicom-compress backends`) live only in that local superset, never in the CI gate.

---

## Legend

A tool produces two kinds of output. They're tracked separately because the
parity harness verifies **artifacts**, while the **console** may carry intentional
GUI extras:

- **Artifact** — the produced DICOM file / converted data / report bytes.
- **Console** — the stdout/stderr text shown to the user.

| Verdict | Meaning |
|---|---|
| ✅ **SAME** | Byte/text‑exact in both artifact and console. Machine‑verified by goldens where a count is shown. |
| 🟰 **SAME artifact / +note** | Produced file/data is byte‑identical (shared engine); the app console adds an **intentional** note or line (sandbox redirect, summary, exit‑code annotation). The CLI artifact and app artifact match exactly. |
| ⚠️ **DIFFER (intentional)** | Output differs **by design** — emoji vs ASCII, educational/verbose extras, or an app‑only capability. Not a regression. |
| 🎲 **NON‑DETERMINISTIC** | Same shared engine, but output varies run‑to‑run by design (fresh SOP/Study/Series UIDs, current date/time). Cannot be bit‑compared; no goldens. |
| 🌐 **NETWORK** | Live PACS/DICOMweb. **Execution** runs through the shared service/client in both; **presentation** may differ (emoji, units, educational echo). Not golden‑coverable. |
| 🐞 **BUG** | Unintended difference. Status noted. |

"Shared engine" column: **full** = both adapters call the same engine for all
logic; **partial** = core shared, some orchestration local.

---

## Summary

| Tool | Shared engine | Overall | Goldens | Headline difference (if any) |
|---|---|---|---:|---|
| `dicom-info` | full | ✅ SAME | 9 | none |
| `dicom-dump` | full | ✅ SAME | 9 | none (app forces `--no-color`; harness normalizes ANSI) |
| `dicom-validate` | full | ✅ SAME | 8 | app adds an exit‑code annotation line (stripped in parity path) |
| `dicom-diff` | full | ✅ SAME | 11 | none |
| `dicom-tags` | full | 🟰 SAME artifact / +note | 4 | console wording (`Saved:` vs `Output written to:`), always prints change count |
| `dicom-anon` | full | 🟰 SAME artifact / +note | 9 | verbose per‑file line format differs; sandbox redirect note |
| `dicom-json` | full | ✅ SAME | 11 | sandbox redirect note only on TCC denial |
| `dicom-xml` | full | ✅ SAME | 8 | sandbox redirect note only on TCC denial |
| `dicom-convert` | full | 🟰 SAME artifact / +note | 22 | DICOM→DICOM artifact identical; app adds progress lines + sandbox note |
| `dicom-pixedit` | full | 🟰 SAME artifact / +note | 3 | edited DICOM identical; app adds a 2‑line summary |
| `dicom-study` | full | ✅ SAME | 12 | all subcommands shared; organize now uses the shared `StudyOrganizer` (text-exact, incl. the copy "already exists" error) |
| `dicom-compress` | full | 🟰 SAME artifact / +note | 29 | info SAME; compress/decompress/batch artifacts identical, app adds sandbox note |
| `dicom-uid` | full | ✅/🎲 split | 6 | validate/lookup SAME; generate/regenerate non‑deterministic |
| `dicom-split` | full | ⚠️ DIFFER | 0 | same FrameSplitter; app lists extracted paths + summary |
| `dicom-merge` | full | 🎲 NON‑DET | 0 | same FrameMerger; fresh SOP UID each run |
| `dicom-image` | full | 🎲 NON‑DET | 0 | same ImageConverter; fresh UIDs + timestamps |
| `dicom-export` | full | 🟰 SAME artifact / +note | 0 | same DICOMImageExporter; app sandbox redirect note |
| `dicom-pdf` | partial | 🟰/🎲 split | 0 | **extract** SAME; **encapsulate** non‑deterministic (fresh UIDs) |
| `dicom-dcmdir` | full | ⚠️ DIFFER | 0 | same engine; emoji (CLI) vs plain (app) |
| `dicom-archive` | full | 🟰/✅ + fix | 0 | read ops SAME; import/export sandbox note; `--skip-duplicates` **fixed** |
| `dicom-script` | partial | ✅/⚠️ split | 2 | **template** SAME; **run/validate** app shows a plan only (sandbox) |
| `dicom-echo` | full | 🌐 NETWORK | 0 | emoji, ms vs s, always‑on header |
| `dicom-send` | full | 🌐 NETWORK | 0 | emoji, ms vs s, educational error hints |
| `dicom-query` | partial | 🌐 NETWORK | 0 | app adds parent‑study columns + XML/HL7 + two‑step fallback |
| `dicom-retrieve` | full | 🌐 NETWORK | 0 | app auto‑resolves Study UID, prints saved paths |
| `dicom-qr` | full | 🌐 NETWORK | 0 | **BUG:** CLI uppercases patient‑name key, app doesn't; `resume` app‑missing |
| `dicom-mwl` | full | 🌐 NETWORK | 0 | app adds `create` (REST + HL7) the CLI lacks |
| `dicom-mpps` | full | 🌐 NETWORK | 0 | shared `DICOMMPPSService.create/update`; presentation differs |
| `dicom-wado` | full | 🌐 NETWORK | 0 | emoji, `Mode:` line; shared `DICOMwebClient` |

---

## Detailed per‑tool / per‑flag matrix

### Deterministic, golden‑verified tools (artifact + console bit‑exact)

#### `dicom-info` — `MetadataPresenter` — ✅ SAME (9 goldens)
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| (default), all flags | ✅ SAME | Both render via the identical `MetadataPresenter.render()`. All 9 goldens MATCH. No app modification. |

#### `dicom-dump` — `HexDumper` — ✅ SAME (9 goldens)
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| (default) | ✅ SAME (7) | Shared `HexDumper`; byte‑identical. |
| `--tag <tag>` | ✅ SAME (2) | Shared `HexDumper.tagDump()`. |
| `--no-color` | ✅ SAME | App always disables ANSI for the SwiftUI console; CLI honors the flag. The harness strips ANSI from CLI output before comparing, so covered scenarios MATCH. |

#### `dicom-validate` — `DICOMValidator` — ✅ SAME (8 goldens)
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| (default), `--level`, `--iod`, `--detailed`, `--strict`, `--format` | ✅ SAME | Identical `ValidationResult` → `ValidationReport` rendering. |
| exit status | 🟰 +note | App appends an educational `Exit code: N (…)` line for the GUI; the CLI conveys status via process exit code only. This annotation is excluded from the parity comparison path. |

#### `dicom-diff` — `DICOMComparer` / `ComparisonReport` — ✅ SAME (11 goldens)
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| `--format text` | ✅ SAME (1) | `ComparisonReport.formatTextOutput()` shared. |
| `--format json` | ✅ SAME (2) | Deterministic sorted JSON. |
| `--format summary` | ✅ SAME (1) | Shared summary formatter. |
| `--ignore-private`, `--ignore-tags`, `--show-identical`, … | ✅ SAME | All comparison options handled in the shared `DICOMComparer`. App only adds security‑scoped URL access (no output effect). |

#### `dicom-tags` — `TagEditor` — 🟰 SAME artifact / +note (4 goldens)
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| `--set`, `--delete`, `--delete-private`, … | 🟰 SAME artifact | Edited DICOM is byte‑identical (4 goldens compare the `dicom` artifact). **Console differs intentionally:** app prints `Saved: <path>` (CLI: `Output written to: <path>`) and always prints the change count, whereas the CLI prints it only with `--verbose`/`--dry-run`. |

#### `dicom-anon` — `Anonymizer` — 🟰 SAME artifact / +note (9 goldens)
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| `--profile basic` / `clinical-trial` | 🟰 SAME artifact | Identical `Anonymizer` profile application; goldens compare the output DICOM. |
| `--remove`, `--replace`, `--keep` | 🟰 SAME artifact | Identical tag parsing (`GGGG,EEEE`/`GGGGEEEE`) + actions. |
| `--backup`, `--force` | ✅ SAME | Same backup/force paths. |
| `--recursive`, `--verbose` | ⚠️ DIFFER (console) | Per‑file verbose line differs: CLI `✓ <relativePath>`; app `Processing: <name>` + `  ✓ <N> tags modified`. Summary text is identical. |
| output write | 🟰 +note | App may print `⚠ Output redirected to: ~/Downloads/DICOMStudio/Anonymized/` under sandbox/TCC. |

#### `dicom-json` — `DICOMJSONEncoder` / `Decoder` — ✅ SAME (11 goldens)
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| DICOM→JSON (default), `--pretty`, `--no-keywords`, `--include-bulk`, … | ✅ SAME (8) | Identical encoder config from flags. |
| JSON→DICOM (`--reverse`) | ✅ SAME (3) | Identical decoder config (`allowMissingVR: true`, …). |
| file write | 🟰 +note | Sandbox redirect note only on TCC denial (not hit in tests). |

#### `dicom-xml` — `DICOMXMLEncoder` / `Decoder` — ✅ SAME (8 goldens)
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| (default), `--pretty`, `--include-empty`, `--inline-binary`, … | ✅ SAME (8) | Shared encoder/decoder. Sandbox redirect note only on TCC denial. |

#### `dicom-convert` — `DICOMConverter` + `DICOMImageExporter` + `DICOMFile` — 🟰 SAME artifact / +note (22 goldens)
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| DICOM→DICOM (`--format dicom`/default) | 🟰 SAME artifact | Identical `DICOMConverter.convertToDICOM` / `resolveTargetEncoding`; converted DICOM byte‑identical. Goldens sweep a 19‑transfer‑syntax matrix (`--transfer-syntax`), incl. JPEG XL. |
| `--format png` / `jpeg` / `tiff` | 🟰 SAME artifact | Shared `DICOMImageExporter.renderFrameForExport` + `exportCGImage`. |
| `--quality`, `--frame`, `--apply-window`, `--window-center`, `--window-width` | ✅ SAME | All resolve through the same shared exporter call. |
| `--strip-private`, `--validate`, `--force` | ✅ SAME | Handled inside the shared `convertToDICOM`. |
| `--recursive` | ✅ SAME | Shared `FileGatherer.regularFiles` walk; shared `ConvertConsole` batch lines. |
| output path resolution | ✅ SAME | Both resolve a directory `--output` through the shared `OutputPathResolver.resolveFileOutput` + `ConvertConsole.fileExtension(forFormat:)`. *(Fixed 2026‑07‑17 — the app previously inlined its own directory test and format→extension switch, so a typed non‑existent extension‑less `--output` became a directory in the app but a file in the CLI.)* |
| `--transfer-syntax JPEG2000Part2*` (`.92`/`.93`) | ✅ SAME (both error) | **Part 2 encoding is deliberately unsupported** — see the JPEG 2000 Part 2 note below. Both surfaces refuse; goldens pin the refusal. |
| image render / progress | ⚠️ DIFFER (console) | App prints extra progress (file size, frame export, output path) + sandbox redirect note. |

#### `dicom-pixedit` — `PixelEditor` — 🟰 SAME artifact / +note (3 goldens)
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| `--mask-region`, `--crop`, `--apply-window`, `--invert` | 🟰 SAME artifact (3) | Edited DICOM byte‑identical (shared `PixelEditor.processData`). **Console:** app appends `Edited pixel data: N operation(s) applied.` + `Image: WxH, B-bit, S sample(s)`; sandbox note when applicable. |

#### `dicom-study` — `StudyScanner` / `StudyReport` / `StudyOrganizer` — ✅ SAME
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| `summary` | ✅ SAME (4) | Shared `StudyScanner.scanStudies` + `StudyReport.renderSummary`. |
| `check` | ✅ SAME (3) | Shared `evaluateCompleteness`. |
| `stats` | ✅ SAME (3) | Shared `computeStatistics`. |
| `compare` | ✅ SAME (2) | Shared `compareStudies`. |
| `organize` | ✅ SAME | Now shared via `StudyOrganizer` (DICOMKit/Study). Identical descriptive/uid folder naming, deterministic file ordering, the `→` (U+2192) verbose arrow, and the same `copyItem`/`moveItem` **"already exists"** error on a re-run (the app no longer pre-removes the destination). Only the summary line's output *path* differs when the app's sandbox redirects the write (an adapter concern, not the renderer). |

#### `dicom-compress` — `CompressionManager` + `CompressionConsole` — split (29 goldens)
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| `info` (+`--json`) | ✅ SAME | Shared `getCompressionInfo` + `CompressionConsole.infoText/infoJSON`; text + JSON byte‑identical. |
| `compress` (`--codec`,`--quality`,`--backend`,`--verbose`) | 🟰 SAME artifact | Shared `compressDataWithMetrics`; goldens cover per‑codec (RLE, JPEG‑LS, JPEG lossless/extended, J2K, JPEG XL), quality, and backend selection. Console adds sandbox redirect note under TCC. |
| `decompress` (`--syntax`) | 🟰 SAME artifact | Shared `decompressData`; artifact verified. Console sandbox note. |
| `batch` (`--decompress`,`--recursive`,`--quality`,`--syntax`,`--verbose`) | 🟰 SAME artifact | Per‑file shared `compressData`/`decompressData`. **Now golden‑covered** (`batch-compress-*` / `batch-decompress-*` scenarios). |
| `backends` (+`--json`) | ✅ SAME | Shared `CodecBackendProbe`/`CodecBackend`; identical text/JSON. Host‑dependent, so it lives in the local `goldens.json` superset only — **never** the committed CI gate. |
| `compress --codec j2k-part2*` (`.92`/`.93`) | ✅ SAME (both error) | **Part 2 encoding is deliberately unsupported** — see below. Both surfaces refuse identically. |

##### JPEG 2000 Part 2 (`.92` / `.93`) is decode‑only — by design

`J2KSwiftCodec.supportedEncodingTransferSyntaxes` filters Part 2 **out** of the
encoder registry (`J2KRoutePlanner.unsupportedEncodeReason`): the Part‑2
multi‑component transform cannot be inverted by the current decoder, so an encode
would emit a codestream that will not read back. Decoding stays registered so
previously‑written Part‑2 files remain readable.

Both surfaces therefore fail closed, and the goldens pin that:

- `dicom-compress compress -c j2k-part2[-lossless]` → `Error: No encoder registered for transfer syntax 1.2.840.10008.1.2.4.93. …`
- `dicom-convert --transfer-syntax JPEG2000Part2Lossless` → `Error: Unsupported target transfer syntax: 1.2.840.10008.1.2.4.93`

Both exit `1` and produce no artifact. Goldens for these three scenarios were
**stale until 2026‑07‑17** — they still held pixel hashes captured before Part‑2
encoding was withdrawn, so the gate reported a false DIFFERS against an app that was
behaving correctly. Regenerated; use Part 1 (`.90`/`.91`) or HTJ2K (`.201`–`.203`) to
actually encode.

#### `dicom-uid` — `UIDManager` — split (6 goldens)
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| `generate` | 🎲 NON‑DET | Shared `UIDManager.generateUIDs`; output is fresh UIDs by definition. |
| `validate` (+`--check-registry`,`--file`,`--json`) | ✅ SAME (4) | Shared `validateUID`/`validateFileUIDs`; goldens MATCH (incl. invalid case, registry lookup). |
| `lookup` (+`--list-all`) | ✅ SAME (2) | Shared `UIDDictionary` lookup + `uidTypeDescription`. |
| `regenerate` | 🎲 NON‑DET / +note | Shared `regenerateData`; output has fresh UIDs (no golden). App appends sandbox write note. |

### Deterministic, **not** golden‑covered

#### `dicom-split` — `FrameSplitter` — ⚠️ DIFFER
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| (default), `--output`, `--format`, … | ⚠️ DIFFER (console) | **Same `FrameSplitter` engine** (identical extracted frames). App enriches the console: `Extracted N frame(s) to <path>`, lists up to 10 written paths, shows sizes; CLI prints only `Split complete!`. Excluded from goldens (non‑deterministic file set / paths). |

#### `dicom-merge` — `FrameMerger` — 🎲 NON‑DETERMINISTIC
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| (default), `--format`, `--level`, `--sort-by`, … | 🎲 NON‑DET | **Same `FrameMerger` engine.** The merged multi‑frame object gets a **fresh SOP Instance UID** each run, so bytes differ run‑to‑run; not bit‑comparable. Logic is identical (input paths sorted in the engine for determinism of frame order). |

#### `dicom-image` — `ImageConverter` — 🎲 NON‑DETERMINISTIC
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| single, batch (`--recursive`), multipage‑TIFF (`--split-pages`); `--use-exif`, `--patient-*`, … | 🎲 NON‑DET | **Same `ImageConverter.secondaryCaptureData` engine** (UID generation reconciled to `UIDGenerator` in both). Output Secondary‑Capture DICOM carries **fresh SOP/Study/Series UIDs + current Study Date/Time**, so bytes differ run‑to‑run. Verified by smoke (valid SC DICOM). App adds sandbox handling. |

#### `dicom-export` — `DICOMImageExporter` — 🟰 SAME artifact / +note
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| `single`, `contact-sheet`, `animate`, `bulk` | 🟰 SAME artifact | **Same `DICOMImageExporter`** (EXIF/layout/paths/window/encode shared). Console messages identical (`Exported: …`, `Contact sheet exported: …`, etc.). The only difference is the app's **sandbox `OutputAccess`** redirect note under TCC. Image bytes depend on CoreGraphics encoding (deterministic per host); no goldens (binary image output). |

#### `dicom-pdf` — `EncapsulatedDocument*` — split
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| `extract` (single + directory) | 🟰 SAME artifact | Shared `EncapsulatedDocumentParser`; extracted document byte‑identical; identical success/fail counts. App adds sandbox note. |
| `encapsulate` (single + directory) | 🎲 NON‑DET | Shared `EncapsulatedDocumentBuilder`, but the produced DICOM gets **fresh Study/Series/SOP UIDs** → bytes differ run‑to‑run. |

#### `dicom-dcmdir` — `DICOMDirectory`/`DICOMDIRReader`/`Writer` — ⚠️ DIFFER
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| `create` | ⚠️ DIFFER (emoji) | Same builder engine; CLI prints `✅ DICOMDIR created`, app prints plain text. |
| `validate` | ⚠️ DIFFER (emoji) | CLI `✅ … is valid`; app plain. |
| `dump` | ✅ SAME | No emoji in either; identical tree rendering. |
| `update` | ⚠️ DIFFER | Stub in both; CLI `⚠️ not yet implemented`, app plain text. |

#### `dicom-archive` — `ArchiveStore` — read ops SAME; writes +note
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| `query`, `list`, `check`, `stats` | ✅ SAME | Read‑only; shared `ArchiveStore`; byte‑identical across all formats. |
| `init` | 🟰 +note | Shared `initArchive`; app may add sandbox redirect note. |
| `import` (`--recursive`, `--skip-duplicates`, `--verbose`) | 🟰 +note · 🐞→**fixed** | Shared `importFiles`. **BUG (fixed `b418bfc`):** the app's `--skip-duplicates` toggle was ignored (hardcoded `false`); now wired through. App may add sandbox note. |
| `export` (`--flatten`, …) | 🟰 +note | Shared `export`; app resolves output dir via `OutputAccess` (may add note). |

#### `dicom-script` — `ScriptParser`/`Executor`/`Validator`/`TemplateGenerator` — split (2 goldens)
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| `template <name>` | ✅ SAME (2) | Shared `TemplateGenerator().generate()`; byte‑identical. |
| `run` | ⚠️ DIFFER (intentional) | CLI executes the script via `ScriptExecutor` (spawns nested tools). The **sandboxed app cannot spawn processes**, so it shows a parsed **plan only** + an educational note. Engine (`ScriptParser`) is shared; behavior intentionally differs. |
| `validate` | ⚠️ DIFFER (intentional) | Similar: app renders a plan summary rather than the CLI's full `ScriptValidator` issue report. |

### Network tools (execution shared; presentation differs; not golden‑coverable)

> For all of these the **DICOM/DICOMweb protocol execution runs through the shared
> service/client in both adapters** — the wire requests are the same. Differences
> are in console presentation or app‑only convenience features. Live‑server output
> is non‑deterministic, so none can have goldens.

#### `dicom-echo` — `DICOMVerificationService` — 🌐 NETWORK
| Aspect | Verdict | Notes |
|---|---|---|
| C‑ECHO execution | ✅ shared | Identical `DICOMVerificationService.echo()`. |
| console | ⚠️ DIFFER | App: `✅/❌`, latency in **ms** (1 dp), always shows connection header; CLI: `✓/✗`, **s** (3 dp), header only with `--verbose`. |

#### `dicom-send` — `DICOMStorageService` — 🌐 NETWORK
| Aspect | Verdict | Notes |
|---|---|---|
| C‑STORE execution | ✅ shared | Identical `DICOMStorageService`; same network I/O. |
| console | ⚠️ DIFFER | App `✅/❌/⚠️` + **ms**, plus educational error hints; CLI `✓/✗` + **s**. |

#### `dicom-query` — `DICOMQueryService` — 🌐 NETWORK
| Aspect | Verdict | Notes |
|---|---|---|
| C‑FIND execution | ✅ shared | Both call `DICOMQueryService.find()`. |
| query strategy | ⚠️ app‑enhanced | App implements a PS3.4‑compliant **two‑step** SERIES/IMAGE fallback (catches `0xA900`); CLI does single‑step. |
| formatting | ⚠️ DIFFER | App `formatQueryResults*` take `(result, parent)` pairs and add **parent‑study context** columns for SERIES/IMAGE; CLI's `QueryFormatter` takes plain results. App also adds **XML** and **HL7** output formats. *(Intentional divergence — sharing the CLI's plainer formatter would regress the GUI.)* |

#### `dicom-retrieve` — `DICOMRetrieveService` — 🌐 NETWORK
| Aspect | Verdict | Notes |
|---|---|---|
| C‑MOVE / C‑GET execution | ✅ shared | Both call `DICOMRetrieveService.move*/get*`; identical DIMSE + identical Part‑10 wrapping of received instances. |
| app extras | ⚠️ app‑enhanced | App auto‑resolves a missing **Study UID** via `DICOMQueryService.find()` (CLI errors), and prints each received instance's saved path; CLI prints progress only with `--verbose`. |

#### `dicom-qr` — `DICOMQueryService` / `DICOMRetrieveService` — 🌐 NETWORK
| Aspect | Verdict | Notes |
|---|---|---|
| query/retrieve execution | ✅ shared | Same services. |
| `query` formatting | ⚠️ DIFFER | App prints structured output; CLI plain text with `─` dividers. |
| patient‑name key | 🐞 **BUG (to fix)** | CLI uppercases the C‑FIND patient‑name key (`name.uppercased()`); the app sends it as‑typed → the same user input yields different query keys. |
| `resume` | ⚠️ app‑missing | CLI has a `resume` subcommand for interrupted retrievals; the app does not implement it. |

#### `dicom-mwl` — `DICOMModalityWorklistService` — 🌐 NETWORK
| Aspect | Verdict | Notes |
|---|---|---|
| `query` execution | ✅ shared | Both call `DICOMModalityWorklistService.find()`. |
| `query` formatting | ⚠️ DIFFER | Same data, different layout. |
| `create` | ⚠️ app‑only | App adds `create` (REST + HL7 ORM^O01) via the shared engine's `create()`/`createViaHL7()`; the CLI exposes only `query`. |

#### `dicom-mpps` — `DICOMMPPSService` — 🌐 NETWORK
| Aspect | Verdict | Notes |
|---|---|---|
| `create`, `update` | ✅ shared | Both call `DICOMMPPSService.create()`/`update()`; identical N‑CREATE/N‑SET. Console presentation differs. |

#### `dicom-wado` — `DICOMwebClient` / `WADOURIClient` — 🌐 NETWORK
| Aspect | Verdict | Notes |
|---|---|---|
| WADO‑RS, WADO‑URI, QIDO‑RS, STOW‑RS, UPS‑RS | ✅ shared | All call the identical `DICOMwebClient`/`WADOURIClient` methods; same HTTP. |
| console | ⚠️ DIFFER | App uses emoji (`✅/❌/⚠️`), adds a `Mode: <type>` line, and (UPS change‑state) prints the **curl‑equivalent + raw HTTP request/response** as an educational feature; CLI prints plain text and no HTTP echo. |

---

## Bugs surfaced by the audit

| Tool | Bug | Status |
|---|---|---|
| `dicom-archive` | App's `--skip-duplicates` import toggle was ignored (hardcoded `skipDuplicates: false`), so it always errored on duplicate SOP Instance UIDs where the CLI could skip them. | **Fixed** — `b418bfc` reads `paramValue("skip-duplicates")` and passes it through. |
| `dicom-qr` | CLI uppercases the patient‑name C‑FIND key; the app sends it as‑typed, so identical user input produces different query keys. | **Open** — documented here; low‑risk to align the app, but it's network behavior with no parity net, so deferred for explicit review. |
| `dicom-convert` | App inlined its own `--output` directory test **and** its own format→extension switch instead of the shared `OutputPathResolver`. A typed, non‑existent, extension‑less `--output` (e.g. `--output ~/out`) became a **directory** in the app but a **file** in the CLI; the duplicated extension map was also free to drift (`jpeg → jpg`). Invisible to the gate — every golden passes a concrete output path. | **Fixed 2026‑07‑17** — extension map moved to shared `ConvertConsole.fileExtension(forFormat:)` (CLI's `ExportFormat.fileExtension` now delegates to it); app calls the shared `OutputPathResolver.resolveFileOutput`. The GUI Browse flow is unaffected (a picked folder exists, so both treat it as a directory). |

---

## How to re‑verify

- **Machine‑verified (deterministic) tools:** `PARITY_STRICT=1 swift test --filter StudioParityTests`.
  - On a **clean checkout / CI** (committed `goldens.synthetic.json` only) → expect `MATCH=160, DIFFERS=0`.
  - On a **dev machine that also has the git‑ignored `goldens.json`** (real‑fixture superset, built from `$DICOM_INPUT_DIR`) → expect `MATCH=422, DIFFERS=1`; the DIFFERS is `dicom-dcmdir-create` (app prints 2 extra lines), which is excluded from the committed gate as non‑deterministic.
  - Regenerate with `swift build && swift run cli-parity-gen` (the generator shells out to the built `dicom-*` binaries, so build first). It rewrites **both** golden files in one pass: everything → `goldens.json`, and the `phiSafe && deterministic && portable` subset → the committed `goldens.synthetic.json`.
  - Regeneration only refreshes the **CLI** reference; it cannot mask an app‑vs‑CLI divergence (a real one still DIFFERS). If a golden changes unexpectedly, that is CLI behaviour drift worth reading, not churn to wave through.
- **Non‑deterministic / network tools:** verify by **shared‑engine construction** (both adapters call the same engine — see the call sites cited in [`APP_CLI_SHARED_API.md`](APP_CLI_SHARED_API.md) §3) plus smoke tests, since stable goldens are impossible.
