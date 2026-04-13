import { LocalRuleEngine } from "./localRuleEngine";
import type { CorrectionEngine, CorrectionRequest } from "./types";
import type { CorrectionResult } from "../shared/ipc";

export class CorrectionService {
  private readonly engine: CorrectionEngine;

  constructor(engine: CorrectionEngine = new LocalRuleEngine()) {
    this.engine = engine;
  }

  async correct(request: CorrectionRequest): Promise<CorrectionResult> {
    return this.engine.correct(request);
  }
}

