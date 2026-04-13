import { app, BrowserWindow, ipcMain, Menu, nativeImage, screen, shell, systemPreferences, Tray } from "electron";
import path from "node:path";
import { NativeCoreClient, nativeBinaryPath } from "./nativeCoreClient";
import { ipcChannels, type NativeHelperEvent, type OverlayPayload } from "../shared/ipc";

const nativeCore = new NativeCoreClient();

let panelWindow: BrowserWindow | null = null;
let overlayWindow: BrowserWindow | null = null;
let tray: Tray | null = null;
let trayMenu: Menu | null = null;

const overlaySize = {
  width: 58,
  height: 38
};

function rendererUrl(page: "app" | "overlay"): string {
  const devServer = process.env.TAB_FIX_DEV_SERVER_URL;

  if (devServer) {
    return page === "app" ? devServer : `${devServer}/overlay.html`;
  }

  const fileName = page === "app" ? "index.html" : "overlay.html";
  return path.join(__dirname, "../renderer", fileName);
}

function createPanelWindow(): BrowserWindow {
  if (panelWindow) {
    return panelWindow;
  }

  panelWindow = new BrowserWindow({
    width: 1120,
    height: 780,
    minWidth: 920,
    minHeight: 640,
    title: "Tab Fix",
    titleBarStyle: "hiddenInset",
    backgroundColor: "#f7f7f2",
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false
    }
  });

  panelWindow.once("ready-to-show", () => panelWindow?.show());
  panelWindow.on("closed", () => {
    panelWindow = null;
  });

  if (process.env.TAB_FIX_DEV_SERVER_URL) {
    void panelWindow.loadURL(rendererUrl("app"));
  } else {
    void panelWindow.loadFile(rendererUrl("app"));
  }

  return panelWindow;
}

function createOverlayWindow(): BrowserWindow {
  if (overlayWindow) {
    return overlayWindow;
  }

  overlayWindow = new BrowserWindow({
    width: overlaySize.width,
    height: overlaySize.height,
    frame: false,
    transparent: true,
    resizable: false,
    movable: false,
    skipTaskbar: true,
    focusable: false,
    alwaysOnTop: true,
    hasShadow: false,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false
    }
  });

  overlayWindow.setIgnoreMouseEvents(true, { forward: true });
  overlayWindow.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });

  if (process.env.TAB_FIX_DEV_SERVER_URL) {
    void overlayWindow.loadURL(rendererUrl("overlay"));
  } else {
    void overlayWindow.loadFile(rendererUrl("overlay"));
  }

  overlayWindow.on("closed", () => {
    overlayWindow = null;
  });

  return overlayWindow;
}

function showPanel(): void {
  const window = createPanelWindow();
  window.show();
  window.focus();
}

function setupTray(): void {
  const icon = nativeImage.createFromDataURL(
    "data:image/svg+xml;utf8," +
      encodeURIComponent(`
        <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
          <rect x="5" y="5" width="22" height="22" rx="6" fill="#dc3b2f"/>
          <path d="M9 10h14v4h-5v10h-4V14H9z" fill="white"/>
        </svg>
      `)
  );
  const trayIcon = icon.resize({ width: 18, height: 18 });
  tray = new Tray(trayIcon);
  tray.setToolTip("Tab Fix");

  trayMenu = Menu.buildFromTemplate([
    { label: "Open Tab Fix", click: showPanel },
    {
      label: "Request Permissions",
      click: () => {
        void requestNativePermissions();
      }
    },
    { type: "separator" },
    { label: "Quit", role: "quit" }
  ]);

  tray.setContextMenu(trayMenu);
  tray.on("click", showPanel);
}

async function requestNativePermissions() {
  const electronAccessibility = process.platform === "darwin"
    ? systemPreferences.isTrustedAccessibilityClient(true)
    : false;
  const permissions = await nativeCore.requestPermissions();
  await shell.openExternal("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility");
  shell.showItemInFolder(nativeBinaryPath());

  nativeCore.stopHelper();
  setTimeout(() => nativeCore.startHelper(), 500);

  return {
    ...permissions,
    electronAccessibility,
    helperPath: nativeBinaryPath(),
    note: permissions.accessibility
      ? permissions.note
      : `Add Electron and the native helper manually if they do not appear. Helper: ${nativeBinaryPath()}`
  };
}

function handleNativeEvent(event: NativeHelperEvent): void {
  switch (event.type) {
    case "candidate":
      showOverlay({
        x: event.x,
        y: event.y,
        text: "Tab"
      });
      break;
    case "hide":
    case "applied":
      overlayWindow?.hide();
      break;
    case "status":
      break;
    case "error":
      console.error(event.message);
      break;
  }
}

function showOverlay(payload: OverlayPayload): void {
  const overlay = createOverlayWindow();
  const display = screen.getDisplayNearestPoint({ x: payload.x, y: payload.y });
  const overlayWidth = overlaySize.width;
  const overlayHeight = overlaySize.height;
  const x = Math.min(Math.max(payload.x, display.workArea.x), display.workArea.x + display.workArea.width - overlayWidth);
  const y = Math.min(Math.max(payload.y, display.workArea.y), display.workArea.y + display.workArea.height - overlayHeight);

  overlay.setBounds({ x, y, width: overlayWidth, height: overlayHeight });
  overlay.webContents.send(ipcChannels.overlayPayload, payload);
  overlay.showInactive();
}

function setupIpc(): void {
  ipcMain.handle(ipcChannels.getState, async () => {
    return {
      version: app.getVersion(),
      native: await nativeCore.status()
    };
  });

  ipcMain.handle(ipcChannels.correct, async (_event, text: string) => nativeCore.correct(text));
  ipcMain.handle(ipcChannels.requestPermissions, async () => requestNativePermissions());

  ipcMain.handle(ipcChannels.showOverlay, (_event, payload: OverlayPayload) => {
    showOverlay(payload);
  });

  ipcMain.handle(ipcChannels.hideOverlay, () => {
    overlayWindow?.hide();
  });
}

app.setName("Tab Fix");

app.whenReady().then(() => {
  setupIpc();
  setupTray();
  createOverlayWindow();
  nativeCore.on("event", handleNativeEvent);
  nativeCore.startHelper();
  showPanel();

  app.on("activate", showPanel);
});

app.on("window-all-closed", () => {
  // Menu bar app: keep running after the panel closes.
});

app.on("before-quit", () => {
  nativeCore.stopHelper();
});
