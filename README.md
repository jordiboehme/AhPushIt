# Ah, push it

A macOS menu bar app that forwards notifications from the macOS Notification Center to a wide range of services — ntfy, Pushover, Slack, Discord, Telegram, Mattermost, iMessage, n8n webhooks, generic JSON HTTP endpoints, and CSV file logging. Runs silently in your menubar, polling the system notification database and pushing new notifications to configurable endpoints with template support.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/V7V31T6CL9)

## Features

- **Menubar App** — Lives in your menubar with no Dock icon, shows forwarding status at a glance
- **Real-Time Polling** — Configurable polling interval (default 5 seconds) for near-instant forwarding
- **10 Notification Services** — Forward to ntfy, Pushover, Slack, Discord, Telegram, Mattermost, iMessage, n8n, JSON HTTP, or CSV files
- **Multiple Endpoints** — Configure as many service instances as you need, each with independent settings and enable/disable toggles
- **Template Engine** — Customize notification titles, messages, and tags using `{{placeholders}}` like `{{appName}}`, `{{title}}`, `{{body}}`
- **App Filters** — Include or exclude specific apps by bundle identifier, with auto-discovery from the notification database
- **Time Scheduling** — Define active time windows with weekday selection to control when forwarding is active
- **Settings UI** — Native SwiftUI settings window with tabs for Schedule, Filters, and Services
- **Test Notifications** — Send a test notification through all enabled services or test a single service before saving

## Supported Services

| Service | Description |
|---------|-------------|
| **[ntfy](https://ntfy.sh)** | Self-hostable push notification server. Supports custom topics, auth tokens, tags, and priority levels (1–5). |
| **[Pushover](https://pushover.net)** | Push notifications to iOS, Android, and desktop. Supports user key, app token, device targeting, sounds, and priority. |
| **[Slack](https://slack.com)** | Post to Slack channels via incoming webhooks. |
| **[Discord](https://discord.com)** | Post to Discord channels via webhooks. |
| **[Telegram](https://telegram.org)** | Send messages via Telegram Bot API with bot token and chat ID. |
| **[Mattermost](https://mattermost.com)** | Post to Mattermost channels via incoming webhooks. |
| **iMessage** | Send notifications as iMessages via AppleScript. Requires a phone number or email. Messages.app notifications are automatically suppressed to prevent loops. |
| **[n8n](https://n8n.io)** | Trigger n8n workflow automations via webhook URL. |
| **JSON HTTP** | Send to any HTTP endpoint as a JSON POST/PUT with custom headers, auth token, and body template. |
| **CSV File** | Log notifications to local CSV files with configurable columns, directory, and filename template. |

## Installation

### Homebrew (recommended)

```bash
brew tap jordiboehme/tap
brew install --cask ahpushit
```

### Download

Grab the latest DMG from [GitHub Releases](https://github.com/jordiboehme/AhPushIt/releases), open it, and drag AhPushIt to Applications.

### Build from Source

```bash
git clone https://github.com/jordiboehme/ahpushit.git
cd ahpushit
xcodebuild -project AhPushIt/AhPushIt.xcodeproj -scheme AhPushIt -configuration Release build CONFIGURATION_BUILD_DIR=build
```

Then move `build/AhPushIt.app` to `/Applications` and launch it.

## Requirements

- **macOS 14 Sonoma** or later
- **Full Disk Access** permission (required to read the macOS Notification Center database)

### Grant Full Disk Access

1. Open **System Settings > Privacy & Security > Full Disk Access**
2. Click the **+** button and add `AhPushIt.app`
3. Restart AhPushIt if it was already running

> **Note**: Without Full Disk Access, the app cannot read the Notification Center database and will show an error in the menubar.

## Privacy Notice

AhPushIt forwards macOS notifications — including their titles, subtitles, and body text — to external services. Notifications may contain sensitive information such as two-factor authentication codes, private messages, banking alerts, or personal details. Be mindful of which apps you allow through the filter settings and which services you forward to, especially when using third-party or cloud-hosted endpoints.

## Usage

### Menubar

Once running, AhPushIt appears as a bell icon in your menubar:

- **Bell icon** — Active and forwarding
- **Slashed bell** — Paused
- Click the icon to see forwarded count, pause/resume, access settings, send a test notification, or quit

### Settings

Open Settings from the menubar menu or press `Cmd+,`:

**Schedule** — Toggle time-based scheduling. Add windows with start/end times and active weekdays. Outside these windows, notifications are not forwarded.

**Filters** — Choose between exclude or include mode. Click "Scan DB" to auto-discover apps from your notification history. Toggle individual apps on/off. Add apps manually by bundle identifier.

**Services** — Add and configure notification services. Each service has its own connection settings plus shared template fields:

| Field | Description |
|-------|-------------|
| Name | Display name for this service instance |
| Title Template | Template for notification title (default: `{{title}}`) |
| Message Template | Template for notification body (default: `{{message}}`) |

Service-specific parameters (server URLs, tokens, topics, etc.) are shown in the editor for each service type.

### Template Placeholders

| Placeholder | Description |
|-------------|-------------|
| `{{app}}` | Bundle identifier (e.g. `com.apple.Safari`) |
| `{{appName}}` | Resolved display name (e.g. `Safari`) |
| `{{title}}` | Notification title |
| `{{subtitle}}` | Notification subtitle |
| `{{body}}` | Notification body text |
| `{{message}}` | Composed message (subtitle + body, or just body) |
| `{{date}}` | Formatted date/time |
| `{{fileDate}}` | Date for filenames (`yyyy-MM-dd`) |
| `{{timestamp}}` | Unix timestamp |
| `{{isoDate}}` | ISO 8601 date |

## How It Works

AhPushIt reads the macOS Notification Center SQLite database located at:

```
~/Library/Group Containers/group.com.apple.usernoted/db2/db
```

It polls for new records, parses the Apple plist blobs to extract app name, title, subtitle, and body, resolves bundle identifiers to display names using Spotlight (`mdfind`), then forwards matching notifications to your configured services.

## Project Structure

```
ahpushit/
├── AhPushIt/
│   ├── AhPushIt.xcodeproj/
│   ├── App/              # App entry point, menubar UI, app state
│   ├── Polling/          # SQLite access, plist parsing, polling engine
│   ├── Services/         # Service implementations, template engine, protocol
│   ├── Settings/         # SwiftUI settings tabs (Schedule, Filters, Services)
│   ├── Models/           # Data models, settings persistence
│   └── Resources/        # Assets, entitlements
└── build/                # Built .app output
```

## Recommended Companion App

AhPushIt works best together with [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704?mt=12). Amphetamine prevents your Mac from sleeping, ensuring AhPushIt can continuously poll for notifications and forward them without interruption.

## Troubleshooting

### App shows "Full Disk Access Required"

The app needs permission to read the Notification Center database. Go to **System Settings > Privacy & Security > Full Disk Access** and add AhPushIt.

### Notifications not forwarding

1. Check that the app is not paused (menubar icon should be a bell, not a slashed bell)
2. Verify your service configuration in Settings > Services
3. Use the **Test** button on the Services page or inside a service editor to verify connectivity
4. Check that the app is not filtered out in Settings > Filters
5. If using time scheduling, verify the current time falls within an active window

### App names showing as bundle identifiers

Display name resolution uses `mdfind` (Spotlight). If an app isn't indexed by Spotlight, its bundle identifier is used as a fallback.

## Releasing

Tag a version and push to trigger the release pipeline (build, sign, notarize, DMG, GitHub Release, Homebrew tap update):

```bash
git tag v1.0.0
git push origin v1.0.0
```

### GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `DEVELOPER_ID_CERTIFICATE_BASE64` | Base64-encoded Developer ID Application `.p12` certificate |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password for the `.p12` file |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APPLE_ID` | Apple Developer account email |
| `APPLE_ID_PASSWORD` | App-specific password from appleid.apple.com |
| `TAP_GITHUB_TOKEN` | Fine-grained PAT with Contents write on `homebrew-tap` repo |

## License

MIT License — See [LICENSE](LICENSE) for details.
