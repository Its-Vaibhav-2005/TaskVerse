// Reassert native z-order without activating the widget or stealing keyboard focus.
function keepFocusOnTop(window,{every=setInterval,cancel=clearInterval}={}) {
  let closed=false;
  const pin=()=>{
    if(closed||window.isDestroyed()||!window.isVisible()||window.isMinimized())return;
    window.setAlwaysOnTop(true,'screen-saver');
    window.moveTop();
  };
  window.setAlwaysOnTop(true,'screen-saver');
  for(const event of ['show','restore','blur'])window.on(event,pin);
  const interval=every(pin,2000);
  window.once('closed',()=>{closed=true;cancel(interval);for(const event of ['show','restore','blur'])window.removeListener(event,pin);});
  return pin;
}
function setFocusLayout(window,compact) {
  window.setResizable(compact);
  window.setMinimumSize(compact?280:420,compact?320:620);
  window.setSize(compact?300:420,compact?340:620);
  window.setAlwaysOnTop(true,'screen-saver');
  if(window.isVisible())window.moveTop();
}
module.exports={keepFocusOnTop,setFocusLayout};
