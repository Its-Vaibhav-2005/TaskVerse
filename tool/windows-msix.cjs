// Unsigned Store-submission package; does not change the signed MSI build path.
const fs = require('node:fs');
const path = require('node:path');
const {build} = require('../package.json');
const root = path.resolve(__dirname, '..');
// Store 2.0.0.0 is already published; the corrected 2.0.0 app needs a
// monotonically higher servicing package version (Store revision stays zero).
const storePackageVersion = '2.0.1.0';
const xml = value => value.replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&apos;'}[c]));

function msixConfig(identity) {
  if (!identity || !/^[A-Za-z0-9][A-Za-z0-9.-]{2,49}$/.test(identity.identityName || '')) throw Error('A valid Partner Center Package/Identity/Name is required.');
  if (!/^CN=[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}$/.test(identity.publisher || '')) throw Error('Use the exact CN=GUID publisher from Partner Center Product identity.');
  if (typeof identity.publisherDisplayName !== 'string' || !identity.publisherDisplayName.trim()) throw Error('Partner Center PublisherDisplayName is required.');
  return {
    ...build,
    forceCodeSigning: false,
    directories: {...build.directories, output: '.local-data/msix-2.0.0/build', buildResources: '.local-data/msix-2.0.0/resources'},
    toolsets: {winCodeSign: '1.1.0'},
    win: {...build.win, target: 'appx', signExecutable: false, signExts: []},
    appx: {
      customManifestPath: path.join(root, '.local-data/msix-2.0.0/resources/AppxManifest.xml'),
      // This builder version calls the target "appx"; MakeAppx writes MSIX directly.
      artifactName: 'TrackVerse-${version}-${arch}.msix',
      applicationId: 'TrackVerse',
      identityName: identity.identityName,
      publisher: xml(identity.publisher),
      publisherDisplayName: xml(identity.publisherDisplayName),
      displayName: 'TrackVerse', backgroundColor: '#394047',
      languages: ['en-US'], capabilities: ['internetClient'],
      minVersion: '10.0.19041.0', maxVersionTested: '10.0.26100.0',
      setBuildNumber: false, addAutoLaunchExtension: false,
    },
  };
}

function readIdentity() {
  const file = path.join(root, '.config/msix-identity.json');
  if (!fs.existsSync(file)) throw Error('Save Partner Center Product identity in .config/msix-identity.json; see docs/windows-msix.md.');
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}
module.exports = () => msixConfig(readIdentity());
module.exports.msixConfig = msixConfig;
module.exports.readIdentity = readIdentity;
module.exports.storePackageVersion = storePackageVersion;
