const { app, BrowserWindow, ipcMain, protocol, net, dialog, nativeTheme, safeStorage, shell, Notification, Tray, Menu }=require('electron');
const path=require('node:path');
const fs=require('node:fs');
const {pathToFileURL}=require('node:url');
const {WorkspaceManager,validateAlias}=require('./workspaces.cjs');
const {GoogleAuth}=require('./google-auth.cjs');
const {GoogleSheets}=require('./google-sheets.cjs');
const {SyncEngine}=require('./sync-engine.cjs');
const {Pomodoro}=require('./pomodoro.cjs');
const {themes,themePalette}=require('./theme-palette.cjs');
const {keepFocusOnTop,setFocusLayout}=require('./focus-window.cjs');
const {HabitReminders}=require('./reminders.cjs');

protocol.registerSchemesAsPrivileged([{scheme:'trackverse',privileges:{standard:true,secure:true,supportFetchAPI:true,corsEnabled:true,stream:true}}]);
if(process.env.TRACKVERSE_DATA_DIR){const isolated=path.resolve(process.env.TRACKVERSE_DATA_DIR);fs.mkdirSync(isolated,{recursive:true});app.setPath('userData',isolated);}
const gotLock=app.requestSingleInstanceLock();
if(!gotLock) app.quit();
let win,store,manager,auth,sheets,sync,connectionTimer,pomodoro,timerWindow,focusInterval,online=false;
let reminders,tray,quitting=false;
const activeNotifications = new Map();
function showMainWindow(){if(win){win.show();if(win.isMinimized())win.restore();win.focus();}}
function hasReminders(){return manager.list().some(p=>manager.store(p.id).load().some(h=>h.reminder?.enabled));}
function notifyHabit(message){
  if(!Notification.isSupported())return false;
  const key=JSON.stringify([message.workspaceId,message.habitId]);
  activeNotifications.get(key)?.close();
  const notification=new Notification({title:`TrackVerse · ${message.title}`,body:message.body,icon:path.join(app.getAppPath(),'assets','trackverse.ico')});
  activeNotifications.set(key,notification);
  notification.on('click',showMainWindow);
  notification.on('close',()=>{if(activeNotifications.get(key)===notification)activeNotifications.delete(key);});
  notification.on('failed',(_,error)=>{console.error('Habit notification failed:',error);});
  notification.show();
  return true;
}
function refreshReminders(){
  // Withdraw an outstanding toast immediately when its target is reached or disabled.
  for(const [key,notification] of activeNotifications){
    const [id,habitId]=JSON.parse(key);
    const habit=manager.profile(id)&&manager.store(id).load().find(h=>h.id===habitId);
    const now=new Date(),day=`${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`;
    if(!habit?.reminder?.enabled||habit.checks.includes(day)){notification.close();activeNotifications.delete(key);}
  }
}
async function checkConnection(){try{const response=await net.fetch('https://www.gstatic.com/generate_204',{cache:'no-store',signal:AbortSignal.timeout(7000)});online=response.status===204;}catch(_){online=false;}}
function cloudState() {return {...auth.status(),online:online&&net.isOnline(),activeId:manager.activeId,profiles:manager.list(),onboarded:store.getPreference('cloudOnboarded',false)};}
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
app.on('second-instance',showMainWindow);
app.whenReady().then(async()=>{
  if(!gotLock)return;
  app.setAppUserModelId('app.trackverse.desktop');
  const dataPath=process.env.TRACKVERSE_DATA_DIR||app.getPath('userData');
  fs.mkdirSync(dataPath,{recursive:true});
  manager=new WorkspaceManager(dataPath);store=manager.root;
  manager.removeSamples();
  auth=new GoogleAuth(dataPath,{safeStorage,openBrowser:url=>shell.openExternal(url)});
  const clientConfig=app.isPackaged?path.join(process.resourcesPath,'google-client.json'):path.join(app.getAppPath(),'.config','google-client.json');
  if(!auth.status().configured&&fs.existsSync(clientConfig))auth.configure(JSON.parse(fs.readFileSync(clientConfig,'utf8')));
  sheets=new GoogleSheets(auth);
  checkConnection();connectionTimer=setInterval(checkConnection,15000);auth.refreshProfile();
  sync=new SyncEngine(manager,sheets);sync.start();
  pomodoro=new Pomodoro(manager,{onSave:id=>sync.schedule(id)});
  focusInterval=setInterval(()=>{try{pomodoro.checkpoint();}catch(e){pomodoro.state.running=false;pomodoro.persist();}},5000);
  if(auth.status().connected)sync.schedule(manager.activeId);
  nativeTheme.themeSource=store.getTheme();
  const root=path.join(app.getAppPath(),'build','web');
  protocol.handle('trackverse',(request)=>{
    const url=new URL(request.url);
    if(url.host!=='app')return new Response('Not found',{status:404});
    if(url.pathname==='/pomodoro.html')return net.fetch(pathToFileURL(path.join(__dirname,'pomodoro.html')).toString());
    const target=path.resolve(root,'.'+decodeURIComponent(url.pathname==='/'?'/index.html':url.pathname));
    if(!target.startsWith(root+path.sep))return new Response('Forbidden',{status:403});
    return net.fetch(pathToFileURL(target).toString());
  });
  ipcMain.handle('trackverse:data',async(event,operation,payload)=>{
    const fromTimer=timerWindow&&event.sender===timerWindow.webContents;
    if(!win||(!fromTimer&&event.sender!==win.webContents)||!event.senderFrame.url.startsWith('trackverse://app/'))throw Error('Untrusted sender');
    if(fromTimer&&!['timerState','timerAction','timerLayout','timerClose','getTheme'].includes(operation))throw Error('Unsupported widget operation');
    const workspaceId=manager.activeId,local=manager.store(workspaceId);
    switch(operation){
      case 'openPomodoro':{
        if(!timerWindow){timerWindow=new BrowserWindow({width:420,height:620,minWidth:420,minHeight:620,useContentSize:true,minimizable:false,maximizable:false,fullscreenable:false,frame:false,roundedCorners:true,hasShadow:true,title:'TrackVerse • Focus',icon:path.join(app.getAppPath(),'assets','trackverse.ico'),alwaysOnTop:true,resizable:false,autoHideMenuBar:true,backgroundColor:themePalette(store,nativeTheme.shouldUseDarkColors).palette.surface,webPreferences:{preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true}});keepFocusOnTop(timerWindow);timerWindow.setMenu(null);timerWindow.webContents.setWindowOpenHandler(()=>({action:'deny'}));timerWindow.webContents.on('will-navigate',(e,url)=>{if(url!=='trackverse://app/pomodoro.html')e.preventDefault();});timerWindow.on('closed',()=>{timerWindow=null;});await timerWindow.loadURL('trackverse://app/pomodoro.html');}
        timerWindow.show();timerWindow.focus();return '{}';
      }
      case 'timerState':return JSON.stringify({...themePalette(store,nativeTheme.shouldUseDarkColors),timer:pomodoro.read(),habits:local.load().map(h=>({id:h.id,name:h.name,color:h.color})),workspace:manager.profile(workspaceId).alias,typography:store.getPreference('typography',{step:0,family:'Inter'})});
      case 'timerAction':{const data=JSON.parse(payload);return JSON.stringify(pomodoro.action(data.action,data));}
      case 'timerLayout':{
        if(!fromTimer)throw Error('Widget only');
        const compact=JSON.parse(payload).compact;if(typeof compact!=='boolean')throw Error('Invalid timer layout');
        setFocusLayout(timerWindow,compact);
        return '{}';
      }
      case 'timerClose':if(fromTimer)timerWindow.close();return '{}';
      case 'focusStats':return JSON.stringify(local.loadFocusSessions());
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
      case 'deleteTracker':{
        if(pomodoro.state.workspaceId===payload&&pomodoro.state.session)throw Error('Finish the focus session before deleting this tracker.');
        const p=manager.profile(payload);
        if(!p?.sheet_id||p.account!==auth.identity?.id)throw Error('Connect the Google account that owns this tracker first.');
        if(sync.running.has(p.id))throw Error('This tracker is syncing. Try again when it finishes.');
        sync.running.add(p.id);
        try{await sheets.trashTracker(p.sheet_id);manager.remove(p.id);sync.queue.delete(p.id);}finally{sync.running.delete(p.id);}
        return JSON.stringify(cloudState());
      }
      case 'switchTracker':manager.activate(payload);sync.schedule(payload);return JSON.stringify(cloudState());
      case 'renameTracker':{const data=JSON.parse(payload);manager.rename(data.id,data.alias);manager.mutate(data.id,()=>{});sync.schedule(data.id);return JSON.stringify(cloudState());}
      case 'syncTracker':{const data=JSON.parse(payload||'{}');await sync.sync(data.id||workspaceId,{force:true,resolve:data.resolve});return JSON.stringify(cloudState());}
      case 'openTrackerSheet':{const p=manager.profile(payload||workspaceId);if(p?.sheet_id)await shell.openExternal(`https://docs.google.com/spreadsheets/d/${p.sheet_id}/edit`);return '{}';}
      case 'load':return JSON.stringify(manager.readActive());
      case 'getTheme':return store.getTheme();
      case 'getThemePreset':return store.getPreference('themePreset','TrackVerse');
      case 'setThemePreset':if(!themes.some(t=>t.name===payload))throw Error('Invalid theme');store.setPreference('themePreset',payload);return '{}';
      case 'getTypography':return JSON.stringify(store.getPreference('typography',{step:0,family:'Inter'}));
      case 'setTypography':{const value=JSON.parse(payload);if(!Number.isInteger(value.step)||value.step< -2||value.step>4||!['Inter','Lora','JetBrains Mono'].includes(value.family))throw Error('Invalid font preference');store.setPreference('typography',value);return '{}';}
      case 'savePlan':{
        const data=JSON.parse(payload);manager.assertRevision(data.workspaceId,data.revision);
        manager.mutate(workspaceId,db=>db.savePlan(data.habits,data.months,true));sync.schedule(workspaceId);return JSON.stringify(manager.readActive().revision);
      }
      case 'setTheme':store.setTheme(payload);nativeTheme.themeSource=payload;return '{}';
      case 'setDailyCount':{const data=JSON.parse(payload);manager.assertRevision(data.workspaceId,data.revision);manager.mutate(workspaceId,db=>db.setCount(data.id,data.day,data.count));refreshReminders();sync.schedule(workspaceId);return JSON.stringify(manager.readActive().revision);}
      case 'checkIn':{const data=JSON.parse(payload);manager.assertRevision(data.workspaceId,data.revision);manager.mutate(workspaceId,db=>db.checkIn(data.id,data.day,data.complete));sync.schedule(workspaceId);return JSON.stringify(manager.readActive().revision);}
      case 'save':{const data=JSON.parse(payload);manager.assertRevision(data.workspaceId,data.revision);manager.mutate(workspaceId,db=>db.save(data.habits,true));refreshReminders();sync.schedule(workspaceId);return JSON.stringify(manager.readActive().revision);}
      case 'loadMonths':return JSON.stringify(local.loadMonths());
      case 'saveMonths':{const data=JSON.parse(payload);manager.assertRevision(data.workspaceId,data.revision);manager.mutate(workspaceId,db=>db.savePlan(db.load(),data.months,true));sync.schedule(workspaceId);return JSON.stringify(manager.readActive().revision);}
      case 'restore':if(pomodoro.state.session&&pomodoro.state.workspaceId===workspaceId)throw Error('Finish the focus session before restoring a backup.');manager.mutate(workspaceId,db=>db.restore(JSON.parse(payload),true));sync.schedule(workspaceId);return JSON.stringify(local.loadMonths());
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
  win=new BrowserWindow({width:1500,height:1020,minWidth:390,minHeight:650,title:'TrackVerse',backgroundColor:themePalette(store,nativeTheme.shouldUseDarkColors).palette.background,icon:path.join(app.getAppPath(),'assets','trackverse.ico'),autoHideMenuBar:true,show:false,webPreferences:{preload:path.join(__dirname,'preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true}});
  win.webContents.setWindowOpenHandler(()=>({action:'deny'}));
  win.webContents.on('will-navigate',(event,url)=>{if(!url.startsWith('trackverse://app/'))event.preventDefault();});
  win.once('ready-to-show',()=>win.show());
  tray=new Tray(path.join(app.getAppPath(),'assets','trackverse.ico'));
  tray.setToolTip('TrackVerse · Habit reminders');
  tray.setContextMenu(Menu.buildFromTemplate([{label:'Open TrackVerse',click:showMainWindow},{type:'separator'},{label:'Quit TrackVerse (stops reminders)',click:()=>app.quit()}]));
  tray.on('double-click',showMainWindow);
  win.on('close',event=>{
    if(!quitting&&hasReminders()){event.preventDefault();win.hide();timerWindow?.hide();}
  });
  await win.loadURL('trackverse://app/');
  reminders=new HabitReminders(manager,{notify:notifyHabit});reminders.start();
}).catch(e=>{dialog.showErrorBox('TrackVerse could not start',String(e));app.quit();});
app.on('window-all-closed',()=>app.quit());
app.on('before-quit',()=>{quitting=true;reminders?.stop();if(pomodoro){pomodoro.checkpoint();pomodoro.state.running=false;pomodoro.persist();}});
app.on('will-quit',()=>{clearInterval(connectionTimer);clearInterval(focusInterval);for(const notification of activeNotifications.values())notification.close();tray?.destroy();sync?.stop();auth?.cancel?.();manager?.close();});
