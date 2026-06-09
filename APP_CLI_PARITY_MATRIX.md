# App ↔ CLI Parity Matrix

Per‑tool, per‑subcommand, per‑flag verdict on whether DICOMStudio's *CLI Workshop*
produces **bit/text‑exact** the same output as the `dicom-*` CLI for the same input.

Derived from a code‑level audit of all 29 CLI‑Workshop tools (engine call sites,
golden coverage, and concrete output diffs) plus the Tier‑2 parity harness
(`MATCH=266, DIFFERS=0`). Companion to
[`APP_CLI_SHARED_API.md`](APP_CLI_SHARED_API.md).

> Generated 2026‑06‑09 from the App‑vs‑CLI parity audit.

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
| `dicom-convert` | partial | 🟰 SAME artifact / +note | 1 | DICOM→DICOM artifact identical; app adds progress lines + sandbox note |
| `dicom-pixedit` | full | 🟰 SAME artifact / +note | 3 | edited DICOM identical; app adds a 2‑line summary |
| `dicom-study` | partial | ⚠️/✅ split | 12 | summary/check/stats/compare SAME; **organize** differs (`→` vs `->`, sort) |
| `dicom-compress` | full | 🟰 SAME artifact / +note | 4 | info SAME; compress/decompress artifact identical, app adds sandbox note |
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

#### `dicom-convert` — `TransferSyntaxConverter` + `DICOMFile` — 🟰 SAME artifact / +note (1 golden)
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| DICOM→DICOM (`--format dicom`/default) | 🟰 SAME artifact (1) | Identical `TransferSyntaxConverter`; converted DICOM byte‑identical. |
| image render / progress | ⚠️ DIFFER (console) | App prints extra progress (file size, frame export, output path) + sandbox redirect note. |

#### `dicom-pixedit` — `PixelEditor` — 🟰 SAME artifact / +note (3 goldens)
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| `--mask-region`, `--crop`, `--apply-window`, `--invert` | 🟰 SAME artifact (3) | Edited DICOM byte‑identical (shared `PixelEditor.processData`). **Console:** app appends `Edited pixel data: N operation(s) applied.` + `Image: WxH, B-bit, S sample(s)`; sandbox note when applicable. |

#### `dicom-study` — `StudyScanner` / `StudyReport` — split
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| `summary` | ✅ SAME (4) | Shared `StudyScanner.scanStudies` + `StudyReport.renderSummary`. |
| `check` | ✅ SAME (3) | Shared `evaluateCompleteness`. |
| `stats` | ✅ SAME (3) | Shared `computeStatistics`. |
| `compare` | ✅ SAME (2) | Shared `compareStudies`. |
| `organize` | ⚠️ DIFFER | Separate impls: CLI verbose arrow `→` (U+2192) vs app ASCII `->`; app sorts collected files (CLI uses enumerator order); sandbox path resolution. No shared organize engine. |

#### `dicom-compress` — `CompressionManager` — split (4 goldens)
| Subcommand / flag | Verdict | Notes |
|---|---|---|
| `info` (+`--json`) | ✅ SAME (2) | Shared `getCompressionInfo`; text + JSON byte‑identical. |
| `compress` (`--codec`,`--quality`,`--backend`) | 🟰 SAME artifact (1) | Shared `compressData`; produced DICOM verified by golden (RLE). Console adds sandbox redirect note under TCC. |
| `decompress` (`--syntax`) | 🟰 SAME artifact (1) | Shared `decompressData`; artifact verified. Console sandbox note. |
| `batch` | 🟰 SAME artifact | Per‑file shared `compressData`/`decompressData`. Not golden‑covered (multi‑file, filesystem‑dependent). |
| `backends` | ✅ SAME | Shared `CodecBackendProbe`/`CodecBackend`; identical text/JSON. (Backend list is host‑dependent, identical on a given host.) |

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

---

## How to re‑verify

- **Machine‑verified (deterministic) tools:** `PARITY_STRICT=1 swift test --filter StudioParityTests` → expect `MATCH=266, DIFFERS=0`. Regenerate with `swift run cli-parity-gen`.
- **Non‑deterministic / network tools:** verify by **shared‑engine construction** (both adapters call the same engine — see the call sites cited in [`APP_CLI_SHARED_API.md`](APP_CLI_SHARED_API.md) §3) plus smoke tests, since stable goldens are impossible.
