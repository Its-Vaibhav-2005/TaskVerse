const {test}=require('node:test'),assert=require('node:assert/strict');
const {themes,themePalette}=require('./theme-palette.cjs');
const {TrackVerseDatabase}=require('./database.cjs');
function luminance(h){return h.slice(1).match(/../g).map(x=>parseInt(x,16)/255).map(x=>x<=.04045?x/12.92:((x+.055)/1.055)**2.4).reduce((s,x,i)=>s+x*[.2126,.7152,.0722][i],0);}
function contrast(a,b){const x=luminance(a),y=luminance(b);return (Math.max(x,y)+.05)/(Math.min(x,y)+.05);}
test('All 43 theme presets have distinct names, paired modes and readable text and buttons',()=>{
  assert.equal(themes.length,43);assert.equal(new Set(themes.map(t=>t.name)).size,43);
  for(const t of themes)for(const mode of ['light','dark']){const p=t[mode];assert.ok(contrast(p.text,p.surface)>=7,`${t.name} primary`);assert.ok(contrast(p.muted,p.surface)>=4.5,`${t.name} secondary`);assert.ok(contrast(p.onAccent,p.accent)>=4.5,`${t.name} buttons`);}
});
test('New profiles follow OS appearance; manual overrides and palette choices persist',()=>{
  const db=new TrackVerseDatabase(':memory:');assert.equal(db.getTheme(),'system');
  assert.equal(themePalette(db,true).theme,'dark');assert.equal(themePalette(db,false).theme,'light');
  db.setPreference('themePreset','Nord');db.setTheme('light');assert.equal(themePalette(db,true).theme,'light');assert.equal(themePalette(db,true).preset,'Nord');
  db.setTheme('system');assert.equal(themePalette(db,true).palette.surface,themes.find(t=>t.name==='Nord').dark.surface);db.close();
});
