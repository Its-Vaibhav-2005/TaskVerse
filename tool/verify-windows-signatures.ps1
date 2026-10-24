param(
    [Parameter(Mandatory = $true)][string]$AppDirectory,
    [Parameter(Mandatory = $true)][string]$Installer,
    [Parameter(Mandatory = $true)][string]$Publisher
)
$ErrorActionPreference = 'Stop'
$appRoot = (Resolve-Path -LiteralPath $AppDirectory).Path
$installerFile = Get-Item -LiteralPath $Installer
$mainExe = Join-Path $appRoot 'TrackVerse.exe'
if (!(Test-Path -LiteralPath $mainExe -PathType Leaf)) { throw 'TrackVerse.exe is missing.' }
$files = @(Get-ChildItem -LiteralPath $appRoot -File -Recurse | Where-Object { $_.Extension.ToLowerInvariant() -in '.exe', '.dll', '.node' }) + @($installerFile)
$evidence = foreach ($file in $files) {
    $signature = Get-AuthenticodeSignature -LiteralPath $file.FullName
    if ($signature.Status -ne 'Valid') { throw "Untrusted or missing signature: $($file.FullName) ($($signature.Status))." }
    if (!$signature.TimeStamperCertificate) { throw "Missing trusted timestamp: $($file.FullName)." }
    $name = $signature.SignerCertificate.GetNameInfo([System.Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
    if (($file.FullName -eq $mainExe -or $file.FullName -eq $installerFile.FullName) -and $name -cne $Publisher) {
        throw "Publisher mismatch: $($file.FullName). Expected '$Publisher', found '$name'."
    }
    [pscustomobject]@{
        file = $file.FullName
        status = [string]$signature.Status
        publisher = $name
        thumbprint = $signature.SignerCertificate.Thumbprint
        timestamped = $true
    }
}
ConvertTo-Json -InputObject @($evidence) -Depth 4 -Compress
