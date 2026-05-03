# Building the .app bundle

Claudex uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate
`Claudex.xcodeproj` from `project.yml`. The `.xcodeproj` itself is **not
committed** — contributors regenerate it locally so we never fight pbxproj
merge conflicts.

## One-time setup

```bash
brew install xcodegen
```

## Generate the project

```bash
cd /path/to/Claudex
xcodegen generate
```

This creates `Claudex.xcodeproj` with:
- `Claudex` target (macOS app, deployment target 14.0, `LSUIElement = YES`)
- `ClaudexTests` target (XCTest bundle, all tests in `ClaudexTests/`)
- Bundle ID `com.claudex.app`
- Auto-managed signing (you'll need to pick your team in Xcode the first time)

## Open & run

```bash
open Claudex.xcodeproj
```

In Xcode:
1. **Signing & Capabilities** → pick your team
2. `⌘R` to run

The app launches silently into the menu bar (no Dock icon). On first launch
it shows the onboarding window because no service is configured yet.

## Build from command line (no Xcode UI)

```bash
xcodebuild \
  -project Claudex.xcodeproj \
  -scheme Claudex \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Output `.app` lands in:
```
~/Library/Developer/Xcode/DerivedData/Claudex-*/Build/Products/Debug/Claudex.app
```

You can launch it directly:
```bash
open ~/Library/Developer/Xcode/DerivedData/Claudex-*/Build/Products/Debug/Claudex.app
```

## Run tests

```bash
# Via SwiftPM (fast, no Xcode required for the core library)
swift test --parallel --num-workers 1

# Via Xcode (uses the generated xcodeproj)
xcodebuild test -project Claudex.xcodeproj -scheme Claudex \
  -destination 'platform=macOS'
```

## Modifying the project structure

If you add a new Swift folder, edit `project.yml` (if needed) and re-run
`xcodegen generate`. Source folders under `Claudex/` are auto-discovered, so
adding a new file usually requires no `project.yml` changes.
