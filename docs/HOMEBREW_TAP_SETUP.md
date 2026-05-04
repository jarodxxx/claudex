# One-time setup: homebrew-tap repo

`brew install --cask jarodxxx/tap/claudex` works because Homebrew looks for a
repo named `jarodxxx/homebrew-tap` and reads cask formulas from
`Casks/<name>.rb`. This document walks you through creating that repo once.

## 1. Create the repo

```bash
gh repo create jarodxxx/homebrew-tap --public \
  --description "Homebrew tap for Claudex and other tools" \
  --clone --add-readme
cd homebrew-tap
mkdir -p Casks .github/workflows
```

## 2. Add the Claudex cask

Create `Casks/claudex.rb` with the template below. The `version` and `sha256`
fields will be auto-bumped by the release workflow on every Claudex release —
the placeholder values are fine for the initial commit.

```ruby
cask "claudex" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/jarodxxx/Claudex/releases/download/v#{version}/Claudex-#{version}.dmg"
  name "Claudex"
  desc "macOS menu bar app aggregating Claude.ai, RTK and MemPalace usage"
  homepage "https://github.com/jarodxxx/Claudex"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "Claudex.app"

  zap trash: [
    "~/.claudex",
    "~/Library/Preferences/com.claudex.app.plist",
    "~/Library/Caches/com.claudex.app",
  ]
end
```

## 3. Add the auto-bump workflow

Create `.github/workflows/update-cask.yml` with this content. It is dispatched
by Claudex's release workflow on every successful release.

```yaml
name: Update Cask

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'New version (e.g. 1.0.0, no leading v)'
        required: true
      sha256:
        description: 'SHA256 of the .dmg'
        required: true
      tag:
        description: 'Git tag (e.g. v1.0.0)'
        required: true

permissions:
  contents: write

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Update claudex.rb
        run: |
          sed -i "s/version \".*\"/version \"${{ inputs.version }}\"/" Casks/claudex.rb
          sed -i "s/sha256 \".*\"/sha256 \"${{ inputs.sha256 }}\"/" Casks/claudex.rb

          echo "--- Updated cask ---"
          cat Casks/claudex.rb

      - name: Commit and push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add Casks/claudex.rb
          git commit -m "claudex: bump to ${{ inputs.version }}"
          git push
```

## 4. Commit and push

```bash
git add Casks/claudex.rb .github/workflows/update-cask.yml
git commit -m "Initial tap with claudex cask"
git push
```

## 5. Test the install

Once `Claudex` v1.0.0 is released and the cask updated:

```bash
brew install --cask jarodxxx/tap/claudex
```

That's it. From now on, every `git tag vX.Y.Z && git push --tags` in the
Claudex repo will automatically:
1. Build, sign and notarize the `.app`
2. Publish a GitHub Release with the `.dmg`
3. Dispatch this workflow which bumps the cask
4. Users can `brew upgrade --cask claudex` to get the new version

## Adding more tools later

This tap can host other casks (other tools you build). Just add another
`.rb` file in `Casks/` and a matching auto-bump workflow.
