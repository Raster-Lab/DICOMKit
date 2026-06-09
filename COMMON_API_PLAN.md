# Common API Plan

## Goal

Create one pure shared processing layer that sits above `DICOMCore`/`DICOMKit`/
`DICOMNetwork`/`DICOMWeb` and below both the CLI tools and DICOMStudio. That
layer becomes the single public API for input reading, processing, diagnostics,
artifact generation, and output rendering.

The intended outcome is:

- CLI tools become thin adapters over the common API.
- DICOMStudio remains a Swift/SwiftUI application, but becomes a thin UI
   adapter over the same common API.
- Third-party applications can call the same common API directly without
   shelling out or re-implementing tool logic, regardless of whether they use
   SwiftUI, UIKit/AppKit, or no UI at all.

## Key Decision

Use a new pure library target for the common processing API as a first-class
public library product in the DICOMKit package, rather than placing it in
`DICOMToolbox`.

Reason:

- `DICOMToolbox` currently mixes UI and process-execution concerns.
- The common API must not depend on SwiftUI, `Process`, or `ArgumentParser`.
- The common API must be usable by CLI tools, DICOMStudio, and third-party apps.

What this means:

- The common API is still written in Swift.
- The common API is part of the DICOMKit library ecosystem.
- The common API is not a CLI-only layer and is not owned by DICOMStudio.
- SwiftUI remains valid in applications that consume the common API; the rule is
   only that SwiftUI must stay out of the shared processing layer itself.

Recommended working name:

- `DICOMOperations`

## Architecture Rules

These rules should be fixed before implementation starts:

1. No SwiftUI dependency in the common API. SwiftUI belongs in app adapters,
   not in the shared processing layer.
2. No `Process` or shell execution in the common API.
3. No `ArgumentParser` in the common API.
4. Public contracts must be `Sendable` where appropriate.
5. Input, processing, diagnostics, artifacts, and rendering must all come from
   the shared layer.
6. Stdout/stderr are adapter concerns, not operation concerns.
7. Written files, directories, images, JSON, DICOM outputs, and reports are
   first-class artifacts.
8. CLI flags and DICOMStudio UX should remain stable while internals migrate.

## Scope Boundary

Phase 1 should cover the tools DICOMStudio already executes in-process.

Current execute-supported tool set is defined in:

- `Sources/DICOMStudio/Components/CLIParityEngine.swift`

Tools outside that set can follow after the common contracts are proven.

## Phased Plan

### Phase 0 - Architecture Foundation

1. Define the final ownership boundaries between `DICOMCore`, `DICOMKit`,
   `DICOMDictionary`, `DICOMNetwork`, `DICOMWeb`, the new common API module,
   DICOMStudio, and the CLI adapters.
2. Add a new pure library target/product in `Package.swift` for the common API
   as a public DICOMKit package library product.
3. Freeze the rule that DICOMStudio and every `dicom-*` executable become thin
   adapters only.

### Phase 1 - Common Contracts

Define public shared contracts for:

- input sources
- output targets
- execution context
- diagnostics
- artifacts
- progress
- error policy
- per-tool request and response models

The common API must treat artifact output as a first-class result instead of a
side effect.

### Phase 1 - Output Contract

Centralize output-path resolution, write policy, and artifact emission under the
new module.

Existing logic to wrap first:

- `Sources/DICOMKit/OutputPathResolver.swift`

Do not move working code until the shared adapter shape is proven.

### Phase 1 - Shared Presenter Seeds

Use the already-shared success cases as the first common operations:

- `Sources/DICOMKit/MetadataPresenter.swift`
- `Sources/DICOMKit/HexDumper.swift`

These are the first examples of common processing plus common rendering.

### Phase 2 - Pilot Tools

Migrate these tools first:

1. `dicom-info`
2. `dicom-dump`

Reason:

- They already have true shared presenter paths.
- They are the lowest-risk proof that the new layer works.

### Phase 2 - First High-Drift Refactor

Migrate `dicom-validate` next.

Target files:

- `Sources/dicom-validate/DICOMValidate.swift`
- `Sources/dicom-validate/Validator.swift`
- `Sources/dicom-validate/Report.swift`
- `Sources/DICOMStudio/ViewModels/ValidationViewModel.swift`
- `Sources/DICOMStudio/Models/ValidationModel.swift`

Goal:

- one common validation operation
- one common validation report/artifact model
- no mirrored formatter in DICOMStudio

### Phase 2 - Mixed Local Tools

Migrate these after `dicom-validate`:

1. `dicom-tags`
2. `dicom-diff`

Reason:

- They exercise file mutation, comparison, and reporting.
- They validate that the common API handles more than read-only inspection.

### Phase 3 - Local Processing Cohort

Move these tools onto common operations and shared artifact outputs:

- `dicom-anon`
- `dicom-convert`
- `dicom-json`
- `dicom-xml`
- `dicom-uid`
- `dicom-compress`

CLI wrappers remain responsible only for command-line parsing and exit-code
mapping.

### Phase 3 - Batch and File Organization Cohort

Add shared batch and directory abstractions for:

- `dicom-split`
- `dicom-merge`
- `dicom-dcmdir`
- `dicom-archive`
- `dicom-study`
- `dicom-image`
- `dicom-export`
- `dicom-pixedit`
- `dicom-pdf`
- `dicom-script`

Standardize:

- directory inputs
- per-file progress
- partial-failure policy
- multi-artifact outputs

### Phase 4 - Network and Web Cohort

Introduce shared request/result/session models over `DICOMNetwork` and
`DICOMWeb` for:

- `dicom-echo`
- `dicom-query`
- `dicom-send`
- `dicom-retrieve`
- `dicom-qr`
- `dicom-mwl`
- `dicom-mpps`
- `dicom-qido`
- `dicom-wado`
- `dicom-stow`
- `dicom-ups`

Standardize:

- cancellation
- progress
- connection profiles
- machine-readable results

### Phase 5 - Tool Metadata Unification

After the shared operations are stable, derive CLI and app parameter metadata
from one canonical source tied to the new request models.

This should replace duplicated definitions across:

- `Sources/DICOMStudio/Components/ParameterBuilderHelpers.swift`
- `Sources/DICOMStudio/ViewModels/CLIWorkshopViewModel.swift`
- `Sources/DICOMToolbox/Models/ToolRegistry.swift`
- the `ArgumentParser` declarations in `Sources/dicom-*/`

### Phase 5 - Adapter Simplification

Reduce adapters to their minimum responsibilities.

CLI adapters should only:

- parse arguments
- invoke shared operations
- emit shared artifacts
- map exit codes

DICOMStudio should only:

- manage UI state
- manage security-scoped URLs
- present progress and artifacts

No mirrored processing logic should remain in DICOMStudio after a tool is
migrated.

### Phase 6 - Rollout and Cleanup

1. Migrate tool-by-tool.
2. Remove mirrored code only after parity verification passes.
3. Update public architecture and integration documentation.
4. Direct third-party application developers to the new common API instead of
   executable-local implementations.

## Relevant Files

- `Package.swift`
- `Sources/DICOMKit/MetadataPresenter.swift`
- `Sources/DICOMKit/HexDumper.swift`
- `Sources/DICOMKit/OutputPathResolver.swift`
- `Sources/dicom-info/main.swift`
- `Sources/dicom-dump/main.swift`
- `Sources/dicom-validate/DICOMValidate.swift`
- `Sources/dicom-validate/Validator.swift`
- `Sources/dicom-validate/Report.swift`
- `Sources/dicom-anon/main.swift`
- `Sources/dicom-anon/Anonymizer.swift`
- `Sources/dicom-convert/DICOMConvert.swift`
- `Sources/dicom-json/main.swift`
- `Sources/dicom-xml/main.swift`
- `Sources/dicom-tags/main.swift`
- `Sources/dicom-tags/TagEditor.swift`
- `Sources/dicom-diff/main.swift`
- `Sources/DICOMStudio/ViewModels/CLIWorkshopViewModel.swift`
- `Sources/DICOMStudio/ViewModels/ValidationViewModel.swift`
- `Sources/DICOMStudio/Models/ValidationModel.swift`
- `Sources/DICOMStudio/Components/ParameterBuilderHelpers.swift`
- `Sources/DICOMToolbox/Views/ConsoleView.swift`
- `Sources/DICOMToolbox/Models/ToolRegistry.swift`
- `Sources/DICOMNetwork/`
- `Sources/DICOMWeb/`
- `README.md`
- `Documentation/Architecture.md`

## Verification Plan

1. For each migrated tool, verify that the same input produces the same shared
   artifacts whether invoked from the CLI adapter or the DICOMStudio adapter.
2. Extend the existing parity infrastructure from console-only checks to file,
   directory, image, JSON, and DICOM artifact parity.
3. Add API-level tests for file input, in-memory input, file output, in-memory
   output, batch processing, progress, cancellation, and partial-failure
   policies.
4. Keep release-mode CLI smoke tests in the loop for migrated tools.
5. Add third-party-app examples proving direct API use without shelling out.

## Decisions

- Recommended module home: a new pure library target/product, not
  `DICOMToolbox`.
- Recommended rollout scope: start with the DICOMStudio execute-supported tool
  set.
- Recommended API rule: the shared layer owns input interpretation,
  processing, diagnostics, artifact generation, and rendering.
- Recommended migration rule: wrap existing shared helpers first and move code
  later only when a wrapper still leaves unacceptable duplication.
- Recommended compatibility rule: keep existing CLI flags and DICOMStudio UX
  stable while internals change.

## Further Considerations

1. `DICOMOperations` is the clearest working name for the new common layer.
2. Expose it first as a separate public product.
3. Unifying parameter metadata should happen after the processing layer is
   stable, not before.