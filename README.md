# TrackVerse

TrackVerse is a local-first Windows habit tracker with an MSI installer and optional Google Sheets backup.

**[Download Windows x64 MSI](https://github.com/Its-Vaibhav-2005/TaskVerse/releases/latest)** · **[Website](https://its-vaibhav-2005.github.io/TaskVerse/)** · **[Privacy policy](https://its-vaibhav-2005.github.io/TaskVerse/privacy.html)**

## Watch the quick-start guide

[![Watch the TrackVerse walkthrough](website/media/walkthrough-preview.gif)](https://its-vaibhav-2005.github.io/TaskVerse/#walkthrough)

**[Watch the full video with audio](https://its-vaibhav-2005.github.io/TaskVerse/#walkthrough)** · [Download MP4](https://github.com/Its-Vaibhav-2005/TaskVerse/releases/download/v1.0.0/TrackVerse-Quick-Start.mp4)

The original 3-minute, 1080p illustrated guide covers the core workflow with English narration, captions, and chapter markers: setup, new habits, daily check-ins, monthly plans, dashboards, appearance, backups, and separate trackers. Only demonstration data appears. The animated preview above is silent; open the full video for narration.

## Install on Windows

Download the MSI and its SHA-256 checksum from [Releases](https://github.com/Its-Vaibhav-2005/TaskVerse/releases/latest), then run the installer. Windows x64 is the currently packaged target. The installer is unsigned, so Windows may identify an unknown publisher. New users can choose local-only setup or optional Google sign-in.

## New in 1.1.0

- Habit-linked Pomodoro with configurable work/break durations, pause/resume, and a floating always-on-top mini window.
- Smooth animated circular wave timer; actual work time is saved to SQLite, while breaks are excluded.
- Focus-time donut chart in Insights, colored by habit; sessions are included in cloud and local backups.
- 43 paired theme presets, searchable previews, automatic System appearance, clearer light-mode text, and neutral branding.
- Redesigned Settings with grouped appearance, typography, backup controls, and expandable tracker management.
- Fixes for timer z-order, fixed setup dimensions, unwanted scrollbars, larger text, and interrupted-session recovery.

[Full changelog](CHANGELOG.md) · [Explore all themes](https://its-vaibhav-2005.github.io/TaskVerse/themes.html)

## Open the preview

Double-click `Start TrackVerse.cmd` for development. Development data is saved in `.local-data/trackverse.sqlite3`. New installations start empty, with Google sign-in or local-only setup. Sample generators and demo controls are removed.

## Using TrackVerse

1. Click **New habit**, enter a name, choose a category, repeat days, color and icon, then click **Create habit**.
2. Click today's scheduled cell to complete it; click again today to undo. Progress updates automatically. Past dates are locked, but saved completions remain visible. Future dates and days before habit creation are disabled.
3. Click **+** at the end of the month tabs, choose a month/year, then choose **Use same habits** from the nearest earlier tab or **Start fresh**. Month assignments are saved independently. When creating a habit, choose **This month only** or **All months** (all existing month tabs).
4. Use the **...** menu beside a habit to edit or delete it. Deletion requires confirmation.
5. Search by habit name or filter by category above the grid.
6. A compact motivation card and 2×2 KPI grid appear above the month controls. Search, category filter, and **New habit** share one toolbar row. The consistency graph and Today card remain at the bottom. A subtle copy of the same consistency curve appears behind the fixed-height navbar.
7. Use **Settings** to export or restore JSON backups. Restoring replaces current data after confirmation.
8. Use the sun/moon button in the top bar or **Settings → Appearance** to switch between light and dark mode. The preference is saved locally.
9. In **Settings → Appearance → Typography**, increase or decrease all text by one point, or choose **Inter**, **Lora**, or **JetBrains Mono**. Fonts and their open-source licenses are bundled for offline use. Reset restores Inter at the default size.
10. Future month tabs have a close button with confirmation. The current month and past months cannot be deleted. SQLite enforces the date rule too. Cloud sync mirrors month assignments and removes managed future Google tabs when they are deleted in the app.

Choose from 26 named habit icons, 16 categories, and 16 colors. Existing habits keep their original icon/color indexes and completion history after the database migration.

Previously generated local samples are retired on startup. Their separate SQLite file is archived outside the installation bundle. Real local habits and connected Google trackers are preserved.

The app reads the device's local date and time. It updates at midnight, on resume, and after device clock changes. Windows also rechecks the system date immediately before each SQLite check-in, so yesterday cannot be edited through a screen left open overnight. At month boundaries a new current-month tab is added automatically if needed.

## Storage and calculations

The sidebar shows your Google name and profile photo when available. **Online / Offline** reflects an internet reachability check, independently of Google sign-in, and updates within about 15 seconds.

In **Settings → Trackers & cloud backup**, **Delete tracker & sheet** asks for confirmation, moves the spreadsheet to Drive's Trash, and removes the tracker from the app. Its SQLite database is archived in `.local-data/deleted-trackers/`. Restore the spreadsheet in Drive, then use **Find my trackers** to reconnect it. The local-only tracker is retained.

Month tabs for Google trackers are mirrored to the matching spreadsheet as `Oct 2026`, with scheduled checkboxes, completion formulas, and daily progress charts. These views are generated from the app; editing them does not import check-ins into TrackVerse. Offline additions wait for the next successful sync. The versioned history remains the source for backup recovery.

Google development setup uses your own desktop OAuth client in the ignored `.config/google-client.json`, with Sheets and Drive APIs enabled and scopes `openid`, `email`, `profile`, and `drive.file`. Tokens are encrypted on Windows. Never upload OAuth configurations or local user data to GitHub.

The Windows preview runs the shared Flutter UI inside an Electron desktop shell. It uses Node's native SQLite engine and a normalized database stored on disk, through a restricted IPC bridge. The renderer has no Node access. No account, network service or internet connection is required; rendering assets are bundled locally.

Monthly completion is completed scheduled check-ins divided by scheduled opportunities through today. Future dates and dates before creation are excluded. Streaks count consecutive scheduled days; missing today does not break a streak until the day finishes. Weekly groups are days 1-7, 8-14 and so on. The Today card always represents the actual current date.

Habits, check-ins and month tabs persist across restarts. The Windows backup export includes all three, and restore is transactional. Development data is separate from the packaged application's future user-data folder.

## Source and development

- `lib/main.dart`: screens, dialogs and actions.
- `lib/tracker_grid.dart`: spreadsheet grid with pinned habit names and colored week groups.
- `lib/model.dart`: dates, schedules, completion and streak calculations.
- `desktop/database.cjs`: native SQLite persistence and transactions.
- `desktop/main.cjs`: Windows shell, file dialogs and restricted IPC.
- `lib/storage_native.dart`: SQLite implementation for future direct Flutter builds.

Node 24+ and Flutter stable are required for development.

```powershell
npm ci
flutter pub get
flutter build web --no-web-resources-cdn
.\Start-TrackVerse.ps1
```

Rebuild UI assets and reload the development window after Dart edits. Restart the desktop app after desktop JavaScript edits.

```powershell
flutter analyze
flutter test
npm run test:desktop
```

Tests cover schedules, streaks, leap days, narrow layouts, check-in actions, month selection, SQLite reopening and failed-write/restore rollback.

## Windows MSI packaging

Build the Flutter UI, then run `npm run dist:win -- --config.directories.output=dist/release-1.1.0` to produce `dist/release-1.1.0/TrackVerse-Setup-1.1.0-x64.msi`. This is an assisted, per-user Windows x64 MSI with desktop and Start menu shortcuts. The build does not publish to GitHub. Code signing is not configured, so Windows may show an unknown publisher.

The release preflight permits only a Desktop OAuth client configuration from ignored `.config/google-client.json`. Google treats installed-app clients as public clients: the distributed client configuration cannot be kept confidential inside an MSI. Authentication uses PKCE, state validation, and a loopback callback. Each user grants their own access. Refresh/access tokens and cached account information stay encrypted on that user's Windows device and are never transferred through the installer. Service-account keys are not accepted for release.

The package allowlist contains application code, production dependencies, built UI assets, the app icon, and the desktop OAuth configuration. Development databases, exported backups, `.local-data`, encrypted credential vaults, tests, and sample fixtures are excluded. Use the application's export/restore to transfer your own habits; never copy a Google token vault between users or machines.

WiX ICE validation is disabled in this environment because the host's Windows Installer policy blocks it; system policy and elevation settings are unchanged. `node tool/audit-release.cjs` inspects the application archive and creates a SHA-256 checksum and release audit. Test installation/uninstallation on a clean Windows machine before wider distribution. Installer compression uses standard MSZIP.

Linux and Android platform scaffolding is present for future work; those targets have not been built or verified.
