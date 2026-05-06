# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.1.1] - 2026-05-06

### Fixed
- **In-app updater — "already installed" case**: when Homebrew already has the
  latest version installed, the output window now shows "already installed" instead
  of falsely claiming the update succeeded.
- **Relaunch after brew upgrade**: the Relaunch button now opens
  `/Applications/Claudex.app` (the standard Homebrew cask install path) instead of
  the bundle that triggered the upgrade, so users running a dev build get the correct
  production binary on relaunch.

## [2.1.0] - 2026-05-06

### Added
- **In-app updater** — "Update Now" button in the update alert and in Settings → About.
  On first use, Claudex asks how it was installed (Homebrew or manual download) and
  remembers the answer. Homebrew path runs `brew upgrade --cask claudex` in the
  background and shows live output in a window with a "Relaunch" button on success.
  Manual path opens the GitHub release page. Install method can be reset at any time
  from Settings → About.
- **Caveman extended stats** — the Caveman section now surfaces 8 additional metrics
  parsed from Claude Code session JSONL files:
  - Cache creation vs. cache read tokens (split from the previously merged `cachedTokens`)
  - Cache hit rate progress bar
  - Message count (individual assistant turns, not just file count)
  - Tool call count (`tool_use` content blocks)
  - Active projects (distinct project directories touched in the window)
  - Dominant model (Claude model that consumed the most tokens)
  - Estimated cost in USD (Haiku / Sonnet / Opus pricing table, May 2025)
- **Tool card UI** — each tool section (Claude, RTK, Caveman, MemPalace) is now
  wrapped in a card with rounded corners, a subtle border, and a soft drop shadow.
  Section dividers removed; card borders provide visual separation.
- **Compact token formatting** — large token counts displayed as `32.8M` instead of
  `32 831 809`. Tokens section uses a 4-column layout separated by thin vertical rules.

### Changed
- `Info.plist CFBundleShortVersionString` now uses `$(MARKETING_VERSION)` instead of
  a hardcoded string — single source of truth in `project.yml`.

## [2.0.0] - 2026-05-05

### Added
- **Modular tool architecture** (`Tools/ToolDefinition`, `Tools/ToolRegistry`). Each
  tool is now a first-class `ToolID` with name, icon, category, and estimated
  popover height. Tools can be enabled/disabled from Settings → General → Tools.
  The registry auto-injects category headers once the combined height exceeds 500 pt.
- **Caveman integration** — reads Claude Code session JSONL files from
  `~/.claude/projects/` (last 24 h) and surfaces input/output token volumes
  and the output ratio (a proxy for response compression). No binary required.
- **Settings → Tools tab** — binary paths for RTK and MemPalace, plus Caveman
  session-folder configuration (custom or default `~/.claude/projects`).
- **ProcessLocator extended PATH** — now probes `/opt/homebrew/bin`,
  `~/.local/bin`, `~/.cargo/bin` etc. directly before falling back to `which`,
  so binaries installed outside the system PATH are auto-detected.

### Changed
- Settings is now a 4-tab window: General / Tools / Notifications / About.
- Settings → General no longer contains binary paths (moved to Tools).
- About tagline: "Your AI dev tools, unified in the menu bar."
- Popover sections are hidden when a tool is not configured (no binary, no data).

## [1.0.2] - 2026-05-04

### Changed
- **Menu bar icon now reflects the most imminent quota**, not the highest %.
  We pick the quota whose `resets_at` is closest in time (typically the
  5-hour session) so the icon shows what will actually constrain the next
  few hours of usage. Previously a Weekly at 63 % shadowed a Session at
  26 %; now Session at 26 % drives the icon because it resets sooner.

## [1.0.1] - 2026-05-04

### Fixed
- Claude section showed `Error: invalidResponse("missing or invalid five_hour.resets_at")`
  when the user had no recent activity in a quota window (the API returns
  `resets_at: null` in that case). We now fall back to a 5h / 7d projection
  so the utilization still renders.

## [1.0.0] - 2026-05-04

First public release.

### Added
- **2 new menu bar icon styles** — `Segments` (5 vertical bars filling
  left-to-right, cellular-signal style) and `DualBar` (two stacked horizontal
  bars: session on top, weekly below).
- **In-app help for missing RTK / MemPalace** — when a binary is not
  auto-detected, the wizard shows a one-line description, a link to the
  install page and a "Copy install command" button.
- **Precise reset countdowns** — values under 2 hours show `1h 24min` /
  `47min` instead of the rounded `1 hr` / `47 min`.
- **In-app update checker** (`UpdateChecker`). Pings GitHub Releases at launch
  (silently, ≤ 1 / 24 h) and on demand from Settings → About. Shows an alert
  with "Open Release Page" / "Copy Brew Command" / "Skip This Version".
- **Launch-at-login** toggle in Settings → General, backed by `SMAppService`.
- Embedded `WKWebView` Claude sign-in flow (`ClaudeWebLogin`). Captures the
  `sessionKey` cookie on successful login and saves it to Keychain. Manual
  paste fallback kept under a disclosure group.
- "Sign out" button in the Claude setup view.
- Popover action buttons:
  - Claude: open `claude.ai` in the default browser.
  - RTK: run `rtk gain --history` in the background and display the output in
    a dedicated window. Result also surfaces as a macOS notification.
- `CommandRunner` (background `Process()` execution + `UNUserNotificationCenter`)
  and `CommandOutputWindow` (read-only mono-spaced output viewer).
- `UsageExporter` writes `~/.claudex/usage.json` on every refresh, mirroring
  the ClaudeMeter schema for the Claude section and adding RTK + MemPalace.
- Initial project skeleton (Swift 5.9, SwiftUI, macOS 14+).
- Module structure: `Sources/Claude`, `Sources/RTK`, `Sources/MemPalace`, `Config`, `Menu`, `Onboarding`, `Refresh`.
- `KeychainStore` wrapper around the macOS Security framework.
- `ProcessRunning` protocol + `SystemProcessRunner` to shell out to `rtk` and `mempalace`.
- `RTKReader`, `MemPalaceReader` and matching Codable models.
- `ClaudeClient` skeleton (endpoint to be reverse-engineered).
- `StatusBarController`, `DropdownView`, `OnboardingWindow` and the three setup views.
- `RefreshScheduler` (Combine `Timer`, configurable interval).
- `Package.swift` for SwiftPM build of the core library + tests.
- GitHub Actions CI: `swift build` + `swift test` on macos-14.
- Unit tests: Keychain, ClaudeAuth, RTKReader, MemPalaceReader, ClaudeUsage decoding.

### To do
- Reverse-engineer the actual Claude usage endpoint and wire `ClaudeClient.fetchUsage()`.
- Generate `Claudex.xcodeproj` to ship a real `.app` bundle.
- App icon, screenshots, Homebrew tap.
