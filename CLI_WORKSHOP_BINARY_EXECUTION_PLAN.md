# CLI Workshop Binary Execution Plan

## Goal

Make DICOMStudio CLI Workshop execute the real `dicom-*` binaries for all tool
operations instead of maintaining mirrored in-process implementations.

The intended behavior is:

- the terminal and DICOMStudio CLI Workshop use the same executable path
- all tool input, processing, and output generation happen inside the CLI binary
- DICOMStudio acts as a UI adapter that builds commands, launches binaries,
  captures output, and previews produced artifacts

This plan is specifically about CLI Workshop execution parity. It is different
from the separate plan for a shared reusable common package API.

## Core Decision

Adopt one execution rule for CLI Workshop:

- every CLI Workshop tool run must invoke the corresponding `dicom-*` executable
- DICOMStudio must not perform tool-specific mirrored processing for CLI Workshop
- DICOMStudio may still inspect or preview the artifacts produced by the CLI
  binaries, but it must not recreate those tool workflows itself

## Scope

This plan applies to DICOMStudio CLI Workshop behavior.

It does not define a reusable third-party application API.

It does not replace the existing DICOMKit package libraries.

It does not prevent DICOMStudio from using DICOMKit libraries elsewhere for
viewer, browser, analysis, or non-CLI-workshop features.

## Constraints

### Platform Scope

This approach is primarily a macOS desktop strategy.

Reason:

- CLI Workshop depends on launching external executables.
- That is a natural fit on macOS desktop.
- It is not an equivalent fit for iOS or visionOS.

### Sandbox Policy

The current real-binary launcher already documents the main constraint:

- a sandboxed app cannot freely launch external executables

See:

- `Sources/DICOMStudio/Components/CLIToolTerminalCompare.swift`
- `DICOMStudio.entitlements`

Before implementation, decide one of these models:

1. DICOMStudio stays unsandboxed for this macOS workflow.
2. DICOMStudio uses a different Apple-approved helper/process model.
3. CLI Workshop real-binary mode remains development-only.

This decision must be made up front.

### Binary Packaging

CLI Workshop must not depend on random PATH contents or local `.build` outputs
for normal application behavior.

The app must have a deterministic way to locate the required release binaries.

## Target Architecture

The final CLI Workshop execution model should be:

1. DICOMStudio UI collects parameter values.
2. DICOMStudio builds the exact CLI command and argv.
3. DICOMStudio resolves input/output paths and security-scoped access.
4. DICOMStudio launches the matching `dicom-*` executable.
5. The CLI binary performs input, processing, and output.
6. DICOMStudio captures stdout, stderr, exit code, and produced artifacts.
7. DICOMStudio displays the CLI output and previews the produced artifacts.

This means:

- the CLI binary is the only execution engine
- DICOMStudio is only a command builder, runner, and result viewer

## Current Anchors

The current repository already contains the pieces needed to build this model:

- `Sources/DICOMStudio/Components/CLIToolTerminalCompare.swift`
- `Sources/DICOMToolbox/Models/CommandExecutor.swift`
- `Sources/DICOMStudio/ViewModels/CLIWorkshopViewModel.swift`
- `DICOMStudio.entitlements`

These should be treated as starting points, not the final architecture.

## Implementation Plan

### Phase 0 - Execution Contract

1. Document that CLI Workshop is a binary-driven execution surface.
2. Freeze the rule that no new mirrored `executeDicomX` implementations are
   added for CLI Workshop behavior.
3. Define the contract that DICOMStudio CLI Workshop only builds commands,
   launches binaries, captures results, and previews artifacts.

### Phase 1 - Production CLI Runner

Create one production-grade binary execution service for DICOMStudio.

This service should:

- locate the correct binary for a selected tool
- launch the binary using argv, not mirrored logic
- stream stdout and stderr
- capture exit code and execution status
- support cancellation
- report binary path used for execution

Reuse and consolidate logic currently spread across:

- `Sources/DICOMToolbox/Models/CommandExecutor.swift`
- `Sources/DICOMStudio/Components/CLIToolTerminalCompare.swift`

### Phase 1 - Binary Resolution Strategy

Define two resolution modes:

#### Development Mode

Use binaries from:

- `DICOM_CLI_BIN_DIR`
- `.build/release/`
- optionally `.build/debug/` only as a fallback for development

#### Application Mode

Use binaries bundled inside the DICOMStudio app package.

This must become the default for distributed app builds.

### Phase 2 - Bundle Release Binaries

Update the app packaging flow so DICOMStudio ships with release-mode CLI
binaries for the supported tool set.

This work will affect packaging/build configuration rather than tool logic.

The release-binary rule should match the existing testing preference used for
binary validation.

### Phase 2 - Artifact Model

For each CLI tool, define what DICOMStudio consumes after execution.

Possible outputs include:

- stdout text
- stderr text
- exit code
- output file
- output directory
- generated DICOM file
- generated image file
- generated JSON or XML file
- generated audit log

CLI Workshop must stop assuming console text is the full result for all tools.

Examples:

- `dicom-info`: stdout is the result
- `dicom-validate --output report.json`: the file is the main result
- `dicom-anon`: anonymized output files are the main result
- conversion/export tools: produced image or DICOM files are the main result

### Phase 3 - Artifact-Aware Result Presentation

Add a result layer in DICOMStudio that can:

- show stdout/stderr text
- show exit status
- open or preview produced files
- inspect produced DICOM artifacts using existing viewers
- inspect produced JSON/XML/text artifacts
- browse output directories for batch tools

DICOMStudio may use existing internal viewers and inspectors to visualize these
artifacts, but it must not regenerate the artifacts itself.

### Phase 3 - Replace Mirrored Tool Execution

Remove the per-tool in-process execution path from CLI Workshop.

The current large tool switch in:

- `Sources/DICOMStudio/ViewModels/CLIWorkshopViewModel.swift`

should be reduced to:

- command-building
- binary execution
- result capture
- artifact presentation

After migration, there should be no CLI Workshop-specific reimplementation of
tool processing behavior.

### Phase 4 - Migration Waves

Migrate tools in waves to reduce risk.

#### Wave 1

- `dicom-info`
- `dicom-dump`
- `dicom-validate`
- `dicom-anon`

These are the best first candidates because they are common local-file tools and
expose the main output patterns.

#### Wave 2

- `dicom-convert`
- `dicom-tags`
- `dicom-diff`
- `dicom-json`
- `dicom-xml`

#### Wave 3

- file organization and export tools
- archive/report/measure tools
- viewer-related CLI tools

#### Wave 4

- network tools
- DICOMweb tools
- JPIP / J2K specialty tools

### Phase 5 - Cleanup

After all target tools are migrated:

1. Remove mirrored CLI Workshop processing implementations.
2. Remove testing-only compare paths that are superseded by production binary execution.
3. Keep only one binary execution surface in CLI Workshop.
4. Update architecture and user documentation.

## Verification Plan

1. For each migrated tool, verify that CLI Workshop and terminal execute the
   same binary with the same arguments.
2. Verify stdout, stderr, exit code, and produced artifacts.
3. Verify output-path handling for writable, redirected, and sandbox-scoped paths.
4. Verify bundled release binary discovery in distributed app builds.
5. Keep release-mode smoke tests for all migrated tools.
6. Extend parity coverage from text-only comparison to artifact comparison.

## Benefits

- one execution path for terminal and CLI Workshop
- no mirrored tool logic in CLI Workshop
- no CLI Workshop drift from actual CLI binary behavior
- easier debugging because the app runs the same binaries users run in terminal

## Tradeoffs

- this solves CLI execution parity, not reusable third-party library parity
- DICOMStudio becomes dependent on process execution and packaged binaries
- sandbox and platform constraints become first-order architectural concerns
- third-party applications still do not get a clean importable tool API from
  this decision alone

## Go / No-Go Conditions

Proceed only if all of the following are accepted:

1. CLI Workshop is a macOS-oriented binary runner surface.
2. DICOMStudio packaging will include release CLI binaries.
3. Sandbox/process-launch policy is explicitly decided before implementation.

## Relevant Files

- `Sources/DICOMStudio/ViewModels/CLIWorkshopViewModel.swift`
- `Sources/DICOMStudio/Components/CLIToolTerminalCompare.swift`
- `Sources/DICOMToolbox/Models/CommandExecutor.swift`
- `DICOMStudio.entitlements`
- `Package.swift`

## Relationship To Other Plans

This plan is different from the common API plan.

- The common API plan focuses on a reusable shared library pipeline.
- This plan focuses on making CLI Workshop call the real CLI binaries.

These two plans can coexist, but they solve different problems.

If the binary-execution model is adopted for CLI Workshop, it should be treated
as a UI/runtime execution policy, not as the long-term reusable application API.