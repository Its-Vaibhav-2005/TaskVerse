const { DatabaseSync } = require('node:sqlite');

class TrackVerseDatabase {
  constructor(path) {
    this.db = new DatabaseSync(path);
    this.db.exec(`PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL;
      CREATE TABLE IF NOT EXISTS habits (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT NOT NULL,
        color INTEGER NOT NULL, icon INTEGER NOT NULL, created TEXT NOT NULL, weekdays TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS completions (
        habit_id TEXT NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
        day TEXT NOT NULL, PRIMARY KEY(habit_id, day)
      );
      CREATE TABLE IF NOT EXISTS months (month TEXT PRIMARY KEY);
      CREATE TABLE IF NOT EXISTS preferences (key TEXT PRIMARY KEY, value TEXT NOT NULL);
      PRAGMA user_version = 2;`);
    if(!this.db.prepare('PRAGMA table_info(habits)').all().some(c=>c.name==='months'))this.db.exec('ALTER TABLE habits ADD COLUMN months TEXT');
    const columns=this.db.prepare('PRAGMA table_info(habits)').all().map(c=>c.name);
    for(const [name,type] of [['dailyTarget','INTEGER NOT NULL DEFAULT 1'],['dailyCounts',"TEXT NOT NULL DEFAULT '{}'"],['reminder','TEXT']])if(!columns.includes(name))this.db.exec(`ALTER TABLE habits ADD COLUMN ${name} ${type}`);
    this.db.exec('PRAGMA user_version = 4');
  }
  load() {
    const checks = this.db.prepare('SELECT * FROM completions').all();
    return this.db.prepare('SELECT * FROM habits ORDER BY rowid').all().map(({months,dailyCounts,reminder,...h}) => ({
      ...h, dailyCounts:JSON.parse(dailyCounts),reminder:reminder?JSON.parse(reminder):null, ...(months?{months:JSON.parse(months)}:{}), weekdays: JSON.parse(h.weekdays), checks: checks.filter(c=>c.habit_id===h.id).map(c=>c.day)
    }));
  }
  loadFocusSessions(){return this.getPreference('focusSessions',[]);}
  saveFocusSession(record){
    if(!record||typeof record.id!=='string'||typeof record.habitId!=='string'||typeof record.name!=='string'||!Number.isInteger(record.color)||record.color<0||record.color>15||!Number.isFinite(record.seconds)||record.seconds<0||record.seconds>10801||!Number.isFinite(Date.parse(record.started)))throw Error('Invalid focus session');
    const records=this.loadFocusSessions(),index=records.findIndex(r=>r.id===record.id);
    if(index<0)records.push(record);else records[index]=record;
    this.setPreference('focusSessions',records);
  }
  save(habits, inTransaction=false) {
    if(!Array.isArray(habits)||habits.length>10000) throw Error('Invalid habit data');
    const ids=new Set();
    for(const h of habits) {
      if(!h||typeof h.id!=='string'||!h.id||ids.has(h.id)||typeof h.name!=='string'||!h.name.trim()||h.name.length>60||typeof h.category!=='string'||!Number.isInteger(h.color)||h.color<0||h.color>15||!Number.isInteger(h.icon)||h.icon<0||h.icon>25||!validDay(h.created)||!Array.isArray(h.weekdays)||!h.weekdays.length||h.weekdays.some(d=>!Number.isInteger(d)||d<1||d>7)||!Array.isArray(h.checks)||h.checks.some(d=>!validDay(d))) throw Error('Invalid habit data');
      if(h.months!=null&&(!Array.isArray(h.months)||h.months.some(m=>!validDay(m)||!m.endsWith('-01'))))throw Error('Invalid habit month scope');
      if(!Number.isInteger(h.dailyTarget??1)||(h.dailyTarget??1)<1||(h.dailyTarget??1)>99)throw Error('Daily target must be between 1 and 99.');
      if(h.dailyCounts!=null&&(typeof h.dailyCounts!=='object'||Array.isArray(h.dailyCounts)||Object.entries(h.dailyCounts).some(([day,count])=>!validDay(day)||!Number.isInteger(count)||count<0||count>99)))throw Error('Invalid daily counts.');
      if(h.reminder!=null&&(typeof h.reminder!=='object'||typeof h.reminder.enabled!=='boolean'||!/^([01]\d|2[0-3]):[0-5]\d$/.test(h.reminder.time)||!Number.isInteger(h.reminder.interval)||h.reminder.interval<5||h.reminder.interval>720))throw Error('Invalid reminder schedule.');
      ids.add(h.id);
    }
    if(!inTransaction)this.db.exec('BEGIN IMMEDIATE');
    try {
      this.db.exec('DELETE FROM completions; DELETE FROM habits;');
      const insert=this.db.prepare('INSERT INTO habits (id,name,category,color,icon,created,weekdays,months,dailyTarget,dailyCounts,reminder) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
      const check=this.db.prepare('INSERT INTO completions VALUES (?, ?)');
      for(const h of habits) {
        insert.run(h.id,h.name,h.category,h.color,h.icon,h.created,JSON.stringify(h.weekdays),h.months==null?null:JSON.stringify(h.months),h.dailyTarget??1,JSON.stringify(h.dailyCounts??{}),h.reminder==null?null:JSON.stringify(h.reminder));
        for(const day of h.checks) check.run(h.id,day);
      }
      if(!inTransaction)this.db.exec('COMMIT');
    } catch(e) { if(!inTransaction)this.db.exec('ROLLBACK'); throw e; }
  }
  loadMonths() { return this.db.prepare('SELECT month FROM months ORDER BY month').all().map(r=>r.month); }
  savePlan(habits,months,inTransaction=false,systemNow=new Date()) {
    const current=`${systemNow.getFullYear()}-${String(systemNow.getMonth()+1).padStart(2,'0')}-01`;
    if(!Array.isArray(months)||this.loadMonths().some(m=>!months.includes(m)&&m<=current))throw Error('Current and past months cannot be deleted.');
    if(!inTransaction)this.db.exec('BEGIN IMMEDIATE');
    try{this.save(habits,true);this.saveMonths(months,true);if(!inTransaction)this.db.exec('COMMIT');}catch(e){if(!inTransaction)this.db.exec('ROLLBACK');throw e;}
  }
  saveMonths(months, inTransaction=false) {
    if(!Array.isArray(months)||months.some(m=>!validDay(m)||!m.endsWith('-01'))) throw Error('Invalid month tabs');
    if(!inTransaction)this.db.exec('BEGIN IMMEDIATE');
    try {
      this.db.exec('DELETE FROM months');
      const insert=this.db.prepare('INSERT INTO months VALUES (?)');
      for(const m of months) insert.run(m);
      if(!inTransaction)this.db.exec('COMMIT');
    } catch(e) {if(!inTransaction)this.db.exec('ROLLBACK');throw e;}
  }
  restore(backup, inTransaction=false) {
    if(backup.format!=='trackverse'||backup.version!==1)throw Error('Invalid backup');
    if(!inTransaction)this.db.exec('BEGIN IMMEDIATE');
    try {this.save(backup.habits,true);this.saveMonths(backup.months?.length?backup.months:this.loadMonths(),true);this.setPreference('focusSessions',[]);for(const session of backup.focusSessions||[])this.saveFocusSession(session);if(!inTransaction)this.db.exec('COMMIT');}
    catch(e){if(!inTransaction)this.db.exec('ROLLBACK');throw e;}
  }
  close() { this.db.close(); }
  getPreference(key,fallback=null) {const row=this.db.prepare('SELECT value FROM preferences WHERE key = ?').get(key);return row?JSON.parse(row.value):fallback;}
  setPreference(key,value) {this.db.prepare('INSERT INTO preferences VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value').run(key,JSON.stringify(value));}
  getTheme() {return this.db.prepare("SELECT value FROM preferences WHERE key = 'theme'").get()?.value||'system';}
  setTheme(mode) {
    if(!['system','light','dark'].includes(mode))throw Error('Invalid appearance');
    this.db.prepare("INSERT INTO preferences VALUES ('theme', ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value").run(mode);
  }
  checkIn(id,day,complete,systemNow=new Date()) {
    if(typeof complete!=='boolean')throw Error('Invalid completion flag.');
    const target=this.db.prepare('SELECT dailyTarget FROM habits WHERE id = ?').get(id)?.dailyTarget||1;
    this.setCount(id,day,complete?target:0,systemNow);
  }
  setCount(id,day,count,systemNow=new Date()) {
    const localDay=`${systemNow.getFullYear()}-${String(systemNow.getMonth()+1).padStart(2,'0')}-${String(systemNow.getDate()).padStart(2,'0')}`;
    if(day!==localDay)throw Error('Only today can be changed. Past days are locked.');
    const habit=this.db.prepare('SELECT * FROM habits WHERE id = ?').get(id);
    const weekday=systemNow.getDay()||7;
    if(!habit||habit.created>day||habit.months&&!JSON.parse(habit.months).includes(day.slice(0,7)+'-01')||!JSON.parse(habit.weekdays).includes(weekday))throw Error('This habit is not scheduled today.');
    if(!Number.isInteger(count)||count<0||count>habit.dailyTarget)throw Error('Count must be between zero and the daily target.');
    const counts=JSON.parse(habit.dailyCounts);counts[day]=count;
    this.db.prepare('UPDATE habits SET dailyCounts = ? WHERE id = ?').run(JSON.stringify(counts),id);
    if(count>=habit.dailyTarget)this.db.prepare('INSERT OR IGNORE INTO completions VALUES (?, ?)').run(id,day);
    else this.db.prepare('DELETE FROM completions WHERE habit_id = ? AND day = ?').run(id,day);
  }
}
function validDay(value) {
  return typeof value==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(value)&&!Number.isNaN(Date.parse(value))&&new Date(value).toISOString().slice(0,10)===value;
}
module.exports={TrackVerseDatabase};
