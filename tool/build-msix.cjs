const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const output = path.join(root, 'release-2.0.0');
const work = path.join(root, '.local-data/msix-2.0.0');

function run(file, args, options = {}) {
  const result = spawnSync(file, args, {cwd:root, stdio:'inherit', ...options});
  if (result.error) throw result.error;
  if (result.status !== 0) throw Error(`${path.basename(file)} ${args[0]} failed (${result.status}); packing stopped.`);
}
async function main() {
  if (process.platform !== 'win32') throw Error('Build the MSIX on Windows.');
  const pkg = require('../package.json');
  if(pkg.version !== '2.0.0') throw Error('This release recipe targets version 2.0.0.');
  const {readIdentity,msixConfig} = require('./windows-msix.cjs');
  const identity = readIdentity(); msixConfig(identity);
  const flutter = process.env.FLUTTER_BIN || path.join(os.homedir(), '.codex/tools/flutter/bin/flutter.bat');
  if (!fs.existsSync(flutter) || flutter.includes('"')) throw Error('Set FLUTTER_BIN to your flutter.bat path.');
  const flutterRun = args => run(process.env.ComSpec || 'cmd.exe', ['/d','/s','/c',`""${flutter}" ${args.join(' ')}"`], {windowsVerbatimArguments:true});
  // All test suites finish successfully before any application packing starts.
  run(process.execPath, ['--test', ...fs.readdirSync(path.join(root,'desktop')).filter(f=>f.endsWith('.test.cjs')).map(f=>'desktop/'+f)]);
  run(process.execPath, ['--test', ...fs.readdirSync(path.join(root,'tool')).filter(f=>f.endsWith('.test.cjs')).map(f=>'tool/'+f)]);
  flutterRun(['analyze']); flutterRun(['test']);
  flutterRun(['build','web','--no-web-resources-cdn']);
  run(process.execPath, ['tool/validate-release.cjs']);
  fs.mkdirSync(output, {recursive:true}); fs.mkdirSync(work, {recursive:true});
  fs.writeFileSync(path.join(work,'test-results.json'), JSON.stringify({desktop:'All desktop tests passed',flutter:'All Flutter tests passed',releasePolicy:'All release policy tests passed',flutterAnalysis:'No issues found',webBuild:'Passed',beforePacking:true,checkedAt:new Date().toISOString()},null,2));
  const assets = path.join(work,'resources/appx'); fs.mkdirSync(assets,{recursive:true});
  const logoScript = `$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$source=[Drawing.Image]::FromFile($env:TRACKVERSE_MSIX_LOGO)
try {
  foreach($spec in @(@('StoreLogo.png',50,50),@('Square44x44Logo.png',44,44),@('Square150x150Logo.png',150,150),@('Wide310x150Logo.png',310,150))) {
    $bitmap=[Drawing.Bitmap]::new([int]$spec[1],[int]$spec[2]); $graphics=[Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.Clear([Drawing.Color]::Transparent)
      $graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $size=[int]([Math]::Min([int]$spec[1],[int]$spec[2]) * 0.85)
      $graphics.DrawImage($source,[int](([int]$spec[1]-$size)/2),[int](([int]$spec[2]-$size)/2),$size,$size)
      $bitmap.Save((Join-Path $env:TRACKVERSE_MSIX_ASSETS $spec[0]),[Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
  }
} finally {$source.Dispose()}`;
  run('powershell.exe',['-NoProfile','-NonInteractive','-Command',logoScript],{env:{...process.env,TRACKVERSE_MSIX_LOGO:path.join(root,'assets/trackverse.png'),TRACKVERSE_MSIX_ASSETS:assets}});
  const sdk=await require('./msix-sdk.cjs').ensureMsixSdk();
  process.env.ELECTRON_BUILDER_WINDOWS_KITS_PATH=sdk.kit;
  // Use the installed builder's Windows Store target with an explicit .msix output.
  run(process.execPath,['node_modules/electron-builder/cli.js','--config','tool/windows-msix.cjs','--win','appx','--x64','--publish','never']);
  await require('./audit-msix.cjs').auditMsix();
}
main().catch(error=>{console.error(error.message);process.exitCode=1;});
