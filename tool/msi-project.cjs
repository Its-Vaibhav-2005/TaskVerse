// Standard MSI compression keeps release builds fast without storing files uncompressed.
module.exports=async function(projectFile){
  const fs=require('node:fs/promises');
  const text=await fs.readFile(projectFile,'utf8');
  const baseline=require('./windows-upgrade-baseline.json');
  if(!text.includes(`UpgradeCode="${baseline.upgradeCode}"`))throw Error('MSI UpgradeCode changed; existing users would not be upgraded.');
  if(!text.includes('<MajorUpgrade ')||!text.includes('DowngradeErrorMessage='))throw Error('MSI must support major upgrades and reject downgrades.');
  if(!text.includes(`Name="${baseline.productName}"`)||!text.includes('Id="APPLICATIONFOLDER"'))throw Error('MSI product or installation directory identity changed.');
  if(!text.includes('<MediaTemplate CompressionLevel="high"'))throw Error('Unexpected MSI media template');
  await fs.writeFile(projectFile,text.replace('<MediaTemplate CompressionLevel="high"','<MediaTemplate CompressionLevel="mszip"'));
};
