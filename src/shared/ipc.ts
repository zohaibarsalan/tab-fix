export type PermissionState = {
  platform: string;
  accessibility: "granted" | "missing" | "unknown";
  inputMonitoring: "unknown";
  note: string;
};

export type CorrectionResult = {
  input: string;
  output: string;
  changed: boolean;
  fixes: string[];
  durationMs: number;
};

export type FixRunResult = {
  ok: boolean;
  reason?: string;
  correction?: CorrectionResult;
  durationMs: number;
};

export type AppState = {
  version: string;
  platform: string;
  triggerAccelerator: string;
  tabTriggerStatus: "prototype-trigger" | "native-helper-required";
  permissionState: PermissionState;
  isFixing: boolean;
  lastRun?: FixRunResult;
};

export type TabFixApi = {
  getState: () => Promise<AppState>;
  previewCorrection: (text: string) => Promise<CorrectionResult>;
  runSelectedTextFix: () => Promise<FixRunResult>;
  requestAccessibilityPermission: () => Promise<PermissionState>;
  onStateChange: (callback: (state: AppState) => void) => () => void;
};

export const ipcChannels = {
  getState: "tab-fix:get-state",
  previewCorrection: "tab-fix:preview-correction",
  runSelectedTextFix: "tab-fix:run-selected-text-fix",
  requestAccessibilityPermission: "tab-fix:request-accessibility-permission",
  stateChanged: "tab-fix:state-changed"
} as const;

