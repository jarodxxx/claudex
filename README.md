<div align="center">

<img src="docs/logo.png" alt="Claudex" width="160">

# Claudex

**One macOS menu bar, three usage stats: [Claude.ai](https://claude.ai), [RTK](https://github.com/rtk-ai/rtk), and [MemPalace](https://github.com/mempalace/mempalace).**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14.0+-blue.svg)](#requirements)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)](#requirements)
[![Status](https://img.shields.io/badge/status-alpha-orange.svg)](#roadmap)

</div>

---

## What it is

Claudex is a macOS menu bar app that aggregates the usage stats of three tools
you probably already use as a Claude Code power user:

- **Claude.ai** — your 5-hour session, weekly, and Sonnet quotas
- **[RTK](https://github.com/rtk-ai/rtk)** — token savings from the CLI proxy that compresses your bash output
- **[MemPalace](https://github.com/mempalace/mempalace)** — drawer/wing counts of your local-first AI memory

One glance at the menu bar tells you where you stand on all three. Open the
popover for a detailed breakdown.

You don't need all three services installed — Claudex shows what's available
and quietly hides the rest.

## Features

- **Live menu bar indicator** — colored gauge that turns green / orange / red as
  the highest of your three quotas climbs
- **4 menu bar icon styles** — Gauge, Minimal, Circular, Battery (configurable
  in Settings, with live preview)
- **Detailed popover** — per-period progress bars with reset countdowns,
  RTK savings + token counts, MemPalace wing breakdown
- **Native macOS notifications** — configurable warning/critical thresholds,
  reset alerts
- **Three sign-in methods for Claude** — embedded WebKit window for
  email/password accounts, or manual paste from DevTools (works with Google
  SSO too)
- **Auto-detect** — `rtk` and `mempalace` binaries are picked up via
  `which` automatically, override with a path picker
- **Stats export** — writes `~/.claudex/usage.json` after every refresh so
  shell prompts, dashboards, or status-line scripts can consume the same data
- **Dark / light mode aware** — icon and popover follow the system
  appearance, including live re-rendering when you toggle modes

## Screenshots

### Menu bar + popover

The icon lives in your menu bar and turns green / orange / red as your
highest quota climbs. Click it to open the detailed popover.

<p align="center">
  <img src="docs/screenshots/popover.png" width="380" alt="Claudex popover with Claude / RTK / MemPalace sections">
</p>

### Settings — General

Pick your refresh interval, toggle Sonnet display, and choose your menu bar
icon style with a live preview that cycles through the three usage zones.

<p align="center">
  <img src="docs/screenshots/settings-general.png" width="520" alt="Settings General tab">
</p>

### Settings — Notifications

Configure warning and critical thresholds, opt in to reset notifications,
and run a test alert to confirm everything is wired up.

<p align="center">
  <img src="docs/screenshots/settings-notifications.png" width="520" alt="Settings Notifications tab">
</p>

## Requirements

- macOS 14.0 (Sonoma) or later
- An active **Claude.ai** account (Pro or higher)
- Optional: [`rtk`](https://github.com/rtk-ai/rtk) installed (Claudex auto-detects via `which rtk`)
- Optional: [`mempalace`](https://github.com/mempalace/mempalace) installed (idem)

To build from source: Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

## Installation

### Homebrew Cask (recommended)

```bash
brew install --cask jarodxxx/tap/claudex
```

The cask installs `Claudex.app` into `/Applications/`. Launch it from
Spotlight, Launchpad, or Finder. The app is signed with an Apple Developer
ID and notarized by Apple — Gatekeeper will let it through without warnings.

To upgrade later:
```bash
brew upgrade --cask claudex
```

To uninstall:
```bash
brew uninstall --cask claudex
```

### Manual download

1. Grab the latest `Claudex-<version>.dmg` from
   [GitHub Releases](https://github.com/jarodxxx/Claudex/releases)
2. Open the `.dmg` and drag `Claudex.app` to `/Applications/`
3. Eject the disk image, launch from Applications

### From source (developers / contributors)

```bash
brew install xcodegen
git clone https://github.com/jarodxxx/Claudex.git
cd Claudex
./scripts/dev-install.sh
```

The script generates the Xcode project, builds Claudex with your Apple
Development certificate (set the team ID in `project.yml`), installs it to
`/Applications/Claudex.app`, registers it with Launch Services and launches
it. See [docs/RELEASE.md](docs/RELEASE.md) for the public release pipeline.

> **Why install to `/Applications/`?** macOS notification services (and a
> few other entitlements) refuse to talk to apps running from a non-stable
> path like `~/Library/Developer/Xcode/DerivedData/`.

## Configuration

On first launch a 3-card wizard lets you connect each service. You can
re-open it any time from **Settings → General**.

### Claude

Three sign-in methods, choose what fits your account:

#### 1. Web sign-in (recommended for email/password accounts)

Click **"Sign in to Claude"**. A WebKit window opens on `claude.ai/login`,
you authenticate normally, the `sessionKey` cookie is captured and saved to
the macOS Keychain. The cookie never leaves your device.

> **Heads up:** Google SSO is blocked inside embedded browsers by Anthropic.
> If your Claude account uses Google SSO, use method 2 instead.

#### 2. Manual paste (works with Google SSO)

Open `claude.ai` in your browser, find the `sessionKey` cookie in DevTools,
paste it in Claudex.

**Firefox:** F12 → **Storage** tab → Cookies → `https://claude.ai` → click
`sessionKey` → copy the **Value** column.

**Chrome / Edge:** F12 → **Application** → Cookies → `https://claude.ai` →
copy `sessionKey` value.

**Safari:** enable Developer menu first (**Settings → Advanced → Show
features for web developers**), then ⌥⌘I → **Storage** → Cookies →
`sessionKey`.

Claudex auto-detects when a valid `sk-ant-…` value is in your clipboard and
pre-fills the field.

### RTK

Auto-detected via `which rtk`. If you installed RTK in a non-standard
location, override the path in **Settings → General → RTK**.

### MemPalace

Same — auto-detected via `which mempalace`, override in Settings if needed.

## Daily use

- **At a glance** — the menu bar icon color reflects the highest of your
  three Claude quotas (green < 50% < orange < 90% < red).
- **Click the icon** for the detailed popover: progress bars with reset
  countdowns, RTK savings %, MemPalace drawer counts.
- **Click "Refresh"** for an immediate update; otherwise Claudex polls
  every minute (configurable: 1 / 5 / 15 / 30 min).
- **Notifications** — opt-in alerts when quotas cross your warning or
  critical threshold (configurable in Settings → Notifications).

## External integration

After every refresh, Claudex writes a snapshot of all known stats to
`~/.claudex/usage.json`. Shell prompts, statusline scripts and dashboards
can consume it without polling Claude.ai themselves.

```json
{
  "last_updated": "2026-05-04T20:00:00Z",
  "claude": {
    "last_updated": "...",
    "session_usage": { "reset_at": "...", "utilization": 31 },
    "sonnet_usage":  { "reset_at": "...", "utilization": 12 },
    "weekly_usage":  { "reset_at": "...", "utilization": 55 }
  },
  "rtk": {
    "summary": {
      "total_commands": 637,
      "total_saved": 207770,
      "avg_savings_pct": 27.6
    }
  },
  "mempalace": {
    "total_drawers": 30486,
    "wings": [
      { "name": "certi-files", "rooms": [{ "name": "general", "drawers": 9767 }] }
    ]
  }
}
```

Sections may be `null` if the corresponding service is not configured or
its last refresh failed. The Claude section mirrors the
[ClaudeMeter](https://github.com/eddmann/ClaudeMeter) schema for
drop-in compatibility with existing scripts.

### Example — Claude Code statusline

`~/.claude/statusline.sh`:

```bash
#!/bin/bash
usage=$(jq -r '.claude.session_usage.utilization // "?"' ~/.claudex/usage.json 2>/dev/null)
[ -z "$usage" ] || [ "$usage" = "null" ] && usage="?"
echo "Claude: ${usage}%"
```

`~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
```

## Architecture

```
Claudex.app
├── ClaudexApp.swift           @main entry point
├── AppDelegate.swift          NSStatusItem + lifecycle
├── Menu/                      menu bar UI (icon, popover)
├── Sources/
│   ├── Claude/                claude.ai web API client
│   ├── RTK/                   shells out to `rtk gain --format json`
│   └── MemPalace/             shells out to `mempalace status`
├── Config/                    Keychain (sessionKey), UserDefaults (paths/prefs)
├── Settings/                  General / Notifications / About tabs
├── Onboarding/                first-launch wizard
├── Refresh/                   StatsAggregator + Timer + UsageNotifier
└── Actions/                   CommandRunner + system notifications
```

- One folder per integrated service, no cross-talk between them.
- Aggregation happens in `StatsAggregator`; the UI layer just renders.
- Secrets live **only** in Keychain (`com.claudex.app`), never on disk.
- Process launches use the `ProcessRunning` protocol so unit tests can
  stub them.

See [docs/architecture.md](docs/architecture.md) for the full diagram.

## Building from source

```bash
brew install xcodegen           # one-time
git clone https://github.com/jarodxxx/Claudex.git
cd Claudex

# Generate Claudex.xcodeproj (regenerated locally; not committed)
xcodegen generate

# Edit project.yml -> DEVELOPMENT_TEAM if you want signing.
# Without a team, build with: xcodebuild ... CODE_SIGNING_ALLOWED=NO build
# (notifications won't work — see "Why install to /Applications" above)

./scripts/install.sh
```

Run the test suite:

```bash
swift test --parallel --num-workers 1
```

(`--num-workers 1` because the Keychain tests share a single item per
service name and would race in parallel.)

See [docs/xcode-setup.md](docs/xcode-setup.md) for the full Xcode workflow.

## Roadmap

- [x] Signed + notarized `.dmg` via GitHub Actions on every tag
- [x] Homebrew Cask (`brew install --cask jarodxxx/tap/claudex`)
- [ ] Auto-launch at login toggle
- [ ] More menu bar icon styles (Segments, Dual Bar)
- [ ] In-app onboarding for first-time RTK / MemPalace setup
- [ ] Localization (FR, EN, …)
- [ ] App Sandbox + Mac App Store distribution

Contributions welcome — please open an issue first if it's a non-trivial
change. See [docs/RELEASE.md](docs/RELEASE.md) for the release process.

## Disclaimer

**Claudex is unofficial** and is not affiliated with, endorsed by, or
supported by Anthropic, the RTK project, or the MemPalace project.

Claudex talks to the **Claude.ai web API** using browser-based session
cookies. **This may violate Anthropic's Terms of Service.** By using
Claudex you acknowledge that:

- Anthropic may block, restrict, or terminate access at any time
- Your Claude account could be affected by using unofficial API clients
- **Use at your own risk** — the developer assumes no liability

**Data storage:**

- The Claude session key is stored in the macOS Keychain (encrypted,
  device-local only)
- All other prefs are in `UserDefaults` (`com.claudex.app` domain)
- Aggregated stats are written to `~/.claudex/usage.json` (plain JSON,
  utilization percentages only)
- **No data is sent to any third party** — Claudex talks only to
  `claude.ai`, `rtk`, and `mempalace`

This software is provided "as is" under the MIT License, without warranty
of any kind.

## Credits

Claudex stands on the shoulders of three excellent projects:

- **[ClaudeMeter](https://github.com/eddmann/ClaudeMeter)** by Edd Mann (MIT)
  — the original menu bar app for Claude.ai usage. Claudex re-implements the
  Claude.ai client by reading ClaudeMeter's open-source Swift code, and
  preserves its `usage.json` schema.
- **[RTK](https://github.com/rtk-ai/rtk)** by the rtk-ai team (MIT) — the CLI
  proxy whose stats Claudex surfaces.
- **[MemPalace](https://github.com/mempalace/mempalace)** by the MemPalace
  team (MIT) — the local-first AI memory whose drawer counts Claudex shows.

## License

[MIT](LICENSE) — © 2026 Avi Teboul.
