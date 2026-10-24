const fs=require('node:fs');const path=require('node:path');const crypto=require('node:crypto');const asar=require('@electron/asar');
const {spawnSync}=require('node:child_process');
async function main(){
  const root=path.resolve(__dirname,'..'),dist=path.resolve(root,process.argv[2]||'dist'),archive=path.join(dist,'win-unpacked','resources','app.asar');
  const pkg=JSON.parse(fs.readFileSync(path.join(root,'package.json'),'utf8'));
  const msi=path.join(dist,`TrackVerse-Setup-${pkg.version}-x64.msi`);
  // A failed re-audit must not leave a previous successful report/checksum behind.
  for(const file of [path.join(dist,'release-audit.json'),msi+'.sha256'])fs.rmSync(file,{force:true});
  if(process.platform!=='win32')throw Error('Release signature verification requires Windows.');
  const publisher=process.env.TRACKVERSE_SIGNING_PUBLISHER?.trim();
  if(!publisher)throw Error('Set TRACKVERSE_SIGNING_PUBLISHER to the verified certificate common name.');
  const verification=spawnSync('powershell.exe',['-NoProfile','-NonInteractive','-File',path.join(__dirname,'verify-windows-signatures.ps1'),'-AppDirectory',path.join(dist,'win-unpacked'),'-Installer',msi,'-Publisher',publisher],{encoding:'utf8',maxBuffer:10*1024*1024});
  if(verification.error)throw verification.error;
  if(verification.status!==0)throw Error('Windows signature verification failed: '+verification.stderr.trim());
  const signatures=JSON.parse(verification.stdout.replace(/^\uFEFF/,''));
  if(!Array.isArray(signatures)||signatures.length<2)throw Error('Incomplete signature verification evidence.');
  const files=asar.listPackage(archive).map(file=>file.replaceAll('\\','/'));
  const forbidden=files.filter(f=>/(^|\/)(\.local-data|\.config|test|tool|fixtures)\//.test(f)||/google-tokens|client_secret[^/]*\.json|\.(sqlite3?|db)(-wal|-shm)?$|\.(enc|test\.cjs)$/.test(f)||/\/desktop\/sample-tracker\.cjs$/.test(f));
  if(forbidden.length)throw Error('Private or development artifacts in release: '+forbidden.join(', '));
  const config=JSON.parse(fs.readFileSync(path.join(dist,'win-unpacked','resources','google-client.json'),'utf8'));
  if(!config.installed||config.web||config.type)throw Error('Wrong OAuth configuration type');
  const bundled=JSON.parse(asar.extractFile(archive,'package.json').toString());
  if(bundled.version!==pkg.version)throw Error('Packaged application version does not match release.');
  for(const required of ['desktop/pomodoro.html','desktop/pomodoro.cjs','desktop/focus-window.cjs','desktop/theme-palette.cjs','assets/themes.json','build/web/main.dart.js'])if(!files.includes('/'+required))throw Error('Missing release feature: '+required);
  const palettes=JSON.parse(asar.extractFile(archive,'assets/themes.json').toString());if(palettes.length!==43)throw Error('Incomplete theme catalog');
  const digest=crypto.createHash('sha256');
  for await(const chunk of fs.createReadStream(msi))digest.update(chunk);
  const hash=digest.digest('hex');
  fs.writeFileSync(msi+'.sha256',`${hash}  ${path.basename(msi)}\n`);
  const report={version:pkg.version,artifact:path.basename(msi),bytes:fs.statSync(msi).size,sha256:hash,packagedFiles:files.length,personalDatabasesExcluded:true,tokenVaultsExcluded:true,sampleModuleExcluded:true,oauthType:'public installed desktop client',codeSigned:true,publisher,signatures,iceValidation:'Unavailable under host policy; MSI built with -sval',checkedAt:new Date().toISOString()};
  fs.writeFileSync(path.join(dist,'release-audit.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report));
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
