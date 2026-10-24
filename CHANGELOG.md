# Changelog

## 1.2.1 — 2026-10-24

### Fixed
- Completed daily targets show the normal check mark instead of a full n/n
  counter. Partial progress continues to show n/target; corrections reopen it.

### Website
- Redesigned the download page with a clearer product preview, concise feature
  sections, an interactive habit-counter example, and responsive layouts.
- Kept the tutorial, theme gallery, privacy information, and signing status accessible.

### Distribution
- Windows x64 MSI, compatible upgrade identity retained. Installer and app remain
  unsigned; Smart App Control may still block execution. SignPath approval,
  clean-machine installation and upgrade acceptance remain pending.

## 1.2.0 — 2026-10-24

A backward-compatible minor feature update, distributed unsigned at the
maintainer's request. Trusted signing and clean-machine upgrade acceptance remain
pending. Smart App Control may still block the application.

### Added
- Daily targets from 1–99, with partial progress counters and correction controls.
- Editable first reminder time and repeat interval for each habit.
- Windows notifications on scheduled days until the daily target is complete.
- A system tray menu so reminders can continue after closing the main window.
- Counter progress and reminder settings in SQLite and local/Google backups.

### Upgrade and distribution
- Version numbers follow Major.Minor.Micro: 1.2.0 adds compatible features to 1.1.0.
- Preserve the existing MSI UpgradeCode, application ID, per-user installation
  scope, installation name, and data directory for an in-place MSI upgrade.
- Existing habits default to one completion per day; existing history is retained.
- New release builds require signing; the audit verifies trusted signatures,
  timestamps, and the expected publisher before generating release evidence.
- The unsigned 1.2.0 MSI was submitted to Microsoft for review. A clean malware
  scan is not signing approval or confirmation of Smart App Control acceptance.

## 1.1.0 — 2026-10-22

A minor feature release with UI refinements and timer fixes. Existing habit data remains compatible; export a backup before upgrading.

### Added
- Pomodoro sessions linked to a habit, with adjustable work (1–180 minutes) and break (1–60 minutes) durations.
- Always-on-top focus widget, compact/resizable running view, pause/resume, and smooth circular wave animation.
- SQLite focus-time history, backup recovery, and a monthly time-invested breakdown in Insights. Breaks do not count.
- All 42 requested theme names plus TrackVerse, each with paired light/dark palettes, searchable previews, and offline fonts.
- System appearance for new profiles, with explicit light/dark overrides and persisted theme choices.

### Improved and fixed
- Organized Settings: appearance, typography with live preview, portable backups, daily rules, and expandable tracker management.
- Higher-contrast light-mode text, clearer chart labels, and neutral charcoal/white app branding.
- Timer z-order is reasserted without taking keyboard focus from the active app.
- Fixed setup-window dimensions; removed widget scrollbars and bottom instructional copy.
- Partial work is saved on pause/reset. Interrupted sessions recover paused without counting application downtime.
- A running focus session stays attached to its original tracker when switching workspaces.

### Distribution
- Windows x64 MSI, per-user installation, bundled assets, clean first run, and SHA-256 checksum.
- Personal SQLite databases, exported backups, test/demo fixtures, and Google token vaults are excluded from the installer.
- The installed-app Google OAuth client configuration is public client metadata; personal tokens remain encrypted on the user's Windows device.
- This build is unsigned. WiX ICE validation is unavailable under the build host policy. No claim of code-signing or external security certification is made.
- Linux and Android are not released.

## 1.0.0 — 2026-10-22

Initial Windows release: SQLite habit grid, independent monthly plans, automatic progress dashboards, local backups, and optional private Google Sheets sync.
