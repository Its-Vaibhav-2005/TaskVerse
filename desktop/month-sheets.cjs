const MONTHS=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
function column(n){let s='';for(n++;n;n=Math.floor((n-1)/26))s=String.fromCharCode(65+(n-1)%26)+s;return s;}
function monthRequests(snapshot,metadata){
  const requests=[],sheets=metadata.sheets||[];let next=Math.max(0,...sheets.map(s=>s.properties.sheetId))+1;
  const current=new Date(),currentMonth=`${current.getFullYear()}-${String(current.getMonth()+1).padStart(2,'0')}-01`;
  for(const sheet of sheets){const managed=sheet.developerMetadata?.find(d=>d.metadataKey==='trackverseMonth');if(managed&&managed.metadataValue>currentMonth&&!snapshot.months.includes(managed.metadataValue))requests.push({deleteSheet:{sheetId:sheet.properties.sheetId}});}
  for(const month of snapshot.months){
    const match=/^(\d{4})-(\d{2})/.exec(month);if(!match)continue;
    const year=Number(match[1]),m=Number(match[2]);if(m<1||m>12)continue;
    const title=`${MONTHS[m-1]} ${year}`,days=new Date(Date.UTC(year,m,0)).getUTCDate();
    const existing=sheets.find(s=>s.properties.title===title),sheetId=existing?.properties.sheetId??next++;
    const habits=snapshot.habits.filter(h=>(h.months==null||h.months.includes(month))&&h.created.slice(0,10)<=`${match[1]}-${match[2]}-${days}`);
    const end=habits.length+3,rateColumn=days+2,last=column(days+1);
    if(!existing)requests.push({addSheet:{properties:{sheetId,title,gridProperties:{rowCount:Math.max(100,end+5),columnCount:days+3,frozenRowCount:3,frozenColumnCount:2}}}});
    else requests.push({updateSheetProperties:{properties:{sheetId,gridProperties:{rowCount:Math.max(existing.properties.gridProperties?.rowCount||100,end+5),columnCount:Math.max(existing.properties.gridProperties?.columnCount||0,days+3),frozenRowCount:3,frozenColumnCount:2}},fields:'gridProperties'}});
    if(!existing?.developerMetadata?.some(d=>d.metadataKey==='trackverseMonth'))requests.push({createDeveloperMetadata:{developerMetadata:{metadataKey:'trackverseMonth',metadataValue:month,location:{sheetId},visibility:'DOCUMENT'}}});
    const rows=[{values:[{userEnteredValue:{stringValue:`${snapshot.alias||'TrackVerse'} · ${title}`}}]},
      {values:[{userEnteredValue:{stringValue:'Daily completion'}},{},...Array.from({length:days},(_,i)=>({userEnteredValue:habits.length?{formulaValue:`=IFERROR(COUNTIF(${column(i+2)}4:${column(i+2)}${end},TRUE)/COUNTIF(${column(i+2)}4:${column(i+2)}${end},"<>"),0)`}:{numberValue:0}}))]},
      {values:['Habit','Category',...Array.from({length:days},(_,i)=>String(i+1)),'Completion'].map(stringValue=>({userEnteredValue:{stringValue}}))},
      ...habits.map((h,index)=>({values:[{userEnteredValue:{stringValue:h.name}},{userEnteredValue:{stringValue:h.category}},...Array.from({length:days},(_,i)=>{
        const day=`${match[1]}-${match[2]}-${String(i+1).padStart(2,'0')}`,weekday=(new Date(`${day}T12:00:00Z`).getUTCDay()+6)%7+1;
        return h.weekdays.includes(weekday)&&day>=h.created.slice(0,10)?{userEnteredValue:{boolValue:h.checks.includes(day)}}:{};
      }),{userEnteredValue:{formulaValue:`=IFERROR(COUNTIF(C${index+4}:${last}${index+4},TRUE)/COUNTIF(C${index+4}:${last}${index+4},"<>"),0)`}}]}))];
    requests.push({updateCells:{range:{sheetId,startRowIndex:0,endRowIndex:Math.max(end,existing?.properties.gridProperties?.rowCount||0),startColumnIndex:0,endColumnIndex:days+3},rows,fields:'userEnteredValue'}});
    requests.push({repeatCell:{range:{sheetId,startRowIndex:3,endRowIndex:Math.max(4,end),startColumnIndex:2,endColumnIndex:days+2},cell:{dataValidation:{condition:{type:'BOOLEAN'},strict:true,showCustomUi:true}},fields:'dataValidation'}});
    for(const range of [{sheetId,startRowIndex:1,endRowIndex:2,startColumnIndex:2,endColumnIndex:days+2},{sheetId,startRowIndex:3,endRowIndex:Math.max(4,end),startColumnIndex:rateColumn,endColumnIndex:rateColumn+1}])requests.push({repeatCell:{range,cell:{userEnteredFormat:{numberFormat:{type:'PERCENT',pattern:'0%'}}},fields:'userEnteredFormat.numberFormat'}});
    requests.push({repeatCell:{range:{sheetId,startRowIndex:2,endRowIndex:3},cell:{userEnteredFormat:{backgroundColor:{red:.14,green:.39,blue:.29},textFormat:{bold:true,foregroundColor:{red:1,green:1,blue:1}}}},fields:'userEnteredFormat'}});
    requests.push({updateDimensionProperties:{range:{sheetId,dimension:'COLUMNS',startIndex:0,endIndex:1},properties:{pixelSize:220},fields:'pixelSize'}});
    if(!existing?.charts?.length)requests.push({addChart:{chart:{spec:{title:`${title} · Daily completion`,basicChart:{chartType:'COLUMN',legendPosition:'NO_LEGEND',domains:[{domain:{sourceRange:{sources:[{sheetId,startRowIndex:2,endRowIndex:3,startColumnIndex:2,endColumnIndex:days+2}]}}}],series:[{series:{sourceRange:{sources:[{sheetId,startRowIndex:1,endRowIndex:2,startColumnIndex:2,endColumnIndex:days+2}]}},targetAxis:'LEFT_AXIS'}],headerCount:0}},position:{overlayPosition:{anchorCell:{sheetId,rowIndex:end+2,columnIndex:0},widthPixels:900,heightPixels:280}}}}});
  }
  return requests;
}
module.exports={monthRequests};
