# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
