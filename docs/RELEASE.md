# Cutting a release

This document is for the maintainer. Users don't need to read it — they just
do `brew install --cask jarodxxx/tap/claudex` or download the `.dmg`.

## TL;DR

```bash
# Bump version in CHANGELOG.md, commit, then:
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions takes over from there:
1. Builds Claudex.app with the Release config (Developer ID Application
   signing).
2. Notarizes the .app with Apple via `notarytool` and staples the ticket.
3. Packages it into `Claudex-<version>.dmg`.
4. Creates a GitHub Release and uploads the .dmg as an asset.
5. Dispatches `update-cask.yml` in `jarodxxx/homebrew-tap` to bump the cask
   formula. Within ~30 s, `brew install --cask jarodxxx/tap/claudex` picks
   up the new version.

Total runtime: ~10–15 min, mostly waiting on Apple's notary service.

## Prerequisites — one-time setup

The workflow needs **7 GitHub Secrets** in `Settings → Secrets and variables → Actions`:

| Secret | What | Where to get it |
|---|---|---|
| `MACOS_CERTIFICATE` | base64-encoded `.p12` of "Developer ID Application: Elanos (5FDYH5TMJ3)" | See ["Export the certificate"](#export-the-certificate) below |
| `MACOS_CERTIFICATE_PASSWORD` | Password used when exporting the .p12 | You set it during export |
| `KEYCHAIN_PASSWORD` | Arbitrary password for the temporary CI keychain | Any random string, e.g. `openssl rand -base64 32` |
| `APPLE_ID` | Apple ID email tied to your Developer account | e.g. `teboul.avi@gmail.com` |
| `APPLE_ID_PASSWORD` | **App-specific password** (not your Apple ID password) | See ["Generate an app-specific password"](#generate-an-app-specific-password) |
| `MACOS_TEAM_ID` | Apple Developer Team ID | `5FDYH5TMJ3` |
| `HOMEBREW_TAP_TOKEN` | Personal Access Token with `repo` scope on `jarodxxx/homebrew-tap` | GitHub → Settings → Developer settings → Personal access tokens |

### Export the certificate

You need a **Developer ID Application** certificate (NOT "Apple Development"
which is for local dev only).

1. Go to [developer.apple.com/account/resources/certificates/list](https://developer.apple.com/account/resources/certificates/list)
2. Make sure the **Elanos** team is selected (Account → Membership)
3. Create a new certificate of type **Developer ID Application** if none exists
4. Download it, double-click to import into Keychain Access (login keychain)
5. In Keychain Access, find "Developer ID Application: Elanos (5FDYH5TMJ3)"
   — **expand the arrow** so its private key is selected too
6. Right-click → Export 2 items → save as `claudex-cert.p12` with a strong
   password (you'll add that password to GitHub Secrets as `MACOS_CERTIFICATE_PASSWORD`)
7. Convert to base64 for GitHub:
   ```bash
   base64 -i claudex-cert.p12 | pbcopy
   ```
8. Paste the clipboard contents into the `MACOS_CERTIFICATE` secret
9. Delete the `.p12` file from disk (`rm claudex-cert.p12`) — it's now safely
   in your password manager and in GitHub Secrets

### Generate an app-specific password

Apple requires app-specific passwords for command-line tools like `notarytool`
(your real Apple ID password won't work).

1. Go to [appleid.apple.com](https://appleid.apple.com) → Sign in
2. Sign-In and Security → **App-Specific Passwords** → Generate
3. Label it "Claudex CI Notarization"
4. Copy the password (looks like `xxxx-xxxx-xxxx-xxxx`) → paste into the
   `APPLE_ID_PASSWORD` secret

### Set up the homebrew-tap repo

See [HOMEBREW_TAP_SETUP.md](HOMEBREW_TAP_SETUP.md) for the one-time creation
of `jarodxxx/homebrew-tap`.

## Cutting a release — step by step

1. **Update CHANGELOG.md** — move items from `[Unreleased]` to a new
   `[<version>] - YYYY-MM-DD` section.
2. **Commit & push to main**:
   ```bash
   git add CHANGELOG.md
   git commit -m "Release vX.Y.Z"
   git push
   ```
3. **Tag and push the tag**:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
4. **Watch the workflow**:
   ```bash
   gh run watch
   ```
   or visit the Actions tab in GitHub.

5. **After ~10–15 min**, the GitHub Release is published and the cask is
   bumped. Verify with:
   ```bash
   brew update
   brew install --cask jarodxxx/tap/claudex
   ```

## Troubleshooting

### Notarization fails

- **"The signature does not include a secure timestamp"** — the cert was
  exported without its private key, OR the `OTHER_CODE_SIGN_FLAGS` setting
  is missing `--timestamp`. Check `project.yml`.
- **"User account validation failed"** — `APPLE_ID_PASSWORD` is not the
  app-specific password. Re-generate one at appleid.apple.com.
- **"Hardened runtime not enabled"** — `ENABLE_HARDENED_RUNTIME` should be
  `YES` in `project.yml`. Already set.

To inspect the failed submission:
```bash
xcrun notarytool log <submission-id> \
  --apple-id "<your-id>" --password "<app-pwd>" --team-id 5FDYH5TMJ3
```

### Cask bump fails

- **"Workflow does not exist"** — the `homebrew-tap` repo doesn't have
  `.github/workflows/update-cask.yml` yet. See [HOMEBREW_TAP_SETUP.md](HOMEBREW_TAP_SETUP.md).
- **"403 Forbidden"** — `HOMEBREW_TAP_TOKEN` is missing `repo` scope or
  is expired.

### Local sanity-check before tagging

You can dry-run a Release build locally (without notarization):

```bash
xcodebuild archive \
  -project Claudex.xcodeproj \
  -scheme Claudex \
  -configuration Release \
  -archivePath /tmp/Claudex.xcarchive

xcodebuild -exportArchive \
  -archivePath /tmp/Claudex.xcarchive \
  -exportOptionsPlist scripts/ExportOptions.plist \
  -exportPath /tmp/Export

codesign -dv --verbose=4 /tmp/Export/Claudex.app
# Should show "Authority=Developer ID Application: Elanos (5FDYH5TMJ3)"
```
