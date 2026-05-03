# Instructions for Claude Code

## Project

Claudex — macOS menu bar app aggregating usage stats from Claude.ai, RTK and mempalace.
See [README.md](README.md) for the public-facing overview.

## Stack

- Swift 5.9+ / SwiftUI, macOS 14+
- Xcode 16+
- No third-party dependencies (use stdlib + Foundation + AppKit + Security frameworks)

## Architecture

```
Claudex/
├── ClaudexApp.swift            @main entry point
├── AppDelegate.swift           NSStatusItem lifecycle
├── Menu/                       status bar UI (NSStatusItem + NSPopover)
├── Sources/
│   ├── Claude/                 ClaudeClient + ClaudeWebLogin (WKWebView) + Codable models
│   ├── RTK/                    RTKReader (Process → rtk gain --format json)
│   └── MemPalace/              MemPalaceReader (Process → mempalace ...)
├── Config/                     KeychainStore, AppSettings (UserDefaults)
├── Actions/                    CommandRunner (async + notifications), CommandOutputWindow
├── Onboarding/                 first-launch wizard (NSWindow + SwiftUI views)
└── Refresh/                    RefreshScheduler, StatsAggregator, UsageExporter
```

## Conventions

- One service = one folder under `Sources/`. A service module knows nothing about
  the others — aggregation happens at the UI layer (`DropdownView`).
- Secrets (Claude `sessionKey`) live ONLY in Keychain, never in `UserDefaults`,
  never in files on disk, never logged.
- `Process()` for shelling out to `rtk` / `mempalace`. Never `bash -c`.
- All network calls use `URLSession` async/await. No third-party HTTP libs.
- Codable models match the upstream JSON schema 1:1 — don't massage field names.

## Testing

- Unit tests in `ClaudexTests/` — one file per source module.
- Network calls are mocked via `URLProtocol` subclass (no live HTTP in tests).
- `Process()` calls are wrapped behind a protocol so readers can be mocked.

## Workfiles (private, not in Git)

`.workfiles/` contains personal notes, API research captures, mockups, test
secrets. It IS in `.gitignore` — do not commit anything from it.

When reverse-engineering an API endpoint, save the captured request/response
under `.workfiles/api-research/<service>/<endpoint>.md`.

## Build & test commands

```bash
# Build
xcodebuild -project Claudex.xcodeproj -scheme Claudex build

# Test
xcodebuild test -project Claudex.xcodeproj -scheme Claudex \
  -destination 'platform=macOS'

# Verify code signature
codesign -dv --verbose=4 build/Release/Claudex.app
```

## Don't

- Don't add third-party Swift packages without discussing first.
- Don't write secrets to disk — Keychain only.
- Don't commit anything from `.workfiles/`.
- Don't log full `sessionKey` values (mask to `sk-ant-...****`).
