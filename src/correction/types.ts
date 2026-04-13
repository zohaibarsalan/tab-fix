import type { CorrectionResult } from "../shared/ipc";

export type CorrectionRequest = {
  text: string;
  source: "preview" | "active-selection";
};

export type CorrectionEngine = {
  correct: (request: CorrectionRequest) => Promise<CorrectionResult>;
};

