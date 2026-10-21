const fs=require('node:fs');
const path=require('node:path');
const {TrackVerseDatabase}=require('./database.cjs');

class WorkspaceManager {
  constructor(directory) {
    this.directory=directory;
    fs.mkdirSync(path.join(directory,'workspaces'),{recursive:true});
    this.root=new TrackVerseDatabase(path.join(directory,'trackverse.sqlite3'));
    this.root.db.exec('CREATE TABLE IF NOT EXISTS workspaces (id TEXT PRIMARY KEY, alias TEXT NOT NULL, sheet_id TEXT UNIQUE, url TEXT, account TEXT)');
    this.root.db.prepare("INSERT OR IGNORE INTO workspaces VALUES ('local','Personal habits',NULL,NULL,NULL)").run();
    this.stores=new Map([['local',this.root]]);
    this.activeId=this.root.getPreference('activeWorkspace','local');
    if(!this.profile(this.activeId))this.activeId='local';
  }
  profile(id) {return this.root.db.prepare('SELECT * FROM workspaces WHERE id = ?').get(id);}
  store(id=this.activeId) {
    if(!this.profile(id))throw Error('Tracker not found');
    if(!this.stores.has(id))this.stores.set(id,new TrackVerseDatabase(path.join(this.directory,'workspaces',`${id}.sqlite3`)));
    return this.stores.get(id);
  }
  list() {return this.root.db.prepare('SELECT * FROM workspaces ORDER BY rowid').all().map(p=>{const s=this.store(p.id).getPreference('syncState',{});return {...p,dirty:s.dirty||false,status:s.status||(p.sheet_id?'pending':'local'),lastSync:s.lastSync||null,revision:s.revision||0,sharing:s.sharing||'Private · Google account only',error:s.error||null};});}
  activate(id) {this.store(id);this.activeId=id;this.root.setPreference('activeWorkspace',id);return this.snapshot(id);}
  snapshot(id=this.activeId) {const db=this.store(id);return {format:'trackverse',version:1,alias:this.profile(id).alias,habits:db.load(),months:db.loadMonths()};}
  readActive() {return {...this.snapshot(),workspaceId:this.activeId,revision:this.store().getPreference('syncState',{}).revision||0};}
  assertRevision(id,revision) {if(id!==this.activeId||revision!==(this.store(id).getPreference('syncState',{}).revision||0))throw Error('This tracker changed while you were editing. Refresh and try again.');}
  add({sheetId,alias,url,account},copyCurrent=false) {
    if(!/^[a-zA-Z0-9_-]{15,150}$/.test(sheetId))throw Error('Invalid Google spreadsheet');
    const name=validateAlias(alias),existing=this.root.db.prepare('SELECT * FROM workspaces WHERE sheet_id = ?').get(sheetId);
    if(existing)return existing.id;
    const id=`sheet-${sheetId}`;
    const copied=copyCurrent?this.snapshot():null;
    this.root.db.prepare('INSERT INTO workspaces VALUES (?,?,?,?,?)').run(id,name,sheetId,`https://docs.google.com/spreadsheets/d/${sheetId}/edit`,account);
    if(copied)this.mutate(id,db=>db.restore(copied,true));
    return id;
  }
  rename(id,alias) {this.root.db.prepare('UPDATE workspaces SET alias = ? WHERE id = ?').run(validateAlias(alias),id);}
  mutate(id,action) {
    const db=this.store(id);db.db.exec('BEGIN IMMEDIATE');
    try {action(db);const state=db.getPreference('syncState',{});db.setPreference('syncState',{...state,revision:(state.revision||0)+1,dirty:true,status:this.profile(id).sheet_id?'pending':'local',error:null});db.db.exec('COMMIT');}
    catch(e){db.db.exec('ROLLBACK');throw e;}
  }
  updateSync(id,patch) {const db=this.store(id);db.setPreference('syncState',{...db.getPreference('syncState',{}),...patch});}
  applyRemote(id,snapshot,remoteId) {
    if(snapshot.alias)validateAlias(snapshot.alias);
    const db=this.store(id);db.db.exec('BEGIN IMMEDIATE');
    try {db.restore(snapshot,true);const old=db.getPreference('syncState',{});db.setPreference('syncState',{...old,revision:(old.revision||0)+1,dirty:false,status:'synced',base:remoteId,lastSync:new Date().toISOString(),error:null,pending:null});db.db.exec('COMMIT');}
    catch(e){db.db.exec('ROLLBACK');throw e;}
    if(snapshot.alias)this.rename(id,snapshot.alias);
  }
  markSynced(id,revision,base) {const state=this.store(id).getPreference('syncState',{});this.updateSync(id,{base,lastSync:new Date().toISOString(),dirty:state.revision!==revision,status:state.revision!==revision?'pending':'synced',error:null,pending:null});}
  remove(id) {
    if(id==='local'||!this.profile(id)?.sheet_id)throw Error('Only Google trackers can be deleted here.');
    // Archive the database on disk rather than destroying offline records.
    this.stores.get(id)?.close();this.stores.delete(id);
    const file=path.join(this.directory,'workspaces',`${id}.sqlite3`);
    if(fs.existsSync(file)){const archive=path.join(this.directory,'deleted-trackers');fs.mkdirSync(archive,{recursive:true});fs.renameSync(file,path.join(archive,`${id}-${Date.now()}.sqlite3`));}
    if(this.activeId===id)this.activate('local');
    this.root.db.prepare('DELETE FROM workspaces WHERE id = ?').run(id);
  }
  close() {for(const db of this.stores.values())db.close();}
}
function validateAlias(value) {if(typeof value!=='string'||!value.trim()||value.trim().length>60)throw Error('Give the tracker a name of 1–60 characters.');return value.trim();}
module.exports={WorkspaceManager,validateAlias};
