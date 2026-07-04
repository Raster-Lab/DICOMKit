# App ⇄ CLI Command-Construction Verification

**STATUS: ✅ AUDIT COMPLETE — all 7 phases, 33 tool entries, ~466 flags, 66 agents (Opus Phase 1, Fable Phases 2–7), every divergence adversarially verified.**

## Executive summary

**49 confirmed defect entries (18 High / 24 Med / 7 Low-grouped) + 1 refuted.** 12 of 33 tool
entries were fully clean. The defects cluster into **six root-cause classes**, which is the key
result — most fixes are shared-code changes that repair many tools at once:

| # | Class | Register entries | Shared fix |
|---|-------|-----------------|------------|
| 1 | **Multi-value flag not `isRepeatable`** (repeated-flag / positional-list / space-list) | #1 #2 #4 #5 #6 #10 #12 #14 #19 #20 #38 #46 | `isRepeatable:true` + executor via `splitMultiValue` + **one new positional-list branch in `buildCommand`** (empty flag + repeatable → one escaped token per item) |
| 2 | **Bespoke split conventions** (newline / comma / space vs the semicolon contract) | same entries + #41c | Route every executor through `CommandBuilderHelpers.splitMultiValue`; fix placeholders/help to `;` |
| 3 | **Pre-seeded default port overrides embedded `host:port`** — systemic, all 7 DIMSE tools | #23 | Empty the port `defaultValue` (placeholder only) + emit `--port N` when both present. **Highest-leverage single fix.** |
| 4 | **"Field exists, executor never reads it"** (incl. reading nonexistent ids) | #25 #28 #29 #32 #42 (+verbose family #22 #36 #41) | Per-tool wiring + **CI guard: every non-internal param id must be referenced by its tool's executor, and every `paramValue(id)` must reference a declared id** |
| 5 | **Silent-drop instead of CLI's error** (hex-only parseTag, Double/date coercion, malformed pairs) | #4 #5 #6 #16 #49 | Error + exit 1 on unparseable input, mirroring ArgumentParser/ValidationError |
| 6 | **App-only surface leaking into "paste-runnable" previews** (phantom subcommand, basic-auth token, fictitious flags) | #37 #45 | Suppress/annotate preview when the state is not CLI-representable |

**Most dangerous individual defects:** #3 (dicom-anon silently **overwrites the input file** when
`--output` omitted), #4–#6 (anonymizer keep/remove/replace directives **silently discarded with a
success summary**), #43 (UPS SCHEDULED **claims the workitem IN PROGRESS**), #30 (MPPS update can
emit **non-conformant Referenced SOP**), #27 (retrieve negotiates the **wrong transfer syntax** for
`jpeg-lossless`), #23 (app connects to a **different port** than the previewed command).

**One confirmed CLI-side bug:** #35 (`dicom-qr --transfer-syntax` parsed+printed but never
forwarded) — fix in the CLI, then regenerate CLIContracts.json + goldens per the wire-parity rule.

**Recommended fix order:** (1) #23 systemic port; (2) the `buildCommand` positional-list branch +
all class-1/2 entries in one sweep; (3) dicom-anon cluster #3–#6; (4) the never-read fields
#25/#28/#29/#42 + the two CI guards; (5) #43/#30/#27 protocol-integrity fixes; (6) preview
suppression #37/#45; (7) remaining Med/Low + NOT_IN_APP coverage adds.

---

**Goal:** For every tool × subcommand × flag exposed in the DICOMStudio **CLI Workshop**,
verify that when a user drives the flag from the app UI:

1. the **Command Preview** is valid, copy-pasteable CLI syntax, **and**
2. the app **executes** with the exact effective arguments the real `dicom-*` CLI's
   ArgumentParser would produce from that same command.

The app does **not** shell out — it re-implements each CLI on the shared DICOMKit API — so
these two things live in independent code paths and can silently diverge. The audit checks a
**three-way agreement** per flag and treats the CLI's ArgumentParser declaration as the source
of truth for "what DICOMKit accepts."

> Seed case that motivated this audit: `dicom-xml --filter-tag` is `var filterTag: [String]`
> (a repeatable option), but the app emits `--filter-tag PatientName,Modality` as a single
> token → `Error: Invalid tag`. See Phase 1.

---

## The contract (verified per flag)

Three artifacts must agree, and the preview must run as-is:

| # | Artifact | Source of truth location |
|---|----------|--------------------------|
| 1 | **CLI truth** — the `@Option`/`@Argument`/`@Flag` declaration (type, `name:`, `parsing:`, default, enum choices) | `Sources/dicom-<tool>/*.swift` |
| 2 | **Preview** — `CommandBuilderHelpers.buildCommand` | `Sources/DICOMStudio/Components/CLIWorkshopHelpers.swift:3602` |
| 3 | **Executor** — per-tool `executeDicom<Tool>()` | `Sources/DICOMStudio/ViewModels/CLIWorkshopViewModel.swift` |

App parameter definitions (what the UI exposes): `parameterDefinitions(for:)` in
`Sources/DICOMStudio/Components/CLIWorkshopHelpers.swift` (`case "dicom-<tool>":` blocks).

### The three legal multi-value shapes (pick per flag by the CLI's `parsing:` strategy)

| CLI declaration | Accepted shape | Correct app construction |
|-----------------|----------------|--------------------------|
| Default array `@Option var x: [T]` | **repeated flag** | `--flag A --flag B` — param must set `isRepeatable: true`; executor splits via `CommandBuilderHelpers.splitMultiValue` (`;`) |
| `@Option(parsing: .upToNextOption) var x: [T]` | **one flag, space-separated** | `--flag A B C` |
| `@Argument var x: [T]` / `.remaining` / `.captureForPassthrough` | **bare positional list** | `A B C` (no flag) |
| `@Flag var x: Bool` | boolean presence | `--flag` (never `--flag true`) |
| enum-typed `@Option` | one of a fixed set | value spelled identically to a CLI choice |

`buildCommand` today expands to repeated flags **only** when `isRepeatable: true`
(`CLIWorkshopHelpers.swift:3720`); otherwise it emits `--flag <entire field>` as one token.
`splitMultiValue` uses a **semicolon** separator (`CLIWorkshopHelpers.swift:3761`) — several
executors instead split on newline, a divergence to catch.

### Verdict legend

| Verdict | Meaning |
|---------|---------|
| ✅ OK | Preview + executor both match CLI truth |
| ❌ DIVERGES | Preview and/or executor produce args the CLI would reject or misinterpret |
| ⚠️ NOT_IN_APP | CLI flag not surfaced in the app (coverage gap) |
| ❔ UNCERTAIN | Needs manual confirmation |

Each DIVERGES finding is independently re-checked by an adversarial verifier
(CONFIRMED / REFUTED / PLAUSIBLE) before landing in the register below.

---

## Phase plan & status

| Phase | Category | Tools | Status |
|:-:|----------|-------|:------:|
| 1 | File Inspection & Data Export | dicom-info, dicom-dump, dicom-tags, dicom-diff, dicom-json, dicom-xml | ✅ Complete — 2 defects |
| 2 | File Processing & Conversion | dicom-convert, dicom-validate, dicom-anon, dicom-compress | ✅ Complete — 7 defects |
| 3 | Image & Document Export | dicom-image, dicom-export, dicom-pixedit, dicom-pdf | ✅ Complete — 2 defects |
| 4 | File Organization | dicom-split, dicom-merge, dicom-dcmdir, dicom-archive | ✅ Complete — 7 defects (1 refuted) |
| 5 | Automation | dicom-study, dicom-uid, dicom-script | ✅ Complete — 4 defects |
| 6 | Network (DIMSE) | dicom-echo, dicom-query, dicom-send, dicom-retrieve, dicom-qr, dicom-mwl, dicom-mpps | ✅ Complete — 19 defects (1 systemic ×7 tools) |
| 7 | DICOMweb (WADO family) | dicom-qido, dicom-wado, dicom-stow, dicom-ups | ✅ Complete — 9 defect entries (29 findings) |

*33 tool entries. dicom-qido/wado/stow/ups all map to the `dicom-wado` CLI (subcommands
query/retrieve/store/ups).*

**CLIs present in the repo but NOT surfaced in the CLI Workshop (out of scope for this audit):**
dicom-3d, dicom-ai, dicom-cloud, dicom-gateway, dicom-j2k, dicom-jpip, dicom-measure,
dicom-print, dicom-report, dicom-server, dicom-viewer. (The app executor returns
"not yet supported" for these.)

---

## Confirmed defect register (ranked, running)

_Populated as phases complete and findings pass adversarial verification._

| # | Sev | Tool | Flag | Problem | Correct behavior | Anchor |
|:-:|:---:|------|------|---------|------------------|--------|
| 1 | 🔴 High | dicom-xml | `--filter-tag` | `.arrayField` w/o `isRepeatable` → preview emits one joined token (`--filter-tag PatientName,Modality`); executor newline-split is dead code on a single-line field → any 2+ tag input rejected with `Error: Invalid tag`. | `--filter-tag A --filter-tag B` via `isRepeatable:true` + `splitMultiValue`. | `CLIWorkshopHelpers.swift:2489`; `CLIWorkshopViewModel.swift:1305`; `dicom-xml/main.swift:52` |
| 2 | 🔴 High | dicom-json | `--filter-tag` | Same root cause: preview not paste-runnable for 2+ tags; executor splits on newline while preview uses semicolon. | Same fix as #1. | `CLIWorkshopHelpers.swift:2412`; `CLIWorkshopViewModel.swift:1123`; `dicom-json/main.swift:58` |
| 3 | 🔴 High | dicom-anon | `--output` (omitted) | With no output path on a single file, app **overwrites the input file in place**; CLI writes nothing (`if !dryRun, let outputURL` guard). Silent destruction of the original. | Skip the write when output is empty (mirror CLI guard); warn "no --output given; nothing written". | `SecurityViewModel.swift:536`; `dicom-anon/main.swift:299` |
| 4 | 🔴 High | dicom-anon | `--keep` | `[String]` w/o `isRepeatable`; help says comma-separate (impossible — commas are tag syntax); app `parseTag` is hex-only so keyword entries — incl. the app's own placeholder "Modality" — are **silently discarded and the tag anonymized anyway**, with a success summary. | `isRepeatable:true` + `splitMultiValue` + semicolon help; add CLI `tagFromKeyword` map to `SecurityViewModel.parseTag`; error (not drop) on unparseable. | `CLIWorkshopHelpers.swift:1856`; `SecurityViewModel.swift:626`; `dicom-anon/main.swift:47,202` |
| 5 | 🔴 High | dicom-anon | `--remove` | Same class: 3-way convention mismatch (help=comma, preview=whole-string, executor=newline); multi-value or keyword input silently dropped → tags **not removed** despite success summary. Placeholder "PatientSex" is invalid even for the CLI. | Same fix as #4; fix placeholder to a CLI-accepted keyword. | `CLIWorkshopHelpers.swift:1844`; `CLIWorkshopViewModel.swift:5217`; `dicom-anon/main.swift:41` |
| 6 | 🔴 High | dicom-anon | `--replace` | Same class, aggravated: both tag and value halves may contain commas so the comma advice can never parse; malformed pairs dropped instead of erroring (CLI raises ValidationError). | Same fix as #4; error on '='-less pairs. | `CLIWorkshopHelpers.swift:1850`; `SecurityViewModel.swift:659`; `dicom-anon/main.swift:44,159` |
| 7 | 🟡 Med | dicom-anon | `--audit-log` | App skips the audit log under `--dry-run` (`&& !dryRun` guard); CLI writes it unconditionally — dry-run auditing is a primary use case. Verbose "Audit log written to:" line also missing. | Drop the `&& !dryRun` guard; emit the verbose line. | `SecurityViewModel.swift:562`; `dicom-anon/main.swift:119-126` |
| 8 | 🟡 Med | dicom-validate | `--output` | Directory-valued output: CLI resolves to `<dir>/<input-stem>.json\|.txt` via shared `OutputPathResolver` (built for this parity); app never calls it → writes `output.dat` or redirects to Downloads. Format extension never applied in-app. | Call `OutputPathResolver.resolveFileOutput(...)` in `ValidationViewModel.runValidation` before `OutputAccess.writeString`. | `ValidationViewModel.swift:141`; `DICOMValidate.swift:85-91`; `OutputPathResolver.swift:31` |
| 9 | 🟢 Low | dicom-anon | `--backup` | Backup written next to the **input** (`<input>.backup`); CLI writes it next to the **output** (`<output>.backup`) — different directory whenever output ≠ input. | Change target to `destURL.appendingPathExtension("backup")` (or fix the CLI + regenerate contracts — the two must agree). | `SecurityViewModel.swift:538`; `dicom-anon/main.swift:301` |
| 10 | 🟡 Med | dicom-export | `<inputs>` (contact-sheet) | CLI arity is a **variadic positional list** of files; app models one directory path and only the executor expands it. Pasted preview feeds the directory to the CLI → per-input catch draws a red placeholder → exit 0 with a silently wrong 1-cell sheet. App can't express the N-file form at all. | Dedicated `inputs` param with `isRepeatable:true` + a positional-list branch in `buildCommand` (empty flag + repeatable → one escaped token per `splitMultiValue` item); executor shares the split. | `CLIWorkshopHelpers.swift:3042`; `CLIWorkshopViewModel.swift:4224`; `dicom-export/main.swift:148,232` |
| 11 | 🟡 Med | dicom-pixedit | `--fill-value` | `visibleWhen values: []` is **unsatisfiable** in every evaluator (the only empty-values condition among ~180) → Fill Value field never rendered, flag never in preview, executor silently uses default 0. Non-zero fills (e.g. −1024 air for signed CT) can't be expressed. Live parity panel reports it missing; committed goldens only sweep `--fill-value 0`, masking it. | Drop the `visibleWhen` from the fill-value definition (field is harmless when mask-region empty); add a non-zero fill parity scenario. | `CLIWorkshopHelpers.swift:2910`; `CLIWorkshopViewModel.swift:1013-1020`; `dicom-pixedit/main.swift:45` |
| 12 | 🔴 High | dicom-archive | `<files>` (import) | Three-way divergence on the positional file list: preview joins N paths into **one token**; executor splits on **spaces** (a typed macOS path with a space silently becomes two bogus paths); a picked scoped URL **silently drops** all additional typed paths. | `isRepeatable:true` + positional-list branch in `buildCommand` (same as #10); executor via `splitMultiValue`; union scoped URL with typed paths. | `CLIWorkshopHelpers.swift:2249`; `CLIWorkshopViewModel.swift:2993-2998`; `dicom-archive/main.swift:99` |
| 13 | 🟡 Med | dicom-dcmdir | `--recursive`/`--no-recursive` (create) | CLI flag is `@Flag(inversion: .prefixedNo)` **default true**; toggle OFF → preview omits any token → pasted command recurses while the in-app run didn't. `buildCommand` has no inverted-flag concept. | Add a negated-flag notion (e.g. `cliMapping ["true": "--recursive", "false": "--no-recursive"]`) and emit the negated token when the toggle is false. | `CLIWorkshopHelpers.swift:2665,3686-3689`; `CLIWorkshopView.swift:766`; `dicom-dcmdir/main.swift:65` |
| 14 | 🟡 Med | dicom-merge | `<inputs>` | CLI accepts **N positional roots** and merges across series/studies; app field is one non-repeatable path — multi-path input fails on both surfaces and the CLI's multi-input capability is unreachable from the Workshop. | Same positional-list fix as #10/#12; executor iterates `splitMultiValue` roots through `gatherInputFiles`. | `CLIWorkshopHelpers.swift:2167`; `CLIWorkshopViewModel.swift:2778`; `DICOMMerge.swift:40,126-177` |
| 15 | 🟡 Med | dicom-archive | `--output` (export) | CLI requires `--output`; app has no empty guard → `URL(fileURLWithPath: "")` resolves to the process **CWD** and the app silently exports there (or opaque sandbox error) instead of a missing-argument error. | Guard empty output in the export branch (mirror the archive-path guard at VM:2927). | `CLIWorkshopViewModel.swift:2975`; `ArchiveStore.swift:661`; `dicom-archive/main.swift:197` |
| 16 | 🟢 Low | dicom-split | `--window-center`, `--window-width` | Non-numeric input silently coerced to `nil` (`Double(...)`) → run "succeeds" without the requested window; CLI exits with an invalid-value error for the same pasted command. | Error + exit 1 when non-empty field fails `Double()` parse (mirror the frames parse-error path VM:2577). | `CLIWorkshopViewModel.swift:2551-2552`; `dicom-split/DICOMSplit.swift:56` |
| 17 | 🟢 Low | dicom-split | `--recursive` (dir walk) | Executor hand-rolls the directory walk (`.skipsHiddenFiles`, unsorted) instead of the shared `FrameSplitter.processDirectory` (includes hidden files, sorted) → hidden `.foo.dcm` skipped only in-app; output ordering differs. | Replace the bespoke walk with `splitter.processDirectory(...)` — the CLI's exact call. | `CLIWorkshopViewModel.swift:2636-2668`; `FrameSplitter.swift:147-160,332-367` |
| 18 | 🟢 Low | dicom-merge | `--format` (verbose) | ~~Format dropped~~ **refuted**: `FrameMerger` ignores `format` everywhere, so CLI and app bytes are identical. Residue: executor hardcodes `.standard` and the verbose banner omits the CLI's `Format:` line. | Read the param, pass it through, add the banner line (future-proofs when FrameMerger implements enhanced formats). | `CLIWorkshopViewModel.swift:2887`; `FrameMerger.swift:42,232-276`; `DICOMMerge.swift:84` |
| 19 | 🔴 High | dicom-script | `--variables` (run) | First **space-list** (`.upToNextOption`) divergence. Three-way disagreement with **no separator a user can type that works on both surfaces**: preview emits one joined `--variables` token (unquoted `;` even breaks shell parsing); executor's comma-or-space split corrupts values containing spaces/commas and silently drops malformed pairs (CLI errors on them). | `isRepeatable:true` (ArgumentParser accepts repeated occurrences for `.upToNextOption` arrays — each appends) + executor via `splitMultiValue`; error on `=`-less pairs. | `CLIWorkshopHelpers.swift:3508`; `CLIWorkshopViewModel.swift:4497`; `dicom-script/main.swift:58,93-103` |
| 20 | 🟡 Med | dicom-uid | `validate <uids>` | 4th positional-list instance: field "1.2.3 4.5.6" validates two UIDs in-app but pastes as ONE positional → CLI reports "Contains invalid characters", exit 1. Executor uses bespoke comma/space/tab/newline splitter. | Same positional-list fix (#10/#12/#14) + executor via `splitMultiValue`; update help from "space/comma separated" to semicolons. | `CLIWorkshopHelpers.swift:2544`; `CLIWorkshopViewModel.swift:1519-1522`; `dicom-uid/main.swift:118` |
| 21 | 🟢 Low | dicom-uid | `regenerate --maintain-relationships` | **NOT_IN_APP** — CLI flag has no app param; executor pins `false`. Has a real single-file effect (intra-file duplicate UID mapping), so a Workshop user can't reproduce that CLI run. | Add booleanToggle def (visibleWhen subcommand==regenerate) and pass into `UIDManager.regenerateData(...)`. | `CLIWorkshopHelpers.swift:2591-2624`; `CLIWorkshopViewModel.swift:1757`; `dicom-uid/main.swift:355,422` |
| 22 | 🟢 Low | dicom-study | `compare --verbose` | Executor hardcodes `verbose: false` and never reads the toggle (unlike organize/summary/check siblings). Latent today — the shared renderer ignores its verbose param — but diverges silently the day it doesn't. | Read the toggle like siblings and pass through at VM:3801. | `CLIWorkshopViewModel.swift:3801`; `StudyManager.swift:336-375` (DICOMKit); `dicom-study/main.swift:181` |
| 23 | 🔴 High | **all 7 DIMSE tools** | `--port` (systemic) | Tool selection **pre-seeds every non-empty `defaultValue` as a real param value** (VM:411-413), so Port is never empty; `resolveHostPort` then lets it **unconditionally override an embedded `host:port`** (VM:5085-5088). Host `server:4242` + untouched Port → app connects to **11112** while the pasted preview (`dicom-* server:4242 …`) connects to 4242. Reverse case: explicit port + embedded host → preview drops the `--port` token. | **TRIAGE 2026-07-03: ACCEPTED AS-IS (user decision) — no change.** Current app behavior kept deliberately. | `CLIWorkshopViewModel.swift:411-413,5085-5088`; `CLIWorkshopHelpers.swift:3628-3645` |
| 24 | 🔴 High | dicom-query | `--level` | Executor switch maps `PATIENT/SERIES/IMAGE` but the picker value is **`instance`** → hits `default:` → **silently runs a STUDY-level C-FIND** while the pasted `--level instance` correctly queries image level. | Add `case "INSTANCE"` (or reuse the CLI's `QueryLevelOption` rawValues so picker and enum can't drift). | `CLIWorkshopViewModel.swift:7341-7347`; `CLIWorkshopHelpers.swift:418`; `DICOMQuery.swift:184,191` |
| 25 | 🔴 High | dicom-retrieve | `--uid-list` (+ `--parallel`) | Field exists in UI and preview but **executor never reads it** (`uid-list` appears nowhere in the VM): filling only the UID List File → in-app error "At least one UID is required" while the identical pasted command performs a bulk retrieval. `--parallel` (bulk batch size) equally dead. | Implement the bulk path: load UIDs with the CLI's convention (newline, `#`-comments), include in the guard, loop with `--parallel` batching. | `CLIWorkshopViewModel.swift:7903-7909`; `DICOMRetrieve.swift:121-123,240-246`; `RetrieveExecutor.swift:60-94` |
| 26 | 🔴 High | dicom-retrieve | `--instance-uid` | Instance UID without Series UID: level dispatch needs BOTH non-empty → falls through to `moveStudy/getStudy` and **retrieves the ENTIRE study while the header claims "Instance"**. CLI rejects this state with ValidationError. | Resolve the series UID in the existing C-FIND lookup then call `moveInstance/getInstance`, or reject like the CLI. | `CLIWorkshopViewModel.swift:8048,8100,8081-8096`; `DICOMRetrieve.swift:125-127` |
| 27 | 🔴 High | dicom-retrieve | `--transfer-syntax` | Executor uses a private hand-rolled alias map: `jpeg-lossless` → **`.4.70` (SV1)** while the CLI's shared `TransferSyntax.parse` yields **`.4.57` (Process 14)** — C-GET negotiates a different TS than the identical pasted command. | Delete `transferSyntaxUID(for:)` (VM:8851-8867); use `TransferSyntax.parse(name)?.uid` at both call sites (retrieve 8025, qr 8235); error on nil like the CLI. | `CLIWorkshopViewModel.swift:8851-8867`; `TransferSyntax.swift:556-557,134-135`; `DICOMRetrieve.swift:106-113` |
| 28 | 🔴 High | dicom-mwl | `--accession-number` | Executor never reads the field: `WorklistQueryKeys.forQuery` call omits `accession:` (defaults `""`) → the typed filter shows in the preview but is **silently dropped from the in-app C-FIND**, returning an unfiltered result set. | Read the param, pass `accession:`, add the `Accession:` verbose filter line. | `CLIWorkshopViewModel.swift:8496-8503`; `ModalityWorklistService.swift:249`; `DICOMMWLCommand.swift:194` |
| 29 | 🔴 High | dicom-mpps | `--sps-id` | Executor never reads it; `DICOMMPPSService.create` called without `scheduledProcedureStepID` → **the MWL SCHEDULED→IN PROGRESS linkage the help text promises never happens** in-app; pasted command works. | Read `sps-id`, pass `scheduledProcedureStepID:`, add the `SPS ID:` header line. | `CLIWorkshopViewModel.swift:8885-8887,8967-8978`; `DICOMMPPSCommand.swift:159-171` |
| 30 | 🔴 High | dicom-mpps | `--study-uid` (update) | Field hidden in update mode, yet the executor reads the stale invisible value and, when empty, **substitutes the MPPS SOP Instance UID as the Referenced Study Instance UID** — transmitting a non-conformant Referenced SOP Sequence the CLI (requiring study+series) would never emit. | Make study-uid visible in update mode; remove the `mppsUID` fallback; gate refs on study+series like the CLI. | `CLIWorkshopViewModel.swift:8995,8993`; `CLIWorkshopHelpers.swift:1118`; `DICOMMPPSCommand.swift:259-264` |
| 31 | 🟡 Med | dicom-qr | mode picker (`--interactive/--auto/--review`) | (1) Label switch matches `"automatic"` but the picker value is `"auto"` → Automatic runs print "Mode: Interactive" (guaranteed terminal-compare DIFFERS). (2) In-app Interactive **retrieves ALL studies with no selection step** — behaves like `--auto` while previewing `--interactive`. | Fix the label case; surface a selection UI or map app-Interactive to `--auto` in the preview. | `CLIWorkshopViewModel.swift:8226-8232,8327`; `DICOMQR.swift:184` |
| 32 | 🟡 Med | dicom-qr | `--validate` | Executor reads the toggle and discards it (`let _ = …`) — no validation pass, none of the CLI's validation output. | Implement the post-summary validation pass mirroring `DICOMQR.validateRetrievedFiles`. | `CLIWorkshopViewModel.swift:8195`; `DICOMQR.swift` validate path |
| 33 | 🟡 Med | dicom-qr | `--patient-name` | CLI uppercases the match key (`name.uppercased()`); app sends verbatim → on case-sensitive PACS, result sets silently differ; header shows raw value on both sides so terminal-compare can't catch it. | `patientName.uppercased()` at VM:8273 (or drop it in the CLI and regenerate goldens — align both). | `CLIWorkshopViewModel.swift:8273`; `DICOMQR.swift:344` |
| 34 | 🟡 Med | dicom-qr | `--move-dest` | CLI requires it for c-move even in `--review`; app only enforces when not review → review+c-move+no-dest runs in-app but the pasted preview exits with an error. | Align both (either relax the CLI or tighten the executor) + regenerate goldens. | `CLIWorkshopViewModel.swift:8216`; `DICOMQR.swift:167-172` |
| 35 | 🟡 Med | dicom-qr | `--transfer-syntax` | **CLI-side bug**: CLI parses and prints the TS but never forwards it (`RetrieveExecutor` has no TS field); the app DOES forward it → C-GET negotiates the requested TS in-app but not from the terminal. | Fix the CLI (its help promises the behavior): add TS to `RetrieveExecutor`, share one alias map (hoist into DICOMKit) — then #27's map fix covers both. | `DICOMQR.swift:192,757-765`; `CLIWorkshopViewModel.swift:8363`; `RetrieveService.swift:545-554` |
| 36 | 🟡 Med | dicom-mwl | `--verbose` / `--json` | Executor never reads verbose; prints the query header unconditionally and hardcodes `verbose:false` in `mwlItem`. In JSON mode the header precedes the array — CLI prints ONLY the array (header gated `verbose && !json`) — contradicting the code's own first-`[`…last-`]` contract comment. | Read verbose; gate the header `if verbose && !jsonOutput`; pass verbose to `mwlItem`. | `CLIWorkshopViewModel.swift:8470,8485-8488,8535`; `DICOMMWLCommand.swift:114-119,168` |
| 37 | 🟡 Med | dicom-mwl | `create` subcommand | App offers a `create` operation the **real CLI does not have** (only `Query` is registered) → preview `dicom-mwl create …` is fake-runnable ("Unexpected argument 'create'"). The create-* fields are correctly `isInternal`; only the subcommand token leaks. | **TRIAGE 2026-07-03 (user decision): implement ONLY the in-app-only marking — banner / suppressed preview when operation=create (end-user facing). Keep the create feature itself.** | `CLIWorkshopHelpers.swift:792,3706-3710`; `DICOMMWLCommand.swift:50` |
| 38 | 🟡 Med | dicom-mpps | `--image-uid` | Three-way: preview omits the UIDs entirely; stored flag name `--image-uids` doesn't exist in the CLI (real: `--image-uid`); executor splits on comma (vs semicolon contract). | Rename to `--image-uid`, `isRepeatable:true`, semicolon placeholder, executor via `splitMultiValue`. | `CLIWorkshopViewModel.swift:8994`; `CLIWorkshopHelpers.swift` mpps image-uids def |
| 39 | 🟡 Med | dicom-retrieve | `--series-uid` | App resolves the missing Study UID via C-FIND (convenience) but the preview in that state is not paste-runnable — CLI throws "requires --study-uid". Execution OK, preview wrong. | Require study-uid in UI validation, or substitute the resolved study UID into the recorded/preview command. | `CLIWorkshopViewModel.swift:7925-8016`; `DICOMRetrieve.swift:121-127` |
| 40 | 🟡 Med | dicom-qr | `--accession-number` | **NOT_IN_APP** — no field, yet the executor contains fully-wired but unreachable handling under id `"accession"` (definition dropped or never added). | Add the textField definition; existing executor code then works as-is. | `CLIWorkshopViewModel.swift:8191,8249,8278`; qr param list |
| 41 | 🟢 Low | DIMSE misc | grouped | (a) echo example presets emit `--host/--port` flags the CLI doesn't have → presets not paste-runnable; (b) send `--verbose` dead (gather warnings never shown); (c) send `<paths>`: multi-file via UI runs but preview omits the files (PLAUSIBLE); (d) mpps update leaks a hidden stale `accession-number` into the N-SET (CLI update has no such option); (e) mpps `--verbose`: header printed unconditionally; (f) qr `--save-state`/`resume`/query-`--verbose` NOT_IN_APP (document in contracts). | **TRIAGE 2026-07-03 (user decision): (a) ACCEPTED AS-IS — leave presets unchanged. Fix the remaining items (b)–(f).** | various (Phase 6) |
| 42 | 🔴 High | dicom-ups | `--aet` (change-state) | Executor reads `paramValue("called-aet")` — **a param id that doesn't exist for this tool** — so it's always empty and falls back to hardcoded `"DCM4CHEE"`. The user's typed Requesting AE (`change-state-aet`) is **never read**: preview shows `--aet <typed>`, execution silently sends DCM4CHEE. | Read `paramValue("change-state-aet")` instead. One-line fix. | `CLIWorkshopViewModel.swift:6990-6992` |
| 43 | 🔴 High | dicom-ups | `--state` | State switch only maps COMPLETED/CANCELED; everything else defaults to IN PROGRESS → selecting the picker's own **SCHEDULED silently CLAIMS the workitem** (IN PROGRESS + generated Transaction UID) instead of a SCHEDULED transition. | Add explicit SCHEDULED case; honor the user's transaction UID; exclude from the auto-generate branch. | `CLIWorkshopViewModel.swift:6945-6950,7076-7081`; `DICOMWado.swift:1138-1163` |
| 44 | 🟡 Med | dicom-ups | `--subscribe`/`--unsubscribe` | CLI supports **global** (un)subscription when `--workitem-uid` omitted; app executor hard-rejects the empty UID ("Workitem UID is required") — the empty-UID preview is paste-runnable but fails in-app. | **TRIAGE 2026-07-03: ACCEPTED AS-IS (user decision) — no change.** | `CLIWorkshopViewModel.swift:7153-7158,7217-7222`; `DICOMWado.swift:1215-1278` |
| 45 | 🟡 Med | WADO family (qido/wado/stow; ups low) | `--token` with basic auth | The app-only Authentication=basic mode executes HTTP **Basic** (username+password) but the preview emits `--token <password>` — the CLI maps `--token` to **Bearer** only. Pasted command authenticates with the wrong scheme (401, or worse, a different identity). `--username` is a fictitious flag kept out of the preview only by `isInternal`. | Scope token's preview emission to auth=bearer (visibleWhen), or annotate/suppress the preview under basic auth ("# basic auth not supported by dicom-wado"). | `DICOMWado.swift:118-119,493-496`; `DICOMwebClientFactory.swift:58-60`; VM:5996-5998 |
| 46 | 🟡 Med | dicom-stow | `<files>` | 5th positional-list instance + a **third split convention**: executor splits the field on **comma** (not the documented semicolon; a path containing a comma mis-splits); preview emits the whole field as one token (not paste-runnable for multi-file). | Same positional-list fix (#10/#12/#14/#20) + executor via `splitMultiValue`. | `CLIWorkshopViewModel.swift:6602`; `CLIWorkshopHelpers.swift:3693-3695` |
| 47 | 🟡 Med | dicom-wado | `--frames` (URI mode) | Bespoke parse: no whitespace trim (`' 1,2'` → CLI retrieves frame 1, app silently retrieves the **whole object**) and `0` treated as nil (CLI sends `frameNumber=0` and surfaces the server error). RS mode is correct (shared parser). | Use the CLI's construction (trim + `flatMap Int`) or the shared `parseFrameNumbers`. | `CLIWorkshopViewModel.swift:6355,6411`; `DICOMWado.swift:169-175` |
| 48 | 🟡 Med | dicom-qido | `--study` scoping; `--series`/`--accession-number` missing | CLI **path-scopes** (`GET /studies/{uid}/series`…) when `--study` set; app always queries root resources with the UID as a query param — fails on servers without the optional all-series/all-instances resources. `--series` and `--accession-number` have **no app field at all**. | Mirror the CLI's path-scoped dispatch; add the two missing textField definitions. | `CLIWorkshopViewModel.swift:6048-6061`; `DICOMWado.swift:559-597,464-465` |
| 49 | 🟡 Med | dicom-ups | `--scheduled-start` | Unparseable date **silently dropped** (workitem created without a start; CLI throws ValidationError) and the app's ISO-8601 fallback list omits `yyyyMMdd'T'HHmmss` / `yyyyMMdd` which the CLI accepts — `20260320` works in terminal, silently ignored in-app. | Add the two compact formats; turn parse failure into console error + exit 1. | `CLIWorkshopViewModel.swift:6843-6847,7312`; `DICOMWado.swift:1042,1114-1120` |
| 50 | 🟢 Low | DICOMweb misc | grouped | (a) ups: **10 create-metadata CLI options NOT_IN_APP** (`--patient-birth-date`, `--patient-sex`, `--referring-physician`, `--procedure-id`, `--step-id`, `--worklist-label`, `--expected-completion`, `--performer-organization`, `--admission-id`, `--create` alias) — CLI create runs can't be fully reproduced; (b) ups `--transaction-uid` ignored on cancel path; (c) ups/qido `--verbose` divergences; (d) qido app-only internal `--timeout` never emitted (benign); (e) stow `--input` dir-vs-files nuance. | Add fields incrementally or record exclusions in CLIContracts.json. | Phase 7 section |

---

## Phase 1 — File Inspection & Data Export

**Tools:** dicom-info · dicom-dump · dicom-tags · dicom-diff · dicom-json · dicom-xml
**Status:** ✅ Complete · 6 tools / ~59 flags audited · **2 confirmed defects** (both `--filter-tag`) · 3 low-severity notes
**Method:** 1 audit agent/tool + adversarial verifier on every divergence (8 agents, all Opus).

### Per-tool verdicts

| Tool | Flags | Result |
|------|:-----:|--------|
| dicom-info | 6 | ✅ Clean. `--tag` (`[String]`) correctly `isRepeatable:true` → `--tag A --tag B`; executor shares `splitMultiValue`. |
| dicom-dump | 10 | ✅ Clean (2 low notes). No multi-value flags — every option is scalar. |
| dicom-tags | 9 | ✅ Clean. `--set`/`--delete` correctly repeatable; `--tags` correctly **single** (CLI comma-splits internally; executor matches). |
| dicom-diff | 10 | ✅ Clean (1 low note). `--ignore-tag` correctly repeatable. |
| dicom-json | 13 | ❌ **1 defect** — `--filter-tag` (register #2). |
| dicom-xml | 11 | ❌ **1 defect** — `--filter-tag` (register #1). |

### 🔑 Structural finding — `.arrayField` is a false friend

The `.arrayField` parameter type provides **no** multi-value behavior on its own:
- In the view it has no dedicated case and renders as a plain **single-line `TextField`**
  (`CLIWorkshopView.swift:751-756`) — it cannot hold newlines.
- In `buildCommand` it has no `case` and falls to the single-token `else` branch.

Multi-value correctness comes **entirely** from `isRepeatable: true` (drives the `buildCommand`
repeated-flag expansion) **+** the executor calling `CommandBuilderHelpers.splitMultiValue`
(semicolon). Every *correct* multi-value flag in Phase 1 (`dicom-info --tag`,
`dicom-tags --set/--delete`, `dicom-diff --ignore-tag`) uses `.textField` + `isRepeatable:true`.
Both *broken* flags use `.arrayField` **without** `isRepeatable`.
**→ In later phases, treat any `.arrayField` (or any `[String]` CLI option) whose app param
lacks `isRepeatable:true` as a probable defect.**

### Confirmed defects — the `--filter-tag` class (register #1 & #2)

`dicom-xml --filter-tag` and `dicom-json --filter-tag` are both `@Option var filterTag: [String]`
(repeated-flag arity). Neither app param sets `isRepeatable:true`, so:

- **Preview:** `buildCommand` emits the whole field as one token → e.g. `--filter-tag PatientName,Modality`.
  For 2+ tags this is not paste-runnable; the CLI binds one value and rejects the rest as an
  unexpected positional argument.
- **Executor:** splits on **newline** (`\n`/`\r`) while `buildCommand`/`splitMultiValue` use
  **semicolon** — inconsistent conventions. On a single-line field the newline split is dead code,
  so the whole entry is treated as one tag → `Error: Invalid tag`.
- Works for exactly one tag; breaks at two. The advertised "Multiple values allowed" is non-functional.

**Shared fix (apply to both together):** (a) `isRepeatable: true` on the `filter-tag`
`CLIParameterDefinition`; (b) replace the bespoke newline split in the executor with
`CommandBuilderHelpers.splitMultiValue(...)`; (c) change placeholder/help ("One per line." /
"e.g. PatientName, 0010,0010") to a semicolon example ("PatientName; 0010,0010") and fix the
misleading executor comment claiming the CLI "splits on newlines" (it never splits — one value per flag).

### Low-severity notes (not command-construction defects — no fix required)

- **dicom-dump `--no-color`** — executor hardcodes `useColor:false` (SwiftUI console strips ANSI); toggle is a no-op on in-app output. Preview is correct; intentional.
- **dicom-dump `--bytes-per-line`** — modeled as enumPicker {8,16,32} while the CLI accepts any `Int`; a non-empty default also makes the preview always emit `--bytes-per-line 16` (redundant but valid).
- **dicom-diff `--tolerance`** — CLI type is `Double`; app constrains to an integer field clamped 0–255, so fractional / large tolerances can't be entered. Input-domain narrowing only; construction is correct.

---

## Phase 2 — File Processing & Conversion

**Tools:** dicom-convert · dicom-validate · dicom-anon · dicom-compress
**Status:** ✅ Complete · 4 tools / 58 flags audited · **7 confirmed defects** (4 High, 2 Med, 1 Low) · run in Fable mode (6 agents)

### Per-tool verdicts

| Tool | Flags | Result |
|------|:-----:|--------|
| dicom-convert | 13 | ✅ Clean. TS parsing, format enum, window flags all route through the shared `DICOMConverter`/`DICOMImageExporter` — single source of truth on both paths. Sandbox output redirects are deliberate app accommodations, not defects. |
| dicom-compress | 22 | ✅ Clean (largest surface so far: 5 subcommands). Shared `CompressionConsole` holding. |
| dicom-validate | 9 | ❌ **1 defect** — `--output` directory resolution (register #8). |
| dicom-anon | 14 | ❌ **6 defects** — register #3–#7, #9. Worst tool audited so far. |

### dicom-anon — the `--filter-tag` class, weaponized

`--remove`, `--replace`, `--keep` are all repeated-flag `[String]` options, all missing
`isRepeatable`, and their help text advises **comma** separation — impossible, since commas are
part of the `GGGG,EEEE` tag syntax itself. The F19 comment (`CLIWorkshopViewModel.swift:5213-5216`)
correctly bans comma-splitting but picked **newline** instead of the established semicolon
`splitMultiValue` convention — on a single-line TextField, dead code (same trap as Phase 1).

Compounding it: `SecurityViewModel.parseTag` is **hex-only**, while the CLI accepts 11 keyword
names via `tagFromKeyword` (`main.swift:202-219`). Keyword entries are silently `compactMap`-dropped
— including the app's own placeholder suggestions. For an anonymizer, "keep/remove directive
silently ignored + success summary" is the worst possible failure mode. #3 (in-place overwrite of
the source file when output is empty) is flat-out data-destroying.

### Cross-cutting executor findings (beyond arg construction — tracked, not yet in register)

- **dicom-validate false success on slow runs:** `executeDicomValidate` polls `vm.isRunning` with a
  hard **3-second cap** (`CLIWorkshopViewModel.swift:5145-5149`); big recursive runs time out mid-flight
  and report exit 0 with partial output. Fix: await the VM task instead of a bounded poll.
- **Second bespoke command builder:** `ValidationHelpers.buildCommand` (`ValidationModel.swift:182-204`)
  formats a "Running: …" line differently from the Workshop preview — two builders that can drift.
- **dicom-anon exit-code sniffing:** app derives exit code from `output.contains("error")`
  (`CLIWorkshopViewModel.swift:5262-5263`); CLI exits non-zero if any file failed — "Failed: 1" without
  the word "error" reports success in-app.

---

## Phase 3 — Image & Document Export

**Tools:** dicom-image · dicom-export · dicom-pixedit · dicom-pdf
**Status:** ✅ Complete · 4 tools / 65 flags audited · **2 confirmed defects** (2 Med) · Fable mode (6 agents)

### Per-tool verdicts

| Tool | Flags | Result |
|------|:-----:|--------|
| dicom-image | 15 | ✅ Clean. All scalar metadata options map 1:1; UID auto-generation and validation messages mirror the CLI exactly. |
| dicom-pdf | 15 | ✅ Clean. Shared `EncapsulatedDocumentWorkflow` holding on both paths. |
| dicom-export | 25 (4 subcommands) | ❌ **1 defect** — contact-sheet `<inputs>` positional list (register #10). `--format` collisions across subcommands correctly resolved via mutually-exclusive `visibleWhen`. |
| dicom-pixedit | 10 | ❌ **1 defect** — `--fill-value` unreachable (register #11). Executor otherwise mirrors CLI validation order byte-for-byte. |

### 🔑 New defect class — unsatisfiable `visibleWhen`

`dicom-pixedit --fill-value` declares `visibleWhen: CLIParameterVisibilityCondition(parameterId:
"mask-region", values: [])`. An empty `values` array can never match (`values.contains(x)` is
always false), and the **same contains-based check is implemented in four evaluators**
(`satisfiesVisibility`, `buildCommand`, `validateRequired`, `CLIParityEngine`). Result: the field
is invisible in both Beginner and Advanced modes, the flag never reaches the preview, and
execution silently uses the default. It's the only empty-values condition in the ~180-condition
catalog — an authoring error, not a convention.
**→ Cheap global check for later phases / CI: grep for `values: []` in visibleWhen conditions.**

### Also confirmed in Phase 3

- First **positional-list** arity divergence (dicom-export contact-sheet) — the third multi-value
  shape from the methodology finally exercised; `buildCommand` has no branch for it (empty flag +
  repeatable is currently unreachable), which the #10 fix must add.
- Verifier correction worth keeping: `minValue`/`maxValue` on `CLIParameterDefinition` are **dead
  metadata** — stored but never enforced by any view, validator, or executor. Integer bounds
  cited in earlier phases are advisory only.

### Non-defect behavioral notes

- **dicom-export bulk** — CLI always exits 0 after the summary (per-file errors caught); app behavior tracked in the cross-cutting exit-code review.
- **dicom-image `--series-number`/`--instance-number`** — UI integer fields make the CLI's parse-error paths unreachable (benign narrowing).

---

## Phase 4 — File Organization

**Tools:** dicom-split · dicom-merge · dicom-dcmdir · dicom-archive
**Status:** ✅ Complete · 4 tools / 51 flags audited · **7 confirmed defects** (1 High, 3 Med, 3 Low) + **1 refuted** · Fable mode (8 agents — every tool hit the verify stage)

### Per-tool verdicts

| Tool | Flags | Result |
|------|:-----:|--------|
| dicom-split | 10 | ❌ 3 Low — silent `Double()` coercion on window params (#16); bespoke dir walk skips hidden files / unsorted (#17). |
| dicom-merge | 9 | ❌ 1 Med (#14 positional-list) · 1 **refuted** (#18 — `--format` is a no-op in `FrameMerger` itself, so no byte divergence). |
| dicom-dcmdir | 15 (4 subcommands) | ❌ 1 Med (#13) — **new class: inverted flag** (`.prefixedNo`). |
| dicom-archive | 17 (5 subcommands) | ❌ 1 High (#12 import `<files>`) + 1 Med (#15 export `--output` unguarded). |

### 🔑 New defect class — inverted flags (`@Flag(inversion: .prefixedNo)`, default `true`)

`buildCommand`'s `.booleanToggle` case emits the flag only when the value is `"true"` — it has no
concept of a negated token. For a default-true CLI flag, toggling OFF must emit `--no-<flag>`;
omitting it means the pasted command re-enables the behavior the user disabled. Confirmed on
`dicom-dcmdir create --recursive`. Global grep for `inversion:` run: the only other two are in
`dicom-report` (not surfaced in the Workshop) — **the class is fully covered by #13.**

### 🔑 Recurring class — positional lists (now 3 instances)

dicom-export contact-sheet (#10), dicom-archive import (#12), dicom-merge (#14) all declare
`@Argument var x: [String]` while the app models a single path. The shared fix is one change:
honor `isRepeatable` in `buildCommand`'s empty-flag `.filePath` branch (emit one escaped token per
`splitMultiValue` item) — then per-tool executor updates. #12 is the worst: the executor splits on
**spaces**, so even a single path containing a space breaks in-app.

### Adversarial-verify value demonstrated

The dicom-merge `--format` finding entered as High ("app produces different DICOM objects") and
was **refuted** by the verifier: `FrameMerger` declares but never reads `format`, so both surfaces
produce identical bytes today. Downgraded to Low (verbose-banner + future-proofing). This is the
false-positive class the two-stage design exists to catch.

### Non-defect notes

- dicom-split `--frames` — comma/range syntax is a **single-token value** (correctly NOT semicolon-expanded); executor's parse mirrors the CLI faithfully except a whitespace-only segment (`'1, ,3'`) that the CLI rejects and the app skips. Consider moving `parseFrameRange` into DICOMKit to share.
- dicom-split `--output` empty → `"."` matches the CLI default; sandbox redirect is a deliberate affordance.

---

## Phase 5 — Automation

**Tools:** dicom-study · dicom-uid · dicom-script
**Status:** ✅ Complete · 3 tools / 41 flags audited · **4 confirmed defects** (1 High, 1 Med, 2 Low) · Fable mode (6 agents)

### Per-tool verdicts

| Tool | Flags | Result |
|------|:-----:|--------|
| dicom-study | 17 (5 subcommands) | ❌ 1 Low (#22 compare `--verbose` hardcoded false). Subcommand routing, scoped `--format` visibility, shared StudyScanner/StudyReport all clean. |
| dicom-uid | 17 (4 subcommands) | ❌ 1 Med (#20 validate `<uids>` positional-list) + 1 Low (#21 first **NOT_IN_APP** coverage gap). |
| dicom-script | 7 | ❌ **1 High (#19)** — `--variables`, the methodology's space-list case, realized. |

### 🔑 All three multi-value shapes now have confirmed instances

| Shape | Confirmed instances |
|-------|--------------------|
| repeated-flag | #1 dicom-xml, #2 dicom-json, #4–#6 dicom-anon |
| positional-list | #10 dicom-export, #12 dicom-archive, #14 dicom-merge, #20 dicom-uid |
| space-list (`.upToNextOption`) | #19 dicom-script `--variables` |

#19 is the purest form of the bug: there is **no separator the user can type** that both surfaces
handle — semicolon breaks the pasted shell command (unquoted `;`), space collapses into one quoted
CLI element, comma corrupts comma-containing values in-app. Fix note from the verifier worth
keeping: ArgumentParser **accepts repeated flag occurrences for `.upToNextOption` arrays** (each
appends), so the standard `isRepeatable:true` expansion is valid CLI syntax here too — the
established pattern covers all three shapes once `buildCommand` learns the positional-list branch.

### Non-defect notes

- dicom-study organize `--copy` — app defaults the toggle ON while the CLI defaults to move; consistent on both surfaces (explicit `--copy` in preview), reads as a deliberate safer in-app default.
- dicom-uid validate `--file` and generate/lookup/regenerate paths all clean; the `regenerate` executor is a documented single-file subset of the CLI's multi-file form.

---

## Phase 6 — Network (DIMSE)

**Tools:** dicom-echo · dicom-query · dicom-send · dicom-retrieve · dicom-qr · dicom-mwl · dicom-mpps
**Status:** ✅ Complete · 7 tools / 110 flags audited · **19 confirmed defect entries** (#23–#41; 8 High, 10 Med, grouped Lows) · Fable mode (14 agents — every tool hit verify)

### Per-tool verdicts

| Tool | Flags | Result |
|------|:-----:|--------|
| dicom-echo | 9 | ❌ systemic #23 + example presets emit non-existent `--host/--port` flags (#41a) |
| dicom-query | 17 | ❌ #23 + **`--level instance` silently runs a study-level C-FIND** (#24) |
| dicom-send | 13 | ❌ #23 + dead `--verbose` (#41b), preview omits picked files (#41c). `--transfer-syntax` NOT_IN_APP is **correct** (deliberate as-is policy, documented in-code) |
| dicom-retrieve | 16 | ❌ #23 + `--uid-list` unimplemented (#25), instance-scope bug (#26), **wrong TS UID map** (#27), `--series-uid` preview (#39) |
| dicom-qr | 23 | ❌ #23 + mode mislabel/behavior (#31), `--validate` discarded (#32), patient-name casing (#33), move-dest order (#34), TS **CLI-side bug** (#35), accession NOT_IN_APP with orphaned executor wiring (#40), save-state/resume gaps (#41f) |
| dicom-mwl | 15 | ❌ #23 + **accession filter silently dropped** (#28), verbose/json header gating (#36), phantom `create` subcommand in preview (#37) |
| dicom-mpps | 17 | ❌ #23 + **`--sps-id` silently dropped** (#29), **update Referenced-SOP built from MPPS UID fallback** (#30), `--image-uid` three-way (#38), hidden accession leak into N-SET (#41d) |

### 🔑 Systemic defect #23 — pre-seeded default port overrides embedded `host:port` (all 7 tools)

Two interacting mechanisms, each innocent alone:
1. `updateSelectedTool` **materializes every non-empty `defaultValue` into `parameterValues`**
   (`CLIWorkshopViewModel.swift:411-413`) — so the Port field always holds `"11112"` as a *real* value.
2. The shared `resolveHostPort` treats any non-empty port as *explicit* and lets it override an
   embedded `host:port` (`VM:5085-5088`) — but the CLI's `--port` is `UInt16?` with **no default**:
   when absent, the embedded port wins.

Net effect: type `server:4242`, leave Port untouched → **preview/CLI hit 4242, the app silently
hits 11112**. The fix is one change (empty the `defaultValue`, keep it as placeholder; emit
`--port N` in the preview when both host-embedded and explicit ports are present) applied to the
shared code — it repairs all seven tools at once. This is the highest-leverage fix in the audit.

### 🔑 New failure mode — "field exists, executor never reads it"

Phase 6's signature bug shape (distinct from the multi-value classes): the param is defined, the
preview emits it, but the executor never calls `paramValue(...)` for it — so the flag silently
does nothing in-app while the pasted command honors it. Instances: retrieve `--uid-list`/`--parallel`
(#25), mwl `--accession-number` (#28), mpps `--sps-id` (#29), qr `--validate` (read-then-discarded,
#32), send/mwl/mpps/study `--verbose` (#36, #41). **A cheap CI guard: for every non-internal param id,
assert the tool's executor references it.**

### Notable one-offs

- **#27 is a data-integrity bug**: the app's hand-rolled TS alias map translates `jpeg-lossless` to
  SV1 (`.4.70`) where the CLI's shared parser yields Process 14 (`.4.57`) — the negotiated transfer
  syntax differs for the *same command text*. Root cause: bespoke duplicate of a shared parser
  (violates the "never re-hardcode" project rule).
- **#35 is the audit's first confirmed CLI-side bug**: `dicom-qr --transfer-syntax` is parsed,
  printed… and never forwarded by the CLI, while the app forwards it. Fix goes in the CLI (its help
  promises the behavior), then regenerate contracts/goldens per the wire-parity rule.
- **#30 can emit non-conformant DICOM on the wire**: MPPS update builds a Referenced SOP Sequence
  using the MPPS SOP Instance UID as the Study UID fallback — an object the CLI could never produce.
- **#37 phantom subcommand**: the app previews `dicom-mwl create …`, which the real binary rejects —
  the create flow is an app-internal HL7 ORM feature whose subcommand token leaks into a
  "paste-runnable" preview.

---

## Phase 7 — DICOMweb (WADO family)

**Tools:** dicom-qido · dicom-wado · dicom-stow · dicom-ups (all → `dicom-wado` CLI subcommands query/retrieve/store/ups)
**Status:** ✅ Complete · 4 tools / 81 flags audited · **29 confirmed findings → 9 register entries** (#42–#50; 2 High, 6 Med, grouped Lows) · Fable mode (8 agents — all hit verify)

### Per-tool verdicts

| Tool | Flags | Result |
|------|:-----:|--------|
| dicom-qido | 18 | ❌ `--token` basic-auth preview (#45), root-vs-path-scoped queries + 2 missing filters (#48), misc low |
| dicom-wado | 17 | ❌ URI-mode `--frames` parse (#47), `--token` (#45) |
| dicom-stow | 10 | ❌ `<files>` comma-split positional list (#46), `--token`/`--username` (#45) |
| dicom-ups | 36 | ❌ **`--aet` reads nonexistent param id → hardcoded DCM4CHEE** (#42), **SCHEDULED→IN PROGRESS state collapse** (#43), global (un)subscribe rejected (#44), `--scheduled-start` silent drop (#49), 10 create-metadata options NOT_IN_APP (#50a) |

### Highlights

- **#42 is the "executor never reads it" failure mode at its sharpest**: the code reads
  `paramValue("called-aet")` — an id that exists only for DIMSE tools — so the fallback
  `"DCM4CHEE"` is *always* used and the user's typed AE is dead. The proposed CI guard from
  Phase 6 (assert every non-internal param id is referenced by its executor) would have caught
  this **and** its mirror image (executor referencing an id no definition declares).
- **#43 is protocol-behavior-changing**: picking SCHEDULED performs an N-ACTION that claims the
  workitem IN PROGRESS with a generated transaction UID — a materially different UPS operation
  than the previewed command performs.
- **#45 is systemic across the family**: the app-only basic-auth mode previews as `--token
  <password>` (Bearer), silently changing the authentication scheme between surfaces.
- **#46 adds a third split convention** (comma) to the semicolon/newline mismatch catalog —
  every multi-value convention in the app now has at least one bespoke divergent implementation.
- dicom-ups is the **largest coverage gap** of the audit: 10 CLI create-metadata options with no
  app fields (#50a) — a CLI `ups --create-workitem` run with patient demographics cannot be
  reproduced or previewed from the Workshop.

---

## Remediation

**Triage (2026-07-03, user):** #23 accepted as-is · #37 banner/suppressed-preview only · #41(a) accepted as-is, (b)–(f) fix · #44 accepted as-is. All other confirmed entries: **fix**.

Work runs as sequential clusters (same two large files are touched throughout — no parallel edits).
Each cluster ends with a compile check; regen/rebuild/tests close it out per the wire-parity rule.

| Cluster | Scope (register entries) | Status |
|:-:|----------|:------:|
| A | Shared `buildCommand` machinery: positional-list branch (empty flag + `isRepeatable`), negated-flag support · repeated-flag/split fixes #1 #2 #19 #20 · #13 dcmdir `--no-recursive` | ✅ 8/8 FIXED, build clean |
| B | Positional-list consumers: #10 export contact-sheet · #12 archive import · #14 merge inputs · #46 stow files · #38 mpps image-uid · #41c send paths preview | ✅ 6/6 FIXED, build clean |
| C | dicom-anon cluster: #3 in-place overwrite guard · #4 #5 #6 keep/remove/replace (isRepeatable + keyword parseTag + error-not-drop) · #7 audit-log dry-run · #9 backup location | ✅ 6/6 FIXED, build clean |
| D | Small executor fixes: #16 split window parse · #22 study compare verbose · #24 query level INSTANCE · #28 mwl accession · #29 mpps sps-id · #31 qr mode · #32 qr validate · #33 qr patient-name · #36 mwl verbose/json · #41b/d/e · #42 ups aet · #47 wado frames · #49 ups scheduled-start | ✅ 15/15 FIXED, build clean |
| E | Protocol/feature: #17 split dir walk · #25 retrieve uid-list+parallel bulk · #26 instance scope · #27 shared TS parse · #30 mpps study-uid update · #34 qr move-dest (tighten executor) · #39 retrieve series-uid (resolved-UID substitution) · #43 ups SCHEDULED | ✅ 8/8 FIXED, build clean |
| F | Field additions & guards: #8 validate OutputPathResolver · #11 pixedit fill-value visibleWhen · #15 archive export guard · #18 merge format passthrough · #21 uid maintain-relationships · #40 qr accession · #48 qido series/accession + path-scoping · #50 ups create-metadata fields + misc | ✅ 8/8 applied (agent stalled on final report; every edit verified in-tree by inspection, build clean) |
| G | Preview truthfulness + CLI-side: #37 mwl create banner (scoped) · #45 token basic-auth preview · #35 qr TS forward (CLI fix) · #11 parity scenario · **regenerate CLIContracts.json + goldens, rebuild both binaries** (wire-parity rule) | ✅ 5/5 FIXED — dicom-qr & dicom-pixedit rebuilt debug+release, contracts/goldens regenerated |
| H | Final verification: build (debug+release), targeted tests, parity spot-checks; update this doc's register with per-entry outcomes | ✅ **PASS** — see verdict below |

### ✅ Remediation complete — final verdict (2026-07-04)

**All 8 clusters done. 54 fix items applied, 0 skipped, 0 regressions.**

**Builds:** debug package clean · release `dicom-qr` clean · release `dicom-pixedit` clean.

**Tests:**
- `CLIWorkshop` suites: **208/208 passed** (incl. 2 new `buildCommand` machinery tests)
- `StudioParity`: exit 0 — **parity harness MATCH=429 · DIFFERS=0 · UNAVAILABLE=0 · ERROR=0**
- `CompressionConsole`: 7/7 (regression canary)
- New focused tests: `RepeatablePositionalExpansion`, `BooleanToggleNegatedFlag`, `RepeatableFlag` — 3/3
- No tests asserting the old newline-split behavior remain (migrated to the semicolon/repeatable contract).

**Regeneration (wire-parity rule):** CLIContracts.json rewritten (36 tools, 0 broken — only
pre-existing JPEG-XL help-text hunks beyond this work); goldens.synthetic.json +2 scenarios
(`syn-ct__dicom-pixedit-mask-region-fill-255` from #11, plus one pre-existing JPEG-XL scenario that
had never been regenerated); local goldens.json 429 scenarios. Every changed golden entry accounted
for (compress ratio lines & pixedit window-bake lines stem from the branch's pre-existing
uncommitted work — correct per the wire-parity rule).

**Register outcomes:** #1–#22, #24–#36, #38–#43, #45–#50 → **FIXED** (with #37 scoped to the
in-app-only preview banner and #41(b–f) fixed). #23, #44, #41(a) → **ACCEPTED AS-IS** (user triage).
#18 was the lone refuted finding (fixed anyway as future-proofing).

**Not committed** — all changes are in the working tree for review. Note the tree also carries the
branch's pre-existing uncommitted work (JPEG-XL codec naming, CompressionConsole ratio lines,
PixelEditor window-bake), which the regenerated contracts/goldens correctly fold in.

**In-app-only preview convention introduced (end-user facing):** a state that cannot be expressed
as a real CLI command (mwl create, basic-auth mode) renders its preview as a `# in-app only — …`
banner with the command commented out, so a paste is inert and never misleads; `runTerminalCompare`
detects the comment prefix and reports gracefully instead of exec'ing `#`.

---

## Change log

| Date | Event |
|------|-------|
| 2026-07-03 | Document created; methodology fixed; Phase 1 started. |
| 2026-07-03 | Phase 1 complete (6 tools, 8 agents). 2 confirmed defects (dicom-xml/json `--filter-tag`), 3 low notes. Verified `.arrayField` renders single-line. Phase 2 started in **Fable mode**. |
| 2026-07-03 | Phase 2 complete (4 tools, 58 flags, 6 Fable agents). 7 confirmed defects: dicom-anon ×6 (incl. in-place overwrite High, keep/remove/replace silent-drop High) + dicom-validate `--output` Med. convert & compress clean. 3 cross-cutting executor findings noted. Phase 3 started. |
| 2026-07-03 | Phase 3 complete (4 tools, 65 flags, 6 Fable agents). 2 confirmed defects: dicom-export contact-sheet positional-list (#10 Med), dicom-pixedit `--fill-value` unreachable via `visibleWhen values: []` (#11 Med). image & pdf clean. New class: unsatisfiable visibleWhen. Phase 4 started. |
| 2026-07-03 | Phase 4 complete (4 tools, 51 flags, 8 Fable agents). 7 confirmed defects (#12–#18): archive import `<files>` High (space-split paths), dcmdir inverted-flag Med (new class), merge `<inputs>` Med, archive export `--output` Med, split ×3 Low. dicom-merge `--format` High **refuted** by verifier (FrameMerger ignores format). Phase 5 started. |
| 2026-07-03 | Phase 5 complete (3 tools, 41 flags, 6 Fable agents). 4 confirmed defects (#19–#22): dicom-script `--variables` High (first space-list; no working separator exists), dicom-uid validate `<uids>` Med, `--maintain-relationships` NOT_IN_APP Low, dicom-study compare `--verbose` Low. All 3 multi-value shapes now confirmed. Phase 6 (DIMSE) started. |
| 2026-07-03 | Phase 6 complete (7 tools, 110 flags, 14 Fable agents). 19 defect entries (#23–#41): systemic `--port` High across all 7 tools; query `--level` High; retrieve `--uid-list`/instance-scope/TS-map High; mwl accession-drop High; mpps sps-id/study-uid High; qr TS = first CLI-side bug. New failure mode: "field exists, executor never reads it". Phase 7 (final) started. |
| 2026-07-03 | Phase 7 complete (4 tools, 81 flags, 8 Fable agents). 29 findings → entries #42–#50: ups `--aet` nonexistent-param-id High, ups SCHEDULED→IN PROGRESS High, global (un)subscribe rejected, WADO-family basic-auth `--token` preview, stow comma-split positional, ups 10-option coverage gap. **AUDIT COMPLETE** — executive summary + 6 root-cause classes + fix order added. |
| 2026-07-03 | **Triage received** (user): #23 accepted as-is · #37 banner-only · #41(a) as-is, (b)–(f) fix · #44 accepted as-is. **Remediation started** — 8 sequential clusters (A–H, Fable), plan in the Remediation section. |
| 2026-07-04 | Clusters A–E complete (43 items). Cluster F agent stalled on its final report after applying all 8 edits — every item verified in-tree by direct inspection, build clean. G+H relaunched as a fresh stall-guarded workflow. |
| 2026-07-04 | **REMEDIATION COMPLETE.** G: #37 banner, #45 token/basic-auth truthful previews, #35 CLI-side qr TS forwarding, #11 fill-255 scenario, contracts+goldens regenerated, release rebuilds. H verdict: **PASS** — CLIWorkshop 208/208, StudioParity MATCH=429/DIFFERS=0, CompressionConsole 7/7, 3 new buildCommand tests. 54/54 items, 0 skipped, nothing committed. |
