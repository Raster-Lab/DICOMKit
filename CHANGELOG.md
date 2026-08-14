# Changelog

All notable changes to DICOMKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed — the preview survives a scaling change, says when its tools are off, and sets its corners in one size (2026-08-14)

*Work in progress, not yet committed.*

- **Changing the scaling mode no longer kills the preview.** The mode decides
  which cache draws each cell — Stretch is CPU-drawn, the rest come off the
  GPU — without changing a single mark, so switching to Stretch asked for
  thumbnails that had been deliberately released while the GPU had the film,
  and nothing re-requested them: every cell fell to a spinner, and every tool
  drag looked dead until some unrelated edit happened to refresh the caches.
  The caches now refresh the moment the mode changes.

- **The film says when a job setting has taken the tools away.** Raw pixels
  disable window/zoom/pan/invert by definition, and the job-wide window
  disables per-cell windowing — but both did it silently: the drag was
  accepted and discarded, and the switch that did it sits folded away under
  More. A notice over the film now names the setting and what still works.

- **Identification corners are one block of type again.** A long line — a
  study description, an institution name — used to shrink alone (down to
  half) while the patient's name beside it kept full size, so one cell's
  corners came out in two font sizes; the burner meanwhile drew every line at
  full size, so the film disagreed with the preview too. Preview and burner
  now compute one size per cell — the cell's own, stepped down as a whole
  block until the widest line fits its corner — measured with the same face
  so they step down together.

### Added — the image filter works on a film that mixes series (2026-08-14)

*Work in progress, not yet committed.*

"Filter Images" used to be withheld the moment a second series was marked,
because image numbers restart at 1 in every series and one global "60 to 140"
would have taken a different run out of each. The filter now carries **one
range per marked series**, keyed by the series' identity (Series Instance UID,
with the existing description/folder fallbacks):

- The popover shows a row per series — its description, its marked run, and
  its own From/To fields plus a per-series "All" button. A single-series film
  gets the one row it always had. Rows are named by Series Description: from
  the mark, else read out of the file header alongside the image numbers — so
  a whole-series mark from a UID-named export folder still gets a readable
  name, not the UID.
- Each range clamps to its own series' bounds, and the ordinal fallback for
  unnumbered files now counts within the series, not across the film.
- Everything downstream still reads one filtered list (`printedItems`), so the
  preview, the plan and the print run cannot disagree; ranges whose series
  leave the film are dropped by the clamp, and a new film still starts
  unfiltered.

### Added — the queue survives a restart, the audit trail becomes a record, and four print-correctness gaps close (2026-08-14)

*Work in progress, not yet committed.*

The queue and audit trail built earlier today did their jobs only while the app
stayed up and only for a reader who trusted the file. This pass makes the queue
durable and the trail evidentiary, and closes the FR-004/006 rendering gaps —
one of which printed wrong contrast without saying so.

- **The print queue survives a quit or crash.** Jobs persist to
  `print-queue.json` on every state transition (never on progress ticks — a
  job restarting at 40% would be a lie). On relaunch, jobs that were on the
  printer come back **failed** ("Interrupted — the app quit while it was
  printing"): their association is gone and pretending otherwise would be
  worse. Waiting jobs come back waiting — but the queue restores **held**,
  because an app launch must never open an association and print film on its
  own; resuming is a deliberate act. A waiting job whose source file no longer
  exists fails at restore, naming the path, rather than at print time.
  Reprint therefore survives a restart too: Resend replays the captured
  payload from disk.

- **The queue speaks SRS §6.2's full state language.** SUBMITTING (association
  setup and image preparation) and RETRYING join the states. A job whose run
  *throws* — a dropped association, an unreachable printer — retries
  automatically, up to a cap, a few seconds apart, with the attempt count
  persisted so the §8.2 "retry count < max" gate survives a restart. A printer
  that **answered and rejected** the job does not retry: rejection is final,
  a fault is not.

- **A job for an offline printer waits instead of failing.** The last FR-012
  item: when the status monitor knows a printer is offline, its job stays
  pending — the row says it is waiting for the printer — and the monitor's
  next good report releases it. Strictly FIFO: a later job does not jump an
  offline printer's job, because queue order is a promise about film order.
  Only monitored printers hold jobs; an unmonitored printer has no live status
  to trust, so its jobs run and fail honestly.

- **Jobs can be reordered by dragging** in the queue list. The running job is
  tracked by ID, not position, so moving rows is always safe.

- **The audit trail is now a record, not a list.** Every new event carries a
  session ID (one UUID per app launch), the recording host, and — on
  transitions — the state before and after. Events are **hash-chained**
  (SHA-256, each entry sealing the one before it): editing a recorded field or
  removing an event from the middle breaks every hash after it, and the Audit
  Trail tab shows a red shield naming the first broken link. Trails written
  before these fields existed still load; their events are simply unhashed.

- **Retention is a policy, not a count.** The 500-event cap — which a busy
  department would roll past in days, silently — is gone. Audit events live
  seven years; a failure's *detail text* is redacted after one (the event
  itself stays); the rewrite re-chains the hashes and is itself recorded as
  a `retentionApplied` event, so the trail explains its own edits.

- **The Clear button is gone.** SRS §11.2 forbids deleting audit records, and
  a control whose own dialog conceded "This cannot be undone" had no business
  existing. Retention policy is now the only thing that removes an event.

- **CSV joins JSON and PDF** in the export menus of both the audit trail and
  the job history — the spreadsheet form §11.3 names.

- **A SIGMOID image now prints with sigmoid contrast.** A window carried off a
  viewer mark arrives as two bare numbers, and its VOI LUT Function silently
  defaulted to linear — the one place the never-silently-degrade rule was not
  honoured. The print path now inherits the file's (0028,1056), because the
  function belongs to the image; an explicit non-linear choice on the request
  still wins.

- **A custom Presentation LUT can be sent.** `PresentationLUTTable` travels as
  the Presentation LUT Sequence (2050,0010) — descriptor and 16-bit data — in
  the N-CREATE, instead of a shape, for printers calibrated against a
  site-supplied curve.

- **LIN OD is a density curve, not a negation.** The composer previously
  approximated Linear Optical Density by inverting the pixels. It now maps
  P-values through the film box's Min/Max Density range with transmitted
  luminance falling as 10^(−OD) — mid-gray on film transmits ~4% of full
  light, not 50%. Orientation is unchanged, so existing films do not flip.

- **The film-wide caption band can sit on any edge.** Footer (the default,
  unchanged), header, either side — where the text runs spine-wise along the
  film — or drawn over the images without reserving space. The band is carved
  out of the picture area on its edge only: a side band never costs the
  images height. Chosen in the printer emulator's settings as "Annotation
  position", persisted with the rest of the SCP settings.

### Changed — print preview: what is armed is now visible before the drag (2026-08-14)

*Work in progress, not yet committed.*

The preview's tools were readable only from the rail at the edge of the screen,
and only if you went and looked. Everything here is about making the answer to
"what will this drag do, and to how many cells" available where the hand
already is.

- **The pointer says which tool is armed.** Over a cell with a picture in it,
  the cursor takes the tool's shape — the plain arrow for W/L (matching the
  rail's own pointer glyph, and leaving the default tool's film untouched), a
  magnifier for zoom, an open hand for pan that closes while the drag is
  running, an I-beam for text, a crosshair for arrow. Empty cells and the sheet
  margin keep the normal arrow, since no tool can act there. Via a tracking
  area and `cursorUpdate` (`ToolCursor`), not `NSCursor.push()`/`.pop()`: hover
  callbacks do not arrive in balanced pairs, and moving quickly between cells
  left the pushed cursor stuck over the whole window. The overlay refuses hits
  in `hitTest` rather than through SwiftUI's `allowsHitTesting(false)` — the
  latter takes the view out of cursor tracking too, which is why the shape only
  ever changed when a tool was switched under a stationary mouse.

- **The W/L tool's rail icon is a pointer.** It was `circle.lefthalf.filled` —
  the same glyph the Invert button carries, mirrored — so two buttons a few
  points apart showed the same shape.

### Changed — advanced print defaults for the department setup (2026-08-14)

*Work in progress, not yet committed.*

The sheet now opens with Medium: Blue Film, Destination: Magazine,
Magnification: Bilinear, Presentation LUT: None (unchanged), and the burned
identification includes birth date and institution alongside the always-on
name/ID lines. Nothing here is persisted, so every launch starts from these;
within a session they still survive between films as department settings.
Burned birth date is a deliberate choice — it lives in the pixels and survives
later header de-identification.

### Fixed — the pan tool did nothing on a fill-scaled film (2026-08-14)

*Work in progress, not yet committed.*

Two halves of the same bug, found a layer apart. A fill-scaled cell is showing
a crop at every zoom, so a pan has real travel even unzoomed — but every step
of the pipeline read the picture with the *fitted* geometry:

- `ViewerPresentation.clampedPan` computed its travel limits from the fit
  scale, so at zoom 1 the limits were zero and the model discarded every pan.
  Fixed first: a `covers:` flag scales by `max` rather than `min`.
- That alone moved nothing on screen, because `visibleRegion` — the call that
  decides which pixels the shader and the film actually get — re-clamped the
  now-surviving pan with the same fitted assumption and answered "the whole
  image", which the fill crop then re-centred. The pan lived in the mark and
  died on the way to the pixels.

`visibleRegion` now takes the same `covers:` flag, and the film's real scaling
mode is threaded from one truth to every consumer: the model's clamps
(`panCell`, the zoom-out re-clamp, the linked-cells propagation), the preview
shader (`PrintCellDisplay.presentation`, covering when a fill cell size is
passed), and the print pixel path (`PrintPresentationTransform.apply` via
`PrintService`, from `request.scalingMode`) — so the film prints the same
panned crop the preview shows. `PrintFillPanTests` asserts on what the shader
and the transform are given, not on the stored value, which is exactly the gap
the first fix fell into.

Corrections to the first attempt: Stretch is out of the covering set — it
covers the cell by distortion, not by cropping, so nothing is hidden and a pan
has nowhere to go, same as fit. Fit at zoom 1 likewise remains a no-op by
design: the whole image is on the film, and the preview does not pretend a
drag would print. Zooming a fill cell back out to 1 still keeps the reader's
framing, since zoom 1 there is still a crop. The CPU thumbnail fallback keeps
the fitted read (it is shared with the viewer); a fill cell drawn from it shows
the centred crop only until its texture lands and the GPU path takes over.

- **The tools and locks reset on every visit.** They used to survive as
  "working habits", alongside the printer and film size. The difference is
  that a habit is visible when you come back to it and an armed mode is not:
  a reader who left the pan tool armed with the W/L lock shut pans four cells
  on the next visit's first drag, and finds out afterwards. The screen now
  always opens windowing, nothing locked, nothing picked, scope back to the
  series. Job settings — printer, film size, medium, identification — still
  survive, as before.

- **The sync locks are in the same order as the tools.** W/L, Zoom & Pan,
  Invert — matching the rail above them, so a lock sits where the tool it
  holds together does.

- **Separators are visible.** The rail's group rules and its edge against the
  film were hairline `Divider`s that all but vanished; they are now a 1pt rule
  at 45% secondary. The rail's grouping is what makes eleven buttons readable
  as four groups.

- **Every control on the rail has a key.** The five tools already had W, Z, P,
  T, R; the sync locks, the scope and Pick did not, and those are exactly the
  controls reached for mid-drag with the other hand on the film. A lock takes
  its tool's key shifted — ⇧W, ⇧Z, ⇧V — which is the same tool-to-lock pairing
  the rail now shows by ordering them alike. S swaps a shut lock's reach
  between Series and Film; A picks the run of cells from the focused one, or
  lets a picked set go. The full table is documented on `toolShortcuts`.

- **One door for shutting a lock.** The rail button, the context menu and the
  new shortcut all go through `toggleSyncFromUI(_:)`, which carries the window
  seeding (cells never opened have no window for a relative edit to work from)
  and the job-wide-window refusal. Previously the seeding was copied into each
  call site; a shortcut is delivered whether or not a disabled button would
  have taken the click, so that refusal had to move below the button.

- **Tooltips are a guide, not a label.** Every tool, lock, scope, selection
  and reset control now states the gesture, what it changes, its shortcut, and
  — read live from the same rules the drag itself uses — how many cells the
  next drag will actually reach. The film size, printer, orientation and copies
  controls gain the tooltips they never had, and the film size menu is labelled
  "Film Size" rather than "Film", which read as a heading for the whole bar.

### Added — app-side print queue and audit trail (2026-08-14)

*Work in progress, not yet committed.*

Queue management and the audit trail are app responsibilities, so both live
entirely in DICOMStudio — no package logic moved, and no login module: the
trail records what this app instance did, not who was signed in.

- **Print jobs now go through a queue.** `PrintQueueService` (DICOMStudio)
  executes submitted jobs one at a time, so two jobs never interleave
  associations on the same printer. Jobs move through pending → running →
  completed/failed, with paused and stopped under user control. The print
  sheet still mirrors its own job's phase, console, progress and result —
  through handlers the queue calls — so the submit flow looks unchanged.

- **Queue management screen.** The Print Center's right pane gains a
  Queue / History / Audit Trail switcher. The Queue tab lists every job with
  its state, progress and attempt count, with per-job actions the state makes
  meaningful — Start Now (jump the line), Pause/Resume (hold a waiting job),
  Stop (cancel; the SCU N-DELETEs the film session), Resend (a finished job
  re-enters the queue as a fresh attempt with the same captured payload),
  Remove — and queue-wide Pause/Resume, Stop All and Clear Finished.
  A running job cannot pause: its association is already open, so pausing
  one is refused rather than half-honored.

- **Audit trail, recorded and persisted app-side.** Every queue action and
  job outcome — submitted, started, completed (with Print Job UIDs), failed,
  paused, resumed, stopped, resent, removed, queue-level actions, history
  clearing — lands in `print-audit-trail.json` (newest first) the moment it
  happens, so a crash mid-job still leaves a record. The Audit Trail tab
  browses it with text search, an action filter and export. (Retention,
  tamper evidence and the removal of the clear control are in the later
  entry above.)

- **Both records export as PDF as well as JSON.** The Export button in the
  History and Audit Trail panes is now a menu offering **JSON…** or **PDF…**.
  JSON is unchanged and still byte-identical to the on-disk store, for another
  program to read. PDF renders a paginated Letter-size report — title, row
  count and generation date, ruled column headings, and a page footer — for
  the reader who is filing it with a QA record or handing it to a service
  engineer rather than running `jq` over it. The audit PDF always covers the
  whole trail, not the current search filter: an exported audit record that
  silently dropped rows would be a misleading document to file. Empty records
  still produce a one-page "No records." report, since a zero-page PDF is a
  file no viewer will open.

- **History records resends too.** Job history is now written by the queue's
  completion callback rather than the print sheet, so a job resent from the
  queue screen lands in Recent Jobs like any other. Cancelled jobs stay out
  of history — it remains a record of jobs that were sent — while the audit
  trail keeps the stop.

### Added — the print history answers questions, not just lists jobs (2026-08-14)

*Work in progress, not yet committed.*

The history stored every job's Print Job SOP Instance UIDs but never showed
them again: "did that print?" could only be asked while the print sheet was
still open. The Print Center's Recent Jobs pane now closes that loop.

- **Check Status on a past job.** Each history row with recorded job UIDs gains
  a **Check Status** button that N-GETs every film's execution status from the
  printer the job was sent to (found by name — if the profile has since been
  removed, the row says so instead of failing silently). Multi-film jobs get
  one line per film — `Film 2: FAILURE (CHECK PRINTER)` — coloured and
  glyphed by state, matching the print sheet's own status display. Results are
  in-memory only: an execution status is what the printer says now, so a stale
  answer from a previous launch would mislead. The query runs through a new
  `PrintJobStatusQuerying` seam (same pattern as the status monitor's probe),
  so the flow is tested without a printer on the network.

- **The UIDs are visible at last.** Hovering a history row shows the Film
  Session UID and Print Job UID(s) as a tooltip.

- **Fixed: the emulator forgot its print jobs the moment the SCU released.**
  `DICOMPrintServer` kept Print Job records on the association, so any status
  query on a later association — which is how "Check Status" necessarily asks —
  answered 0x0112 *No such SOP Instance* for a job it had just printed. Film
  session state is rightly association-scoped (PS3.4 H.4), but the Print Job
  SOP Instance is exactly the part that must outlive the release (PS3.4
  H.4.8). Jobs now live in a server-wide `PrintSCPJobStore`, bounded to the
  100 most recent. A loopback test prints, releases, and N-GETs the job on a
  fresh association.

- **Export… and Clear…** in the Recent Jobs header. Export writes the history
  as JSON in the exact on-disk format (`print-job-history.json`), so an
  exported audit file and the live store are interchangeable. Clear asks first
  and removes the entries from disk as well.

### Added — the workstation notices a printer changing state on its own (2026-08-13)

*Work in progress, not yet committed. Closes five of the six FR-012 sub-items
of `PRINT_SRS_CONFORMANCE_REPORT.md`; the sixth needs FR-011's queue.*

A printer's state was only ever as fresh as the last time somebody pressed a
button, and it was reported in two colours where the standard defines three.
A printer low on film looked exactly like one that had failed.

- **A printer's state is now a closed enum, not a string comparison.**
  `PrinterStatusSeverity` covers the three states PS3.3 C.13.9 defines —
  NORMAL, WARNING, FAILURE — plus `unknown` for an SCP that answered with
  something else. Parsing is lenient about padding and case, because CS values
  arrive padded and non-conformant printers vary the case; anything it cannot
  place becomes `unknown` rather than being read as healthy, since the
  dangerous failure is a printer we cannot understand being handed a job.
  `PrinterStatus.isNormal` keeps working, joined by `isWarning`/`isFailure`.

- **WARNING is no longer reported as an error.** `ServerConnectionStatus` gains
  a `warning` case and the status pane maps onto it, replacing
  `status.isNormal ? .online : .error` — which had been telling the user a
  printer with low film was broken. A warning printer still accepts jobs, per
  the SRS: blocking on it would stop usable work. Warning and failure differ in
  glyph as well as colour, so the distinction survives for a colour-blind
  reader.

- **Background polling on a configurable interval (10–300s).**
  `PrinterStatusMonitor` runs one task per printer rather than a shared timer,
  so an unreachable printer cannot set everyone else's cadence. The first poll
  is jittered: printers enabled together would otherwise open associations in
  lockstep for as long as the app runs. On failure the interval doubles to a
  ten-minute ceiling and resets the moment the printer answers, so a printer
  switched off overnight is not probed every ten seconds until morning.

- **Monitoring is opt-in per printer, and off by default.** Polling opens a
  real association on someone's hospital printer; that is a thing to ask for,
  not something to switch on for every profile a user has ever saved.

- **Polled status is deliberately not persisted.** It is observed state, and
  writing `printer-profiles.json` on every poll would rewrite the file every
  few seconds per printer to store something meaningless after a restart. The
  interval and the opt-in *are* persisted, and a profile written before those
  fields existed still decodes — an older file loads with monitoring off
  rather than dropping every printer the user configured. An out-of-range
  interval, from a hand-edited file or an older build, is clamped rather than
  trusted: at zero it would be a hot loop against a hospital printer.

- An unreachable printer reports as offline, a failed one as error. "We could
  not ask" and "it answered and said it is broken" are different facts, and an
  operator needs to tell them apart.

- 43 tests. The probe and the clock are both injected, so the backoff curve,
  the lifecycle and the legacy-JSON decode are asserted without a real printer
  or a real second passing.

### Added — print scaling modes, table LUTs, and optional identification fields (2026-08-13)

*Work in progress, not yet committed. Closes the FR-003 / FR-004 / FR-006 gaps
of `PRINT_FR_003_004_006_PLAN.md`; every default reproduces the previous
output byte for byte.*

- **Scaling modes (FR-003).** `PrintScalingMode` — Fit to Film (the old and
  still-default behaviour), Fill to Film, True Size (1:1), and Stretch — with
  9-way `PrintCellAlignment` positioning. Fit and fill travel to a real
  printer as Requested Decimate/Crop Behavior (2020,0040); true size
  additionally sends Requested Image Size (2020,0030), computed per image from
  Pixel Spacing / Imager Pixel Spacing / Nominal Scanned Pixel Spacing —
  column spacing × columns, so a crop narrows the request with it, a quarter
  turn swaps the axes, and a free-angle resample clears it. An image with no
  recorded spacing falls back to fit **with a console warning**, never
  silently: a wrong-scale film is one a clinician might measure against.
  Stretch and the alignment have no DICOM form and apply where the toolkit
  composes the film itself (preview, Save Film, the SCP emulator); the
  settings sheet says so. The film-box composer's CROP path now honours
  Requested Image Size (PS3.4 H.4.3) instead of ignoring it. In the live
  preview, fill is composed into the display shader's *source region* — the
  cell's Metal view keeps one size through every tool drag, which is what
  keeps a tool step at one quad redraw — and stretch draws on the CPU path,
  which can ignore the aspect. True size and non-centre alignment draw as
  centred fit on screen (a panel-scaled sheet has no physical size) and are
  exact on the composed film. Print preview cells sample bilinear where the
  viewer stays nearest-pixel: a film cell is judged as a picture, its
  CPU-drawn neighbours are smoothed, and a cell must not change texture the
  moment its GPU texture arrives.
- **Table-form LUTs (FR-004).** `GrayscaleLUT` decodes the Modality LUT
  Sequence (0028,3000) and VOI LUT Sequence (0028,3010): descriptor entry
  count 0 meaning 65536, sign following the pixels (and, for VOI, a negative
  rescale intercept), byte- and word-packed data, clamping at both ends, and
  normalization over the table's actual range so a 12-in-16-bit table keeps
  the film's full dynamic range. A Modality LUT **replaces** the rescale pair
  (PS3.3 C.11.1 makes them mutually exclusive); the VOI precedence is now
  explicit user window → VOI LUT table → header Window Center/Width →
  auto-stretch. Before this, an image whose presentation requires a table LUT
  printed with the wrong contrast, silently.
- **Window presets beyond CT and MR (FR-004).** CR/DX, MG, PT (SUV), NM and
  XA/RF join the preset table, in the viewer and the print cell tools alike.
  US stays empty deliberately: its frames are display-ready and a fixed
  window would be an invented number.
- **Optional identification fields (FR-006).** Birth date, accession number,
  institution and series description can join the burned caption — each
  opt-in, each in a documented corner, all off by default so the default film
  is unchanged. Birth date stays off unless deliberately chosen: burned into
  pixels it survives later header de-identification. Caption typography is
  now configurable (`PrintAnnotationStyle`: font family, size as a fraction
  of the frame clamped to a legible 2–10%, forced white/black that still
  flips for MONOCHROME1); the automatic style remains the default and the
  recommendation. The film footer's minimum type size rises from 2.5 mm to
  2.82 mm — the SRS's 8 pt floor stated physically.

### Changed — every film cell says what made its picture (2026-08-10)

*Work in progress, not yet committed.*

The caption under a film cell named the patient and the study, and stopped
there. A reader comparing two slices on one sheet is comparing their technique
as much as their anatomy, and that was on neither.

- **What made the picture, each value under its own label.** `Modality: CT`,
  `Image: 45` — the acquisition sequence number, with the series left off, since
  a cell is one image and its series is already named by the study description
  above it — then the technique that modality is actually read by:
  `Slice Thickness: 5.00 mm` and `kVp`/`Exposure` on a CT, `TR`/`TE` and
  `Field Strength` on an MR, `kVp`/`Exposure`/`View` on a plain film, thickness
  and `Radiopharmaceutical` on PT/NM. Anything the list does not know still gets
  its slice thickness. Labelled because "5.00 mm" alone could be a thickness, a
  spacing or a slice interval; whatever the scanner did not record is left off,
  since a film that prints "kVp:" with no number beside it has said something
  false about a machine. The patient and the study stay unlabelled — a name
  reads as a name.
- **The study date carries its time.** `15 Oct 2025 14:32`, to the minute: a
  patient can be scanned twice in a day, before and after contrast, and two
  films differing only by the hour are two films nobody can put in order.
- **The film footer is gone.** Stating the identification once at the foot of a
  sheet only worked while every cell said the same thing; a caption that names
  the image's own number and thickness cannot be lifted off the picture it
  belongs to. Captions are now always under the image, burned into the pixels
  that carry them, so nothing depends on whether a printer honours annotation
  boxes. The "Caption" placement picker and its context-menu twin are gone with
  it; the identification switch remains.
- **The caption moved into the corners, as on the viewer.** Not a strip below
  the picture: the corners of a fitted image are background, the reader's eye is
  in the middle, and a caption under the picture is one read by looking away
  from the anatomy it describes. The arrangement is the workstation's — who and
  what at the top right, what made the picture at the bottom left, the study
  date at the bottom right, the top left left clear for the printer's own label
  — so a film and the screen it was approved on are read the same way.
- **The picture gets its rows back.** Nothing is scaled to make room, in the
  preview or in the burned pixels: `ImageAnnotationBurner` draws the four corner
  blocks over the frame with a halo at the opposite end of the greyscale, so
  each line survives both a white lung field and a black background, and
  `PrintCornerAnnotation` is what the preview and the burner both lay out from.
  Set plain, at one weight, on screen and on film: nothing in the corners is a
  different kind of statement from anything else there, and the halo is what
  keeps a line legible, not its weight. The blocks are pushed into the corners
  of the *cell* rather than of the picture inside it — a frame that is not the
  cell's shape leaves a letterbox margin, and text held to the picture reads as
  floating in the middle of the sheet — and set a size smaller than the viewer's
  corners, since a film cell carries more lines in less room.

### Fixed — the range filtered by position, and ⌘-click never landed (2026-08-11)

*Work in progress, not yet committed.*

- **The image range now matches the series' own numbers.** It was falling back
  to each mark's *position in the tray*, which equals the image number only when
  a series is marked whole, from image one, with nothing skipped — so "3 to 9"
  printed whichever seven marks sat in those slots. Marking a whole series
  records paths and no numbers on purpose (reading two hundred headers to label
  a tray nobody has opened would stall the viewer), so the numbers are now read
  from the files themselves: header only, stopping at Instance Number, done once
  and kept, and only when the range control is actually opened. The control
  greys out while it reads rather than letting a range be typed against half the
  numbers.
- **⌘-click reaches the selection.** It was expressed as a second, modified
  `TapGesture` alongside the plain one, and SwiftUI's priority rules gave the
  plain one the click — so every ⌘-click arrived as an ordinary click, the
  picked set never grew past the cell clicked last, and Delete took only that
  cell. The modifier is now read from the event inside the one tap handler, so
  there is no contest to lose. A plain click on an unpicked cell clears the set,
  which is what makes "click somewhere else and start again" work.
- **Delete works from the keyboard.** It was handled by the film's own key
  handler, which needs the film to hold keyboard focus — after a click in the
  settings column or the range popover it does not. It is a shortcut now
  (⌫ and ⌦), delivered wherever the print screen is, and still takes a selected
  annotation before the cell it was drawn on.

### Added — a run of the series, and thinning a sheet out (2026-08-11)

*Work in progress, not yet committed.*

- **Images: from ( ) to ( ).** A CT of two hundred slices is fourteen sheets, and
  the reader wants the four where the finding is. The range names them by the
  image's own number — the one printed in the cell's corner — and the films are
  laid out from what falls inside it.

  It is a **filter, not an edit**: the marks it holds back keep their windowing
  and their arrangement, widening the range brings them straight back, and *Load
  All Images* is one click rather than a re-mark of the series. One filtered
  list feeds the plan, the preview and the print run, so the sheet on screen is
  the sheet the printer receives. Offered for a single series only — across two
  the numbers restart, and one range would take a different run out of each.
- **Cells come off the film with ⌫.** The picked cells, or the focused one, from
  the cell's own menu or the delete key — which still takes a selected
  annotation first, innermost thing first. The rest of the film shuffles up in
  order: image 7 moves into the hole image 4 left, no cell is left blank in the
  middle of a sheet, and the last film simply ends earlier. The focus lands on
  the cell that moved up into the first hole, so a run of deletions is done from
  one spot instead of chasing the picture around the sheet.
- **Locks stop at the edge of the sheet.** A locked window or zoom now reaches
  only the film being judged. It is the sheet in front of the reader and the
  only one whose cells they can watch move; re-windowing thirteen films nobody
  has turned to is an edit whose effects are discovered on paper. The scope
  choice is now *Same Series* or *Whole Film*, both read as "…on this film", and
  "All Cells" is gone.

### Added — picking out the cells a tool acts on (2026-08-11)

*Work in progress, not yet committed.*

The locks answer "which cells move with this one" by rule — same series, this
film, everything. That is right when the rule is the intent. It is the wrong
shape for "these four, and not the rest", which is common enough that stating
it as a rule is a chore.

- **⌘-click picks cells out.** A checkmark badge marks each one, a thin accent
  ring draws round it, and the film's caption says how many are picked. Escape
  clears them, and so does the rail's own button.
- **Select ▸ Succeeding Cells on This Film**, on the cell's right-click menu,
  takes the focused cell and everything after it on the sheet — stopping at the
  film's edge, so what a drag is about to touch is on screen to be seen. *All
  Cells on This Film* is beside it.
- **A selection outranks the locks.** While two or more cells are picked, every
  tool — window, zoom/pan, invert — acts on exactly those and the locks stand
  aside. An explicit selection is a statement the reader has just made by hand,
  and a lock quietly widening it to the rest of the series would undo the point
  of making it. Drag a cell that is *not* picked and it moves alone. Clear the
  selection and the locks are in charge again, unchanged.
- **A job-wide window still wins.** Nothing per-cell reaches the film then, so a
  picked selection carries no window edit either — geometry still travels.
- **The lock badge moved to the top left.** The identification now occupies the
  top right and both bottom corners, and a badge over a patient's name is a
  badge over the one thing on the film that must stay legible.
- **The film grew into the slack it already had.** The page arrows float over
  the empty gutter beside a portrait sheet instead of charging the picture 68
  points for two chevrons standing in space; when the panel is too tight for
  that, they take their gutter back and the sheet fits in the rest. The layout
  button now says what it is — *Layout: 4×5*.

### Fixed — a film of sixteen cells loaded one decode at a time (2026-08-11)

*Work in progress, not yet committed.*

`FrameSourceCache` is an actor, and it read and decoded the file *inside* its
own isolation. Every cell after the first therefore queued behind a full
JPEG 2000 decode, and a window/level drag — which needs nothing but pixels
already in hand — queued behind all of them: a 4×4 film trickled in row by row
and the tools felt dead while it did.

- **The decode runs off the actor.** The cache is shared state and has to be
  serialised; the codec is not. Each path's decode is a detached task the actor
  awaits, so sixteen files decode concurrently and sixteen cells of one file
  share a single decode.
- **A byte budget, not a file count.** The cache held three files, which is far
  too few for a film whose every cell is being adjusted — loading cell sixteen
  evicted cell one, so dragging it re-decoded from disk. It now holds 256 MB of
  decoded pixels, never fewer than three files, which is a whole CT film over.
- **Identification is read per film.** The preview parsed every marked file's
  header up front — a hundred marks is a hundred full reads competing for the
  same disk and cores as the decodes the cells are waiting on. It now reads the
  film on screen, and the next one when it is turned to.
- **A new layout loads its new cells.** The preview refreshed its caches when
  the film index or the mark list changed, and a layout change alters neither:
  a 2×2 turned into a 4×4 showed the four pictures it already had and twelve
  spinners nobody had asked to render, until some later event happened to
  refresh them. It now watches the cells the film is actually showing, which is
  the thing all three of those changes have in common.

### Added — linked film cells: adjust one, adjust them all (2026-08-07)

*Work in progress, not yet committed.*

"Apply this window to all cells" was a one-shot copy made after the fact. Judging
a film means comparing its cells, and cells can only be compared when they are
shown alike — which meant repeating every zoom by hand, cell by cell.

- **The tools are back on a rail, and the locks are on it too.** Window/level,
  zoom, pan, text, arrow and invert (`V`) sit down the left of the film with the
  three locks,
  the scope and the two resets. A right-click menu is a fine place for a command
  and a poor place for a *mode*: which tool is armed and which cells are linked
  have to be answerable at a glance, and a menu that only exists while it is open
  cannot answer them. The menu keeps everything it had.
- **The lock is drawn on the cells it applies to.** A closed padlock appears on
  every cell that will move when the focused cell is dragged — and on none that
  will not, which is how the scope becomes visible before the drag rather than
  after it. It is the one thing the preview draws over a picture that the film
  will not carry, sits in the corner over the letterbox margin, and takes no
  clicks.
- **A mode, not a command.** `PrintCellSyncOptions` — Zoom & Pan, Window, Invert
  — are locks on that rail. While one is on, dragging a cell carries that
  adjustment to the others as the gesture happens. Zoom and pan are one switch
  deliberately: cells that magnify together but sit over different anatomy are
  the confusing state, not one anybody asks for. Rotation and flip are not
  offered: they are how one image is put the right way up, and turning the whole
  sheet because one cell was upside down is never what was meant.
- **A way back out.** Reset Cell and Reset All sit beside the links (`0` and
  `⇧0`), because one linked drag can now put a whole sheet wrong and undoing it
  must not be harder than causing it. The cell menu's reset still acts on the
  cell that was right-clicked, and names itself so.
- **A dragged cell keeps up with the drag.** A window/level drag re-keys the
  cell on every mouse event, so its GPU render nearly always landed after its own
  key had been superseded — and `PrintCellTextureCache` threw those renders away,
  leaving the cell being dragged showing the picture the drag started from. A
  superseded render now stands in for the mark it belongs to, so the cell tracks
  the drag a dispatch behind instead of stalling.
- **Geometry copies absolutely, windowing carries relatively.** Every cell on a
  film is the same size, so the same zoom and pan is the same picture, and each
  peer's pan is then re-held inside its own image. A window is not portable that
  way — a film mixes modalities, and marks do not all state their window in the
  same space — so a drag scales each cell's width by the same factor and shifts
  its centre by the same fraction of a width. Presets are the exception: "lung"
  names a tissue, so it is copied as the numbers it is.
- **Scope, because a film is not always one series.** All Cells / Same Series /
  This Film, defaulting to Same Series — a film carrying two series is usually
  carrying them for comparison. Marks now carry their Series Instance UID for
  this; marks made without opening a file group by the folder they came from.
- **It yields to the job.** With raw pixels or a job-wide window on, nothing
  per-cell reaches the film, so the window link reads and behaves as off rather
  than claiming an effect the job has already taken away. Marks never opened are
  given their file's own window when the link goes on, so they move with the
  rest instead of sitting still.

### Added — a film of one study names its patient once (2026-08-07)

*Work in progress, not yet committed.*

Identification was burned under every image, which is right for a sheet that
mixes studies and repetitive noise on a sheet that does not: sixteen cells of one
CT carried the same name sixteen times, each one costing its picture a strip of
height. With multi-study selections coming, "print this film" has to answer both
cases.

- **The rule, in one place.** `FilmIdentificationPlanner` decides per *film*, not
  per job: a sheet whose captioned images all share one Study Instance UID states
  the patient once along its bottom edge; a sheet mixing studies captions each
  image, as before. A job spilling onto a second sheet has each sheet decided on
  its own, because each sheet has to be identifiable on its own. The UID is the
  test rather than the caption text — two studies of one patient on the same day
  read identically and are still two studies. An image whose header could not be
  read has no study to agree with, so it forces per-image captions.
- **The strip is kept clear of the pictures.** `FilmCellLayout` takes a footer
  band out of the sheet before it lays out cells, so the footer sits under the
  bottom row rather than across it — text over anatomy is where a finding hides.
  Annotation boxes generally now get that band too; they used to be drawn into
  the bottom margin over whatever was there, and they are centred rather than
  flush left.
- **It reaches real film three ways.** Composed sheets (Save Film, the printer
  emulator) draw the footer themselves. On the wire it goes as a film-level Basic
  Annotation Box — `PrintOptions.filmAnnotations` carries a set per film, so two
  sheets of one job can name two patients, which one job-wide list could not.
- **Whether the printer can carry it is asked, not assumed.** The first cut
  looked at whether an Annotation Display Format ID had been typed into the
  settings sheet, so every printer that had not been configured by hand — which
  is every printer, by default — silently fell back to captioning each image and
  the film never matched the preview. Support is now a question about the
  association: `DICOMPrintService.supportsAnnotationBoxes` opens one, asks
  whether the Basic Annotation Box SOP Class was accepted, and releases. It is
  asked *before* the frames are prepared, because the answer decides whether they
  are captioned. A printer that takes annotation boxes but has no configured
  format ID gets a plain default (`ANNOTATION`), since a film box cannot carry
  annotation boxes without one; a printer that refuses the film box over that
  value has it created again without it rather than losing the job, and the
  progress line says the film will carry no annotation text. A printer that takes
  no annotation boxes at all — or cannot be reached — still gets the caption
  burned under each image: a film with no name on it is worse than a film that
  repeats one.
- **The footer's type is sized off the film.** It was a flat 3 mm, which is
  oversized on an 8×10 held in a hand and lost on a 14×17 across a viewing room.
  It is now 1.1% of the sheet's height, floored at 2.5 mm and capped at 6 mm —
  ~2.8 mm on 8×10 and ~4.75 mm on 14×17 — and the strip reserved for it, in the
  composer and in the preview alike, follows the type rather than a constant.
- **Choosable, in the preview and in the settings column.** Automatic (the rule
  above), "Under each image", or "Once at the foot of the film". The preview
  draws whichever the film will carry, scaled off the physical sheet, so the
  strip that is approved is the strip that prints.

### Changed — the print preview stays shut, opens wider, and writes the film out (2026-08-07)

*Work in progress, not yet committed.*

- **A launch shows the library and nothing else.** Print Preview and Printer
  Emulator are singleton `Window` scenes, so macOS restored whichever was open at
  quit — the preview holding no marks and the emulator with its server stopped,
  because neither survives the app. Both now carry `.restorationBehavior(.disabled)`
  and `.defaultLaunchBehavior(.suppressed)`; they open when they are asked for and
  not before.
- **The console log column is as wide as the reader wants it.** It was a fixed 300
  points, which wrapped every import path and print job UID into four lines. It
  now opens at 460 and is dragged from the divider between it and the film, up to
  60% of the panel and never below 260; the width is kept in `AppStorage`, so it
  is chosen once rather than every job. The film takes back whatever the log is
  not using, as it did before.
- **The film can be saved as a file.** "Save Film" in the preview's header writes
  PNG, TIFF or PDF. Not a screenshot of the preview: the images go through the
  same `PrintService.prepare` a real print sends them through and the sheet comes
  out of the same `FilmComposer` the printer emulator composes received film
  with, so what lands on disk is the sheet the printer would have laid down —
  identification band, drawn annotations, spillover and all. A PDF holds every
  film of the job as a page; PNG and TIFF write one file per sheet.

### Added — film layouts the standard has and a grid has not (2026-08-06)

*Work in progress, not yet committed.*

PS3.3 C.13.3 lets a film's rows hold different numbers of images: `ROW\1,3` is a
scout above three slices, `COL\1,2` is one image beside two. The Print SCP has
always understood those forms — it has to, modalities send them — but everything
that *composes* a film here could only say rows × columns, so the one layout a
reader most often wants for a comparison film could be received and not sent.

- **Seven band layouts are in the gallery, drawn.** `ROW\1,2`, `ROW\2,3`,
  `COL\1,2`, `COL\1,3`, `COL\1,4`, `COL\1,4,4` and `COL\2,4,4` are picked the way
  the grids are — by looking at the film rather than reading a string — and live
  in `PrintBandLayout` in `PrintOptionCatalog`, the one table the print sheet and
  `dicom-print --layout` both read.
- **The print sheet takes a format string too.** Under the bands is a Custom
  field: type an Image Display Format and the film beside it is redrawn as it is
  typed, with the layout named in words underneath ("rows of 1, 3 — 4 images").
  Picking a band fills that same field, so the layout in force can always be read
  as the string that will be sent, and adjusted from there. Text that is not a
  format says so in red and leaves the film on the automatic grid rather than
  quietly printing 1×1, which is what a lenient parse would have made of
  half-typed input. The gallery scrolls now that it holds four sections.
- **The preview draws the film, not a grid.** `FilmPreviewView` lays its cells
  out with `FilmCellLayout` — the same geometry the SCP composes received film
  with — instead of a SwiftUI `Grid`, so a band layout is shown as the bands it
  is. Every per-cell measurement (zoom and pan limits, annotation anchors, the
  identification strip) now comes from that cell's own rectangle; it used to come
  from one film-wide size, which was only ever right because the cells were all
  the same. Arrow-key navigation follows the cells' geometry for the same reason.
- **The format reaches the printer verbatim.** `PrintLayoutSelection` gained a
  `.displayFormat` case, `PrintJobRequest`/`PrintPlan` carry the format and count
  films by its image-box count, and the SCU sends the string as written. Verified
  end to end against `dicom-printscp`: `--layout 'ROW\1,3'` composes one image
  over three, `'COL\1,2'` one beside two, `'COL\1,4,4'` one beside two columns
  of four.
- **`dicom-print --layout` accepts both.** A grid token ("2x3") as before, or a
  format (`'ROW\2,1,2'`, quoted so the shell keeps the backslash); the named
  bands are listed in its help. The dry-run banner and the film plan name a band
  layout by its format string — reporting `ROW\1,1` as a 2×1 grid would have
  misstated the film.
- `PrintImageDisplayFormat` gained `validated(_:)` (strict, for UI and command
  lines), an initializer from a `PrintLayout`, `isUniformGrid`, and `summary`.

### Changed — the viewer opens on the images (2026-08-06)

*Work in progress, not yet committed.*

Opening a study put four columns on screen before the first picture: the app's
feature list, the series pane, the images, and an empty selection tray. Two of
them were answering questions nobody had asked yet.

- The feature sidebar steps aside on the way into the viewer and comes back on
  the way out (`MainView` drives `columnVisibility`). The toolbar toggle still
  opens it over the images, and that choice holds until the viewer is left.
  Launching straight into the viewer starts collapsed too.
- The selection tray starts hidden (`isPrintTrayVisible` now defaults to `false`)
  and comes up on its own the moment the first image is marked — every marking
  path, the library's "Print…" included, goes through `revealPrintTray()`.
  Unmarking never puts it away again, so the "Clear" button cannot vanish under
  the pointer; opening a different study does, along with the marks it held.
- The current series is marked by one cue, on the card: a neutral white ring and
  a lifted surface. Nothing is drawn on the thumbnail — a ring there framed the
  letterboxing rather than the picture — and the accent stays out of the pane
  entirely, because in the viewer it means "this is what prints".
- In the grid, a marked tile no longer carries an accent edge along its bottom.
  The chip and the tick already say it, and with a film fully composed the edge
  drew a blue rule under every tile; the only accent edge left in the grid is the
  focus ring, so exactly one tile is lit — the one being worked on.

### Changed — the viewer's three columns are told apart (2026-08-06)

*Work in progress, not yet committed.*

The series pane, the reading area and the selection tray all sat on the same
near-black surface, so nothing on screen said which column held the images that
were about to print:

- Three planes instead of one. The panes are a lighter surface
  (`StudioColors.viewerPanel`) with a dark seam on the side facing the picture;
  the gutter is darker than before (0.14 → 0.10); the reading area keeps its pure
  black and gains a shadow that lifts it off the mount.
- Every column is titled. A shared `ViewerPaneHeader` names the panes ("Series",
  "On film" with its count); the reading area's own strip names it, shows the tile
  layout, and reports "N of M on film" — the count of images *on screen* that are
  marked, so the middle column visibly owns the print selection.
- The reading area's frame is thicker and keeps the accent while it holds the
  keyboard, in a grid as well as at 1×1.
- Marked tiles are readable across a whole grid: a numbered film-position chip in
  the top-left corner (the number the tray lists it at) and an accent bar along the
  bottom edge. The border stays focus-only — the live tile's ring went 2 pt → 3 pt,
  and hovering brightens a tile's hairline.
- The patient plate in the series pane is neutral rather than accent-tinted: in the
  viewer the accent now means "this is what prints".

### Changed — the print preview is a window, not a sheet (2026-08-06)

*Work in progress, not yet committed.*

- The preview's cells now draw from GPU textures (`PrintCellTextureCache`), because
  the preview is where the tools are used: window/level, zoom, pan, rotate, flip and
  invert were each a CPU re-render per mouse delta. The arrangement is the display
  shader's transform, so those drags now re-draw a quad and render nothing; only a
  window change makes a new texture, and that is one GPU dispatch. A re-windowed cell
  holds its previous texture while the new one renders, so a drag never falls back to
  the CPU. Falls back per cell — overlay planes, YBR, an unresolvable window, no
  Metal — never per film. Only the film on screen holds textures.
- The shader is given the *film's* geometry, not the viewer's: new
  `DisplayPresentation.sourceRegion` fits and centres the region that
  `ViewerPresentation.visibleRegion` — the same call the print path makes — says will
  be cropped, and flips after the rotation as `PrintPresentationTransform` does. The
  viewer's own transform agrees with the printer only while a cell is merely zoomed,
  so reusing it would have misreported every rotated or edge-panned cell.
- Film composition and export are unchanged and still CPU, as the GPU plan fences
  them: preview and film agree because neither invents anything the other does not.

- On macOS the print preview opens in its own window (`StudioWindowID.printPreview`)
  instead of a modal sheet over the viewer, so the film can be compared with the
  images it was made from, moved to a second display, or zoomed to fill one.
  ⌘P and the library's "Print…" both raise it; `PrintScreenPresenter` keeps the
  sheet on platforms without windows.
- `PrintSettingsView` takes a `presentation` (`.sheet` / `.window`): a sheet is
  still given a fixed size, a window only a minimum, so the user's own size sticks.
- The Print screen gained a "Print Preview" button that raises the window — the
  preview no longer has to be re-opened from the viewer once it has been closed.
- Opening a study closes the print preview window along with clearing the marks:
  the film on it was composed from the study being left. `prepareForNewStudy()`
  bumps `printScreenDismissRequests`, which the shell turns into a
  `dismissWindow` — watched there rather than in the viewer, since the study may
  be opened while the library is still on screen.
- The print log console starts closed and opens by itself when a job starts,
  giving the film its width while the film is what is being judged. It is put
  away again on "Print Again", and the header toggle still overrides both.

### Added — Metal GPU frame rendering, `DICOMRenderKit` (2026-08-04)

Full GPU rendering pipeline for the viewer, landing GPU plan milestones M0–M7
(see `GPU_RENDERING_PLAN.md`):

- New `DICOMRenderKit` target: a Metal compute pipeline that windows/LUTs a decoded
  frame directly into a `CGImage`-readable texture with zero-copy UMA input and no
  upload/render/readback round trip. Monochrome and RGB/palette kernels; YBR stays
  on the CPU. Output is byte-for-byte identical to the CPU path
  (`MetalCPUEquivalenceTests`), so the two are freely interchangeable.
- Shared `WindowLUT` (integer, not float shader math) backs both the CPU and GPU
  paths — 10–19× faster monochrome rendering on its own (M0+M1), before any GPU
  work.
- Focused-viewport direct-to-display path keeps the frame on the GPU across tool
  actions (window/level, invert, zoom, pan): 0.008 ms per action, down from a full
  re-render (M5). The per-drag decode is cached too, up to 675× faster per step.
- `minimumGPUPixelCount` dropped from 1 megapixel to 0 — no frame is declined for
  being small; the CPU is now purely the no-GPU fallback, not a size-selected
  alternative. Safe only because of the CPU/GPU output equivalence guarantee above.
- Shipped the compute shader as `.metal.txt` so the app builds without requiring
  the separate Metal Toolchain install in Xcode.

### Added — corner annotations and GPU textures for unfocused tiles (2026-08-04, in progress)

*Work in progress, not yet committed.*

- On-screen viewer tiles and the focused viewport now carry the traditional
  four-corner reading-room annotation layout — size/window/cursor readout
  (top left), patient/study identification (top right), zoom/position/
  compression/geometry (bottom left), acquisition date/time (bottom right) —
  composed by `ViewerAnnotationCorners`/`ViewerAnnotationText` and drawn by the
  new `ViewerAnnotationOverlayView`. Detail scales down (`.full` → `.reduced` →
  `.minimal`) as a tile shrinks, keeping identification and position and
  dropping the rest rather than shrinking everything to illegibility.
- `ViewerHoverGeometry` maps a cursor point back through the viewport's fit,
  zoom, pan, rotation and flip to the underlying image pixel — separately for
  the CPU/print transform order (pan before rotation) and the GPU display
  shader's order (pan after rotation), since they only agree when a picture is
  unrotated or unpanned — so the top-left corner can show the pixel value and
  patient-space position under the cursor. A wrong readout is worse than none,
  so every step returns `nil` rather than guess when the point is off the
  picture.
- `PatientIdentificationOverlayView` is now film/print-only — the on-screen
  viewer's old single-band overlay is replaced by the corner layout above,
  since on screen the reader can move the picture out from under the text but
  paper cannot.
- New `ViewerTileTextureCache` extends the GPU display path (M5) to unfocused
  grid tiles: a texture keyed only on file + frame + window, so a synchronized
  zoom or window drag across a grid re-draws a quad per tile instead of
  re-rendering one. This is the GPU-tile work M6 explicitly deferred ("`
  ViewerTileImageCache` ... stay on the readback path") — tiles now have both a
  CPU image and, where Metal is available and the frame supports it, a GPU
  texture, falling back to the CPU image per tile (overlay planes, an
  unresolvable window, no Metal device) rather than per grid.
- Also removed the unused Inspector-panel toggle from `MainView`/`MainViewModel`
  (dead code, unrelated cleanup).

### Removed — CLI-parity test harness (2026-08-03)

Deleted the whole Tier-2 CLI-parity subsystem: the "CLI Parity" Studio screen and its
engine/comparators, the orphaned CLI Automation Testing screen, bundled synthetic
fixtures and goldens, the `cli-parity-gen`/`cli-parity-docs`/`studio-cli-introspect`
dev targets, all `CLIParity*Tests` suites plus the `StudioParityTests` target, the
"Tier-2 Output Parity Gate" CI job, and every `APP_CLI_*PARITY*`/`docs/cli-parity/`
doc — 103 files, ~14,400 lines of code, ~5,100 lines of docs, 1.1 MB of fixtures.

- Kept deliberately: `CLIToolTerminalCompare` + `CLIToolBuilder` (reachable only from
  code now that the Workshop's comparator panel is gone) and the `syn-ct.dcm` fixture
  the print tests depend on, now `Tests/DICOMStudioTests/Fixtures/syn-ct.dcm` via a
  new `StudioTestFixtures` helper.
- `APP_CLI_SHARED_API.md` updated to describe verification as it stands today: the
  oracle-based round-trip suite (`DICOMRoundTripTests`) plus, per tool, an optional
  shared `*Console` type.

### Added — shared consoles for dicom-split/merge/script (2026-08-03)

`dicom-split`, `dicom-merge` and `dicom-script` were the last three tools whose
Workshop executors shared only the engine while duplicating console text and input
parsing. Text and parsing now live once in DICOMKit — `SplitConsole`, `MergeConsole`,
`ScriptConsole` — pinned by `Tests/DICOMRoundTripTest/SharedConsoleParityTests.swift`.
Fixed real drift found in the process: the app's banners had dropped the CLI version
string, `dicom-merge` relabelled its input-count line and echoed `--format` values as
enum case names instead of the CLI's raw text, and `dicom-split`'s frame parser
silently accepted whitespace-only components the CLI rejected.

### Fixed — Print SCP honors SCU-supplied SOP Instance UIDs (2026-08-03)

A dcm4che-based Print SCU failed at N-ACTION with `0x0112` "Unknown Film Session" and
never produced a film. PS3.7 10.1.5 lets the SCU supply the Affected SOP Instance UID on
N-CREATE, and such SCUs then address every follow-up N-SET / N-ACTION by *their* UID
regardless of what the response carries — while our SCP minted and stored its own.

- `PrintSCP.assignedUID(requested:)` stores the object under the SCU's UID whenever one is
  supplied, for Film Session, Film Box, Presentation LUT and Basic Annotation Box N-CREATE;
  it falls back to the generator otherwise. A supplied UID must be non-empty after trimming
  NUL/space padding, ≤ 64 characters, and digits-and-dots only, so a malformed value can
  never become a stored key.
- Film Box N-CREATE now rejects a UID already in use with `0x0111` (Duplicate SOP
  Instance) — unreachable while the SCP minted its own.
- Image Box UIDs remain SCP-allocated; they are created implicitly with the film box.
- `PrintSCPStatusMatrixTests.testSCUSuppliedSOPInstanceUIDsAreHonored` replays the field
  sequence end to end and asserts the composed film carries the SCU's UIDs.
- `PRINT_CONFORMANCE.md` §2.1 / §4 and `DICOM_PRINT_SCP_PLAN.md` updated.

### Added — DICOM Print SCP: emulator screen and `dicom-printscp` CLI (2026-07-31)

Milestones E and F of `DICOM_PRINT_SCP_PLAN.md` — the last two rows in that plan's
matrix. The app surface came first, so the sharing ran in the direction opposite
every other print entry: settings, assembly and wording were **moved** out of
`DICOMStudio` into `DICOMPrintKit`, and both the Studio screen and the CLI now
consume rather than own them.

- **`PrintSCPSettings` / `PrintSCPService` / `PrintSCPConsole` / `PrintSCPSimulator`**
  (`DICOMPrintKit/Printing/`): every configuration knob and its
  `PrintSCPConfiguration` / `FilmComposerConfiguration` mapping, the sink stack and
  server assembly, the wording of every event/film/startup line, and a no-network
  film simulator, in one place — Studio's view model now owns only what a window
  owns (retained films, selection, button state).
- **`dicom-printscp`** (`Sources/dicom-printscp/`): `serve` (default) / `simulate`
  / `status` / `queues`. `simulate` takes DICOM files rather than a `film.json`
  descriptor as originally sketched — the composer needs real pixels, and routing
  through `PrintImagePreparer` means a simulated sheet is built by the same code a
  live SCU's job is.
- **Studio's "Printer Emulator"** (`PrintSCPView`, `PrintSCPViewModel`,
  `PrintSCPSettingsStorageService`): a persistent `Window` (not a `WindowGroup` —
  one emulator, one listener) reachable from the sidebar while a print is in
  flight from the main window.
- **Two defects a live SCU→SCP run caught, both fixed in the shared core:**
  `--max-films` counted off the screen stream (delivered the instant a sheet is
  composed) instead of `.filmPrinted`, so the listener could stop mid-N-ACTION and
  abort the SCU's association before its PNG was written; and the association log
  line rendered the port as `:0` because `AssociationInfo.remotePort` is always 0
  for this SCP and the whole endpoint is in `remoteHost` — fixed once in the
  shared console.

Plan: `DICOM_PRINT_SCP_PLAN.md` ("Milestone F as built" section has the full
shared-type table). Not in the CLI-parity harness (print tools are covered by
dedicated tests instead, per `APP_CLI_SHARED_API.md`).

### Added — DICOM Studio: overlay planes, patient identification, and print window fixes (2026-07-31)

- **Overlay plane rendering** (`DICOMKit/OverlayPlaneRenderer.swift`): PS3.3
  C.9.2 group-60xx overlay bitmaps, read and drawn both as a `CGImage` composite
  (viewer) and burned into raw samples (film). Written for Siemens' "Patient
  Protocol" Secondary Capture, whose Pixel Data is entirely zero and whose whole
  content lives in a 1-bit overlay — previously rendered as a black square, now
  shown/printed correctly. Wired into both `ImageViewerViewModel` (render path)
  and `PrintImagePreparer` (so a film matches the screen it was approved on,
  except under `--raw`).
- **Print window resolution now falls back to the file's own VOI**
  (`PrintImagePreparer.resolvedWindow`, `PrintWindowSpace`): a mark made without
  opening the file (whole-series or library print) previously auto-stretched a
  CT's full pixel range and left soft tissue in a handful of indistinguishable
  greys; it now falls back to the data set's VOI window like the viewer, export
  and tiles already do. `PrintWindowSpace` (`.outputUnits` / `.storedValues`)
  travels with an explicit window so a value taken off the viewer (stored units)
  is converted through Rescale Slope/Intercept before printing — sending it
  unconverted put the window entirely outside the pixels and printed a flat
  black cell.
- **Arrow geometry fully consolidated** (`PrintArrowGeometry.swift`): the
  fractional-of-image-height math for shaft width and head size, previously
  duplicated between `ImageAnnotationBurner` (film) and `FilmCellAnnotationLayer`
  (preview), now lives once and both call it; the preview's arrow rendering also
  switched from a shadow-based halo to a stroked-outline halo so the head no
  longer blurs into the shaft and reads as a plain line. Selection handles on a
  selected arrow shrank to a small ring with a separately-sized (2x) invisible
  grab area, so a handle no longer hides the anatomy the arrow points at.
- **Viewer patient-identification header** (`ImageViewerViewModel+PatientOverlay`):
  `patientIdentityLine` ("name, ID · CT / PT"), `modalitiesForOverlay` (every
  modality in the open study, series order, no repeats — a study is routinely
  PET/CT or a CT with an SR), and `studyDescriptionSanitizedForOverlay` (strips
  the caret/pipe/backslash separators a description arrives with, keeping only
  what reads as words).
- **Viewer toolbar reworked around click-armed tools**: windowing and zoom are
  now toggled tool buttons (highlighted while armed) rather than ⌥-drag/⌘-drag
  modifiers, freeing ⌘-drag; `resetView()` now also resets window/level and
  inversion, not just pan/zoom/rotation; the inline "Open DICOM File" button,
  file importer and ⌘O shortcut were removed from the viewer.
- **Tests**: `PrintSCPSharedCoreTests` (23), `PrintSCPScreenTests` (39),
  `PrintWindowSpaceTests` (9), `OverlayPlaneRendererTests` (17),
  `PrintMarkWindowTests` (5), `ViewerIdentificationHeaderTests` (5);
  `PrintOverlayAnnotationTests`, `PrintCellEditingTests`, `NavigationServiceTests`,
  `ViewerTileLayoutTests` and `PolishReleaseViewModelTests` updated for the
  arrow-geometry, cell-editing-window and toolbar/reset-view changes.

### Added — DICOM Studio: the film as a working surface (2026-07-30)

Plan: `DICOM_PRINT_STUDIO_PLAN.md` §10.

- **Patient identification burned into the film** (`DICOMPrintKit/ImageAnnotationBurner.swift`,
  `PatientOverlayText`, `PatientOverlayTextCache`, `PatientIdentificationOverlayView`): "name,
  ID, study date" over the study description, from one definition shared by viewer tiles and
  film cells. A DICOM printer draws identification from annotation boxes to its own layout and
  many ignore them, so the lines are burned into the prepared 8-bit frame instead — one bitmap
  pass per cell, applied last so a later crop or rotate cannot carry the caption with it, and
  skipped quietly on an unexpected pixel format rather than failing the print. The viewer draws
  it as a reserved band below the picture; the film preview overlays it, since there the cell
  *is* the film.
- **Drawn annotations on a film cell** (`PrintOverlayAnnotation`, `PrintViewModel+Annotations`,
  `FilmCellAnnotationLayer`): text and arrows, in coordinates normalized to the **image** and
  held per **mark ID** — so re-arranging the film, changing layout or printing to another sheet
  cannot move an arrow off the vessel it pointed at, and the 512-pixel preview and the
  3000-pixel frame agree. The preview uses the burner's own arrow geometry.
- **Per-cell editing in the print preview** (`PrintViewModel+CellEditing`): window/level, zoom,
  pan, text and arrow tools writing back into the mark that `PrintService.prepare` reads, so
  the preview cannot drift from the film. `FrameSourceCache` keeps decoded pixels so a
  window/level drag re-maps rather than re-decoding (tens of ms per event on a JPEG 2000 CT);
  cell renders moved 256 → 512 (at 256 half the grey levels being judged are lost to
  downscaling) and the previous rendering stands in during a gesture instead of a spinner.
- **Non-image instances open instead of failing** (`ViewerContentKind`, `ViewerNonImageContent`,
  `ViewerNonImageContentView`): SR read as a narrative, encapsulated PDF as pages, presentation
  states / KOS / raw data as named summaries. Previously a valid SR was reported as an
  "unsupported transfer syntax" — a decode failure for pixels it never claimed to have.
- **Library rows describe the study again** (`StudyModel.merging`, `StudyRowSummary`,
  `LibraryModel`, `DICOMFileService`): study fields are unioned across the files of a study
  rather than overwritten by whichever was read last; rows fall back to the series' modality
  and description, then patient ID / accession, before saying "Unknown"; series and instances
  sort by Series/Instance Number with unnumbered **last** and a total-order tiebreak (a series
  used to open on a different image on each read); empty studies are pruned; a DICOMDIR and any
  object with no SOP/Series Instance UID are refused at import instead of manufacturing an
  unopenable "Unknown Patient, 0 series, 0 images" row.
- **Reading with one hand on the keyboard**: shared `ScrollWheelHandler` (viewer pages images,
  film preview zooms cells, both live while the print sheet is over the viewer) with step
  accumulation for fine trackpad deltas; first/last jumps and opt-in wrap at series ends;
  `ViewerPrintTrayView` — the selection in film order, each row rendered with that mark's own
  window and arrangement, without opening the print sheet; ⌘/ keyboard-shortcut legend on both
  screens.
- **Tests**: `PrintOverlayAnnotationTests`, `ImageAnnotationBurnerTests`,
  `PrintCellAnnotationTests`, `PrintCellEditingTests`, `PatientOverlayTextTests`,
  `PatientIdentificationOverlaySizingTests`, `ViewerContentKindTests`,
  `ViewerProtocolLineTests`, `LibraryStudyMergeTests`, `LibraryImportEndToEndTests`,
  `StudyRowSummaryTests`, `ScrollStepAccumulatorTests`, `ViewerTileLayoutTests` —
  4,335 tests in 394 suites green.

### Added — DICOM Print SCP: printer emulator (2026-07-28/29)

DICOMKit now implements Print Management (PS3.4 Annex H) in **both** roles. Any Print SCU —
modality, workstation or third-party tool — can associate, send a film session, film boxes
and image boxes, and issue N-ACTION *print*; the film is composed and handed to an output
sink. Conformance statement: `PRINT_CONFORMANCE.md`. Plan: `DICOM_PRINT_SCP_PLAN.md`.

- **Protocol machine** (`DICOMNetwork`): `DICOMPrintServer` actor + `PrintSCP.swift`,
  `PrintSCPTypes.swift`, `PrintSCPEncoder.swift` — association accept/reject, called/calling
  AE checks, N-CREATE / N-SET / N-GET / N-ACTION / N-DELETE / N-EVENT-REPORT across Film
  Session, Film Box, Grayscale/Color Image Box, Printer, Print Job, Presentation LUT and
  Basic Annotation Box, with the PS3.4 H.4 lifecycle and cascade deletes. Configurable via
  `PrintSCPConfiguration` (film sizes, medium types, colour, max boxes per film, annotation
  boxes, idle timeout, AE lists, printer identity).
- **SCP-direction dataset parsing** (`PrintDatasetReader.swift`, `PrintSCPParser.swift`):
  a real element walk for both Explicit and Implicit VR LE, including sequences with defined
  and undefined length and image-box `PixelData`, mapped back onto the existing `FilmSession`
  / `FilmBox` / `ImageBoxContent` / `PrintImageData` model.
- **`PrintImageDisplayFormat`**: parses `STANDARD` / `ROW` / `COL` / `SLIDE` / `SUPERSLIDE` /
  `CUSTOM`, driving image-box allocation, composer cell layout and the SCU's box maths.
- **Film composition** (`DICOMPrintKit/Printing/`): `FilmGeometry` (sheet sizes at a
  configurable DPI, cell layout, fitting), `FilmComposer` (image boxes → one page bitmap:
  magnification, polarity, LUT shape, border/empty density, trim marks) and `ComposedFilm`.
  Four inversions compose correctly — MONOCHROME1, Polarity REVERSE, INVERSE / LIN OD
  Presentation LUT shape, and film emulation. `DensityMapping` is `.paperDirect` by default,
  with `.filmEmulation` opt-in rather than a silent guess.
- **Output sinks**: `PrintOutputSink` protocol with `ScreenSink` (full-resolution stream +
  bounded downsampled scrollback; never blocks the SCP on a viewer that is not draining),
  `PDFSink`, `ImageSink` (PNG/TIFF), `PaperPrinterSink` (CUPS `lp`, opt-in) and
  `CompositePrintSink`; `FilmComposingPrintHandler` wires the SCP to them.
- **Tests**: `PrintSCPTests.swift` (74 — parser round-trip in both VRs, encoder, loopback SCU
  → SCP, status matrix, robustness) and `DICOMPrintKitTests` (63 — geometry, composer, sinks,
  screen scrollback, DCMTK interop).

### Fixed — DICOM Print interoperability, verified against DCMTK 3.7.0 (2026-07-29)

Automated in `Tests/DICOMPrintKitTests/DCMTKInteropTests.swift` (skips when DCMTK is absent):
`dcmpsprt`/`dcmprscu` → our SCP, and our SCU → `dcmprscp` (IHE Full profile).

- **SCU proposes the meta *and* the individual SOP Classes** and routes each N-service to an
  accepted context (`PrintPresentationContexts`). A printer that rejects the meta class was
  previously unusable.
- **Image Display Format order was a conformance bug:** PS3.3 C.13.3 defines `STANDARD\C,R`
  as columns-first; `PrintLayout.imageDisplayFormat` emitted rows-first, so every non-square
  layout printed transposed on a conformant printer. `PrintLayout` is now the single source
  of the string.
- **Configuration Information (2010,0150) threaded end to end** — Studio and the CLI collected
  it but `PrintOptions` had no field and it was never sent; several vendors require it.
- **0x0106 reclassified as a failure** (`DIMSEStatus`) — it was treated as a warning, so a job
  sailed past a printer's rejection and failed later with a misleading code.
- **Trim (2010,0140) omitted when NO** and **Requested Decimate/Crop Behavior (2020,0040)
  omitted when DECIMATE** — printers that do not implement them reject a box for merely
  carrying them.
- **SCP idle-association timeout** (default 300 s) so a vanished peer no longer holds a slot
  forever, and **A-ASSOCIATE-RJ at capacity** instead of dropping the socket.
- **Error Comment (0000,0902) transliterated to ASCII** — `CommandSet` encodes as ASCII and
  silently dropped any value containing a non-ASCII character, discarding the only diagnostic
  an SCU developer gets.

### Added — `DICOMPrintKit`: shared print core for the CLI and Studio

- **New target/product `DICOMPrintKit`** (DICOMCore + DICOMDictionary + DICOMKit +
  DICOMNetwork), consumed by `dicom-print` and `DICOMStudio`. The shared core cannot live in
  DICOMKit — it needs both `ImagePreprocessor` and `PrintImageData` — and putting networking
  into DICOMKit would force it on all ~30 CLIs.
- `PrintJobRequest` (every job knob as one value type, plus `validate()`, `filmCount(for:)`
  and `PrintPlan`), `PrintOptionCatalog` (one table of selectable values per option, feeding
  both UI pickers and the CLI's arg enums), `PrintImagePreparer`, `PrintWorkflow` (preflight,
  retries, events, progress, job/printer status) and `PrintConsoleFormatter` (text + JSON).
- **`dicom-print` refactored** onto all of the above — arg declarations, help text and output
  unchanged; `PrintCLIEndToEndTests`, `PrintServiceTests` and `PrintSCPIntegrationTests` stay
  green.
- **Multi-film gap fixed:** `PrintResult` now carries `filmBoxUIDs` and `printJobUIDs` (the
  singular properties remain as last-element accessors), so per-film job-status polling and
  job history work for multi-film jobs.

### Added — DICOM Studio: print workflow (2026-07-28)

Library → viewer → mark images → print. Plan and full file map:
`DICOM_PRINT_STUDIO_PLAN.md`.

- **Marking in the viewer**: ordered, frame-level `PrintSelectionModel`; **M** marks the
  current image, **⌘P** opens the print sheet, a badge shows the count, a capsule shows the
  film position, and the context menu carries mark-all-frames / whole-series / clear.
- **Print settings sheet**: printer picker with Test (C-ECHO) and Status (N-GET), layout
  (auto | grid | preset), film size, orientation, copies, a live film preview showing
  spillover, a marks tray, and an Advanced disclosure covering the rest of the CLI surface.
  (Reworked 2026-07-29 — see below.)
- **Printer management**: `PrinterProfile` + `PrinterProfileStorageService`
  (`printer-profiles.json`), modelled on the existing PACS server profiles. The CLI's
  `~/.config/dicomkit/printers.json` registry stays independent by design — a sandboxed app
  cannot reach it.
- **Execution**: `PrintViewModel` + Studio `PrintService` over `DICOMPrintKit`, determinate
  per-image-box progress, live N-EVENT-REPORT console, cancel with film-session cleanup,
  per-film **Check Status**, and job history persisted to `print-job-history.json`.
- **New `Print` navigation destination** (printers + job history) and a **Print…** action on
  a study/series in the library, which adds those files to the selection without discarding
  marks already made in the viewer.

### Fixed — DICOM Studio: windowing, series order and the print sheet layout (2026-07-29)

- **Multi-valued VOI no longer discarded** (`DICOMImageExporter.determineWindowSettings`): a
  CT that carries a lung *and* a soft-tissue window in one element (`-600\50` / `1200\350`)
  fell through `windowSettings()` — which parses a single DS — and was auto-stretched over the
  full pixel range. The multi-valued form is read first and its first pair, the default
  presentation, wins.
- **One window policy everywhere**: `ImageViewerViewModel` now adopts a file's default window
  through `determineWindowSettings` (the same call the exporter, tile cache and film use), and
  `FrameRenderer`'s fallback ladder goes through it too instead of
  `renderFrameWithStoredWindow`, which hands a raw HU centre to a renderer reading *stored*
  values and washes a CT with a large Rescale Intercept out to white.
- **A window no longer follows the user across a hang**: `ViewerCellState.windowCenter/Width`
  are optional, `nil` meaning "this image's own VOI". A freshly hung tile starts at its own
  VOI, and the viewer's window is inherited only by tiles in the same series — filling a grid
  from a flat file list used to stamp one kernel's window across an MPR and every other
  reconstruction in the study.
- **Series pane in series-number order**: ascending, unnumbered series last (the library's
  ordering treated a missing number as 0, filing them ahead of series 1), ties broken by title
  then UID so the pane cannot reshuffle between two reads. Cards show the series number badge,
  and VoiceOver announces "Series 4, …".
- **Print sheet reworked**: options moved from a 320 pt left column into a band across the top
  so the film preview owns the whole centre; the sheet opens at the size of the window it was
  raised from; Advanced expands sideways under a height cap instead of pushing the film off
  the bottom; the marks tray became a "Show List…" popover, since film order now follows the
  viewer's tile order (`syncPrintOrderToViewer`) rather than the order the boxes were ticked.

### Added — DICOM Studio: the film matches the screen (2026-07-28)

- **`ViewerPresentation` + `PrintPresentationTransform`** (`DICOMPrintKit`): a mark now
  records the viewer's arrangement as *geometry over the source image* — zoom, pan, viewport,
  quarter turns, flips, invert — and the print path crops, permutes and negates the
  full-resolution frame accordingly. Nothing resamples, so a zoomed print carries the
  modality's real detail rather than an upscaled copy of what the monitor showed.
- **Film preview shows the actual frames**: `FrameRenderer` + `FrameImageStore` +
  `PrintThumbnailCache` render each marked frame as it will print. Cache keys include the
  whole arrangement, so two marks of the same frame at different zooms are two pictures.
- **`ImageInversion`**: the viewer inverts the rendered frame rather than negating the VOI
  window, which is not equivalent once Rescale Slope/Intercept or a signed representation are
  involved; the print path inverts P-values directly.

### Added — DICOM Studio: viewer tile grid and series pane (2026-07-28)

- **Tile grid 1×1 … 4×4** whose cells map to film cells in the same order. The focused tile
  *is* the live view model, so gestures, window/level and cine behave exactly as at 1×1;
  every tile keeps its own file, frame, window, zoom/pan, rotation, flips and inversion.
  Unfocused tiles are cached renders keyed on full tile state, so panning one tile does not
  re-decode the others.
- **Series pane**: every series of the open study as a card (thumbnail, description, objects
  *and* frames, current/visited state). Drag a card onto a tile, or select a tile and
  double-click, to hang a different series there. Built from indexed library metadata, with
  orientation read from one file per series afterwards and folded in.
- **Arrow-key navigation by image, not by file**: frames first, rolling onto the neighbouring
  file and stopping at the end of the series; wrapping stays cine behaviour.
- **Tests**: `ViewerPresentationTests`, `PrintPresentationTransformTests`,
  `PrintViewerPresentationEndToEndTests`, `PrintThumbnailCacheTests`,
  `PrintSelectionModelTests`, `ViewerTileLayoutTests`, `ViewerSeriesPaneTests` —
  `DICOMStudioTests` 4,185 tests green.

### Fixed — DICOMNetwork test-suite hang and unmasked failures (2026-07-27)

- **`CommitmentNotificationListener.waitForResult` hang:** the timeout race used
  a task group whose waiter child suspended in a non-cancellation-aware
  continuation, so after the timeout threw the group could never drain —
  `testCommitmentNotificationListenerWaitForResultTimeout` (and any caller
  hitting the timeout path) hung forever, stalling full `DICOMNetworkTests`
  runs after ~880 tests. The wait is now a single continuation registered
  synchronously on the actor and resumed by exactly one of: result arrival,
  timeout, or `stop()`. `stop()` also no longer waits on a listener that is
  already cancelled.
- **`ClientIdentity` keychain lookup:** `kSecClassIdentity` queries do not
  reliably filter on `kSecAttrLabel`, so a lookup for a non-existent label
  could return an arbitrary keychain identity (wrong client certificate). The
  lookup now fetches attributes for all candidates and matches the label
  explicitly, throwing `keychainIdentityNotFound` when nothing matches.
- **`StoreAndForwardQueueTests.test_queue_enqueueDrainingThrows` race:** an
  empty queue could finish draining (→ `.stopped`) before the test's enqueue
  ran; the test now holds the queue in `.draining` via
  `notifyConnectivityLost()` first.
- Full `DICOMNetworkTests` (1086 XCTest + 192 swift-testing tests) now
  completes green in ~15 s and can gate CI.

### DICOM Print — post-plan pending work (items 1–7)

- **Palette color printing:** PALETTE COLOR sources are mapped through the data
  set's Red/Green/Blue palette LUTs to RGB (or luminance grayscale); a missing
  LUT module produces a clear error instead of `notYetImplemented`.
- **Uncompressed subsampled YBR:** packed YBR_FULL_422 (full range) and
  YBR_PARTIAL_422 (BT.601 studio range) frames are chroma-upsampled and
  converted to RGB; 4:2:0/ICT/RCT remain rejected (never occur uncompressed).
- **Deep grayscale output:** `--bit-depth 8|12|16` — depths above 8 emit
  little-endian 16-bit-allocated P-Values with matching Bits Stored/High Bit.
- **Explicit VOI window:** `--window-center`/`--window-width` override the
  data set's window.
- **Full Implicit VR LE support:** print presentation contexts propose
  Explicit VR LE with Implicit VR LE fallback, and both serialization and all
  response parsers honor the negotiated syntax — implicit-only printers now
  work end-to-end (verified against the mock SCP in both syntaxes).
- **`--magnification none`** exposed (library case existed).
- **Spawn-based CLI end-to-end tests:** `PrintCLIEndToEndTests` runs the built
  `dicom-print` binary — version/validation exit codes, dry-run behavior, the
  JSON stdout contract, and a full print + failure path against the in-process
  mock Print SCP.

### DICOM Network — release-window P-DATA tolerance (print plan P2-7)

- **`Association.release()` no longer aborts on a late P-DATA PDU:** a message
  pushed by the peer between A-RELEASE-RQ and A-RELEASE-RP (e.g. a Print SCP's
  N-EVENT-REPORT) previously hit the unexpected-PDU path — abort + error on an
  otherwise successful operation. Per PS3.8 §7.2 the release requestor now
  discards P-DATA received in the release window and keeps waiting for
  A-RELEASE-RP. Integration-tested with the mock Print SCP.

### DICOM Print — Milestone D: CLI re-enabled + mock SCP integration tests

- **`dicom-print` re-enabled in `Package.swift`** (product + executable target,
  owner approved) — previously excluded under Phase-1 scope. Builds with zero
  warnings.
- **Mock Print SCP test harness:** new in-process, NWListener-based
  `MockPrintSCP` (DICOMNetworkTests) implementing A-ASSOCIATE accept/reject,
  N-GET printer status, N-CREATE film session / film box (Referenced Image Box
  Sequence sized from the requested Image Display Format), N-SET, N-ACTION,
  N-DELETE, and A-RELEASE — with scriptable failure injection (status + Error
  Comment/ID), silence-after-accept, presentation-context rejection, omitted
  job UID, and pushed N-EVENT-REPORTs.
- **10 end-to-end workflow tests** (`PrintSCPIntegrationTests`): happy path with
  exact DIMSE sequence + single-association assertion (PS3.4 H.4), multi-film on
  one association, failure injection carrying "OUT OF FILM (Error ID 42)" to the
  thrown error, defensive cleanup, silent-SCP timeout, zero-context rejection,
  interleaved event delivery + acknowledgement, omitted-job-UID handling, and
  printer-status round-trip.
- **Defensive cleanup on failure (P2-3):** when a later workflow step fails, the
  SCU now attempts a best-effort in-association Film Session N-DELETE before
  aborting (the inner guards no longer abort pre-throw, so the association is
  still alive for cleanup).
- **Machine-readable output contract (P3-2):** `send` gained `--format json`
  (result object on stdout); the stdout/stderr/exit-code contract is documented
  in the CLI README.

### DICOM Print — Milestone E hardening + CLI ergonomics (partial)

- **Scoped image-box UID parsing (P2-2, bug fix):** `parseImageBoxUIDs` scanned
  the whole response for (0008,1155) and could mis-attribute annotation-box or
  presentation-LUT references as image boxes; it is now bounded to the
  Referenced Image Box Sequence (2010,0510).
- **Empty Print Job UID no longer recorded (P2-4):** the workflow silently
  appended an empty job UID when the N-ACTION response omitted it; consistent
  with the discrete `printFilmBox`, empty UIDs are now dropped.
- **Port bounds guard (P2-5, crash fix):** `pacs://host:99999` trapped on
  `UInt16` conversion; now a clean validation error.
- **New `send` options (P3-1):** `--magnification replicate|bilinear|cubic`,
  `--film-destination magazine|processor|bin-1|bin-2`, and the full film-size
  set (`8.5x11`, `24x24cm`, `24x30cm` added).
- **Pre-flight checks:** `--check-status` (P2-1) queries printer status before
  printing — aborts on FAILURE, warns on WARNING; `--verify` (P3-3) performs a
  C-ECHO connectivity check first.

### DICOM Print — Milestone C (interoperability) from the enhancement plan

- **Image-box pixel attributes always sent (P1-1, bug fix):** the N-SET
  Preformatted Image Sequence previously omitted Rows/Columns/BitsAllocated/
  PhotometricInterpretation when no descriptor was supplied — rejected by strict
  SCPs. The print workflow now requires one `PrintImageData` per image (validated
  up front, before any network activity) and emits the attributes unconditionally;
  the discrete `setImageBox` throws a clear error without a descriptor.
- **`printWithTemplate` / `printImagesWithProgress` on a single association
  (P1-2, conformance fix):** both previously opened a separate association per
  DIMSE step (PS3.4 H.4 violation — the Film Session UID does not survive across
  associations). Both are reimplemented on the single-association workflow; the
  progress stream keeps its phase/percent updates via a new internal progress
  hook, and both gained `imageDescriptors:`/`eventHandler:` parameters.
- **Transfer syntax (P1-3, documented decision):** print presentation contexts
  now propose **Explicit VR LE only**. Previously Implicit VR LE was also
  proposed but data was always serialized Explicit — an implicit-only SCP would
  accept a syntax we then mis-encoded. Now such an SCP cleanly rejects
  negotiation; full Implicit-VR support remains future work if a real printer
  needs it.
- **DIMSE-response timeout (P1-4, bug fix):** an SCP that accepted the
  association and then went silent hung the tool forever. All print DIMSE
  response reads now race against `PrintConfiguration.timeout`; on expiry the
  association is aborted and `operationTimeout` is thrown.

### DICOM Print — Milestone B (image fidelity) from the enhancement plan

- **Preprocessing pipeline wired into printing (P0-1, bug fix):** `dicom-print send`
  now runs every frame through `ImagePreprocessor` by default — Rescale
  Slope/Intercept → VOI window (from the data set or auto-calculated) →
  MONOCHROME1 inversion → 8-bit MONOCHROME2 output (8-bit RGB for color mode).
  Previously raw *stored* pixel values were sent, so windowed CT/MR and
  MONOCHROME1 images printed with clinically incorrect grayscale/polarity.
  A `--raw` flag bypasses the pipeline. The two `XCTSkip`-quarantined MONOCHROME1
  preprocessor tests were rewritten to the decided behavior and re-enabled.
- **Encapsulated pixel data decoded before N-SET (P0-2, bug fix):** compressed
  sources (JPEG, JPEG 2000, JPEG-LS, RLE) were shipped as raw encapsulated
  fragments — malformed image boxes. `send` now decodes to native frames via
  `DICOMFile.tryPixelData()`, which also applies the JPEG-Baseline YBR→RGB
  descriptor correction.
- **Multi-frame handling (P0-6, bug fix):** previously the entire multi-frame
  Pixel Data value was sent as one image. New `--frame N` (1-based, default 1)
  and `--all-frames` (one image box per frame) options with bounds validation.
- **YBR color conversion (P1-5):** uncompressed YBR_FULL sources are converted
  to RGB for color printing (PS3.3 C.7.6.3.1.2); RGB→grayscale conversion is
  applied for grayscale mode. Uncompressed *subsampled* YBR (YBR_FULL_422 etc.)
  is explicitly rejected with a clear error rather than mis-converted (packed
  4:2:2 layouts need `bytesPerFrame` modeling in DICOMCore first).
- **Signed pixel safety (P2-6):** with preprocessing on by default, Pixel
  Representation = 1 sources are sign-extended and emitted as unsigned 8-bit
  P-Values — signed values are no longer sent to unsigned Image Boxes.
- New `ImagePreprocessor.prepareForPrint(pixelData:dataSet:frameIndex:colorMode:)`
  API prepares a single frame of already-decoded pixel data (the existing
  data-set variant now delegates to it).

### DICOM Print — Milestone A (safety) from the enhancement plan

- **Real printer-status parsing (P0-3, bug fix):** `parsePrinterStatus` was a stub
  that always returned NORMAL regardless of the N-GET response, so
  `PrinterStatus.isNormal` was always true. It now decodes Printer Status
  (2110,0010), Printer Status Info (2110,0020), Printer Name (2110,0030), and —
  when returned — Manufacturer (0008,0070) / Manufacturer Model Name (0008,1090).
  A response without a status attribute now reports "UNKNOWN" instead of a false
  NORMAL. `dicom-print status` surfaces the new fields in text and JSON output.
- **Non-zero exit code on print failure (P0-4, bug fix):** `dicom-print send` now
  exits with a failure code when the print result is unsuccessful; previously it
  printed "✗ Print failed" but exited 0, so automation could not detect failures.
- **DIMSE error detail surfaced (P0-5):** `CommandSet` gained `errorComment`
  (0000,0902), `errorID` (0000,0903), and `offendingElements` (0000,0901)
  accessors. `DICOMNetworkError.printOperationFailed` now carries an optional
  `detail` string populated from the SCP's Error Comment / Error ID on every
  print failure path, so users see e.g. "OUT OF FILM" instead of only a numeric
  status. A one-argument `printOperationFailed(_:)` factory preserves source
  compatibility.

### DICOM Print tool (`dicom-print`) — features + fixes

- **`--layout` now honored (bug fix):** the flag was parsed and echoed but never
  applied — `send` always used the automatic layout. `printImages` gained an
  optional explicit `layout:` override (nil = existing auto-layout) and the CLI
  now threads `--layout` through. A single image with an explicit `--layout` is
  routed accordingly.
- **`--color` added (gap fix):** the CLI always printed grayscale because
  `PrintConfiguration.colorMode` was never set. Added `--color grayscale|color`
  on `send`, which negotiates the Color Print Management Meta SOP Class and sends
  color image boxes.
- **Conformant image descriptors:** `send` now extracts per-image attributes
  (rows, columns, bits allocated/stored, high bit, samples per pixel, pixel
  representation, photometric interpretation) from each dataset and sends them in
  the N-SET Preformatted Image Sequence (PS3.3 C.13.5.1). Previously required
  image attributes were omitted.
- **N-EVENT-REPORT reception:** the Print SCU now receives, decodes, and
  acknowledges asynchronous printer/print-job notifications pushed by the SCP
  (Printer SOP Class status; Print Job SOP Class progress). New `PrintEvent`,
  `PrinterEventType`, `PrintJobEventType`, and a `PrintEventHandler` callback
  wired through `printImage`/`printImages`. `dicom-print send` prints faults
  always and routine progress in `--verbose`. This also fixes a latent
  correctness bug where an interleaved event could be mis-parsed as the awaited
  DIMSE response.
- **Build:** the `dicom-print` target was excluded from `Package.swift` and had
  drifted out of compilability (`DICOMParser`/`data(for:)` no longer existed,
  `@Sendable` capture errors). Repaired to use `DICOMFile.read(from:force:)`.
- **Layout presets + retry:** `dicom-print send` gained `--template`
  (single/comparison/grid/multi-phase — sets layout + film size + orientation,
  routed through the conformant single-association path) and `--retries N`
  (retry on connection/setup failure with exponential backoff; a submitted job
  is never retried, so no duplicate prints).
- **Presentation LUT:** added `PresentationLUTShape` and a `presentationLUTShape`
  print option. When set, the workflow N-CREATEs a Presentation LUT SOP Instance
  (part of the Grayscale/Color Print Management Meta, so no extra presentation
  context) and references it from each film box (Referenced Presentation LUT
  Sequence, 2050,0500). CLI: `--presentation-lut identity|inverse|lin-od`.
- **Annotation boxes:** added `PrintAnnotation` and `annotations` /
  `annotationDisplayFormatID` print options. The workflow sets Annotation Display
  Format ID on the film box and N-SETs each Basic Annotation Box (position + text)
  using a new sequence-scoped UID parser so annotation-box UIDs are not confused
  with image-box UIDs. CLI: repeatable `--annotate <text>` + `--annotation-format
  <id>`. Note: the Annotation Display Format ID is printer-specific.
- **Overlay box scaffolding:** added the Basic Print Image Overlay Box SOP Class
  UID and Referenced Image Overlay Box Sequence tag; full overlay-plane extraction
  remains a follow-up.

### Tests

- **Re-enabled the `DICOMNetworkTests` target** (was excluded from `Package.swift`),
  so print logic — including the new Presentation LUT / annotation / N-EVENT-REPORT
  code — is covered again (177 tests). The rotted, live-PACS `PACSIntegrationTests`
  is quarantined via `exclude:` until ported to the current API; two outdated
  MONOCHROME1 `ImagePreprocessor` expectations are `XCTSkip`-quarantined pending a
  product decision on 8-bit vs 16-bit print output.

### Fixed — Bug review pass (library crashes/correctness + CLI hardening)

- **STOW-RS server (critical):** the multipart parser decoded the entire body as UTF-8
  before splitting, so binary `application/dicom` uploads (almost never valid UTF-8)
  parsed to zero parts and were silently dropped while the server still reported
  success; rare bodies that did decode were corrupted by whitespace-trimming raw bytes.
  Now uses the same byte-scanning `MultipartMIME` parser as the client. See `BUG_REVIEW.md` (C1).
- **SIMD window/level:** `applyWindowLevel` passed a positive offset instead of
  `-minValue` into the vDSP scalar-add, blowing out every image rendered through the
  fast path. `PerformanceTests/SIMDImageProcessorTests.swift` had also silently dropped
  out of the build (excluded in `Package.swift`), so the regression test for this never
  ran; both are now fixed and back in the build. See `BUG_REVIEW.md` (H1).
- **Crash hardening:** bounds-check encapsulated pixel-data fragment lengths before
  slicing (`TransferSyntaxConverter`), handle empty/dot-only `TM` values (`DICOMTime`),
  tolerate duplicate tags inside a sequence item (`SequenceItem`), and guard a
  double-`resume()` race in the Storage SCP association handshake (`StorageSCP`). See
  `BUG_REVIEW.md` (H2, H3, M3, H4).
- **Correctness:** `allowMissingVR` in the DICOM JSON decoder had its condition
  inverted and never inferred a VR from the dictionary; `AT`-valued elements were
  byte-swapped as a single 32-bit word instead of two ordered 16-bit words on
  cross-endian transcode (also added missing `OD`/`OL`/`SV`/`UV` to the numeric-VR
  swap set); the data element dictionary loader dropped rows with an empty `Name`
  field (`(0018,0061)`, `(0400,0315)`, `(300A,0782)`). See `BUG_REVIEW.md` (M1, M2, M4).
- **Hardening:** segmentation palette index underflow on `segmentNumber == 0`,
  slice-unsafe absolute-index reads in `ByteOrder`/`PaletteColorLUT` (now relative to
  `startIndex`), non-ASCII digits accepted in UID validation, and a 3-byte G1 escape
  sequence unrecognized at end-of-buffer. See `BUG_REVIEW.md` (L1-L4, M5).
- **CLI / DICOMStudio Workshop parity:** rejected negative `--frame`/`--retry`/
  `--parallel`/`--batch` values that previously reached a trapping range or stride
  instead of erroring cleanly; `dicom-anon` and its app equivalent now require
  `--output` (or `--dry-run`) instead of silently doing nothing; directory converts in
  `dicom-convert` now retag non-DICOM output files with the correct extension per file
  (previously only the single-file path did); reversed `--select` ranges in `dicom-qr`
  no longer trap; study-level C-GET with `--hierarchical` now recovers the series UID
  from the received dataset instead of collapsing to a flat layout; `dicom-split` now
  reports real per-file failure counts and exits non-zero when any file failed. See
  `BUG_REVIEW.md` ("CLI / DICOMStudio Workshop hardening").

## [2.2.10] - 2026-07-15

### Added — J2K GPU/CPU Encode Route Planner

- Introduced `J2KRoutePlanner`, which resolves the three previously conflated encode
  choices — backend (`CPU`/`GPU`/`auto`), intent (`lossy`/`lossless`/`lossless-only`),
  and compression type (JPEG 2000 Part-1/Part-2/HTJ2K) — into a single deterministic
  J2KSwift API call instead of reverse-engineering them from the transfer-syntax UID.
  `auto` now genuinely selects the Metal GPU backend for lossy JPEG 2000/HTJ2K encodes
  where previously it never did. See `J2K_ROUTING_ARCHITECTURE.md`.
- JPEG 2000 Part-2 (`.92`/`.93`) *encoding* is explicitly rejected with a clear error —
  the pinned J2KSwift v11.0.2 cannot decode the Part-2 codestreams it encodes — while
  *decoding* existing Part-2 files remains fully supported; the real-Part-2 encode path
  is gated behind a flag for when the library gains decode support.
- Updated `CodecBackend`/`CompressionManager`/`CompressionConsole` wiring and added
  `J2KRoutePlannerTests` and `J2KGPUEncodeRoundTripTests` covering the new routing
  decisions and GPU round-trip correctness.

### Added — CharLS (dcmdjpls) JPEG-LS Bench Peer, `repro12bit` Repro Tool

- Added `CharLSCLICodec` (macOS-only), a decode-only DICOMStudio bench peer that wraps DCMTK's
  `dcmdjpls` to cross-validate JLSwift-produced JPEG-LS codestreams against a CharLS-backed
  reference decoder, matching the existing `binaryPath`/`version`/`decodeFrame` surface used by
  the other CLI peers (djpeg/djxl/Kakadu/Grok).
- `J2KTestBenchModels`/`J2KTestBenchService`/`J2KTestBenchViewModel`/`J2KTestBenchView`: wired
  `.charls` through the JPEG-LS bench family (`includeCharLS`), and `J2KBenchSyntax.all` is now
  derived entirely from `TransferSyntax.selectableEncodings` for every format (previously only
  JPEG 2000/HTJ2K rows were catalog-driven), excluding JPEG XL JPEG Recompression (`.111`) since
  the bench encodes raw frames rather than repacking an existing JPEG.
- Added `repro12bit`, a standalone executable target for reproducing/isolating 12-bit codec
  issues against J2KSwift, alongside `JLISWIFT_GAP_ANALYSIS.md` documenting a verified bit-depth,
  color/sampling, and gap audit of the JLISwift dependency (no critical/high findings).
- `CompressionQuality.expectedMinPSNRDb` gives each encode preset (`.low`/`.medium`/`.high`/
  `.maximum`, and `.custom` via interpolation) a conservative minimum-PSNR pass bar for lossy
  round-trip tests, so the bench's `lossyPSNRThresholdDb` default now tracks
  `J2KTestBenchService.lossyEncodeQuality` instead of a fixed 40 dB value a lower-quality preset
  could never clear.
- `ModalityMapping.StandardModality`/`allCodes` centralizes the canonical DICOM modality list;
  the CLI Workshop's modality pickers (C-FIND/C-MOVE/MWL/etc.) now draw their `allowedValues`
  from it instead of hand-maintained arrays, so new modalities need updating in one place.

### Fixed — Same-syntax lossy recompression silently dropped `--quality`

- `CompressionManager.isRecompression`/`compressData`/`compressDataWithMetrics` now treat a
  same-UID lossy target with an explicit `quality` as a genuine recompression (decode-to-native
  + re-encode) rather than a byte passthrough. Previously, re-compressing an already-JPEG-2000
  (or other lossy-encapsulated) file into the *same* transfer syntax UID with a new `--quality`
  silently copied the existing codestream through unchanged (input size == output size, ~0 ms),
  discarding the requested quality. Lossless / no-quality same-syntax targets keep the
  passthrough. `dicom-compress` and the DICOMStudio Workshop both pass `quality` through to
  `isRecompression` so their two-phase-recompression UI note stays accurate.

### Fixed — Standalone macOS packaging

- Removed the DICOMStudio-only OpenJPEG comparison wrapper from `DICOMCore`'s
  default dependency graph. Standalone macOS consumers no longer require a
  Homebrew installation or the absolute `/opt/homebrew/lib/libopenjp2.a` path.
- Removed the corresponding DICOMStudio static-link and arm64-only Xcode settings;
  production JPEG 2000 support continues to use J2KSwift.
- Optional real-image codec and benchmark tests now report as skipped when the
  gitignored `LocalDatasets` or `SampleStudies` corpora are unavailable in CI.

### Changed — J2KSwift v11.0.2

- Updated the JPEG 2000 / HTJ2K / JP3D dependency floor to J2KSwift v11.0.2.
- The decoder-only update stops truncated quality-layer decoding at the exact
  coding-pass boundary and bounds scratch clearing to the active code-block region,
  without changing the DICOMKit public API or codestream format.

### Added — JPEG Baseline Encoder Choice (DICOMStudio-only)

- Added `JPEGCodecEngine` (DICOMCore: `.jli` / `.native`) and
  `CodecRegistry.encoder(for:engine:)`, which honours the engine selection **only** for
  JPEG Baseline (1.2.840.10008.1.2.4.50) — the one transfer syntax this library can encode
  two ways: the pure-Swift `JLICodec` (the registry default for all four JPEG syntaxes) or
  Apple's `NativeJPEGCodec` (ImageIO). JPEG Extended/Lossless/Lossless SV1 have no second
  encoder, so `engine` is a no-op for them.
- Threaded `jpegEngine` through `CompressionManager.compressData` /
  `compressDataWithMetrics`, defaulting to `.jli` so `dicom-compress` output is unchanged.
- Added an internal "JPEG Engine" picker to the DICOMStudio CLI Workshop's `dicom-compress`
  form, visible only for `operation == compress && codec == jpeg` — a benchmarking aid with
  no `dicom-compress` CLI counterpart, so it never appears in the copy-pasteable command
  preview. Required a new `CLIParameterDefinition.visibleWhenAll` ([`[CLIParameterVisibilityCondition]`],
  ANDed with the existing single-condition `visibleWhen`) since `codec` persists across
  operations and a single condition couldn't pin the picker to compress-only.
  `CommandBuilderHelpers.isVisible(...)` is now the one predicate shared by command-preview
  generation, required-field validation, and the ViewModel's form rendering.

### Fixed — `dicom-convert` to DEFLATE dropped pixel data from encapsulated sources

- An encapsulated source (JPEG/JPEG 2000/RLE/…) converted to Deflated Explicit VR Little
  Endian is now decoded to native pixels first. DEFLATE (PS3.5 A.5) is a data-set-level
  codec over a *native* stream — it has no encapsulated form — but `DICOMConverter` used to
  serialize the encapsulated (7FE0,0010) straight into the deflate stream: the codestream
  survived, but the output was labelled 1.2.840.10008.1.2.1.99 while still carrying an
  undefined-length, Item-fragmented pixel element, so no conformant reader (including
  DICOMKit's own) could decode pixel data from it — and the tool reported success.

### Fixed — `dicom-compress`/`dicom-convert` `--output` naming a directory failed with "Is a directory"

- Both CLIs now resolve `--output` through the existing `OutputPathResolver` (already used
  elsewhere) before writing, so passing a directory (e.g. `~/Desktop/DICOM_Output/`, or
  whatever the DICOMStudio Workshop's Browse button hands back) writes the input's filename
  into that directory instead of failing. An explicit file path is still used verbatim.

### Fixed — DICOMStudio CLI Workshop could build/compare against a different checkout's DICOMKit

- `CLIToolBuilder.repoRoot()` and `CLIToolTerminalCompare.locateBinary()` no longer fall back
  to a hard-coded absolute path or the process's working directory (which is `/` for a GUI
  app). They now resolve the SwiftPM package root by walking up from `#filePath` — the
  checkout the running app was actually compiled from — so `swift build`/binary lookup can
  no longer silently target a sibling repo whose DICOMKit accepts different tokens, which
  previously made "Compare CLI" report diffs that didn't exist in the current repo.

### Added — Transfer-Syntax Lossy/Lossless Split and Encode-Intent Threading

- Introduced `LosslessCapability` (`losslessOnly`/`lossyOnly`/`both`), `EncodingIntent`, and
  `SelectableEncoding` on `TransferSyntax` to correctly model the JPEG 2000/HTJ2K/JPEG XL
  "general" UIDs (`.91`/`.93`/`.203`/`.112`), which per PS3.5 may carry either a lossy or
  lossless codestream. `TransferSyntax.parse()` itself remains conservative (bare
  `…-lossless` still maps to the old reversible-only UID, to avoid changing association
  negotiation behavior in dicom-send/retrieve/qr) — the lossy/lossless split is exposed only
  through the new `parseEncoding()` API.
  See `J2K_HTJ2K_TRANSFER_SYNTAX_SPLIT_PLAN.md`.
- Added missing `UIDDictionary` entries and corrected display names for `.92`/`.93`/`.201`/
  `.202`/`.203` (e.g. "JPEG 2000 Lossless Only", "HTJ2K Lossless Only (RPCL)").
- Threaded `EncodingIntent` from CLI/app codec-name resolution through to `JXLCodec` and
  `DICOMConverter`, so `…-lossless` codec names now genuinely encode reversibly into the
  general UID (previously not possible) and `…-lossy` produces true irreversible compression.
  See `J2K_HTJ2K_JXL_ENCODE_INTENT_AND_LOSSY_ATTRS_PLAN.md`.
- Added `CompressionManager.applyLossyImageCompressionAttributes`, shared by `dicom-compress`
  and `dicom-convert`, which stamps Lossy Image Compression (0028,2110), Method (0028,2114),
  and Ratio (0028,2112) plus Image Type → DERIVED per PS3.3 C.7.6.1.1.5, with
  append/once-lossy-always-lossy semantics.
- `JXLCodec`: added signed 16-bit support (JXLSwift `int16` level-shift) and genuine lossy
  VarDCT grayscale encoding (JXLSwift 1.4.0) instead of silently falling back to lossless.

## [2.2.9] - 2026-07-15

### Fixed — SwiftPM consumer build hygiene

- Declared the `dicom-3d` and `dicom-j2k` target README files as excluded package
  inputs, removing the two unhandled-file warnings emitted during consumer builds.
- Declared the intentionally inactive complements of the explicitly sourced
  `DICOMKitTests` and `DICOMViewerTests` targets as excluded inputs, removing two
  package-planning warnings covering 102 test files without changing test membership.
- Applied the existing optional-fixture contract to two HTJ2K benchmark tests so
  clean CI checkouts skip them when the gitignored MR corpus is unavailable.
- Hardened release validation to reject production compiler warnings and test
  package-planning warnings, synchronized the release artifact matrix with all
  36 enabled CLI products, pinned manual release jobs to the requested tag, and
  staged release creation as a draft before publication for immutable releases.
- No decoder, runtime, product API, ABI, or command behavior changed.

## [2.2.6] - 2026-07-09

Patch release: shared transfer-syntax negotiation token list for `dicom-retrieve`/`dicom-qr`,
plus two reporting-accuracy fixes (`--backend`, `dicom-compress info` lossless state). No
association-negotiation or encode-behavior changes — this release only corrects what tools
report and what token lists they offer.

### Added — Shared transfer-syntax negotiation token list

- Added `TransferSyntax.negotiableImageSyntaxTokens` / `negotiableImageTokens` (DICOMCore) as
  the single source of truth for the transfer-syntax lists offered by the UID-only negotiation
  tools (`dicom-retrieve`, `dicom-qr`) — the negotiation analogue of
  `CompressionManager.supportedCodecs()` (dicom-compress) and `DICOMConverter.cliTokens`
  (dicom-convert). Every token round-trips through `TransferSyntax.parse()` (enforced by tests).
- Wired the DICOMStudio CLI Workshop `dicom-retrieve` / `dicom-qr` transfer-syntax pickers and
  the `dicom-retrieve` / `dicom-qr` CLI `--transfer-syntax` help onto that shared list, so both
  surfaces stay in lockstep. This adds the previously-missing JPEG-LS, JPEG XL, and JPEG 2000
  Part 2 (plus `explicit-vr-be`, `deflate`, `jpeg-extended`, `jpeg-lossless-sv1`) syntaxes that
  the old hand-maintained lists stopped short of; regenerated the `CLIContracts.json` parity
  golden to match.
- CLI Workshop: the `dicom-convert` transfer-syntax dropdown now shows the short kebab aliases
  (`DICOMConverter.aliasTokens`, e.g. `jpeg2000-lossless`, `htj2k-lossy`) instead of the CamelCase
  `cliTokens`, so it reads the same as the `dicom-compress` / `dicom-retrieve` / `dicom-qr`
  dropdowns. The `dicom-convert` CLI resolves the kebab alias identically, so the generated
  command and in-process execution are unchanged.

### Fixed — `dicom-compress info` reports the true lossless state for general J2K/HTJ2K/JXL UIDs

- `CompressionManager.getCompressionInfo` now derives `isLossless` (and the transfer-syntax
  display name) from Lossy Image Compression (0028,2110) for the `both`-capable general UIDs
  (`.91`/`.93`/`.203`/`.112`), instead of the UID-level flag which always reported "Lossy".
  A file reversibly encoded into a general UID (e.g. `--codec jpeg2000-lossless` → `.91`) now
  reports `Transfer Syntax: JPEG 2000 Lossless` / `Lossless: Yes` on both `dicom-compress info`
  surfaces (text + `--json`) and in the CLI Workshop, so the name and the Lossless line no
  longer contradict each other. Single-capability UIDs (e.g. `.90`, `.50`) are unchanged —
  their UID is authoritative. Reference: PS3.3 C.7.6.1.1.5.

### Fixed — `--backend` reporting reflected the hardware probe, not the actual encode path

- Added `CodecBackendPreference.effectiveEncodeBackend(isLossless:isJPEG2000Family:)` (DICOMCore)
  and `CompressionConsole.compressBackend(codec:preference:)` (DICOMKit), which report the backend
  the encoder will **actually** dispatch to rather than the best available hardware.
  `J2KSwiftCodec` only takes the Metal GPU path for a genuinely lossy JPEG 2000/HTJ2K encode — the
  lossless GPU path isn't bit-exact on 12/16-bit medical data — so `auto`/`--backend metal` on a
  lossless or non-J2K encode previously reported "Metal (GPU)" in `dicom-compress`/CLI Workshop
  verbose output even though the encode ran on the CPU. An explicit `--backend metal` request that
  can't use the GPU is now downgraded to the CPU backend with an explanatory note instead of
  silently misreporting.
- `CodecBackend.accelerate.displayName` now reports "Accelerate (CPU)" instead of the stale
  "Accelerate (not available)" on platforms where Apple's `Accelerate` framework is present but the
  old J2KAccelerate SIMD-family probe (removed in J2KSwift v11.0.0) no longer exists.

## [2.2.1] - 2026-07-06

Patch release: strict-concurrency bridge fix plus package-wide warning cleanup.
Both `swift build` and `swift build -Xswiftc -warnings-as-errors` pass cleanly;
no runtime behavior changes.

### Fixed — Swift 6 Strict-Concurrency Task Bridge in CLI Targets

- Fixed the `DispatchSemaphore` + `Task {}` async-to-sync bridge pattern used by CLI entry points so Swift 6 strict-concurrency no longer flags data-race sendability risks for `waitForTask`/`runAsync` helpers. The bridge now uses `Task.result` and an explicitly documented manually-synchronized capture (`nonisolated(unsafe)`), preserving runtime behavior while satisfying the compiler's model.
- Updated affected targets:
  - `Sources/dicom-jpip/main.swift`
  - `Sources/dicom-3d/main.swift`
  - `Sources/dicom-j2k/main.swift`
  - `Sources/dicom-viewer/main.swift`
- Also cleaned up adjacent strict/warnings-as-errors diagnostics surfaced during validation in shared runtime files (`ScriptEngine`, `DICOMDIRReader`/`DICOMDIRWriter`, `ImagePreprocessor`, `ImageResizer`, `JP3DVolumeBridge`, `JP3DVolumeDocument`, `StudyManager`, gateway mapping/converter helpers, and compression manager) without changing intended behavior.

### Fixed — Remaining `-warnings-as-errors` Diagnostics Across the Package

- `dicom-3d`: never-mutated `var` locals converted to `let` (`VolumeExport`, `MPRGenerator`); redundant `try`/`try?` removed from non-throwing `DataSet` accessor calls (`VolumeData`).
- `DICOMWeb`: redundant `await` removed from synchronous same-isolation calls (`ConformanceStatementGenerator`, `HTTPConnectionPool`, `HTTPRequestPipeline`); unused `guard let url` binding replaced with a `URL(string:) != nil` existence test (`DICOMJSONDecoder`); unused locals dropped (`CompressionMiddleware`, `HTTPRequestPipeline`).
- `DICOMStudio`: pure static J2K test helpers marked `nonisolated` — they already executed off the main actor at runtime (`J2KTestingViewModel`); pipe-drain captures in `CLIToolTerminalCompare` use the same documented `nonisolated(unsafe)` + happens-before pattern as the CLI bridge; cine timer callback wrapped in `MainActor.assumeIsolated` (timer is scheduled on the main run loop); slider `Binding` setters pass closures instead of non-`@Sendable` function values (`DICOMVolumeViewerView`, `JP3DComparisonView`, `JP3DVolumeComparisonView`); unused locals removed (`CLIWorkshopViewModel`, `JP3DMPRView`).

## [2.2.0] - 2026-07-04

CLI parity harness, JPEG XL lossy/recompression, and round-trip regression suite.

### Changed — P2/P3 Console-Builder and Dir-Walk Dedup (2026-07-04)

Follow-up to the remediation batch: every remaining hand-duplicated console block and directory
walk now lives in one shared builder/gatherer that both the CLI and the Workshop call, so the two
surfaces can no longer drift (`CLI_TOOLS_SHARED_CORE_VERIFICATION.md` → *P — duplication*).

- **New shared console builders (CLI text canonical):** `AnonConsole` (+ shared
  `Anonymizer.parseFlexibleTag`), `PixelEditConsole`, `ImageConsole`, `ExportConsole`,
  `UIDConsole`, `CompressionConsole.infoText/infoJSON/backendsText/backendsJSON`,
  `NetworkConsole` qr-line additions, `UPSConsole` (DICOMWeb), and
  `NetworkConsole.mwlCreateDetailBlock` (dedups the app's HL7/REST MWL-create branches).
- **New shared gatherers:** `FileGatherer.regularFiles(under:recursive:)` (sorted,
  content-agnostic walk — anon/validate/convert/pdf/export/image on both surfaces) and
  `FrameMerger.gatherInputFiles(from:recursive:)` + `FrameMerger.isDICOMFile` (dicom-merge).
- **Real drift found and fixed while hoisting** (all previously hiding in un-goldened paths):
  the app's pixedit executor double-printed the Image line, added an "Edited pixel data:" line
  and a byte-size suffix the CLI never prints; anon's per-file verbose text and single-file
  failure behavior differed from the CLI; UPS create-workitem/change-state used app-invented
  wording instead of the CLI's response text; dicom-merge sorted its inputs in-app but not in
  the CLI, so merged instance order could differ between surfaces (both now sort).
- **Deterministic batch order:** all shared walks sort by path, so directory-mode output order
  is stable run-to-run on both surfaces (previously filesystem enumeration order).
- App-only additions that have no CLI counterpart (sandbox redirect notes, UPS pre-flight
  guidance and error hints, MWL create banners) are unchanged.

### Changed — Three-Axis Shared-Core Remediation Batch (2026-07-04)

Follow-up to the three-axis verification of all 40 tools (`CLI_TOOLS_SHARED_CORE_VERIFICATION.md`,
full per-claim outcomes in its *Remediation outcomes* section). Eleven tools were held by user
triage (measure, viewer, 3d, ai, report, gateway, cloud, server, j2k, jpip, print) and the network
port/hostname workflow was left untouched as planned. Highlights:

- **New shared surfaces (CLI + Workshop call one implementation):**
  - `DataExchangeWorkflow` (DICOMWeb) — the entire dicom-json/dicom-xml pipeline (default output
    path, always-write-file behavior, tag filtering, metadata-only, verbose lines). Fixes the app's
    divergent print-to-console/refuse-reverse behavior.
  - `ConvertConsole` (DICOMKit) — dicom-convert's terse console (transcode line, batch ✓/✗ +
    `Conversion complete:` summary); the app's extra Read/Wrote/Transfer-Syntax chrome removed.
  - `TagEditConsole` (DICOMKit) — dicom-tags change block + `Output written to:` completion line
    (the app previously printed an unconditional count and `Saved:`).
  - `QRSessionState` (DICOMNetwork) — dicom-qr's save-state model hoisted from the executable;
    `--save-state` now also works in the Workshop and app-saved states resume via `dicom-qr resume`.
  - App validate now renders via the shared `ValidationReport` (the drifted app copy with its
    `Exit code:` annotation block was deleted); app compress batch uses the shared
    `findDICOMFiles`; app uid/pixedit call the shared `validateFileUIDs`/`parseRegion`.
- **Formerly-inert flags implemented:** `dicom-merge --format enhanced-ct/mr/xa` (Enhanced SOP
  Class + Shared/Per-frame Functional Groups), `dicom-script run --parallel` (concurrent pipeline
  commands with source-order output replay), `dicom-compress --backend`
  (`CompressionConfiguration.forcedBackend` → J2K/HTJ2K Metal GPU encode; other codecs unaffected),
  `dicom-image --use-exif` under `--split-pages` (per-page EXIF), `dicom-dcmdir update`
  (real implementation via `DICOMDIRWorkflow.updateDirectory`), `dicom-query
  --referring-physician` (now a study-level C-FIND matching key on both surfaces).
- **Removed (declared no-ops):** `dicom-json --format standard|dicomweb` and `--stream` (goldens
  proved byte-identical output for every value; the encoder always emits the DICOMweb PS3.18 JSON
  model); the app-only qido timeout field.
- **Wire/exit-code correctness:** app mpps update no longer sends a `studyInstanceUID` the CLI
  never sets; anon in-app exit code is now structured (any failed file → 1) instead of sniffed
  from output text; dump's No-Color toggle is honored (defaults ON in-app with a truthful
  `--no-color` preview).
- **Surface adds:** uid regenerate accepts multiple inputs in-app (cross-file UID mapping like the
  CLI); ups gains the CLI's `--create <json-file>` form; qido gains `--verbose`.
- **New round-trip oracles:** merge enhanced-format (SOP class + functional groups + standard
  unchanged), script parallel-pipeline (rendezvous concurrency + source-order replay + failure
  propagation), dcmdir update (add + prune-missing).

### Added — JPEG XL Lossy Encode (Transfer Syntax …4.112) in dicom-compress

- **`dicom-compress compress --codec jpeg-xl`** now produces **lossy** JPEG XL (`1.2.840.10008.1.2.4.112`, general JPEG XL) via JXLSwift's VarDCT encoder, alongside the existing lossless JPEG XL (`…4.110`). Both the `dicom-compress` CLI and the DICOMStudio CLI Workshop drive the identical shared `CompressionManager` / `CodecRegistry` path, so the two surfaces cannot drift. `--quality maximum|high|medium|low|0.0–1.0` maps to the JPEG XL quality/distance curve (mirroring the `--quality` mapping already used by the JPEG and JPEG-LS lossy codecs).
  - **Codec naming** aligns with the rest of the family (`jpeg2000`/`htj2k`): the bare `jpeg-xl`/`jxl` names now resolve to the **lossy** syntax (`…4.112`); the explicit `jpeg-xl-lossless`/`jxl-lossless` names select the lossless syntax (`…4.110`). `jpeg-xl-lossy`/`jxl-lossy` are accepted aliases for the lossy target. (Behaviour change: `jpeg-xl`/`jxl` previously encoded lossless.)
  - **`JXLCodec`** (`Sources/DICOMCore/JXLCodec.swift`): added `…4.112` to `supportedEncodingTransferSyntaxes`, a per-instance `encodingTransferSyntaxUID` that selects the encode mode (…4.110 → lossless Modular, distance 0; …4.112 → lossy VarDCT at a quality-derived distance), and a `jxlQuality(from:)` mapping. JXLSwift's VarDCT lossy encoder covers 8-/16-bit RGB/RGBA within its size limits; for inputs it can't take (grayscale, oversized) it transparently falls back to the lossless Modular path, so a `…4.112` encode always yields a valid — and conformant, since the general syntax permits both — JPEG XL codestream.
  - **`CodecRegistry`** (`Sources/DICOMCore/ImageCodec.swift`): the JPEG XL encoder is now wired per-UID (`JXLCodec(encodingTransferSyntaxUID: uid)` for `…4.110` and `…4.112`), mirroring the per-syntax encoder wiring already used for JLISwift / J2KSwift.
  - **`CompressionManager`** (`Sources/DICOMKit/Compression/CompressionManager.swift`): codec-name map splits JPEG XL into a lossless entry (`jpeg-xl-lossless`/`jxl-lossless` → `…4.110`) and a lossy entry (`jpeg-xl`/`jxl`/`jpeg-xl-lossy`/`jxl-lossy` → `…4.112`). Flows automatically to the CLI validator, the `--help` codec list, and the DICOMStudio Workshop codec picker (which derives from `supportedCodecs()`).
  - **DICOMStudio** (`Sources/DICOMStudio/Views/DataExchangeView.swift`): the Data Exchange compression-algorithm picker gains "JPEG XL Lossless" and "JPEG XL Lossy" entries, with `jpeg-xl` marked lossy.
  - **Tests** (`Tests/DICOMCoreTests/JXLCodecRegistryTests.swift`, `CompressionCodecMapTests.swift`): registry now exposes an encoder for `…4.112`; new round-trips prove an RGB lossy encode decodes back to source dimensions and a grayscale lossy request falls back to lossless (bit-exact); the codec-map parity test pins `jpeg-xl` → `…4.112` and `jpeg-xl-lossless` → `…4.110`.
  - **Note:** `dicom-convert`'s `jpeg-xl`/`jxl` `--transfer-syntax` aliases remain **lossless** (`…4.112` is not yet a convert target) — this change is scoped to `dicom-compress`.

### Added — JPEG XL JPEG Recompression (Transfer Syntax …4.111) in dicom-convert

- **`dicom-convert --transfer-syntax JPEGXLRecompression`** now losslessly transcodes a JPEG Baseline (…4.50) file to JPEG XL JPEG Recompression (`1.2.840.10008.1.2.4.111`) and back. Unlike every other codec, recompression is not a pixel operation: it wraps the existing JPEG bitstream in a JPEG XL container (with a `jbrd` reconstruction box) so the original JPEG is recovered **byte-for-byte** — no additional loss on top of the JPEG the file already carries. The reverse (`…4.111` → `JPEGBaseline`) reconstructs the byte-identical original JPEG.
  - **`JXLCodec`** (`Sources/DICOMCore/JXLCodec.swift`): added the fragment-level `recompressJPEGFragment(_:)` / `reconstructJPEGFragment(_:)` helpers (backed by JXLSwift's `encodeLosslessJPEG` / `decodeLosslessJPEG`), added `…4.111` to the decodable transfer syntaxes, and routed the `…4.111` pixel decode through JPEG reconstruction → the JPEG codec so decoded pixels match the wrapped JPEG with the descriptor's channel layout (rather than the VarDCT bridge's colour-space representation). The forward encode is deliberately NOT registered as a pixel `ImageEncoder` (recompression takes JPEG bytes, not pixels).
  - **`TransferSyntaxConverter`** (`Sources/DICOMCore/TransferSyntaxConverter.swift`): added `isJXLRecompressionForward` / `isJXLRecompressionReverse` predicates (gated to JPEG Baseline ↔ …4.111, matching JXLSwift's baseline-DCT scope), a fragment-level `transcodeJXLRecompression(…)` path (no pixel decode/re-encode — structurally mirrors the J2K↔HTJ2K fast path), the `canTranscode` admission for these pairs, and a lossless-guard bypass so a lossy-Baseline → …4.111 wrap is correctly treated as lossless (it adds no loss).
  - **`DICOMConverter`** (`Sources/DICOMKit/DICOMConverter.swift`): added `JPEGXLRecompression` to the shared convert target catalog, so the new target flows automatically to the CLI `--transfer-syntax` help, the DICOMStudio CLI Workshop picker, the representative parameter catalog, and `parseTarget(_:)` — the CLI and the Workshop share one code path. It is convert-only (not a `dicom-compress`/`CompressionManager` pixel codec).
  - **CLI parity**: `CLIContracts.json` transfer-syntax abstract updated; `cli-parity-gen` gains a derived `syn-ct-baseline.dcm` JPEG-Baseline fixture (`ctbaseline`) and a `dicom-convert ts-JPEGXLRecompression` decoded-pixel-hash scenario exercising the shared path in both surfaces.
  - **Tests** (`Tests/DICOMRoundTripTest/ConvertRoundTripTests.swift`): oracle round-trips proving byte-identical JPEG reconstruction through the …4.111 wrap, …4.111 pixel decode equals the wrapped JPEG's pixels, onward transcode …4.111 → J2K Lossless, and rejection of a non-JPEG source.

### Added — Shared CLI ↔ App Orchestration: CompressionConsole, DICOMConverter, DICOMDIRDumpFormatter, DICOMDIRWorkflow, EncapsulatedDocumentWorkflow

- **`CompressionConsole`** (`Sources/DICOMKit/Compression/CompressionConsole.swift`): Pure shared formatter and input-parser for `dicom-compress`. Both the CLI binary and DICOMStudio's CLI Workshop call this single type for `--quality` / `--backend` parsing, binary byte formatting, and every console line (compress header, stats, batch totals). Replaces duplicated inline formatting on both sides. Mirrors the `NetworkConsole` shared-formatter pattern.
- **`DICOMConverter`** (`Sources/DICOMKit/DICOMConverter.swift`): Single source of truth for the `dicom-convert` transfer-syntax conversion API — the ordered target catalog (UID, CamelCase CLI tokens, kebab aliases), `parseTarget(_:)`, `cliTokens`/`aliasTokens` picker lists, and the shared `convertToDICOM(dicomFile:to:stripPrivate:)` pipeline. Both the CLI (`dicom-convert`) and the DICOMStudio CLI Workshop call this directly so conversion bytes are identical and the `--transfer-syntax` help text cannot drift from the picker.
- **`DICOMDIRDumpFormatter`** (`Sources/DICOMKit/DICOMDIRDumpFormatter.swift`): Shared renderer for `dicom-dcmdir dump` output (tree / json / text formats). The CLI and the CLI Workshop both call `DICOMDIRDumpFormatter.render(_:format:verbose:)` so their output pipelines cannot drift.
- **`DICOMDIRWorkflow`** (`Sources/DICOMKit/DICOMDIRWorkflow.swift`): Shared orchestration helpers for `dicom-dcmdir` — recursive DICOM file discovery (skipping the existing DICOMDIR, sorting by path), the create build-loop (read, compute relative path, add to `DICOMDirectory.Builder`, emit summary), and the validate report (statistics + file-set + record-type breakdown). Both the CLI and the Workshop call these helpers, eliminating hand-mirrored orchestration that could silently diverge.
- **`EncapsulatedDocumentWorkflow`** (`Sources/DICOMKit/EncapsulatedDocument/EncapsulatedDocumentWorkflow.swift`): Shared orchestration helpers for `dicom-pdf` — `EncapsulatedDocumentType.fileExtension`, `defaultModality`, the `--show-metadata` report block, and the human-readable file-size formatter. Both the CLI and the Workshop call these helpers so the `dicom-pdf` parity surface cannot drift.
- **Synthetic DICOMDIR fixture** (`Sources/DICOMStudio/Resources/CLIParity/synthetic/syn-dicomdir`): Pre-built minimal DICOMDIR file added to the synthetic corpus for the offline `dicom-dcmdir` parity scenario, making the dcmdir dump/validate scenarios runnable without a real PACS file hierarchy.

### Fixed — DICOMWriter Drops Encapsulated Pixel Data

- **`DICOMWriter.serializeElement(_:)` now emits encapsulated pixel data** (`Sources/DICOMCore/DICOMWriter.swift`): The generic serializer previously skipped any undefined-length (`0xFFFFFFFF`) element that was not `.SQ`, silently emitting an empty PixelData shell. This caused `DICOMConverter`/`dicom-convert` to fail on ANY compressed source — the decoder saw zero fragments and threw "Frame 0 starts beyond data bounds" — and would have corrupted any `DataSet.write()` / `DICOMFile.write()` rewrite of a compressed dataset. Fixed by adding a dedicated `serializeEncapsulatedPixelData(_:fragments:)` branch that emits the full Basic Offset Table Item + one Item per codestream fragment (odd fragments padded to even length per PS3.5 A.4) + the Sequence Delimitation Item.

### Fixed — DICOMFile.pixelData() No Longer Relabels YBR as RGB

- **Removed stale YBR→RGB photometric relabel** (`Sources/DICOMKit/DICOMFile+PixelData.swift`): The previous code relabelled YBR pixel data as RGB for transfer syntaxes that the retired ImageIO-based codecs once handled (JPEG 50/51/57/70, JPEG 2000 90/91). The current registry uses pure-Swift codecs (JLISwift, J2KSwiftCodec, JPEG-LS, RLE) that decode to the *source* photometric interpretation and leave YBR→RGB conversion to `PixelDataRenderer`. The relabel suppressed that renderer conversion and washed out/blanked colour compressed previews. Removing it restores correct colour rendering for all compressed sources while preserving the existing `isImageIODecodedTransferSyntax` helper (unused after this change).

### Fixed — JPEG-LS NEAR Parameter Overflow for 16-bit Sources

- **JPEG-LS NEAR clamped to 255** (`Sources/DICOMCore/JPEGLSCodec.swift`): JLSwift's `JPEGLSEncoder.Configuration` rejects a NEAR value above 255. For a 16-bit source at high quality, the formula `maxVal * (1 - quality) * 0.1` could yield NEAR ≈ 655, causing the encode to throw. Added a `maxNear = 255` clamp so lossy JPEG-LS encoding of 16-bit images at any quality level succeeds.

### Fixed — PixelEditor Handles Compressed Sources

- **`PixelEditor` decodes encapsulated sources before editing** (`Sources/DICOMKit/PixelEditing/PixelEditor.swift`): Editing a compressed (encapsulated) PixelData element in place corrupts the encoded bitstream; the output — still tagged as the compressed transfer syntax — cannot be decoded by a viewer. `PixelEditor` now detects an encapsulated source, decodes it to native pixels first, and emits the edited result as uncompressed Explicit VR Little Endian. Multi-frame sources are handled correctly.

### Fixed — dicom-pixedit `--invert` Rendered Solid White

- **`PixelEditor` now inverts the VOI window and uses the correct signed pivot** (`Sources/DICOMKit/PixelEditing/PixelEditor.swift`): `dicom-pixedit --invert` (and the CLI Workshop "Invert" toggle, which shares `PixelEditor.processData`) produced a solid-white image. `applyInvert` inverted stored pixels around `2^bitsStored − 1` but never updated the file's VOI Window Center (0028,1050); because the viewer, image exporter, and Horos all honour the stored window by default (`DICOMImageExporter.determineWindowSettings`, rescale-adjusted), every inverted pixel fell outside the unchanged window and clamped to white. Signed data was additionally clamped because the pivot used the unsigned max instead of `−1`. Fixes: (1) invert around `isSigned ? −1 : maxValue`; (2) re-point each Window Center to `slope·pivot + 2·intercept − center` (output-unit equivalent of inverting the stored center around the pivot), leaving Window Width unchanged and no-op when the file carries no stored window; (3) `--apply-window` now bakes into — and resets the stored VOI window to — the full *representable* stored range (signed-aware: `[0, 2^b−1]` unsigned, `[−2^(b−1), 2^(b−1)−1]` signed), so a baked signed image is no longer written into only half the range and rendered ~2× too dark. `formatDS` guards against non-finite values from pathological rescale metadata. Regression tests in `PixelEditorTests` render the inverted frame through the shared viewer/export window policy and assert a true photographic negative (not solid white) for both MONOCHROME2 and MONOCHROME1, plus the signed window-bake range.

### Added — DICOMKitTests: Parity and Regression Test Suite

Seven new test files added to the `DICOMKitTests` target (`Package.swift` sources updated):

- **`EncapsulatedPixelDataWriteTests`**: Regression for the `DICOMWriter` encapsulated pixel data fix — asserts the full BOT + fragment structure is emitted, odd fragments are padded, a zero-fragment BOT writes cleanly, and a round-trip `DataSet.write()` → `DICOMParser.parse()` recovers the original fragments.
- **`CompressionManagerImplicitVRTests`**: Regression for `CompressionManager` on Implicit VR Little Endian sources — pins that the shared `DICOMWriter` path re-encodes sequences from parsed items (not raw bytes) and promotes oversized short-VR values to UN, preventing byte-stream desync and the "No pixel data found" failure on decompress.
- **`CompressedPreviewRenderParityTests`**: Parity regression that the `DICOMFile.pixelData()` return value for a freshly compressed file matches the value after a round-trip decompress, for every codec — so the photometric-relabel removal cannot silently reintroduce colour corruption.
- **`CompressionConsoleTests`**: Contract tests that lock the exact `dicom-compress` console strings produced by `CompressionConsole` — byte formatting, quality parsing, header lines, compressed-result lines — so the CLI and CLI Workshop cannot drift.
- **`DICOMConverterTests`**: Contract tests for the shared `DICOMConverter` API — every catalog token (cliToken / aliasToken / UID / extraAliases) round-trips through `parseTarget`; picker token lists are exactly the catalog; `CLIContracts.json` entry is regenerable from the catalog; DEFLATE converts without error.
- **`ExportWindowParityTests`**: Regression that `DICOMImageExporter.renderFrameForExport` and `determineWindowSettings` rescale-adjust the VOI window (HU → stored via Rescale Slope/Intercept), so a CT with a non-zero Rescale Intercept exports with the correct contrast — not washed out.
- **`PixelEditorTests`**: Regression that `PixelEditor` decodes encapsulated sources to native pixels before editing, emits Explicit VR Little Endian output, and preserves tag edits in the serialized file.

### Added — WADORetrieveConsoleFormatter (Shared WADO-RS / WADO-URI Retrieve Renderer)

- **`WADORetrieveConsoleFormatter`** (`Sources/DICOMWeb/WADORetrieveConsoleFormatter.swift`): Shared output renderer for WADO-RS / WADO-URI retrieve — verbose preamble blocks, per-mode status lines (metadata / rendered / thumbnail / frames / instances / WADO-URI result), and the metadata body (JSON pretty-printed + PS3.19 Native DICOM Model XML). Mirrors `QIDOResultFormatter` (query) and `UPSResultFormatter` (ups): a SINGLE formatter both sides call, so the `dicom-wado retrieve` CLI binary and DICOMStudio's in-app retrieve cannot produce different output.
  - `DICOMWado.swift` (`RetrieveCommand`) now delegates all verbose preamble, per-mode status, and metadata body output to `WADORetrieveConsoleFormatter` instead of hand-rolling inline strings.
  - `CLIWorkshopViewModel.swift` (WADO retrieve case) likewise delegates to the formatter; the mode-detection / inline-echo block is removed, and the verbose preamble is gated by `--verbose` on both sides identically.
  - `parseFrameNumbers` moved from `RetrieveCommand` into `WADORetrieveConsoleFormatter` (as a throwing method returning `[Int]`) with a companion `WADOFrameParseError` type; the CLI catches `WADOFrameParseError` and re-throws as `ValidationError`.

### Added — STOWResultFormatter (Shared WADO STOW-RS Upload Renderer)

- **`STOWResultFormatter`** (`Sources/DICOMWeb/STOWResultFormatter.swift`): Shared console renderer for `dicom-wado store` (STOW-RS) upload output — verbose pre-upload header, per-batch start/result lines, per-failure detail, and the always-printed final summary block. Both the `dicom-wado store` CLI path and DICOMStudio's in-app STOW upload call this single formatter, preventing output pipeline drift. The summary block format is a parity contract that `CLIParityWADOComparator.parseStore` anchors on.

### Added — UPS-RS Parity Harness: Full Operation Matrix, Global Subscribe, and get --format/--verbose

- **UPS write scenarios run out-of-the-box**: The parity harness no longer gates the full UPS operation matrix on a user-supplied Procedure Step Label. A `upsDefaultLabel` (`"CLI Parity Workitem"`) is substituted when the WADO panel's label is blank, so `ups-lifecycle`, `ups-lifecycle-complete`, `ups-lifecycle-cancel`, `ups-get`, `ups-create-attrs`, `ups-create-json`, and `ups-subscribe` always appear in the scenario list — matching how the harness already auto-picks the AE title and station filter.
- **Global UPS subscribe scenario** (`ups-subscribe-global`): New `runWADOUPSSubscribeGlobalScenario` runner exercises `ups --subscribe --aet <ae>` (no `--workitem-uid`) → `ups --unsubscribe --aet <ae>` — the GLOBAL round-trip that subscribes to ALL workitems' events. Reference uses `DICOMwebClient.subscribeToAllWorkitems` + `unsubscribeFromWorkitem(nil)`. Parity on round-trip outcome; servers that don't enable UPS subscription fail both sides identically (`failureAgreement`).
- **ups-get `--format` / `--verbose` variants**: Four `--format` flag variants (`table`, `json`, `csv`) plus a `--verbose` variant are now generated for the `ups-get` scenario. The flags are threaded through `studioParams["get-format"]` and `"get-verbose"` and appended at run time (after the Workitem UID is known), mirroring how the CLI appends them to the chained `ups --get <uid>` command.
- **Transaction UID flow corrected**: The UPS lifecycle runner (`runWADOUPSLifecycleScenario`) no longer pre-mints a Transaction UID and supplies it to the `--update --state IN_PROGRESS` claim. Instead it lets the server assign one, parses it from the CLI's IN PROGRESS output (`Transaction UID: …`), and reuses it for the terminal `COMPLETED`/`CANCELED` transition — exactly how a real operator works. The reference (`CLIParityNetworkReference.wadoUPSLifecycle`) likewise captures and reuses `claimResp.transactionUID`. When no UID is returned the terminal transition is skipped and recorded as not reached.
- **`wadoUPSSubscribeGlobal`** reference method added to `CLIParityNetworkReference`: calls `client.subscribeToAllWorkitems` + `client.unsubscribeFromWorkitem(nil)`; `createOK` is vacuously true (no workitem is created).

### Changed — C-GET and dicom-send Dry-Run Comparators Aligned with Shared Formatters

- **C-GET comparator** (`CLIParityRetrieveComparator`): The shared `NetworkConsole.cGetSummary` now emits exactly one terse line — `"✅ C-GET completed — N file(s) received"` on success or `"⚠️ C-GET completed but received 0 instances. …"` when nothing arrived — instead of a structured `C-GET Completed:` block with sub-operation counts. The parser now reads the received-file count from that line only; `completed`/`failed` are no longer parsed or compared for C-GET (they are unobservable in the CLI text). `canonical()` updated accordingly: C-GET compares `success + files`; C-MOVE still compares `completed + failed + warning`.
- **dicom-send dry-run comparator** (`CLIParitySendComparator`): The shared formatter's dry-run path (`NetworkConsole.sendHeader`) prints the gathered file count in the header's `"Files: N"` field rather than `"Found N file(s) to send"`. The parser now reads the first `"Files:"` line — the header count — rather than `"Found"`.

### Changed — UPS CLI Workshop: unsubscribe Operation and Simplified cliMapping

- **`unsubscribe` operation added** to the UPS parameter definition in `CLIWorkshopHelpers`: the operation picker now lists `search`, `get`, `create-workitem`, `change-state`, `subscribe`, `unsubscribe`. `--workitem-uid` is shown for `unsubscribe` as well as `subscribe` and `create-workitem`.
- **`--search` and `--create-workitem` moved to `cliMapping`**: Both flags are now emitted automatically when the matching operation tab is selected, removing the separate boolean-toggle `CLIParameterDefinition` entries that were previously needed. This mirrors the existing `--subscribe`/`--unsubscribe` mapping pattern.
- **No auto-pre-selection in Network mode**: Switching to Network mode no longer pre-selects the first network tool. The user explicitly picks which tools to include in the parity sweep.

### Fixed — HL7 ORM^O01 Field Placement for dcm4chee-arc MWL Create

- **HL7 ORM IPC segment + OBR field map corrected** (`ModalityWorklistService.buildHL7ORM`): The previous implementation wrote `scheduledStationAETitle` into `OBR-20`, which dcm4chee-arc's default inbound order stylesheet (`hl7-order2dcm.xsl`) reads as the **Scheduled Procedure Step ID** (`0040,0009`) — so a user's Station AET surfaced on the server as the SPS ID. Fixed in two ways:
  - **OBR path corrected**: rebuilt with an explicit index→value map (`hl7Segment(_:fields:)` helper) so the values land at their exact positions. OBR-18 = Accession Number, OBR-19 = Requested Procedure ID, OBR-20 = SPS ID, OBR-24 = Modality, OBR-27 4th component = SPS Start Date/Time.
  - **IPC segment added**: a dcm4che-private `IPC` (Imaging Procedure Control) segment is emitted after OBR so every SPS attribute has an unambiguous, configuration-independent slot — **IPC-7 = Station Name**, **IPC-9 = Scheduled Station AE Title** (the only ORM path that carries them). IPC-1/2/3 also supply Accession / Requested Procedure ID / Study Instance UID, matching the OBR fallback exactly.
  - `buildHL7ORM` promoted from `private` to `internal` to allow the new field-placement regression tests (`Tests/DICOMStudioTests/MWLCreateHL7ORMTests.swift`) to assert each value's exact HL7 position without requiring a live MLLP server.

### Fixed — WADO-URI Endpoint Resolution for dcm4chee5

- **`WADOURIClient.resolveURIEndpoint(_:)`** (new public static method): dcm4chee-arc 5.x serves WADO-URI (`?requestType=WADO`) from `/wado`, while the sibling WADO-RS/QIDO-RS endpoint lives at `/rs`. Supplying a WADO-RS base URL for a WADO-URI request returned HTTP 404. The resolver rewrites a trailing `/rs` path segment to `/wado`; all other base URLs are returned unchanged. Because the `dicom-wado` CLI, CLI Workshop, and parity reference all retrieve through this one client, they resolve identically and cannot drift.

### Fixed — dicom-mpps N-CREATE Status Guard

- **`dicom-mpps create --status` validation**: N-CREATE must always start the step `IN PROGRESS`; the previous code accepted `COMPLETED` or `DISCONTINUED` at creation, which servers reject (terminal states are reached only via N-SET). The `create` subcommand now validates that `--status` is `IN PROGRESS` and emits a clear `ValidationError` directing the user to `dicom-mpps update` for state transitions.

### Added — UPS-RS Result Formatter (Shared)

- **`UPSResultFormatter`** (`Sources/DICOMWeb/UPSResultFormatter.swift`): Shared output renderer for UPS-RS worklist search results — table, JSON (`UPSOutputFormat`), and CSV — used by both the `dicom-wado ups --search` CLI path and DICOMStudio's in-app UPS worklist search. Mirrors `QIDOResultFormatter` (QIDO-RS) and `DICOMQueryResultFormatter` (DIMSE): a single formatter both sides call so their output pipelines cannot drift.

### Added — CLI Workshop PACS Server Edit

- **Edit saved PACS server profiles**: The CLI Workshop saved-server list now supports in-place editing (`beginEditServer(id:)` / `saveEditedServer()` on `CLIWorkshopViewModel`). A new `showEditServerSheet` / `editingServerID` pair drives the edit sheet; saving re-applies the updated values when the edited profile is currently selected. Previously only add and delete were supported.

### Changed — NetworkConsole Shared Formatter Covers All Network CLIs

- **`NetworkConsole` (DICOMNetwork) now covers all DIMSE network tools**: `dicom-echo`, `dicom-mwl` (query), and `dicom-mpps` joined the shared formatter, completing the set started with `dicom-query / dicom-send / dicom-retrieve / dicom-qr / dicom-wado`. All human console output — headers, per-echo progress, summaries, verbose details — routes through one `NetworkConsole` method on both the CLI binary and the DICOMStudio CLI Workshop in-process path, making terminal-compare diff drift impossible by construction.
- **`dicom-send/ProgressReporter.swift` removed**: its logic was absorbed into `NetworkConsole`. Any callers that imported it directly must switch to the corresponding `NetworkConsole.*` methods.

### Added — Network CLI & DICOMweb Tests

- **`MWLCreateHL7ORMTests`** (`Tests/DICOMStudioTests/`): Regression tests asserting each value in the HL7 ORM^O01 message built by `ModalityWorklistService.buildHL7ORM` lands at its exact field position in both the OBR fallback path and the IPC segment, so the field-placement bug (`OBR-20` Station AET mismap) cannot silently return.
- **`UPSTests`** (`Tests/DICOMWebTests/`): Coverage for UPS-RS workitem query parsing and the new `UPSResultFormatter` output (table/JSON/CSV).
- **`WADOURIClientTests`** (`Tests/DICOMWebTests/`): Coverage for `WADOURIClient.resolveURIEndpoint` (no-op for `/wado`, rewrite for `/rs`, passthrough for other paths) and WADO-URI URL building.

### Added — Network Utility (Live Terminal Output)

- **Network Utility panel** (`NetworkUtilityView`, `NetworkUtilityViewModel`, `NetworkUtilityService`): Six-tab general-purpose network diagnostics tool surfaced as a new sidebar destination in DICOMStudio.
  - **Ping** — wraps `/sbin/ping`; live per-packet output streams into a terminal panel, parsed summary (min/avg/max RTT, packet loss) replaces it on completion.
  - **Port Scanner** — concurrent TCP probes via `NWConnection`; results append in arrival order for a live scan log, sorted by port number on completion.
  - **Traceroute** — wraps `/usr/sbin/traceroute`; each hop line streams as it resolves; stderr merged into stdout so the `traceroute to …` header appears at the top in real time.
  - **DNS Lookup** — wraps `/usr/bin/dig` per selected record type (A, AAAA, MX, TXT, NS, CNAME, SOA, PTR); each query echoes a `$ dig …` header then streams its answer block.
  - **Interfaces** — lists all network interfaces with IPv4/IPv6 addresses, MAC address, MTU, flags, and status badges.
  - **Netstat** — wraps `/usr/sbin/netstat`; streams TCP/UDP connections or routing table live; parsed counts (listening/established/routes) shown on completion.
- **Shared host input**: A single `sharedHost` field is shared by the Ping, Port Scanner, and Traceroute tabs — typing a host in any one of them pre-fills the others.
- **`AsyncStream<String>`-based live streaming** (`runStreamingProcess`): All five process-based tools share a single streaming process runner; stdout and stderr are merged into one pipe so output arrives in natural order, then yielded chunk-by-chunk via `AsyncStream`.
- **UTF-8 carry-over buffer**: A `var pending = Data()` accumulator in the `availableData` read loop ensures multibyte characters (IDN hostnames, TXT/PTR record content) are never split and silently dropped between reads.
- **Run-identity guard** (`streamGeneration` / `portScanGeneration`): Each run captures a generation counter; `onChunk` closures and completion assignments check `self.streamGeneration == gen` and discard stale deliveries from cancelled or superseded runs.
- **SIGKILL escalation**: Both the wall-clock watchdog and `ProcessKillBox.cancel()` send SIGTERM then escalate to SIGKILL after a 3-second grace period, preventing hung processes from blocking the UI indefinitely.
- **Watchdog liveness guard**: The watchdog `DispatchWorkItem` checks `proc.isRunning` before acting, preventing a process that exits naturally at the deadline from being mislabelled as timed out.

## [2.1.0] - 2026-05-21

DICOMStudio: J2K Test Bench, responsive layout, and imaging-first navigation.

## [2.0.0] - 2026-05-21

### Added — J2KSwift v3.2.0 Integration (Phases 1–9)

- **J2KSwift v3.2.0 codec stack** (`Sources/DICOMCore/J2KSwiftCodec.swift`, `HTJ2KCodec.swift`, `JP3DCodec.swift`): Replaces Apple ImageIO as the primary JPEG 2000 path on all platforms, enabling full Linux support via a pure-Swift scalar backend.
  - `J2KSwiftCodec`: Handles JPEG 2000 Lossless (`.90`), JPEG 2000 Lossy (`.91`), Part 2 Lossless (`.92`), Part 2 Lossy (`.93`) with 8/12/16-bit grayscale and RGB support.
  - `HTJ2KCodec`: Full HTJ2K Lossless (`.201`), HTJ2K RPCL Lossless (`.202`), HTJ2K Lossy (`.203`). Fast-path transcoder via `J2KTranscoder` (no pixel decode); 5.4× decode speedup over J2K on macOS arm64.
  - `JP3DCodec`: ISO/IEC 15444-10 volumetric encoding/decoding for multi-frame CT/MR/PET series with lossless, lossless-HTJ2K, and lossy modes.
- **JPIP streaming** (`Sources/DICOMKit/DICOMJPIPClient.swift`): Progressive 2D and 3D tile streaming for large remote studies; transfer syntaxes JPIP Referenced (`.94`) and JPIP Referenced Deflate (`.95`) registered.
  - `dicom-jpip` CLI tool with `fetch`, `uri`, `serve`, and `info` subcommands.
  - `DICOMFile.openVolumeProgressively(serverURL:sliceJPIPURIs:qualityLayers:)` API for huge CT/MR datasets.
- **JP3D volume bridge** (`Sources/DICOMKit/JP3DVolumeBridge.swift`): Converts multi-frame DICOM series ↔ `J2KVolume`; preserves `SliceLocation`, `ImagePositionPatient`, `SeriesInstanceUID`.
  - `JP3DVolumeDocument`: Encapsulated document SOP (private SOP `1.2.826.0.1.3680043.10.511.10`) with `.jp3d` payload + JSON sidecar; MIME type `application/x-jp3d`.
  - `DICOMFile.openVolume(from:)` / `openVolume(from:jpipServerURL:)` for unified volume access.
- **Hardware acceleration** (`CodecBackend` enum): Metal (Apple GPU), Accelerate (SIMD), scalar fallback; `CodecBackendProbe` selects best available at runtime. `--backend` flag on `dicom-compress` and `dicom-3d`.
- **`dicom-j2k` CLI tool** (8 subcommands): `info`, `validate`, `transcode`, `reduce`, `roi`, `benchmark`, `compare`, `completions`. 53 tests.
- **DICOMStudio enhancements**:
  - Progressive decoding with `ProgressiveDecodeModel` / `ProgressiveImageView` (AsyncStream-driven `.quarter → .half → .complete` state machine).
  - ROI decoding wired to pinch-zoom gestures.
  - JP3D MPR views (axial / sagittal / coronal) via `JP3DMPRViewModel` / `JP3DMPRView`.
  - JPIP loader with quality-layer slider.
- **Transfer syntaxes** added to registry, `DICOMValidator`, and `StorageSCP` presentation contexts: `.htj2kLossless`, `.htj2kRPCLLossless`, `.htj2kLossy`, `.jpip`, `.jpipDeflate`, `.jpeg2000Part2Lossless`, `.jpeg2000Part2`.
- **DICOMweb HTJ2K media types**: `image/jph` and `image/jphc` advertised in capability; WADO-RS accept headers updated.
- **`dicom-compress`**, **`dicom-convert`**, **`dicom-send`**, **`dicom-retrieve`**, **`dicom-viewer`**, **`dicom-info`**, **`dicom-validate`** extended for HTJ2K, JP3D, and JPIP transfer syntaxes.
- **Codec Inspector panel** in DICOMStudio: shows decoder name, backend (Metal/Accelerate/scalar), and decode timing.

### Fixed
- **JPEG 2000 16-bit rendering pipeline**: Fixed near-black output after conversion when preserving original bit depth
  - Normalized ImageIO-decoded 16-bit JPEG 2000 samples back to the DICOM `Bits Stored` range in `NativeJPEG2000Codec`
  - Preserved original metadata for JPEG 2000 and JPEG 2000 Lossless conversions (`BitsAllocated`, `BitsStored`, `HighBit`)
  - Verified CT-style datasets with VOI/Rescale tags render correctly after implicit VR → JPEG 2000 lossless transcoding

- **DICOM Studio metadata consistency**: Fixed transfer syntax source ordering in metadata loading
  - `MetadataViewModel` now prefers File Meta Information `(0002,0010)` before dataset fallback
  - Aligns metadata display behavior with converted-file transfer syntax as stored on disk

- **Test Infrastructure**: Fixed platform-specific test compilation errors
  - Added `#if canImport(CoreGraphics)` guards to ColorTransformTests for Apple platform-only APIs
  - Fixed DataElement initializer calls in ICCProfileAdvancedTests with missing length parameters
  - Fixed ambiguous type references in SegmentationParserTests
  - Tests now compile cleanly on Linux CI runners and Apple platforms

### Changed - DICOM Standard Edition Update
- **Updated DICOM standard reference from 2025e to 2026a**
  - The 2026a release is now the current edition available at https://www.dicomstandard.org/current/
  - Updated `dicomStandardEdition` constant to "2026a"
  - Updated all source code doc comments referencing DICOM PS3.x editions
  - Updated conformance statement, FAQ, contributing guide, and README
  - Key differences from 2025e to 2026a:
    - New supplements including CT Image Storage for Processing (Sup252)
    - Radiation Dose Structured Report (RDSR) informative annex (Sup245)
    - Enhanced DICOMweb services (Sup248, Sup228)
    - Data dictionary and controlled terminology updates
    - Correction proposals addressing encoding clarifications and CID additions
    - Improved sex and gender data representation
    - Frame Deflate transfer syntax enhancements for segmentation encoding

## [1.2.6] - 2026-02-07

### Added - Phase 5 CLI Tools Complete
- **dicom-mpps (v1.2.6)**: Modality Performed Procedure Step (MPPS) operations
  - N-CREATE operation for creating MPPS instances (procedure start)
  - N-SET operation for updating MPPS instances (procedure completion/discontinuation)
  - Support for IN PROGRESS, COMPLETED, and DISCONTINUED states
  - Referenced SOP instance tracking
  - MPPSService in DICOMNetwork module
  - Complete CLI tool with create and update subcommands
  - Documentation and README

## [1.2.5] - 2026-02-07

### Added - Phase 5 CLI Tools
- **dicom-mwl (v1.2.5)**: Modality Worklist Management
  - C-FIND query support for Modality Worklist Information Model
  - WorklistQueryKeys with flexible filtering (date, station AET, patient, modality)
  - JSON output support for automation
  - Verbose mode for detailed attribute display
  - ModalityWorklistService in DICOMNetwork module
  - Complete CLI tool with query subcommand
  - Documentation and README

## [1.0.0] - TBD

### Major Release - Production Ready

This is the first production-ready release of DICOMKit, a pure Swift DICOM toolkit for Apple platforms (iOS 17+, macOS 14+, visionOS 1+).

### Core Features (v0.1-v0.5)

#### DICOM File Support
- **Reading & Parsing**: Full support for reading DICOM files with comprehensive parsing
- **Transfer Syntaxes**: 
  - Explicit VR Little Endian (1.2.840.10008.1.2.1)
  - Implicit VR Little Endian (1.2.840.10008.1.2)
  - Explicit VR Big Endian (1.2.840.10008.1.2.2)
  - Deflated Explicit VR Little Endian (1.2.840.10008.1.2.1.99)
- **Data Types**: All standard DICOM Value Representations (VR) supported
- **Specialized Types**: Date, Time, DateTime, AgeString, PersonName, UniqueIdentifier, etc.
- **Writing**: Create and modify DICOM files with proper serialization
- **UID Generation**: Utilities for creating unique DICOM identifiers

#### Pixel Data Support (v0.3-v0.4)
- **Uncompressed Images**: Support for all standard photometric interpretations
  - MONOCHROME1, MONOCHROME2
  - RGB, PALETTE COLOR
- **Compressed Images**: Native codec support for:
  - JPEG Baseline (Process 1)
  - JPEG Extended (Process 2 & 4)
  - JPEG Lossless & JPEG Lossless SV1
  - JPEG 2000 (Lossless and Lossy)
  - RLE Lossless (pure Swift implementation)
- **Multi-frame Support**: Handle image sequences
- **CGImage Rendering**: Native Apple platform integration for display
- **Windowing**: Window Center/Width support for grayscale images

### Networking Features (v0.6-v0.7)

#### DICOM Network Protocol (DIMSE)
- **Core Infrastructure**: PDU handling, association management
- **C-ECHO**: Verification service for connectivity testing
- **C-FIND**: Query services for searching DICOM archives (Patient, Study, Series, Image levels)
- **C-MOVE & C-GET**: Retrieve services for fetching studies and images
- **C-STORE**: Storage services (SCU and SCP)
  - Single file and batch storage operations
  - Progress tracking with AsyncSequence
  - Storage SCP for receiving files
- **Storage Commitment**: N-ACTION based commitment verification
- **Advanced Features**:
  - TLS/SSL support for secure connections
  - Connection pooling and reuse
  - Association timeout configuration
  - Asynchronous API with Swift Concurrency

### DICOMweb Services (v0.8)

#### RESTful Web Services
- **WADO-RS**: Retrieve studies, series, and instances via HTTP
  - Multi-part response parsing
  - Metadata retrieval
  - Rendered image support
- **QIDO-RS**: Query services over HTTP
  - Study, series, and instance queries
  - Fuzzy matching support
  - Pagination with limit/offset
- **STOW-RS**: Store instances via HTTP multipart upload
  - Batch upload support
  - Progress tracking
- **UPS-RS**: Unified Procedure Step worklist services
  - Workitem creation, retrieval, updates
  - State transitions (SCHEDULED → IN PROGRESS → COMPLETED/CANCELED)
  - Subscription support for notifications
- **Authentication**: Bearer token and OAuth2 support
- **TLS**: Secure HTTPS connections with custom certificate validation

### Structured Reporting (v0.9)

#### SR Document Support
- **Core Infrastructure**: SR IOD parsing and document tree navigation
- **Document Types**: Support for all standard SR templates
  - Basic Text SR, Enhanced SR, Comprehensive SR
  - Key Object Selection
  - Measurement reports
  - CAD SR (Chest, Mammography)
- **Content Items**: All relationship types and value types supported
- **Coded Terminology**: SNOMED CT, LOINC, RadLex integration
- **Measurement Extraction**: Automated extraction of measurements and coordinates
- **Document Creation**: SR document builders with template validation
- **Template Support**: TID 1500 (Measurement Report), TID 1400 (Chest CAD SR), and more

### Advanced Features (v1.0.1-v1.0.13)

#### Presentation States
- **Grayscale Presentation State (GSPS)**: Annotations, LUT transformations, spatial transforms
- **Color Presentation State (CSPS)**: Color management, blending operations
- **Pseudo-Color**: Color lookup tables, hot/cold mapping

#### Hanging Protocols
- **Protocol Definition**: Screen layout and viewport configuration
- **Matching Logic**: Image set selection based on modality, anatomy, laterality
- **Display Sets**: Multi-image layout management

#### Radiation Therapy (RT)
- **RT Structure Set**: ROI contours, structure visualization, volume calculation
- **RT Plan**: Beam definitions, treatment machine setup
- **RT Dose**: Dose grids, isodose curves, DVH (Dose-Volume Histogram)

#### Segmentation
- **SEG IOD**: Binary and fractional segmentation support
- **Rendering**: Segment overlay with configurable colors
- **Builder API**: Create segmentation objects programmatically

#### Parametric Maps
- **Quantitative Imaging**: Float pixel data support
- **Real-World Value Mapping**: Physical units, SUV calculation
- **ICC Color Profiles**: Professional color management

#### International Support
- **Character Sets**: ISO 2022, ISO 8859, GB18030, GBK, EUC-KR, Shift_JIS, UTF-8
- **Private Tags**: Vendor-specific tag dictionaries (GE, Siemens, Philips)

#### Performance
- **Memory Optimization**: Efficient large file handling
- **SIMD Acceleration**: Vectorized operations for image processing
- **Lazy Loading**: On-demand pixel data decompression

#### Documentation
- **DocC Catalogs**: Comprehensive API documentation
- **Platform Guides**: iOS, macOS, visionOS integration guides
- **DICOM Conformance**: Formal conformance statement

### Example Applications (v1.0.14)

#### DICOMViewer iOS
- Multi-modality image viewer with gesture controls
- Windowing, pan, zoom, measurements
- Hanging protocol support
- Series browser with thumbnails
- Local file import and PACS integration

#### DICOMViewer macOS
- Removed from the repository.

#### Command-Line Tools
- **dicom-info**: Display DICOM file metadata
- **dicom-dump**: Detailed data element dump
- **dicom-convert**: Transfer syntax conversion
- **dicom-anon**: Anonymization tool
- **dicom-validate**: Conformance validation
- **dicom-query**: PACS query tool
- **dicom-send**: DICOM network send utility

#### Sample Code & Playgrounds
- 27 Xcode Playgrounds demonstrating library features
- Integration examples for iOS, macOS, visionOS
- Network protocol examples
- Image processing examples

### Technical Highlights

- **Pure Swift**: No Objective-C runtime dependencies
- **Swift 6 Compliant**: Full strict concurrency support
- **Platform Native**: Leverages Apple frameworks (ImageIO, CoreGraphics, RealityKit)
- **Modern API**: Swift Concurrency (async/await), Sendable types
- **Comprehensive Testing**: 1,920+ tests across core, networking, and applications
- **Medical Imaging Standards**: DICOM PS3.x compliant

### Platform Support

- **iOS**: 17.0 and later
- **macOS**: 14.0 and later  
- **visionOS**: 1.0 and later
- **Swift**: 6.0 and later

### Dependencies

- Swift Argument Parser 1.3+ (for CLI tools only)

### Installation

#### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Raster-Lab/DICOMKit.git", from: "1.0.0")
]
```

### Documentation

- [README.md](README.md) - Overview and quick start
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [MILESTONES.md](MILESTONES.md) - Development roadmap
- [Documentation/](Documentation/) - API documentation and guides

### Known Limitations

- Network integration tests require access to test PACS systems (documented for future)
- Transfer syntax conversion deferred to future versions
- Some advanced character sets deferred (ISO IR 100 extended)
- Store-and-forward networking features deferred

### Security & Privacy

- No known vulnerabilities in dependencies
- HIPAA considerations documented
- PHI (Protected Health Information) handling guidelines provided
- Secure network communication with TLS support

### Breaking Changes

This is the first stable release (v1.0.0). Future breaking changes will only occur in major version updates (2.0, 3.0, etc.).

### Contributors

Built with ❤️ by the DICOMKit team and contributors.

### License

See [LICENSE](LICENSE) file for details.

---

## Pre-release History

For detailed development history of pre-release versions (v0.1 - v0.9, v1.0.1 - v1.0.15), see [MILESTONES.md](MILESTONES.md).

### Notable Pre-release Versions

- **v0.1**: Core infrastructure, basic file parsing
- **v0.2**: Extended transfer syntax support
- **v0.3**: Pixel data access
- **v0.4**: Compressed pixel data
- **v0.5**: DICOM writing
- **v0.6**: Networking (Query/Retrieve)
- **v0.7**: Storage services
- **v0.8**: DICOMweb
- **v0.9**: Structured Reporting
- **v1.0.1-v1.0.13**: Advanced features
- **v1.0.14**: Example applications
- **v1.0.15**: Production release preparation

---

[1.0.0]: https://github.com/Raster-Lab/DICOMKit/releases/tag/v1.0.0
