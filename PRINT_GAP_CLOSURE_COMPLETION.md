# Print gap closure — completion summary (2026-08-14)

The implementation pass that closed the open SRS print gaps, holding four items
by decision. Written after the work, verified by running the tests. Current
state of record: `PRINT_SRS_CONFORMANCE_REPORT.md`; design history:
`PRINT_FR_011_013_014_PLAN.md` and `PRINT_FR_003_004_006_PLAN.md`.

**Scorecard movement:** 9 done / 7 partial / 1 absent → **13 done / 3 partial /
1 absent** (all 17 requirements are MUST).

**Held by decision, not oversight:** per-user statistics (blocked on
authentication), FR-010 printer capability query, IPv6, FR-015 modality
presets.

---

## FR-011 / FR-012 / FR-013 — the queue, finished

| What | Where |
|---|---|
| Queue persistence | `Sources/DICOMStudio/Services/PrintQueueStorageService.swift` (new), `PrintQueueService.swift` |
| Codable payload chain | ~20 leaf types across DICOMCore / DICOMNetwork / DICOMPrintKit / DICOMStudio |
| States + retry | `PrintQueueService.swift` (`State`, `scheduleRetry`) |
| Offline auto-queue | `PrintQueueService.isPrinterReady` / `reevaluate()`, wired in `PrintViewModel` |
| Reorder | `PrintQueueService.move`, drag in `PrintQueueView` |

- **Persistence.** `print-queue.json`, written on every state transition and
  never on progress ticks. `PrintQueueJob.result` is deliberately excluded
  (it wraps DIMSE types; job history is the durable record of outcomes). Only
  the app's shared `PrintViewModel` gets the storage — previews, standalone
  viewers and tests stay off the file.
- **Restore rules.** Jobs that died mid-print restore *failed*
  ("Interrupted"); waiting jobs whose source files vanished fail at restore,
  naming the path; and the queue restores **held** — a launch never opens an
  association on its own, resuming is a deliberate act.
- **Full §6.2 state set.** SUBMITTING and RETRYING added (8-for-8). Thrown
  faults auto-retry — default 2 extra sends, 5 s apart — gated on the
  persisted attempt count (§8.2 "retry count < max" survives a restart).
  A printer that answered and *rejected* the job does not retry.
- **Offline auto-queue** (the last FR-012 item). A monitored-offline printer's
  job stays pending, saying why; the monitor's next good update releases it.
  Strictly FIFO. Unmonitored printers are not gated — no live status to trust.
- **FR-013.** Resend replays the captured payload, now from disk, so reprint
  survives a restart. Fresh SOP Instance UIDs are guaranteed by construction:
  the SCU never generates print UIDs — every N-CREATE takes the SCP's
  assignment.

## FR-014 — audit trail, evidentiary (per-user stats held)

All in `Sources/DICOMStudio/Models/PrintAuditEvent.swift` and
`AuditTrailView.swift`:

- **§11.1 fields** on every new event: session ID (one UUID per launch),
  source (recording host — printing is initiated locally), before/after states
  on transitions. Pre-existing trail files still decode, their events unhashed.
- **§11.2 tamper evidence.** SHA-256 hash chain, each entry sealing the one
  before it. `verifyIntegrity()` walks the chain; the Audit Trail tab shows a
  red shield naming the first broken link. Tested by doctoring the JSON on
  disk. Honest limit: this detects *outside* tampering — the app itself can
  still rewrite the file; true append-only storage or signing is beyond what
  §11.2's recommended hash chain asks.
- **§11.3 tiered retention** replaces the 500-event cap: events 7 years,
  failure *detail* redacted at 1 year (the event stays). Redaction re-chains
  and records itself as `retentionApplied`, so the trail explains its own
  edits.
- **The Clear control is gone** — API and button. Retention policy is the only
  thing that removes an event (§11.2).
- **CSV export** added alongside JSON and PDF, for the audit trail and the job
  history both.

## FR-004 — window/level & LUT processing, finished

- **SIGMOID** (`PrintImagePreparer.resolvedFunction`). A viewer mark's window
  arrives as bare numbers whose function defaulted to linear; the print path
  now inherits the file's VOI LUT Function (0028,1056) — the function belongs
  to the image (PS3.3 C.11.2.1.3). An explicit non-linear request function
  still wins. This was the one silent-wrong-contrast path.
- **Custom Presentation LUT** (`PresentationLUTTable`, DICOMNetwork). Sent as
  the Presentation LUT Sequence (2050,0010), descriptor + OW data, in the
  N-CREATE instead of a shape; plumbed from
  `PrintJobRequest.presentationLUTTable`. Validates entry count and depth at
  construction; the 65536-entry descriptor-zero wrap handled.
- **LIN OD** (`FilmComposer.linODTransfer`). A real density curve: P-values
  map linearly to optical density across the film box's Min/Max Density range,
  and displayed luminance falls as 10^(−OD) — mid-gray transmits ~4% of full
  light, not the 50% the old invert-toggle drew. Orientation deliberately
  unchanged so existing films do not flip; flipping is a one-line change if a
  lightbox comparison ever says otherwise.

## FR-006 — annotation bands (small residuals remain)

- **`FilmAnnotationEdge`** — footer (default, unchanged) / header / left /
  right / overlay. The cell layout (`FilmCellLayout.cells`) carves the band
  off the chosen edge; side bands cost width, never height; overlay reserves
  nothing and draws over the pictures. Side text runs spine-wise (left reads
  top-to-bottom, right bottom-to-top), by rotating the drawing context.
- Exposed in the printer emulator's settings as **"Annotation position"**,
  persisted with `PrintSCPSettings` (tolerant decode — old settings files
  load).
- **Still open (small):** custom free-text field and Study Time as selectable
  identification fields, halo/background configuration, and the per-image
  caption floor stated in points rather than pixels.

---

## Verification

- Full suite: **7,477 tests / 743 suites** — green apart from two pre-existing
  flaky tests (the Print SCP loopback end-to-end and a cache timing benchmark;
  both fail intermittently on clean `de67c39` too) and one known JPEG2000
  issue.
- New/changed coverage: `PrintQueueAuditTests` (29 — persistence round-trip,
  interrupted-restore, missing-source, reorder, retry cap, offline gate, hash
  chain, tamper detection, tiered retention, CSV), `PrintWindowSpaceTests`
  (13 — SIGMOID inheritance and pixel effect), `FilmComposerTests` (30 —
  LIN OD orientation + curve, band placement per edge, cell carving),
  `PresentationLUTTableTests` (3 — validation and exact element bytes).
- The tamper and retry tests were checked to *fail* without their fixes.

## Known caveats

1. Side-band typography passes its ink-placement tests but has not been
   inspected visually in the running app.
2. The retry default (2 extra sends) composes with `PrintJobRequest.retries`
   (the DIMSE-layer knob); a site that sets both gets both.
3. Restored queues hold until resumed — deliberate, but it means film asked
   for before a crash does not print until someone presses Resume Queue.
