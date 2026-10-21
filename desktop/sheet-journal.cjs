const crypto=require('node:crypto');
const zlib=require('node:zlib');
const MAGIC='TRACKVERSE_JOURNAL_V1';
const HISTORY='_TrackVerse History';
const COLUMNS=['Snapshot ID','Parent snapshots','Saved at (UTC)','Part','Part count','SHA256','Backup data (gzip/base64)'];
function encodeSnapshot(snapshot,parents=[],id=crypto.randomUUID()) {
  const json=JSON.stringify(snapshot);
  if(Buffer.byteLength(json)>8*1024*1024)throw Error('Tracker is too large for a single backup. Export a local backup.');
  const data=zlib.gzipSync(Buffer.from(json)).toString('base64');
  if(data.length>1500000)throw Error('Backup exceeds the safe Google Sheets request size.');
  const hash=crypto.createHash('sha256').update(json).digest('hex');
  const count=Math.max(1,Math.ceil(data.length/40000)),time=new Date().toISOString();
  return {id,parents,rows:Array.from({length:count},(_,i)=>[id,JSON.stringify(parents),time,String(i+1),String(count),hash,data.slice(i*40000,(i+1)*40000)])};
}
function readJournal(rows) {
  if(!rows.length)return {snapshots:[],heads:[]};
  if(rows[0]?.[0]!==MAGIC)throw Error('This spreadsheet does not contain a supported TrackVerse backup.');
  if(rows[1]?.[0]!==COLUMNS[0])throw Error('The backup history header is missing. Local data has not been changed.');
  const grouped=new Map();
  for(const row of rows.slice(2)) {
    if(!row[0])continue;
    const [id,parents,time,part,count,hash,data]=row;
    if(!/^[a-f\d-]{36}$/i.test(id)||!Number.isInteger(Number(part))||Number(part)<1||Number(count)<1||Number(count)>50||Number(part)>Number(count)||typeof data!=='string'||data.length>40000)throw Error('The sheet backup contains invalid records. Local data has not been changed.');
    if(!grouped.has(id))grouped.set(id,{id,parents:JSON.parse(parents),time,count:Number(count),hash,parts:new Map()});
    const record=grouped.get(id);
    if(record.count!==Number(count)||record.hash!==hash||JSON.stringify(record.parents)!==parents||record.parts.has(Number(part))&&record.parts.get(Number(part))!==data)throw Error('Conflicting backup records found.');
    record.parts.set(Number(part),data);
  }
  const snapshots=[];
  for(const r of grouped.values()) {
    if(r.parts.size!==r.count)throw Error('An incomplete backup was found in the sheet. Retry after checking the sheet.');
    const compressed=Buffer.from(Array.from({length:r.count},(_,i)=>r.parts.get(i+1)).join(''),'base64');
    const json=zlib.gunzipSync(compressed,{maxOutputLength:8*1024*1024}).toString('utf8');
    if(crypto.createHash('sha256').update(json).digest('hex')!==r.hash)throw Error('The sheet backup checksum is invalid. Local data has not been changed.');
    const snapshot=JSON.parse(json);
    if(snapshot.format!=='trackverse'||snapshot.version!==1||!Array.isArray(snapshot.habits)||!Array.isArray(snapshot.months)||!Array.isArray(r.parents)||r.parents.some(p=>typeof p!=='string'||p===r.id))throw Error('Invalid TrackVerse backup format.');
    snapshots.push({id:r.id,parents:r.parents,time:r.time,snapshot});
  }
  const ids=new Set(snapshots.map(s=>s.id));
  if(snapshots.some(s=>s.parents.some(p=>!ids.has(p))))throw Error('Backup history is missing a parent version. Restore a complete backup sheet.');
  const ancestors=new Set(snapshots.flatMap(s=>s.parents));
  const heads=snapshots.filter(s=>!ancestors.has(s.id));
  if(snapshots.length&&!heads.length)throw Error('Invalid cyclic backup history.');
  return {snapshots,heads};
}
module.exports={MAGIC,HISTORY,COLUMNS,encodeSnapshot,readJournal};
