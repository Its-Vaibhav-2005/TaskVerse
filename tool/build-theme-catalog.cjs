const fs=require('node:fs'),path=require('node:path');
// Original app palettes inspired by the requested names, with accessible paired modes.
const definitions=[
['TrackVerse','Native','121a19','1b2523','7ad5b0','f8f9fc','ffffff','32816a'],
['Vercel','Tech & brand','090909','171717','ededed','fafafa','ffffff','171717'],
['Stripe','Tech & brand','151831','212344','a99afa','f6f5ff','ffffff','635bff'],
['Linear','Tech & brand','14141c','1e1e2a','a5a1ff','f7f7fc','ffffff','625ac4'],
['Claude Light','Tech & brand','23201d','302b27','e6aa8b','faf7f2','fffdf9','a85132'],
['Claude Dark','Tech & brand','1c1b19','292724','d99a7c','f5f0e8','fffcf7','a05336'],
['Tokyo Night','Editor classics','1a1b26','24283b','7aa2f7','eef0fa','ffffff','3453a0'],
['Tokyo Night LD','Editor classics','161926','22283b','89b4fa','e8ecf7','f7f9ff','3b5ea6'],
['Dracula','Editor classics','282a36','343746','bd93f9','f5f0fc','ffffff','7541aa'],
['Dracula Official','Editor classics','21222c','2b2d3a','ff79c6','fff3fa','ffffff','a32371'],
['Dracula LD','Editor classics','252432','343144','a998ef','f3effa','fdfbff','6f4ba7'],
['Nord','Editor classics','2e3440','3b4252','88c0d0','eceff4','ffffff','30647b'],
['Nord LD','Editor classics','242c36','303c48','8fbcbb','eaf0f3','f9fcff','306d70'],
['Catppuccin Mocha','Editor classics','1e1e2e','313244','cba6f7','f1eff8','ffffff','7848a8'],
['Catppuccin','Editor classics','242437','34344b','f5bde6','eff1f5','ffffff','8839ef'],
['Gruvbox','Editor classics','282828','3c3836','fabd2f','fbf1c7','fff8df','875a08'],
['Gruvbox Dark','Editor classics','1d2021','32302f','b8bb26','f4eed7','fffbec','607013'],
['One Dark Pro','Editor classics','282c34','323842','61afef','eff3f9','ffffff','2465a0'],
['One Dark','Editor classics','242830','303640','98c379','f0f5ee','ffffff','406a28'],
['GitHub Dark','Editor classics','0d1117','161b22','58a6ff','f6f8fa','ffffff','0969da'],
['GitHub Light','Editor classics','151b23','212830','79c0ff','ffffff','f6f8fa','0969da'],
['Everforest','Editor classics','2d353b','343f44','a7c080','f3f5e8','fffef8','536a31'],
['Solarized Dark','Editor classics','002b36','073642','2aa198','fdf6e3','fffcf2','16746e'],
['Solarized Light','Editor classics','073642','134651','b58900','fdf6e3','fffdf6','876300'],
['Monokai','Editor classics','272822','36372e','a6e22e','f6f6eb','ffffff','4d6c09'],
['Rose Pine','Editor classics','191724','26233a','ebbcba','faf4ed','fffaf5','a34d6c'],
['Ayu','Editor classics','0f1419','1c242e','ffb454','faf8f2','ffffff','926004'],
['Cobalt2','Editor classics','193549','22445e','ffc600','edf4fb','ffffff','1a6096'],
['Cobalt Gold','Editor classics','132b40','1d3c54','e9bd59','f9f4e6','ffffff','886211'],
['Midnight Purple 2077','Editor classics','130f26','24183d','d7a0ff','f5edff','ffffff','8134b6'],
['Celestial Mage','Dream skins','151b35','222b49','c3b3ff','f1f0ff','ffffff','6651a5'],
['Interstellar Crossing','Dream skins','091b2b','152d40','6bdfed','edf7fb','ffffff','136b85'],
['Neon Moon Pavilion','Dream skins','1b102c','301c45','ee9ee8','fbf0fa','ffffff','973b90'],
['Sakura Sports Car','Dream skins','291b29','3d283a','ff9dbb','fff1f5','ffffff','a8325c'],
['Snow Country Cabin','Dream skins','1d2d36','2d414b','b6dce6','f1f7fa','ffffff','346d82'],
['Sunlit Summer Sky','Dream skins','122b39','20404e','f4d77d','f0f8ff','fffefa','26709a'],
['White Night and Solace','Dream skins','232738','33394c','b9c5ee','f6f7fd','ffffff','596a9a'],
['Blushing Muse','Dream skins','2e2028','432f3a','edb0bd','fff4f4','fffdfc','a54667'],
['Obsidian Gold','Community & native','171715','282721','e4bf71','faf7ed','ffffff','80631a'],
['Cosmic Red','Community & native','24151c','38222c','ff9aab','fff2f3','ffffff','b3324c'],
['Nebula Velvet','Community & native','231a32','342843','c6a0ea','f7f0fc','ffffff','7d4aa2'],
['Sage Serenity','Community & native','1d2b24','2c3e32','b5cba4','f2f6ef','ffffff','4a6b3b'],
['Digital Melody','Community & native','111f2b','203342','79d5d0','eef9f8','ffffff','20726b']
];
const rgb=h=>h.replace('#','').match(/../g).map(x=>parseInt(x,16));
const hex=v=>'#'+v.map(x=>Math.round(x).toString(16).padStart(2,'0')).join('');
const mix=(a,b,t)=>hex(rgb(a).map((x,i)=>x*(1-t)+rgb(b)[i]*t));
function luminance(h){return rgb(h).map(x=>{x/=255;return x<=.04045?x/12.92:((x+.055)/1.055)**2.4;}).reduce((s,x,i)=>s+x*[.2126,.7152,.0722][i],0);}
function contrast(a,b){const x=luminance(a),y=luminance(b);return (Math.max(x,y)+.05)/(Math.min(x,y)+.05);}
function readable(color,bg,target=4.5){const end=luminance(bg)>.4?'#10151c':'#f5f7ff';let result=color;for(let i=1;contrast(result,bg)<target&&i<=100;i++)result=mix(color,end,i/100);return result;}
function palette(bg,surface,accent,dark){bg='#'+bg;surface='#'+surface;accent=readable('#'+accent,surface);const text=readable(dark?'#e5ede8':'#252735',surface,7),muted=readable(dark?'#aab5bc':'#596270',surface,4.5);return {background:bg,surface,raised:mix(surface,accent,.065),text,muted,border:mix(surface,text,.17),accent,selected:mix(surface,accent,.16),onAccent:contrast('#ffffff',accent)>=4.5?'#ffffff':'#111b24'};}
const themes=definitions.map(([name,group,db,ds,da,lb,ls,la])=>({name,group,dark:palette(db,ds,da,true),light:palette(lb,ls,la,false)}));
fs.writeFileSync(path.join(__dirname,'../assets/themes.json'),JSON.stringify(themes,null,2)+'\n');
let dart="// Generated by tool/build-theme-catalog.cjs.\nimport 'package:flutter/material.dart';\nclass ThemePreset {\nfinal String name,group;\nfinal Map<String,Color> light,dark;\nconst ThemePreset(this.name,this.group,this.light,this.dark);\nMap<String,Color> palette(Brightness b)=>b==Brightness.dark?dark:light;\n}\nconst themePresets=<ThemePreset>[\n";
for(const t of themes){dart+=`ThemePreset(${JSON.stringify(t.name)},${JSON.stringify(t.group)},`+[t.light,t.dark].map(p=>'{'+Object.entries(p).map(([k,v])=>`'${k}':Color(0xFF${v.slice(1)}),`).join('')+'}').join(',')+'),\n';}
dart+='];\n';fs.writeFileSync(path.join(__dirname,'../lib/theme_catalog.dart'),dart);console.log(`Built ${themes.length} paired theme presets`);
