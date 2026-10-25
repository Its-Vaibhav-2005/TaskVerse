// Package-content and upgrade checks for an intentionally unsigned MSI.
// The signed audit remains mandatory for releases built through dist:win.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');
const asar = require('@electron/asar');

function readMsiMetadata(msi, expectedUpgradeCode) {
  const script = String.raw`
$ErrorActionPreference = 'Stop'
$msi = $env:TRACKVERSE_MSI_FILE
$database = (New-Object -ComObject WindowsInstaller.Installer).OpenDatabase($msi, 0)
$quote = [string][char]96
function Read-Property([string]$name) {
  $sql = 'SELECT '+$quote+'Value'+$quote+' FROM '+$quote+'Property'+$quote+' WHERE '+$quote+'Property'+$quote+" = '$name'"
  $view = $database.OpenView($sql)
  $view.Execute()
  $record = $view.Fetch()
  if ($null -eq $record) { throw "MSI property missing: $name" }
  return $record.StringData(1)
}
$view = $database.OpenView('SELECT '+$quote+'UpgradeCode'+$quote+' FROM '+$quote+'Upgrade'+$quote)
$view.Execute()
$upgradeCodes = @()
while ($null -ne ($record = $view.Fetch())) { $upgradeCodes += $record.StringData(1) }
$signature = 'NotSigned'
try {
  [void][System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromSignedFile($msi)
  $signature = 'Signed'
} catch { }
[ordered]@{
  ProductName = Read-Property 'ProductName'
  ProductVersion = Read-Property 'ProductVersion'
  Manufacturer = Read-Property 'Manufacturer'
  ProductCode = Read-Property 'ProductCode'
  UpgradeCodes = @($upgradeCodes)
  SignatureStatus = $signature
} | ConvertTo-Json -Compress
`;
  const output = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', script], {
    encoding: 'utf8', maxBuffer: 1024 * 1024,
    env: {...process.env, TRACKVERSE_MSI_FILE: msi},
  });
  if (output.error) throw output.error;
  if (output.status !== 0) throw Error(`Could not inspect MSI metadata: ${output.stderr.trim()}`);
  const result = JSON.parse(output.stdout.trim());
  const scalar = value => Array.isArray(value) ? scalar(value.filter(item => item != null).at(-1)) : value;
  for (const key of ['ProductName', 'ProductVersion', 'Manufacturer', 'ProductCode', 'SignatureStatus']) result[key] = scalar(result[key]);
  const normalizeGuid = value => value.replace(/[{}]/g, '').toUpperCase();
  const upgradeCodes = [result.UpgradeCodes].flat(Infinity).filter(value => typeof value === 'string').map(normalizeGuid);
  if (result.ProductName !== 'TrackVerse' || !/^1\.3\.0(?:\.0)?$/.test(result.ProductVersion)) throw Error(`MSI product name or version does not match: ${JSON.stringify({name: result.ProductName, version: result.ProductVersion})}`);
  if (!upgradeCodes.includes(normalizeGuid(expectedUpgradeCode))) throw Error(`MSI upgrade identity mismatch: expected ${expectedUpgradeCode}; found ${JSON.stringify(upgradeCodes)}.`);
  if (result.SignatureStatus !== 'NotSigned') throw Error(`Expected an unsigned MSI; Windows reports ${result.SignatureStatus}.`);
  return result;
}

async function main() {
  if (process.platform !== 'win32') throw Error('MSI package inspection requires Windows.');
  const root = path.resolve(__dirname, '..');
  const dist = path.resolve(root, process.argv[2] || 'dist/release-1.3.0');
  const msi = path.join(dist, 'TrackVerse-Setup-1.3.0-x64.msi');
  const archive = path.join(dist, 'win-unpacked', 'resources', 'app.asar');
  const pkg = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
  const baseline = JSON.parse(fs.readFileSync(path.join(__dirname, 'windows-upgrade-baseline.json'), 'utf8'));
  if (pkg.version !== '1.3.0' || !fs.existsSync(msi) || !fs.existsSync(archive)) throw Error('Expected 1.3.0 MSI and packaged application.');

  const files = asar.listPackage(archive).map(file => file.replaceAll('\\', '/'));
  const forbidden = files.filter(file => /(^|\/)(\.local-data|\.config|test|tool|fixtures)\//.test(file) || /google-tokens|client_secret[^/]*\.json|\.(sqlite3?|db)(-wal|-shm)?$|\.(enc|test\.cjs)$/.test(file) || /\/desktop\/sample-tracker\.cjs$/.test(file));
  if (forbidden.length) throw Error(`Private or development artifacts in MSI: ${forbidden.join(', ')}`);
  const required = ['desktop/pomodoro.html', 'desktop/pomodoro.cjs', 'desktop/focus-window.cjs', 'desktop/theme-palette.cjs', 'assets/themes.json', 'build/web/main.dart.js'];
  for (const file of required) if (!files.includes(`/${file}`)) throw Error(`MSI is missing ${file}.`);
  const bundled = JSON.parse(asar.extractFile(archive, 'package.json').toString());
  if (bundled.version !== pkg.version) throw Error('Packaged application version mismatch.');
  const metadata = readMsiMetadata(msi, baseline.upgradeCode);
  const palettes = JSON.parse(asar.extractFile(archive, 'assets/themes.json').toString());
  if (palettes.length !== 43) throw Error('MSI is missing theme presets.');
  const digest = crypto.createHash('sha256');
  for await (const chunk of fs.createReadStream(msi)) digest.update(chunk);
  const sha256 = digest.digest('hex');
  fs.writeFileSync(`${msi}.sha256`, `${sha256}  ${path.basename(msi)}\n`);
  const report = {
    version: pkg.version,
    artifact: path.basename(msi),
    bytes: fs.statSync(msi).size,
    sha256,
    packagedFiles: files.length,
    privateDataExcluded: true,
    requiredFeaturesPresent: true,
    upgradeCode: baseline.upgradeCode,
    productCode: metadata.ProductCode,
    codeSigned: false,
    signatureStatus: metadata.SignatureStatus,
    publisherAudit: 'not performed; this release is unsigned',
    checkedAt: new Date().toISOString(),
  };
  fs.writeFileSync(path.join(dist, 'release-audit.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
}

main().catch(error => { console.error(error.message); process.exitCode = 1; });
