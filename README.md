# CodexBar Lite

A lightweight macOS menu bar application that displays your Codex usage limits directly in the top bar.

No browser extensions.

No Chrome profile access.

No Chrome cookie access.

No Keychain access.

No telemetry.

No analytics.

No API keys.

Just a tiny native macOS utility that reads your existing Codex session and displays your current usage quota.

---

## Why?

Most existing usage trackers rely on one or more of the following:

- Browser extensions
- Chrome profile access
- Chrome cookie access
- Keychain access
- API keys
- Third-party services
- Cloud dashboards

CodexBar Lite takes a different approach.

If you're already authenticated with:

```bash
codex login
```

then CodexBar Lite simply reads the same local session information that Codex already uses.

Nothing more.

---

## Requirements

CodexBar Lite is intended for developers already using Codex locally.

### macOS

Supported:

- macOS 13 Ventura or newer

### Swift

Swift 5.10 or newer is required.

Verify:

```bash
swift --version
```

### Xcode Command Line Tools

CodexBar Lite does not require the full Xcode IDE.

However, it does require Apple's Command Line Tools.

Install:

```bash
xcode-select --install
```

Verify:

```bash
swift --version
clang --version
```

### Codex CLI

CodexBar Lite relies on an existing Codex login session.

Authenticate once:

```bash
codex login
```

Verify:

```bash
ls ~/.codex/auth.json
```

### Permissions

CodexBar Lite does not require:

- Chrome access
- Chrome profile access
- Chrome cookie access
- Safari access
- Firefox access
- macOS Keychain access
- Accessibility permissions
- Screen recording permissions
- Full disk access
- Administrator privileges

---

## Features

- Native macOS menu bar application
- Extremely lightweight
- Uses minimal memory and CPU
- Displays 5-hour usage window
- Displays weekly usage window
- Automatic background refresh
- Automatic launch on login
- Cached fallback during temporary failures
- No external dependencies
- No browser integration

---

## Menu Bar

Example:

```txt
CX 18%/12%
```

Where:

- First value = current 5-hour usage
- Second value = current weekly usage

---

## Dropdown

```txt
Codex Plus

5h: 18% used
82% remaining

Week: 12% used
88% remaining

Reset credits: 1
```

## Security Model

CodexBar Lite authenticates using the same local session already used by the Codex CLI.

Credentials are read from:

```txt
~/.codex/auth.json
```

The application does not:

- Copy credentials
- Export credentials
- Store credentials elsewhere
- Access browser cookies
- Access browser profiles
- Access macOS Keychain

Authentication remains managed entirely by the official Codex CLI.

---

## Startup

CodexBar Lite automatically starts when you log into macOS.

No manual launch required.

- Does not access Chrome cookies
- Does not access Chrome profiles
- Does not access Safari data
- Does not access Firefox profiles
- Does not access macOS Keychain
- Does not require API keys
- Does not send analytics
- Does not collect usage data
- Does not transmit personal information to third parties

All processing happens locally on your machine.

---

## Resource Usage

CodexBar Lite is designed to be extremely lightweight.

Typical operation consists of:

- One small network request every minute
- A tiny cached JSON file
- A single menu bar item

No embedded browser.

No Electron.

No Chromium.

No background web server.

No heavyweight runtime.

---

## Installation

Build:

```bash
swift build
```

Release build:

```bash
swift build -c release
```

Install:

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

---

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/dev.vaibhav.codexbarlite.plist

rm ~/Library/LaunchAgents/dev.vaibhav.codexbarlite.plist

rm -rf /Applications/CodexBarLite.app
```

---

## Disclaimer

CodexBar Lite is an independent utility and is not affiliated with, endorsed by, or sponsored by OpenAI.
