import { contextBridge, ipcRenderer } from "electron";
import { ipcChannels, type AppState, type CorrectionResult, type OverlayPayload, type PermissionState, type TabFixApi } from "../shared/ipc";

const api: TabFixApi = {
  getState: () => ipcRenderer.invoke(ipcChannels.getState) as Promise<AppState>,
  correct: (text) => ipcRenderer.invoke(ipcChannels.correct, text) as Promise<CorrectionResult>,
  requestPermissions: () => ipcRenderer.invoke(ipcChannels.requestPermissions) as Promise<PermissionState>,
  showOverlay: (payload) => ipcRenderer.invoke(ipcChannels.showOverlay, payload) as Promise<void>,
  hideOverlay: () => ipcRenderer.invoke(ipcChannels.hideOverlay) as Promise<void>,
  onOverlayPayload: (callback) => {
    const listener = (_event: Electron.IpcRendererEvent, payload: OverlayPayload) => {
      callback(payload);
    };

    ipcRenderer.on(ipcChannels.overlayPayload, listener);

    return () => {
      ipcRenderer.off(ipcChannels.overlayPayload, listener);
    };
  }
};

contextBridge.exposeInMainWorld("tabFix", api);

