# Print gap closure — FR-011, FR-013, FR-014

Implementation plan for print queue management, reprint, and audit trail. Companion
to `PRINT_FR_003_004_006_PLAN.md`, which covers scaling, LUTs and annotations.

> **Status 2026-08-14: implemented.** FR-011 and FR-013 are done — queue with
> serial execution, persistence (`print-queue.json`, held restore, source-path
> revalidation), reorder, the full §6.2 state set with automatic retry, and
> restart-durable resend. FR-014 is done except per-user statistics, which stay
> blocked on authentication: the trail is hash-chained, carries session/source/
> before-after fields, retains by the tiered §11.3 policy, exports JSON/CSV/PDF,
> and has no delete control. Current state of record:
> `PRINT_SRS_CONFORMANCE_REPORT.md`. This plan is kept as design history.

**Scope:** job queue lifecycle and persistence (FR-011), reprint from history
(FR-013), and a single persistent audit trail (FR-014). Presets and user
management are *not* covered here.

> **Superseded in places — read `PRINT_SRS_CONFORMANCE_REPORT.md` alongside this.**
>
> This plan was written before the SRS was available and reconstructed the
> requirements from a gap report. The real spec
> (`DICOM_Film_Printing_SRS_TDD.md`, in `~/Downloads`) has since been read, and it
> corrects this plan in six places. The architecture below holds — the two-status-axis
> separation, persisting the full request for reprint, and consolidating the
> duplicate models are all confirmed by SRS §6.1, §6.2 and §8.2 — but before
> building, apply these:
>
> 1. The queued state is **`PENDING`**, not `QUEUED` (§6.2), which is also what the
>    existing enum already uses.
> 2. Retention is **tiered**, not a flat 7 years (§11.3): audit events and print
>    history 7 years, failed job details 1 year, system logs 90 days. This also
>    dissolves the size-cap contradiction flagged as an open question below.
> 3. Retry and reprint must **generate new SOP Instance UIDs** (§4.11, §4.13).
>    Re-sending the originals would be a conformance violation.
> 4. Audit entries additionally need **session ID, source IP and before/after state
>    snapshots** (§11.1).
> 5. The job record needs `user_id`, `submitted_by`, `original_job_id`, `error_code`,
>    and per-image `cell_row`/`cell_column` with optional per-image W/L and scaling
>    overrides (§6.1).
> 6. **Per-user statistics depend on authentication, which does not exist** — there
>    is a `UserSession` type and RBAC logic, but nothing sets `currentSession`. This
>    is a prerequisite, not a detail.
>
> The SRS also closes the two open questions at the foot of this plan: it never
> mentions ATNA, Supplement 95, RFC 3881 or syslog, so **a local append-only trail
> is sufficient**; and the required export formats are **CSV and PDF** (§11.3).

---

## The root cause, stated once

All three gaps share one cause: **the print subsystem has two parallel
implementations that never learned about each other**, plus a third orphaned in the
library layer. Closing FR-011/013/014 as three isolated features would triple the
duplication. The bulk of this plan is therefore consolidation, and the features
fall out of it nearly for free.

The duplication, concretely — each of these names is declared two or three times:

| Name | Declarations |
|---|---|
| `PrintJob` | `NetworkingModel.swift:1071` (Studio, has `status` + bookmarks) · `PrintService.swift:1359` (Network, has `imageURLs` + `configuration`) |
| `PrintJobStatus` | `NetworkingModel.swift:1042` (Studio UI enum, 4 cases) · `PrintService.swift:520` (Network **struct**, DIMSE N-GET wire result) |
| `PrintPriority` | `NetworkingModel.swift:901` · `PrintService.swift:209` |
| `AuditLogEntry` | `AuditLogger.swift:177` (rich: patient/study/SOP) · `NetworkingModel.swift:1252` (thin: 6 fields) |
| `AuditEventOutcome` | `AuditLogger.swift:79` (4-level ATNA ladder) · `NetworkingModel.swift:1195` (3-level) |

Plus three audit event enums with disjoint case sets (§FR-014.1) and a fourth,
unrelated status enum `PrintQueueJobStatus` at `PrintService.swift:1453`.

**The two print paths:**

- **Path 1 — Networking Hub.** `NetworkingView.swift:1144` creates a Studio
  `PrintJob`; `NetworkingService._printJobs` (`:57`) holds it; executed by
  `NetworkingViewModel.executePrintJob` (`:505`). Has a status model and file
  bookmarks. **Zero persistence** — the array is never written to disk.
- **Path 2 — Print Center.** `PrintViewModel.print()` (`:540`) → `PrintService` →
  `PrintWorkflow.execute` (`:135`). Has JSON-persisted history
  (`PrintJobHistoryEntry`) but no status model, and records only display strings.

Neither path can satisfy FR-011 or FR-013 alone: Path 1 has the state but forgets
it, Path 2 remembers but records too little to act on.

### Two assets that already exist

Both are load-bearing for this plan and neither is currently reachable from the app.

**1. `public actor PrintQueue` — `PrintService.swift:1479`.** Already implements
`enqueue` (`:1461`), `dequeue` (`:1469`), `peek` (`:1477`), **`cancel(jobID:)`**
(`:1485`), `markCompleted` (`:1508`), **`markFailed` with automatic re-queue on
retry** (`:1536`), `status(jobID:)` (`:1568`), priority sorting, and a bounded
history. No Studio code references it — it is mentioned only as a CLI surface in
`DICOM_PRINT_ENHANCEMENT_PLAN.md:405`. This is the substrate for FR-011; it needs
persistence and pause/resume, not a rewrite.

**2. `FileAuditLogHandler` — `AuditLogger.swift:448`.** Append-only JSONL, serial
dispatch queue, size-based rotation (`:638`), 50 MB × 10 files. Referenced only by
its own file and `AuditLoggerTests.swift`; `AuditLogger.shared` is never wired up,
so **nothing is ever written**. This is the substrate for FR-014.

### Suggested ordering

FR-014 first, then FR-011, then FR-013. Audit is the only one of the three that is
a *compliance* obligation rather than a convenience, it is the least entangled with
the two print paths, and both later phases need to emit audit events — building it
last would mean revisiting every call site added in between. FR-013 is last because
it is mostly a consequence of FR-011's persisted job record.

---

## FR-014 — Audit trail

### Requirement (reconstruct from SRS before building)

A persistent, append-only audit trail covering print-job and administrative events,
retained for 7 years.

### Status

| Capability | State | Where |
|---|---|---|
| Append-only JSONL writer | ✅ Exists, **dead code** | `AuditLogger.swift:448` |
| Wired into the app | ❌ Absent | no call sites outside its own file + tests |
| Survives relaunch (app-side) | ❌ In-memory only | `SecurityService.swift:35`, `NetworkingService.swift:67` |
| 7-year retention | ❌ Max 1 year | `SecurityModel.swift:618` (`days365`) |
| Print-job events | ❌ One coarse case, never emitted | `NetworkingModel.swift:1229` (`printJob`) |
| Admin events | ⚠️ Partial | `settingsChange`, `userLogin/Logout` in `SecurityModel.swift:453` |
| Tamper evidence | ❌ Absent | no hash/HMAC/signature anywhere |
| ATNA/Sup-95 conformance | ❌ Custom JSON only | `encodeEntry`, `AuditLogger.swift:544` |

Three disconnected implementations:

1. **`DICOMNetwork.AuditLogger`** (`AuditLogger.swift:782`) — the good one. Actor,
   handler-based, 17 event types (`:15`), rich `AuditLogEntry` with patient/study/SOP
   identifiers (`:177`), 4-level ATNA outcome ladder (`:79`). **Never called.**
2. **`SecurityService`** (`SecurityService.swift:35`) — `[SecurityAuditEntry]` in
   memory. 13 event types (`SecurityModel.swift:453`) including login/logout and
   settingsChange. Has the retention policy (`:613`) and the only audit UI.
3. **`NetworkingService`** (`NetworkingService.swift:67`) — `[AuditLogEntry]` in
   memory, 6-field entries, 10 event types (`NetworkingModel.swift:1220`). This is
   the only enum with a `printJob` case (`:1229`) and nothing ever emits it.

Both app-side stores are wiped on launch — `SecurityService.init()` (`:47`) is empty
and neither file contains any persistence call.

### Design

**Keep `DICOMNetwork.AuditLogger` as the single sink.** It is the only
implementation with the right shape (actor, handler fan-out, rich entries, severity
ladder) and it already has a 1079-line test suite. The two app-side stores become
*views over* it rather than independent stores.

**1. Extend the event vocabulary** — `AuditLogger.swift:15`

`AuditEventType` has 17 cases covering association/store/query/retrieve. Add two
groups. Note `AuditLoggerTests.swift:35` asserts `allCases.count == 17` and must be
updated in the same commit.

```swift
// Print — FR-014. Granularity matches the DIMSE operations actually issued,
// so a failed film session is distinguishable from a failed image box.
case printJobSubmitted, printJobCompleted, printJobFailed, printJobCancelled
case printFilmSessionCreated, printFilmSessionDeleted
case printerStatusRetrieved

// Administrative — FR-014.
case applicationStart, applicationStop
case configurationChanged, userLogin, userLogout, userLogoutTimeout
case auditLogExported, retentionPolicyChanged
```

`applicationStart` is deliberately named to match DICOM Supplement 95's event ID —
see the conformance note below.

**2. Add time-based retention** — new, alongside `FileAuditLogHandler:638`

The existing rotation is size-only (50 MB × 10, then oldest silently deleted). That
is not a retention policy; under load it can discard entries days old, and it can
equally discard nothing for a decade. Add date-stamped files plus a sweep:

- Name files `dicom_audit-YYYY-MM-DD.jsonl`; roll at local midnight *and* at
  `maxFileSize`.
- On startup, delete files whose date is older than the retention window.
- Keep size-based rotation as an inner bound within a day (`-1`, `-2` suffixes).

Extend `SecurityAuditRetentionPolicy` (`SecurityModel.swift:613`) with the required
window. The enum already has `.indefinite`, so the compliance-relevant change is
small:

```swift
case years7 = "7_YEARS"   // 2555 days — FR-014
```

Make `.years7` the default at `SecurityService.swift:37` and
`SecurityViewModel.swift:150` (currently `.days365`).

> **Sizing check.** 7 years of retention with a 500 MB cap is a contradiction —
> whichever binds first wins, silently. Before settling the window, measure the
> per-event byte size and the expected event rate, then either raise the cap or
> document the point at which it truncates. Do not ship both limits without knowing
> which one is real.

**3. Make audit-write failure visible** — `AuditLogger.swift:538`

`FileAuditLogHandler` swallows write errors on the reasoning that "audit logging
should not crash the application". Correct for a crash; wrong for silence. An audit
trail that has silently stopped writing is worse than one that is absent, because
it is trusted. Keep the no-throw contract, add an observable failure counter and
last-error, surfaced in the audit UI as a banner.

**4. Retire the two shadow stores**

- `SecurityService.addAuditEntry` (`:201`) and `NetworkingService.appendAuditEntry`
  (`:446`) forward to `AuditLogger.shared` instead of appending to a local array.
- Their in-memory arrays become bounded read-through caches for the UI only.
- `SecurityAuditEntry` and the Studio `AuditLogEntry` become presentation structs
  mapped from `DICOMNetwork.AuditLogEntry`. Reconcile the two outcome enums
  (`AuditLogger.swift:79` 4-level vs `NetworkingModel.swift:1195` 3-level) by
  keeping the ATNA 4-level ladder and mapping down for display.

**5. Wire it up at launch** — `DICOMStudioApp`

Nothing currently installs a handler. At startup: create the
`FileAuditLogHandler` in `StorageService.baseDirectory`, `addHandler` it (`:805`),
emit `applicationStart`, run the retention sweep. Emit `applicationStop` on
termination.

**6. Guard the Clear button** — `SecurityView.swift:527`

The audit pane has an unguarded **Clear** button that erases the trail in one click.
For a 7-year compliance record this must not be a plain destructive action. Either
remove it, or restrict it to an admin role and have it *emit an audit event* rather
than delete history (clearing the view ≠ clearing the file).

**7. Fix the ATNA export stub** — `SecurityView.swift:925`

The export sheet offers CSV / JSON / **ATNA (IHE)** (`SecurityModel.swift:563`) but
the Export button calls `exportAuditLogCSV()` unconditionally, so choosing ATNA or
JSON silently yields CSV. This is a live user-facing bug independent of the rest of
this work — a user selecting "ATNA (IHE)" for a compliance submission receives CSV
with no indication. Fix by dispatching on `auditExportFormat`. If a real ATNA
serializer is out of scope for this phase, **remove the case from the picker**
rather than leaving it mislabelled.

**Conformance note.** The current format is hand-rolled flat JSON — not RFC 3881
fields, not DICOM audit XML, no syslog framing, no remote repository transport. The
quarantined `PACSIntegrationTests.testAuditLogging`
(`PACSIntegrationTests.swift:583`) references an entirely different, never-built API
(`AuditLoggerConfiguration`, `FileAuditLogger`, `AuditSource`, and the Supplement 95
event IDs `.applicationStart` / `.dicomInstancesTransferred`). That file is
explicitly excluded from the test target in `Package.swift:417`, so it is not a
build break — it is a design intent that was abandoned. **Decide explicitly** whether
FR-014 requires ATNA/Supplement 95 conformance or only a local trail. If it requires
conformance, that is a separate work item of comparable size to this entire section,
and this plan's JSONL trail becomes its input rather than its answer.

### Tests

- Retention sweep: files older than the window deleted, newer kept, boundary at
  exactly N days.
- Append-only: an existing file is never truncated; concurrent writes from multiple
  tasks all land (the handler's serial queue should already guarantee this).
- Round-trip: every new `AuditEventType` encodes and decodes.
- Persistence across launch: write, discard the logger, re-read from a fresh one.
- Update `AuditLoggerTests.swift:35` for the new case count.
- Export dispatch: each format produces its own distinct output.

---

## FR-011 — Print queue management

### Requirement (reconstruct from SRS before building)

Eight job states; jobs persist across launches; pause / resume / cancel / retry
operations.

### Status

| Capability | State | Where |
|---|---|---|
| Job list UI | ⚠️ Read-only history | `PrintCenterView.swift:134` |
| Job list with status | ⚠️ Hub only, not persisted | `NetworkingView.swift:463-560` |
| 8 states | ❌ 4 states | `NetworkingModel.swift:1042` |
| Persistence | ❌ In-memory array | `NetworkingService.swift:57` |
| Cancel | ⚠️ Task cancel only | `PrintViewModel.swift:782` |
| Pause / resume | ❌ Absent | — |
| Retry | ⚠️ Pre-submission throws only | `PrintWorkflow.swift:164-190` |
| Queue engine | ✅ Exists, **unwired** | `PrintService.swift:1479` |

### Design

**Critical distinction — two status axes, not one.** The four missing states are
*local lifecycle* states. DICOM's Execution Status (2100,0020) has exactly four
values on the wire — `PENDING`, `PRINTING`, `DONE`, `FAILURE` (`PrintService.swift:471`,
predicates at `:495-507`) — and `SUBMITTING`, `PAUSED`, `RETRYING`, `CANCELLED` are
**not** among them. Conflating the two would put invented values on the wire and
break SCP conformance.

So: keep the wire struct `DICOMNetwork.PrintJobStatus` (`PrintService.swift:520`)
exactly as-is, and model the local lifecycle separately. Note also that the existing
raw values already disagree (`DONE` vs `.completed = "COMPLETED"`, `FAILURE` vs
`.failed = "FAILED"`) with no bridging code — the mapping below is where that gets
resolved.

**1. Rename the Studio enum and extend it** — `NetworkingModel.swift:1042`

Rename `PrintJobStatus` → **`PrintJobLifecycleState`**. The rename is what makes the
two-axis design self-enforcing; leaving both types sharing a name is how they got
conflated. Then:

```swift
public enum PrintJobLifecycleState: String, Sendable, Equatable, Hashable, Codable {
    case queued      = "QUEUED"       // was .pending
    case submitting  = "SUBMITTING"   // new — association open, N-CREATE in flight
    case printing    = "PRINTING"     // SCP reports PENDING or PRINTING
    case paused      = "PAUSED"       // new — held before submission
    case retrying    = "RETRYING"     // new — failed, awaiting backoff
    case completed   = "COMPLETED"    // SCP reports DONE
    case failed      = "FAILED"       // SCP reports FAILURE, or retries exhausted
    case cancelled   = "CANCELLED"    // new
}
```

Add `displayName` and `sfSymbol` cases (existing switches at `:1048` and `:1057`),
and a mapping from wire status:

```swift
init(executionStatus: String)   // PENDING/PRINTING → .printing, DONE → .completed,
                                // FAILURE → .failed
```

Add the legal-transition table as a `canTransition(to:)` method and test it —
`paused → completed` must be unrepresentable. `.paused` is only meaningful before
submission: once film boxes are on the wire there is no DIMSE pause, so pausing a
`.printing` job is not offered.

Update all switch sites: `NetworkingView.swift:699` and `:708`,
`NetworkingViewModel.swift:512, 521, 530, 539, 595, 618, 710`,
`NetworkingModelTests.swift:400-402`. Adding cases to a non-frozen enum makes the
compiler list every exhaustive switch — lean on that rather than grepping.

**2. Unify the job model** — new `Sources/DICOMPrintKit/PrintQueueJob.swift`

Place it in **DICOMPrintKit**, which sits above `DICOMNetwork` and below
`DICOMStudio` (`Package.swift:334`) and is already shared with the `dicom-print` and
`dicom-printscp` CLIs — so the queue is reachable from every surface that prints.

One `Codable` record replacing both `PrintJob` structs:

```swift
public struct PrintQueueJob: Sendable, Identifiable, Codable, Equatable {
    public let id: UUID
    public var label: String
    public var state: PrintJobLifecycleState
    public let createdAt: Date
    public var submittedAt: Date?
    public var completedAt: Date?

    public let printerProfileID: UUID
    public var request: PrintJobRequest      // needs Codable — see FR-013
    public var imageRefs: [PrintImageReference]

    public var attemptCount: Int
    public var lastError: String?
    public var printJobUIDs: [String]        // one per film, from the SCP
    public var filmSessionUID: String?
}
```

`PrintImageReference` carries the SOP Instance UID, the file path, **and** the
security-scoped bookmark `Data` — the Studio `PrintJob` already models this trio
(`NetworkingModel.swift:1090-1094`) and it is exactly what a reprint needs after a
relaunch (see FR-013).

**3. Persist the queue** — new `PrintQueueStorageService`

Follow the established convention exactly — the template is
`PrinterProfileStorageService.swift` (`filename` `:20`, `fileURL` `:31`, `save` with
`.prettyPrinted/.sortedKeys/.iso8601/.atomic` `:38`, `load` returning `[]` on any
error `:50`). There is no SwiftData or CoreData anywhere in the app target; do not
introduce one for this.

- File `print-queue.json` in `StorageService.baseDirectory`.
- Write on every state transition. The whole-array atomic rewrite is fine at queue
  scale (tens of jobs); it is what every sibling store does.
- On load, any job in `.submitting` or `.printing` was interrupted by a crash or
  quit. Resolve to `.failed` with "interrupted" rather than silently resuming — the
  SCP may well have printed film, and reprinting without asking wastes it. Surface
  as a retryable job so the user decides.

**4. Adopt the `PrintQueue` actor** — `PrintService.swift:1479`

Move it to DICOMPrintKit alongside `PrintQueueJob`, then:

- Retype it over `PrintQueueJob`; drop the now-redundant `PrintJobRecord` (`:1351`)
  and `PrintQueueJobStatus` (`:1400`) in favour of the unified state enum.
- Inject `PrintQueueStorageService`; persist on every mutation.
- Add `pause(jobID:)` / `resume(jobID:)`. `cancel` (`:1485`) and the retry re-queue
  in `markFailed` (`:1536`) already exist and carry over.
- Add an `AsyncStream<[PrintQueueJob]>` so the UI observes rather than polls —
  observation today is pull-only (`PrintViewModel.refreshJobStatus`, `:788`).

The actor replaces the `NSLock`-guarded `_printJobs` array. Note that lock
(`NetworkingService.swift:18`) currently guards *all* service state; removing print
jobs from it is a net reduction in contention.

**5. Cancellation semantics — three distinct cases**

Worth stating explicitly, because "cancel" means something different at each stage
and the UI must not promise more than DIMSE can deliver:

- **Queued / paused** — remove from the queue. Fully reliable.
- **Submitting / printing** — best-effort. The DIMSE path already does the right
  thing: on throw it issues an in-association Film Session `N-DELETE` (message ID
  `0xFFF0`, 5s cap) then aborts the association (`PrintService.swift:4159-4182`).
  Wire the user-initiated cancel into that same path via
  `PrintViewModel.cancel()` (`:782`), which today only calls `runTask?.cancel()`.
- **Completed** — not cancellable. Film exists. Offer reprint instead.

Label the middle case honestly in the UI: film already committed at the printer may
still emerge.

**6. Queue UI** — extend `PrintCenterView.swift:120`

The history pane (`:134`) becomes a live queue list. `NetworkingView.swift:463-560`
already has the status icon/colour/badge vocabulary — reuse it rather than inventing
a second visual language, then retire the Hub's separate list once both paths share
the queue.

Per-row actions gated on state: Pause (`.queued`), Resume (`.paused`), Cancel
(`.queued`/`.paused`/`.submitting`/`.printing`), Retry (`.failed`/`.cancelled`),
Reprint (`.completed` — FR-013).

### Tests

- Every legal transition succeeds; a representative illegal set is rejected.
- Wire-status mapping: `DONE` → `.completed`, `FAILURE` → `.failed`,
  `PENDING`/`PRINTING` → `.printing`.
- Persistence round-trip through `PrintQueueStorageService`; corrupt file → `[]`.
- Crash recovery: a persisted `.printing` job loads as `.failed`/interrupted.
- Cancel from each state; pause/resume preserves queue position.
- Retry increments `attemptCount` and stops at the policy limit
  (`PrintRetryPolicy`, `PrintService.swift:1303`).

---

## FR-013 — Reprint

### Requirement (reconstruct from SRS before building)

Re-submit a previously printed job without rebuilding it.

### Status

Absent entirely. The nearest existing thing is `PrintJobHistoryEntry`
(`PrintJobHistoryEntry.swift:10`), persisted to `print-job-history.json` with a
100-entry cap (`:75`) and written at `PrintViewModel.swift:847`.

**It cannot drive a reprint.** It records the *outcome*, not the *input*: `layout`
is a display string (`"2×2"`, built at `:853-855`), and there are no image
references at all — no SOP Instance UIDs, no file paths, no bookmarks. Everything
needed to reconstruct the job is discarded at the moment it is recorded.

### Design

**Reprint is a consequence of FR-011, not a separate feature.** Once `PrintQueueJob`
persists the full `PrintJobRequest` plus `imageRefs`, reprint is: clone the record,
new `id`, state `.queued`, `attemptCount = 0`, clear the UIDs and error, enqueue.

The one substantive piece of work is making the request persistable.

**1. Make `PrintJobRequest` Codable** — `PrintJobRequest.swift:124`

It is `Sendable` but not `Codable`, with ~51 stored properties. Most component types
are `String`-raw-value enums where conformance is a one-word addition:
`PrintPriority` (`:901` in Studio / `:209` in Network — **and this duplicate should
be collapsed first**), `MediumType` (`:216`), `FilmDestination` (`:225`), `FilmSize`
(`:277`), `FilmOrientation` (`:271`), `MagnificationType` (`:293`).

Two need real work:

- **`PrintLayoutSelection`** (`:45`) — an enum with associated values (auto /
  explicit grid / template). Needs a manual `Codable` with an explicit
  discriminator; do not rely on synthesis.
- **`PrintImageDisplayFormat`** (`:530`) — a struct wrapping the DICOM display
  format string. It has a `raw` representation already, so encode via `raw` and
  re-parse on decode, keeping one source of truth.

Add a schema `version` field to `PrintQueueJob` from day one. These records are
meant to survive 7 years of app updates; a versionless persisted format that outlives
several releases is a migration problem deferred, not avoided.

**2. Re-resolve images at reprint time**

The hard part is not the request, it is the pixels. Between print and reprint the
user may have relaunched (sandbox access lost), moved or deleted files, or removed
the study from the library. So, in order:

1. Resolve the security-scoped bookmark; fall back to the recorded path.
2. Fall back to a library lookup by SOP Instance UID.
3. If any image is unresolvable, **do not silently print a short film.** Report
   exactly which images are missing and offer to reprint the resolvable subset —
   with the layout recomputed for the reduced count, not left with holes.

This is also the honest limit of the feature, and it should be stated in the UI:
reprint re-submits the *job*, and if the source images are gone it cannot recover
them. A film-image cache is the only way around that, and it is out of scope here.

**3. Migrate the existing history**

`PrintJobHistoryEntry` records lack image references entirely, so pre-migration
entries can never be reprinted. On first launch after upgrade, load
`print-job-history.json` into the new store as completed jobs with
`isReprintable = false`, and grey out Reprint for them with a tooltip explaining why.
Keep the old file until the migration is confirmed. The 100-entry cap (`:75`) should
be revisited against FR-014's retention window — but note the *audit* trail and the
*reprintable queue* are different things with different lifetimes: 7 years of audit
records does not imply 7 years of reprintable jobs holding file references.

**4. UI**

- Reprint action on completed rows in the queue list (FR-011 §6), opening the print
  sheet pre-populated so the user can adjust before sending.
- `⌘⇧P` for "reprint last", already sketched in `DICOM_PRINT_STUDIO_PLAN.md:243`.
- Emit `printJobSubmitted` with a `reprintOf: <original id>` metadata field, so the
  audit trail distinguishes a reprint from a first print. This matters for film
  accounting.

### Tests

- `PrintJobRequest` round-trips through JSON with every field preserved, including
  each `PrintLayoutSelection` case and a non-grid (`ROW\`/`COL\`) display format.
- Reprint produces a new `id` and resets `attemptCount`, UIDs and error.
- Reprint with a stale bookmark falls back to path, then to SOP-UID lookup.
- Reprint with a missing image reports it rather than printing a short film.
- Migrated legacy entries are marked non-reprintable.
- Schema version: a v1 record decodes under a v2 binary.

---

## Summary

| FR | Core change | Main risk |
|---|---|---|
| FR-014 | Wire the existing dead `FileAuditLogHandler` as the single sink; add print/admin events; **tiered** retention (7y audit, 1y failure detail, 90d system) | Authentication does not exist, and every per-user field depends on it |
| FR-011 | Unify two `PrintJob` types into a persisted `PrintQueueJob`; adopt the orphaned `PrintQueue` actor; 8 **local** states kept distinct from the 4 wire states | Touching both print paths at once; cancel is only best-effort mid-association |
| FR-013 | Make `PrintJobRequest` Codable and persist it with image refs; reprint is then a clone | Source images may be gone by reprint time; legacy history is not reprintable |

**Answered by the SRS** (see the banner at the top):

- ~~Confirm the requirement text~~ — done; six corrections listed above.
- ~~ATNA / Supplement 95 conformance?~~ — **No.** A local append-only trail is
  sufficient; exports are CSV and PDF (§11.3).
- ~~Retention window vs. the 500 MB cap?~~ — resolved by tiering: the bulky
  diagnostic detail expires at 1 year, the compliance record persists for 7.

**Still to decide before building:**

1. Is the Hub's print path (`NetworkingView` → `executePrintJob`) being kept, or
   folded into Print Center? Both should share the queue either way, but if it is
   going away, the consolidation work in FR-011 §1 shrinks.
2. Authentication and RBAC (§14.1, four roles) is a prerequisite for FR-014's
   per-user tracking and is not scoped anywhere. Is it in this phase or its own?

**Note for FR-011.** `PrinterStatusMonitor` (FR-012, built 2026-08-13) already
reports a printer as `.offline` on a configurable poll. FR-012's last open
sub-item — auto-queueing jobs while a printer is offline — needs only somewhere to
put the job, so it should be closed as part of this work rather than tracked
separately.
