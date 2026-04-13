import { app, BrowserWindow, globalShortcut, ipcMain, nativeTheme, systemPreferences } from "electron";
import path from "node:path";
import { CorrectionService } from "../correction/service";
import { MacosTextController } from "./macosTextController";
import { ipcChannels, type AppState, type FixRunResult, type PermissionState } from "../shared/ipc";

const correctionService = new CorrectionService();
const textController = new MacosTextController();
const triggerAccelerator = process.platform === "darwin" ? "Alt+Tab" : "CommandOrControl+Alt+T";

let mainWindow: BrowserWindow | null = null;
let isFixing = false;
let lastRun: FixRunResult | undefined;

function getPermissionState(prompt = false): PermissionState {
  if (process.platform !== "darwin") {
    return {
      platform: process.platform,
      accessibility: "unknown",
      inputMonitoring: "unknown",
      note: "Native text replacement is only implemented for macOS in this prototype."
    };
  }

  const isTrusted = systemPreferences.isTrustedAccessibilityClient(prompt);

  return {
    platform: process.platform,
    accessibility: isTrusted ? "granted" : "missing",
    inputMonitoring: "unknown",
    note: isTrusted
      ? "Accessibility permission is granted."
      : "Accessibility permission is required for selected-text copy and paste automation."
  };
}

function getAppState(): AppState {
  return {
    version: app.getVersion(),
    platform: process.platform,
    triggerAccelerator,
    tabTriggerStatus: "prototype-trigger",
    permissionState: getPermissionState(false),
    isFixing,
    lastRun
  };
}

function broadcastState(): void {
  if (!mainWindow) {
    return;
  }

  mainWindow.webContents.send(ipcChannels.stateChanged, getAppState());
}

async function runSelectedTextFix(): Promise<FixRunResult> {
  if (isFixing) {
    return {
      ok: false,
      reason: "A correction is already running.",
      durationMs: 0
    };
  }

  const startedAt = performance.now();
  isFixing = true;
  broadcastState();

  try {
    const selection = await textController.readSelectedText();

    if (!selection.ok) {
      lastRun = {
        ok: false,
        reason: selection.reason,
        durationMs: Math.round(performance.now() - startedAt)
      };
      return lastRun;
    }

    const correction = await correctionService.correct({
      text: selection.text,
      source: "active-selection"
    });

    if (!correction.changed) {
      textController.restoreClipboard(selection.previousClipboard);
      lastRun = {
        ok: true,
        reason: "No correction needed.",
        correction,
        durationMs: Math.round(performance.now() - startedAt)
      };
      return lastRun;
    }

    await textController.replaceSelectedText(correction.output, selection.previousClipboard);

    lastRun = {
      ok: true,
      correction,
      durationMs: Math.round(performance.now() - startedAt)
    };

    return lastRun;
  } catch (error) {
    lastRun = {
      ok: false,
      reason: error instanceof Error ? error.message : "Unknown correction failure.",
      durationMs: Math.round(performance.now() - startedAt)
    };

    return lastRun;
  } finally {
    isFixing = false;
    broadcastState();
  }
}

function createWindow(): void {
  mainWindow = new BrowserWindow({
    width: 980,
    height: 680,
    minWidth: 760,
    minHeight: 560,
    title: "Tab Fix",
    backgroundColor: nativeTheme.shouldUseDarkColors ? "#101111" : "#f7f7f2",
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false
    }
  });

  mainWindow.once("ready-to-show", () => {
    mainWindow?.show();
  });

  if (process.env.TAB_FIX_DEV_SERVER_URL) {
    mainWindow.loadURL(process.env.TAB_FIX_DEV_SERVER_URL);
  } else {
    mainWindow.loadFile(path.join(__dirname, "../renderer/index.html"));
  }
}

function registerHotkeys(): void {
  const registered = globalShortcut.register(triggerAccelerator, () => {
    void runSelectedTextFix();
  });

  if (!registered) {
    lastRun = {
      ok: false,
      reason: `Could not register trigger ${triggerAccelerator}. Another app may already own it.`,
      durationMs: 0
    };
  }
}

function registerIpc(): void {
  ipcMain.handle(ipcChannels.getState, () => getAppState());

  ipcMain.handle(ipcChannels.previewCorrection, async (_event, text: string) => {
    return correctionService.correct({
      text,
      source: "preview"
    });
  });

  ipcMain.handle(ipcChannels.runSelectedTextFix, () => runSelectedTextFix());
  ipcMain.handle(ipcChannels.requestAccessibilityPermission, () => getPermissionState(true));
}

app.whenReady().then(() => {
  registerIpc();
  createWindow();
  registerHotkeys();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});

app.on("will-quit", () => {
  globalShortcut.unregisterAll();
});
