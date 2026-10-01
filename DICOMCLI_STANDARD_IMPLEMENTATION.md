# `dicom-*` CLI tools — DICOM 2026a verification

Scope: the 42 `dicom-*` executable targets under `Sources/dicom-*` (80 Swift files). Target edition
**DICOM 2026a**. Method: ["Verification method (reuse for every module)"](DICOMCORE_STANDARD_IMPLEMENTATION.md#verification-method-reuse-for-every-module),
applied to the tools' *surface*: every tool is an adapter over a DICOMKit engine that was verified in
[DICOMKIT_STANDARD_IMPLEMENTATION.md](DICOMKIT_STANDARD_IMPLEMENTATION.md), so what is checked here is the
**parameter contract** — the options, flags and arguments the tool accepts (input contract) and the JSON
keys, XML elements, printed labels, status texts and exit codes it emits (output contract) — against the
2026a tables that define those vocabularies. Extraction and diff: [Scripts/diff_cli.py](Scripts/diff_cli.py)
(code side by regex over `@Argument` / `@Option` / `@Flag`, help strings, defaults, enum raw values, JSON
keys, printed labels and exit codes; standard side from the DocBook tables named in each row; the
DICOMKit literal checks of `diff_kit.py` / `diff_web.py` are re-run over every tool's sources).

Started 2026-10-01. Status: **in progress** — see the Summary table.

Groups (one section each, worked in this order):

| Group | Standard parts | Tools |
|---|---|---|
| G1 Network | PS3.7, PS3.8, PS3.4, PS3.18 | dicom-echo, dicom-send, dicom-query, dicom-qr, dicom-retrieve, dicom-mwl, dicom-mpps, dicom-server, dicom-gateway, dicom-print, dicom-printscp, dicom-wado, dicom-jpip, dicom-cloud |
| G2 File and media | PS3.5, PS3.10, PS3.11, PS3.18 Annex F, PS3.19 Annex A | dicom-dump, dicom-info, dicom-tags, dicom-json, dicom-xml, dicom-dcmdir, dicom-uid, dicom-validate, dicom-diff, dicom-split, dicom-merge, dicom-study, dicom-archive, dicom-export |
| G3 Encoding and pixel | PS3.5, PS3.3, PS3.15 | dicom-compress, dicom-convert, dicom-j2k, dicom-image, dicom-pixedit, dicom-video, dicom-pdf, dicom-anon |
| G4 Derived objects | PS3.3, PS3.16 | dicom-ai, dicom-report, dicom-measure, dicom-3d, dicom-viewer, dicom-script |

Surface extracted by `diff_cli.py --list-surface` on 2026-10-01: 1,042 options/flags/arguments across the
42 tools (9 to 78 per tool).

---

## Summary

| Bucket | Count | Meaning | Status |
|---|---|---|---|
| Carried rows | 4 | D9, D29, D44, D56 — CLI halves of findings opened by earlier reports | ✅ D9, D29, D44, D56 CLI halves closed 2026-10-01 (D9, D29, D56 DICOMStudio halves remain open) |
| G1 Network | 14 tools | input/output contract vs PS3.7 Annex C, PS3.4 C.4/C.6/K/F/H, PS3.18 | ⏳ 7 of 14 done (echo, send, query, retrieve, qr, mwl, mpps) |
| G2 File and media | 14 tools | contract vs PS3.5, PS3.10, PS3.11 Annex H, PS3.18 F, PS3.19 A | ⏳ not started |
| G3 Encoding and pixel | 8 tools | contract vs PS3.5 8.2 / 10, PS3.6 A-1, PS3.3 C.7.6.3 / C.11.2, PS3.15 E | ⏳ not started |
| G4 Derived objects | 6 tools | contract vs PS3.3 C.8.20 / C.17, PS3.16 TIDs and CIDs | ⏳ not started |

---

## Progress log

| Date | Item | What was compared | What changed | Tests |
|---|---|---|---|---|
| 2026-10-01 | D9, D29 | dicom-compress help rows vs PS3.6 Table A-1 (24 match, 1 fixed); dicom-dcmdir profile literals vs PS3.11 Tables A.1-1 … N.1-1 (64 identifiers) | `dfc929c`, `ca2bd29`; D70 opened for DICOMKit; P-DCMDIR-PROFILE | no test target for either tool; binaries built and run; markers pass |
| 2026-10-01 | D44 | dicom-ai segmentation writer vs PS3.3 Tables C.8.20-2 (16 rows), C.8.20-4 (14 rows), A.51-1; CID 7150 / 7151 | `3fe88bd`; D71 opened for DICOMKit | `swift test --filter SegmentationOutputTests`: 5 passed |
| 2026-10-01 | D56 | dicom-video surface (42 declarations, no standard literals) and the new option vs PS3.16 CID 3000 (6 rows) and PS3.3 Table C.7-13 | `8eebfab`; P-AUDIO-SOURCE-PER-TRACK | `swift test --filter AudioChannelSourceOptionTests`: 10 passed; markers pass |
| 2026-10-01 | G1 echo, send, query | echo: PS3.7 9.1.5.1.4, PS3.5 VR AE, PS3.8 9.1.1 (9 options, all plumbing); send: PS3.4 Table B.2-1 (7 rows), PS3.7 Table 9.3-1 priority (matched 2, plumbing 11); query: PS3.4 Tables C.6.1-1/C.6.2-1, C.6-1/-3/-4/-5, C.2.2.2.4/5 (matched 9, wrong 1 fixed, extra 1 documented, plumbing 8) | `0c845da`, `0efff87`, `f24869c`, `695d961`: dicom-send no longer counts A7xx/A9xx/Cxxx C-STORE failures as success (exit 1, retried); `--level image` accepted, IMAGE named in help; README JSON/CSV/exit-code docs corrected; P-QUERY-JSON, P-QUERY-COLUMNS, P-SEND-SUMMARY; D72–D75 opened for DICOMNetwork | `dicom-queryTests` 7, `dicom-sendTests` 6: 13/13 pass; markers 5/5 |
| 2026-10-01 | G1 retrieve, qr | retrieve: PS3.4 Tables C.4-2/C.4-3 (17 status rows generated), PS3.7 Tables 9.3-7/9.3-10, C.6.1-1 levels, PS3.6 A-1 SOP Class names (matched 6, plumbing 10, 2 n/a); qr: PS3.4 C.6 key tables, C.2.2.2.5 range forms (matched 10, extra 1, plumbing 17) | `1f853e8`, `0b5a61a`, `dd74be3`: final status worded per the tables, counters under PS3.7 names, `--hierarchical` help corrected; dicom-qr `query`/`resume` now exit 1 on failed studies, `resume --timeout` added; P-QR-STATUS-TEXT, P-RETRIEVE-PRIORITY, P-RETRIEVE-EXTNEG, P-QR-STATE-MODALITIES, P-QR-PARALLEL; D76–D78 opened for DICOMNetwork | `QueryRetrieveCLIStandardTests` 6 passed; markers 5/5 |
| 2026-10-01 | G1 mwl, mpps | PS3.4 Tables K.6-1 (139 rows), K.6-1a, K.4-1, F.7.2-1 (130 rows), F.7.2-2; PS3.3 C.4-10, C.4-14, C.2-3; PS3.7 Annex C (27 codes); PS3.16 CID 9300/9301. mwl matched 10, wrong 1, plumbing 7; mpps matched 23, wrong 2, missing 1, plumbing 8 | `f2db8f9`: `--sps-status` help listed PPS words, now the 5 SPS Defined Terms; `416de5a`: CID 9300 examples had wrong meanings, `create` requires `--modality`, validates sex/birth date, `update --image-uid` no longer silently dropped, N-CREATE/N-SET statuses named per Annex C; P-MWL-JSON-KEYS, P-MPPS-STRICT; D79–D88 | `MWLMPPSCLIEndToEndTests` 16/16; MPPSDataSetConformanceTests 27 and WorklistQueryKeysTests 31 still pass |
| 2026-10-01 | Scaffold | `Scripts/diff_cli.py`: surface extractor (1,042 options), generic DICOMKit literal checks re-run per tool, transfer-syntax-name and documented-default checks; this report | — | — |

---

## Priority action list (P-items — need the owner's approval)

| Item | What | Status | Evidence |
|---|---|---|---|
| P-DCMDIR-PROFILE | `dicom-dcmdir --profile` still accepts the non-standard spellings STD-GEN-DVD, STD-GEN-USB, STD-GEN-SEC, STD-CTMR-XXXX, STD-US-XXXX (mapped by `DICOMDIRProfile.legacyAliases`, already deprecated in DICOMCore). Proposal: keep accepting them, print a one-line stderr deprecation note naming the identifier used, remove in the next major. `DcmdirRoundTripTests.swift:459` and `DICOMDcmdirTests.swift:312` still use the deprecated constants | PEND | PS3.11 2026a Tables H.1-1, J.1-1 |
| P-QUERY-JSON | `dicom-query --format json` emits a tool-specific summary object, not the PS3.18 F.2 DICOM JSON Model. Proposal: additive `--format dicom-json` (keyword/tag keys, `vr`, `Value`, PN component objects) through the shared `QueryOutputFormat` type, keeping `json` as is | PEND | PS3.18 2026a F.2 |
| P-QUERY-COLUMNS | table/CSV column labels of dicom-query are tool wording, not PS3.6 attribute names; changing them touches the shared formatter and the Studio parity suite | PEND | PS3.6 2026a Table 6-1 |
| P-SEND-SUMMARY | `NetworkConsole.sendSummary` (DICOMKit shared console) has no warning count; dicom-send now tallies B000/B006/B007 itself. Proposal: add the count to the shared summary so the Workshop shows it too | PEND | PS3.4 2026a Table B.2-1 |
| P-QR-STATUS-TEXT | `RetrieveStatusText.swift` (dicom-retrieve, 17 rows generated from PS3.4 Tables C.4-2/C.4-3) duplicates wording that belongs in DICOMNetwork's `DIMSEStatus.description` so the Studio console matches. Proposal: hoist the table into DICOMNetwork | PEND | PS3.4 2026a Tables C.4-2, C.4-3 |
| P-RETRIEVE-PRIORITY | dicom-retrieve has no `--priority`; MEDIUM is hard-coded in the engine. Proposal: engine API for C-MOVE/C-GET Priority (0000,0700) then an additive option | PEND | PS3.7 2026a Table 9.3-7 / 9.3-10 |
| P-RETRIEVE-EXTNEG | no option for Q/R extended negotiation (relational retrieval); needs engine API | PEND | PS3.4 2026a C.5.1 |
| P-QR-STATE-MODALITIES | `QRSessionState.swift:25` state JSON key `modality` stores Modality (0008,0060) where the study-level value is Modalities in Study (0008,0061); a shared JSON key rename | PEND | PS3.4 2026a Table C.6-5 |
| P-QR-PARALLEL | `dicom-qr --parallel` is parsed but never read. Proposal: implement or deprecate | PEND | — |
| P-MWL-JSON-KEYS | 10 of the 38 `dicom-mwl --json` keys are not PS3.6 keywords; the JSON comes from the shared `NetworkConsole.mwlJSON` (also the Studio MWL panel). Proposal: emit PS3.6 keywords, old keys kept for one release | PEND | PS3.6 2026a Table 6-1 |
| P-MPPS-STRICT | `dicom-mpps create` now refuses a missing `--modality` (Type 1, Table F.7.2-1) and an invalid `--patient-sex` / `--patient-birth-date`; `update` refuses `--image-uid` without study/series. Owner choice: keep as errors (done) or downgrade to warnings | PEND (decision only) | PS3.4 2026a Table F.7.2-1; PS3.3 Table C.2-3 |
| P-AUDIO-SOURCE-PER-TRACK | `VideoWorkflow.Metadata.audioChannelSource` (DICOMKit, `VideoWorkflow.swift:133`, `audioChannels(for:metadata:)`) is one Source applied to every audio track, so `--audio-channel-source` is single-valued. Proposal: add `audioChannelSources: [VideoAudioChannel.Source]?` to `Metadata` (one per track) and let the CLI option repeat | PEND | PS3.3 2026a Table C.7-13 (one (003A,0300) Item per channel, each with its own (003A,0208)) |

---

## Deferred findings

### Rows carried into this module (close first)

| ID | Module | Where | Problem | Standard | Severity | Status |
|---|---|---|---|---|---|---|
| D9 | dicom-compress (+ DICOMStudio) | `Sources/dicom-compress/main.swift:63`; `J2KTestBenchModels.swift:123,392` | .4.110 called "JPEG XL Lossless Only"; PS3.6 name is "JPEG XL Lossless". The 25 codec help rows were resolved alias → UID → Table A-1 name by script: 24 match, 1 fixed | PS3.6 2026a Table A-1; PS3.5 Table 8.2.1-1 | Low: text | ✅ CLI half closed 2026-10-01 (`dfc929c`); DICOMStudio half open |
| D29 | dicom-dcmdir (+ DICOMStudio) | `Sources/dicom-dcmdir/main.swift:59,104`; `CLIWorkshopViewModel.swift:1730`, `CLIWorkshopHelpers.swift:3128` | `--profile` help/error listed STD-GEN-DVD / STD-GEN-USB (Annex H/J family headings, not identifiers). 64 identifiers extracted from PS3.11 Tables A.1-1 … N.1-1; help, error list and verbose summary now print the resolved identifier (`DICOMDIRProfile.allStandard`) | PS3.11 2026a Annexes H, J (Tables H.1-1, J.1-1) | Low: text | ✅ CLI half closed 2026-10-01 (`ca2bd29`); DICOMStudio half open |
| D44 | dicom-ai | `AIDICOMOutputGenerator.swift` `createSegmentationObject` | Worse than reported: the writer discarded the builder's data set and emitted 14 attributes plus raw frames — no Segment Sequence, Segmentation Type, Pixel Data element or File Meta; by script, 5 of the 30 rows of Tables C.8.20-2 / C.8.20-4 were written and 10 applicable Type 1/1C rows were missing. Now routes through `Segmentation.buildDataSet` (D37d's check) and `DICOMFile.create`; every segment carries one CID 7150 and one CID 7151 Item, default (85756007, SCT, "Tissue"); additive `--segment-category` / `--segment-type` (keyword or `SCHEME:VALUE[:MEANING]`); new `SegmentPropertyCodes.swift` (8 CID 7150 rows, 21 type keywords from the CIDs CID 7151 includes). `dicom-ai` product and a `dicom-aiTests` target re-enabled in Package.swift (build config, not API) | PS3.3 2026a Tables C.8.20-2, C.8.20-4, A.51-1; PS3.16 CID 7150, 7151 | Medium | ✅ 2026-10-01 (`3fe88bd`); 5 tests pass |
| D56 | dicom-video (+ DICOMStudio) | `convert` / `batch`; CLI Workshop | No option named the audio Channel Source. Correction to the earlier row: (003A,0300) is Multiplexed Audio Channels Description Code Sequence (Type 2C, Cine Module Table C.7-13); the Channel Source is its nested Channel Source Sequence (003A,0208), Type 1, single Item, DCID 3000. Now `--audio-channel-source <value>` on `convert` and `batch` (one of the 6 CID 3000 keywords generated from the DocBook, or `SCHEME:VALUE[:MEANING]`, the CID being Extensible) maps to `VideoWorkflow.Metadata.audioChannelSource`; absent option → no Items, as before. New `dicom-videoTests` target | PS3.3 2026a Table C.7-13; PS3.16 CID 3000 | Low | ✅ CLI half closed 2026-10-01 (`8eebfab`), 10 tests pass; DICOMStudio Workshop half open |

### New findings for other modules

| ID | Module | Where | Problem | Standard | Severity | Status |
|---|---|---|---|---|---|---|
| D70 | DICOMKit | `Sources/DICOMKit/DICOMDIRWriter.swift:273` (`DICOMDirectory.Builder`), `DICOMDIRWorkflow.buildDirectory` | The chosen Application Profile is stored but never enforced: PS3.11 Table D.3-1 allows only Explicit VR Little Endian for STD-GEN-CD, Tables H.3-1 / J.3-1 add specific JPEG (.50/.51/.70) or JPEG 2000 (.90/.91) syntaxes per -JPEG / -J2K profile, and each profile restricts SOP Classes; any syntax / SOP Class is accepted for any profile | PS3.11 2026a Tables D.3-1, H.3-1, J.3-1 | Low | ⏳ Open (DICOMKit; found 2026-10-01 while closing D29) |
| D71 | DICOMKit | `Sources/DICOMKit/Segmentation/SegmentationBuilder.swift:1200` `writeDataSet` | `buildDataSet` writes neither the Enhanced General Equipment Module (Table A.51-1 M; Manufacturer, Manufacturer's Model Name, Device Serial Number, Software Versions, all Type 1 per Table C.7-8b) nor the Type 2 Patient / General Study rows, so its output is not a complete Segmentation IOD on its own; dicom-ai adds them itself | PS3.3 2026a Tables A.51-1, C.7-8b | Low | ⏳ Open (DICOMKit; found 2026-10-01 while closing D44) |
| D72 | DICOMNetwork | `StorageService.swift:829` | `StoreResult.success` is false for the Warning class (B000, B006, B007 are successes per PS3.4 Table B.2-1) and Failure statuses are returned rather than thrown, so callers that test `success` alone misreport | PS3.4 2026a Table B.2-1; PS3.7 9.1.1.1.9 | Medium | ⏳ Open (DICOMNetwork) |
| D73 | DICOMNetwork | `DIMSEStatus.swift` `from(_:)` | No names for 0117 (Invalid object instance), 0210 (Duplicate invocation), 0211 (Unrecognized operation), 0212 (Mistyped argument) | PS3.7 2026a Annex C (C.5.x) | Low | ⏳ Open (DICOMNetwork) |
| D74 | DICOMNetwork | `NetworkConsoleFormatter.swift` `levelName(.image)` | Prints "instance"; the Query/Retrieve Level value is IMAGE | PS3.4 2026a C.6.1.1.3 / Table C.6.1-1 | Low | ⏳ Open (DICOMNetwork; Workshop shows the same text) |
| D75 | DICOMNetwork | `NetworkConsoleFormatter.swift:143,155` | C-STORE Warning statuses are rendered neither as success nor failure | PS3.4 2026a Table B.2-1 | Low | ⏳ Open (DICOMNetwork) |
| D76 | DICOMNetwork | `DIMSEStatus.description` | Service-agnostic wording for A701/A702/A801/A900/B000/Cxxx differs from the Q/R names in PS3.4 Tables C.4-2 / C.4-3 | PS3.4 2026a Tables C.4-2, C.4-3 | Low | ⏳ Open (DICOMNetwork; see P-QR-STATUS-TEXT) |
| D77 | DICOMNetwork | `NetworkConsoleFormatter` | "Level: Instance"; "Completed:/Failed:/Warnings:" instead of the PS3.7 sub-operation names; "Modality:" label used for Modalities in Study (0008,0061) | PS3.4 2026a C.6.1.1.3; PS3.7 Tables 9.3-7 / 9.3-10 | Low | ⏳ Open (DICOMNetwork; Workshop shows the same text) |
| D78 | DICOMNetwork | `QRSessionState.swift:25` | state JSON stores (0008,0060) under `modality` for a study-level (0008,0061) value | PS3.4 2026a Table C.6-5 | Low | ⏳ Open (see P-QR-STATE-MODALITIES) |
| D79 | DICOMNetwork | Sources/DICOMNetwork/DIMSEStatus.swift:278, :280, :282 | C-FIND failure names differ from the 2026a tables: 0xA900 printed "Error: Identifier/Data does not match SOP Class" (K.4-1: "Error: Data Set does not match SOP Class"); 0x0110 printed "Failed: Unable to process" (PS3.7 C.5.21: "Processing Failure"; "Unable to process" is the Cxxx class of K.4-1) | PS3.4 Table K.4-1; PS3.7 C.5.21 | low (wording) | ⏳ Open |
| D80 | DICOMNetwork | Sources/DICOMNetwork/NetworkConsoleFormatter.swift:502-547 | 10 of 38 JSON keys are not PS3.6 keywords (see P-MWL-JSON-KEYS); shared with DICOMStudio's MWL panel | PS3.6 Table 6-1 | low (P-item) | ⏳ Open |
| D81 | DICOMNetwork | Sources/DICOMNetwork/ModalityWorklistService.swift:157-168 | `validateScheduledStationAETitle` tolerates `*`/`?` although Table K.6-1 row 3 allows Single Value Matching only for (0040,0001) | PS3.4 Table K.6-1 | low | ⏳ Open |
| D82 | DICOMNetwork | Sources/DICOMNetwork/DIMSEStatus.swift:124-171, 267-300 | `DIMSEStatus.from` maps no DIMSE-N code except 0110/0111/0112/0118/0122/0213; 0105, 0106, 0107, 0115, 0116, 0117, 0119, 0120, 0121, 0124, 0210-0212 print "Unknown status"; 0110 is named "Failed: Unable to process" instead of "Processing Failure"; the N-SET A710 Error ID (Table F.7.2-2) is never surfaced | PS3.7 Annex C C.4.2-C.5.25; PS3.4 Table F.7.2-2 | medium (every MPPS and Print failure message) | ⏳ Open |
| D83 | DICOMNetwork | Sources/DICOMNetwork/MPPSService.swift:1034, :1099; DICOMNetworkError.swift:476 | MPPS N-CREATE / N-SET failures are thrown as `DICOMNetworkError.storeFailed` → "Store failed: …" (a C-STORE wording) | PS3.4 F.7.2.1.4 / Table F.7.2-2 | low (wording) | ⏳ Open |
| D84 | DICOMNetwork | Sources/DICOMNetwork/MPPSService.swift:143, :162, :326 | `MPPSCodedEntry.parseErrorMessage` and doc comments give "110513\|DCM\|Doctor cancelled procedure" and the title "Procedure Discontinuation Reasons"; Table D-1: 110513 = "Discontinued for unspecified reason", 110500 = "Doctor canceled procedure"; CID 9300 title is "Procedure Discontinuation Reason" | PS3.16 CID 9300, CID 9301, Table D-1 | low (message text; shared with the Studio CLI Workshop) |
| D85 | DICOMStudio | Sources/DICOMStudio/Components/CLIWorkshopHelpers.swift:1379-1380 | same wrong placeholder "110513\|DCM\|Doctor cancelled procedure"; and :1217-1221 offers `--modality` as optional ("Any") although `dicom-mpps create` now requires it (Table F.7.2-1 row 105, 1/1) | PS3.16 Table D-1; PS3.4 Table F.7.2-1 | low |
| D86 | DICOMNetwork | Sources/DICOMNetwork/MPPSService.swift:1125-1168 (N-CREATE builder) | the N-CREATE data set never creates (0040,0281) zero-length, yet the N-SET sends it for DISCONTINUED; F.7.2.1.1 note: "If an SCU wishes to use the PPS Discontinuation Reason Code Sequence (0040,0281), it must create that Attribute (zero-length) during N-CREATE"; F.7.2.1.2 "All Attributes shall be created before they can be set" | PS3.4 F.7.2.1.1 note, F.7.2.1.2 | medium (strict SCPs may answer 0105H No such Attribute) | ⏳ Open |
| D87 | DICOMNetwork | Sources/DICOMNetwork/MPPSService.swift:1163 | `add(0x0008,0x0060,.CS, procedureStep.modality)` writes an empty value when `modality` is nil — a Type 1 attribute (Table F.7.2-1 row 105); the engine's `validate(_:for:)` does not check it (the CLI now refuses before calling) | PS3.4 Table F.7.2-1 | medium | ⏳ Open |
| D88 | Tests/DICOMStudioTests | NetworkToolWorkshopCLIParityTests.swift:151-157 | parse fixtures use the wrong code/meaning pairs ("110513 Doctor cancelled procedure", "110514 Equipment failure"); harmless for parsing but mislead readers | PS3.16 Table D-1 | low | ⏳ Open |

### Rows handed to DICOMStudio

Filled at the end of the module.

---

## G1 Network

### dicom-echo

Commands: dicom-echo · files: DICOMEcho.swift · bucket C1 (plumbing adapter over DICOMNetwork.DICOMVerificationService)

Compared: PS3.7 2026a 9.1.5.1.4 (C-ECHO status values, 5 named codes, dumped from the DocBook), PS3.5 2026a Table 6.2-1 (VR AE: 16 bytes maximum), PS3.8 2026a 9.1.1 (well-known port 104, registered port 11112), PS3.6 2026a Table A-1 (Verification SOP Class 1.2.840.10008.1.1, the two uncompressed transfer syntaxes named in `--diagnose`). The tool holds no literal of its own; every standard value it prints comes from DICOMNetwork (DIMSEStatus, VerificationConfiguration, NetworkConsole). `Scripts/diff_cli.py --tool dicom-echo`: 11 checks ok, 0 FAIL.

**Input contract**

| Option | DICOM concept | 2026a reference | Allowed per standard | Code accepts | Default (std) | Default (code) | Verdict |
|---|---|---|---|---|---|---|---|
| `<host>` | TCP transport address (plumbing) | PS3.8 9.1.1 | hostname / IP (`host[:port]`) | `String` | — | — | plumbing |
| `--port` | TCP port (plumbing) | PS3.8 9.1.1: well-known 104, registered 11112 | 1–65535 | `UInt16?` | 104 if privileged ports allowed, else 11112 | 11112 | plumbing (matches the PS3.8 registered port) |
| `--aet` | Calling AE Title | PS3.8 7.1.1.3; PS3.5 Table 6.2-1 VR AE | ≤16 bytes, no backslash/control chars, not all spaces | `String` (checked by DICOMNetwork.AETitle) | none | required | plumbing |
| `--called-aet` | Called AE Title | PS3.8 7.1.1.4; PS3.5 Table 6.2-1 VR AE | as above | `String` | none | `"ANY-SCP"` | plumbing — "ANY-SCP" is a tool convention, not a standard value; noted |
| `-c, --count` | number of C-ECHO operations (one association each) | PS3.7 9.1.5 | — | `Int` > 0 | — | 1 | plumbing |
| `--timeout` | ARTIM / socket timeout | PS3.8 9.1.2 (ARTIM) | — | `Int` seconds | — | 30 | plumbing |
| `--stats` | round-trip statistics | — | — | `Bool` | — | false | plumbing |
| `--diagnose` | connectivity probe (prints Implementation Class UID / Version Name, PS3.7 Tables D.3-1 / D.3-3, from VerificationConfiguration) | PS3.7 Annex D.3 | — | `Bool` | — | false | plumbing |
| `-v, --verbose` | — | — | — | `Bool` | — | false | plumbing |

Counts: matched 0, wrong 0, missing 0, extra 0, plumbing 9.

**Output contract**

| Field | DICOM source | Encoding (standard) | Encoding (code) | Verdict |
|---|---|---|---|---|
| `Status: …` (echoSuccess / echoStatusFailure) | C-ECHO-RSP Status (0000,0900) | PS3.7 9.1.5.1.4: Success 0000H; Refused: SOP Class not supported 0122H; Duplicate invocation 0210H; Unrecognized operation 0211H; Mistyped argument 0212H | `DIMSEStatus.description`: "Success (0x0000)", "Refused: SOP Class not supported (0x0122)"; 0210/0211/0212 → "Unknown status (0x0210)" | match for 0000 / 0122; 0210–0212 → deferred (DIMSEStatus, DICOMNetwork) |
| `✅ C-ECHO successful` / `❌ C-ECHO failed` | success = status 0000 (`VerificationResult.success = status.isSuccess`) | PS3.7 9.1.5.1.4 | shared NetworkConsole | match |
| `SOP Class: Verification (1.2.840.10008.1.1)` (--diagnose) | PS3.6 Table A-1 | "Verification SOP Class" | abbreviated name, correct UID (shared NetworkConsole) | match (abbreviation) |
| `Transfer Syntaxes: Explicit VR Little Endian, Implicit VR Little Endian` (--diagnose) | PS3.6 Table A-1 | "Explicit VR Little Endian", "Implicit VR Little Endian: Default Transfer Syntax for DICOM" | shared NetworkConsole | match |
| `Implementation Class UID` / `Implementation Version` (--diagnose) | PS3.7 Tables D.3-1 / D.3-3 | UID ≤64 bytes; version name ≤16 bytes | `1.2.826.0.1.3680043.9.7433.1.1` / `DICOMKIT_001` (VerificationConfiguration) | plumbing (implementation identity) |
| exit `0` / `1` / `64` | — | — | 0 all succeeded, 1 any failure (`ExitCode(1)`), 64 usage (`ValidationError`, e.g. `--count 0`) | plumbing; README corrected to list 64 |

Findings: none in the tool. README exit-code list lacked 64 (fixed, docs only).

Deferred (DICOMNetwork): see D-rows in the dicom-send section (DIMSEStatus 0210/0211/0212/0117 unnamed).

P-items: none.

Marker: `// NEMA-verified: 2026a, checked 2026-10-01 — carries no DICOM-standard data of its own: every option is plumbing (host, port, AE Titles, count, timeout, stats, diagnose, verbose); the C-ECHO statuses it prints (PS3.7 2026a 9.1.5.1.4: 0000 Success, 0122 Refused: SOP Class not supported, 0210 Duplicate invocation, 0211 Unrecognized operation, 0212 Mistyped argument) are rendered by DICOMNetwork.DIMSEStatus; port 11112 is the registered DICOM port of PS3.8 2026a 9.1.1; AE Titles are PS3.5 Table 6.2-1 VR AE (16 bytes), checked by DICOMNetwork.AETitle`

Tests: none needed (no behaviour change). `swift build --product dicom-echo` ok; `check_nema_markers.py Sources/dicom-echo`: 1/1.

Commit: 0c845da `docs(cli): dicom-echo verified against DICOM 2026a (marker, README exit codes)`.

### dicom-send

Commands: dicom-send · files: DICOMSend.swift, SendExecutor.swift · bucket B2 (C-STORE status handling contradicted PS3.4 Table B.2-1)

Compared: PS3.4 2026a Table B.2-1 (C-STORE Response Status Values, 7 rows dumped by script: Failure A7xx / A9xx / Cxxx, Warning B000 / B007 / B006, Success 0000); PS3.7 2026a 9.1.1.1.9 (C-STORE status prose: Warning = "was able to store … but detected a probable error", 0122 Refused: SOP Class not supported); PS3.7 2026a Table 9.3-1 (C-STORE-RQ Priority: LOW = 0002H, MEDIUM = 0000H, HIGH = 0001H — 3 of 3 match DIMSEPriority); PS3.6 2026a Table A-1 (transfer-syntax UIDs accepted by `--transfer-syntax` via DICOMCore.TransferSyntax.parse, verified in the DICOMCore report); PS3.5 Table 6.2-1 (VR AE); PS3.8 9.1.1 (port 11112). `Scripts/diff_cli.py --tool dicom-send`: 11 checks ok, 0 FAIL (the status bug is behaviour, not a literal, so only the contract row caught it).

**Input contract**

| Option | DICOM concept | 2026a reference | Allowed per standard | Code accepts | Default (std) | Default (code) | Verdict |
|---|---|---|---|---|---|---|---|
| `<host>` | TCP transport address | PS3.8 9.1.1 | `host[:port]` | `String` | — | — | plumbing |
| `--port` | TCP port | PS3.8 9.1.1 (104 well-known, 11112 registered) | 1–65535 | `UInt16?` | 104 / 11112 | 11112 | plumbing |
| `--aet` | Calling AE Title | PS3.8 7.1.1.3; PS3.5 Table 6.2-1 VR AE | ≤16 bytes | `String` (DICOMNetwork.AETitle) | none | required | plumbing |
| `--called-aet` | Called AE Title | PS3.8 7.1.1.4; PS3.5 Table 6.2-1 | ≤16 bytes | `String` | none | `"ANY-SCP"` (tool convention) | plumbing |
| `<paths>` | files to send (PS3.10 files; SOP Class / Instance / Transfer Syntax read from File Meta) | PS3.10 Table 7.1-1 | — | `[String]` | — | — | plumbing |
| `-r, --recursive` | — | — | — | `Bool` | — | false | plumbing |
| `--verify` | C-ECHO before sending | PS3.4 Annex A | — | `Bool` | — | false | plumbing |
| `--retry` | retry on a thrown error or a Failure-class status | — | — | `Int` ≥ 0 | — | 0 | plumbing |
| `--dry-run` | — | — | — | `Bool` | — | false | plumbing |
| `-v, --verbose` | — | — | — | `Bool` | — | false | plumbing |
| `--timeout` | ARTIM / socket timeout | PS3.8 9.1.2 | — | `Int` s | — | 60 | plumbing |
| `--priority` | Priority (0000,0700) of C-STORE-RQ | PS3.7 Table 9.3-1 | LOW 0002H, MEDIUM 0000H, HIGH 0001H | `low`→0x0002, `medium`→0x0000, `high`→0x0001 (DIMSEPriority) | none (required field) | medium | match (help now cites the hex values) |
| `--transfer-syntax` | Transfer Syntax Name of the proposed Presentation Context | PS3.8 7.1.1.13; PS3.6 Table A-1 | any Table A-1 Transfer Syntax UID | UID or DICOMCore alias (`TransferSyntax.parse`); unknown → usage error | none (file's own) | nil = file's own syntax | match |

Counts: matched 2, wrong 0, missing 0, extra 0, plumbing 11.

**Output contract**

| Field | DICOM source | Encoding (standard) | Encoding (code) | Verdict |
|---|---|---|---|---|
| per-file `✅ (rtt)` / `❌ <error>` | C-STORE-RSP Status (0000,0900) | PS3.4 Table B.2-1: Success 0000 stored; Warning B000/B006/B007 stored with deviation; Failure A7xx/A9xx/Cxxx (+0122, PS3.7 9.1.1.1.9) not stored | **was wrong**: every `StoreResult` returned by the engine was counted and printed as ✅ regardless of status (a Failure response gave ✅ and exit 0). Now: Failure → `SendError.storeFailed(status)` ("C-STORE response status Refused: Out of resources (0xA700) — not stored (PS3.4 Table B.2-1)"), retried, counted as failed, exit 1; Warning → ✅ plus `    ⚠️ Stored with warning: <status>` and a `Stored with warning: N` summary line | wrong → fixed (StoreOutcome, 7 rows of B.2-1 + 0122 pinned by StoreOutcomeTests) |
| `Priority: medium` (sendHeader) | option word | — | shared NetworkConsole prints the CLI word | plumbing |
| `Transfer Syntax: <uid>` (sendHeader) | PS3.6 Table A-1 UID | UID | UID | match |
| `Transfer Summary` (Total files / Succeeded / Failed / Bytes sent / …) | — | — | shared NetworkConsole; no warning count (tool prints its own line) | plumbing (see P-SEND-SUMMARY) |
| exit `0` / `1` / `64` | — | — | 0 all stored (incl. warnings); 1 any failed file (`SendError.partialFailure`) or pre-flight error; 64 usage (`ValidationError`: negative `--retry`, unknown `--transfer-syntax`, no files) | plumbing; README said 2 for partial — corrected |

Findings
1. **Failure statuses counted as success** — `SendExecutor.sendFiles` incremented `successCount` for every returned `StoreResult` and never read `result.success` / `result.status`; `DICOMStorageService.store` returns a `StoreResult` (does not throw) for A7xx / A9xx / Cxxx / 0122. Fixed in the tool: `StoreOutcome(status:)` classifies per Table B.2-1; `sendFile` throws `SendError.storeFailed` for the Failure class so `--retry` applies; Warning class printed and tallied. Test: `Tests/dicom-sendTests/StoreOutcomeTests.swift` (6 tests: 0000; B000/B006/B007/B001/BFFF; A700/A701/A7FF/A900/A901/A9FF/C000/C123/CFFF/0122; error text; priority values; priority help).
2. `--priority` help did not say which Priority values the words map to — now cites PS3.7 Table 9.3-1.
3. README exit codes claimed 2 for partial success (code: 1) — corrected; new "C-STORE Response Statuses" section.

Deferred findings (other modules)
| ID | Module | File:line | Problem | Standard | Severity |
|---|---|---|---|---|---|
| D-new | DICOMNetwork | Sources/DICOMNetwork/StorageService.swift:829 (`success: response.status.isSuccess`, also the preferredTransferSyntax path) | `StoreResult.success` is false for a Warning-class response (B000/B006/B007) although PS3.7 9.1.1.1.9 says the SCP "was able to store the composite SOP Instance"; and a Failure-class response is returned as a result, not thrown, so every caller must re-classify the status (dicom-send did not) | PS3.4 2026a Table B.2-1; PS3.7 9.1.1.1.9 | medium |
| D-new | DICOMNetwork | Sources/DICOMNetwork/DIMSEStatus.swift:122–170 (`from(_:)`) | 0210 Duplicate invocation, 0211 Unrecognized operation, 0212 Mistyped argument, 0117 Invalid SOP Instance (PS3.7 9.1.1.1.9 / 9.1.5.1.4) have no named case and print as "Unknown status (0x0210)" | PS3.7 2026a 9.1.1.1.9, 9.1.5.1.4, Annex C | low |
| D-new | DICOMNetwork | Sources/DICOMNetwork/NetworkConsoleFormatter.swift:143 (`sendFileResultSuffix`) and :155 (`sendSummary`) | no rendering for a Warning-class C-STORE status and no warning tally; dicom-send prints a tool-side line, so Studio parity diverges for warning responses | PS3.4 Table B.2-1 Warning class | low |

P-items
- **P-SEND-SUMMARY**: add a `warnings:` parameter to `NetworkConsole.sendSummary` / a warning variant of `sendFileResultSuffix` (shared DICOMNetwork type, Studio parity) so the Warning class is rendered on both sides; dicom-send would then drop its tool-side lines.

Markers
- DICOMSend.swift: `// NEMA-verified: 2026a, checked 2026-10-01 — --priority values diffed against PS3.7 2026a Table 9.3-1 (C-STORE-RQ Priority: LOW 0002H, MEDIUM 0000H, HIGH 0001H: 3 of 3 match via DIMSEPriority); --transfer-syntax accepts a PS3.6 Table A-1 UID or a DICOMCore.TransferSyntax alias; port 11112 is the registered DICOM port of PS3.8 2026a 9.1.1; AE Titles are PS3.5 Table 6.2-1 VR AE (16 bytes), checked by DICOMNetwork.AETitle`
- SendExecutor.swift: `// NEMA-verified: 2026a, checked 2026-10-01 — C-STORE response handling diffed against PS3.4 2026a Table B.2-1 (7 rows: Success 0000 stored; Warning B000/B006/B007 stored and reported; Failure A7xx/A9xx/Cxxx not stored, counted as failed) and PS3.7 9.1.1.1.9 (0122 Refused: SOP Class not supported); status text comes from DICOMNetwork.DIMSEStatus`

Tests: `swift test --filter StoreOutcomeTests` — 6 tests, 0 failures. `swift build --product dicom-send` ok; `check_nema_markers.py Sources/dicom-send`: 2/2.

Commits: 0efff87 `fix(cli): dicom-send treats a C-STORE Failure status as a failed file (PS3.4 Table B.2-1)`; f24869c `fix(cli): dicom-send test target and CHANGELOG entry` (Package.swift `dicom-sendTests` target + CHANGELOG bullet, which 0efff87 missed).

### dicom-query

Commands: dicom-query · files: DICOMQuery.swift, QueryExecutor.swift · bucket B2 (level naming contradicted PS3.4; JSON/CSV docs wrong)

Compared: PS3.4 2026a Tables C.6.1-1 / C.6.2-1 (Query/Retrieve Level values: PATIENT, STUDY, SERIES, IMAGE — 4 rows / 3 rows dumped by script; the code's `QueryLevel` sends exactly these 4 values); Tables C.6-1 (Patient level, 17 rows), C.6-3 (Series level, 5 rows), C.6-4 (Composite Object Instance level, 20 rows), C.6-5 (Study Root Study level, 65 rows) — every attribute an option maps to (via DICOMNetwork.DICOMQueryService.buildQueryKeys) is listed at that level or covered by "All other Attributes at … Level"; PS3.4 C.4.1.1.3.1 (Identifier structure), C.4.1.2.1 (hierarchical SCU baseline: only the Unique Keys of the levels above), C.2.2.2.4 (wild cards `*` `?`), C.2.2.2.5 (date ranges `d1-d2`, `-d1`, `d1-`); PS3.4 Table C.4-1 (C-FIND status, 7 rows: engine-handled, the tool prints none); PS3.3 C.7.3.1.1.1 (Modality Defined Terms: via DICOMCore.Modality, text-diffed in the DICOMCore report; the tool keeps no list); PS3.18 Annex F (JSON model — not claimed by the tool). `Scripts/diff_cli.py --tool dicom-query`: 11 checks ok, 0 FAIL. The surface extractor missed `--modality` (help built by `ArgumentHelp(stringLiteral: ModalityOptionValidator.helpText("filter"))`, two levels of nested parentheses); the `ATTR` regex in Scripts/diff_cli.py was widened by one nesting level (19 options now listed).

**Input contract**

| Option | DICOM concept | 2026a reference | Allowed per standard | Code accepts | Default (std) | Default (code) | Verdict |
|---|---|---|---|---|---|---|---|
| `<host>` | TCP transport address | PS3.8 9.1.1 | `host[:port]` | `String` | — | — | plumbing |
| `--port` | TCP port | PS3.8 9.1.1 (104 / 11112) | 1–65535 | `UInt16?` | 104 / 11112 | 11112 | plumbing |
| `--aet` | Calling AE Title | PS3.8 7.1.1.3; PS3.5 Table 6.2-1 VR AE | ≤16 bytes | `String` (AETitle) | none | required | plumbing |
| `--called-aet` | Called AE Title | PS3.8 7.1.1.4 | ≤16 bytes | `String` | none | `"ANY-SCP"` (tool convention) | plumbing |
| `-l, --level` | Query/Retrieve Level (0008,0052) | PS3.4 Tables C.6.1-1 / C.6.2-1; C.4.1.1.3.1 | PATIENT, STUDY, SERIES, IMAGE | `patient`, `study`, `series`, `image` (+ alias `instance`) → `QueryLevel` PATIENT/STUDY/SERIES/IMAGE on the wire | none | study | **wrong → fixed**: help/validation/warning said "instance"; wire value was already IMAGE. `image` added, `instance` kept |
| `--patient-name` | Patient's Name (0010,0010) | C.6-5 R (Study Root), C.6-1 R; wild cards C.2.2.2.4 | PN; `*` `?` | `String?` → matching key (PN) | — | — | match |
| `--patient-id` | Patient ID (0010,0020) | C.6-5 R; C.6-1 U | LO | `String?` | — | — | match |
| `--study-date` | Study Date (0008,0020) | C.6-5 R; range C.2.2.2.5 | DA; `d1-d2`, `-d1`, `d1-` | `String?` passed verbatim (DA) | — | — | match (help now lists the open ranges) |
| `--study-uid` | Study Instance UID (0020,000D) | C.6-5 U; C.4.1.2.1 | UI, single value / UID list | `String?` | — | — | match (required at SERIES/IMAGE by `validate()`) |
| `--series-uid` | Series Instance UID (0020,000E) | C.6-3 U; C.4.1.2.1 | UI | `String?` | — | — | match (required at IMAGE) |
| `--accession-number` | Accession Number (0008,0050) | C.6-5 R | SH | `String?` | — | — | match |
| `--modality` | STUDY: Modalities in Study (0008,0061) C.6-5 O; SERIES: Modality (0008,0060) C.6-3 R | PS3.3 C.7.3.1.1.1 Defined Terms | Defined Terms (not Enumerated — unknown value warns) | `String?` via ModalityOptionValidator / DICOMCore.Modality | — | — | match |
| `--strict-modality` | reject a non-Defined-Term | PS3.3 C.7.3.1.1.1 | — | `Bool` | — | false | plumbing |
| `--study-description` | Study Description (0008,1030) | C.6-5 O; C.2.2.2.4 | LO; wild cards | `String?` | — | — | match |
| `--referring-physician` | Referring Physician's Name (0008,0090) | C.6-5 O | PN | `String?` | — | — | match |
| `-f, --format` | output rendering | — | — | `table`, `json`, `csv`, `compact` | — | table | plumbing (see output contract) |
| `--timeout` | ARTIM / socket timeout | PS3.8 9.1.2 | — | `Int` s | — | 60 | plumbing |
| `--verbose` | — | — | — | `Bool` | — | false | plumbing |
| `--include-parent-keys` | non-baseline: parent-level return keys at SERIES/IMAGE | PS3.4 C.4.1.2.1 forbids them for a baseline SCU | — | `Bool` | — | false | extra (deliberate, documented as non-baseline) |

Counts: matched 9, wrong 1 (fixed), missing 0, extra 1 (documented), plumbing 8.

**Output contract**

| Field | DICOM source | Encoding (standard) | Encoding (code) | Verdict |
|---|---|---|---|---|
| JSON object keys (`--format json`) | attribute tags of each C-FIND-RSP Identifier | PS3.18 F.2.2: `"00100010": {"vr":"PN","Value":[…]}` (keyword keys are not standard) | `"(0010,0010)": "SMITH^JOHN"` — tag string → decoded string (DICOMNetwork.DICOMQueryResultFormatter) | tool-specific summary, now documented as such in the README (README previously showed `"(0010,0010) Patient's Name"` keys that the code never produced); see P-QUERY-JSON |
| CSV header (`--format csv`) | attribute tags | PS3.6 keywords/names would be the natural labels | `(0008,0020),(0008,1030),…` sorted by tag | tool-specific; README corrected |
| table column labels (`--format table`) | Patient's Name, Patient ID, Patient's Birth Date, Patient's Sex, Number of Patient Related Studies, Study Date, Study Description, Modalities in Study, Number of Study Related Series, Series Number, Modality, Series Description, Series Date, Number of Series Related Instances, Instance Number, SOP Class UID, Rows×Columns, Number of Frames | PS3.6 Table 6-1 names | "Patient Name", "Patient ID", "Birth Date", "Sex", "Studies", "Date", "Description", "Modalities", "Series", "Series Number", "Modality", "Instances", "Instance Number", "SOP Class", "Dimensions", "Frames" (shared formatter) | abbreviations, 2 match PS3.6 verbatim; shared DICOMNetwork type with Studio parity → P-QUERY-COLUMNS |
| `Query Level: instance` (verbose header) | Query/Retrieve Level (0008,0052) | IMAGE (Table C.6.2-1) | `NetworkConsole.levelName(.image)` = "instance" | deferred (DICOMNetwork NetworkConsoleFormatter.swift:834) |
| `Information Model: Patient Root` / `Study Root` (verbose) | PS3.4 C.6.1 / C.6.2 | PATIENT → Patient Root; else Study Root | QueryExecutor | match |
| stderr `Warning: … cannot be matched at IMAGE level …` | PS3.4 C.4.1.2.1 | level value | now `level.queryLevel.rawValue` (was "INSTANCE") | wrong → fixed |
| `--level series requires --study-uid` / `--level image (instance) requires --study-uid and --series-uid` | PS3.4 C.4.1.2.1 | Unique Key of each level above | `validate()` | match |
| `Total: N study(ies)` etc. | — | — | shared formatter | plumbing |
| C-FIND status (Pending FF00/FF01, Success 0000, Failure A700/A900/Cxxx, Cancel FE00) | PS3.4 Table C.4-1 | — | consumed by DICOMNetwork.DICOMQueryService (not printed by the tool; a Failure surfaces as a thrown error with `DIMSEStatus.description`) | engine (verified in the DICOMNetwork report) |
| exit `0` / `1` / `64` | — | — | 0 completed (empty result set included); 1 thrown error (network, rejection, Failure status); 64 usage (`ValidationError`) | plumbing; README said 1 = validation, 2 = connection — corrected |

Findings
1. `--level` named the bottom level "instance" in help, in the `validate()` message and in the C.4.1.2.1 warning ("at INSTANCE level"), while PS3.4 Tables C.6.1-1 / C.6.2-1 name it IMAGE and the wire value was already IMAGE. Fixed: `QueryLevelOption` cases are patient/study/series/image with `instance` as an alias (`init?(argument:)`), help cites (0008,0052) and the tables, the warning prints `level.queryLevel.rawValue`. Test: `Tests/dicom-queryTests/QueryLevelOptionTests.swift` (7 tests: 4 wire values; alias; rejection; allValueStrings; help; validate(); warning text).
2. README documented JSON keys as `"(0010,0010) Patient's Name"` and CSV headers with names; the code emits bare `(GGGG,EEEE)` tags. README corrected and the format declared a tool-specific summary (not PS3.18 Annex F).
3. README exit codes (1 validation / 2 connection) did not match ArgumentParser (64 / 1). Corrected.
4. Help for `--study-date`, `--patient-name`, `--study-description`, `--include-parent-keys` now cite the tag and PS3.4 clause (C.2.2.2.4 / C.2.2.2.5); SERIES/INSTANCE → SERIES/IMAGE.

Deferred findings (other modules)
| ID | Module | File:line | Problem | Standard | Severity |
|---|---|---|---|---|---|
| D-new | DICOMNetwork | Sources/DICOMNetwork/NetworkConsoleFormatter.swift:834 (`levelName`) | prints "instance" for `QueryLevel.image`; the verbose header therefore shows "Query Level: instance" while the Identifier carries IMAGE | PS3.4 2026a Tables C.6.1-1 / C.6.2-1 | low |

P-items
- **P-QUERY-JSON**: `--format json` emits a tool-specific `{"(GGGG,EEEE)": "string"}` summary. Proposed: a new additive value `--format dicom-json` producing the PS3.18 F.2 DICOM JSON Model (`"00100010": {"vr":"PN","Value":[{"Alphabetic":"…"}]}`) from the raw Identifier; needs `QueryOutputFormat` (shared DICOMNetwork enum, Studio parity) — not implemented. The existing `json` keys stay as they are.
- **P-QUERY-COLUMNS**: table/CSV labels to PS3.6 Table 6-1 names or keywords (e.g. "Patient's Name", "Patient's Birth Date", "Modalities in Study", "Number of Study Related Series", "SOP Class UID"); lives in `DICOMNetwork.DICOMQueryResultFormatter` (shared, byte-compared with Studio) — not implemented.

Markers
- DICOMQuery.swift: `// NEMA-verified: 2026a, checked 2026-10-01 — --level values diffed against PS3.4 2026a Tables C.6.1-1 / C.6.2-1 (PATIENT, STUDY, SERIES, IMAGE: 4 of 4 sent on the wire via QueryLevel; "instance" kept as a CLI alias of image); the match keys each option maps to checked against Tables C.6-1, C.6-3, C.6-4, C.6-5 (9 options, all listed at their level); wildcard and date-range help against C.2.2.2.4 / C.2.2.2.5; --modality terms via DICOMCore.Modality (C.7.3.1.1.1); --format json/csv keys are the tool's own "(GGGG,EEEE)" tag strings, not PS3.18 F.2 (documented in README)`
- QueryExecutor.swift: `// NEMA-verified: 2026a, checked 2026-10-01 — Information Model choice checked against PS3.4 2026a C.6.1 / C.6.2: PATIENT level → Patient Root (Table C.6.1-1), STUDY/SERIES/IMAGE → Study Root (Table C.6.2-1); the key tables themselves live in DICOMNetwork.DICOMQueryService.buildQueryKeys`

Tests: `swift test --filter QueryLevelOptionTests` — 7 tests, 0 failures. `swift build --product dicom-query` ok; `check_nema_markers.py Sources/dicom-query`: 2/2.

Commit: 695d961 `fix(cli): dicom-query --level names the PS3.4 IMAGE level; instance kept as alias` (Sources/dicom-query, Tests/dicom-queryTests, Package.swift `dicom-queryTests` target, CHANGELOG).

Note for the orchestrator: 695d961's Package.swift hunk also carried the concurrently edited `dicom-videoTests` target from the working tree; the dicom-video agent's own commit 8eebfab then added it a second time and 0efff87 removed the duplicate — HEAD has each target once. Scripts/diff_cli.py `status_codes(p7)` finds no rows because the PS3.7 Annex C status tables carry no `label` in the 2026a DocBook (only Tables 7.5-x / 9.x / D.3-x do); the service-specific status rows are in PS3.4 (B.2-1, C.4-1…).

### dicom-retrieve

Commands: dicom-retrieve · files: DICOMRetrieve.swift (C2), RetrieveExecutor.swift (C2), RetrieveStatusText.swift (A, new) · README.md
Commits: 1f853e8 (fix(cli): dicom-retrieve final status worded per PS3.4 2026a Tables C.4-2 / C.4-3, counters per PS3.7)
Standard dumped by script: PS3.4 2026a Tables C.4-2 (9 rows), C.4-3 (8 rows), C.6.1-1 (4), C.6.2.3-1 (3), C.6.1.3-1 (3), C.6-5 (Study level keys), C.5-1 (7 extended-negotiation items); PS3.7 2026a Tables 9.1-3, 9.1-4, 9.3-6, 9.3-7, 9.3-9, 9.3-10; PS3.6 Table A-1 (the 12 1.2.840.10008.5.1.4.1.2.* rows); PS3.8 2026a 9.1.2 (ports 104 / 11112); PS3.10 Table 7.1-1; sections C.4.2.2.1, C.4.3.2.1, C.4.2.1.4.2, C.2.2.2.4, C.2.2.2.5.

**Input contract** — matched 6, wrong 0, missing 0, extra 0, plumbing 10 (+2 n/a rows: Priority, extended negotiation)

| Option | DICOM concept | 2026a reference | Allowed per standard | Code accepts | Default (std) | Default (code) | Verdict |
|---|---|---|---|---|---|---|---|
| `<host>` | TCP transport address of the SCP | PS3.8 9.1.2 | hostname / IP | `String`, `host[:port]`, `pacs://` prefix stripped | — | — | plumbing |
| `--port` | DICOM UL TCP port | PS3.8 9.1.2: "well known" 104, "registered" 11112 | any port | `UInt16?` | none mandated | 11112 (the PS3.8 registered port) | plumbing; help now cites PS3.8 9.1.2 |
| `--aet` | Calling AE Title | PS3.8 Table 9-11; PS3.5 Table 6.2-1 VR AE (≤16 chars) | AE | `String`, validated by DICOMNetwork `AETitle` at association | — | required | plumbing |
| `--called-aet` | Called AE Title | PS3.8 Table 9-11; PS3.5 VR AE | AE | `String` | — | `"ANY-SCP"` | plumbing (no standard default) |
| `--study-uid` | Study Instance UID (0020,000D), unique key at level STUDY | PS3.4 Table C.6-5 (U); Table C.6.1-1 "STUDY" | UI | `String?` | — | — | match (help now names tag and level) |
| `--series-uid` | Series Instance UID (0020,000E), level SERIES; one unique key for each level above (study) required | PS3.4 C.4.2.2.1 / C.4.3.2.1; Table C.6.1-1 "SERIES" | UI | `String?`, requires `--study-uid` (exit 64) | — | — | match |
| `--instance-uid` | SOP Instance UID (0008,0018), level IMAGE (the option says "instance"; the wire value is `IMAGE` via `QueryLevel.image`, PS3.4 Table C.6.1-1 "Composite Object Instance Information — IMAGE") | PS3.4 Table C.6.1-1; C.4.2.2.1 | UI | `String?`, requires study + series (exit 64) | — | — | match (help now says "Query/Retrieve Level IMAGE") |
| `--uid-list` | several Study Instance UIDs, one C-MOVE/C-GET per UID | PS3.4 C.4.2.2.1 allows a UID list at STUDY level; the tool issues one request per UID | — | file path, `#` comments | — | — | plumbing |
| `--output` | directory for the Part 10 files written by C-GET | PS3.10 7.1 | — | path | — | `"."` | plumbing |
| `--method` | C-MOVE = Study Root Query/Retrieve Information Model - MOVE 1.2.840.10008.5.1.4.1.2.2.2; C-GET = … - GET …2.2.3 | PS3.4 C.4.2 / C.4.3; Table C.6.2.3-1; PS3.6 Table A-1 | the two SOP Classes (Patient Root …2.1.2/3 exist but are not selectable) | `c-move`, `c-get` (enum) | none | `c-move` | match (help now names the SOP Classes) |
| `--move-dest` | Move Destination (0000,0600), AE of the Storage SCP | PS3.7 Table 9.3-9 (M in C-MOVE-RQ, Table 9.1-4); PS3.4 C.4.2.2.1 | AE | `String?`, required for c-move (exit 64) | — | — | match |
| `--hierarchical` | output layout `<output>/<StudyInstanceUID>/<SeriesInstanceUID>/` (C-GET only) | — | — | `Bool` | — | false | plumbing; help said "patient/study/series" — fixed to what the code does |
| `--timeout` | socket timeout (not the PS3.8 ARTIM timer) | — | — | `Int` s | — | 60 | plumbing |
| `--parallel` | concurrent `--uid-list` retrievals | — | — | `Int ≥ 1` (exit 64 otherwise) | — | 1 | plumbing |
| `--transfer-syntax` | Transfer Syntax proposed for the Storage presentation contexts of C-GET (advisory for C-MOVE) | PS3.4 C.4.3.2.1 (SCU proposes the storage contexts); PS3.6 Table A-1 via shared `TransferSyntax.parse` | registered transfer syntaxes | any token the shared parser accepts; unknown → exit 64 | — | nil | match (shared parser verified in DICOMCore) |
| `-v, --verbose` | — | — | — | `Bool` | — | false | plumbing |
| *(no option)* Priority (0000,0700) | LOW 0002H / MEDIUM 0000H / HIGH 0001H | PS3.7 Table 9.3-9 / 9.3-6 | three values | not exposed; engine sends MEDIUM (RetrieveService.swift:958, 1267) | — | MEDIUM | n/a — P-RETRIEVE-PRIORITY |
| *(no option)* Extended negotiation | relational-retrieve, Enhanced Multi-Frame Image Conversion | PS3.4 Table C.5-1 items 1, 5; C.4.2.2.2 | — | not exposed; baseline SCU behaviour | — | baseline | n/a — P-RETRIEVE-EXTNEG |

**Output contract** — matched 8, wrong 0 (4 fixed in this commit), missing 0, extra 0, plumbing 5; shared-formatter rows → deferred

| Field | DICOM source | Encoding (standard) | Encoding (code) | Verdict |
|---|---|---|---|---|
| header `Calling AE Title:` / `Called AE Title:` / `Move Destination:` (shared `NetworkConsole.retrieveHeader`) | PS3.8 Table 9-11; (0000,0600) | names as PS3.6/PS3.7 | same | match |
| header `Level:` `Study` / `Series` / `Instance` (shared formatter, string chosen by CLI) | Query/Retrieve Level (0008,0052) | `STUDY` / `SERIES` / `IMAGE` (Table C.6.1-1) | display label; wire value is `QueryLevel.rawValue` (`IMAGE`) | match on the wire; display label "Instance" → deferred D-QR2 (shared console wording, kept for DICOMStudio parity) |
| `C-MOVE Result:` → `Status:` | Status (0000,0900) | PS3.4 Table C.4-2 "Service Status" + "Further Meaning" | `RetrieveStatusText.describe`: e.g. `Failure (0xA702): Refused: Out of resources - Unable to perform sub-operations`, `Warning (0xB000): Sub-operations Complete - One or more Failures`, `Success (0x0000): Sub-operations Complete - No Failures` | **fixed** (was `DIMSEStatus.description`: "Warning: Coercion of data elements (0xB000)", "Failed: Out of resources (0xA702)") |
| `C-MOVE Result:` → `Completed:` / `Failed:` / `Warnings:` (shared formatter) | (0000,1021) (0000,1022) (0000,1023) | Number of Completed / Failed / Warning Sub-operations (PS3.7 Table 9.3-10) | short labels | shared → deferred D-QR2 |
| stderr `Final C-MOVE|C-GET response: <status> — Number of Completed Sub-operations: n, Number of Failed Sub-operations: n, Number of Warning Sub-operations: n` | Tables 9.3-10 / 9.3-7 | PS3.7 names | PS3.7 names | **fixed** (was "n completed, n failed, n warning(s)") |
| stderr `Failed SOP Instance UID List (0008,0058), n UID(s):` + one UID per line | (0008,0058), PS3.4 C.4.2.1.4.2 | attribute name | attribute name + tag | **fixed** (was "Failed SOP Instance UIDs (n):") |
| error `C-MOVE final response <status> (<counters>); Failed SOP Instance UID List (0008,0058): …` (`RetrieveError.retrievalFailed`) | as above | — | PS3.4 / PS3.7 wording | **fixed** |
| `C-GET completed — n file(s) received` / 0-instance warning (shared `cGetSummary`) | — | — | — | plumbing |
| `Bulk retrieval complete: Success n / Failed n` (stderr) | — | — | — | plumbing |
| Part 10 file per received instance | PS3.10 Table 7.1-1 | Type 1: group length, (0002,0001), (0002,0002), (0002,0003), (0002,0010), (0002,0012) | all 6 written, no Type 3 rows; Implementation Class UID literal `1.2.826.0.1.3680043.9.7433.1.1` not compared with DICOMKit's registered one | match (6/6 Type 1) |
| exit `0` | final status Success (0000) and Number of Failed Sub-operations = 0 (PS3.4 C.4.2.2.1 / C.4.3.2.1) | — | `RetrieveResult.isSuccess` | match |
| exit `1` | Warning B000 / Failure A701 A702 A801 A900 Cxxx / Cancel FE00, any failed sub-operation, transport error, bulk partial failure | — | thrown `RetrieveError` → ArgumentParser exit 1 | match (README now documents it) |
| exit `64` | usage (no move-dest with c-move, series without study, …) | — | `ValidationError` → `ExitCode.validationFailure` | match (documented) |
| JSON | none emitted | — | — | — |

**Findings**
- Status text: `DIMSEStatus.description` is service-agnostic; for C-MOVE/C-GET 5 of the 8 final codes were worded differently from Table C.4-2/C.4-3 (A701, A702, A801, A900, B000, Cxxx). Fixed in the tool with `RetrieveStatusText` (17 rows generated from the DocBook; pinned by `QueryRetrieveCLIStandardTests.testRetrieveStatusTextCarriesPS34Tables2026a`). The engine text itself → deferred D-QR1.
- Counters and the Failed SOP Instance UID List were labelled informally → PS3.7 / PS3.6 names (tool-local lines).
- Help: levels, SOP Classes, Move Destination, ports, `--hierarchical` (said patient/study/series; the code lays out study/series and only for C-GET).
- README: `url` row was stale (`pacs://host:port`), exit codes now list 0 / 1 / 64 with the status classes.
- `Tests/DICOMToolsTests/DICOMRetrieveTests.swift` is not compiled by any target (`DICOMToolsTests` is commented out in Package.swift; the file is in `DICOMViewerTests`' exclude list) — its 32 tests have never run. Tests for this pass were placed in `Tests/DICOMNetworkTests/QueryRetrieveCLIStandardTests.swift` (compiled, no Package.swift change). Orchestrator: worth a report note for every dicom-* tool whose tests live there.

**Tests** — `swift test --filter QueryRetrieveCLIStandardTests`: 6 passed, 0 failed, 0 skipped (`testRetrieveStatusTextCarriesPS34Tables2026a`, `testRetrieveStatusTextCopiesAreIdentical`, `testRetrieveHelpNamesStandardConcepts`, `testRetrieveExitCodesForUsageAndTransportFailure` spawn the built product; usage → 64, refused connection with `--timeout 2` → 1). `swift build --product dicom-retrieve` ok. `check_nema_markers.py Sources/dicom-retrieve`: 3 files, 3 markers (2026a). `diff_cli.py --tool dicom-retrieve`: 0 FAIL.

**Deferred findings (DICOMNetwork)**
| ID | Module | file:line | Problem | Standard | Severity |
|---|---|---|---|---|---|
| D-QR1 | DICOMNetwork | Sources/DICOMNetwork/DIMSEStatus.swift:262-305 | `description` is service-agnostic: 0xB000 "Warning: Coercion of data elements" (the C-STORE meaning) where C-MOVE/C-GET mean "Sub-operations Complete - One or more Failures [or Warnings]"; 0xA701/0xA702 "Failed: Out of resources" vs "Refused: Out of resources - Unable to calculate number of matches / Unable to perform sub-operations"; 0xA801 "Failed: Move destination unknown" vs "Refused: Move Destination unknown"; 0xA900 "Identifier/Data does not match SOP Class" vs "Data Set does not match SOP Class"; Cxxx "unable to process / cannot understand" vs "Failed: Unable to process". A service-aware description (see P-QR-STATUS-TEXT) would fix the app console too. | PS3.4 2026a Tables C.4-2, C.4-3 | low (text) |
| D-QR2 | DICOMNetwork | Sources/DICOMNetwork/NetworkConsoleFormatter.swift:174-231 | `retrieveHeader` prints the level as "Instance" (value is IMAGE, Table C.6.1-1); `cMoveResult` labels the counters "Completed:/Failed:/Warnings:" instead of Number of Completed / Failed / Warning Sub-operations; `Remaining` (0000,1020) is never shown. Shared with DICOMStudio, so not changed in the CLI. | PS3.4 Table C.6.1-1; PS3.7 Table 9.3-10 | low |

**P-items**
- P-QR-STATUS-TEXT: hoist `RetrieveStatusText` (PS3.4 Tables C.4-2 / C.4-3 wording, PS3.7 counter names) into DICOMNetwork as public API so `DIMSEStatus` / `NetworkConsole` and DICOMStudio print the same text as the CLI; until then the CLI `Status:` line differs from the in-app console.
- P-RETRIEVE-PRIORITY: `--priority low|medium|high` (PS3.7 Table 9.3-9: LOW 0002H / MEDIUM 0000H / HIGH 0001H) needs `DICOMRetrieveService.move*/get*` to take a `DIMSEPriority` (public API; engine hardcodes `.medium`).
- P-RETRIEVE-EXTNEG: relational-retrieve / Enhanced Multi-Frame Image Conversion (PS3.4 Table C.5-1 items 1, 5) need engine API before a flag can exist.

**Markers**
- `Sources/dicom-retrieve/DICOMRetrieve.swift`: `// NEMA-verified: 2026a, checked 2026-10-01 — option surface compared with PS3.4 2026a: the 3 retrieve levels and their unique keys (Table C.6.1-1 STUDY/SERIES/IMAGE; Table C.6-5 Study Instance UID U key; C.4.2.2.1 / C.4.3.2.1 one unique key per level above the retrieve level), the 2 methods and their SOP Classes (Table C.6.2.3-1, Study Root MOVE/GET), Move Destination (0000,0600) per PS3.7 Table 9.3-9, ports 104 / 11112 per PS3.8 9.1.2; host, --called-aet default, --output, --timeout, --parallel, --hierarchical, --verbose are plumbing`
- `Sources/dicom-retrieve/RetrieveExecutor.swift`: `// NEMA-verified: 2026a, checked 2026-10-01 — final-status handling checked against PS3.4 2026a Tables C.4-2 / C.4-3 (status wording via RetrieveStatusText, success = 0000 with no failed sub-operations per C.4.2.2.1 / C.4.3.2.1), the four counters against PS3.7 2026a Tables 9.3-7 / 9.3-10, Failed SOP Instance UID List (0008,0058) against C.4.2.1.4.2; the Part 10 wrapper writes the 6 Type 1 rows of PS3.10 2026a Table 7.1-1 (…) and no Type 3 row`
- `Sources/dicom-retrieve/RetrieveStatusText.swift`: `// NEMA-verified: 2026a, checked 2026-10-01 — the 9 C-MOVE rows of PS3.4 2026a Table C.4-2 and the 8 C-GET rows of Table C.4-3 (Service Status, Further Meaning, Status Code) generated from the DocBook by Scripts/nema_docbook.py, 17 of 17 carried verbatim; the sub-operation counter names are those of PS3.7 2026a Tables 9.3-7 / 9.3-10. Byte-identical copy in Sources/dicom-qr and Sources/dicom-retrieve (pinned by DICOMRetrieveTests).`

### dicom-qr

Commands: dicom-qr, query (default), resume · files: DICOMQR.swift (C2), RetrieveStatusText.swift (A, byte-identical copy of dicom-retrieve's) · README.md
Commits: 0b5a61a (fix(cli): dicom-qr exits 1 when a study fails; status per PS3.4 2026a Tables C.4-2 / C.4-3; resume --timeout), HEAD docs commit (dicom-qr README no longer claims --parallel runs retrievals concurrently)
Standard dumped by script: PS3.4 2026a Table C.6-5 (Study level keys, Study Root), Tables C.4-2 / C.4-3, C.6.1-1, C.6.2.3-1, C.5-1; PS3.7 Tables 9.3-9 / 9.3-10 / 9.3-7; PS3.6 Table A-1 Q/R rows; PS3.8 9.1.2; PS3.10 Table 7.1-1; sections C.2.2.2.4 (wild card), C.2.2.2.5 (range), C.4.1.1.3.1, C.4.2.2.1, C.4.3.2.1.

**Input contract** — matched 10, wrong 0, missing 0, extra 1 (`--parallel`, accepted with no effect), plumbing 17

| Option | DICOM concept | 2026a reference | Allowed per standard | Code accepts | Default (std) | Default (code) | Verdict |
|---|---|---|---|---|---|---|---|
| `<host>` | TCP address of the SCP | PS3.8 9.1.2 | — | `host[:port]`, `pacs://` stripped | — | — | plumbing |
| `--port` | DICOM UL port | PS3.8 9.1.2 (104 well-known, 11112 registered) | — | `UInt16?` | none | 11112 | plumbing; help cites PS3.8 |
| `--aet` | Calling AE Title | PS3.8 Table 9-11; PS3.5 VR AE | AE | `String` → `AETitle` (throws on >16) | — | required | plumbing |
| `--called-aet` | Called AE Title | same | AE | `String` | — | `"ANY-SCP"` | plumbing |
| `--move-dest` | Move Destination (0000,0600) | PS3.7 Table 9.3-9; PS3.4 C.4.2.2.1 | AE of a Storage SCP | `String?`, required for c-move (exit 64) | — | — | match |
| `--method` | Study Root QR IM - MOVE / - GET | PS3.4 Table C.6.2.3-1 | the two SOP Classes | `"c-move"` / `"c-get"` (String, lower-cased) | none | `"c-move"` | match (help names the SOP Classes) |
| `--patient-name` | Patient's Name (0010,0010), R key at STUDY level; wild card `*` `?` | PS3.4 Table C.6-5; C.2.2.2.4 | PN, wild cards | `String?`, upper-cased before sending (C.2.2.2.4 leaves PN case handling to the SCP, so harmless) | — | — | match |
| `--patient-id` | Patient ID (0010,0020), R | Table C.6-5 | LO | `String?` | — | — | match |
| `--study-date` | Study Date (0008,0020), R; range matching | Table C.6-5; C.2.2.2.5: `d1-d2`, `-d1`, `d1-` | DA / range | `String?` passed through (all three range forms reach the SCP) | — | — | match (help listed only `d1-d2`; now all three forms) |
| `--study-uid` | Study Instance UID (0020,000D), U | Table C.6-5 | UI | `String?` | — | — | match |
| `--accession-number` | Accession Number (0008,0050), R | Table C.6-5 | SH | `String?` | — | — | match |
| `--modality` | Modalities in Study (0008,0061), O key at STUDY level | Table C.6-5; PS3.3 C.7.3.1.1.1 Defined Terms (shared `ModalityOptionValidator`, verified with its module) | CS Defined Terms | any; unknown value warns, `--strict-modality` rejects | — | — | match (the key sent is (0008,0061), not Modality (0008,0060)) |
| `--strict-modality` | — | — | — | `Bool` | — | false | plumbing |
| `--study-description` | Study Description (0008,1030), O; wild card | Table C.6-5; C.2.2.2.4 | LO | `String?` | — | — | match |
| `-o, --output` | — | PS3.10 (Part 10 files from C-GET) | — | path | — | `"."` | plumbing |
| `--hierarchical` | `<output>/<StudyInstanceUID>/` (C-GET only) | — | — | `Bool` | — | false | plumbing; help said Patient/Study/Series — fixed |
| `--interactive` / `--auto` / `--review` | — | — | — | exactly one (exit 64) | — | false | plumbing |
| `--save-state` | — | — | — | path | — | — | plumbing |
| `--timeout` | socket timeout | — | — | `Int` s | — | 60 | plumbing |
| `--parallel` | "Maximum concurrent retrievals" | — | — | `Int`, parsed and never read: `query` retrieves sequentially | — | 1 | extra (no effect) — P-QR-PARALLEL; README corrected |
| `--validate` | Part 10 read of the received files | PS3.10 | — | `Bool` | — | false | plumbing |
| `--transfer-syntax` | Transfer Syntax proposed for the C-GET storage contexts | PS3.4 C.4.3.2.1; PS3.6 Table A-1 via shared parser | registered TS | shared `TransferSyntax.parse`; unknown → exit 64 | — | nil | match |
| `--verbose` | — | — | — | `Bool` | — | false | plumbing |
| `--include-parent-keys` | parent-level return keys at SERIES/IMAGE (non-baseline) | PS3.4 C.4.1.1.3.1 / C.6.2.1.? | — | `Bool`, no effect at STUDY level (documented in help) | — | false | plumbing |
| `resume -s, --state` | — | — | — | path to the state JSON | — | required | plumbing |
| `resume --timeout` (new, additive) | socket timeout | — | — | `Int` s | — | 60 (was hard-coded 60) | plumbing |
| `resume --verbose` | — | — | — | `Bool` | — | false | plumbing |
| *(no option)* Query/Retrieve Level | always STUDY | PS3.4 Table C.6.1-1 | PATIENT/STUDY/SERIES/IMAGE | `QueryLevel.study` → `"STUDY"`; retrieve `RetrieveKeys(level: .study)` | — | STUDY | match |
| *(no option)* Priority / extended negotiation | as dicom-retrieve | PS3.7 Table 9.3-9; PS3.4 Table C.5-1 | — | not exposed (engine MEDIUM, baseline) | — | — | n/a (P-RETRIEVE-PRIORITY, P-RETRIEVE-EXTNEG) |
| *(resume)* Instance Availability (0008,0056) / Retrieve AE Title (0008,0054) | optional return keys the SCP may add | PS3.4 Table C.6-5 ("All other Attributes at Study Level", O); PS3.3 C.4.23 | — | not requested, not stored; `resume` retrieves from the saved host/port/calledAE | — | — | n/a (documented in README Limitations) |

**Output contract** — matched 12, wrong 0 (4 fixed), missing 0, extra 0, plumbing 6; shared-formatter rows → deferred

| Field | DICOM source | Encoding (standard) | Encoding (code) | Verdict |
|---|---|---|---|---|
| header (shared `qrHeader`): `Calling AE Title:` `Called AE Title:` `Method:` `Move Destination:` `Filters:` | PS3.8 Table 9-11; (0000,0600) | — | — | match |
| `Found n study(ies):` / `No studies found …` | C-FIND Pending/Success (Table C.4-1) | — | counts of FF00/FF01 Identifiers | plumbing |
| study entry (shared `qrStudyEntry`): `[i] <PatientName> (ID: <PatientID>)`, `Study:`, `Date:`, `Modality: <Modalities in Study>`, `UID:` | (0010,0010) (0010,0020) (0008,1030) (0008,0020) (0008,0061) (0020,000D) | — | label `Modality:` shows Modalities in Study (0008,0061) | match except the label → deferred D-QR2 (shared) |
| `[i/n] Retrieving: <name> — <uid>` then `  ✅ Success` / `  ❌ Failed: <error>` | — | — | — | plumbing |
| `❌ Failed: Retrieval failed: C-MOVE final response <Service Status (code): Further Meaning> (Number of Completed Sub-operations: n, Number of Failed Sub-operations: n, Number of Warning Sub-operations: n)` | Status (0000,0900); (0000,1021-1023) | PS3.4 Tables C.4-2 / C.4-3; PS3.7 Table 9.3-10 | `RetrieveStatusText` | **fixed** (was "status <DIMSEStatus>: n completed, n failed, n warning(s)") |
| stderr `  Failed SOP Instance UID List (0008,0058):` + UIDs | (0008,0058), C.4.2.1.4.2 | attribute name | name + tag | **fixed** (was "Failed SOP Instance UIDs:") |
| `Retrieval Summary: Total / Success / Failed` | — | — | — | plumbing |
| stderr `Error: Retrieval incomplete: n study(ies) succeeded, n failed` + exit 1 | final status not Success / failed sub-operations (C.4.2.2.1 / C.4.3.2.1) | — | `DICOMQRError.retrievalIncomplete` thrown after the summary (query and resume) | **fixed** (both exited 0 with failures) |
| `Validating retrieved files` block | PS3.10 read | — | — | plumbing |
| state JSON `studies[].studyInstanceUID`, `patientName`, `patientID`, `studyDate`, `studyDescription`, `accessionNumber` | PS3.6 keywords StudyInstanceUID, PatientName, PatientID, StudyDate, StudyDescription, AccessionNumber | keyword | lower-camel keyword (shared `QRStudyInfo`) | match |
| state JSON `studies[].modality` | written from (0008,0060) Modality, a Series-level attribute; the STUDY query carries Modalities in Study (0008,0061) | Table C.6-5 | value is nil unless the SCP volunteers (0008,0060) | shared type → deferred D-QR3; rename → P-QR-STATE-MODALITIES |
| state JSON `host`, `port`, `callingAE`, `calledAE`, `moveDestination`, `method` (`c-move`/`c-get`), `outputPath`, `hierarchical` | — | — | shared `QRRetrievalState` | plumbing |
| Part 10 file per received instance (C-GET) | PS3.10 Table 7.1-1 | 6 Type 1 rows | all 6 written | match |
| exit `0` | every selected study: Success (0000) and no failed sub-operations | — | — | match |
| exit `1` | any study with Warning / Failure / Cancel / failed sub-operation / transport error; any other error | — | thrown error → 1 | match (**fixed**, documented) |
| exit `64` | usage: no mode, several modes, c-move without `--move-dest`, unknown method / transfer syntax, bad modality under `--strict-modality` | — | `ValidationError` | match (documented) |

**Findings**
- Exit code: `query` and `resume` counted failures, printed the summary and returned → exit 0. Fixed (`retrievalIncomplete` thrown after the summary; pinned by `testQRResumeExitsNonZeroWhenAStudyFails`, which spawns `dicom-qr resume` against a refused port with the new `--timeout 2`).
- `resume` had the timeout hard-coded at 60 s; `--timeout` added (additive).
- Status / counter / Failed SOP Instance UID List wording as for dicom-retrieve (byte-identical `RetrieveStatusText`, pinned by `testRetrieveStatusTextCopiesAreIdentical`).
- Help: the 7 match keys now carry their tags; `--study-date` lists the three range forms of C.2.2.2.5; `--hierarchical` said Patient/Study/Series (code: `<output>/<StudyInstanceUID>/`, C-GET only).
- `--parallel` is parsed but never read (sequential loop) — README corrected; the option itself is a P-item (P-QR-PARALLEL).
- `Tests/DICOMToolsTests/DICOMQRTests.swift` (31 tests) is not compiled by any target — same as dicom-retrieve; tests placed in `Tests/DICOMNetworkTests/QueryRetrieveCLIStandardTests.swift`.

**Tests** — `swift test --filter QueryRetrieveCLIStandardTests`: 6 passed (2 dicom-qr spawn tests: `testQRQueryHelpNamesStandardConcepts`, `testQRResumeExitsNonZeroWhenAStudyFails`; 2 table tests shared). `swift build --product dicom-qr` ok. `check_nema_markers.py Sources/dicom-qr`: 2 files, 2 markers. `diff_cli.py --tool dicom-qr`: 0 FAIL (documented defaults 5/5).

**Deferred findings (new, DICOMNetwork)**
| ID | Module | file:line | Problem | Standard | Severity |
|---|---|---|---|---|---|
| D-QR3 | DICOMNetwork | Sources/DICOMNetwork/QRSessionState.swift:25 (`QRStudyInfo.modality = result.modality`) and :117 (`GenericQueryResult.modality` → (0008,0060)) | The dicom-qr state file stores Modality (0008,0060), a Series-level attribute, while the STUDY-level C-FIND requests Modalities in Study (0008,0061) (Table C.6-5); the saved value is empty unless the SCP volunteers (0008,0060). The console entry correctly shows `modalitiesInStudy`. | PS3.4 2026a Table C.6-5 | low |
(D-QR1, D-QR2 as in the dicom-retrieve section.)

**P-items**
- P-QR-STATE-MODALITIES: add `modalitiesInStudy` to `QRStudyInfo` (shared JSON key; keep `modality` for old files).
- P-QR-PARALLEL: `--parallel` has no effect in `dicom-qr query`; either implement (task group as in dicom-retrieve) or deprecate the option.
- P-QR-STATUS-TEXT, P-RETRIEVE-PRIORITY, P-RETRIEVE-EXTNEG: as in dicom-retrieve.

**Markers**
- `Sources/dicom-qr/DICOMQR.swift`: `// NEMA-verified: 2026a, checked 2026-10-01 — the 7 match keys compared with PS3.4 2026a Table C.6-5 (Study Root, Study level: 4 R keys, 1 U key, 2 O keys — Modalities in Study (0008,0061) carries --modality), wildcard / range matching with C.2.2.2.4 / C.2.2.2.5, Query/Retrieve Level STUDY with Table C.6.1-1, methods with Table C.6.2.3-1 (Study Root MOVE/GET), Move Destination (0000,0600) with PS3.7 Table 9.3-9, final-status handling with Tables C.4-2 / C.4-3 via RetrieveStatusText, ports 104 / 11112 with PS3.8 9.1.2; the Part 10 wrapper writes the 6 Type 1 rows of PS3.10 2026a Table 7.1-1; modes, state file, --output, --timeout, --parallel, --validate, --verbose are plumbing`
- `Sources/dicom-qr/RetrieveStatusText.swift`: identical to dicom-retrieve's.

**For Scripts/diff_cli.py (orchestrator)**: the ATTR regex already handles the 3-level nesting of `--modality` / `--transfer-syntax` (both listed now; no edit made). The output-contract skeleton lists `JSON \`Automatic\`` / `JSON \`Interactive\`` for dicom-qr — those are ternary string literals (`modeLabel`), not JSON keys. Consider a check "CLI final-status strings are PS3.4 Table C.4-2/C.4-3 Further Meaning" reading `RetrieveStatusText.swift`, like `testRetrieveStatusTextCarriesPS34Tables2026a`.

### dicom-mwl

Commands: dicom-mwl, query · files: DICOMMWLCommand.swift · bucket C2 (thin adapter over DICOMNetwork.WorklistQueryKeys / DICOMModalityWorklistService / NetworkConsole; the help and discussion carry standard-derived text)

Compared (all dumped by `Scripts/nema_docbook.py` / `sect.py` from the 2026a DocBook): PS3.4 Table K.6-1 (139 rows — the 9 matching keys the options set, their R/O type and the matching allowed per row), Table K.6-1a, Table K.4-1 (7 C-FIND status rows), Table K.6.1.4-1 (SOP Class UID), C.2.2.2.5.1 / C.2.2.2.5.2 / C.2.2.2.5.4 (DA/TM Range Matching, combined date-time with Extended Negotiation), PS3.3 Table C.4-10 (0040,0020) Defined Terms (5), PS3.5 Table 6.2-1 (AE, DA, TM), PS3.6 Table 6-1 (38 JSON keys vs keywords) and Table A-1 (1.2.840.10008.5.1.4.31), PS3.7 Annex C status names (27 codes), PS3.8 9.1.1 (port 104 / 11112). `Scripts/diff_cli.py --tool dicom-mwl`: 11 checks ok, 0 FAIL (18 options extracted).

**Input contract**

| Option | DICOM concept | 2026a reference | Allowed per standard | Code accepts | Default (std) | Default (code) | Verdict |
|---|---|---|---|---|---|---|---|
| `<host>` | TCP transport address | PS3.8 9.1.1 | `host[:port]`, `pacs://` prefix stripped | `String` | — | required | plumbing |
| `--port` | TCP port | PS3.8 9.1.1 (well-known 104; 11112 is the IANA "dicom" registered port, not in the PS3.8 text) | 1–65535 | `UInt16?` | 104 recommended | 11112 | plumbing |
| `--aet` | Calling AE Title | PS3.8 7.1.1.3; PS3.5 Table 6.2-1 VR AE | ≤16 bytes, no backslash/control chars, not all spaces | `String` (DICOMNetwork.AETitle) | none | required | plumbing |
| `--called-aet` | Called AE Title | PS3.8 7.1.1.4; PS3.5 Table 6.2-1 VR AE | as above | `String` | none | `"ANY-SCP"` (tool convention) | plumbing |
| `--date` | Scheduled Procedure Step Start Date (0040,0002), R key in SPS Sequence | PS3.4 Table K.6-1 row 4: Single Value or Range Matching; C.2.2.2.5.1; PS3.5 Table 6.2-1 DA (YYYYMMDD, 18 bytes max with `-`) | `YYYYMMDD`, `D1-D2`, `D1-`, `-D2` | same, plus `today`/`tomorrow` shorthands resolved to YYYYMMDD (WorklistQueryKeys.resolveScheduledDate) | — | absent (Universal Matching) | match |
| `--time` | Scheduled Procedure Step Start Time (0040,0003), R key | PS3.4 Table K.6-1 row 5 (Single Value or Range Matching; combined with the date range as one interval — remark under (0040,0003), C.2.2.2.5.4); C.2.2.2.5.2 (no crossing midnight); PS3.5 Table 6.2-1 TM (HH, HHMM, HHMMSS[.FFFFFF]) | as PS3.5 TM, `T1-T2`, `T1-`, `-T2` | same (resolveScheduledTime; short forms and fraction tested in WorklistQueryKeysTests) | — | absent | match — help/discussion cited "PS3.4 K.6.1" (an overview clause); now cites Table K.6-1 remark + C.2.2.2.5.x and the TM forms (fixed) |
| `--station` | Scheduled Station AE Title (0040,0001), R key | PS3.4 Table K.6-1 row 3: Single Value Matching only; PS3.5 VR AE 16 bytes | AE Title (wildcards `*`/`?` are tolerated by the shared validator although K.6-1 says Single Value only) | `String?` (validateScheduledStationAETitle) | — | absent | match (wildcard tolerance is engine leniency, noted) |
| `--patient` | Patient's Name (0010,0010), R key | PS3.4 Table K.6-1 row 86: Single Value or Wild Card Matching | PN with `*`/`?` | `String?` | — | absent | match |
| `--patient-id` | Patient ID (0010,0020), R key | PS3.4 Table K.6-1 row 87: Single Value Matching | LO | `String?` | — | absent | match |
| `--modality` | Modality (0008,0060), R key | PS3.4 Table K.6-1 row 6: Single Value Matching; PS3.3 C.7.3.1.1.1 Defined Terms | Defined Terms | `String?` via DICOMCore.ModalityOptionValidator (checked against PS3.3 2026a in DICOMCore's report) | — | absent | match (shared) |
| `--strict-modality` | reject non-Defined-Term modality | PS3.3 C.7.3.1.1.1 (Defined Terms are extensible) | — | `Bool` | — | false | plumbing |
| `--sps-status` | Scheduled Procedure Step Status (0040,0020), O key type 3 | PS3.4 Table K.6-1 row 35; PS3.3 Table C.4-10 Defined Terms: SCHEDULED, ARRIVED, READY, STARTED, DEPARTED | Defined Terms (extensible) | any string, sent as given; now warns on stderr when not one of the 5 terms | — | absent | **wrong → fixed**: help and discussion listed "SCHEDULED, IN PROGRESS, DISCONTINUED, COMPLETED" (three are PPS Status values, Table C.4-14) |
| `--accession-number` | Accession Number (0008,0050), O key type 2 | PS3.4 Table K.6-1 row 64 | SH | `String?` | — | absent | match |
| `--performing-physician` | Scheduled Performing Physician's Name (0040,0006), R key type 2 | PS3.4 Table K.6-1 row 7: Single Value or Wild Card Matching | PN with `*`/`?` | `String?` | — | absent | match |
| `--specific-character-set` | Specific Character Set (0008,0005) of the Identifier | PS3.4 Table K.6-1a (1C in the C-FIND Identifier); PS3.5 6.1.2 | Defined Terms of PS3.5 Table 6.1-1 | `String?` (engine chooses the narrowest set otherwise) | absent for ISO-IR 6 | auto | match (shared) |
| `--timeout` | ARTIM / socket timeout | PS3.8 9.1.2 | seconds | `Int` | — | 60 | plumbing |
| `-v, --verbose` | — | — | — | `Bool` | — | false | plumbing |
| `--json` | JSON rendering of the responses | — | — | `Bool` | — | false | plumbing |

Counts: matched 10, wrong 1 (fixed), missing 0, extra 0, plumbing 7.

**Output contract**

| Field | DICOM source | Encoding (standard) | Encoding (code) | Verdict |
|---|---|---|---|---|
| JSON keys `PatientName PatientID PatientBirthDate PatientSex AccessionNumber StudyInstanceUID ReferringPhysicianName RequestedProcedureID RequestedProcedureDescription Modality ScheduledStationAETitle ScheduledStationName RequestedProcedurePriority RequestedContrastAgent PreMedication PatientWeight PatientSize PregnancyStatus MedicalAlerts Allergies SpecialNeeds PatientState AdmissionID CurrentPatientLocation RequestingPhysician` and nested `CodeValue CodingSchemeDesignator CodeMeaning` (28) | the return keys of Table K.6-1 | PS3.6 Table 6-1 keywords | NetworkConsole.mwlJSON (shared) — identical to the keyword | match |
| JSON keys `SPSStartDate SPSStartTime SPSStatus SPSID SPSDescription SPSLocation ScheduledPerformingPhysician RequestedProcedureCode ScheduledProtocolCodes ReferencedStudySOPInstanceUID` (10) | (0040,0002) (0040,0003) (0040,0020) (0040,0009) (0040,0007) (0040,0011) (0040,0006) (0032,1064) (0040,0008) (0008,1110)>(0008,1155) | PS3.6 keywords `ScheduledProcedureStepStartDate … ScheduledPerformingPhysicianName`, `RequestedProcedureCodeSequence`, `ScheduledProtocolCodeSequence`, `ReferencedStudySequence` | abbreviated / flattened names in the shared formatter | not PS3.6 keywords → P-MWL-JSON-KEYS (rename = JSON-key change, not implemented) |
| `PregnancyStatus` value | (0010,21C0) US | PS3.3 C.2-4 Enumerated Values 1–4 | `Int(v)` | match |
| printed labels (`Patient Name:`, `SPS Status:`, `Scheduled Date/Time:`, …) | free-form | — | NetworkConsole.mwlItem (shared) | plumbing |
| C-FIND statuses: Pending FF00/FF01 (items collected), Success 0000, Cancel FE00, A700, A900, Cxxx → `DICOMNetworkError.queryFailed(status)` → "Query failed: <DIMSEStatus>" | C-FIND-RSP Status (0000,0900) | PS3.4 Table K.4-1: A700 "Refused: Out of resources", A900 "Error: Data Set does not match SOP Class", Cxxx "Failed: Unable to process" | DIMSEStatus.description (DICOMNetwork): "Refused: Out of resources (0xA700)" ✓, "Error: Identifier/Data does not match SOP Class (0xA900)", "Failed: unable to process / cannot understand (Cxxx)" | match for A700/FE00/FF00/FF01/0000; A900 / Cxxx wording differs from K.4-1 → deferred (DICOMNetwork, cosmetic) |
| `--date`/`--time`/`--station` validation errors | — | — | ValidationError, exit 64 | plumbing |
| `⚠️ The result count (N) may be capped…` | heuristic | — | shared | plumbing |
| exit codes | — | — | 0 success (also 0 for "No worklist items found."), 64 usage/validation, 1 thrown DICOMNetworkError | plumbing |

Findings:
1. `--sps-status` help/discussion listed PPS Status words as SPS Status values (PS3.3 Table C.4-10 Defined Terms are SCHEDULED, ARRIVED, READY, STARTED, DEPARTED) — fixed in help, discussion and README; a non-Defined-Term value now warns on stderr (still sent, Defined Terms are extensible). Test: `testMWL_helpListsTheScheduledProcedureStepStatusDefinedTerms`, `testMWL_ppsStatusWordAsSPSStatusWarnsBeforeTheQuery`, `testMWL_definedTermDoesNotWarn`.
2. "PS3.4 K.6.1" cited for the combined date+time interval (help, discussion, README): the clause is the remark under (0040,0003) in Table K.6-1 (K.6.1.2.2) and C.2.2.2.5.4 (Extended Negotiation of combined datetime matching) — citations fixed; test `testMWL_helpCitesRangeMatchingClauses`.
3. `--time` help now states the PS3.5 Table 6.2-1 TM forms (HH, HHMM, HHMMSS[.FFFFFF]) the engine already accepts, and that a range never crosses midnight (C.2.2.2.5.2).

Deferred (not fixed here):
| ID | Module | file:line | Problem | Standard ref | Severity |
|---|---|---|---|---|---|
| D79 | DICOMNetwork | Sources/DICOMNetwork/DIMSEStatus.swift:278, :280, :282 | C-FIND failure names differ from the 2026a tables: 0xA900 printed "Error: Identifier/Data does not match SOP Class" (K.4-1: "Error: Data Set does not match SOP Class"); 0x0110 printed "Failed: Unable to process" (PS3.7 C.5.21: "Processing Failure"; "Unable to process" is the Cxxx class of K.4-1) | PS3.4 Table K.4-1; PS3.7 C.5.21 | low (wording) |
| D80 | DICOMNetwork | Sources/DICOMNetwork/NetworkConsoleFormatter.swift:502-547 | 10 of 38 JSON keys are not PS3.6 keywords (see P-MWL-JSON-KEYS); shared with DICOMStudio's MWL panel | PS3.6 Table 6-1 | low (P-item) |
| D81 | DICOMNetwork | Sources/DICOMNetwork/ModalityWorklistService.swift:157-168 | `validateScheduledStationAETitle` tolerates `*`/`?` although Table K.6-1 row 3 allows Single Value Matching only for (0040,0001) | PS3.4 Table K.6-1 | low |

P-items:
- **P-MWL-JSON-KEYS**: rename the 10 abbreviated `--json` keys to the PS3.6 keywords (`SPSStartDate`→`ScheduledProcedureStepStartDate`, `SPSStartTime`→`ScheduledProcedureStepStartTime`, `SPSStatus`→`ScheduledProcedureStepStatus`, `SPSID`→`ScheduledProcedureStepID`, `SPSDescription`→`ScheduledProcedureStepDescription`, `SPSLocation`→`ScheduledProcedureStepLocation`, `ScheduledPerformingPhysician`→`ScheduledPerformingPhysicianName`, `RequestedProcedureCode`→`RequestedProcedureCodeSequence`, `ScheduledProtocolCodes`→`ScheduledProtocolCodeSequence`, `ReferencedStudySOPInstanceUID`→`ReferencedStudySequence[{ReferencedSOPClassUID, ReferencedSOPInstanceUID}]`). Lives in shared `NetworkConsole.mwlJSON` and is parsed by the Studio CLI-parity comparator; keep the old keys as aliases if approved.

Marker: `// NEMA-verified: 2026a, checked 2026-10-01 — the 9 matching keys behind --date/--time/--station/--patient/--patient-id/--modality/--sps-status/--accession-number/--performing-physician diffed against PS3.4 2026a Table K.6-1 (139 rows; matching-key type and allowed matching per row); Range Matching forms against PS3.4 C.2.2.2.5.1/.2 and the combined date-time remark under (0040,0003) in Table K.6-1; SPS Status values against PS3.3 Table C.4-10 (0040,0020) Defined Terms (5: SCHEDULED, ARRIVED, READY, STARTED, DEPARTED); SOP Class UID against PS3.6 Table A-1; DA/TM forms against PS3.5 Table 6.2-1. The 38 JSON keys and the response statuses are shared DICOMNetwork code (NetworkConsole.mwlJSON, DIMSEStatus): 28 keys are PS3.6 keywords, 10 are not (P-item).`

Tests: `Tests/DICOMNetworkTests/MWLMPPSCLIEndToEndTests.swift` (new, spawn-based, 16 tests for both tools; 4 for dicom-mwl) — `swift test --filter MWLMPPSCLIEndToEndTests`: 16 passed, 0 failed. `swift build --product dicom-mwl` ok; `check_nema_markers.py Sources/dicom-mwl`: 1/1.

diff_cli.py note for the orchestrator: `--modality` is declared with `help: ArgumentHelp(stringLiteral: ModalityOptionValidator.helpText(...))`, so the extractor lists it with an empty help column; the `CODE|SCHEME|MEANING` literals (dicom-mpps) are not recognised by the PS3.16 coded-concept check (it reported "matched 0" while the examples were wrong) — a pattern `"(\w+)\|(\w+)\|([^"]+)"` would have caught them.

Commit: f2db8f9 `fix(cli): dicom-mwl SPS Status Defined Terms per PS3.3 Table C.4-10, clause-exact Range Matching citations (2026a)` (also carries the shared test file and the CHANGELOG bullet for both tools).

### dicom-mpps

Commands: dicom-mpps, create, update · files: DICOMMPPSCommand.swift · bucket C2 (adapter over DICOMNetwork.DICOMMPPSService / MPPSStatus / MPPSCodedEntry / NetworkConsole; carries the status-word parser, the CID 9300 examples and, now, the PS3.7 Annex C status names)

Compared (dumped by script from the 2026a DocBook): PS3.4 Table F.7.2-1 (130 rows — N-CREATE/N-SET/Final-State usage of the 24 attributes the options set), Table F.7.2-2 (N-SET 0110/A710), Table F.7.1-1, F.7.2.1.1 note (0040,0281 must be created at N-CREATE), F.7.2.1.2 (N-CREATE only IN PROGRESS), F.7.2.1.3 (0106H on another value), F.7.2.2.2 (final state, no later N-SET); PS3.3 Table C.4-14 (0040,0252) Enumerated Values (3), Table C.2-3 (0010,0040) Enumerated Values (3), Tables C.4-13 / C.4-15 (attribute semantics); PS3.5 Table 6.2-1 (DA, TM, AE); PS3.6 Table 6-1 (the 30 tags cited in help) and Table A-1 (3 UIDs); PS3.7 Annex C C.4.2–C.5.25 (27 status codes with names) and 10.1.5.1.4 (SCP-assigned Affected SOP Instance UID); PS3.16 CID 9300 (6 DCM rows + includes 9301/9302/60), CID 9301 (19 rows), Table D-1 (110500, 110501, 110507, 110513, 110514, 110518, 110526). `Scripts/diff_cli.py --tool dicom-mpps`: 11 checks ok, 0 FAIL (46 options extracted; 2 citations matched).

**Input contract** (plumbing rows `<host>`, `--port`, `--aet`, `--called-aet`, `--timeout`, `-v` are identical to dicom-mwl and appear in both subcommands; counted once)

| Option | DICOM concept | 2026a reference | Allowed per standard | Code accepts | Default (std) | Default (code) | Verdict |
|---|---|---|---|---|---|---|---|
| `<host>` / `--port` / `--aet` / `--called-aet` / `--timeout` / `-v, --verbose` / `--specific-character-set` | as dicom-mwl (PS3.8 9.1.1, 7.1.1.3/4; PS3.5 VR AE; PS3.4 Table F.7.2-1 row 1 for (0008,0005) 1C/1C) | | | | | 11112 / "ANY-SCP" / 60 | plumbing (7) |
| create `--study-uid` | Study Instance UID (0020,000D) in Scheduled Step Attributes Sequence | Table F.7.2-1 row 4: 1/1 N-CREATE | UI | `String` required | — | required | match |
| create `--status` | Performed Procedure Step Status (0040,0252) | Table C.4-14 Enumerated Values IN PROGRESS / COMPLETED / DISCONTINUED; F.7.2.1.2: N-CREATE only "IN PROGRESS"; Table F.7.2-1 row 92 1/1 | IN PROGRESS | `parseStatus`: case-insensitive, space may be `_` or omitted; sends `MPPSStatus.rawValue` = "IN PROGRESS"; create rejects COMPLETED/DISCONTINUED | IN PROGRESS | "IN PROGRESS" | match (tests `testMPPS_createRejectsTerminalStatus`, `_RejectsUnknownStatusWord`, `_updateAcceptsStatusWordSpellings`) |
| create `--modality` | Modality (0008,0060) | Table F.7.2-1 row 105: 1/1 N-CREATE; PS3.3 C.7.3.1.1.1 Defined Terms | Defined Term, Type 1 | was optional (engine sent an empty Type 1 value); **now required** | — | required | **missing → fixed** (`testMPPS_createRequiresModality`) |
| create `--strict-modality` | — | — | — | `Bool` | — | false | plumbing |
| create `--patient-name` | Patient's Name (0010,0010) | Table F.7.2-1 row 32: 2/2 | PN | `String?` | — | empty | match |
| create `--patient-id` | Patient ID (0010,0020) | row 33: 2/2 | LO | `String?` | — | empty | match |
| create `--patient-birth-date` | Patient's Birth Date (0010,0030) | row 45: 2/2; PS3.5 Table 6.2-1 DA 8 bytes fixed | YYYYMMDD | **now validated** 8 digits | — | empty | match (validation added; `testMPPS_createRejectsNonDABirthDate`) |
| create `--patient-sex` | Patient's Sex (0010,0040) | row 46: 2/2; PS3.3 Table C.2-3 Enumerated Values M, F, O | M / F / O | **now validated** (case-insensitive, upper-cased) | — | empty | match (validation added; `testMPPS_createRejectsPatientSexOutsideEnumeratedValues`) |
| create `--sps-id` | Scheduled Procedure Step ID (0040,0009) in (0040,0270) | row 27: 2/2 | SH | `String?` | — | empty | match |
| create `--accession-number` | Accession Number (0008,0050) in (0040,0270) | row 8: 2/2 | SH | `String?` | — | empty | match |
| create `--requested-procedure-id` | Requested Procedure ID (0040,1001) in (0040,0270) | row 23: 2/2 | SH | `String?` | — | empty | match |
| create `--requested-procedure-description` | Requested Procedure Description (0032,1060) | row 26: 2/2 | LO | `String?` | — | empty | match |
| create `--sps-description` | Scheduled Procedure Step Description (0040,0007) | row 28: 2/2 | LO | `String?` | — | empty | match |
| create `--referenced-study-uid` | Referenced SOP Instance UID (0008,1155) in Referenced Study Sequence (0008,1110) | rows 5–7: 2/2, item 1/1 | UI | `String?` | — | empty sequence | match |
| create `--study-id` | Study ID (0020,0010) | row 106: 2/2 | SH | `String?` | — | empty | match |
| create `--station-name` | Performed Station Name (0040,0242) | row 88: 2/2 | SH | `String?` | — | empty | match |
| create `--performed-location` | Performed Location (0040,0243) | row 89: 2/2 | SH | `String?` | — | empty | match |
| create `--procedure-step-id` | Performed Procedure Step ID (0040,0253) | row 86: 1/1 | SH | `String?` | — | "1" (engine) | match |
| create `--procedure-step-description` | Performed Procedure Step Description (0040,0254) | row 93: 2/2 | LO | `String?` | — | empty | match |
| create `--performing-physician` | Performing Physician's Name (0008,1050) in Performed Series Sequence | row 111: 2/2 (inside (0040,0340)); not a root attribute of Table F.7.2-1 | PN | `String?` → engine stores it on the step; `test_nCreate_doesNotCarryAttributesTheTableDoesNotAllowAtRoot` pins it off the root | — | empty | match (shared) |
| update `--mpps-uid` | Requested SOP Instance UID of the N-SET | PS3.7 10.3.5 Table 10.3-5; PS3.7 10.1.5.1.4 (SCP may assign the UID at N-CREATE — the create path prints the assigned UID) | UI | `String` required | — | required | match |
| update `--status` | Performed Procedure Step Status (0040,0252) | Table F.7.2-1 row 92 N-SET 3/1 final; F.7.2.2.2 COMPLETED / DISCONTINUED final; F.7.2.1.1 note: COMPLETED needs ≥1 Performed Series item | COMPLETED / DISCONTINUED | parseStatus; update rejects IN PROGRESS; engine refuses COMPLETED without a series item before connecting | — | required | match (help now says COMPLETED needs a series item; `testMPPS_updateRejectsInProgress`, `_updateCompletedWithoutSeriesFailsBeforeConnecting`) |
| update `--study-uid` / `--series-uid` / `--image-uid` | Performed Series Sequence (0040,0340) item: Series Instance UID (0020,000E) 1/1, Referenced Image Sequence (0008,1140) > Referenced SOP Instance UID (0008,1155) 1/1 | Table F.7.2-1 rows 110, 114, 118–120 | UI | `--image-uid` repeatable; **now an error** without `--study-uid` and `--series-uid` (references were dropped silently) | — | none | **wrong → fixed** (`testMPPS_updateRejectsImageUIDWithoutSeries`) |
| update `--sop-class-uid` | Referenced SOP Class UID (0008,1150) | row 119: 1/1; PS3.6 Table A-1 | registered SOP Class UID | `String?`; warning when absent (engine defaults to 1.2.840.10008.5.1.4.1.1.7 Secondary Capture Image Storage) | — | SC (engine) | match (default is engine leniency, warned; UIDs/names in help verified: 5.1.4.1.1.2 CT Image Storage, 5.1.4.1.1.7 Secondary Capture Image Storage) |
| update `--protocol-name` | Protocol Name (0018,1030) in Performed Series item | row 112: 1/1 N-CREATE and N-SET | LO | `String?` | — | "UNSPECIFIED" (engine) | match |
| update `--series-description` | Series Description (0008,103E) | row 115: 2/2 | LO | `String?` | — | empty | match |
| update `--operator-name` | Operators' Name (0008,1070) | row 113: 2/2 | PN | `String?` | — | empty | match |
| update `--performing-physician` | Performing Physician's Name (0008,1050) | row 111: 2/2 | PN | `String?` | — | empty | match |
| update `--legacy-nset-scheduled-attributes` | Scheduled Step Attributes Sequence (0040,0270) in N-SET | row 3: "Not allowed" in N-SET | not allowed | `Bool` opt-in for non-conformant SCPs | absent | false | match (opt-in documented as forbidden) |
| update `--discontinuation-reason` | Performed Procedure Step Discontinuation Reason Code Sequence (0040,0281) | row 102: 3/3 (macro F.7.2-1c); PS3.3 C.4-14; PS3.16 CID 9300 "Procedure Discontinuation Reason" (includes CID 9301) | CODE\|SCHEME\|MEANING | `MPPSCodedEntry.parse` (shared); only with DISCONTINUED | — | absent | **wrong examples → fixed**: help/discussion cited "110513 Doctor cancelled procedure", "110514 Equipment failure", "110518 Patient did not arrive"; Table D-1: 110513 = Discontinued for unspecified reason, 110514 = Incorrect worklist entry selected, 110518 = Patient Movement (not in CID 9300); correct codes 110500 Doctor canceled procedure, 110501 Equipment failure, 110507 Patient did not arrive (`testMPPS_helpCitesCID9300CodesWithTheirTableD1Meanings`) |

Counts: matched 23, wrong 2 (fixed), missing 1 (fixed), extra 0, plumbing 8 (the 7 shared plumbing options + `--strict-modality`).

**Output contract**

| Field | DICOM source | Encoding (standard) | Encoding (code) | Verdict |
|---|---|---|---|---|
| `Status: IN PROGRESS` (verbose header), `New Status: COMPLETED|DISCONTINUED` | (0040,0252) | PS3.3 Table C.4-14 Enumerated Values, written with the space | `MPPSStatus.rawValue` (DICOMNetwork) | match |
| `MPPS Instance UID: …` and `note: SCP assigned MPPS SOP Instance UID … (PS3.7 10.1.5.1.4)` | N-CREATE-RSP Affected SOP Instance UID (0000,1000) | PS3.7 10.1.5.1.4: included in the success response when assigned by the SCP | `MPPSOperationResult.sopInstanceUIDWasReassigned` (shared) | match (citation verified) |
| `warning: SCP completed the operation with <status>` | N-CREATE/N-SET-RSP Status (0000,0900) warning class | PS3.7 C.4.2 0107H "Attribute List warning", C.4.3 0116H "Attribute Value out of range", B000-BFFF | was `DIMSEStatus.description` → "Unknown status (0x0107)"; now `DICOMMPPSCommand.describe` → "0107H Attribute List warning (PS3.7 C.4.2)" | **wrong → fixed** in the tool (engine row deferred) |
| `Error: N-CREATE failed: SCP returned <status>` / `N-SET failed: …` | failure class | PS3.7 C.5.6–C.5.25 (0105H–0124H, 0210H–0213H) with the Annex C names; PS3.4 Table F.7.2-2: N-SET 0110 Processing Failure, "Performed Procedure Step Object may no longer be updated", Error ID A710; F.7.2.1.3: N-CREATE with a status other than IN PROGRESS → 0106H Invalid Attribute Value | was "Store failed: Unknown status (0x0106)" (DICOMNetworkError.storeFailed); now the 22 DIMSE-N codes are named from the local PS3.7 table | **wrong → fixed** in the tool; engine rows deferred |
| `--sop-class-uid` warning text naming Secondary Capture (1.2.840.10008.5.1.4.1.1.7) | PS3.6 Table A-1 | "Secondary Capture Image Storage" | abbreviated "Secondary Capture" with the right UID | match |
| `Creating MPPS instance (N-CREATE)...`, `✅ MPPS instance created/updated`, `Referenced Images: N` | — | — | shared NetworkConsole | plumbing |
| exit codes | — | — | 0 success, 64 ValidationError (status words, enumerated values, missing --modality, image/series pairing, SCP failure status), 1 other DICOMNetworkError | plumbing |

Findings (all fixed in the tool, tests in MWLMPPSCLIEndToEndTests): CID 9300 example meanings (3 wrong codes); `create` sent an empty Type 1 Modality when `--modality` was omitted; `--patient-sex` / `--patient-birth-date` unvalidated; `--image-uid` silently dropped without `--study-uid`/`--series-uid`; discussion/README examples showed `update --status COMPLETED` without the Performed Series item the final state requires (the engine refuses it before connecting); DIMSE-N statuses printed as "Unknown status". Behaviour changes are in the CHANGELOG bullet (shared with dicom-mwl).

Deferred (not fixed here):
| ID | Module | file:line | Problem | Standard ref | Severity |
|---|---|---|---|---|---|
| D82 | DICOMNetwork | Sources/DICOMNetwork/DIMSEStatus.swift:124-171, 267-300 | `DIMSEStatus.from` maps no DIMSE-N code except 0110/0111/0112/0118/0122/0213; 0105, 0106, 0107, 0115, 0116, 0117, 0119, 0120, 0121, 0124, 0210-0212 print "Unknown status"; 0110 is named "Failed: Unable to process" instead of "Processing Failure"; the N-SET A710 Error ID (Table F.7.2-2) is never surfaced | PS3.7 Annex C C.4.2-C.5.25; PS3.4 Table F.7.2-2 | medium (every MPPS and Print failure message) |
| D83 | DICOMNetwork | Sources/DICOMNetwork/MPPSService.swift:1034, :1099; DICOMNetworkError.swift:476 | MPPS N-CREATE / N-SET failures are thrown as `DICOMNetworkError.storeFailed` → "Store failed: …" (a C-STORE wording) | PS3.4 F.7.2.1.4 / Table F.7.2-2 | low (wording) |
| D84 | DICOMNetwork | Sources/DICOMNetwork/MPPSService.swift:143, :162, :326 | `MPPSCodedEntry.parseErrorMessage` and doc comments give "110513\|DCM\|Doctor cancelled procedure" and the title "Procedure Discontinuation Reasons"; Table D-1: 110513 = "Discontinued for unspecified reason", 110500 = "Doctor canceled procedure"; CID 9300 title is "Procedure Discontinuation Reason" | PS3.16 CID 9300, CID 9301, Table D-1 | low (message text; shared with the Studio CLI Workshop) |
| D85 | DICOMStudio | Sources/DICOMStudio/Components/CLIWorkshopHelpers.swift:1379-1380 | same wrong placeholder "110513\|DCM\|Doctor cancelled procedure"; and :1217-1221 offers `--modality` as optional ("Any") although `dicom-mpps create` now requires it (Table F.7.2-1 row 105, 1/1) | PS3.16 Table D-1; PS3.4 Table F.7.2-1 | low |
| D86 | DICOMNetwork | Sources/DICOMNetwork/MPPSService.swift:1125-1168 (N-CREATE builder) | the N-CREATE data set never creates (0040,0281) zero-length, yet the N-SET sends it for DISCONTINUED; F.7.2.1.1 note: "If an SCU wishes to use the PPS Discontinuation Reason Code Sequence (0040,0281), it must create that Attribute (zero-length) during N-CREATE"; F.7.2.1.2 "All Attributes shall be created before they can be set" | PS3.4 F.7.2.1.1 note, F.7.2.1.2 | medium (strict SCPs may answer 0105H No such Attribute) |
| D87 | DICOMNetwork | Sources/DICOMNetwork/MPPSService.swift:1163 | `add(0x0008,0x0060,.CS, procedureStep.modality)` writes an empty value when `modality` is nil — a Type 1 attribute (Table F.7.2-1 row 105); the engine's `validate(_:for:)` does not check it (the CLI now refuses before calling) | PS3.4 Table F.7.2-1 | medium |
| D88 | Tests/DICOMStudioTests | NetworkToolWorkshopCLIParityTests.swift:151-157 | parse fixtures use the wrong code/meaning pairs ("110513 Doctor cancelled procedure", "110514 Equipment failure"); harmless for parsing but mislead readers | PS3.16 Table D-1 | low |

P-items: none (no option name, accepted value or JSON key was renamed; the new `--modality` requirement, the M/F/O and DA checks and the image/series pairing error are validations of values the standard already constrained — flagged in the CHANGELOG as behaviour changes for the owner's attention: **P-MPPS-STRICT** if the owner prefers warnings instead of errors).

Marker: `// NEMA-verified: 2026a, checked 2026-10-01 — the 24 attribute-bearing options of create/update diffed against PS3.4 2026a Table F.7.2-1 (130 rows: N-CREATE / N-SET / Final State usage per tag); --status words against PS3.3 Table C.4-14 (0040,0252) Enumerated Values (3) and the N-CREATE/N-SET rules of PS3.4 F.7.2.1.2, F.7.2.1.3, F.7.2.2.2; --patient-sex against PS3.3 Table C.2-3 (0010,0040) Enumerated Values (3); --patient-birth-date against PS3.5 Table 6.2-1 DA; --discontinuation-reason examples against PS3.16 CID 9300 (6 DCM rows + CID 9301 17 rows, Table D-1); SOP Class UIDs against PS3.6 Table A-1 (3); response status names against PS3.7 Annex C C.4.2-C.5.25 (27 codes) and PS3.4 Table F.7.2-2 (A710). Data-set building, the status enum and the console text live in DICOMNetwork (MPPSService, NetworkConsole).`

Tests: `Tests/DICOMNetworkTests/MWLMPPSCLIEndToEndTests.swift` — 12 dicom-mpps tests (16 in the file), all pass; `swift build --product dicom-mpps` ok; `check_nema_markers.py Sources/dicom-mpps`: 1/1.

Commit: 416de5a `fix(cli): dicom-mpps CID 9300 reason examples, Type 1 Modality, M/F/O and DA checks, PS3.7 Annex C status names (2026a)`.


## G2 File and media

Not started.

## G3 Encoding and pixel

Not started.

## G4 Derived objects

Not started.

---

## Verification notes

- `Tests/DICOMToolsTests/` (DICOMQRTests, DICOMRetrieveTests, DICOMDcmdirTests, DICOMAITests, …) is compiled by no target: `DICOMToolsTests` is commented out in Package.swift, so those tests have never run. New per-tool test targets (`dicom-queryTests`, `dicom-sendTests`, `dicom-aiTests`, `dicom-videoTests`) are being added as tools are verified; migrating the orphaned files is a follow-up.
- Nothing in this report is from memory; every row cites the table it was diffed against, or is labelled
  "not checked".
