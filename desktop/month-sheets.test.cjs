const {test}=require('node:test');const assert=require('node:assert/strict');
const {monthRequests}=require('./month-sheets.cjs');const {GoogleSheets}=require('./google-sheets.cjs');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {WorkspaceManager}=require('./workspaces.cjs');
test('Month sheets mirror leap-day check-ins, scheduled days, formulas and one chart per month',()=>{
  const snapshot={alias:'Exam prep',months:['2028-02-01','2028-03-01'],habits:[{name:'Study',category:'Learning',created:'2028-02-28',weekdays:[1,2,3,4,5,6,7],checks:['2028-02-29']}]};
  const requests=monthRequests(snapshot,{sheets:[{properties:{sheetId:0,title:'Habits'}}]});
  assert.deepEqual(requests.filter(r=>r.addSheet).map(r=>r.addSheet.properties.title),['Feb 2028','Mar 2028']);
  const feb=requests.find(r=>r.updateCells?.range.sheetId===1).updateCells.rows;
  assert.equal(feb[3].values[29].userEnteredValue.boolValue,false); // February 28
  assert.equal(feb[3].values[30].userEnteredValue.boolValue,true); // Leap day
  assert.equal(feb[3].values[2].userEnteredValue,undefined); // Before creation
  assert.match(feb[3].values.at(-1).userEnteredValue.formulaValue,/COUNTIF/);
  assert.equal(requests.filter(r=>r.addChart).length,2);
  const repeated=monthRequests(snapshot,{sheets:[{properties:{sheetId:1,title:'Feb 2028',gridProperties:{rowCount:100,columnCount:32}},charts:[{chartId:1}]},{properties:{sheetId:2,title:'Mar 2028',gridProperties:{rowCount:100,columnCount:34}},charts:[{chartId:2}]}]});
  assert.equal(repeated.filter(r=>r.addSheet||r.addChart).length,0);
});
test('Deleting an app-created spreadsheet uses recoverable Drive Trash, never permanent deletion',async()=>{
  const calls=[];const sheets=new GoogleSheets({token:async()=>'test'},{fetchImpl:async(url,options)=>{calls.push({url,options});return {ok:true,status:200,json:async()=>({capabilities:{canEdit:true},appProperties:{trackverse:'1'}})};}});
  await sheets.trashTracker('test-sheet-id-12345');assert.equal(calls[1].options.method,'PATCH');assert.deepEqual(JSON.parse(calls[1].options.body),{trashed:true});assert.ok(!calls.some(c=>c.options.method==='DELETE'));
});
test('Deleting the active tracker falls back locally, archives its SQLite and preserves other trackers',()=>{
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'trackverse-delete-'));const manager=new WorkspaceManager(dir);
  try{const a=manager.add({sheetId:'test-sheet-one-12345',alias:'Exam',account:'test'},true),b=manager.add({sheetId:'test-sheet-two-12345',alias:'Regular',account:'test'},true);manager.activate(a);manager.remove(a);assert.equal(manager.activeId,'local');assert.equal(manager.profile(a),undefined);assert.ok(manager.profile(b));assert.equal(fs.readdirSync(path.join(dir,'deleted-trackers')).length,1);assert.throws(()=>manager.remove('local'));}finally{manager.close();fs.rmSync(dir,{recursive:true,force:true});}
});
