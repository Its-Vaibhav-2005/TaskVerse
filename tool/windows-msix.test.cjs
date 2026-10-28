const test = require('node:test');
const assert = require('node:assert/strict');
const {msixConfig} = require('./windows-msix.cjs');
const identity = {identityName:'Example.TrackVerse', publisher:'CN=00000000-0000-0000-0000-000000000001', publisherDisplayName:'Example & Team'};

test('MSIX configuration refuses missing or invented certificate-style Store identity', () => {
  assert.throws(() => msixConfig(), /Identity\/Name/);
  assert.throws(() => msixConfig({...identity, identityName:'bad name'}), /Identity\/Name/);
  assert.throws(() => msixConfig({...identity, publisher:'CN=TrackVerse'}), /CN=GUID/);
  assert.throws(() => msixConfig({...identity, publisherDisplayName:''}), /PublisherDisplayName/);
});

test('Store packaging fits installed builder schema, escapes XML, and leaves default MSI signing intact', async () => {
  const {validateConfiguration} = require('app-builder-lib/out/util/config/config');
  const config = msixConfig(identity);
  await validateConfiguration(config);
  assert.equal(config.appx.publisherDisplayName, 'Example &amp; Team');
  assert.equal(config.appx.publisher, identity.publisher);
  assert.equal(config.appx.identityName, identity.identityName);
  assert.equal(config.appx.applicationId, 'TrackVerse');
  assert.equal(config.appx.setBuildNumber, false);
  assert.equal(config.appx.addAutoLaunchExtension, false);
  assert.deepEqual(config.appx.capabilities, ['internetClient']);
  assert.equal(require('../package.json').build.forceCodeSigning, true);
  assert.equal(require('../package.json').build.win.target, 'msi');
});
