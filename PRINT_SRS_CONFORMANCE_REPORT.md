# DICOM Film Printing SRS — conformance report

Compares `DICOM_Film_Printing_SRS_TDD.md` (in `~/Downloads`, 1,491 lines, 17
functional requirements) against the implementation in this repo at commit
`de67c39` plus uncommitted working-tree changes.

Every status below was verified against code, not against planning docs. Where a
type exists but is never called, it is reported as **absent**, not done.

**Last revised 2026-08-14 (second pass)**, after the day's implementation work
landed. The scorecard and the "closed 2026-08-14" section below are current; the
prose in gaps §1–§4 describes the state *before* that work and is kept as the
record of what was found — each affected gap carries a closure note. On hold by
decision: per-user statistics (needs authentication), FR-010 capability query,
IPv6, and FR-015 modality presets. The implementation pass itself is written up
in `PRINT_GAP_CLOSURE_COMPLETION.md`.

---

## Scorecard

| FR | Requirement | Priority | Status |
|---|---|---|---|
| FR-001 | Film size & format | MUST | ✅ Done |
| FR-002 | Film layout & image matrix | MUST | ✅ Done |
| FR-003 | Image scaling & positioning | MUST | ✅ Done |
| FR-004 | Window/Level & LUT processing | MUST | ✅ Done — SIGMOID, Presentation LUT table and LIN OD closed 2026-08-14 |
| FR-005 | Image transformations | MUST | ✅ Done |
| FR-006 | Annotation & patient info | MUST | ⚠️ Bands (header/side/overlay) done 2026-08-14; custom field, Study Time, halo config remain |
| FR-007 | Color & grayscale management | MUST | ✅ Done (GSDF curve absent) |
| FR-008 | Print preview | MUST | ✅ Done |
| FR-009 | Multiple copies & priority | MUST | ✅ Done |
| FR-010 | Printer selection & management | MUST | ⚠️ Capability query **on hold** by decision; rest done |
| FR-011 | Print queue management | MUST | ✅ Done — persistence, reorder, SUBMITTING/RETRYING + auto-retry closed 2026-08-14 |
| FR-012 | Printer status monitoring | MUST | ✅ Done — offline auto-queue closed 2026-08-14 |
| FR-013 | Reprinting | MUST | ✅ Done — survives restart via the persisted queue; fresh UIDs by construction |
| FR-014 | Print history & audit trail | MUST | ⚠️ Hash chain, tiered retention, session/source/state fields, CSV+PDF done 2026-08-14; per-user stats **on hold** (needs authentication) |
| FR-015 | Modality-specific presets | MUST | ❌ Absent — **not planned** |
| FR-016 | Film/media selection | MUST | ✅ Done |
| FR-017 | Association & transfer syntax | MUST | ✅ Done |

**All 17 are MUST.** There is no SHOULD/MAY tier to defer.

As of 2026-08-14 (second pass): **13 done, 3 partial, 1 absent**.

**Closed 2026-08-14**, each with tests, verified by running them:

- **Queue persistence** — `PrintQueuePayload`/`PrintQueueJob` are `Codable`
  (`result` deliberately excluded), stored via `PrintQueueStorageService`
  (`print-queue.json`), written on every state transition and never on progress
  ticks. Restore marks jobs that died mid-print failed ("Interrupted"), fails
  waiting jobs whose source files vanished, and **restores the queue held** — a
  launch never opens an association on its own; the user resumes deliberately.
  Only the app's shared view model gets the storage; previews and tests stay off
  the file.
- **Queue reorder** — `move(fromOffsets:toOffset:)` + drag in the queue list.
- **SUBMITTING / RETRYING states and automatic retry** — the state enum now
  matches SRS §6.2 8-for-8. Thrown faults retry up to `maxAutoRetries` (default
  2 extra sends, 5 s apart) with the §8.2 attempt-count gate — persisted, so the
  gate survives a restart. A printer that *answered and rejected* the job does
  not retry: rejection is final, a fault is not.
- **Offline auto-queue (the last FR-012 item)** — `isPrinterReady` gate in the
  processor holds a monitored-offline printer's job as pending, saying why;
  a status update flipping the printer back calls `reevaluate()`. Strictly FIFO:
  a later job does not jump an offline printer's job.
- **Audit §11.1 fields** — every new event carries session ID (one UUID per
  launch), source (host name — printing is initiated locally, so the local host
  *is* the source), and before/after states on the transitions that have them.
  Old trail files still decode; their events are simply unhashed.
- **Audit §11.2 tamper evidence** — SHA-256 hash chain per event;
  `verifyIntegrity()` walks it and the Audit Trail tab shows a red shield naming
  the first broken link. Verified by a test that doctors the JSON on disk.
- **Audit §11.3 tiered retention** — the 500-event cap is gone. Events live 7
  years; failure *detail* is redacted at 1 year (the event stays); the rewrite
  re-chains and is itself recorded as `retentionApplied`.
- **Forbidden delete removed** — no `clear()` on the trail, no Clear button.
  Retention policy is the only thing that removes an event.
- **CSV export** — audit trail and job history, alongside JSON and PDF.
- **FR-004 SIGMOID** — a viewer mark's window now inherits the file's
  (0028,1056) instead of silently printing linear contrast
  (`PrintImagePreparer.resolvedFunction`); an explicit non-linear request
  function still wins.
- **FR-004 Presentation LUT table** — `PresentationLUTTable` sends the
  Presentation LUT Sequence (2050,0010) with descriptor + OW data in the
  N-CREATE, plumbed from `PrintJobRequest.presentationLUTTable`.
- **FR-004 LIN OD** — a real density curve (`FilmComposer.linODTransfer`):
  luminance falls as 10^(−OD) across the film box's Min/Max Density range,
  replacing the invert-toggle approximation. Same orientation as before, so
  existing films do not flip.
- **FR-006 annotation bands** — `FilmAnnotationEdge` (footer / header / left /
  right / overlay): the cell layout carves the band off the chosen edge, side
  bands rotate the text spine-wise, overlay reserves nothing. Exposed in the
  emulator settings as "Annotation position", persisted with the SCP settings.

**Still open:** FR-014 per-user statistics (held — blocked on authentication),
FR-010 capability query + IPv6 (held), FR-015 modality presets (held), and the
small FR-006 residuals (custom free-text field, Study Time, halo configuration,
the per-image 9-pixel caption floor).

---

## What is done well

**FR-001/002 — film sizes and layout.** All 12 required sizes including A4/A3
(`PrintService.swift:277-291`), with real physical dimensions
(`FilmGeometry.swift:65`), not just an enum. `STANDARD\C,R` is built columns-first
per PS3.3 C.13.3 (`PrintService.swift:953-957`) — a detail toolkits routinely get
backwards. `ROW\` and `COL\` band formats are genuinely implemented
(`FilmGeometry.swift:216`), which is beyond what many commercial SCUs support.

**FR-005 — transformations.** Real pixel work in the SRS-mandated order
(flip → rotate → invert) at `PrintPresentationTransform.swift:57-93`, with
quarter-turns treated as exact pixel moves rather than resampled
(`ViewerPresentation.swift:70-87`).

**FR-007/017 — color and negotiation.** Color vs grayscale correctly selects the
meta SOP class at association time (`PrintService.swift:2362`). Presentation LUT
SOP Class is implemented end-to-end — N-CREATE, negotiated context, Film Box
reference, and SCP handling. Transfer-syntax negotiation is honoured per-context
(`PrintPresentationContexts.swift:134`).

**FR-008 — preview.** A full interactive WYSIWYG film preview
(`FilmPreviewView.swift`, 1538 lines) built from the same `FilmSheet` geometry used
for output, so it is a true preview rather than an approximation.

---

## Gaps, in priority order

### 1. FR-014 audit trail — a working trail, but still the *regulatory* gap

> **Closed 2026-08-14** except per-user statistics (held, blocked on
> authentication): hash chain + verification, session/source/state fields,
> tiered retention, CSV+PDF export, and the Clear control is gone. The text
> below records the pre-fix findings.

**Changed 2026-08-14.** A print audit trail now exists and is genuinely durable:
`PrintAuditTrail.record()` writes `print-audit-trail.json` atomically on **every**
event (`PrintAuditEvent.swift:194`), reloads at init (`:178`), covers 14 action
types (`:13-27`), and is exposed in the Print screen's Audit Trail tab with search
and action-type filtering (`AuditTrailView.swift:95-104`). The queue records every
transition through it. This replaces the earlier finding of "three disconnected
implementations, none wired to disk" — that described the unrelated
`AuditLogger`/`SecurityModel` code, which is still dead for this purpose.

What it carries is six fields (`PrintAuditEvent.swift:78-105`): `id`, `date`,
`action`, `jobID`, `printerName`, and a free-text `detail`.

The SRS is more demanding. §11.1 requires every event to carry **session ID, source
IP, and before/after JSON state snapshots**; §11.2 requires **tamper-evident
storage** and names a hash chain; §4.14 requires **per-user print volume and
success/failure statistics**; §11.3 sets a **tiered** retention policy.

| SRS §11.1/§11.2/§11.3 field | Status |
|---|---|
| Event written durably per action | ✅ `PrintAuditEvent.swift:194` |
| session ID | ❌ absent |
| source IP | ❌ absent |
| before/after state snapshots | ❌ absent — `detail` is a summary string, not a transition |
| user_id | ❌ absent, by design — no accounts exist (`PrintAuditEvent.swift:6-7`) |
| hash chain / tamper evidence | ❌ absent — plain JSON, editable on disk |
| tiered retention (7y / 1y / 90d) | ❌ absent — a flat 500-event cap (`:120`) |
| CSV + PDF export | ❌ JSON only (`AuditTrailView.swift:41-46`) |
| per-user statistics | ❌ absent — no user dimension to aggregate on |

Two findings that are worse than "not yet built", because they actively destroy
records §11.2 says must be immutable:

- **A one-click permanent wipe.** `PrintAuditTrail.clear()`
  (`PrintAuditEvent.swift:197-201`) empties the file, surfaced as a destructive
  "Clear…" button (`AuditTrailView.swift:82-89`) whose own dialog concedes "This
  cannot be undone." This is the same contradiction previously flagged against
  `SecurityView.swift:527`, now present in the print trail too.
- **Silent truncation.** The 500-event cap drops the oldest events on every save
  (`PrintAuditEvent.swift:133`, `:191-193`) with no warning and no export prompt.
  A busy department would roll past 500 in days, so this is a live data-loss path,
  not a theoretical one.

The retention requirement is 7 years; a 500-event cap is not a retention policy at
all. Fixing the cap is cheap and should not wait for the rest of the field work.

**Two corrections to my earlier plan** (`PRINT_FR_011_013_014_PLAN.md`), both from
reading the actual SRS:

- Retention is **tiered**, not flat: audit events and print history 7 years, *failed
  job details 1 year, system logs 90 days*. My plan proposed a single window. The
  tiering also resolves the size-cap tension I flagged as an open question — the
  bulky diagnostic detail expires early, the compliance record does not.
- **Per-user tracking is a hard requirement**, and it has an unstated dependency:
  there is a `UserSession` type and role-permission logic
  (`SecurityViewModel.swift:827`), but **nothing ever sets `currentSession`** — no
  login flow exists. Per-user statistics cannot be built until authentication (§14.1,
  RBAC with four roles) exists. My plan missed this entirely; it is a prerequisite,
  not a detail.

Also note §11.2's "no deletion or modification of historical records" directly
contradicts the unguarded **Clear** button at `SecurityView.swift:527`.

### 2. FR-011 queue & FR-013 reprint — built 2026-08-14; persistence is the gap

> **Closed 2026-08-14 (second pass)**: persistence, restore-held-with-path-
> revalidation, reorder, SUBMITTING/RETRYING with the persisted attempt gate.
> The text below records the pre-fix findings.

**The queue is real and is the only path to the printer.** `PrintQueueService` is a
`@MainActor` serial queue; `PrintViewModel.print()` enqueues rather than printing
directly (`PrintViewModel.swift:783`), and DIMSE execution happens inside the
queue's own `run()` (`PrintQueueService.swift:425-461`). There is no bypass — the
sheet never calls `PrintService.print` itself. Serial execution is structurally
enforced by a single `runningJobID` guard (`:396-400`), so two jobs cannot
interleave associations on one printer.

**Operations.** `pauseQueue`, `resumeQueue`, `stopAll`, `clearFinished`, and
per-job `start`, `pause`, `resume`, `stop`, `resend`, `remove` — all reachable from
`PrintQueueView`. **Reorder is absent**: the list has no `.onMove` and the service
has no `move` API; the only priority control is `start(_:)`, which jumps one job to
the front (`:296-303`).

**FR-013 resend works** (`PrintQueueService.swift:361-378`), replaying the captured
payload as a new attempt with `attempt` incremented, leaving the original as the
record of its run.

The SRS §6.2 `JobStatus` enum is:

```
PENDING, SUBMITTING, PRINTING, COMPLETED, FAILED, CANCELLED, PAUSED, RETRYING
```

The implemented enum (`PrintQueueService.swift:53-65`) has six of eight. `pending`,
`paused`, `completed` and `failed(String)` match; `running` covers PRINTING and
`stopped` covers CANCELLED under different names. **SUBMITTING and RETRYING are
absent**, and so is any automatic retry — `attempt` is only ever incremented by a
manual `resend()`. Earlier note stands: use the SRS name `PENDING`, which the
implementation does.

**The one acceptance criterion that is already satisfied, for an unexpected
reason.** §4.11/§4.13 require *"Retry creates new SOP Instance UIDs"*. The SCU never
generates print SOP Instance UIDs at all — every N-CREATE passes `nil` and takes
the SCP's assignment (`PrintService.swift:2538`, `:2726`, `:2891`, read back at
`:2573`, `:2761`, `:2911`). A resent job opens a fresh association and is therefore
issued new Film Session / Film Box / Print Job UIDs by construction. There is no
stored-UID reuse path anywhere, so this cannot regress by accident — but it is not
something the app enforces either, and that distinction is worth keeping in mind if
UID generation ever moves client-side.

**The real gap: nothing survives a restart.** `jobs` is an in-memory array
(`PrintQueueService.swift:183`), and neither `PrintQueueJob` nor `PrintQueuePayload`
is `Codable`. There is no storage service, no save/load, and `init` (`:202`) loads
nothing. Consequences:

- A crash or quit loses every pending, paused and running job, with no record that
  they were meant to print.
- `attempt` is lost with them, so the SRS §8.2 rule `FAILED → RETRYING` **gated on
  retry count < max** cannot be implemented as specified — the count must be
  persisted, and today it cannot be.
- **FR-013 resend is restart-fragile for the same reason**: it replays
  `original.payload` from RAM, so reprinting is impossible after a restart, and also
  after `remove()` or `clearFinished()` drops the job from the array.

What *is* persisted — `print-job-history.json` and `print-audit-trail.json` — are
after-the-fact logs. Neither carries the payload, so neither can reconstruct a job
for execution. Making `PrintQueuePayload` `Codable` is the prerequisite for the
retry rule, for durable reprint, and for FR-012's offline auto-queue.

That work is tractable: `PrintSelectionItem` references frames by file path and
frame index (`PrintSelectionModel.swift:17-38`) rather than embedding pixel data,
so a persisted job is small. The design question it raises is what a restored job
should do when its source file has since moved or been deleted — it must fail
visibly rather than silently print the wrong thing, which argues for re-validating
paths at load and marking unresolvable jobs failed with a reason.

**Coverage:** 29 tests — 21 in `PrintQueueAuditTests` (state transitions, audit
recording and persistence, resend, and the queue's activity summary) and 8 in
`PrintJobHistoryTests`.

Unchanged and confirmed: pause/resume is an **"Application-level state change"**
(§4.11) and is pre-submission only, matching the implementation's guard that
`pause()` is a no-op on a running job (`:314-316`). Cancel is *"FilmBox N-DELETE or
abort association"*, which the DIMSE layer already does (`PrintService.swift:4159-4182`).

### 3. FR-012 status monitoring — implemented, 5 of 6

| Sub-requirement | Status |
|---|---|
| Printer SOP Class N-GET status | ✅ `PrintService.swift:2176-2260` |
| N-EVENT-REPORT handling | ✅ `PrintService.swift:3596-3640` — in-association only |
| Polling every 10–300s, configurable | ✅ `PrinterStatusMonitor.swift`, per-printer interval on `PrinterProfile` |
| Green/yellow/red indicator | ✅ `PrinterStatusPresentation.swift`, tri-state + distinct glyphs |
| Exponential backoff | ✅ `PrinterStatusBackoff`, ×2 to a 600s ceiling, resets on success |
| Auto-queue when printer offline | ✅ Closed 2026-08-14 — `isPrinterReady` gate + `reevaluate()`; held jobs persist |

**What was built.** `PrinterStatusSeverity` (`PrintService.swift`) turns the wire
string into a closed enum, parsed leniently so a padded or lower-cased CS value
still reads correctly and anything unrecognised becomes `unknown` rather than being
assumed healthy. `ServerConnectionStatus` gained a `warning` case, and
`PrintViewModel.connectionStatus(for:)` maps severity onto it — replacing
`status.isNormal ? .online : .error`, which silently reported a low-film printer as
broken.

`PrinterStatusMonitor` is an actor running one polling task per printer, so a slow
or unreachable printer cannot delay the others. It carries startup jitter (printers
enabled together would otherwise poll in lockstep forever), exponential backoff to a
10-minute ceiling on failure, and replay of the last known state to a late
subscriber. The probe and the sleep are both injected, so the tests assert timing
and backoff decisions without a real clock or a real printer.

An unreachable printer maps to `.offline`, not `.error`: "we could not ask" and "it
answered and said it is broken" are different facts and an operator needs to
distinguish them.

**Two decisions worth recording.** Polled status is deliberately *not* persisted —
it is observed state, and writing `printer-profiles.json` on every poll would
rewrite the file every few seconds per printer for data that is meaningless after a
restart. And monitoring is off per printer by default, because polling opens a real
association on someone's hospital printer; it is opted into, not switched on for
every profile the user has ever saved.

**Coverage:** 43 tests across `PrinterStatusSeverityTests`,
`PrinterStatusMonitorTests` and `PrinterStatusWiringTests`, including legacy-JSON
decode (a profile written before these fields existed still loads) and interval
clamping against hand-edited values.

The N-EVENT-REPORT limitation is unchanged and structural: events arrive only while
a print association is open, so it supplements the poller rather than replacing it.

### 4. FR-003/004/006 — largely landed 2026-08-13; verified against code

> **2026-08-14:** the three FR-004 gaps below (Presentation LUT table, LIN OD,
> SIGMOID) and FR-006's header/side/overlay bands are closed — see the summary
> at the top. FR-006's remaining items: custom free-text field, Study Time,
> background/halo configuration, per-image caption floor.

The `PRINT_FR_003_004_006_PLAN.md` work is in the tree (uncommitted) and was
re-verified path-by-path, not from declarations. Verdicts:

**FR-003 scaling & positioning — ✅ done.** All four modes
(`PrintScalingMode`, `PrintCellPlacement.swift:22-61`) and all nine alignments
(`:70-115`), genuinely consumed by the fitter — `FilmGeometry.swift:273-277`
routes every branch through `alignment.origin(...)`, and alignment moves the
*crop window* under fill, which is the correct semantic. True Size reads all
three spacing tags in order — (0028,0030) → (0018,1164) → (0018,2010),
`PrintCellPlacement.swift:133-150` — and Requested Image Size (2020,0030) goes
on the wire (`PrintJobRequest.swift:347-365` → `PrintService.swift:2998-3001`).
Missing spacing falls back to fit *audibly* via a diagnostic
(`PrintWorkflow.swift:153-158`). 14 tests plus a byte-for-byte default
regression gate (`PrintCellPlacementTests.swift:35`).

**FR-004 W/L & LUTs — ⚠️ table LUTs done, three gaps remain.** The hard part
landed: `GrayscaleLUT` (`Sources/DICOMKit/GrayscaleLUT.swift`) decodes both the
Modality LUT Sequence (0028,3000) and VOI LUT Sequence (0028,3010) with the
traps handled — descriptor-zero → 65536 entries, signed first-mapped, 8-bit
packing — and even derives VOI-input signedness from the Modality LUT *output*
(the C.11.2.1.1 rule most toolkits get wrong). The print path applies the
correct precedence ladder — explicit window → VOI LUT table → header W/L →
auto (`PrintImagePreparer.swift:292-303`) — and Modality LUT correctly
suppresses rescale (`ImagePreprocessor.swift:232-239`). Still missing:

- **Custom Presentation LUT table** — `PresentationLUTShape` is shape-only;
  no `table` case, so the SRS's "Custom" option cannot be sent.
- **LIN OD is a bare inversion** — `FilmComposer.swift:566` toggles invert for
  `.linearOpticalDensity`, but LIN OD is a density curve, not a negation.
- **VOI LUT Function (0028,1056) / SIGMOID ignored on print** — the viewer
  honours it; `PrintImagePreparer` never reads it, so a SIGMOID image prints
  with linear contrast *silently* — the one place the plan's
  never-silently-degrade rule is not yet honoured.

**FR-006 annotations — ⚠️ fields and style done, placement is not.** The four
new fields (Birth Date, Accession, Institution, Series Description) are read,
opt-in via an OptionSet defaulting to empty — DOB off unless deliberately
chosen (`PatientOverlayText.swift:363-370`, toggles at
`PrintSettingsView.swift:1210-1217`). `PrintAnnotationStyle` (font family,
size fraction clamped 2–10%, auto/white/black) is threaded to the burner. The
footer's legibility floor is the SRS's 8 pt stated physically — 2.82 mm
(`FilmIdentification.swift:205`). Still missing:

- **Header/side/overlay annotation positions** — the composer reserves a
  *bottom band only* (`FilmComposer.swift:644-650`); no top/left/right bands,
  no slot map. This is the largest FR-006 gap.
- **Custom free-text field and Study Time** as selectable fields.
- **Background configuration** — the halo is unconditional.
- The burned per-image caption floor is 9 *pixels*
  (`ImageAnnotationBurner.swift:432`), not DPI-aware; only the footer band
  enforces the true 8 pt floor.

### 5. FR-015 modality presets — absent and unplanned

CT/MR/CR/DX/US-specific print presets do not exist. The only modality-keyed presets
are window/level presets for the viewer (`WindowLevelPresets.swift:22`), which are
a different thing. `PrintTemplatePreset` is a layout/film-size template, not
modality-keyed, and there is no user-preset persistence. Not covered by either plan.

### 6. FR-010 — one stub inside an otherwise complete requirement

Printer CRUD, JSON persistence, and C-ECHO verification are all real. But the
acceptance criterion *"Printer capability query executed on save and on demand"* is
unmet: `PrinterCapabilities` (`PrintService.swift:1715-1751`) is only ever the
hardcoded `.default`, never populated from an N-GET. `PrinterProfile` also lacks
max PDU size, active/inactive, and description. FR-010 additionally requires
**IPv6**, which the DICOMKit defects doc lists as a known "still to do".

---

## Corrections to the existing plans

`PRINT_FR_011_013_014_PLAN.md` was written before this SRS was available, and marked
its requirements as reconstructed. Reading the real spec, it holds up on the
architecture — the two-status-axis separation, persisting the full request for
reprint, and consolidating the duplicate models are all confirmed by §6.1/§6.2/§8.2 —
with these amendments.

**Note (2026-08-14):** items 1 and 4 below are now settled in code — the enum uses
`PENDING`, and fresh UIDs come free from SCP assignment (gap §2). Item 3's job-record
fields and items 5–7 remain outstanding. The plan's own instruction to *persist the
full request for reprint* is the one piece it got right that the implementation has
not yet done, and it is now the highest-value remaining item.

1. Use `PENDING`, not `QUEUED` (SRS §6.2). — **done**
2. Retention is tiered (7y / 7y / 1y / 90d), not a single 7-year window (§11.3).
3. Add to the job record, per §6.1: `user_id`, `submitted_by`, `original_job_id`
   (for reprints), `error_code`, and per-image `cell_row`/`cell_column` with
   optional per-image W/L and scaling overrides.
4. Retry and reprint must **generate new SOP Instance UIDs** (§4.11, §4.13). —
   **satisfied**, because the SCP assigns them and the SCU stores none (gap §2).
5. Audit entries need session ID, source IP, and before/after snapshots (§11.1).
6. Per-user statistics depend on authentication, which does not exist.
7. Tamper-evidence (hash chain) is "recommended" in §11.2 but pairs with the
   "logs immutable" acceptance criterion in §4.14 — treat as required.

The SRS also resolves my two open questions: it never mentions ATNA, Supplement 95,
RFC 3881, or syslog, so a **local append-only trail is sufficient** — no
standards-conformant audit messaging needed. And the export formats required are
**CSV and PDF** (§11.3), not the ATNA option currently mislabelled in the export
picker (`SecurityView.swift:925` always emits CSV regardless of selection).

---

## Suggested sequence

- ~~**FR-012 tri-state indicator**~~ — done 2026-08-13.
- ~~**FR-012 polling, interval and backoff**~~ — done 2026-08-13.
- ~~**FR-003 scaling & positioning**~~ — done 2026-08-13, verified against code.
- ~~**FR-011 queue**~~ — built 2026-08-14: serial execution, full operation set,
  UI, audit-wired. Persistence and reorder outstanding.
- ~~**FR-013 reprint**~~ — resend built 2026-08-14; durable only once the payload
  is persisted.
- ~~**FR-014 audit trail**~~ — built and persisted 2026-08-14; compliance fields
  outstanding.

- ~~**Persist the queue**~~ — done 2026-08-14, with held restore and source-path
  revalidation; unblocked durable reprint, the retry gate, and offline auto-queue.
- ~~**Audit retention + forbidden delete**~~ — done 2026-08-14: tiered by age,
  `clear()` removed.
- ~~**FR-004/006 residuals (the big ones)**~~ — SIGMOID, Presentation LUT table,
  LIN OD, and the annotation bands, all done 2026-08-14.
- ~~**Audit compliance fields**~~ — session ID, source, before/after states, hash
  chain, CSV+PDF — done 2026-08-14.
- ~~**Queue reorder, SUBMITTING/RETRYING + automatic retry**~~ — done 2026-08-14.

What remains, all currently **on hold by decision** except the first:

1. **Small FR-006 residuals** — custom free-text field and Study Time as
   selectable identification fields, halo/background configuration, the
   per-image caption floor stated in points rather than pixels.
2. **Authentication + RBAC → per-user statistics** (FR-014's last item) — the one
   piece of genuinely new subsystem territory; every "user" field blocks on it.
3. **FR-010 capability query + IPv6** — held.
4. **FR-015 modality presets** — held; the only requirement still absent outright.
