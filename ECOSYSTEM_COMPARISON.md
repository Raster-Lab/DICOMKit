# DICOMKit vs. DCMTK / dcm4che / fo-dicom — Competitive Study

**Date:** 2026-08-10
**Method:** Public sources only — GitHub repos, release notes, `ANNOUNCE`/`CHANGES` files, commit
logs, issue titles. **No code was copied.** Where this document recommends implementing something
another toolkit has, the recommendation is a *capability* description; the implementation must be
derived from the DICOM standard (PS3.x) directly — clean room.

**Versions studied (as of August 2026):**

| Toolkit | Language | Latest release | Dictionary | License |
|---|---|---|---|---|
| **DCMTK** (OFFIS) | C++98/11 | **3.7.0** (2026-01-23; announce dated 2025-12-15) | DICOM 2025e (dev branch on 2026c) | BSD-ish (OFFIS) |
| **dcm4che 3** | Java 17+ | **5.35.0** (2026-08-06) | DICOM **2026c** | MPL/GPL/LGPL tri-license |
| **fo-dicom** | C# / .NET 6–9 | **5.2.6** (2026-03-30) | DICOM 2025d | MS-PL |
| **DICOMKit** (ours) | Swift 6.2 | v1.8.x line | DICOM **2026a** (5,036 elements) | MIT |

DICOMKit today: 8 libraries + 31 CLI tools + 2 GUI apps, ~805 Swift files / ~302k LOC, 2,180+ tests.

---

## 1. Where DICOMKit already stands out

These are genuine advantages, not consolation prizes:

1. **Memory safety by construction.** DCMTK's entire 2026 commit stream is dominated by
   memory-safety CVEs — 20+ fixes between June and July 2026 alone: OOB reads in the JPEG-LS
   decoder and RLE decoder, double-free of palette colour LUT data, buffer overflow in overlay
   conversion, OOB write in big-endian 8-bit LUT expansion, use-after-free in charset conversion,
   stack buffer overflow in Q/R Level handling, path traversal reading DICOMDIR, remote memory leak
   in N-GET-RQ handling. Cisco Talos is credited in the 3.7.0 announcement. A pure-Swift parser with
   bounds-checked collections and ARC eliminates *that entire class* by default. This is the single
   strongest marketing claim DICOMKit has, and it is defensible.
2. **Codec breadth.** DICOMKit handles 29 transfer syntaxes including JPEG XL (.110/.111/.112),
   HTJ2K (.201–.203), JPEG 2000 Part 2 (.92/.93), JP3D and encapsulated uncompressed
   (.1.2.5). (The JPIP syntaxes `.94`/`.95` are recognised but retrieval is non-functional —
   see `RESEARCH_ADOPTION_PLAN.md` F1; they are excluded from this claim.)
   dcm4che needed native OpenCV/weasis bindings for HTJ2K; fo-dicom still ships codecs as
   a **separate native package** (`fo-dicom.Codecs`) and its managed core cannot decode JPEG at all.
   DICOMKit decodes in-process, in Swift, with no native dependency for most codecs.
3. **Concurrency model.** Swift 6 strict concurrency with `Sendable` enforcement across the whole
   package is a compile-time guarantee none of the three has. DCMTK 3.6.9 had to *hand-optimise*
   `OFGlobal` for multi-threaded reads; fo-dicom 5.2.5 is still adding `IAsyncDicomService` and
   fixing `DicomServer` disposal leaks (#2046, #2009).
4. **GPU rendering.** A Metal render path (DICOMRenderKit) with byte-identical CPU parity is
   something none of the three ships. DCMTK's `dcmimgle`/`dcmimage` and fo-dicom's ImageSharp/
   SkiaSharp backends are all CPU.
5. **Shipped GUI.** DICOM Studio + CLI Workshop with shared-console parity is a product layer the
   three libraries deliberately don't have (they leave it to Weasis/Horos/MicroDicom).
6. **Tool count parity.** 31 CLI tools vs. DCMTK's ~60 and dcm4che's 57 — but ours cover the modern
   surface (DICOMweb, UPS-RS, JPIP, compression) that DCMTK's older tools don't.

---

## 2. Capability matrix

Legend: ✅ complete · 🟡 partial · ❌ absent

| Capability | DCMTK 3.7.0 | dcm4che 5.35 | fo-dicom 5.2.6 | **DICOMKit** |
|---|---|---|---|---|
| **Core parse/write** |
| Data dictionary currency | 2025e / 2026c dev | **2026c** | 2025d | 2026a |
| Implicit/Explicit VR, BE, deflate | ✅ | ✅ | ✅ | ✅ |
| 64-bit VRs (SV/UV/OV) | ✅ (3.7.0 helpers) | ✅ | ✅ | 🟡 verify |
| Streaming parse, no full accumulation | ✅ | ✅ (`DicomInputHandler`) | ✅ | 🟡 `ParsingOptions` |
| BulkDataURI on read/write | 🟡 (dcm2json 3.7.0) | ✅ | 🟡 | ❌ |
| Parser recursion-depth limit | ✅ (3.7.0 macros) | ✅ | ✅ (iterative, #1977) | ❌ **gap** |
| **Transfer syntaxes** |
| JPEG baseline/extended/lossless | ✅ | ✅ | 🟡 native pkg | ✅ |
| JPEG-LS | ✅ (`dcmjpls`) | ✅ | 🟡 native pkg | ✅ |
| JPEG 2000 Pt.1 | via plugin | ✅ | 🟡 native pkg | ✅ |
| JPEG 2000 Pt.2 (.92/.93) | ❌ | ❌ | ❌ | ✅ **lead** |
| HTJ2K (.201–.203) | ✅ (3.6.9) | ✅ (native reader) | ❌ | ✅ |
| JPEG XL (.110–.112) | ✅ (3.6.9) | ✅ (+XYB PI, 5.35) | ❌ | ✅ |
| JP3D (.94/.95) | ❌ | ❌ | ❌ | ✅ **lead** |
| Encapsulated uncompressed (.1.2.5) | ✅ | ✅ | ✅ | ✅ |
| **Deflated Image Frame Compression** | ✅ **new in 3.7.0** | ❌ | ❌ | ❌ **gap** |
| **Networking (DIMSE)** |
| C-ECHO/FIND/MOVE/GET/STORE SCU | ✅ | ✅ | ✅ | ✅ |
| Storage SCP | ✅ | ✅ | ✅ | ✅ |
| Q/R SCP with database | ✅ `dcmqrdb` | ✅ `dcmqrscp` | 🟡 sample | 🟡 `dicom-server` |
| **Relational queries** | ✅ | ✅ | 🟡 | ❌ **gap** |
| Modality Worklist **SCP** | ✅ `dcmwlm` | ✅ | 🟡 | ❌ **gap** |
| MPPS SCU / SCP | ✅ / ✅ | ✅ / ✅ | ✅ / 🟡 | ✅ / ❌ |
| Storage Commitment SCU/SCP | ✅ | ✅ `stgcmtscu` | ✅ | ✅ |
| Instance Availability Notification | 🟡 | ✅ `ianscp`/`ianscu` | ❌ | ❌ |
| UPS (Unified Procedure Step) DIMSE | ✅ | ✅ `upsscu` | 🟡 | 🟡 (REST only) |
| **IPv6** | ✅ **complete in 3.7.0** | ✅ | ✅ | ❌ **gap** |
| TLS incl. Q/R over TLS | ✅ (3.7.0) | ✅ | ✅ | ✅ |
| TLS Secure Transport **Profiles** | ✅ `--list-profiles` | ✅ | 🟡 | ❌ |
| Async ops window / negotiation | ✅ | ✅ | ✅ | 🟡 |
| **DICOMweb** |
| QIDO/WADO/STOW-RS client | 🟡 | ✅ | 🟡 3rd party | ✅ |
| DICOMweb **server** | ❌ | ✅ (in dcm4chee) | ❌ | ✅ **lead** |
| UPS-RS + WebSocket events | ❌ | 🟡 | ❌ | ✅ **lead** |
| **Objects / IODs** |
| Structured Reporting | ✅ `dcmsr` | ✅ | ✅ | ✅ |
| Segmentation | ✅ `dcmseg` (+ **Labelmap**, 3.7.0) | ✅ | 🟡 | 🟡 (no Labelmap) |
| Parametric Map | ✅ `dcmpmap` | ✅ | ❌ | ✅ |
| RT (plan/dose/struct) | ✅ `dcmrt` | ✅ | 🟡 | ✅ |
| **Tractography** | ✅ `dcmtract` | 🟡 | ❌ | ❌ |
| **Enhanced multi-frame ↔ legacy** | 🟡 | ✅ `emf2sf` + `MultiframeExtractor` | ❌ | ❌ **gap** |
| **Functional Groups framework** | ✅ `dcmfg` | ✅ | ❌ | ❌ **gap** |
| **IOD framework / generic validation** | ✅ `dcmiod` | ✅ `dcmvalidate` | 🟡 | 🟡 (7 hand-written IODs) |
| Presentation States | ✅ `dcmpstat` | ✅ | 🟡 | ✅ |
| Hanging Protocols | 🟡 | 🟡 | ❌ | ✅ **lead** |
| Waveforms / ECG | 🟡 | ✅ | 🟡 | ✅ |
| **Security / compliance** |
| **Digital Signatures (PS3.15)** | ✅ `dcmsign` | 🟡 | ❌ | ❌ **gap** |
| **PS3.15 Annex E de-identification profiles** | 🟡 | ✅ `dcm4che-deident` | 🟡 | ❌ **big gap** |
| Audit trail (DICOM Supp 95 / RFC 5424 syslog) | 🟡 | ✅ `dcm4che-audit` | ❌ | 🟡 `AuditLogger` |
| **HL7 v2 / integration** |
| HL7 v2 parse/send/receive | ❌ | ✅ `dcm4che-hl7` | ❌ | ❌ |
| IHE actors (PIX/PDQ/XDS-I) | ❌ | ✅ | ❌ | ❌ |
| **Format conversion** |
| DICOM → JSON / XML | ✅ | ✅ | ✅ | ✅ |
| **JSON → DICOM** | ✅ **new in 3.7.0** `json2dcm` | ✅ `json2dcm` | ✅ | ❌ **gap** |
| XML → DICOM | ✅ `xml2dcm` | ✅ | ✅ | ❌ **gap** |
| **DICOMDIR icon image sequence** | ✅ | ✅ | ✅ **new in 5.2.6** | ❌ |

---

## 3. What each project is currently investing in — and what that tells us

### DCMTK — hardening and standard currency
The 3.7.0 cycle plus the post-release commit stream reads as: **(a) fix every fuzzer-found memory
bug, (b) track the standard, (c) modernise the tool surface.** Concretely: Deflated Image Frame
Compression TS, Labelmap Segmentation, `dcmencap`/`dcmdecap` replacing the five one-off
encapsulation tools, `json2dcm`, BulkDataURI emission from `dcm2json`, complete IPv6, Q/R over TLS,
runtime-settable Implementation Class UID, and `--list-profiles` for TLS security profiles.

**Lesson for us:** the *deprecate-and-consolidate* move (`pdf2dcm`+`cda2dcm`+`stl2dcm` → `dcmencap`)
is exactly the direction our shared-console refactors already go. And their security stream is a
checklist of inputs we should be fuzzing.

### dcm4che — dictionary currency, codec correctness, enterprise plumbing
Every release bumps the element dictionary (2024a → 2026c across the studied window). The bug list
is overwhelmingly **pixel-pipeline correctness**: VOI LUT descriptor wrong for unsigned pixel data,
1/0 windowing of 8-bit images producing a single-value LUT, very small RescaleSlope causing an
OOM-sized LUT, JPEG XL lossless artefacts when BitsStored < BitsAllocated, multi-fragment frames in
multi-frame images failing to decode, EVRLE→IVRLE transcode failures, ISO 2022 charset not resetting
after a delimiter. Plus a whole enterprise tier we don't have at all: HL7 v2, IHE, audit/syslog,
Keycloak, XDS-I, LDAP-based device configuration.

**Lesson for us:** that bug list is a **ready-made test matrix**. Several of those are conditions our
round-trip oracle would not currently catch, and at least two (tiny RescaleSlope → huge LUT;
BitsStored < BitsAllocated in JXL) plausibly affect our code paths today.

### fo-dicom — API ergonomics and server lifecycle
5.2.x is mostly rendering fixes, DI/`IConfiguration` integration, `INetworkMetricsCollector`,
`IAsyncDicomService`, port-0 binding, deep-clone correctness, and stack-overflow-proofing
`DicomDirectory` by making recursion iterative. Its imaging layer is pluggable
(`WinForms`/`ImageSharp`/`SkiaSharp` packages).

**Lesson for us:** the **metrics-collector hook** and **pluggable imaging backend** are cheap,
high-value API patterns. And `DicomDirectory` recursion → iteration is precisely the hardening we
are missing (see §4.1).

---

## 4. Prioritised gaps in DICOMKit

### P0 — Correctness/safety issues that are live risks today

**4.1 No recursion-depth or allocation bound in the parser.**
`Sources/DICOMKit/DICOMParser.swift` has no depth counter and no upper bound on
attacker-controlled element lengths. Swift saves us from OOB reads, but **not** from a stack
overflow on deeply nested sequences (fo-dicom shipped exactly this fix in 5.2.3, #1977) or from an
allocation DoS when a length field says 4 GB. `ParsingOptions` exposes `maxElements` but no
`maxSequenceDepth` / `maxElementLength` / `maxTotalAllocation`.
→ *Action:* add depth + allocation ceilings to `ParsingOptions`, default them conservatively, and
surface a `DICOMError.limitExceeded`. Mirror in `PDUDecoder`.

**4.2 The anonymiser is not a PS3.15 profile.**
`AnonymizationProfile.basic` removes **14 tags**. PS3.15 Table E.1-1 (Basic Application Level
Confidentiality Profile) lists roughly **530 attributes**, with per-attribute actions (D/Z/X/K/C/U)
and named options (Retain Longitudinal Temporal, Retain Device Identity, Clean Descriptors, Clean
Graphics, Retain UIDs, Retain Patient Characteristics). We also do not recurse into sequences to
strip nested identifiers, do not handle private tags per the safe-private list, and do not touch
burned-in pixel annotations.
→ This is the **single largest conformance gap** and the one most likely to cause a real PHI leak.
It is also pure clean-room work: the table is normative text in PS3.15, not anyone's source code.
→ *Action:* generate an action table from PS3.15 Annex E, implement the D/Z/X/K/C/U action engine
with recursive sequence descent, add the standard option toggles, and record
`(0012,0063) De-identification Method` + `(0012,0064)` code sequence. Add
`(0028,0301) Burned In Annotation` detection as a warning.

**4.3 README limitations table is stale and understates the product.**
It claims "JPEG-LS not supported ❌ Not planned" and "Storage Commitment not implemented" — both are
implemented (`JPEGLSCodec.swift`, `StorageCommitmentSCP.swift`). It says "7+ transfer syntaxes"
when there are 29. Fix before anyone evaluates us on it.

### P1 — Conformance gaps that block real deployments

**4.4 IPv6.** No `AF_INET6` anywhere in `DICOMNetwork`. DCMTK just declared IPv6 support "complete"
in 3.7.0 for both requestor and acceptor with an IPv4/IPv6/dual-stack switch. Hospital networks are
increasingly dual-stack. Swift `Network.framework` makes this comparatively easy.

**4.5 Relational Query/Retrieve.** README acknowledges this. Modern PACS and IHE profiles expect
relational C-FIND; extended negotiation for relational support is a small PDU-level addition plus
query planning in `QueryService`/`ServerSession`.

**4.6 Modality Worklist SCP.** We have an MWL *client* and `dicom-mwl`, but no SCP. Every other
toolkit has one. Combined with an MPPS SCP this makes DICOMKit deployable as a modality simulator —
a genuinely useful product, and a natural companion to `dicom-printscp`.

**4.7 JSON→DICOM and XML→DICOM.** We have `dicom-json` and `dicom-xml` in the outbound direction
only. Both DCMTK (as of 3.7.0) and dcm4che have `json2dcm`/`xml2dcm`. Round-tripping is table stakes
and directly strengthens our round-trip test suite. Low effort — we already own
`DICOMJSONDecoder`/`DICOMXMLDecoder` in DICOMWeb; the missing piece is dataset *construction* and a
CLI.

**4.8 Enhanced multi-frame ↔ legacy conversion.** dcm4che's `emf2sf` / `MultiframeExtractor` splits
Enhanced CT/MR/PET into legacy single-frame instances, distributing per-frame functional group
values into top-level attributes. Ours (`FrameSplitter`) splits frames but does not resolve
functional groups. This is the #1 interop request in real deployments because so many viewers still
can't read Enhanced objects.

**4.9 A real Functional Groups framework.** We reference `SharedFunctionalGroups`/
`PerFrameFunctionalGroups` ad hoc in Segmentation/ParametricMap/FrameMerger. DCMTK has a dedicated
`dcmfg` module. A single typed accessor layer ("give me the Pixel Measures for frame N, falling back
shared→per-frame") would de-duplicate four call sites and unblock 4.8.

### P2 — Strategic / differentiating

**4.10 Deflated Image Frame Compression Transfer Syntax.** Brand new in DICOM and *only* DCMTK
supports it (3.7.0). Implementing it now would make DICOMKit the second toolkit in the world with
it — a strong conformance headline given we already lead on Part 2 / JP3D / JXL.

**4.11 Digital Signatures (PS3.15 Annex C/D).** DCMTK's `dcmsign` is unique among the three in being
complete. With CryptoKit/Security.framework this is very achievable in Swift and matters for
teleradiology and legal-record use cases.

**4.12 Labelmap Segmentation Storage.** New in DICOM 2025; added to `dcmseg` in 3.7.0. Small
increment on our existing `SegmentationBuilder`/`Parser`.

**4.13 Generic IOD/module validation framework.** Our validator hardcodes 7 IODs in a `switch`.
DCMTK's `dcmiod` and dcm4che's `dcmvalidate` are data-driven from module tables. Encoding PS3.3
module/attribute tables as a resource (as we already do for the element dictionary — a 5,036-line
bundled `.txt`, which is a good pattern) would take us from 7 IODs to *all* of them.

**4.14 Dictionary currency + automation.** We're on 2026a; dcm4che is on 2026c. Both DCMTK and
dcm4che bump the dictionary essentially every release. → Add a `Scripts/` generator that regenerates
`DataElementDictionary.txt`, `UIDDictionary`, and `StorageSOPClasses` from the published PS3.6 XML,
and a scheduled CI job that opens a PR when NEMA publishes a new edition.

**4.15 Enterprise integration tier (HL7 v2, IHE, syslog audit).** dcm4che's real moat. Probably out
of scope for an Apple-platform SDK, but an **RFC 5424 syslog audit emitter** conforming to DICOM
Supplement 95 is a small, self-contained addition to our existing `AuditLogger` and is a hard
requirement in many procurement checklists.

### P3 — API/ergonomics borrowings (cheap, high leverage)

- **Metrics hook** — a `DICOMNetworkMetrics` protocol invoked by `Association`/`StorageSCP`
  (fo-dicom's `INetworkMetricsCollector`, 5.2.5). We have `ServerStatistics` but it isn't pluggable.
- **Port 0 binding** — let the OS assign a port for SCPs; makes tests hermetic (fo-dicom #1990).
- **Runtime Implementation Class UID / Version Name** — settable per-file-write and per-association
  (DCMTK 3.7.0). We hardcode ours; vendors integrating DICOMKit will want their own.
- **DICOMDIR icon image sequence** generation (fo-dicom 5.2.6, `IIconGenerator`).
- **TLS profile enumeration** — expose the supported DICOM Secure Transport Connection Profiles and
  a `--list-profiles` flag (DCMTK 3.6.9).
- **Pluggable imaging backend protocol** — we effectively have this (CPU/Metal); formalising it as a
  public protocol (fo-dicom's ImageSharp/SkiaSharp split) makes DICOMRenderKit substitutable.

---

## 5. Test matrix to steal (behaviour, not code)

Each of these is a real bug that shipped in a mature toolkit. Add each as a round-trip oracle case:

| Condition | Source | Our exposure |
|---|---|---|
| VOI LUT Descriptor for **unsigned** pixel data | dcm4che #1521 | `WindowLUT`, `determineWindowSettings` |
| Window width < 1 → must apply LINEAR_EXACT | fo-dicom #1905 | `WindowSettings` |
| 1/0 windowing of 8-bit image → single-value LUT | dcm4che #1513 | `WindowLUT` |
| Very small RescaleSlope → enormous LUT allocation | dcm4che #1499 | **allocation DoS, likely live** |
| Modality LUT Sequence present → must ignore slope/intercept | fo-dicom #1986 | `PixelDataRenderer` |
| Empty Pixel Spacing tag present | fo-dicom #2043 | volume/measure paths |
| Empty rescale info → must still render | fo-dicom #1975 | `PixelDataRenderer` |
| Multi-**fragment** frames in a multi-frame image | dcm4che #1598 | `EncapsulatedPixelData` |
| JXL lossless with BitsStored < BitsAllocated (=16) | dcm4che #1540 | `JXLCodec` |
| Photometric Interpretation **XYB** in JPEG XL | dcm4che #1603 | `PhotometricInterpretation` |
| J2K with YCC 4:2:2 / 4:2:0 subsampling | dcm4che #1405 | `J2KSwiftCodec` |
| EVRLE → IVRLE transcode | dcm4che #1497 | `TransferSyntaxConverter` |
| ISO 2022 charset not reset after delimiter | dcm4che #1503 | `CharacterSetHandler` |
| VR UN group length mis-parsed | fo-dicom #1941 | `DICOMParser` |
| File with trailing delimiter items | fo-dicom #1958 | `DICOMParser` |
| Deeply nested sequences (stack overflow) | fo-dicom #1977 | **`DICOMParser` — no guard** |
| Path traversal via DICOMDIR referenced file IDs | DCMTK 2026-07-03 | `DICOMDIRReader` |
| Overflow in numeric VR value parsing | DCMTK 2026-07-03 | `DICOMDecimalString`, `DICOMIntegerString` |
| Integer overflow in RLE encoder size check | DCMTK 2026-07-03 | `RLECodec` |
| Duplicate User Identity sub-items in A-ASSOCIATE | DCMTK 2026-06-19 | `PDUDecoder` |
| Timezone Offset From UTC on **nested** datasets | dcm4che #1546 | `DICOMDateTime` |

**Also: start fuzzing.** DCMTK's entire security posture improved because Talos and OSS-Fuzz pointed
a fuzzer at it. `swift-testing` + libFuzzer (or just a corpus-driven property test over the round-trip
corpus with random byte mutation) over `DICOMParser.parse`, `PDUDecoder.decode`, and each codec's
`decode` would be a weekend of work and would likely find several of the above immediately.

---

## 6. Recommended sequencing

**Now (unblocks credibility):**
1. Parser hardening — depth, length, and total-allocation limits (§4.1)
2. Fuzz harness over parser + PDU decoder + codecs (§5)
3. PS3.15 Annex E de-identification engine (§4.2)
4. Fix the README limitations table (§4.3)

**Next quarter (conformance):**
5. JSON→DICOM / XML→DICOM (§4.7) — also strengthens round-trip tests
6. Functional Groups framework (§4.9), then Enhanced↔legacy conversion (§4.8)
7. IPv6 (§4.4), relational Q/R (§4.5), MWL SCP (§4.6)
8. Dictionary regeneration script + scheduled CI PR (§4.14)

**Differentiators (after the above):**
9. Deflated Image Frame Compression (§4.10) — be second in the world
10. Digital signatures (§4.11)
11. Data-driven IOD validation from PS3.3 module tables (§4.13)
12. P3 ergonomics batch (§4.15, §P3) — metrics hook, port 0, runtime Implementation UID

---

## Sources

- [DCMTK 3.7.0 ANNOUNCE](https://raw.githubusercontent.com/DCMTK/dcmtk/DCMTK-3.7.0/ANNOUNCE)
- [DCMTK repository (modules, commit log)](https://github.com/DCMTK/dcmtk)
- [DCMTK 3.6.9 release announcement (J. Riesmeier)](https://blog.jriesmeier.com/2024/12/dcmtk-3-6-9-available-for-public-release/)
- [DCMTK project news](https://support.dcmtk.org/redmine/projects/dcmtk/news)
- [dcm4che releases](https://github.com/dcm4che/dcm4che/releases)
- [dcm4che repository (module and tool layout)](https://github.com/dcm4che/dcm4che)
- [fo-dicom releases](https://github.com/fo-dicom/fo-dicom/releases)
- [fo-dicom repository](https://github.com/fo-dicom/fo-dicom)
