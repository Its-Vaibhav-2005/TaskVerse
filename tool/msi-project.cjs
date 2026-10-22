// Standard MSI compression keeps release builds fast without storing files uncompressed.
module.exports=async function(projectFile){
  const fs=require('node:fs/promises');
  const text=await fs.readFile(projectFile,'utf8');
  if(!text.includes('<MediaTemplate CompressionLevel="high"'))throw Error('Unexpected MSI media template');
  await fs.writeFile(projectFile,text.replace('<MediaTemplate CompressionLevel="high"','<MediaTemplate CompressionLevel="mszip"'));
};
