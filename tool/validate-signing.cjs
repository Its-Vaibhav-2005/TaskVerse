try {
  require('./windows-release.cjs').releaseConfig();
  console.log('Signing configuration present. Release audit must still verify trust and timestamps.');
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
