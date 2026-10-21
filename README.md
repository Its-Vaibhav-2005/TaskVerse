# TrackVerse

TrackVerse is a local-first habit tracker. This is a Windows development preview; installer packaging is on hold until the user reviews the UI and features.

## Open the preview

Double-click `Start TrackVerse.cmd`. The downloaded desktop runtime and built UI assets are ready in this workspace. Development data is saved in `.local-data/trackverse.sqlite3`. Six sample habits are loaded for review.

## Using TrackVerse

1. Click **New habit**, enter a name, choose a category, repeat days, color and icon, then click **Create habit**.
2. Click today's scheduled cell to complete it; click again today to undo. Progress updates automatically. Past dates are locked, but saved completions remain visible. Future dates and days before habit creation are disabled.
3. Click **+** at the end of the month tabs. The dialog defaults to the next month. Choose a month and year and click **Add month**. Tabs use labels such as `Oct 2026`. Existing habits carry forward; completion records stay with their dates.
4. Use the **...** menu beside a habit to edit or delete it. Deletion requires confirmation.
5. Search by habit name or filter by category above the grid.
6. Scroll below the grid for weekly completion rings, the consistency curve and today's progress. **Insights** shows the progress dashboards without the grid.
7. Use **Settings** to export or restore JSON backups. Restoring replaces current data after confirmation.
8. Use the sun/moon button in the top bar or **Settings → Appearance** to switch between light and dark mode. The preference is saved locally.

The app reads the device's local date and time. It updates at midnight, on resume, and after device clock changes. Windows also rechecks the system date immediately before each SQLite check-in, so yesterday cannot be edited through a screen left open overnight. At month boundaries a new current-month tab is added automatically if needed.

## Storage and calculations

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

Node 24+ and Flutter stable are required for development. Flutter is installed for this session at `C:\Users\Hey.Vaibhav\.codex\tools\flutter`.

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

## Packaging: deferred

No installer has been generated. After user review and an explicit request to package, `npm run dist:win` can create a per-user Windows x64 NSIS installer. Code signing is not configured. Preview data is excluded from packages; export and restore a backup to transfer it.

Linux and Android platform scaffolding is present for future work; those targets have not been built or verified.
