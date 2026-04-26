# CLAUDE.md — Forgotten Plugins

## What this app does

macOS menubar app that surfaces audio plugins the user owns but hasn't recently used. Scans AU, CLAP, VST2, VST3, and AAX plugin directories. Uses filesystem **atime** (last-accessed timestamp) as a proxy for the last time a DAW loaded a plugin. No network requests, no DAW private data.

## Architecture

- **AppKit + SwiftUI** — `NSStatusItem` / `NSPopover` shell in AppKit; popover content in SwiftUI
- **`MenuBarController`** — manages the status item, popover, hover tracking, and right-click context menu
- **`PluginStore`** — core logic: scanning, rescan detection, forgotten plugin calculation, dismiss/ignore, JSON persistence, manufacturer resolution
- **`PluginScanner`** — filesystem scanning across all plugin directories; atime/mtime heuristic; reads manufacturer from AU `Info.plist` and VST3 `moduleinfo.json`
- **`AnthropicClient`** — optional batch manufacturer lookup via Claude Haiku; API key read from env var or `~/Library/Application Support/ForgottenPlugins/.env`
- **`PluginCategory`** — shared taxonomy (Instrument / Effect / Unknown); reads AU `Info.plist` and VST3 `moduleinfo.json` statically
- **`VolumeChecker`** — detects `noatime` volumes via `statfs()` + `MNT_NOATIME`
- **`Preferences`** — `ObservableObject`; `enabledFormats`, `enabledCategories`, `hideNeverUsed`, `forgottenThresholdDays` (default 90); persisted to `UserDefaults`
- **`FixedSizeHostingController`** — plain `NSViewController` wrapper around `NSHostingController` to prevent the popover from resizing when SwiftUI content changes

## Key design decisions

### JSON over SQLite
Plugin data is stored as JSON at `~/Library/Application Support/ForgottenPlugins/plugins.json`. SQLite was considered but JSON is sufficient at this scale (a few hundred plugins). Do not suggest migrating.

### atime heuristic
A plugin access is only counted as genuine DAW usage when `atime > mtime + 300s`. If `atime ≈ mtime` the file was almost certainly read by an installer, not loaded by a DAW.

### DAW rescan detection
If 10+ plugins have atimes all within a 30-second window, the entire cohort is classified as a DAW rescan and none of those atimes update `lastConfirmedUsedAt`. Constants: `rescanWindowSeconds = 30`, `rescanMinCohortSize = 10`.

### Plugin deduplication
Plugins are tracked per-format in storage (`Plugin`) but grouped by lowercased name for display (`ForgottenPlugin`). Only enabled formats contribute to the "last used" date shown to the user.

### Dismiss / ignore
The × button on each row marks the plugin as ignored (`isDismissed = true`). This is not permanent: if the plugin is genuinely used again, `isDismissed` is automatically cleared. "Reset all ignored plugins" in the right-click context menu restores all at once.

### Manufacturer resolution
1. `PluginScanner` reads manufacturer statically: AU parses `AudioComponents[].name` (the part before the first `:`), VST3 reads the `vendor` field from `moduleinfo.json`.
2. After each scan, `propagateManufacturers()` copies a known manufacturer to any same-name plugin records that are still `nil`.
3. Remaining unknowns are sent in a single batch request to Claude Haiku via `AnthropicClient.resolveManufacturers(for:)`.
4. When looking up manufacturer for display, all formats are searched (not just enabled ones) so a disabled AU can still supply the name.

The Anthropic API is entirely optional — if no API key is present, steps 3 is skipped silently.

### Click-to-search
Clicking a plugin row opens a Google search for `"Manufacturer" "Plugin Name"` (or `"Plugin Name" audio plugin` if the manufacturer is unknown). Using a search rather than a direct URL avoids hallucinated or stale product pages.

### Forgotten threshold
Configurable via a text field in the settings panel (gear icon). Default is 90 days. Stored in `Preferences.forgottenThresholdDays`.

### Login item
Registered once on first launch using `SMAppService.mainApp.register()` (macOS 13+). A `UserDefaults` flag (`hasRegisteredLoginItem`) prevents re-registration.

### Plugin categories
- **AU**: read from `Contents/Info.plist` → `AudioComponents[].type` (fourCC). Analysers fold into Effect.
- **VST3**: read from `Contents/moduleinfo.json` → `classes[].subCategories` (SDK 3.7+ only; older = Unknown).
- **CLAP, VST2, AAX**: always Unknown — category requires loading the binary at runtime.

### Popover size
Fixed at 320×440. `FixedSizeHostingController` + deferred `window.minSize = window.maxSize` lock in `MenuBarController.lockPopoverWindowSize()` prevents SwiftUI content changes from resizing the popover.

### Menubar icon
Custom PNG asset in `Assets.xcassets/MenuBarIcon.imageset` (1x/2x/3x, template image). Set `isTemplate = true` so the system colours it for light/dark mode and menubar highlight.

## Project generation and building

Uses **xcodegen**. Run `xcodegen` after adding new `.swift` files or assets — the `.xcodeproj` is not committed (listed in `.gitignore`).

Always build at the end of every change session:
```
xcodebuild -scheme ForgottenPlugins -configuration Debug build
```
Do not report work as done without a successful build. Do not launch or kill the app — leave that to the user.

A post-build script in `project.yml` copies the built app to `/Applications` automatically:
```yaml
postBuildScripts:
  - name: Install to /Applications
    script: |
      cp -R "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app" "/Applications/${PRODUCT_NAME}.app"
```
This ensures `SMAppService` registers the correct stable path rather than the DerivedData path.

## Deployment target

macOS 13.0.
