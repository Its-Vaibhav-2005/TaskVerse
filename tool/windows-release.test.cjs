const test = require('node:test');
const assert = require('node:assert/strict');
const { releaseConfig } = require('./windows-release.cjs');

test('release refuses missing, conflicting, and malformed signing identities', () => {
  assert.throws(() => releaseConfig({}), /PUBLISHER/);
  const env = { TRACKVERSE_SIGNING_PUBLISHER: 'Verified Developer' };
  assert.throws(() => releaseConfig(env), /No signing identity/);
  assert.throws(() => releaseConfig({ ...env, TRACKVERSE_CERTIFICATE_SHA1: 'bad' }), /thumbprint/);
  assert.throws(() => releaseConfig({ ...env, AZURE_SIGNING_ENDPOINT: 'https://example.com' }), /endpoint, account/);
  assert.throws(() => releaseConfig({ ...env, AZURE_SIGNING_ENDPOINT: 'https://example.com', CSC_LINK: 'secret.pfx' }), /one signing provider/);
  assert.throws(() => releaseConfig({ ...env, TRACKVERSE_CERTIFICATE_SHA1: 'a'.repeat(40), CSC_LINK: 'secret.pfx' }), /either/);
});

test('store and PFX signing require signatures for binaries and installer', () => {
  for (const identity of [{ TRACKVERSE_CERTIFICATE_SHA1: 'ab '.repeat(20) }, { WIN_CSC_LINK: 'private.pfx' }]) {
    const config = releaseConfig({ TRACKVERSE_SIGNING_PUBLISHER: 'Verified Developer', ...identity });
    assert.equal(config.forceCodeSigning, true);
    assert.equal(config.win.signExecutable, true);
    assert.deepEqual(config.win.signExts, ['.dll', '.node']);
    assert.deepEqual(config.win.signtoolOptions.signingHashAlgorithms, ['sha256']);
    assert.ok(config.win.signtoolOptions.rfc3161TimeStampServer);
    assert.equal(config.win.azureSignOptions, undefined);
  }
});

test('Azure signing maps the public certificate profile and timestamp settings', () => {
  const config = releaseConfig({ TRACKVERSE_SIGNING_PUBLISHER: 'Verified Developer', AZURE_SIGNING_ENDPOINT: 'https://example.com', AZURE_SIGNING_ACCOUNT: 'account', AZURE_SIGNING_PROFILE: 'public-profile' });
  assert.equal(config.win.azureSignOptions.codeSigningAccountName, 'account');
  assert.equal(config.win.azureSignOptions.certificateProfileName, 'public-profile');
  assert.equal(config.win.azureSignOptions.publisherName, 'Verified Developer');
  assert.equal(config.win.azureSignOptions.timestampDigest, 'SHA256');
  assert.equal(config.win.signtoolOptions, undefined);
});

test('both signing routes match the installed electron-builder configuration schema', async () => {
  const { validateConfiguration } = require('app-builder-lib/out/util/config/config');
  for (const identity of [
    { TRACKVERSE_CERTIFICATE_SHA1: 'a'.repeat(40) },
    { AZURE_SIGNING_ENDPOINT: 'https://example.com', AZURE_SIGNING_ACCOUNT: 'account', AZURE_SIGNING_PROFILE: 'public-profile' },
  ]) {
    await validateConfiguration(releaseConfig({ TRACKVERSE_SIGNING_PUBLISHER: 'Verified Developer', ...identity }));
  }
});

test('release version and installer identity preserve the released 1.1.0 upgrade path', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const pkg = require('../package.json');
  const lock = require('../package-lock.json');
  const baseline = require('./windows-upgrade-baseline.json');
  const { UUID } = require('builder-util-runtime');
  const legacyDefault = UUID.v5(baseline.appId, UUID.parse('d752fe43-5d44-44d5-9fc9-6dd1bf19d5cc')).toUpperCase();
  assert.equal(pkg.version, '1.2.1');
  assert.equal(lock.version, pkg.version);
  assert.equal(lock.packages[''].version, pkg.version);
  assert.match(fs.readFileSync(path.join(__dirname, '../pubspec.yaml'), 'utf8'), /^version: 1\.2\.1\+4$/m);
  assert.equal(pkg.build.msi.upgradeCode, baseline.upgradeCode);
  assert.equal(pkg.build.msi.upgradeCode, legacyDefault);
  assert.equal(pkg.build.appId, baseline.appId);
  assert.equal(pkg.name, baseline.packageName);
  assert.equal(pkg.build.productName, baseline.productName);
  assert.equal(pkg.author, baseline.manufacturer);
  assert.equal(pkg.build.msi.perMachine, baseline.perMachine);
});

test('MSI generation rejects a changed upgrade identity before creating an installer', async t => {
  const fs = require('node:fs/promises');
  const path = require('node:path');
  const os = require('node:os');
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'trackverse-msi-policy-'));
  t.after(() => fs.rm(directory, {recursive: true, force: true}));
  const file = path.join(directory, 'project.wxs');
  const hook = require('./msi-project.cjs');
  const baseline = require('./windows-upgrade-baseline.json');
  const manifest = `<Product Name="TrackVerse" UpgradeCode="${baseline.upgradeCode}"><MajorUpgrade DowngradeErrorMessage="Newer version installed"/><Directory Id="APPLICATIONFOLDER"/><MediaTemplate CompressionLevel="high"/></Product>`;
  await fs.writeFile(file, manifest);
  await hook(file);
  assert.match(await fs.readFile(file, 'utf8'), /CompressionLevel="mszip"/);
  await fs.writeFile(file, manifest.replace(baseline.upgradeCode, '00000000-0000-0000-0000-000000000000'));
  await assert.rejects(() => hook(file), /UpgradeCode changed/);
  await fs.writeFile(file, manifest.replace('<MajorUpgrade ', '<OtherElement '));
  await assert.rejects(() => hook(file), /major upgrades/);
});
