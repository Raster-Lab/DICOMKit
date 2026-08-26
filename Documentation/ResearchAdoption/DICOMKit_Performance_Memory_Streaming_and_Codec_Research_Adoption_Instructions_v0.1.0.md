---
title: "DICOMKit — Performance, Memory, Streaming and Codec Research Adoption Instructions"
version: "0.1.0"
status: "Project-feed instruction — proposed; human review required"
controlled_date: "2026-08-09"
organisation: "Raster Images"
project: "DICOMKit"
language: "en-GB"
platform_policy: "Swift-native Apple implementation"
companion:
  - "Shared_Performance_Memory_and_Progressive_Delivery_Benchmark_Baseline_v0.1.0.md"
  - "Research_Evidence_Register_v0.1.0.yaml"
---

# DICOMKit — Performance, Memory, Streaming and Codec Research Adoption Instructions v0.1.0

## 1. Repository-agent directive

You are working in the **DICOMKit** repository. Use this instruction to assess and implement research-backed improvements to parsing, bulk-data access, frame selection, codec hand-off, network delivery, memory use and Apple-native execution.

Before changing code:

1. Read the current repository status, public API, conformance statements, DICOM transfer-syntax routing, performance guide, codec integration plans, networking architecture, tests and release policy.
2. Treat existing performance numbers, fixed thresholds and "up to" multipliers as claims to reproduce on named hardware and data—not as design axioms.
3. In particular, do not assume that all files above a fixed size should be memory mapped, or that HTJ2K and Metal multipliers are additive.
4. Produce a source-to-parser-to-codec-to-renderer copy map before proposing a broad refactor.
5. Preserve DICOM semantics, error behaviour, public compatibility and cross-decoder interoperability.
6. Keep DICOMKit as the authoritative native DICOM abstraction for Apple products. Do not introduce dicom.js or a parallel public DICOM object model.

The work shall begin with a gap and benchmark report. Large implementation changes require separate human acceptance.

## 2. Scope

This instruction covers:

- Part 10 and dataset byte access;
- incremental and selective parsing;
- value representation and string decoding;
- sequences and per-frame functional groups;
- pixel and waveform bulk data;
- encapsulated fragment and frame indexing;
- native and compressed frame access;
- DICOMweb and file-based streaming where already within DICOMKit scope;
- caller-owned codec buffers;
- concurrency and cancellation;
- cache and memory-budget behaviour;
- Swift 6.2 ownership and fixed-storage facilities;
- integration contracts for J2KSwift, JLSwift, JXLSwift, JLISwift and Voxelia.

It does not authorise a new private transfer syntax, change the clinical acceptability of lossy compression or make experimental JP3D content standard DICOM.

## 3. Research conclusion for DICOMKit

The literature and platform work indicate that DICOMKit can often gain more by eliminating bytes and objects than by micro-optimising tag lookup:

1. **Source-agnostic streaming and selective access** avoid loading or mapping more data than the request needs.
2. **Borrowed spans and fixed-size parser state** can reduce `Data` slicing, temporary arrays, heap allocation and retain/release traffic [E12–E14].
3. **Lazy bulk-data handles and frame indices** let stack, cine and volume consumers request only the required frame or fragment.
4. **Progressive HTJ2K** can reduce first-useful-image latency when the complete source/server/codec path supports partial resolution [E04, E05].
5. **Caller-owned native-depth buffers** can remove one or more full-frame copies between DICOMKit, codecs and Voxelia.
6. **Memory-budgeted concurrency** is preferable to launching all frame decodes concurrently on unified-memory devices [E09].
7. The same explicit resource-lifetime discipline used in WebGPU systems [E07] transfers to parser, codec and network pipelines even though DICOMKit is native Swift.

## 4. Immediate documentation correction review

Do not silently edit documentation without evidence, but open a corrective review for current performance guidance that:

- recommends memory mapping above fixed file-size thresholds;
- gives fixed percentage memory savings without a reproducible environment;
- implies a simple item-count cache is sufficient;
- suggests processing every multi-frame image with an unbounded task group;
- states that codec and backend speed multipliers are additive;
- recommends transfer syntax by speed alone without compatibility, provenance and use-case constraints.

The revised guide shall distinguish:

- measured fact;
- configuration example;
- heuristic default;
- device-specific qualification;
- hypothesis requiring a benchmark;
- unsupported or experimental path.

## 5. P0 work package A — byte-source abstraction

Introduce or reconcile a `DICOMByteSource` abstraction that decouples parser semantics from one storage strategy.

Illustrative contract:

```swift
public protocol DICOMByteSource: Sendable {
    var count: UInt64? { get }
    var supportsRandomAccess: Bool { get }
    var identity: DICOMSourceIdentity { get }

    func read(
        range: Range<UInt64>,
        into destination: MutableRawBuffer,
        priority: DICOMIOPriority
    ) async throws -> Int

    func borrowedBytes<R>(
        in range: Range<UInt64>,
        _ body: (RawSpan) throws -> R
    ) async throws -> R
}
```

The exact API shall use deployable Swift features and avoid exposing unsafe storage unnecessarily.

Required implementations or adapters:

- in-memory immutable bytes;
- local file with pooled sequential reads;
- memory-mapped window or whole-file mapping where measured;
- network/range source;
- streaming non-seekable source;
- test/fault-injection source;
- encrypted or integrity-checked source where applicable.

### 5.1 Strategy selection

Do not choose by file size alone. Consider:

- sequential metadata scan;
- random frame access;
- repeated reads;
- page-fault behaviour;
- network latency;
- mapping address-space and resident-page pressure;
- mobile memory budget;
- encrypted/compressed container restrictions;
- source lifetime;
- cancellation.

Benchmark at least:

1. `Data(contentsOf:)`;
2. mapped whole-file access;
3. windowed mapping;
4. pooled aligned reads;
5. sequential buffered stream;
6. random selected-frame access.

Store the selected strategy and evidence in telemetry. A heuristic may use size plus access pattern and device profile, but shall have a deterministic override for tests.

## 6. P0 work package B — borrowed parser windows

Use Swift `Span`/`RawSpan` or a deployment-compatible internal equivalent [E12, E14] to parse headers and primitive values without constructing `Data` slices.

Requirements:

- a parser window is lifetime-bound to its byte-source owner or buffer lease;
- byte-order loads are centralised and bounds checked;
- multiplication and offset arithmetic are overflow checked;
- a borrowed value cannot escape into the public dataset model;
- asynchronous suspension does not occur while holding an invalid borrow;
- unsafe unchecked loads, if retained for a proven hot loop, are isolated behind validated preconditions and reference tests.

Suggested parser layers:

1. `DICOMByteCursor` — offset, endianness and bounded primitive loads;
2. `ElementHeaderDecoder` — tag, VR, VL and delimiter state;
3. `DatasetIndexBuilder` — compact element location and structural index;
4. `ValueMaterialiser` — typed value on demand;
5. `BulkDataResolver` — pixel/waveform/document fragments by handle.

Avoid object allocation for each parser state transition.

## 7. P0 work package C — compact dataset index and lazy materialisation

Separate the on-disk/in-source location index from high-level materialised values.

### 7.1 Compact element record

A compact internal record should be sufficient to identify:

- tag;
- explicit or inferred VR;
- value offset and length;
- sequence/item nesting;
- transfer syntax/endianness context;
- undefined-length state;
- bulk-data designation;
- source identity;
- materialisation/cache state.

Use a packed or structure-of-arrays layout only if profiling shows a benefit and maintainability remains acceptable.

### 7.2 Lazy values

Do not eagerly create:

- `String` for every text value;
- arrays for every multi-valued field;
- complete nested object graphs for untouched sequences;
- complete per-frame functional-group models when only selected frames are requested;
- `Data` copies of large OB/OW/OF/OD/OL/OV/UN values.

Materialise on typed access and cache according to cost and expected reuse.

### 7.3 Character sets

String laziness must preserve:

- Specific Character Set;
- value multiplicity and padding;
- person-name component semantics;
- code-extension state where applicable;
- exact raw bytes for round-trip;
- deterministic decoding error policy.

Do not trade conformance for faster UTF-8 assumptions.

## 8. P0 work package D — `BulkDataHandle`

Represent large values as handles rather than copied bytes.

Illustrative concept:

```swift
public struct BulkDataHandle: Sendable, Hashable {
    public let source: DICOMSourceIdentity
    public let offset: UInt64
    public let length: UInt64
    public let vr: DICOMVR
    public let byteOrder: ByteOrder
    public let fragments: FragmentIndex?
    public let provenance: BulkDataProvenance
}
```

A handle shall support:

- bounded read into caller-owned storage;
- stream or chunk iteration;
- checksum;
- cancellation;
- fragment selection;
- source-lifetime validation;
- exact copy for round-trip without decoding;
- explicit prohibition on access after source disposal.

Candidate values:

- Pixel Data;
- Float/Double Pixel Data;
- Waveform Data;
- encapsulated documents;
- spectra or large private values;
- overlays where large;
- large sequence payloads when an index is sufficient.

Public API compatibility may require existing `Data` accessors. Keep them as explicit materialisation operations rather than the internal representation.

## 9. P0 work package E — encapsulated frame and fragment index

Build one validated index and reuse it.

The index shall account for:

- Basic Offset Table;
- Extended Offset Table and lengths;
- empty or absent offset tables;
- fragment item offsets and lengths;
- frame count;
- codestream boundary detection only where permitted and validated;
- multi-fragment frames;
- padding;
- malformed or inconsistent tables;
- transfer-syntax-specific frame semantics.

Requirements:

- index building shall not copy fragment payloads;
- selected-frame access shall read only required fragments;
- repeated frame decode shall reuse the index;
- malformed mappings shall fail closed rather than decode the wrong frame;
- telemetry shall report whether the mapping came from BOT, EOT, validated scan or fallback;
- frame index shall be serialisable only if source identity and checksum make reuse safe.

For very large multi-frame objects, allow index construction to be incremental, with priority for requested frames where the syntax permits.

## 10. P0 work package F — caller-owned codec buffers

Define a shared native buffer contract for codec integrations.

Minimum properties:

- scalar signedness and width;
- bits allocated/stored/high bit;
- dimensions and components;
- planar/interleaved organisation;
- row, plane and frame strides;
- byte order;
- alignment;
- destination capacity;
- owner lifetime;
- cancellation;
- fidelity/progressive state;
- source frame provenance.

Preferred flow:

```text
DICOMByteSource
  → selected compressed fragments
  → codec input view
  → codec writes native-depth samples into caller-owned destination
  → DICOMKit validates receipt and semantics
  → Voxelia or image pipeline borrows/adopts the same storage
```

Avoid:

```text
Data fragment copies
  → codec-owned array
  → DICOMKit array copy
  → RGBA conversion
  → Metal staging copy
```

Allow a copy where API safety or backend requirements demand it, but measure and report it.

The codec adapter shall expose scratch-memory requirements before scheduling when feasible.

## 11. P0 work package G — memory-budgeted codec scheduler

Create or reconcile a scheduler that limits concurrent frame operations by bytes, not only task count.

Inputs:

- compressed input bytes;
- expected decoded bytes;
- per-codec scratch;
- destination buffer bytes;
- pending network bytes;
- pending GPU upload;
- cache occupancy;
- active viewport urgency;
- CPU/GPU backend;
- device memory class;
- cancellation rate.

Policies:

- current frame and near-neighbour frames outrank deep prefetch;
- obsolete requests are cancelled and their buffer leases returned;
- background metadata and thumbnail work yields to interaction;
- a large frame may consume the whole decode budget;
- worker pools are long lived and reuse scratch;
- task groups have bounded width;
- no detached task storm.

On Apple unified memory, CPU decode and GPU rendering share bandwidth [E09]. The scheduler shall react to P95 frame-time degradation rather than maximise decode throughput blindly.

## 12. P0 work package H — progressive HTJ2K contract

DICOM defines two lossless HTJ2K syntaxes, including one optimised for progressive bitstream display, plus a potentially lossy syntax [E05].

DICOMKit shall distinguish:

- complete lossless decode support;
- subresolution decode support;
- quality-layer decode support;
- incremental byte delivery;
- resumable decoder state;
- server/source range support;
- final lossless equality;
- transfer-syntax and progression order.

### 12.1 API requirements

Provide an asynchronous sequence or callback model that may emit:

- resolution level;
- quality level where applicable;
- dirty region;
- final/non-final;
- source byte ranges consumed;
- exact final-state guarantee;
- cancellation and error.

The stable logical frame identity shall not change when refinement replaces its storage or content.

### 12.2 Network and server path

Where DICOMKit owns DICOMweb access, add a capability/request model for:

- metadata first;
- selected frames;
- transfer-syntax negotiation;
- progressive-capable ranges or chunks;
- transcode provenance;
- checksum/finality;
- fallback to complete instance or frame.

Do not assume generic HTTP range requests align with a useful codestream boundary. The server and client contract must identify what partial content means.

### 12.3 Integration

- J2KSwift should provide resolution/quality-selective decode and reusable state where implemented.
- Voxelia may begin building a coarse volume from subresolution frames.
- Final lossless output must equal direct full decode.
- Measurements, stored output and AI input must wait for or explicitly request full fidelity.

## 13. P1 work package I — metadata-first and frame-first retrieval

Optimise real viewer workflows:

### Study browser

- QIDO-RS or index metadata only;
- no Pixel Data materialisation;
- lazy string decoding for displayed fields;
- thumbnail request separated from metadata.

### Stack/cine

- retrieve current and adjacent frames first;
- velocity-aware prefetch;
- bounded frame cache;
- cancel old direction work;
- preserve native depth until display.

### Volume

- retrieve geometry and per-frame mappings first;
- reject invalid regular-volume assumptions;
- request a coarse working set before full series;
- allow downstream volume pager to identify high-priority frames/bricks.

### Structured content

- do not optimise image paths by making SR, waveform, PDF or private large-value handling unsafe;
- use the same bulk-data handle and source model where applicable.

## 14. P1 work package J — cache redesign

Replace fixed item-count assumptions with byte-cost and semantic tiers.

Suggested tiers:

- parsed metadata/index;
- raw selected frame/fragments;
- decoded native frame;
- derived display frame;
- volume/brick artefacts owned by downstream toolkit;
- codec scratch pool.

A cache key shall include all values that change output, including:

- SOP Instance and frame;
- transfer syntax/codestream identity;
- decode fidelity/resolution/quality;
- modality/value transform;
- VOI/window and inversion for display artefacts;
- colour management;
- derivation version.

Avoid caching full display images in DICOMKit when the renderer already owns a more suitable cache. Define ownership rather than duplicate.

Memory warnings shall trigger staged eviction, not an all-or-nothing global clear unless necessary.

## 15. P1 work package K — Swift data-structure optimisation

Use [E12–E14] where measurement supports it.

Good candidates:

- `InlineArray` for tag bytes, fixed UID parsing state, small VR tables, JPEG marker state and short transform coefficients;
- `Span`/`RawSpan` for parser windows and codec input;
- noncopyable buffer leases;
- borrowing accessors for large datasets;
- `ContiguousArray` where Objective-C bridging is not needed;
- interned or compact keys for repeated tag/VR metadata;
- actors for cache/scheduler ownership with coarse-grained operations.

Avoid:

- very large `InlineArray` fields;
- escaping spans;
- hidden copies from bridged `Data`, `String` or `Array`;
- actor call per byte/tag;
- reference type per data element;
- blanket unsafe subscripting.

Use Instruments to inspect allocations, ARC traffic, copy-on-write and exclusivity checks.

## 16. Round-trip and write-path constraints

Optimised reading shall not weaken writing.

Preserve:

- original raw bytes where the round-trip contract requires them;
- undefined versus defined lengths where policy permits;
- fragment order and padding;
- transfer syntax;
- character set;
- unknown/private elements;
- sequence/item delimiters as required by the chosen write mode;
- pixel and bulk-data provenance.

A lazy source-backed dataset must fail clearly if the source has been disposed before a deferred write. It must not emit truncated or zero-filled values.

## 17. Security, fuzzing and resource limits

Add limits for:

- element count and nesting depth;
- undefined-length scan;
- declared value length;
- fragment count;
- frame count;
- decoded sample count;
- string length;
- allocation and scratch budget;
- network ranges and retries;
- progressive update count.

Fuzz:

- explicit and implicit VR;
- endian paths;
- malformed VR/VL combinations;
- nested undefined-length sequences;
- BOT/EOT inconsistency;
- truncated fragments;
- integer overflow;
- invalid character-set transitions;
- cancellation at every stage;
- source returning short or changing reads.

A limit violation shall return a structured error and release leases.

## 18. Benchmark plan

Use the shared benchmark companion. Add DICOMKit-specific comparisons:

### 18.1 Parsing

- in-memory `Data`;
- mapped file;
- pooled sequential file reads;
- windowed mapping;
- network source;
- metadata-only;
- index-only;
- selected-tag materialisation;
- full materialisation.

Measure:

- first metadata;
- complete index;
- allocations per element;
- peak memory;
- bytes copied;
- string conversions;
- random selected-value latency.

### 18.2 Pixel access

- complete object read versus fragment handle;
- first selected frame;
- random frame;
- sequential cine;
- progressive subresolution;
- final full decode;
- cancellation after rapid scrolling;
- caller-owned versus codec-owned output.

### 18.3 Integration

- DICOMKit → codec → CPU consumer;
- DICOMKit → codec → Voxelia shared owner;
- DICOMKit → codec → Metal upload;
- current path versus proposed path with copy counts.

Proposed gates:

- no output or dataset semantic mismatch;
- material reduction in peak memory for large instances;
- no fixed mapping threshold retained without evidence;
- at least one fewer full-frame copy on the selected-frame path where technically possible;
- bounded task and scratch concurrency;
- no allocation growth after repeated study cycling;
- first selected frame improves without unacceptable small-file regression;
- final progressive lossless decode equals direct full decode.

Set numerical throughput gates only after collecting the baseline.

## 19. Required repository deliverables

Produce:

1. **Current-State Reconciliation**
   - existing source abstractions;
   - parser copies and allocations;
   - bulk-data and frame-index status;
   - codec buffer ownership;
   - existing benchmark claims requiring reproduction.

2. **DICOM Byte Source and Lifetime ADR**
   - source types;
   - borrow/owner semantics;
   - mapping heuristic;
   - cancellation and integrity;
   - public compatibility.

3. **Compact Index and Lazy Materialisation Specification**
   - records and nesting;
   - string/charset policy;
   - bulk handles;
   - round-trip semantics.

4. **Codec Interchange Contract**
   - caller-owned destination;
   - progressive updates;
   - scratch declaration;
   - fidelity and provenance;
   - integration adapters.

5. **Benchmark and Copy-Path Report**
   - raw results;
   - file/device matrix;
   - allocation and resident memory;
   - exact output;
   - adverse cases.

6. **P0 Implementation Slice**
   - one file source;
   - one network or test streaming source;
   - borrowed parser window;
   - selected-frame index;
   - one codec caller-owned output;
   - bounded scheduler;
   - tests and telemetry.

7. **Documentation Corrections**
   - replace unsupported universal claims;
   - name benchmark environments;
   - distinguish hypotheses from accepted guidance;
   - state limitations honestly.

## 20. Explicit exclusions

Do not:

- introduce a second public native DICOM model for Apple products;
- use dicom.js in the native stack;
- make memory mapping a universal large-file rule;
- multiply HTJ2K and backend speed-ups;
- launch all frame tasks concurrently without a byte budget;
- eagerly expand every large value;
- convert native-depth images to RGBA inside the parser;
- add private codec semantics without governance;
- treat lossy compression as clinically acceptable by default;
- allow borrowed storage to outlive its owner;
- weaken malformed-input handling for speed.

## 21. References

- [E04] Medical Image Streaming Toolkit research: https://arxiv.org/abs/2307.00438
- [E05] DICOM HTJ2K: https://dicom.nema.org/medical/dicom/current/output/chtml/part05/sect_8.2.14.html
- [E06] DICOM JPEG XL: https://dicom.nema.org/medical/dicom/current/output/chtml/part05/sect_8.2.15.html
- [E07] Static WebGPU memory planning evidence: https://arxiv.org/abs/2605.20706
- [E09] Apple Silicon unified-memory performance: https://arxiv.org/abs/2502.05317
- [E12] Swift Span: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0447-span-access-shared-contiguous-storage.md
- [E13] Swift InlineArray: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0453-vector.md
- [E14] WWDC25 Swift memory/performance: https://developer.apple.com/videos/play/wwdc2025/312/
- Current repository: https://github.com/Raster-Lab/DICOMKit
- Current performance guide under review: https://github.com/Raster-Lab/DICOMKit/blob/main/PERFORMANCE_GUIDE.md
