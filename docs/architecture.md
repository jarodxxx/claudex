# Architecture

```
┌──────────────────────────────────────────────────────┐
│                       AppDelegate                     │
│                                                       │
│  ┌────────────────────┐   ┌─────────────────────┐    │
│  │ StatusBarController│   │  RefreshScheduler   │    │
│  │  (NSStatusItem +   │◄──┤ (Combine Timer,     │    │
│  │   NSPopover)       │   │  configurable)      │    │
│  └─────────┬──────────┘   └──────────┬──────────┘    │
│            │                         │                │
│            └────────► StatsAggregator ◄───────────────┤
│                       (@MainActor)                    │
│                            │                          │
│         ┌──────────────────┼──────────────────┐       │
│         ▼                  ▼                  ▼       │
│  ┌────────────┐    ┌────────────┐    ┌─────────────┐  │
│  │ClaudeClient│    │ RTKReader  │    │MemPalaceRdr │  │
│  │(URLSession)│    │(Process()) │    │(Process())  │  │
│  └─────┬──────┘    └─────┬──────┘    └─────┬───────┘  │
│        │                 │                 │          │
│        ▼                 ▼                 ▼          │
│   api.claude.ai      `rtk gain`      `mempalace      │
│   (sessionKey)         --format json   status --json` │
│        ▲                                              │
│        │                                              │
│  KeychainStore                                        │
│  (com.claudex.app)                                    │
└──────────────────────────────────────────────────────┘
```

## Module boundaries

- **`Sources/Claude/`**, **`Sources/RTK/`**, **`Sources/MemPalace/`** — one
  folder per integrated service. A service module knows nothing about the
  others. Each exposes a *Reader* (or *Client*) that returns a Codable model.
- **`Config/`** — `KeychainStore`, `AppSettings`, `ServiceConfig`. Single
  source of truth for secrets vs. preferences.
- **`Refresh/`** — `StatsAggregator` (fan-out parallel calls to the three
  sources) + `RefreshScheduler` (timer wrapper).
- **`Menu/`** — `NSStatusItem` + SwiftUI popover. UI only; no business logic.
- **`Onboarding/`** — first-launch wizard. SwiftUI views inside a regular
  `NSWindow`.

## Key design decisions

- **No third-party dependencies.** Everything from Foundation / AppKit /
  SwiftUI / Security.
- **Secrets in Keychain only.** `sessionKey` never touches `UserDefaults` or
  disk files. `ClaudeAuth.mask()` is used everywhere we'd otherwise log it.
- **`Process()` behind a protocol.** `ProcessRunning` lets us mock shell
  invocations in unit tests (see `RTKReaderTests`, `MemPalaceReaderTests`).
- **Schema parity with ClaudeMeter.** `ClaudeUsage` mirrors the layout of
  `~/.claudemeter/usage.json` so we can later expose `~/.claudex/usage.json`
  for downstream tools.
- **Graceful degradation.** Each service is independent. If `rtk` is not
  installed, the RTK section shows "Not detected" — the app still works.
