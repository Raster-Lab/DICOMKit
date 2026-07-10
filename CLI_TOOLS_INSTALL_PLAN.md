# DICOMStudio — "Install Command‑Line Tools" Feature Plan

**Status:** Proposed
**Author:** (drafted with Claude Code)
**Scope:** New DICOMStudio feature that lets an end user install the `dicom-*`
command‑line tools onto their machine **while the App Sandbox is enabled**.
**Related docs:** [CLI_TOOLS_GUI_PLAN.md](CLI_TOOLS_GUI_PLAN.md),
[DISTRIBUTION.md](DISTRIBUTION.md), [Scripts/install-cli-tools.sh](Scripts/install-cli-tools.sh)

---

## 1. Problem statement & the "build vs. install" decision

The literal request is *"can DICOMStudio build the CLI tools when the sandbox is
enabled for the end user?"* The honest engineering answer is:

> **You cannot *compile* the CLI tools on the end user's machine from inside a
> sandboxed app — but you can *install* pre‑built, code‑signed CLI tools from the
> app bundle, and that fully satisfies the underlying goal.**

### 1.1 Why on‑device compilation is not viable under the sandbox

| Requirement of `swift build` | Sandbox / end‑user reality |
| --- | --- |
| Swift toolchain (`swiftc`, `swift-build`, linker, SDK) present | End users don't have Xcode/toolchain; you can't legally/practically ship one inside an app |
| Spawn the compiler driver + dozens of child processes | App Sandbox blocks executing arbitrary binaries outside the container |
| Write build products to `~/.build`, temp dirs, arbitrary paths | Sandbox confines writes to the container + user‑selected paths |
| Full SwiftPM source tree (`Package.swift` + all `Sources/`) | Not shipped to end users |

This is exactly why the two existing spawn‑based helpers are flagged
**TESTING‑ONLY — REMOVE BEFORE PRODUCTION** and require the sandbox to be
disabled:

- [Sources/DICOMStudio/Components/CLIToolBuilder.swift](Sources/DICOMStudio/Components/CLIToolBuilder.swift) — runs `swift build`.
- [Sources/DICOMStudio/Components/CLIToolTerminalCompare.swift](Sources/DICOMStudio/Components/CLIToolTerminalCompare.swift) — spawns the real binary.
- [DICOMStudio.entitlements](DICOMStudio.entitlements) currently sets
  `com.apple.security.app-sandbox = false` **solely** to enable those two.

**Conclusion:** "build under sandbox" = ❌. The production feature must instead
**bundle pre‑built binaries and install them**.

### 1.2 Why "bundle + install" is the correct pattern

This is the industry‑standard "shell command in PATH" installer used by VS Code
(`Install 'code' command in PATH`), Xcode, Tower, Postico, etc.

The crucial sandbox insight:

> The sandbox constrains only the **install‑time write** (copying a file to a
> directory). Once a `dicom-*` binary has been copied out of the bundle and the
> user launches it **from Terminal**, it runs as a **normal, unsandboxed user
> process** with full filesystem/network access — identical to a Homebrew
> install.

So a sandboxed DICOMStudio can ship fully‑functional CLI tools; we only need a
sandbox‑legal way to place them where the user's shell can find them.

---

## 2. Current state (what exists today)

- **43 `dicom-*` executable targets** are declared in [Package.swift](Package.swift)
  (`dicom-info`, `dicom-convert`, … `dicom-xml`). Today they're distributed via
  Homebrew / `swift build` / [Scripts/install-cli-tools.sh](Scripts/install-cli-tools.sh)
  (build‑from‑source, copies `.build/release/dicom-*` to `/usr/local/bin`).
- **DICOMStudio's "CLI Workshop"** ([Sources/DICOMStudio/ViewModels/CLIWorkshopViewModel.swift](Sources/DICOMStudio/ViewModels/CLIWorkshopViewModel.swift))
  re‑implements each tool **in‑process** against the DICOMKit library — it does
  **not** need a subprocess for normal operation. Only the TESTING‑ONLY
  "Compare CLI" path spawns a real binary.
- The app is built from an Xcode project ([DICOMStudio.xcodeproj](DICOMStudio.xcodeproj))
  and is intended for **notarized/DMG and (aspirationally) App Store** distribution
  (see [DISTRIBUTION.md](DISTRIBUTION.md)).
- The entitlements **already grant** the two things Strategy A (below) needs:
  `com.apple.security.files.user-selected.read-write` and
  `com.apple.security.files.bookmarks.app-scope`.

---

## 3. Design overview

Three components:

1. **Bundling** — embed signed release CLI binaries inside `DICOMStudio.app`.
2. **Installer service** — a sandbox‑safe service that places the tools where the
   shell can find them, via tiered strategies.
3. **UI** — an "Install Command‑Line Tools…" surface (Settings pane + menu
   command) with status, update, and uninstall.

```
DICOMStudio.app/
└── Contents/
    ├── MacOS/DICOMStudio            (sandboxed GUI)
    ├── Helpers/                      ← NEW: bundled CLI payload
    │   ├── dicomkit                  (umbrella multitool — see §4)
    │   ├── dicom-info -> dicomkit    (symlinks, one per tool)
    │   └── …
    └── Library/LaunchServices/       (OPTIONAL privileged helper — Strategy B)
```

---

## 4. Bundling strategy — one multitool vs. 43 binaries

Each `dicom-*` statically links DICOMKit/DICOMCore/J2K, so **43 separate release
binaries can total hundreds of MB** and bloat the `.app`. Two options:

### Option 4A (Recommended): single umbrella `dicomkit` multitool + symlinks

Create **one** new executable target, `dicomkit`, that dispatches on `argv[0]`
(BusyBox style) or on its first subcommand:

- `dicomkit info …`  ≡  `dicom-info …`
- Symlink `dicom-info → dicomkit`; when invoked as `dicom-info`, it inspects
  `CommandLine.arguments[0]`'s basename and routes to the `info` subcommand.

Benefits: **one binary** (one code‑sign, one copy of the static libs) instead of
43 → dramatically smaller bundle & faster install. Each `dicom-*` name is just a
symlink. Swift ArgumentParser makes the dispatch trivial (a root
`ParsableCommand` with `subcommands:`; the `argv[0]` shim selects one).

> Note: there is **no** unified multitool today — `DICOMToolbox` is a GUI
> library, and each `dicom-*` is its own `executableTarget`. Option 4A therefore
> adds a thin `dicomkit` target that re‑exports the existing per‑tool
> `AsyncParsableCommand`/`ParsableCommand` root commands as subcommands. This is
> mostly wiring, not new logic.

### Option 4B (Fallback): bundle all N pre‑built `dicom-*` binaries as‑is

Zero source changes to the CLIs; just embed `.build/release/dicom-*`. Simpler to
ship first, but large. Good for an MVP; migrate to 4A to cut size.

**Recommendation:** ship **4B for the MVP** (fastest to a working feature), then
land **4A** to control bundle size before wide distribution.

### Xcode build phase to embed the payload

Add a **Run Script build phase** (runs before code signing) to
[DICOMStudio.xcodeproj](DICOMStudio.xcodeproj):

```bash
# Build release CLI tools from the SwiftPM package, then copy into the bundle.
# (CI can pre‑build to keep local Xcode builds fast; gate on a build setting.)
set -e
PKG="$SRCROOT"
DEST="$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/Helpers"
mkdir -p "$DEST"
# Option 4A: swift build --product dicomkit ; cp + symlink each dicom-* name
# Option 4B: for t in $CLI_TOOLS; do swift build --product "$t"; cp ".build/release/$t" "$DEST/"; done
```

Then a **Code Sign** step signs each bundled binary with the app's Developer ID
and the **Hardened Runtime** (required for notarization). Because they live under
`Contents/Helpers`, they're part of the app's signature/notarization envelope.

> Keep local dev builds fast: gate the heavy `swift build` behind a build setting
> (e.g. `EMBED_CLI_TOOLS=YES`, on only for Release/Archive), and have CI produce
> the binaries once.

---

## 5. Installer service — sandbox‑legal placement (tiered)

New type `CLIToolInstaller` (see §7). It offers three strategies, presented to
the user in order of preference; the app auto‑detects which are available.

### Strategy A — User‑selected directory + security‑scoped bookmark (PRIMARY, App‑Store‑safe)

The only strategy that works under a strict sandbox **and** is App‑Store‑review
friendly. Flow:

1. Show an `NSOpenPanel` (`canChooseDirectories = true`) pre‑pointed at a
   sensible default (`~/bin`, `~/.local/bin`, or `/usr/local/bin` if the user
   navigates there). The user's selection grants a **security‑scoped** URL.
2. Persist an **app‑scope security‑scoped bookmark** so re‑install/uninstall/
   update works later without re‑prompting (entitlement already present:
   `com.apple.security.files.bookmarks.app-scope`).
3. Inside `url.startAccessingSecurityScopedResource()`, **copy** the bundled
   binaries (Option 4A: copy `dicomkit` + recreate the `dicom-*` symlinks;
   Option 4B: copy each binary), `chmod 0755`.
4. Detect whether the chosen dir is on `PATH`. If not, show precise, copy‑ready
   shell snippets for the user's shell (`zsh`/`bash`):
   ```zsh
   echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
   ```
5. Verify with an in‑process check (file exists + executable bit). We do **not**
   spawn the tool to "test" it — spawning is what the sandbox forbids and what
   we're avoiding.

Why this is sandbox‑legal: writing to a **user‑selected** location is explicitly
permitted by `com.apple.security.files.user-selected.read-write`, which the
entitlements already grant.

### Strategy B — Privileged helper → `/usr/local/bin` (OPTIONAL; Developer‑ID/DMG builds only)

For users who specifically want the tools in `/usr/local/bin` without picking a
folder, use `ServiceManagement`:

- Register a small **non‑sandboxed** privileged helper via **`SMAppService`**
  (macOS 13+) / legacy `SMJobBless`. The main app stays sandboxed; the helper is
  a separate signed daemon that performs a privileged `install`/symlink into
  `/usr/local/bin` after an Authorization Services prompt.
- **Caveats:** privileged helpers are **generally not accepted on the Mac App
  Store**, add notarization/signing surface, and require careful teardown. Ship
  this **only** for the Developer‑ID/DMG channel, and make it an advanced option.

### Strategy C — Reveal in Finder + clipboard snippet (ALWAYS‑AVAILABLE FALLBACK)

Zero privilege, always works, useful when A/B fail or the user prefers manual:

- A button that reveals `Contents/Helpers` in Finder and copies a ready‑to‑paste
  install command to the clipboard, e.g.:
  ```zsh
  sudo cp -R "/Applications/DICOMStudio.app/Contents/Helpers/"dicom-* /usr/local/bin/
  ```
- Purely informational; the user runs it themselves in Terminal.

### Strategy decision matrix

| | Sandbox‑legal | App Store OK | UX | Effort |
| --- | --- | --- | --- | --- |
| A. User‑selected dir + bookmark | ✅ | ✅ | Good (one folder pick) | Low |
| B. Privileged helper → /usr/local/bin | ✅ (app) | ⚠️ risky | Best (no pick) | High |
| C. Reveal + clipboard | ✅ | ✅ | Manual | Trivial |

**Recommendation:** implement **A (primary) + C (fallback)** first. Add **B**
later, gated to the non‑App‑Store build, if `/usr/local/bin` demand is real.

---

## 6. UX / UI design

- **Entry points:**
  - `Settings → Command‑Line Tools` pane (recommended primary home).
  - App menu command: `DICOMStudio → Install Command‑Line Tools…`.
  - A banner/CTA in the CLI Workshop ("Want these in your terminal? Install the
    CLI tools →").
- **Pane contents:**
  - Install status: *Not installed / Installed at `<path>` / Update available*.
  - Bundled version vs. installed version (drift detection — see §6.1).
  - Primary button: **Install Command‑Line Tools…** (Strategy A picker).
  - Secondary: **Reveal Bundled Tools in Finder** (Strategy C).
  - Advanced (DMG build only): **Install to /usr/local/bin (requires admin)**
    (Strategy B).
  - **Uninstall** (removes copied files / symlinks at the bookmarked path).
  - PATH guidance with copy buttons; live "on PATH?" indicator.
  - Tool list (all 43) with per‑tool one‑line descriptions (reuse Workshop's
    tool catalog metadata).

### 6.1 Version / staleness handling

Stamp the bundled payload with the app version (e.g. a `Contents/Helpers/VERSION`
file or read `dicom-info --version` string baked at build time). On launch/pane
open, compare against the version recorded at the install location (write a
`.dicomkit-cli-version` sidecar at install time). If drift → surface
**"Update available"** and re‑run the copy. This mirrors the project memory
concern about stale binaries (`rebuild-tool-after-dicomkit-change`), but solves
it via **re‑copy**, never on‑device rebuild.

---

## 7. Files to add / change

### New (app)
- `Sources/DICOMStudio/Services/CLIToolInstaller.swift` — the installer service
  (Strategies A/B/C), bookmark persistence, copy/symlink, verify, uninstall.
- `Sources/DICOMStudio/ViewModels/CLIToolInstallViewModel.swift` — `@MainActor`
  observable state: install status, versions, PATH detection, progress, errors.
- `Sources/DICOMStudio/Models/CLIToolInstallModel.swift` — value types
  (`InstallLocation`, `InstallStrategy`, `InstallStatus`, `BundledToolInfo`).
- `Sources/DICOMStudio/Views/CLIToolInstallView.swift` — the Settings pane / sheet.
- (Option 4A) `Sources/dicomkit/` — umbrella multitool `executableTarget`
  re‑exporting each tool's root command as a subcommand + `argv[0]` shim.

### New (helper, Strategy B only, later)
- `Sources/DICOMKitInstallHelper/` — non‑sandboxed privileged helper target +
  its own `Info.plist`/launchd plist, `SMAppService` registration.

### Modified
- [DICOMStudio.xcodeproj](DICOMStudio.xcodeproj) — Run Script build phase to
  build + embed CLI binaries into `Contents/Helpers`; Code Sign phase for them;
  `EMBED_CLI_TOOLS` build setting.
- [DICOMStudio.entitlements](DICOMStudio.entitlements) — **re‑enable the sandbox**
  (`app-sandbox = true`); remove the dev‑only absolute‑path temp exceptions;
  keep `files.user-selected.read-write` + `bookmarks.app-scope`.
- [Package.swift](Package.swift) — (Option 4A) add the `dicomkit` product/target.
- Menu commands in [Sources/DICOMStudio/App/ViewerCommands.swift](Sources/DICOMStudio/App/ViewerCommands.swift)
  (or the app's `Commands`) — add the install menu item.

### Removed (production hardening — prerequisite, see §8)
- [Sources/DICOMStudio/Components/CLIToolBuilder.swift](Sources/DICOMStudio/Components/CLIToolBuilder.swift)
- [Sources/DICOMStudio/Components/CLIToolTerminalCompare.swift](Sources/DICOMStudio/Components/CLIToolTerminalCompare.swift)
  and the Workshop's `runTerminalCompare()`/`Compare CLI (TEST)` UI hooks
  (per the removal checklist already written in those files' headers).

---

## 8. Sandbox / signing / notarization implications

1. **Re‑enable App Sandbox** — flip `com.apple.security.app-sandbox` back to
   `true`. This is a **prerequisite** and forces removal of the two TESTING‑ONLY
   spawners (§7 "Removed"). The Workshop keeps working because it's in‑process.
2. **Hardened Runtime + notarization** — every bundled `dicom-*` (or the single
   `dicomkit`) must be signed with the app's identity and the Hardened Runtime,
   or notarization fails. They're inside `Contents/Helpers`, so they're covered
   by the app's notarization submission.
3. **App Store nuances** — Strategy A (copy to user‑selected dir) and C are the
   compliant subset. Strategy B (privileged helper) is **DMG/Developer‑ID only**.
   Gate B behind a compile‑time/distribution flag.
4. **Gatekeeper on the installed copies** — because the binaries are notarized as
   part of the app, the copies the user runs from Terminal pass Gatekeeper. (If
   we ever *download* them post‑install instead of bundling, they'd need separate
   notarization + quarantine handling — avoid that; bundle them.)

---

## 9. Phased milestones

**Phase 0 — Production hardening (prerequisite)**
- Remove `CLIToolBuilder`/`CLIToolTerminalCompare`; re‑enable sandbox; confirm
  Workshop still fully functional in‑process; app archives + notarizes clean.

**Phase 1 — Bundle the tools (Option 4B)**
- Run Script build phase builds `.build/release/dicom-*` and embeds them in
  `Contents/Helpers`; Code Sign phase; verify notarization succeeds.

**Phase 2 — Installer service + UI (Strategies A + C)**
- `CLIToolInstaller`, view model, Settings pane; user‑selected‑dir install with
  bookmark persistence; PATH detection + snippets; reveal‑in‑Finder fallback;
  uninstall.

**Phase 3 — Versioning & update**
- Version stamping + drift detection + "Update available" re‑copy.

**Phase 4 — Size reduction (Option 4A)**
- Add `dicomkit` umbrella multitool + symlinks; switch bundling to the single
  binary; measure bundle‑size delta.

**Phase 5 — (Optional) Privileged helper (Strategy B)**
- `SMAppService` helper for `/usr/local/bin`, DMG channel only.

---

## 10. Testing & acceptance

- **Sandbox regression:** app runs with `app-sandbox = true`; no entitlement
  temp‑path exceptions; Workshop features all pass.
- **Install (A):** picking `~/bin` copies all tools; `dicom-info --version` runs
  from a fresh Terminal (proves the copy is unsandboxed & functional); re‑opening
  the app shows "Installed at ~/bin" via the persisted bookmark.
- **PATH logic:** correct detection + correct `zsh`/`bash` snippet; "on PATH?"
  indicator flips after the user applies it.
- **Update:** bump app version → pane shows "Update available"; re‑copy replaces
  binaries; version sidecar updated.
- **Uninstall:** removes exactly the installed files/symlinks at the bookmarked
  path; nothing else.
- **Notarization:** `xcrun notarytool` + `stapler validate` pass with the
  embedded binaries; `codesign --verify --deep --strict` clean.
- **(4A) Multitool parity:** `dicom-info …` (symlink) produces byte‑identical
  output to the standalone build for a sample corpus — reuse the existing CLI
  parity harness ([Scripts/cli_parity_report.py](Scripts/cli_parity_report.py)).

---

## 11. Risks & mitigations

| Risk | Mitigation |
| --- | --- |
| Bundle bloat from 43 static binaries | Ship 4B for MVP; land 4A multitool to collapse to one binary |
| Local Xcode builds slow (building all CLIs) | Gate embed behind `EMBED_CLI_TOOLS` (Release/Archive only); CI pre‑builds |
| App Store rejects "installer" behavior | Strategy A (user‑selected dir) is the compliant path; helper (B) is DMG‑only |
| Notarization fails on unsigned helper binaries | Sign every embedded binary w/ Hardened Runtime in the Code Sign phase |
| User expects `/usr/local/bin` without admin | Offer Strategy B on DMG build, or clear Strategy C snippet w/ `sudo` |
| Stale installed tools after app update | Version sidecar + "Update available" re‑copy (§6.1) |
| Re‑introducing a sandbox‑breaking spawner | Code‑review rule: no `Process()` in shipping app targets; keep Workshop in‑process |

---

## 12. TL;DR

- **Compile on device under sandbox:** ❌ not possible (no toolchain; sandbox
  blocks the build).
- **Bundle pre‑built, signed tools + in‑app installer:** ✅ the right feature.
- **Sandbox‑safe install:** copy to a **user‑selected directory** via a
  security‑scoped bookmark (entitlements already support it); reveal‑in‑Finder
  fallback; optional privileged helper for `/usr/local/bin` on the DMG build only.
- **Prerequisite:** re‑enable the sandbox and delete the two TESTING‑ONLY
  spawners; the Workshop keeps working because it already runs in‑process.
- **Bundle size:** start with N binaries (4B), then collapse to one `dicomkit`
  multitool with `dicom-*` symlinks (4A).
