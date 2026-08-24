---
title: "Shared Performance, Memory and Progressive Delivery Benchmark Baseline"
version: "0.1.0"
status: "Proposed cross-project benchmark companion; human review required"
controlled_date: "2026-08-09"
organisation: "Raster Images"
language: "en-GB"
applies_to:
  - dicom.js
  - Voxelia
  - DICOMKit
  - J2KSwift
  - JLSwift
  - JXLSwift
  - JLISwift
  - OpenJP3D
---

# Shared Performance, Memory and Progressive Delivery Benchmark Baseline v0.1.0

## 1. Instruction to the receiving project

Use this document as the common measurement contract for the project-specific research-adoption instruction. Do not claim an optimisation from a microbenchmark alone. Establish an unmodified release-build baseline, capture correctness and memory evidence, apply one controlled change at a time, and publish enough environmental detail for another engineer to reproduce the result.

Project-specific benchmarks may add metrics and datasets. They shall not redefine the common metrics below in a way that prevents cross-project comparison.

## 2. Scientific claim policy

1. Published results establish that a mechanism is worth testing; they do not establish the performance of Raster Images code.
2. Percentages and speed-ups from separate papers shall never be multiplied or added.
3. "Up to" values shall not be used as a headline result unless the median, range and workload are also reported.
4. A result shall name the exact commit, compiler, optimisation mode, device, OS, browser where applicable, dataset, warm-up, iteration count and statistic.
5. Wall-clock, resident-memory and energy results shall include idle/background controls where practicable.
6. A faster result that changes decoded samples, geometry, transfer-function semantics, measurements, error handling or interoperability is a failed result unless the difference was explicitly authorised and validated.
7. For lossy or approximate research, record rate-distortion and task-specific clinical risk separately from throughput.

## 3. Common benchmark corpus

The controlled corpus shall include de-identified or synthetic instances with immutable hashes and documented expected semantics.

### 3.1 Image and volume cases

| ID | Workload | Required characteristics |
|---|---|---|
| C01 | Large thin-slice CT | At least one volume large enough to exceed a conservative mobile working set; signed 12–16-bit source; regular geometry. |
| C02 | CTA/high-frequency anatomy | Fine vessels and bone edges; stresses interpolation, gradients and lossless codec behaviour. |
| C03 | Dense MR | Low empty-space ratio so hierarchy traversal and skipping are tested where they may not help. |
| C04 | Enhanced multi-frame | Per-frame functional groups, non-trivial transforms or value mappings; catches invalid global assumptions. |
| C05 | PET/CT | Co-registered multichannel sampling, separate scaling and transfer functions. |
| C06 | Irregular/tilted series | Gantry tilt, irregular spacing, missing frame or orientation inconsistency; must fail closed or follow an explicit resampling policy. |
| C07 | Colour medical image | RGB/YBR and relevant bit depth for JPEG/JPEG XL paths. |
| C08 | High-bit-depth monochrome | 12-, 16- and, where supported, greater-than-16-bit source coverage. |
| C09 | Very large multi-frame | Selected-frame access and cancellation without decoding all frames. |
| C10 | Dense-no-skip adversarial volume | Confirms that a spatial hierarchy does not create an unacceptable regression. |

### 3.2 Segmentation and geometry cases

| ID | Workload | Required characteristics |
|---|---|---|
| S01 | Binary DICOM SEG | Sparse mask and dense mask variants. |
| S02 | Multi-segment DICOM SEG | Many labels and both overlapping and non-overlapping segment semantics. |
| S03 | Editable label volume | Random voxel access, brush edits and bounded recompression latency. |
| S04 | Implicit isosurface | Bone/airway/vessel threshold exploration and deterministic full-resolution mesh comparison. |
| S05 | Independently movable volumes | Multiple structures with changing relative transforms for depth-buffer composition. |

### 3.3 Codec cases

Each codec repository shall include:

- small, medium and large frames;
- low-entropy and high-entropy images;
- all supported bit depths, signedness and component layouts;
- lossless round-trip cases with byte-exact or sample-exact expected output;
- progressive, restart-marker, tiling, precinct, quality-layer or group variants relevant to the standard;
- malformed, truncated, oversized and adversarial codestreams;
- cross-decoding against at least one independent conformant implementation where licensing and deployment permit;
- cold-start, warm steady-state and batched-series modes.

## 4. Common data and buffer contract

Project boundaries shall use an explicit description rather than an untyped byte blob.

Minimum fields:

```text
sample type: unsigned integer | signed integer | floating point
bits allocated / bits stored / high bit
endianness
component count
planar or interleaved organisation
row, plane and frame strides
width, height, depth and frame count
owner and lifetime
mutability
alignment
source provenance and frame mapping
full-fidelity / partial-fidelity state
cancellation identity
```

A caller-owned output path shall be preferred where the codec can safely write into validated capacity. Ownership must be explicit: borrowed views shall not escape their owner, and asynchronous work must retain or otherwise guarantee the underlying storage.

## 5. Metrics

### 5.1 Latency and throughput

- time to metadata;
- time to first image;
- time to first interactive stack or volume;
- time to requested subresolution;
- time to full-fidelity convergence;
- selected-frame latency;
- encode/decode throughput in megapixels or megavoxels per second;
- P50, P90, P95 and worst-case interactive frame time;
- cancellation latency and obsolete-work percentage;
- cold and warm pipeline creation latency.

### 5.2 Memory and data movement

- peak resident set size;
- Swift heap, JavaScript heap and WebAssembly linear memory where applicable;
- estimated and, where available, measured GPU allocations;
- bytes read from storage/network;
- bytes decoded;
- bytes copied between stages;
- bytes uploaded to GPU;
- scratch high-water mark per worker and per operation;
- allocation count after warm-up;
- cache hit, miss, eviction and duplicate-residency counts;
- number and duration of CPU–GPU waits or readbacks.

### 5.3 Energy and thermals

On Apple platforms, record:

- energy per image, frame or volume operation where tooling permits;
- sustained throughput after thermal equilibrium;
- CPU, GPU and memory-pressure observations;
- performance under representative battery/thermal conditions for mobile and spatial devices.

### 5.4 Correctness and quality

- exact decoded sample hash for lossless paths;
- maximum absolute and relative error for authorised floating-point paths;
- geometry transform, spacing and orientation checks;
- measurement and ROI equality;
- segmentation label and overlap equality;
- codec conformance and cross-decoder results;
- progressive-final versus direct-full decode equality;
- error-path equivalence and fail-closed behaviour;
- rate-distortion metrics only for separately authorised lossy experiments.

## 6. Measurement protocol

1. Pin the source commit and all dependencies.
2. Build release/optimised binaries with symbol information sufficient for profiling.
3. Disable unrelated logging and debugging, but do not disable safety checks that ship in production unless the comparison says so.
4. Record cold start separately from warm steady state.
5. Warm the operation until pipeline compilation and one-time cache population are no longer contaminating steady-state measurements.
6. Use enough iterations to report a stable distribution; record median and tail behaviour rather than only mean.
7. Randomise or alternate baseline and candidate runs when thermal drift is material.
8. Reset caches when measuring cold behaviour and preserve them when measuring realistic scrolling or repeated access.
9. Record memory high-water marks over the complete operation, not just at its end.
10. Keep reference and candidate results from the same host session where practical.
11. Validate exact output before accepting timing results.
12. Store raw benchmark output as a versioned artefact.

## 7. Initial engineering gates

These are proposed prototype gates, not promises derived from literature.

### 7.1 Cross-project P0 gates

- No continuing allocation growth after a defined warm-up and workload cycle.
- No routine synchronous GPU readback or device-wide wait in the interactive frame loop.
- No lossless output mismatch.
- No measurement, annotation, geometry or label-semantic change.
- All partial/coarse presentation carries explicit refinement state.
- Cancellation prevents obsolete work from continuing without bound.
- Unsupported transfer syntax, device capability or geometry fails closed or follows an approved fallback.

### 7.2 Target gates for the combined volume-paging prototype

- At least **30% lower peak resident memory** than the monolithic-volume baseline on C01, without an unacceptable C10 regression.
- At least **2× faster time to first interactive volume** in the constrained-network progressive-delivery scenario.
- Stable full-fidelity convergence to the same source-derived output.
- Bounded cache occupancy under repeated pan, zoom, scroll, MPR and camera-motion traces.

### 7.3 Parser and codec target gates

Each repository shall set workload-specific thresholds after collecting a baseline. At minimum:

- reduce or hold peak memory while improving throughput;
- eliminate avoidable whole-input and whole-output copies;
- keep worker concurrency within an explicit memory budget;
- demonstrate no statistically material regression for small inputs when optimising large inputs;
- document CPU/GPU crossover points rather than forcing one backend universally.

## 8. Required benchmark report

The report shall contain:

1. objective and hypothesis;
2. relevant research evidence and why it may transfer;
3. exact baseline and candidate commits;
4. environment and corpus hashes;
5. architecture or algorithm change;
6. correctness results;
7. raw and summarised performance results;
8. memory and allocation results;
9. energy/thermal results where applicable;
10. adverse cases and regressions;
11. limitations;
12. recommendation: accept, reject, continue experiment or block;
13. traceability to requirements, ADRs and risk controls.

## 9. Prohibited reporting practices

Do not:

- combine unrelated paper multipliers;
- present a GPU-kernel microbenchmark as end-to-end application performance;
- compare different devices without identifying them;
- omit codec compression ratio or image quality when claiming faster lossy encoding;
- omit warm-up and pipeline-compilation cost;
- report only the best run;
- silently exclude failures or unsupported data;
- use "zero copy" where an API, bridge, staging operation or copy-on-write materialisation still copies;
- treat unified memory as infinite or cost-free;
- treat coarse or foveated presentation as full fidelity.
