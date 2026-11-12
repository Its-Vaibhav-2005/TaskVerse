const {encodeSnapshot,readJournal}=require('./sheet-journal.cjs');
const {mergeSnapshot}=require('./merge-snapshot.cjs');
class SyncEngine {
  constructor(manager,remote,{onChange=()=>{},isOnline=()=>true}={}) {this.manager=manager;this.remote=remote;this.onChange=onChange;this.isOnline=isOnline;this.running=new Set();this.closed=false;this.lastTry=new Map();this.backoff=new Map();this.queue=new Set();}
  start() {this.closed=false;this.tick().catch(()=>{});this.plan();}
  plan() {clearTimeout(this.timer);if(!this.closed)this.timer=setTimeout(async()=>{try{await this.tick();}catch{}finally{this.plan();}},60000+Math.floor(Math.random()*120001));}
  wake() {this.lastTry.clear();this.backoff.clear();return this.tick();}
  stop() {this.closed=true;clearInterval(this.timer);clearTimeout(this.debounce);}
  schedule(id) {this.queue.add(id);clearTimeout(this.debounce);this.debounce=setTimeout(()=>this.tick().catch(()=>{}),1500);}
  async tick() {
    if(this.closed||!this.isOnline())return;
    if(this.remote.auth&&!this.remote.auth.status().connected)return;
    const profiles=this.manager.list().filter(p=>p.sheet_id&&(!this.remote.auth||p.account===this.remote.auth.status().identity?.id));
    for(const p of profiles) {
      if(this.closed)return;
      const delay=this.backoff.get(p.id)||15000;
      if(Date.now()-(this.lastTry.get(p.id)||0)<delay)continue;
      await this.sync(p.id).catch(()=>{});
    }
  }
  async sync(id,{resolve=null,force=false}={}) {
    const profile=this.manager.profile(id);
    if(!profile?.sheet_id)return;
    if(this.remote.auth&&profile.account!==this.remote.auth.status().identity?.id) {this.manager.updateSync(id,{status:'error',error:'Reconnect the Google account that owns this tracker. Local changes remain saved.'});return;}
    if(this.running.has(id))return;
    if(!force&&Date.now()-(this.lastTry.get(id)||0)<15000)return;
    this.running.add(id);this.lastTry.set(id,Date.now());this.queue.delete(id);
    this.manager.updateSync(id,{status:'syncing',error:null});this.onChange(id);
    const db=this.manager.store(id);
    try {
      const permission=await this.remote.inspect(profile.sheet_id);
      this.manager.updateSync(id,{sharing:permission.sharing});
      const history=readJournal(await this.remote.read(profile.sheet_id));
      let local=db.getPreference('syncState',{});
      if(resolve==='remote') {
        if(history.heads.length!==1)throw Error('Several devices created separate versions. Keep this tracker as a new version or recover a backup manually.');
        this.manager.applyRemote(id,history.heads[0].snapshot,history.heads[0].id);await this.remote.updateSummary?.(profile.sheet_id,this.manager.snapshot(id),this.manager.profile(id).alias);return;
      }
      // Recover uncertain network writes by snapshot ID, without appending duplicate backups.
      if(local.pending&&history.snapshots.some(s=>s.id===local.pending.id)) {
        this.manager.markSynced(id,local.pending.revision,local.pending.id);local=db.getPreference('syncState',{});
      }
      const head=history.heads[0];
      if(history.heads.length===1&&local.dirty&&head.id!==local.base&&resolve!=='local') {
        const base=history.snapshots.find(s=>s.id===local.base);
        const merged=mergeSnapshot(base?.snapshot,this.manager.snapshot(id),head.snapshot);
        if(merged) {
          this.manager.mutate(id,store=>store.restore(merged,true));
          this.manager.rename(id,merged.alias);
          this.manager.updateSync(id,{base:head.id,pending:null});
          local=db.getPreference('syncState',{});
        }
      }
      if((history.heads.length>1||local.dirty&&head&&head.id!==local.base)&&resolve!=='local') {
        this.manager.updateSync(id,{status:'conflict',error:'This tracker changed on another device. Choose which version to continue with; both versions remain backed up.'});return;
      }
      if(resolve!=='local'&&!local.dirty&&head&&head.id!==local.base) {this.manager.applyRemote(id,head.snapshot,head.id);await this.remote.updateSummary?.(profile.sheet_id,this.manager.snapshot(id),this.manager.profile(id).alias);return;}
      if(resolve!=='local'&&!local.dirty&&head) {this.manager.updateSync(id,{status:'synced',lastSync:new Date().toISOString(),error:null});return;}
      const snapshot=this.manager.snapshot(id),revision=local.revision||0;
      let pending=local.pending;
      if(!pending||pending.revision!==revision||resolve==='local') {
        const encoded=encodeSnapshot(snapshot,history.heads.map(h=>h.id));
        pending={...encoded,revision};this.manager.updateSync(id,{pending});
      }
      await this.remote.append(profile.sheet_id,pending.rows);
      // Never erase another device's snapshot: append-only history retains every version.
      const verified=readJournal(await this.remote.read(profile.sheet_id));
      if(!verified.snapshots.some(s=>s.id===pending.id))throw Error('Google has not confirmed the backup yet. It will be checked again automatically.');
      this.manager.markSynced(id,revision,pending.id);
      if(verified.heads.length>1)this.manager.updateSync(id,{status:'conflict',error:'A second device synced at the same time. All versions are kept; choose a version to continue.'});
      else await this.remote.updateSummary?.(profile.sheet_id,snapshot,profile.alias);
      this.backoff.delete(id);
    } catch(e) {
      this.backoff.set(id,Math.min((this.backoff.get(id)||15000)*2,300000));
      this.manager.updateSync(id,{status:'error',error:e.message});throw e;
    } finally {this.running.delete(id);if(db.getPreference('syncState',{}).status==='synced')this.backoff.delete(id);this.onChange(id);}
  }
}
module.exports={SyncEngine};
