const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('trackverseDesktop', {
  request: (operation, payload='') => ipcRenderer.invoke('trackverse:data', operation, payload)
});
