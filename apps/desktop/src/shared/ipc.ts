export type PermissionState = {
  accessibility: boolean;
  electronAccessibility?: boolean;
  inputMonitoring: boolean;
  note: string;
  helperPath?: string;
};

export type CorrectionResult = {
  input: string;
  output: string;
  changed: boolean;
  fixes: string[];
  durationMs: number;
};

export type NativeStatus = {
  ok: boolean;
  platform: string;
  permissions: PermissionState;
  capabilities: string[];
};

export type NativeHelperEvent =
  | {
      type: "status";
      status: NativeStatus;
    }
  | {
      type: "candidate";
      x: number;
      y: number;
      correction: CorrectionResult;
      appName?: string;
    }
  | {
      type: "hide";
      reason?: string;
    }
  | {
      type: "applied";
      correction: CorrectionResult;
    }
  | {
      type: "error";
      message: string;
    };

export type OverlayPayload = {
  x: number;
  y: number;
  text?: string;
};

export type AppState = {
  version: string;
  native: NativeStatus;
};

export type TabFixApi = {
  getState: () => Promise<AppState>;
  correct: (text: string) => Promise<CorrectionResult>;
  requestPermissions: () => Promise<PermissionState>;
  showOverlay: (payload: OverlayPayload) => Promise<void>;
  hideOverlay: () => Promise<void>;
  onOverlayPayload: (callback: (payload: OverlayPayload) => void) => () => void;
};

export const ipcChannels = {
  getState: "tab-fix:get-state",
  correct: "tab-fix:correct",
  requestPermissions: "tab-fix:request-permissions",
  showOverlay: "tab-fix:show-overlay",
  hideOverlay: "tab-fix:hide-overlay",
  overlayPayload: "tab-fix:overlay-payload"
} as const;
