// Explicit, isolated review fixture. Never runs in the installed application.
const path=require('node:path'),fs=require('node:fs');
const {WorkspaceManager}=require('../desktop/workspaces.cjs');
const dir=path.resolve(__dirname,'../.local-data/focus-demo');
if(fs.existsSync(path.join(dir,'trackverse.sqlite3')))throw Error('Demo already exists; use it without overwriting.');
const manager=new WorkspaceManager(dir),now=new Date(),month=`${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-01`;
const habits=[['focus-maths','Maths practice','Learning',2,8],['focus-read','Read 20 pages','Learning',0,0],['focus-music','Practise guitar','Music',1,10],['focus-language','Learn Spanish','Learning',4,9]].map(([id,name,category,color,icon],index)=>({id,name,category,color,icon,created:month,months:[month],weekdays:[1,2,3,4,5,6,7],checks:Array.from({length:Math.max(0,now.getDate()-1)},(_,i)=>`${month.slice(0,8)}${String(i+1).padStart(2,'0')}`).filter((_,i)=>(i+index)%4!==0)}));
manager.root.save(habits);manager.root.saveMonths([month]);manager.root.setTheme('dark');manager.root.setPreference('cloudOnboarded',true);manager.rename('local','Focus demo · SQLite');
habits.forEach((h,i)=>manager.root.saveFocusSession({id:`review-session-${i}`,habitId:h.id,name:h.name,color:h.color,started:new Date(now.getFullYear(),now.getMonth(),Math.max(1,now.getDate()-1),10).toISOString(),seconds:[5400,3600,2700,1800][i]}));
manager.close();console.log(dir);
