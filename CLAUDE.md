# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is AhPushIt?

A native macOS menu bar app that polls the macOS Notification Center SQLite database for new notifications and forwards them to configurable services (ntfy, Pushover, Slack, Discord, Telegram, Mattermost, n8n, JSON HTTP webhooks, CSV file logging).

## Build & run commands

```
xcodebuild -project AhPushIt/AhPushIt.xcodeproj -scheme AhPushIt -configuration Release build CONFIGURATION_BUILD_DIR=build
open build/AhPushIt.app
```

There is no test suite yet. When adding tests, use Xcode's XCTest framework.

## Key runtime requirements

- **macOS only** — reads `~/Library/Group Containers/group.com.apple.usernoted/db2/db`
- The app needs **Full Disk Access** to read the notification database
- Uses `mdfind` (Spotlight) at runtime to resolve bundle identifiers to app display names

## Architecture notes

- Swift macOS app using SwiftUI and the `@Observable` macro
- Xcode project lives in `AhPushIt/AhPushIt.xcodeproj`
- Source is under `AhPushIt/AhPushIt/` organized into: Models, Services, Settings, Polling, and supporting files
- Uses `modernc.org/sqlite`-style pure-Swift SQLite access (via a `SQLiteDatabase` wrapper)
- The notification DB is opened **read-only**
- The notification DB uses Core Data timestamps (seconds since Jan 1, 2001 UTC)
- Notification records contain Apple plist blobs with keys: `app` (bundle ID), `date`, `req` (with sub-keys `titl`, `subt`, `body`)
- Polling tracks both `last_id` and `last_date` to handle dismissed/deleted notifications correctly
- Services are configured via `ServiceConfiguration` (persisted in UserDefaults) and instantiated via `ServiceConfiguration.createService()`
- Template engine resolves `{{placeholders}}` in title/message/tags templates

## CI/CD

- **CI** (`.github/workflows/ci.yml`) — Runs on push/PR to `main`. Builds with signing disabled on `macos-15`.
- **Release** (`.github/workflows/release.yml`) — Triggered by `v*` tags. Archives with Developer ID signing, notarizes, creates DMG, publishes GitHub Release, and updates the Homebrew tap (`jordiboehme/homebrew-tap`).
- To release: `git tag v1.x.x && git push origin v1.x.x`
