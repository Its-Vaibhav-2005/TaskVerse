// Signing secrets stay in the environment or the Windows certificate store.
const { build } = require('../package.json');

function releaseConfig(env = process.env) {
  const publisher = env.TRACKVERSE_SIGNING_PUBLISHER?.trim();
  if (!publisher) throw Error('Set TRACKVERSE_SIGNING_PUBLISHER to the verified certificate common name. See docs/windows-signing.md.');
  const azureKeys = ['AZURE_SIGNING_ENDPOINT', 'AZURE_SIGNING_ACCOUNT', 'AZURE_SIGNING_PROFILE'];
  const azure = azureKeys.some(key => env[key]);
  const thumbprint = env.TRACKVERSE_CERTIFICATE_SHA1?.replace(/\s/g, '');
  const pfx = env.WIN_CSC_LINK || env.CSC_LINK;
  if (azure && (thumbprint || pfx)) throw Error('Choose one signing provider: Azure, certificate store, or PFX.');
  if (thumbprint && pfx) throw Error('Choose either the certificate store or PFX signing.');
  if (thumbprint && !/^[a-f\d]{40}$/i.test(thumbprint)) throw Error('TRACKVERSE_CERTIFICATE_SHA1 must be a 40-character certificate thumbprint.');
  if (!azure && !thumbprint && !pfx) throw Error('No signing identity configured. Obtain a publicly trusted code-signing identity; see docs/windows-signing.md.');
  if (azure && azureKeys.some(key => !env[key]?.trim())) throw Error('Azure signing requires endpoint, account, and certificate profile.');
  const signing = azure ? {
    azureSignOptions: {
      publisherName: publisher,
      endpoint: env.AZURE_SIGNING_ENDPOINT,
      codeSigningAccountName: env.AZURE_SIGNING_ACCOUNT,
      certificateProfileName: env.AZURE_SIGNING_PROFILE,
      fileDigest: 'SHA256', timestampDigest: 'SHA256',
      timestampRfc3161: 'http://timestamp.acs.microsoft.com',
    },
  } : {
    signtoolOptions: {
      publisherName: publisher,
      ...(thumbprint ? { certificateSha1: thumbprint } : {}),
      signingHashAlgorithms: ['sha256'],
      rfc3161TimeStampServer: 'http://timestamp.digicert.com',
    },
  };
  return { ...build, forceCodeSigning: true, win: { ...build.win, signExecutable: true, signExts: ['.dll', '.node'], ...signing } };
}

// electron-builder accepts a function returning its configuration.
module.exports = () => releaseConfig();
module.exports.releaseConfig = releaseConfig;
