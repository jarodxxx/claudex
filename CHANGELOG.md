# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
