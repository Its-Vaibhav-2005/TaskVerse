const fs=require('node:fs');
const path=require('node:path');
const http=require('node:http');
const crypto=require('node:crypto');
const {OAuth2Client}=require('google-auth-library');
const SCOPES=['openid','email','profile','https://www.googleapis.com/auth/drive.file'];

class GoogleAuth {
  constructor(directory,{safeStorage,openBrowser}) {
    this.directory=directory;this.safeStorage=safeStorage;this.openBrowser=openBrowser;
    this.client=null;this.identity=null;this.signingIn=false;
    const config=this.readVault('google-client');
    if(config)this.configure(config,false);
  }
  writeVault(name,data) {
    if(!this.safeStorage.isEncryptionAvailable())throw Error('Windows credential encryption is unavailable. Google sign-in cannot be saved securely.');
    const file=path.join(this.directory,`${name}.enc`),temp=file+'.tmp';
    fs.writeFileSync(temp,this.safeStorage.encryptString(JSON.stringify(data)));fs.renameSync(temp,file);
  }
  readVault(name) {
    const file=path.join(this.directory,`${name}.enc`);
    if(!fs.existsSync(file))return null;
    try{return JSON.parse(this.safeStorage.decryptString(fs.readFileSync(file)));}catch(_){return null;}
  }
  configure(raw,persist=true) {
    const c=raw.installed;
    if(!c||typeof c.client_id!=='string'||!c.client_id.endsWith('.apps.googleusercontent.com')||typeof c.client_secret!=='string')throw Error('Choose the Google OAuth JSON downloaded for a Desktop app.');
    this.clientId=c.client_id;
    this.identity=null;
    this.client=new OAuth2Client({clientId:c.client_id,clientSecret:c.client_secret});
    const saved=this.readVault('google-tokens');
    if(saved?.clientId===c.client_id){this.client.setCredentials(saved.tokens);this.identity=saved.identity;}
    this.client.on('tokens',tokens=>{if(!this.identity)return;const existing=this.readVault('google-tokens');this.writeVault('google-tokens',{clientId:c.client_id,tokens:{...existing?.tokens,...this.client.credentials,...tokens},identity:this.identity});});
    if(persist)this.writeVault('google-client',{installed:c});
  }
  status() {return {configured:!!this.client,connected:!!this.client?.credentials?.refresh_token,identity:this.identity,signingIn:this.signingIn};}
  async refreshProfile() {
    if(!this.status().connected||!this.identity)return;
    const identityId=this.identity.id;
    try {
      const response=await fetch('https://openidconnect.googleapis.com/v1/userinfo',{headers:{Authorization:`Bearer ${await this.token()}`},signal:AbortSignal.timeout(10000)});
      if(!response.ok)return;const profile=await response.json();
      if(profile.sub!==identityId)return;
      let photo=null;
      if(profile.picture){const url=new URL(profile.picture);if(url.protocol==='https:'&&url.hostname.endsWith('.googleusercontent.com')){
        const image=await fetch(url,{signal:AbortSignal.timeout(10000)});
        if(image.ok&&/^image\//.test(image.headers.get('content-type')||'')){const bytes=Buffer.from(await image.arrayBuffer());if(bytes.length<=1024*1024)photo=bytes.toString('base64');}
      }}
      if(this.identity?.id!==identityId||!this.status().connected)return;
      this.identity={...this.identity,name:profile.name||this.identity.name,photo:photo||this.identity.photo||null};
      this.writeVault('google-tokens',{clientId:this.clientId,tokens:this.client.credentials,identity:this.identity});
    }catch(_){/* Profile images are optional; offline use remains available. */}
  }
  async signIn() {
    if(!this.client)throw Error('Google sign-in setup is not finished yet. Configure the TrackVerse desktop OAuth client first.');
    if(this.signingIn)throw Error('Google sign-in is already open in your browser.');
    this.signingIn=true;
    const previousIdentity=this.identity;
    const previousTokens={...this.client.credentials};
    this.identity=null;
    const state=crypto.randomBytes(32).toString('hex');
    const {codeVerifier,codeChallenge}=await this.client.generateCodeVerifierAsync();
    let server,timer;
    try {
      const code=await new Promise((resolve,reject)=>{
        server=http.createServer((req,res)=>{
          const url=new URL(req.url,'http://127.0.0.1');
          if(url.pathname!=='/oauth2callback'){res.writeHead(404);res.end();return;}
          if(url.searchParams.get('state')!==state){res.writeHead(400);res.end('Invalid sign-in response.');return;}
          if(url.searchParams.get('error')||!url.searchParams.get('code')){res.end('Sign-in was cancelled. Return to TrackVerse.');reject(Error('Google sign-in was cancelled.'));return;}
          res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'"});
          res.end('<html><body style="background:#121a19;color:#e5ede8;font:18px system-ui;padding:60px"><h1>Welcome to TrackVerse.</h1><p>Sign-in received. You can return to the app.</p></body></html>');
          resolve({code:url.searchParams.get('code'),redirect_uri:`http://127.0.0.1:${server.address().port}/oauth2callback`});
        });
        server.on('error',reject);
        server.listen(0,'127.0.0.1',()=>{
          const redirect_uri=`http://127.0.0.1:${server.address().port}/oauth2callback`;
          this.openBrowser(this.client.generateAuthUrl({redirect_uri,scope:SCOPES,state,code_challenge:codeChallenge,code_challenge_method:'S256',access_type:'offline',prompt:'consent',include_granted_scopes:true})).catch(reject);
        });
        timer=setTimeout(()=>reject(Error('Google sign-in timed out. Please try again.')),180000);
        this.cancel=()=>reject(Error('Google sign-in cancelled.'));
      });
      const {tokens}=await this.client.getToken({...code,codeVerifier});
      if(!tokens.refresh_token)throw Error('Google did not grant offline access. Reconnect and allow the requested permissions.');
      const ticket=await this.client.verifyIdToken({idToken:tokens.id_token,audience:this.clientId});
      const payload=ticket.getPayload();
      const identity={id:payload.sub,email:payload.email,name:payload.name||payload.email};
      this.writeVault('google-tokens',{clientId:this.clientId,tokens,identity});
      this.client.setCredentials(tokens);this.identity=identity;
      await this.refreshProfile();
      return this.status();
    } catch(error) {
      this.client.setCredentials(previousTokens);this.identity=previousIdentity;throw error;
    } finally {clearTimeout(timer);server?.close();this.cancel=null;this.signingIn=false;}
  }
  async token() {
    if(!this.status().connected)throw Error('Sign in with Google to sync your trackers.');
    let timeout;
    try {const {token}=await Promise.race([this.client.getAccessToken(),new Promise((_,reject)=>{timeout=setTimeout(()=>reject(Error('Token refresh timed out')),15000);})]);if(!token)throw Error();return token;}
    catch(_){throw Error('Google access expired. Reconnect your Google account; local data is safe.');}
    finally {clearTimeout(timeout);}
  }
  signOut() {this.cancel?.();if(this.client)this.client.setCredentials({});this.identity=null;const file=path.join(this.directory,'google-tokens.enc');if(fs.existsSync(file))fs.unlinkSync(file);}
}
module.exports={GoogleAuth,SCOPES};
