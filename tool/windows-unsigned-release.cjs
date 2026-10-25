// Explicit fallback for the maintainer-requested unsigned MSI release.
// Normal dist:win builds still require a trusted signing identity.
const {build} = require('../package.json');

module.exports = {
  ...build,
  forceCodeSigning: false,
  win: {...build.win, signExecutable: false, signExts: []},
};
