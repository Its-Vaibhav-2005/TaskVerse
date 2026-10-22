const fs=require('node:fs');const path=require('node:path');
const root=path.resolve(__dirname,'..');
const config=JSON.parse(fs.readFileSync(path.join(root,'.config','google-client.json'),'utf8'));
if(!config.installed||config.web||config.type==='service_account')throw Error('Release requires a desktop OAuth client, never service-account credentials.');
const allowed=new Set(['client_id','client_secret','project_id','auth_uri','token_uri','auth_provider_x509_cert_url','redirect_uris','universe_domain']);
if(Object.keys(config.installed).some(k=>!allowed.has(k))||Object.keys(config).some(k=>k!=='installed'))throw Error('Unexpected fields in desktop OAuth configuration.');
if(!config.installed.client_id?.endsWith('.apps.googleusercontent.com')||!config.installed.client_secret)throw Error('Desktop OAuth configuration is incomplete.');
if(!fs.existsSync(path.join(root,'build','web','index.html')))throw Error('Build Flutter web assets first.');
for(const file of ['lib/main.dart','lib/model.dart','desktop/main.cjs','desktop/workspaces.cjs']){
  const code=fs.readFileSync(path.join(root,file),'utf8');if(/Explore SQLite sample|Explore with sample habits|sampleTracker|TRACKVERSE_SAMPLE|demoHabits\(/.test(code))throw Error('Sample UI still present in '+file);
}
console.log('Release preflight passed: desktop OAuth only; no sample controls. Personal databases and encrypted tokens are outside the package allowlist.');
