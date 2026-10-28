// Microsoft's SDK tools, pinned independently of electron-builder's SDK bundle.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {Readable} = require('node:stream');
const {pipeline} = require('node:stream/promises');
const {spawnSync} = require('node:child_process');
const version = '10.0.26100.7463';
const sha256 = 'a04af886752a4a59a6a427c9a154430ab0cb681703faf5ad2ca40b4cc18bd9c6';
const directory = path.resolve(__dirname,'../.local-data/msix-2.0.0/sdk-nuget');
let sdkPromise;
async function prepare() {
  fs.mkdirSync(directory,{recursive:true});
  const file=path.join(directory,`Microsoft.Windows.SDK.BuildTools.${version}.nupkg`);
  if(!fs.existsSync(file)) {
    const url=`https://api.nuget.org/v3-flatcontainer/microsoft.windows.sdk.buildtools/${version}/microsoft.windows.sdk.buildtools.${version}.nupkg`;
    const response=await fetch(url);
    if(!response.ok)throw Error(`Windows SDK download failed: ${response.status}`);
    await pipeline(Readable.fromWeb(response.body),fs.createWriteStream(file));
  }
  const digest=crypto.createHash('sha256');
  for await(const chunk of fs.createReadStream(file))digest.update(chunk);
  if(digest.digest('hex')!==sha256)throw Error('Windows SDK NuGet checksum mismatch; refusing to run tools.');
  const kit=path.join(directory,'x64');
  const script=String.raw`$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=[IO.Path]::GetFullPath($env:TRACKVERSE_MSIX_SDK_OUT)
[IO.Directory]::CreateDirectory($root)|Out-Null
$archive=[IO.Compression.ZipFile]::OpenRead($env:TRACKVERSE_MSIX_SDK_PACKAGE)
try {
  foreach($entry in $archive.Entries) {
    $prefix='bin/10.0.26100.0/x64/'
    if(!$entry.FullName.StartsWith($prefix) -or !$entry.Name){continue}
    $relative=$entry.FullName.Substring($prefix.Length)
    $destination=[IO.Path]::GetFullPath((Join-Path $root $relative))
    if(!$destination.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'SDK path escaped extraction directory'}
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null
    [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$destination,$true)
  }
} finally {$archive.Dispose()}`;
  const result=spawnSync('powershell.exe',['-NoProfile','-NonInteractive','-Command',script],{encoding:'utf8',env:{...process.env,TRACKVERSE_MSIX_SDK_OUT:kit,TRACKVERSE_MSIX_SDK_PACKAGE:file}});
  if(result.error)throw result.error;
  if(result.status!==0)throw Error(`Windows SDK extraction failed: ${result.stderr}`);
  return {kit,version,sha256};
}
module.exports.ensureMsixSdk=()=>sdkPromise||(sdkPromise=prepare());
