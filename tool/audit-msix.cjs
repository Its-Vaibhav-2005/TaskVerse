const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const {DOMParser} = require('@xmldom/xmldom');
const asar = require('@electron/asar');
const {readIdentity} = require('./windows-msix.cjs');
const root = path.resolve(__dirname, '..');
const work = path.join(root, '.local-data/msix-2.0.0');
const output = path.join(root, 'release-2.0.0');
const hash = file => new Promise((resolve,reject) => {
  const digest=crypto.createHash('sha256');
  fs.createReadStream(file).on('data',chunk=>digest.update(chunk)).on('error',reject).on('end',()=>resolve(digest.digest('hex')));
});
function walk(directory) {
  return fs.readdirSync(directory,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(path.join(directory,e.name)):[path.join(directory,e.name)]);
}
async function auditMsix() {
  const identity = readIdentity(), pkg = require('../package.json');
  const artifactName = `TrackVerse-${pkg.version}-x64.msix`;
  const artifact = path.join(work,'build',artifactName);
  const unpacked = path.join(work,'build/win-unpacked');
  const inspection = path.join(work,'inspection-'+crypto.randomUUID());
  const sdk = await require('./msix-sdk.cjs').ensureMsixSdk();
  // SDK unpack validates the container without installing or trusting a certificate.
  const result = spawnSync(path.join(sdk.kit,'makeappx.exe'),['unpack','/p',artifact,'/d',inspection],{encoding:'utf8',maxBuffer:4*1024*1024});
  fs.writeFileSync(path.join(work,'makeappx-unpack.log'),result.stdout+'\n'+result.stderr);
  if(result.error)throw result.error;
  assert.equal(result.status,0,'MakeAppx could not unpack the MSIX; see local inspection log.');
  const manifestPath=path.join(inspection,'AppxManifest.xml');
  const doc=new DOMParser().parseFromString(fs.readFileSync(manifestPath,'utf8'),'application/xml');
  const first = name => doc.getElementsByTagName(name)[0];
  assert.equal(first('Identity').getAttribute('Name'),identity.identityName);
  assert.equal(first('Identity').getAttribute('Publisher'),identity.publisher);
  assert.equal(first('Identity').getAttribute('Version'),`${pkg.version}.0`);
  assert.equal(first('Identity').getAttribute('ProcessorArchitecture'),'x64');
  assert.equal(first('PublisherDisplayName').textContent,identity.publisherDisplayName);
  assert.equal(first('Application').getAttribute('Id'),'TrackVerse');
  assert.equal(first('Application').getAttribute('Executable'),'app\\TrackVerse.exe');
  assert.equal(first('Application').getAttribute('EntryPoint'),'Windows.FullTrustApplication');
  assert.equal(first('TargetDeviceFamily').getAttribute('Name'),'Windows.Desktop');
  const capabilities=Array.from(doc.getElementsByTagNameNS('*','Capability')).map(e=>e.getAttribute('Name')).sort();
  assert.deepEqual(capabilities,['internetClient','runFullTrust']);
  assert.equal(doc.getElementsByTagNameNS('*','StartupTask').length,0);
  assert.ok(!fs.existsSync(path.join(inspection,'AppxSignature.p7x')),'Store input is expected to be unsigned.');
  const containerFiles=walk(inspection).map(f=>path.relative(inspection,f).replaceAll('\\','/'));
  const forbidden=f=>/(^|\/)(\.local-data|\.config|test|tool|fixtures|\.git)\//.test(f)||/google-tokens|client_secret[^/]*\.json|\.(sqlite3?|db)(-wal|-shm)?$|\.(enc|pfx|p12|test\.cjs)$/.test(f);
  assert.deepEqual(containerFiles.filter(forbidden),[],'Unexpected private or development file in MSIX.');
  const archive=path.join(inspection,'app/resources/app.asar');
  const files=asar.listPackage(archive).map(f=>f.replaceAll('\\','/'));
  assert.deepEqual(files.filter(forbidden),[],'Unexpected private or development file in application archive.');
  const packaged=JSON.parse(asar.extractFile(archive,'package.json').toString());
  assert.equal(packaged.version,pkg.version);
  for(const required of ['desktop/main.cjs','desktop/reminders.cjs','desktop/database.cjs','desktop/pomodoro.html','build/web/main.dart.js','assets/themes.json']) assert.ok(files.includes('/'+required),`Missing ${required}`);
  assert.match(asar.extractFile(archive,'desktop/main.cjs').toString(),/if\(!process\.windowsStore\)app\.setAppUserModelId/);
  assert.equal(fs.readFileSync(path.join(inspection,'app/resources/TRACKVERSE-LICENSE.txt'),'utf8'),fs.readFileSync(path.join(root,'LICENSE'),'utf8'));
  const client=JSON.parse(fs.readFileSync(path.join(inspection,'app/resources/google-client.json'),'utf8'));
  assert.ok(client.installed&&!client.web&&!client.type,'Only public installed-app OAuth metadata may be packaged.');
  assert.deepEqual(Object.keys(client),['installed']);
  const allowedClientKeys=new Set(['client_id','client_secret','project_id','auth_uri','token_uri','auth_provider_x509_cert_url','redirect_uris','universe_domain']);
  assert.ok(Object.keys(client.installed).every(k=>allowedClientKeys.has(k)));
  const payloadFiles=walk(unpacked);
  for(const source of payloadFiles) {
    const target=path.join(inspection,'app',path.relative(unpacked,source));
    assert.ok(fs.existsSync(target),`Missing application payload: ${path.relative(unpacked,source)}`);
    assert.equal(await hash(source),await hash(target),`Payload differs: ${path.relative(unpacked,source)}`);
  }
  assert.equal(walk(path.join(inspection,'app')).length,payloadFiles.length,'Unexpected extra application payload.');
  const logos={StoreLogo:[50,50],Square44x44Logo:[44,44],Square150x150Logo:[150,150],Wide310x150Logo:[310,150]};
  for(const [name,dimensions] of Object.entries(logos)) {
    const png=fs.readFileSync(path.join(inspection,'assets',name+'.png'));
    assert.deepEqual([png.readUInt32BE(16),png.readUInt32BE(20)],dimensions);
    assert.equal(await hash(path.join(inspection,'assets',name+'.png')),await hash(path.join(work,'resources/appx',name+'.png')),'MSIX must use the generated TrackVerse branding.');
  }
  const sha256=await hash(artifact);
  const tests=JSON.parse(fs.readFileSync(path.join(work,'test-results.json'),'utf8'));
  assert.equal(tests.beforePacking,true);
  const report={version:pkg.version,packageVersion:`${pkg.version}.0`,architecture:'x64',artifact:artifactName,bytes:fs.statSync(artifact).size,sha256,identity,capabilities,
    minimumWindowsVersion:first('TargetDeviceFamily').getAttribute('MinVersion'),
    tests,sdk:{package:'Microsoft.Windows.SDK.BuildTools',version:sdk.version,packageSha256:sdk.sha256},packageChecks:{sdkPackValidation:true,sdkUnpackPassed:true,manifestIdentityMatchesPartnerCenter:true,applicationArchiveVersionMatches:true,privateDataExcluded:true,publicInstalledOAuthMetadataOnly:true,licenseIncluded:true,brandedLogoSizesValid:true,unpackedPayloadHashesMatch:true,containerFiles:containerFiles.length,applicationFiles:payloadFiles.length,asarEntries:files.length},
    codeSigned:false,storeCertified:false,installedOrLaunched:false,windowsAppCertificationKitRun:false,
    migration:'MSIX is a separate installation identity from MSI. Export/import a backup; automatic MSI replacement is not implemented.',
    pending:['Partner Center package acceptance and Store certification','Store signing','Packaged runtime tests: launch, notifications, Google OAuth, backup and data migration'],checkedAt:new Date().toISOString()};
  fs.mkdirSync(output,{recursive:true});
  fs.copyFileSync(artifact,path.join(output,artifactName));
  fs.copyFileSync(manifestPath,path.join(output,'AppxManifest.xml'));
  fs.writeFileSync(path.join(output,artifactName+'.sha256'),`${sha256}  ${artifactName}\n`);
  fs.writeFileSync(path.join(output,'msix-verification.json'),JSON.stringify(report,null,2));
  fs.writeFileSync(path.join(output,'README.txt'),`TrackVerse ${pkg.version} — x64 Microsoft Store submission MSIX\n\nPackage: ${artifactName}\nSHA-256: ${sha256}\nIdentity: ${identity.identityName}\nPublisher: ${identity.publisher}\nStore product: ${identity.storeId||'see Partner Center'}\n\nAll application test suites passed before packing. See msix-verification.json.\nThe SDK validated packing and unpacking; payload files match the built app.\nPersonal habit databases, tokens, signing keys and development files are excluded.\nPublic installed-app Google OAuth metadata is included for optional sign-in.\n\nThis package is UNSIGNED input for Microsoft Store submission, not a trusted\ndirect-download installer. Microsoft signs after certification. No certificates\nwere generated or installed, and no Windows security settings were changed.\nThis build has not been installed, launched or WACK-certified.\n\nThe MSIX does not directly upgrade/uninstall the existing MSI. Export a backup\nfrom the old app, then import into the Store app and verify your data.\n\nSubmit this MSIX in the reserved MSIX/PWA product's Packages page. Complete\nrequired product metadata, privacy information and certification notes there.\nThe runFullTrust capability is required for this Electron desktop app.\n`);
  console.log(JSON.stringify(report,null,2));
  return report;
}
module.exports={auditMsix};
if(require.main===module)auditMsix().catch(e=>{console.error(e.message);process.exitCode=1;});
