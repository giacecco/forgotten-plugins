# Forgotten Plugins

A macOS menubar app that helps musicians rediscover plugins they own but haven't used in a long time — reducing waste and encouraging creative exploration.

## How it works

Forgotten Plugins scans your standard plugin directories (AU, VST2, VST3, AAX) and uses each plugin binary's **last-accessed timestamp** (atime) as a proxy for the last time a DAW loaded it. Plugins you haven't opened in a while surface as suggestions in a popover when you hover over the menubar icon.

## System requirements

### atime must be enabled (necessary condition)

Forgotten Plugins relies on the filesystem recording access timestamps on plugin files. This requires that the volume containing your plugin directories is **not** mounted with the `noatime` option.

Most standard macOS installations (APFS on the internal drive) have atime enabled by default. If your plugins live on an external drive, check its mount options. If atime is disabled, the app will detect this at launch and display a warning — plugin suggestions will not be available for affected directories until atime is re-enabled.

To check whether atime is enabled on a volume, run in Terminal:

```
mount | grep noatime
```

If your plugin volume appears in the output, atime is disabled on it.

### Plugin updates and the atime/mtime heuristic

When a plugin is installed or updated, the installer writes a new binary, setting both the modification timestamp (mtime) and — incidentally — the access timestamp (atime) to roughly the same moment. This would make a freshly updated plugin look "recently used" even if you haven't opened it in years.

To avoid this false positive, Forgotten Plugins only treats an access as genuine DAW usage when **atime is meaningfully later than mtime** (by default, more than a few minutes). If `atime ≈ mtime`, the app assumes the file was read as part of installation, not loaded by a DAW.

The app also tracks mtime across scans: if a plugin's mtime changes between scans, it records an update event and resets the usage clock accordingly.

## Supported plugin formats

- **AU** (Audio Units) — macOS only
- **CLAP**
- **VST2**
- **VST3**
- **AAX** (Pro Tools)

## Plugin directories scanned

| Format | System-wide | User |
|--------|-------------|------|
| AU | `/Library/Audio/Plug-Ins/Components/` | `~/Library/Audio/Plug-Ins/Components/` |
| CLAP | `/Library/Audio/Plug-Ins/CLAP/` | `~/Library/Audio/Plug-Ins/CLAP/` |
| VST2 | `/Library/Audio/Plug-Ins/VST/` | `~/Library/Audio/Plug-Ins/VST/` |
| VST3 | `/Library/Audio/Plug-Ins/VST3/` | `~/Library/Audio/Plug-Ins/VST3/` |
| AAX | `/Library/Application Support/Avid/Audio/Plug-Ins/` | `~/Documents/Avid/Audio/Plug-Ins/` |

## DAW plugin rescans

Many DAWs (Bitwig, Logic, Ableton, etc.) periodically rescan all installed plugins — on launch, after a macOS update, or when new plugins are detected. During a rescan the DAW loads every plugin binary via `dlopen`, which updates atime on each file. Without protection, this would make every plugin look "recently used" and suppress suggestions.

Forgotten Plugins detects rescans using a sliding-window heuristic: if 10 or more plugins have atime values that all fall within the same 30-second window, the entire cohort is classified as a rescan and none of those atimes are recorded as genuine usage. A musician opening plugins in a project might load a handful over several minutes; a DAW rescan touches hundreds within seconds.

This heuristic has two edge cases worth knowing:

- **False negative (rescan not detected):** if a DAW scans very slowly (e.g. due to a slow drive), the cohort may spread beyond 30 seconds and get treated as genuine use. The 30-second window is conservative to avoid this.
- **False positive (real use flagged as rescan):** if you happen to open 10+ plugins in a project within 30 seconds, those sessions would not be recorded. Unlikely in practice.

## Plugin type detection

Forgotten Plugins classifies each plugin as **Instrument**, **Effect**, or **Unknown**. This is done by reading static metadata from the plugin bundle — no plugin binary is loaded.

| Format | Source | Notes |
|--------|--------|-------|
| AU | `Contents/Info.plist` → `AudioComponents[].type` | Reliable; every AU bundle declares its type |
| VST3 | `Contents/moduleinfo.json` → `classes[].subCategories` | Only present in plugins built with VST3 SDK 3.7 or later; older plugins return Unknown |
| VST2 | — | Category only available at runtime; always Unknown |
| CLAP | — | Category only available at runtime; always Unknown |
| AAX | — | Category only available at runtime; always Unknown |

AU analysers (spectrum analysers, meters, scopes) register as the `aufx` (Effect) type — the AU format has no dedicated analyser type. They will appear as **Effect**, which is technically correct.

MIDI effects and analysers are folded into **Effect** in the shared taxonomy.

## Dismissing plugins

Each plugin row has an **×** button that dismisses the plugin, hiding it from the list. Dismissal is not permanent: if you genuinely use the plugin again (i.e. a DAW loads it and atime advances past mtime by the required margin), it will automatically reappear the next time the list is refreshed.

To restore all dismissed plugins at once without waiting for usage events, right-click the menubar icon and choose **Reset all ignored plugins**.

## Manufacturer names

Forgotten Plugins tries to identify who made each plugin:

1. **AU** — reads the `AudioComponents[].name` field in `Contents/Info.plist` (the part before the first colon, e.g. `Native Instruments` from `Native Instruments: Massive X`).
2. **VST3** — reads the `vendor` field in `Contents/moduleinfo.json` (present in plugins built with VST3 SDK 3.7+).
3. **Cross-format propagation** — if one format of a plugin has a manufacturer, the name is copied to any other formats of the same plugin that are missing it.
4. **Anthropic API** — any plugin still missing a manufacturer after the above steps is sent in a single batch request to Claude Haiku. This step is optional and requires an API key (see below).

### Setting up the Anthropic API key (optional)

Without an API key the app works fully — manufacturer lookup from bundle metadata still runs; only the AI batch step is skipped.

To enable AI-assisted manufacturer lookup, provide your Anthropic API key in either of two ways:

**Environment variable** (takes precedence):
```
export ANTHROPIC_API_KEY=sk-ant-...
```

**.env file** (read at launch):
Create `~/Library/Application Support/ForgottenPlugins/.env` with the contents:
```
ANTHROPIC_API_KEY=sk-ant-...
```

## Clicking a plugin

Clicking a plugin row opens a Google search for the plugin in your default browser. If the manufacturer is known, the search is `"Manufacturer" "Plugin Name"`; otherwise it falls back to `"Plugin Name" audio plugin`. This reliably surfaces the correct product page without risk of hallucinated or stale direct URLs.

## Forgotten threshold

The number of days without use before a plugin is considered forgotten. Default is 90 days. Adjust it in the settings panel (gear icon in the popover header).

## Starts at login

Forgotten Plugins registers itself as a login item on first launch using macOS's built-in login item API. You can remove it later via **System Settings → General → Login Items**.

## Privacy

Plugin metadata and usage timestamps are stored locally at `~/Library/Application Support/ForgottenPlugins/plugins.json`. No data leaves your machine unless you have configured an Anthropic API key, in which case plugin names (not file paths or personal data) are sent to the Anthropic API solely for manufacturer lookup.
