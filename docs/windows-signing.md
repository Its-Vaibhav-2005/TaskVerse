# Trusted Windows releases

The original 1.1.0 installer and TrackVerse.exe were unsigned. Smart App Control
can block these files because Windows cannot verify the publisher. Users should
keep Smart App Control enabled. Replacing the installed application with a new,
trusted, signed release is the intended fix. Existing downloads remain unsigned.

## Obtain a verified signing identity

Use a publicly trusted code-signing provider that verifies your legal identity.
A self-signed certificate or a certificate users must manually trust does not
solve public distribution. The certificate's publisher may be your legal name;
do not substitute the product name unless that is the verified identity.

Choose one supported route:

- A CA-issued certificate on a hardware token or cloud KSP exposed through the
  Windows certificate store, with the provider's signing software installed.
- Microsoft Artifact Signing with an identity-validated **Public Trust** profile
  and an eligible account/region. Check eligibility before purchasing. Private
  Trust profiles are for managed environments, not public downloads.
- A PFX from a trusted provider where that provider permits exportable signing
  keys. Modern publicly trusted certificates commonly require protected hardware;
  PFX support is not a reason to use a self-signed certificate.

No certificate, private key, or signing account is supplied by this repository.
Never commit signing credentials. Keep the same verified publisher for updates.

### If you do not have a signing identity yet

TrackVerse's maintainer has selected **free services only**. The current route
is the [SignPath Foundation open-source program](https://signpath.org/apply).
On 2026-10-24 a support request was sent because the embedded application form
did not load. The form later loaded and the formal application was submitted.
Approval remains pending. No certificate has been issued and no SignPath signing
integration is configured.

The Foundation must confirm eligibility, build provenance, approval roles, and
coverage for upstream Electron binaries before integration. Do not put a
SignPath token into the certificate-store, PFX, or Azure variables below: these
are different signing routes. Keep the native-file audit mandatory. An approved
MSI signature alone does not resolve unsigned runtime files.

The following paid-provider information is reference material; obtaining or
buying one is not part of the current release plan.

For a GitHub-distributed MSI, obtain a publicly trusted code-signing certificate
or an eligible Artifact Signing Public Trust account. The provider must verify
your legal identity; this cannot be replaced by a product name or self-signed key.
Check that the provider accepts your country and individual/organization status
before buying anything, and follow its identity-validation process yourself.

As checked on 2026-10-24, Microsoft lists Artifact Signing Public Trust onboarding
for organizations in the USA, Canada, EU, and UK, and individuals in the USA and
Canada. An individual based in India should check a trusted CA route instead.
Ask the CA for Windows Authenticode code signing with a compatible hardware token
or cloud signing/KSP, then configure one of the build routes below. Do not send
identity documents, private keys, or certificate passwords in chat.

[Microsoft's current signing options and eligibility](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options)

Microsoft Store MSIX distribution is another route where the Store signs the
package after certification. It does not replace signing for the requested MSI;
Store submission of MSI/EXE installers still requires publisher Authenticode signing.

## Configure the build machine

Set the certificate common name exactly (case included):

```powershell
$env:TRACKVERSE_SIGNING_PUBLISHER = 'Your verified certificate common name'
```

For a Windows certificate store identity, set its SHA-1 thumbprint (this identifies
the certificate; file signing still uses SHA-256):

```powershell
$env:TRACKVERSE_CERTIFICATE_SHA1 = 'YOUR_40_CHARACTER_CERTIFICATE_THUMBPRINT'
```

Alternatively, for Artifact Signing:

```powershell
$env:AZURE_SIGNING_ENDPOINT = 'https://YOUR_REGION.codesigning.azure.net/'
$env:AZURE_SIGNING_ACCOUNT = 'your-signing-account'
$env:AZURE_SIGNING_PROFILE = 'your-public-trust-profile'
```

Configure Microsoft Entra authentication for the build machine, such as
`AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, and `AZURE_CLIENT_SECRET` through your secret
manager, and grant the signing principal the certificate profile signer role.
Use the provider's current setup instructions for modules and permissions.

For an eligible PFX, set `WIN_CSC_LINK` to its path and `WIN_CSC_KEY_PASSWORD`
through your secret manager instead. Do not configure multiple providers together.

## Build, verify, then distribute

On Windows, with Node, Flutter, and the signing provider configured:

```powershell
flutter build web --no-web-resources-cdn
npm run dist:win -- --config.directories.output=dist/signed-release
npm run audit:release -- dist/signed-release
```

The release build refuses absent signing configuration, requires signing, and
includes DLLs and native Node modules as signing targets. SHA-256 signatures use
RFC 3161 timestamps. The audit separately checks Windows Authenticode trust and
timestamps for every EXE, DLL, and native module plus the MSI, and requires the
expected publisher for TrackVerse.exe and the installer. It only produces a
checksum and successful audit after verification and package inspection pass.
Never publish a directory whose build or audit failed.

Test installation, launch, upgrade, and uninstall on a clean Windows 11 device
with Smart App Control enabled before publishing a new version. Signing verifies
publisher identity and integrity; it does not certify the app is vulnerability-free
or guarantee every Windows or organization policy will permit it. SmartScreen
reputation is a separate consideration. If a validly signed release is still
blocked, investigate the named binary and submit it to Microsoft for review.

Record the results using the [Windows acceptance checklist](windows-release-checklist.md).

Use `npm start` for source development after building the Flutter assets.
`pack:win` also requires signing by default; do not ship development builds.

## References

- [Microsoft: Sign your app for Smart App Control compliance](https://learn.microsoft.com/en-us/windows/apps/develop/smart-app-control/code-signing-for-smart-app-control)
- [Microsoft: Artifact Signing](https://learn.microsoft.com/en-us/azure/artifact-signing/overview)
- [electron-builder: Windows signing](https://www.electron.build/docs/features/code-signing/code-signing-win/)
