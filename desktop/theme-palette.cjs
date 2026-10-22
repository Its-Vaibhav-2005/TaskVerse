const themes=require('../assets/themes.json');
function themePalette(store,systemDark){const mode=store.getTheme(),dark=mode==='system'?systemDark:mode==='dark',name=store.getPreference('themePreset','TrackVerse'),preset=themes.find(t=>t.name===name)||themes[0];return {theme:dark?'dark':'light',preset:preset.name,palette:preset[dark?'dark':'light']};}
module.exports={themes,themePalette};
