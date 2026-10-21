// Run with Electron to check the real Google API using the locally encrypted sign-in.
// Creates one disposable tracker spreadsheet and moves only that new file to Trash.
const {app,safeStorage}=require('electron');
const path=require('node:path'),fs=require('node:fs');
const {GoogleAuth}=require('../desktop/google-auth.cjs');
const {GoogleSheets}=require('../desktop/google-sheets.cjs');
app.setName('trackverse');app.setPath('userData',path.join(app.getPath('appData'),'trackverse'));
app.whenReady().then(async()=>{
  const dir=process.env.TRACKVERSE_DATA_DIR;if(!dir)throw Error('TRACKVERSE_DATA_DIR is required');
  const auth=new GoogleAuth(dir,{safeStorage,openBrowser:async()=>{throw Error('Use the app to sign in first.');}});
  if(!auth.status().connected)throw Error('Sign in to TrackVerse before running this check.');
  const remote=new GoogleSheets(auth);let created;
  try {
    created=await remote.createTracker('Feature check · temporary');
    await remote.updateSummary(created.sheetId,{alias:'Feature check',months:['2028-02-01','2028-03-01'],habits:[{name:'Sample habit',category:'Testing',created:'2028-02-28',weekdays:[1,2,3,4,5,6,7],checks:['2028-02-29']}]},'Feature check');
    const metadata=await remote.request(`https://sheets.googleapis.com/v4/spreadsheets/${created.sheetId}?fields=sheets(properties(title),charts(chartId))`);
    const months=metadata.sheets.filter(s=>['Feb 2028','Mar 2028'].includes(s.properties.title));
    if(months.length!==2||months.some(s=>s.charts?.length!==1))throw Error('Month tabs or charts did not match.');
    const check=await remote.request(`https://sheets.googleapis.com/v4/spreadsheets/${created.sheetId}/values/${encodeURIComponent("'Feb 2028'!AE4:AF4")}?valueRenderOption=UNFORMATTED_VALUE`);
    if(check.values?.[0]?.[0]!==true||check.values[0][1]!==0.5)throw Error('Leap-day check-in or completion formula failed.');
    await remote.updateSummary(created.sheetId,{alias:'Feature check',months:['2028-02-01','2028-03-01'],habits:[]},'Feature check');
    const again=await remote.request(`https://sheets.googleapis.com/v4/spreadsheets/${created.sheetId}?fields=sheets(properties(title),charts(chartId))`);
    if(again.sheets.filter(s=>['Feb 2028','Mar 2028'].includes(s.properties.title)).some(s=>s.charts.length!==1))throw Error('Repeated sync duplicated a chart.');
    await auth.refreshProfile();
    fs.writeFileSync(path.join(dir,'review','cloud-smoke-result.json'),JSON.stringify({passed:true,monthTabs:months.map(s=>s.properties.title),charts:2,completionFormula:true,repeatedSync:true,profilePhoto:!!auth.identity?.photo,checkedAt:new Date().toISOString()}));
  } finally {if(created)await remote.trashTracker(created.sheetId);}
  app.quit();
}).catch(error=>{console.error(error.message);app.exit(1);});
