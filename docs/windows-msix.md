# Microsoft Store MSIX build

The Windows MSIX uses TrackVerse's existing Electron desktop application and
bundled Flutter web UI. The installed electron-builder version calls this target
`appx`; Windows SDK MakeAppx writes the final `.msix` container directly. No MSI
is renamed or wrapped, and the default signed MSI build policy is unchanged.

Save the exact three public identity values from Partner Center → your MSIX/PWA
product → Product management → Product identity in ignored
`.config/msix-identity.json`:

```json
{
  "identityName": "YOUR_PACKAGE_IDENTITY_NAME",
  "publisher": "CN=YOUR_PARTNER_CENTER_PUBLISHER_GUID",
  "publisherDisplayName": "YOUR_PUBLISHER_DISPLAY_NAME"
}
```

Use your real Store identity, not the product name as a certificate subject.

```powershell
# If Flutter is elsewhere, set its complete executable path first.
$env:FLUTTER_BIN = 'C:\path\to\flutter\bin\flutter.bat'
npm run dist:win:msix
```

The recipe runs all desktop/release tests, Flutter analysis, all Flutter tests,
and a fresh web build before packaging. It derives Store tile PNGs from the
existing logo and uses Microsoft's checksum-pinned `Microsoft.Windows.SDK.BuildTools`
NuGet package (10.0.26100.7463). It does not disable
MakeAppx validation. The audit unpacks the MSIX, verifies the manifest identity,
capabilities, application version, complete payload hashes, logo sizes, and
exclusion of personal databases, tokens, signing keys and development files.
Public installed-app OAuth metadata remains bundled for optional Google sign-in.

Final outputs are in **`release-2.0.0/`**: MSIX, SHA-256 checksum, manifest,
verification report and README. Build caches and inspection files stay in ignored
`.local-data/msix-2.0.0/`. MSIX output is ignored by Git; nothing is published.

## Signing and acceptance

The corrected app still displays **2.0.0**, matching the Android and GitHub
release. Its Store package version is **2.0.1.0**: the previous 2.0.0.0 package
was already published, so the replacement must have a higher package version.
The build generates its manifest from the installed builder's template with
this explicit servicing version; the package audit verifies it.

This is an unsigned input package for the reserved Microsoft Store product.
Microsoft handles Store signing after certification. It is not a trusted
direct-download installer. No self-signed certificate or trust-store modification
is required to produce it. This build process does not install the package,
change Windows protections, or submit it to Microsoft.

The manifest grants `runFullTrust` for the Electron desktop process and
`internetClient` for optional Google services. It declares no automatic startup,
unrelated protocols, broad filesystem capabilities or services. The packaged
process retains Windows' package notification identity instead of overwriting it
with the MSI shortcut identity.

Store package acceptance, Windows App Certification Kit, and installed-runtime
checks are separate from unit tests and SDK container validation. Verify launch,
tray/background reminders, notification delivery, Google OAuth loopback callback,
backup/restore, and restart behavior after a Store-signed test installation.

MSIX and MSI have different deployment identities. This package does not silently
replace the old MSI or claim an automatic data migration. Export a backup from
the old app, import it in the Store app and verify all data before removing the
old installation. Do not change the package identity between Store updates.

References: [Microsoft package identity](https://learn.microsoft.com/en-us/windows/apps/publish/view-app-identity-details),
[Store signing](https://learn.microsoft.com/en-us/windows/apps/publish/get-started),
[electron-builder AppX configuration](https://www.electron.build/appx/).
