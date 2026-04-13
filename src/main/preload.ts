import { contextBridge, ipcRenderer } from "electron";
import { ipcChannels, type AppState, type CorrectionResult, type FixRunResult, type PermissionState, type TabFixApi } from "../shared/ipc";

const api: TabFixApi = {
  getState: () => ipcRenderer.invoke(ipcChannels.getState) as Promise<AppState>,
  previewCorrection: (text: string) => ipcRenderer.invoke(ipcChannels.previewCorrection, text) as Promise<CorrectionResult>,
  runSelectedTextFix: () => ipcRenderer.invoke(ipcChannels.runSelectedTextFix) as Promise<FixRunResult>,
  requestAccessibilityPermission: () => ipcRenderer.invoke(ipcChannels.requestAccessibilityPermission) as Promise<PermissionState>,
  onStateChange: (callback) => {
    const listener = (_event: Electron.IpcRendererEvent, state: AppState) => {
      callback(state);
    };

    ipcRenderer.on(ipcChannels.stateChanged, listener);

    return () => {
      ipcRenderer.off(ipcChannels.stateChanged, listener);
    };
  }
};

contextBridge.exposeInMainWorld("tabFix", api);
