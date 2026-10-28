param(
  [string]$FlutterSdk,
  [string]$GoogleWebClientId,
  [switch]$Preview,
  [switch]$Release
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $taskRoot
$taskFlutter = if ($FlutterSdk) { Join-Path $FlutterSdk 'bin/flutter.bat' } else { (Get-Command flutter -ErrorAction Stop).Source }
$taskOAuthConfig = Join-Path $taskRoot '.config/android-oauth.json'
if (!$GoogleWebClientId -and (Test-Path -LiteralPath $taskOAuthConfig)) {
  $taskOAuthSettings = Get-Content -LiteralPath $taskOAuthConfig -Raw | ConvertFrom-Json
  $GoogleWebClientId = $taskOAuthSettings.webClientId
}
if ($GoogleWebClientId -and $GoogleWebClientId -notmatch '^\d+-[a-zA-Z0-9_-]+\.apps\.googleusercontent\.com$') {
  throw 'Provide a Google Web OAuth client ID, not an Android client ID or client secret.'
}
if ($Release -and $Preview) { throw 'Preview builds are for debug testing only.' }
if ($Release -and !(Test-Path -LiteralPath 'android/key.properties')) { throw 'Configure android/key.properties before a release build. See docs/android.md.' }
$taskArguments = @('build', $(if ($Release) { 'appbundle' } else { 'apk' }), $(if ($Release) { '--release' } else { '--debug' }))
if ($GoogleWebClientId) { $taskArguments += "--dart-define=GOOGLE_WEB_CLIENT_ID=$GoogleWebClientId" }
if ($Preview) { $taskArguments += '--dart-define=TRACKVERSE_PREVIEW=true' }
& $taskFlutter pub get
if ($LASTEXITCODE) { throw 'Flutter dependencies failed.' }
& $taskFlutter @taskArguments
if ($LASTEXITCODE) { throw 'Android build failed.' }
New-Item -ItemType Directory -Path 'release-android' -Force | Out-Null
$taskSource = if ($Release) { 'build/app/outputs/bundle/release/app-release.aab' } else { 'build/app/outputs/flutter-apk/app-debug.apk' }
$taskName = if ($Release) { 'TrackVerse-release.aab' } elseif ($Preview) { 'TrackVerse-preview-debug.apk' } else { 'TrackVerse-debug.apk' }
$taskVersionLine = Select-String -LiteralPath 'pubspec.yaml' -Pattern '^version:\s*(\d+\.\d+\.\d+)'
$taskVersion = $taskVersionLine.Matches[0].Groups[1].Value
$taskName = $taskName.Replace('TrackVerse-', "TrackVerse-$taskVersion-")
$taskDestination = Join-Path 'release-android' $taskName
Copy-Item -LiteralPath $taskSource -Destination $taskDestination -Force
$taskChecksum = (Get-FileHash -LiteralPath $taskDestination -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath "$taskDestination.sha256" -Value "$taskChecksum  $taskName" -Encoding ascii
Write-Output "Built $taskDestination"
