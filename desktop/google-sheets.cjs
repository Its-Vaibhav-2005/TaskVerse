const {MAGIC,HISTORY,COLUMNS}=require('./sheet-journal.cjs');
const SHEETS='https://sheets.googleapis.com/v4/spreadsheets';
const DRIVE='https://www.googleapis.com/drive/v3/files';
const {monthRequests}=require('./month-sheets.cjs');
class GoogleSheets {
  constructor(auth,{fetchImpl=fetch}={}) {this.auth=auth;this.fetch=fetchImpl;this.requests=[];}
  async request(url,{method='GET',body}={}) {
    const token=await this.auth.token();
    this.requests=this.requests.filter(t=>Date.now()-t<60000);
    if(this.requests.length>=40)throw Error('Google sync is cooling down to stay within free limits. It will retry automatically.');
    this.requests.push(Date.now());
    let response;
    try {response=await this.fetch(url,{method,headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(20000)});}
    catch(_){throw Error('Offline or Google is unreachable. Your changes are saved locally and will retry.');}
    if(!response.ok) {
      if(response.status===401)throw Error('Reconnect your Google account to continue syncing.');
      if(response.status===403)throw Error('Google denied access. Check that Sheets and Drive APIs are enabled and the signed-in account can edit this tracker.');
      if(response.status===404)throw Error('This tracker sheet was removed or is no longer accessible. Local data is still available.');
      if(response.status===429||response.status>=500)throw Error('Google is temporarily busy. Sync will retry automatically.');
      throw Error(`Google sync failed (${response.status}). Local data is safe.`);
    }
    return response.status===204?{}:response.json();
  }
  async listTrackers() {
    let files=[],page='';
    do {
      const query=new URLSearchParams({q:"trashed = false and mimeType = 'application/vnd.google-apps.spreadsheet' and appProperties has { key='trackverse' and value='1' }",fields:'nextPageToken,files(id,name,webViewLink,appProperties)',pageSize:'100',...(page?{pageToken:page}:{})});
      const response=await this.request(`${DRIVE}?${query}`);files.push(...response.files);page=response.nextPageToken||'';
    } while(page);
    return files.map(f=>({sheetId:f.id,alias:f.appProperties?.alias||f.name.replace(/^TrackVerse · /,''),url:f.webViewLink||`https://docs.google.com/spreadsheets/d/${f.id}/edit`}));
  }
  async createTracker(alias) {
    const created=await this.request(SHEETS,{method:'POST',body:{properties:{title:`TrackVerse · ${alias}`},sheets:[{properties:{title:'Habits',sheetId:0}},{properties:{title:HISTORY,sheetId:1}}]}});
    const id=created.spreadsheetId;
    // Only files created by this OAuth app are discovered; personal Drive files are never enumerated.
    await this.request(`${DRIVE}/${id}?fields=id`,{method:'PATCH',body:{appProperties:{trackverse:'1',alias}}});
    await this.request(`${SHEETS}/${id}/values:batchUpdate`,{method:'POST',body:{valueInputOption:'RAW',data:[{range:`'${HISTORY}'!A1:G2`,values:[[MAGIC,'TrackVerse keeps versioned backups here. Do not edit these rows.'],COLUMNS]},{range:"'Habits'!A1:D2",values:[['TrackVerse',alias],['Habits and check-ins are backed up in the history tab.','Manage this tracker inside TrackVerse.']]}]}});
    return {sheetId:id,alias,url:created.spreadsheetUrl};
  }
  async inspect(id) {
    const info=await this.request(`${DRIVE}/${id}?fields=id,name,capabilities(canEdit),permissions(type,role),appProperties`);
    if(!info.capabilities?.canEdit)throw Error('Your Google account does not have edit permission for this tracker.');
    if(info.appProperties?.trackverse!=='1')throw Error('Choose a tracker created by TrackVerse.');
    return {title:info.name,sharing:info.permissions?.some(p=>p.type==='anyone')?'Anyone with link':'Private · Google account only'};
  }
  async trashTracker(id) {
    await this.inspect(id);
    await this.request(`${DRIVE}/${id}`,{method:'PATCH',body:{trashed:true}});
  }
  async read(id) {
    const response=await this.request(`${SHEETS}/${id}/values/${encodeURIComponent(`'${HISTORY}'!A:G`)}`);
    const rows=response.values||[];
    if(rows.length>50000)throw Error('Backup history is too large. Export your tracker before continuing.');
    return rows;
  }
  async append(id,rows) {
    return this.request(`${SHEETS}/${id}/values/${encodeURIComponent(`'${HISTORY}'!A:G`)}:append?valueInputOption=RAW&insertDataOption=INSERT_ROWS`,{method:'POST',body:{majorDimension:'ROWS',values:rows}});
  }
  async updateSummary(id,snapshot,alias) {
    const rows=[['TrackVerse · '+alias,'Category','Schedule','Created','Check-ins'],...snapshot.habits.map(h=>[h.name,h.category,h.weekdays.map(d=>['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d-1]).join(', '),h.created,String(h.checks.length)]),[''],['Month tabs',snapshot.months.map(d=>d.slice(0,7)).join(', ')],['Last backed up',new Date().toISOString()]];
    const metadata=await this.request(`${SHEETS}/${id}?fields=sheets(properties(sheetId,title,gridProperties),charts(chartId))`);
    const tab=metadata.sheets.find(s=>s.properties.title==='Habits');
    if(!tab)return;
    const requests=monthRequests(snapshot,metadata);const size=tab.properties.gridProperties.rowCount;
    if(rows.length>size)requests.push({appendDimension:{sheetId:tab.properties.sheetId,dimension:'ROWS',length:rows.length-size}});
    requests.push({updateCells:{range:{sheetId:tab.properties.sheetId,startRowIndex:0,endRowIndex:Math.max(rows.length,size),startColumnIndex:0,endColumnIndex:5},rows:rows.map(row=>({values:row.map(v=>({userEnteredValue:{stringValue:v}}))})),fields:'userEnteredValue'}});
    await this.request(`${SHEETS}/${id}:batchUpdate`,{method:'POST',body:{requests}});
  }
}
module.exports={GoogleSheets};
