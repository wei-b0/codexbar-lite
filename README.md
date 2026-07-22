# CodexBar Lite

<p align="center">
  Native macOS menu bar app for tracking your Codex usage from your existing local session.
</p>

<p align="center">
  <a href="https://github.com/wei-b0/codexbar-lite/releases/latest">
    <img alt="Latest release" src="https://img.shields.io/github/v/release/wei-b0/codexbar-lite?display_name=tag">
  </a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2013%2B-black">
  <img alt="Swift" src="https://img.shields.io/badge/swift-5.10%2B-F05138">
  <img alt="Type" src="https://img.shields.io/badge/app-menu%20bar-0A7CFF">
</p>

<p align="center">
  <img src="assets/screenshots/hero-menu-bar.png" alt="CodexBar Lite running in the macOS menu bar" width="900">
</p>

<p align="center">
  <img src="assets/screenshots/dropdown.png" alt="CodexBar Lite dropdown showing usage details" width="700">
</p>

## What It Does

- Shows your current Codex usage in the macOS menu bar
- Uses your existing `codex login` session
- Refreshes automatically in the background
- Starts automatically on login
- Falls back to cached usage when live requests fail

## Why This Exists

Most usage trackers depend on one or more of these:

- browser extensions
- cookie scraping
- Chrome profile access
- keychain access
- external dashboards
- API keys

CodexBar Lite does not.

It reads the same local Codex auth session you already use and makes the minimum request needed to display your usage.

## Security Model

CodexBar Lite reads:

```txt
~/.codex/auth.json
```

It does not require:

- Chrome access
- Safari access
- Firefox access
- macOS Keychain access
- Accessibility permissions
- Screen recording permissions
- full disk access
- API keys
- telemetry
- analytics

## Current Behavior

The app shows the live usage windows returned by the current Codex usage API.

That means:

- if Codex returns two windows, the app shows two windows
- if Codex returns one window, the app shows one live value and `--` for the missing slot
- reset countdowns are computed from the absolute `reset_at` timestamp

Example menu bar states:

```txt
CX 18%/12%
CX 36%/--
```

Example dropdown:

```txt
Codex PLUS

Week: 36% used, 64% left
Resets in 6d 14h

Secondary: unavailable
Current Codex usage API is only returning one live window.

Reset credits: 2
```

## Requirements

### macOS

- macOS 13 Ventura or newer

### Swift

- Swift 5.10 or newer

Check:

```bash
swift --version
```

### Apple Command Line Tools

Install:

```bash
xcode-select --install
```

### Codex CLI

Authenticate once:

```bash
codex login
```

Check:

```bash
ls ~/.codex/auth.json
```

## Install

### Option 1: Download a release

1. Open the [latest release](https://github.com/wei-b0/codexbar-lite/releases/latest)
2. Download the `CodexBarLite-macos-*.zip` asset
3. Unzip it
4. Move `CodexBarLite.app` into `/Applications`
5. Open it once

### Option 2: Build from source

Build:

```bash
swift build
```

Install the app bundle and LaunchAgent:

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/dev.vaibhav.codexbar.plist
rm ~/Library/LaunchAgents/dev.vaibhav.codexbar.plist
rm -rf /Applications/CodexBarLite.app
```

Optional cache cleanup:

```bash
rm -rf ~/Library/Application\ Support/CodexBarLite
```

## Repository

- Releases: https://github.com/wei-b0/codexbar-lite/releases
- Latest release: https://github.com/wei-b0/codexbar-lite/releases/latest

## Disclaimer

CodexBar Lite is an independent utility and is not affiliated with, endorsed by, or sponsored by OpenAI.
