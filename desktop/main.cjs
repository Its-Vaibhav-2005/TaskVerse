const { app, BrowserWindow, ipcMain, protocol, net, dialog, nativeTheme, safeStorage, shell }=require('electron');
const path=require('node:path');
const fs=require('node:fs');
const {pathToFileURL}=require('node:url');
const {WorkspaceManager,validateAlias}=require('./workspaces.cjs');
const {GoogleAuth}=require('./google-auth.cjs');
const {GoogleSheets}=require('./google-sheets.cjs');
const {SyncEngine}=require('./sync-engine.cjs');

protocol.registerSchemesAsPrivileged([{scheme:'trackverse',privileges:{standard:true,secure:true,supportFetchAPI:true,corsEnabled:true,stream:true}}]);
const gotLock=app.requestSingleInstanceLock();
if(!gotLock) app.quit();
let win,store,manager,auth,sheets,sync;
function cloudState() {return {...auth.status(),activeId:manager.activeId,profiles:manager.list(),onboarded:store.getPreference('cloudOnboarded',false)};}
async function discoverTrackers() {
  const files=await sheets.listTrackers();
  for(const file of files) {
    const id=manager.add({...file,alias:file.alias.slice(0,60),account:auth.identity.id});
    await sync.sync(id,{force:true}).catch(()=>{});
  }
  return files;
}
async function createTracker(alias,copyCurrent) {
  validateAlias(alias);
  const file=await sheets.createTracker(alias);
  const id=manager.add({...file,account:auth.identity.id},copyCurrent);
  await sync.sync(id,{force:true}).catch(()=>{});
  manager.activate(id);return cloudState();
}
app.on('second-instance',()=>{if(win){if(win.isMinimized())win.restore();win.focus();}});
app.whenReady().then(async()=>{
  if(!gotLock)return;
  app.setAppUserModelId('app.trackverse.desktop');
  const dataPath=process.env.TRACKVERSE_DATA_DIR||app.getPath('userData');
  fs.mkdirSync(dataPath,{recursive:true});
  manager=new WorkspaceManager(dataPath);store=manager.root;
  auth=new GoogleAuth(dataPath,{safeStorage,openBrowser:url=>shell.openExternal(url)});
  const clientConfig=app.isPackaged?path.join(process.resourcesPath,'google-client.json'):path.join(app.getAppPath(),'.config','google-client.json');
  if(!auth.status().configured&&fs.existsSync(clientConfig))auth.configure(JSON.parse(fs.readFileSync(clientConfig,'utf8')));
  sheets=new GoogleSheets(auth);
  sync=new SyncEngine(manager,sheets);sync.start();
  if(auth.status().connected)sync.schedule(manager.activeId);
  nativeTheme.themeSource=store.getTheme();
  const root=path.join(app.getAppPath(),'build','web');
  protocol.handle('trackverse',(request)=>{
    const url=new URL(request.url);
    if(url.host!=='app')return new Response('Not found',{status:404});
    const target=path.resolve(root,'.'+decodeURIComponent(url.pathname==='/'?'/index.html':url.pathname));
    if(!target.startsWith(root+path.sep))return new Response('Forbidden',{status:403});
    return net.fetch(pathToFileURL(target).toString());
  });
  ipcMain.handle('trackverse:data',async(event,operation,payload)=>{
    if(!win||event.sender!==win.webContents||!event.senderFrame.url.startsWith('trackverse://app/'))throw Error('Untrusted sender');
    const workspaceId=manager.activeId,local=manager.store(workspaceId);
    switch(operation){
      case 'cloudState':return JSON.stringify(cloudState());
      case 'cloudOnboarded':store.setPreference('cloudOnboarded',true);return '{}';
      case 'googleSetup':{
        const selected=await dialog.showOpenDialog(win,{properties:['openFile'],filters:[{name:'Google OAuth Desktop configuration',extensions:['json']}]});
        if(!selected.canceled)auth.configure(JSON.parse(fs.readFileSync(selected.filePaths[0],'utf8')));
        return JSON.stringify(cloudState());
      }
      case 'googleSignIn':{
        await auth.signIn();const files=await discoverTrackers();
        if(!files.length)await createTracker('Personal habits',true);
        else manager.activate(`sheet-${files[0].sheetId}`);
        store.setPreference('cloudOnboarded',true);return JSON.stringify(cloudState());
      }
      case 'cancelGoogleSignIn':auth.cancel?.();return '{}';
      case 'googleSignOut':auth.signOut();return JSON.stringify(cloudState());
      case 'discoverTrackers':await discoverTrackers();return JSON.stringify(cloudState());
      case 'createTracker':{const data=JSON.parse(payload);return JSON.stringify(await createTracker(data.alias,!!data.copyCurrent));}
      case 'switchTracker':manager.activate(payload);sync.schedule(payload);return JSON.stringify(cloudState());
      case 'renameTracker':{const data=JSON.parse(payload);manager.rename(data.id,data.alias);manager.mutate(data.id,()=>{});sync.schedule(data.id);return JSON.stringify(cloudState());}
      case 'syncTracker':{const data=JSON.parse(payload||'{}');await sync.sync(data.id||workspaceId,{force:true,resolve:data.resolve});return JSON.stringify(cloudState());}
      case 'openTrackerSheet':{const p=manager.profile(payload||workspaceId);if(p?.sheet_id)await shell.openExternal(`https://docs.google.com/spreadsheets/d/${p.sheet_id}/edit`);return '{}';}
      case 'load':return JSON.stringify(manager.readActive());
      case 'getTheme':return store.getTheme();
      case 'setTheme':store.setTheme(payload);nativeTheme.themeSource=payload;return '{}';
      case 'checkIn':{const data=JSON.parse(payload);manager.assertRevision(data.workspaceId,data.revision);manager.mutate(workspaceId,db=>db.checkIn(data.id,data.day,data.complete));sync.schedule(workspaceId);return JSON.stringify(manager.readActive().revision);}
      case 'save':{const data=JSON.parse(payload);manager.assertRevision(data.workspaceId,data.revision);manager.mutate(workspaceId,db=>db.save(data.habits,true));sync.schedule(workspaceId);return JSON.stringify(manager.readActive().revision);}
      case 'loadMonths':return JSON.stringify(local.loadMonths());
      case 'saveMonths':{const data=JSON.parse(payload);manager.assertRevision(data.workspaceId,data.revision);manager.mutate(workspaceId,db=>db.saveMonths(data.months,true));sync.schedule(workspaceId);return JSON.stringify(manager.readActive().revision);}
      case 'restore':manager.mutate(workspaceId,db=>db.restore(JSON.parse(payload),true));sync.schedule(workspaceId);return JSON.stringify(local.loadMonths());
      case 'export':{
        const result=await dialog.showSaveDialog(win,{defaultPath:`TrackVerse-backup-${new Date().toISOString().slice(0,10)}.json`,filters:[{name:'TrackVerse backup',extensions:['json']}]});
        if(result.canceled)return 'null';
        fs.writeFileSync(result.filePath,JSON.stringify(manager.snapshot(workspaceId),null,2),'utf8');
        return 'true';
      }
      case 'import':{
        const result=await dialog.showOpenDialog(win,{properties:['openFile'],filters:[{name:'TrackVerse backup',extensions:['json']}]});
        if(result.canceled)return 'null';
        const stat=fs.statSync(result.filePaths[0]);
        if(stat.size>25*1024*1024)throw Error('Backup is too large');
        return fs.readFileSync(result.filePaths[0],'utf8');
      }
      default:throw Error('Unsupported operation');
    }
  });
  win=new BrowserWindow({width:1500,height:1020,minWidth:390,minHeight:650,title:'TrackVerse',backgroundColor:store.getTheme()==='dark'?'#121A19':'#F8F9FC',icon:path.join(app.getAppPath(),'assets','trackverse.ico'),autoHideMenuBar:true,show:false,webPreferences:{preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true}});
  win.webContents.setWindowOpenHandler(()=>({action:'deny'}));
  win.webContents.on('will-navigate',(event,url)=>{if(!url.startsWith('trackverse://app/'))event.preventDefault();});
  win.once('ready-to-show',()=>win.show());
  await win.loadURL('trackverse://app/');
}).catch(e=>{dialog.showErrorBox('TrackVerse could not start',String(e));app.quit();});
app.on('window-all-closed',()=>app.quit());
app.on('will-quit',()=>{sync?.stop();auth?.cancel?.();manager?.close();});
