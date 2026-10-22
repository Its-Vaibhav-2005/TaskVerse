const {test}=require('node:test'),assert=require('node:assert/strict'),{EventEmitter}=require('node:events');
const {keepFocusOnTop,setFocusLayout}=require('./focus-window.cjs');
test('Focus widget restores topmost on blur and later app changes without activating, and stops after closing',()=>{
  const w=new EventEmitter();let visible=true,raised=0,cancelled=false,level,tick;
  Object.assign(w,{isDestroyed:()=>false,isVisible:()=>visible,isMinimized:()=>false,setAlwaysOnTop:(flag,value)=>{assert.equal(flag,true);level=value;},moveTop:()=>raised++,focus:()=>assert.fail('Must not steal focus')});
  keepFocusOnTop(w,{every:fn=>{tick=fn;return 1;},cancel:id=>{assert.equal(id,1);cancelled=true;}});
  w.emit('blur');assert.equal(raised,1);tick();assert.equal(raised,2);assert.equal(level,'screen-saver');visible=false;tick();assert.equal(raised,2);w.emit('closed');assert.equal(cancelled,true);tick();assert.equal(raised,2);assert.equal(w.listenerCount('blur'),0);
});
test('Full setup returns to fixed dimensions after compact resizing; mini view remains resizable',()=>{
  let size,minimum,resizable;const w={setResizable:value=>resizable=value,setMinimumSize:(...v)=>minimum=v,setSize:(...v)=>size=v,setAlwaysOnTop:()=>{},isVisible:()=>true,moveTop:()=>{}};
  setFocusLayout(w,true);assert.equal(resizable,true);assert.deepEqual(minimum,[280,320]);assert.deepEqual(size,[300,340]);
  setFocusLayout(w,false);assert.equal(resizable,false);assert.deepEqual(size,[420,620]);assert.deepEqual(minimum,[420,620]);
});
