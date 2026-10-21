$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
if (!(Test-Path -LiteralPath 'node_modules\electron\dist\electron.exe')) {
    & npm.cmd ci
    if ($LASTEXITCODE -ne 0) { throw 'Could not install desktop dependencies.' }
    & node '.\node_modules\electron\install.js'
    if ($LASTEXITCODE -ne 0) { throw 'Could not download the desktop runtime.' }
}
if (!(Test-Path -LiteralPath 'build\web\index.html')) {
    throw 'Build the UI first: flutter build web --no-web-resources-cdn'
}
$env:TRACKVERSE_DATA_DIR = Join-Path $PSScriptRoot '.local-data'
& '.\node_modules\electron\dist\electron.exe' '.'
