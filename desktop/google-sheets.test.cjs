const {test}=require('node:test');const assert=require('node:assert/strict');
const {GoogleSheets}=require('./google-sheets.cjs');const {SCOPES}=require('./google-auth.cjs');
test('Google uses per-file permissions and automatically creates tracker sheets',async()=>{
  assert.ok(SCOPES.includes('https://www.googleapis.com/auth/drive.file'));assert.ok(!SCOPES.includes('https://www.googleapis.com/auth/drive'));
  const calls=[];const sheets=new GoogleSheets({token:async()=>'test-token'},{fetchImpl:async(url,options)=>{calls.push({url,options});return {ok:true,status:200,json:async()=>calls.length===1?{spreadsheetId:'test-sheet-id-12345',spreadsheetUrl:'https://docs.google.com/spreadsheets/d/test-sheet-id-12345/edit'}:{}};}});
  const result=await sheets.createTracker('Exam prep');assert.equal(result.alias,'Exam prep');assert.equal(calls.length,3);
  assert.equal(JSON.parse(calls[0].options.body).properties.title,'TrackVerse · Exam prep');
  assert.deepEqual(JSON.parse(calls[1].options.body).appProperties,{trackverse:'1',alias:'Exam prep'});
  assert.ok(!calls.some(c=>c.url.includes('/permissions')),'Automatic OAuth backups do not require public sharing.');
});
test('Read-only permissions and missing app ownership are rejected',async()=>{
  let data={capabilities:{canEdit:false},appProperties:{trackverse:'1'}};
  const sheets=new GoogleSheets({token:async()=>'test-token'},{fetchImpl:async()=>({ok:true,status:200,json:async()=>data})});
  await assert.rejects(sheets.inspect('test-sheet-id-12345'),/edit permission/);
  data={capabilities:{canEdit:true},appProperties:{}};await assert.rejects(sheets.inspect('test-sheet-id-12345'),/created by TrackVerse/);
  data={capabilities:{canEdit:true},appProperties:{trackverse:'1'},permissions:[{type:'user',role:'owner'}]};assert.equal((await sheets.inspect('test-sheet-id-12345')).sharing,'Private · Google account only');
});
