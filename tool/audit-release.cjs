const fs=require('node:fs');const path=require('node:path');const crypto=require('node:crypto');const asar=require('@electron/asar');
async function main(){
  const root=path.resolve(__dirname,'..'),dist=path.join(root,'dist'),archive=path.join(dist,'win-unpacked','resources','app.asar');
  const files=asar.listPackage(archive);
  const forbidden=files.filter(f=>/(^|\/)(\.local-data|\.config|test|tool)\//.test(f)||/google-tokens|client_secret[^/]*\.json|\.(sqlite3|enc|test\.cjs)$/.test(f)||/\/desktop\/sample-tracker\.cjs$/.test(f));
  if(forbidden.length)throw Error('Private or development artifacts in release: '+forbidden.join(', '));
  const config=JSON.parse(fs.readFileSync(path.join(dist,'win-unpacked','resources','google-client.json'),'utf8'));
  if(!config.installed||config.web||config.type)throw Error('Wrong OAuth configuration type');
  const pkg=JSON.parse(fs.readFileSync(path.join(root,'package.json'),'utf8'));
  const msi=path.join(dist,`TrackVerse-Setup-${pkg.version}-x64.msi`),digest=crypto.createHash('sha256');
  for await(const chunk of fs.createReadStream(msi))digest.update(chunk);
  const hash=digest.digest('hex');
  fs.writeFileSync(msi+'.sha256',`${hash}  ${path.basename(msi)}\n`);
  const report={version:pkg.version,artifact:path.basename(msi),bytes:fs.statSync(msi).size,sha256:hash,packagedFiles:files.length,personalDatabasesExcluded:true,tokenVaultsExcluded:true,sampleModuleExcluded:true,oauthType:'public installed desktop client',codeSigned:false,iceValidation:'Unavailable under host policy; MSI built with -sval',checkedAt:new Date().toISOString()};
  fs.writeFileSync(path.join(dist,'release-audit.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report));
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
