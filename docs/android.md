# TrackVerse for Android

The Android app runs Flutter natively. Android opens the mobile interface; the
Windows Electron interface remains the desktop entry point. Local mobile data is
stored in `trackverse-mobile.sqlite3`, with one transactional snapshot per tracker.
The Android application ID is `app.trackverse.trackverse` and the current minimum
Android version is API 24 (Android 7).

## Build environment

- Flutter 3.47.7 / Dart 3.13.5 was used during development.
- Android SDK platform 36, Build-Tools 36.0.0, Platform-Tools and Command-line Tools.
  Plugin builds also install platform 35 automatically.
- NDK 28.2.13676358, matching the installed Flutter SDK, and CMake 3.22.1.
- AGP 9.1.0, Kotlin 2.4.0 and the checked-in Gradle 9.3.1 wrapper.
- Java 25 is installed on the development PC. Java source/bytecode compatibility
  remains 17. Flutter is configured to use Android Studio's bundled JBR 25.
- An Android phone or emulator for acceptance testing.

Run `flutter doctor -v`, then review any outstanding SDK licenses with
`flutter doctor --android-licenses`. Do not commit local SDK paths or keystores.

On this Windows desktop host, Java's Unix-domain wakeup socket failed when the
SDK tools ran inside the desktop agent. For those child processes only, the build
used `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=E:/trackverse-unavailable-unix-sockets`.
That intentionally nonexistent directory makes Java use its normal TCP fallback.
No firewall, security, or global Java settings were changed. Omit the workaround
in a normal terminal unless the same error occurs. Gradle downloads were cached
in the ignored `.gradle-cache/` on E: to conserve C: space.

The installed NDK resides at `D:/AndroidSdkComponents/ndk/28.2.13676358`.
The original SDK's `ndk/28.2.13676358` directory is a Windows junction to it,
which recovered about 2 GB on C: while preserving Android Studio's SDK path.
Keep that D: directory while using this toolchain.

Kotlin incremental compilation is disabled in `android/gradle.properties` because
its relocatable caches fail when plugin sources are on C: and this checkout is on
E:. Kotlin runs in the Gradle process. Normal Gradle up-to-date task checks still
apply; SDK and Maven downloads remain cached.

## Local test APK

From the repository directory:

```powershell
flutter pub get
flutter analyze
flutter test
./tool/build-android.ps1
```

If Flutter is not on PATH, pass `-FlutterSdk` with the SDK directory (not `bin`).
The script copies the debug APK and its SHA-256 to `release-android/`.
A debug APK is for installation and testing, not Play submission.

To run with clearly labeled sample data in a separate local database:

```powershell
./tool/build-android.ps1 -Preview
flutter run -d emulator-5554 --dart-define=TRACKVERSE_PREVIEW=true
```

Preview and normal builds have the same package ID; installing one updates the
other. Their databases are separate. The normal build starts empty. Preview
mode skips automatic account restoration and its sample habits are not uploaded
unless the user explicitly connects Google and backs up that preview tracker.

## Enable Google sign-in

The Android debug client and Web client were registered in project
`trackverse-512318` on October 28, 2026. Their public identifiers and debug
fingerprint are saved locally in ignored `.config/android-oauth.json`.
`tool/build-android.ps1` reads its `webClientId` automatically, so future builds
retain Google sign-in without repeating command-line flags. The file contains no
client secret or account tokens. A fresh clone without this configuration keeps
Google connection disabled until its owner supplies a Web client ID.
Google Cloud's Audience page was checked on October 28, 2026: the project is
**External** and **In production**. The Android implementation does not restrict
email domains or maintain a test-user allowlist. Google account eligibility,
organization restrictions, and OAuth policy limits still apply.
Live account and cross-device acceptance must still be completed before claiming
Google sync has been verified. To register another signing configuration or set
up a fresh project, follow these steps:

1. Open the **same Google Cloud project** that owns the Windows installed-app
   OAuth client. Keep the existing Windows client.
2. Ensure Google Drive API and Google Sheets API are enabled.
3. Configure the OAuth consent screen and test users as appropriate for the
   project's publishing status.
4. Create an **Android** OAuth client with package `app.trackverse.trackverse`
   and the signing certificate SHA-1. For the debug build, inspect it with:

   ```powershell
   keytool -list -v -keystore "$env:USERPROFILE/.android/debug.keystore" -alias androiddebugkey -storepass android -keypass android
   ```

5. Create a **Web application** OAuth client in that same project. Only its
   public client ID is passed to Android. Do not put its client secret in the app.
   No backend or Firebase project is required for this implementation.
6. Rebuild:

   ```powershell
   ./tool/build-android.ps1 -GoogleWebClientId 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com'
   ```

7. On the device, open **Sync → Connect Google** and complete Google's account
   and authorization screens yourself. The app requests `drive.file`, matching
   the Windows app's per-file access. Tokens are supplied by Google Sign-In;
   the app does not persist access or refresh tokens in its database or preferences.

Use the same Google account and Cloud project on both platforms. The discovery
query looks for TrackVerse's private `appProperties`; a different OAuth project
will not discover the original app's private file metadata. No wider Drive scope
is requested. See Google's [custom file properties guide](https://developers.google.com/workspace/drive/api/guides/properties),
[Android sign-in codelab](https://codelabs.developers.google.com/sign-in-with-google-android),
and the Flutter [Android Google Sign-In configuration](https://pub.dev/packages/google_sign_in_android).

## Sync behavior

- On the source device, back up a tracker. On the second device, connect Google,
  choose **Find my trackers**, then open the existing tracker. Creating a separate
  backup from each device creates two independent trackers.
- Android reads and appends the same `_TrackVerse History` journal as Windows:
  gzip/base64 JSON, SHA-256, UUID snapshot IDs, chunked rows and parent snapshot IDs.
- Habits, daily counts, checks, schedules, month membership and saved focus sessions
  transfer together. Appearance and a running focus timer stay device-local.
- Changes save to SQLite before network requests. Sync is attempted two seconds
  after edits, every 60 seconds while the app is open, and on returning to the app.
  Background/terminated-app sync is not implemented.
- If both devices edit before syncing, the app asks which version to continue.
  It does not merge individual habit fields automatically. Previous Google
  snapshots remain in history. Before applying a Google replacement, Android keeps
  its old snapshot in **Appearance and backups → Local recovery history**.
- An upload whose acknowledgement was lost is checked by snapshot ID on retry,
  preventing duplicate history writes. Corrupt or incomplete history is rejected.
- Google Sheets is the backup transport. Editing worksheet cells directly does not
  edit app habits. The Windows app maintains its existing human-readable month
  sheets; Android updates the versioned history, which Windows reads on its next sync.

## Interface and current scope

The app has Today cards with daily target controls, category filters, a read-only
progress calendar, a habit-linked focus timer, and a dedicated Sync screen.
The Today headline includes a faint consistency curve based on the last 21
calendar days. It uses scheduled daily completion rates, with gaps for days
without scheduled habits, and follows the selected theme color.
Habit creation supports schedule, category, color, icon and target. JSON imports
open as a separate local tracker. JSON exports use Android's share sheet.
Light/dark/system appearance and the existing 43 theme palettes are supported.

Focus timer state is saved per tracker and survives tab changes and process
restart. The running clock counts elapsed wall time until its selected limit;
pause excludes subsequent time. Finishing records the session with a stable ID
so recovery does not credit it twice. Android notifications, reminder scheduling,
and desktop-style floating overlays are not implemented in this version. Existing
reminder data from Windows is retained in backups but not scheduled on Android.

## Release signing

Create a private upload keystore and save its values in ignored
`android/key.properties`:

```properties
storeFile=C:/private/trackverse-upload.jks
storePassword=YOUR_LOCAL_PASSWORD
keyAlias=upload
keyPassword=YOUR_LOCAL_PASSWORD
```

Then run `./tool/build-android.ps1 -Release -GoogleWebClientId 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com'`.
The output is an AAB. Release tasks fail clearly if signing is missing; they never
fall back to the debug key. Register the release certificate SHA-1 as another
Android OAuth client. For Play App Signing, also register the Play app-signing
certificate SHA-1 from Play Console. Store submission, release credentials, live
Google consent and Play policy acceptance are separate owner steps.

## Acceptance checklist

1. Install the normal debug APK on a phone. Create, edit, complete and partially
   complete habits; restart and verify data survives.
2. Test portrait, landscape, large system text, dark mode and the Android back key.
3. Start/pause a focus timer, switch tabs, restart, finish and verify focus history.
4. Export JSON and import it on the other platform. Verify all habit data.
5. Complete OAuth setup. Back up on Windows, find the tracker on Android, edit on
   Android and verify Windows pulls the change. Repeat in the reverse direction.
6. Make offline edits on both devices. Verify the conflict prompt, both resolution
   choices, recovery copies, retry behavior and account mismatch handling.
7. Before public release, complete physical-device and release-signed acceptance,
   including the sign-in flow under the actual Play signing certificate.

## Version 2.0.0 validation

Google account sign-in was confirmed working by the owner on October 28, 2026.
Settings → Create tracker creates an empty local tracker without replacing existing data.
Switch trackers in Settings or Sync. To share one, connect Google and choose
Sync → Back up this tracker, then find it on the other platform with the same account.
Auto-sync retries dirty inactive trackers and checks the active tracker while the app is open.
Concurrent offline edits require an explicit version choice and preserve backup history.

The automated cross-platform integration test runs both actual sync engines over a
shared in-memory journal transport, including Android creation, a Windows edit and
an Android check-in returned to Windows. This is distinct from a live, two-installed-device
Google API acceptance test, which remains pending. The distributed APK uses the
registered debug certificate; it is a test build, not a Play Store production release.
