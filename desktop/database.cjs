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
  }
  load() {
    const checks = this.db.prepare('SELECT * FROM completions').all();
    return this.db.prepare('SELECT * FROM habits ORDER BY rowid').all().map(h => ({
      ...h, weekdays: JSON.parse(h.weekdays), checks: checks.filter(c=>c.habit_id===h.id).map(c=>c.day)
    }));
  }
  save(habits, inTransaction=false) {
    if(!Array.isArray(habits)||habits.length>10000) throw Error('Invalid habit data');
    const ids=new Set();
    for(const h of habits) {
      if(!h||typeof h.id!=='string'||!h.id||ids.has(h.id)||typeof h.name!=='string'||!h.name.trim()||h.name.length>60||typeof h.category!=='string'||!Number.isInteger(h.color)||h.color<0||h.color>4||!Number.isInteger(h.icon)||h.icon<0||h.icon>7||!validDay(h.created)||!Array.isArray(h.weekdays)||!h.weekdays.length||h.weekdays.some(d=>!Number.isInteger(d)||d<1||d>7)||!Array.isArray(h.checks)||h.checks.some(d=>!validDay(d))) throw Error('Invalid habit data');
      ids.add(h.id);
    }
    if(!inTransaction)this.db.exec('BEGIN IMMEDIATE');
    try {
      this.db.exec('DELETE FROM completions; DELETE FROM habits;');
      const insert=this.db.prepare('INSERT INTO habits VALUES (?, ?, ?, ?, ?, ?, ?)');
      const check=this.db.prepare('INSERT INTO completions VALUES (?, ?)');
      for(const h of habits) {
        insert.run(h.id,h.name,h.category,h.color,h.icon,h.created,JSON.stringify(h.weekdays));
        for(const day of h.checks) check.run(h.id,day);
      }
      if(!inTransaction)this.db.exec('COMMIT');
    } catch(e) { if(!inTransaction)this.db.exec('ROLLBACK'); throw e; }
  }
  loadMonths() { return this.db.prepare('SELECT month FROM months ORDER BY month').all().map(r=>r.month); }
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
    try {this.save(backup.habits,true);this.saveMonths(backup.months?.length?backup.months:this.loadMonths(),true);if(!inTransaction)this.db.exec('COMMIT');}
    catch(e){if(!inTransaction)this.db.exec('ROLLBACK');throw e;}
  }
  close() { this.db.close(); }
  getPreference(key,fallback=null) {const row=this.db.prepare('SELECT value FROM preferences WHERE key = ?').get(key);return row?JSON.parse(row.value):fallback;}
  setPreference(key,value) {this.db.prepare('INSERT INTO preferences VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value').run(key,JSON.stringify(value));}
  getTheme() {return this.db.prepare("SELECT value FROM preferences WHERE key = 'theme'").get()?.value||'light';}
  setTheme(mode) {
    if(!['light','dark'].includes(mode))throw Error('Invalid appearance');
    this.db.prepare("INSERT INTO preferences VALUES ('theme', ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value").run(mode);
  }
  checkIn(id,day,complete,systemNow=new Date()) {
    const localDay=`${systemNow.getFullYear()}-${String(systemNow.getMonth()+1).padStart(2,'0')}-${String(systemNow.getDate()).padStart(2,'0')}`;
    if(day!==localDay)throw Error('Only today can be changed. Past days are locked.');
    const habit=this.db.prepare('SELECT * FROM habits WHERE id = ?').get(id);
    const weekday=systemNow.getDay()||7;
    if(!habit||habit.created>day||!JSON.parse(habit.weekdays).includes(weekday)||typeof complete!=='boolean')throw Error('This habit is not scheduled today.');
    if(complete)this.db.prepare('INSERT OR IGNORE INTO completions VALUES (?, ?)').run(id,day);
    else this.db.prepare('DELETE FROM completions WHERE habit_id = ? AND day = ?').run(id,day);
  }
}
function validDay(value) {
  return typeof value==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(value)&&!Number.isNaN(Date.parse(value))&&new Date(value).toISOString().slice(0,10)===value;
}
module.exports={TrackVerseDatabase};
