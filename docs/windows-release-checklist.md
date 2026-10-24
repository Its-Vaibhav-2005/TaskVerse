# Windows release acceptance checklist

Version: **1.2.0**. All manual installation checks below are **pending**.
Use a disposable Windows 11 VM or test device with Smart App Control enabled;
do not change the maintainer's installed application or personal habit database.

## Signing gate

- [ ] Provider approves the free program, signing policy, and Electron coverage.
- [ ] Configure the approved signing integration without committing credentials.
- [ ] Build from the reviewed source commit; record its full Git SHA.
- [ ] Audit the final MSI and every bundled EXE, DLL, and native module. Require
      valid trust, timestamps, and the expected app and installer publisher.
- [ ] Generate the checksum only after the final signature is applied. Retain
      the exact audited files; any rebuild or file change requires a fresh audit.

Current local build routes support certificate store, PFX, and Azure signing.
SignPath integration remains pending its approved setup; do not claim it is ready.

## Clean installation

- [ ] Record Windows edition/build, Smart App Control state, artifact SHA-256,
      test date, and source commit. Use the final downloaded artifact so Windows
      download-origin handling is exercised.
- [ ] Install as a standard user with the default per-user scope. Confirm the
      publisher in the installer signature details. Keep Windows protections on.
- [ ] Launch using desktop and Start menu shortcuts; record any warning or block
      and the exact file named. Verify Settings displays 1.2.0.
- [ ] Create a habit with target 3, save partial progress, reach the target, and
      correct the count. Verify the daily completion follows the target.
- [ ] Set a near-term reminder, observe a Windows notification, edit its time
      and repeat interval, and verify notifications stop after target completion.
- [ ] Close the window with reminders enabled, verify tray reopen and background
      reminders, then Quit from the tray and verify the process exits.
- [ ] Restart the app and confirm counts and reminder settings persist. Check
      that a new local day resets progress without erasing the previous history.

Windows notifications must be enabled for the notification checks. Record the
notification and Focus/Do Not Disturb settings when assessing delivery.

## Upgrade from released MSI

Repeat independently for **1.0.0** and **1.1.0**, using snapshots or separate
test profiles. These older unsigned releases may be blocked by Smart App Control;
record that outcome and prepare legacy data in a separate disposable migration
test environment. Do not weaken protections on the acceptance device. An old
unsigned launch failure does not count as a new signed-release failure or as a
successful upgrade test.

- [ ] Prepare representative legacy habits, completion history, preferences,
      and multiple trackers; export a backup and record expected values.
- [ ] Quit the app and its tray process. Install 1.2.0 as the same Windows user
      and installation scope without manually uninstalling the old app.
- [ ] Confirm one installed TrackVerse entry, working shortcuts, version 1.2.0,
      and preserved trackers, preferences, and all prior completion dates.
- [ ] Confirm old habits default to target 1 and database migration preserves data.
- [ ] Verify export/import and optional Google backup retain targets, counts,
      and reminder settings; use a dedicated test Google account if testing sync.
- [ ] Re-run the same MSI for maintenance/repair and verify data remains intact.
- [ ] Attempt an older MSI and record the downgrade rejection.
- [ ] Uninstall and verify app processes and shortcuts are removed; confirm
      user data preservation before reinstalling and reopening the same profile.

## Publication gate

- [ ] Every required check has evidence; unresolved signing or Smart App Control
      failures block publication. Record skipped checks explicitly.
- [ ] Push reviewed source using Chrome and verify the release tag points to its
      full commit SHA. Publish only the audited MSI, checksum, and audit evidence.
- [ ] Test the downloaded release artifact and replace the unsigned download link
      only after acceptance. Keep the previous release available for reference.

Signing establishes publisher identity and integrity; acceptance testing records
observed behavior and cannot guarantee every Windows or organization policy.
