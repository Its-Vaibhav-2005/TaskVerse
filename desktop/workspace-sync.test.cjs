const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');const os=require('node:os');const path=require('node:path');
const {WorkspaceManager}=require('./workspaces.cjs');
const {SyncEngine}=require('./sync-engine.cjs');
const {MAGIC,COLUMNS,encodeSnapshot,readJournal}=require('./sheet-journal.cjs');
const sheets=[
  ['1gpx_D0suqdeWWaScz5y10TK1mS6Keq-Y7XuPOGdi9lQ','Regular'],
  ['1av5KTWG1HJFAAXuuvVpnqgDQgrXhvVOQlCri2Z-3rEE','Exam prep'],
  ['1xc5L7TdRtX09s3GFUe7NaBNdSQ_SdRCLbxehN8eCm30','Fitness']
];
const habit=(id,name)=>({id,name,category:'Wellness',color:0,icon:0,created:'2026-10-01',weekdays:[1,2,3,4,5,6,7],checks:['2026-10-21']});
class FakeGoogleSheets {
  constructor(){this.data=new Map(sheets.map(([id])=>[id,[[MAGIC],COLUMNS]]));this.offline=false;this.denied=false;}
  async inspect(){if(this.offline)throw Error('Offline');if(this.denied)throw Error('Permission denied');return {sharing:'Private · Google account only'};}
  async read(id){if(this.offline)throw Error('Offline');return structuredClone(this.data.get(id));}
  async append(id,rows){if(this.offline)throw Error('Offline');this.data.get(id).push(...structuredClone(rows));if(this.afterAppend){const cb=this.afterAppend;this.afterAppend=null;cb();}}
  async updateSummary(){}
}
function fixture(){const directory=fs.mkdtempSync(path.join(os.tmpdir(),'trackverse-sync-'));const manager=new WorkspaceManager(directory);const remote=new FakeGoogleSheets();const engine=new SyncEngine(manager,remote);const ids=sheets.map(([sheetId,alias])=>manager.add({sheetId,alias,account:'test-account'}));return {directory,manager,remote,engine,ids,close(){engine.stop();manager.close();fs.rmSync(directory,{recursive:true,force:true});}};}
test('Three tracker workspaces stay isolated and recover into a fresh installation',async()=>{
  const f=fixture();let fresh,dir;
  try {
    for(let i=0;i<3;i++) {f.manager.activate(f.ids[i]);f.manager.mutate(f.ids[i],db=>{db.save([habit(`habit-${i}`,['Read daily','Study mathematics','Morning run'][i])],true);db.saveMonths(['2026-10-01','2026-11-01'],true);});await f.engine.sync(f.ids[i],{force:true});}
    assert.equal(f.manager.store('local').load().length,0);
    f.manager.activate(f.ids[0]);assert.equal(f.manager.store().load()[0].name,'Read daily');
    f.manager.activate(f.ids[1]);assert.equal(f.manager.store().load()[0].name,'Study mathematics');
    f.manager.activate(f.ids[2]);assert.equal(f.manager.store().load()[0].name,'Morning run');
    dir=fs.mkdtempSync(path.join(os.tmpdir(),'trackverse-reinstall-'));fresh=new WorkspaceManager(dir);const recovery=new SyncEngine(fresh,f.remote);
    for(let i=0;i<3;i++){const id=fresh.add({sheetId:sheets[i][0],alias:'Recovered',account:'test-account'});await recovery.sync(id,{force:true});assert.deepEqual(fresh.snapshot(id),f.manager.snapshot(f.ids[i]));assert.equal(fresh.list().find(p=>p.id===id).status,'synced');}
    recovery.stop();
  } finally {fresh?.close();if(dir)fs.rmSync(dir,{recursive:true,force:true});f.close();}
});
test('Offline changes remain durably queued and retry after restart',async()=>{
  const f=fixture();let reopened;
  try {
    const id=f.ids[0];f.manager.mutate(id,db=>db.save([habit('walk','Walk offline')],true));f.remote.offline=true;
    await assert.rejects(f.engine.sync(id,{force:true}),/Offline/);
    assert.equal(f.manager.list().find(p=>p.id===id).dirty,true);
    f.engine.stop();f.manager.close();
    reopened=new WorkspaceManager(f.directory);assert.equal(reopened.snapshot(id).habits[0].name,'Walk offline');
    assert.equal(reopened.list().find(p=>p.id===id).dirty,true);
    f.remote.offline=false;const engine=new SyncEngine(reopened,f.remote);await engine.sync(id,{force:true});
    assert.equal(reopened.list().find(p=>p.id===id).dirty,false);assert.equal(readJournal(f.remote.data.get(sheets[0][0])).heads[0].snapshot.habits[0].name,'Walk offline');engine.stop();
  }finally {if(reopened){reopened.close();fs.rmSync(f.directory,{recursive:true,force:true});}else f.close();}
});
test('An in-flight backup cannot mark newer local edits as synced',async()=>{
  const f=fixture();try {
    const id=f.ids[0];f.manager.mutate(id,db=>db.save([habit('h','First version')],true));
    f.remote.afterAppend=()=>f.manager.mutate(id,db=>db.save([habit('h','Edited during upload')],true));
    await f.engine.sync(id,{force:true});assert.equal(f.manager.list().find(p=>p.id===id).dirty,true);
    await f.engine.sync(id,{force:true});const history=readJournal(f.remote.data.get(sheets[0][0]));assert.equal(history.snapshots.length,2);assert.equal(history.heads[0].snapshot.habits[0].name,'Edited during upload');assert.equal(f.manager.list().find(p=>p.id===id).dirty,false);
  }finally {f.close();}
});
test('Concurrent devices create a conflict instead of silently losing either version',async()=>{
  const f=fixture();try {
    const id=f.ids[0];f.manager.mutate(id,db=>db.save([habit('h','Initial')],true));await f.engine.sync(id,{force:true});
    const base=readJournal(f.remote.data.get(sheets[0][0])).heads[0];
    const another={...base.snapshot,habits:[habit('h','Other device')]};f.remote.data.get(sheets[0][0]).push(...encodeSnapshot(another,[base.id]).rows);
    f.manager.mutate(id,db=>db.save([habit('h','This device')],true));await f.engine.sync(id,{force:true});
    assert.equal(f.manager.list().find(p=>p.id===id).status,'conflict');assert.equal(f.manager.snapshot(id).habits[0].name,'This device');
    await f.engine.sync(id,{force:true,resolve:'local'});const journal=readJournal(f.remote.data.get(sheets[0][0]));assert.equal(journal.snapshots.length,3);assert.equal(journal.heads.length,1);assert.equal(journal.heads[0].snapshot.habits[0].name,'This device');
  }finally{f.close();}
});
test('Permission loss, invalid backup data and stale workspace writes do not erase SQLite data',async()=>{
  const f=fixture();try {
    const id=f.ids[0];f.manager.activate(id);f.manager.mutate(id,db=>db.save([habit('h','Keep me')],true));const stale=f.manager.readActive();
    f.remote.denied=true;await assert.rejects(f.engine.sync(id,{force:true}),/Permission denied/);assert.equal(f.manager.snapshot(id).habits[0].name,'Keep me');
    f.remote.denied=false;f.remote.data.set(sheets[0][0],[['Not a TrackVerse backup']]);await assert.rejects(f.engine.sync(id,{force:true}),/supported TrackVerse/);assert.equal(f.manager.snapshot(id).habits[0].name,'Keep me');
    f.manager.mutate(id,db=>db.saveMonths(['2026-10-01'],true));assert.throws(()=>f.manager.assertRevision(id,stale.revision),/changed while/);
    f.manager.activate(f.ids[1]);assert.throws(()=>f.manager.assertRevision(id,f.manager.store(id).getPreference('syncState').revision),/changed while/);
  }finally{f.close();}
});
test('Snapshot checksum, schema and incomplete-row validation reject damaged backups',()=>{
  const snapshot={format:'trackverse',version:1,habits:[habit('h','Read')],months:['2026-10-01']};const encoded=encodeSnapshot(snapshot);
  assert.deepEqual(readJournal([[MAGIC],COLUMNS,...encoded.rows]).heads[0].snapshot,snapshot);
  const broken=structuredClone(encoded.rows);broken[0][5]='0'.repeat(64);assert.throws(()=>readJournal([[MAGIC],COLUMNS,...broken]),/checksum/);
  const missing=structuredClone(encoded.rows);missing[0][4]='2';assert.throws(()=>readJournal([[MAGIC],COLUMNS,...missing]),/incomplete/);
});
