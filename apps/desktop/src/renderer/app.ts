import "./styles.css";
import type { AppState, CorrectionResult, TabFixApi } from "../shared/ipc";

declare global {
  interface Window {
    tabFix: TabFixApi;
  }
}

const idleDelayMs = 420;
const app = document.querySelector<HTMLDivElement>("#app");

if (!app) {
  throw new Error("Missing app root");
}

const appRoot = app;

appRoot.innerHTML = `
  <section class="shell">
    <header class="masthead">
      <div>
        <p class="eyebrow">Tab Fix</p>
        <h1>Type. Pause. Tab.</h1>
      </div>
      <div class="logo" aria-label="Tab Fix">
        <span>T</span>
        <strong>Tab Fix</strong>
      </div>
    </header>

    <section class="composer" aria-label="Inline correction demo">
      <div class="field-wrap">
        <label for="preview-input">Write here</label>
        <textarea id="preview-input" spellcheck="false" autocomplete="off" placeholder="Try: i dont think this are right"></textarea>
      </div>
      <aside class="suggestion" data-suggestion hidden aria-live="polite">
        <span class="label">Suggested fix</span>
        <strong data-suggestion-text></strong>
      </aside>
    </section>

    <section class="system-strip" aria-label="System status">
      <article>
        <span class="label">macOS access</span>
        <strong data-permission>Loading</strong>
        <p data-permission-note>Checking native core.</p>
      </article>
      <article>
        <span class="label">Native core</span>
        <strong data-native>Loading</strong>
        <p>Swift owns text fields, caret bounds, Tab event taps, and replacement.</p>
      </article>
      <article>
        <span class="label">Last fix</span>
        <strong data-last-run>None yet</strong>
        <p data-last-run-note>Pause after typing, then press Tab.</p>
      </article>
    </section>

    <section class="panel-grid" aria-label="Product panel">
      <article>
        <span class="label">Settings</span>
        <h2>Correction trigger</h2>
        <p>Show the Tab hint after a short pause. Press Tab to apply only while a fix is available.</p>
        <button type="button" data-permissions>Request macOS access</button>
      </article>
      <article>
        <span class="label">Dictionary</span>
        <h2>Custom words</h2>
        <p>Names, products, slang, and words Tab Fix should leave alone will live here.</p>
        <button type="button" disabled>Coming later</button>
      </article>
      <article>
        <span class="label">Native helper</span>
        <h2>Every app</h2>
        <p>Next: focused field detection, caret bounds, real Tab event tap, and in-place replacement.</p>
        <button type="button" disabled>Swift core</button>
      </article>
    </section>
  </section>
`;

const input = must<HTMLTextAreaElement>("#preview-input");
const suggestion = must<HTMLElement>("[data-suggestion]");
const suggestionText = must<HTMLElement>("[data-suggestion-text]");
const permission = must<HTMLElement>("[data-permission]");
const permissionNote = must<HTMLElement>("[data-permission-note]");
const nativeStatus = must<HTMLElement>("[data-native]");
const lastRun = must<HTMLElement>("[data-last-run]");
const lastRunNote = must<HTMLElement>("[data-last-run-note]");
const permissionsButton = must<HTMLButtonElement>("[data-permissions]");

let pendingCorrection: CorrectionResult | null = null;
let idleTimer: number | undefined;
let requestId = 0;

function must<T extends Element>(selector: string): T {
  const element = appRoot.querySelector<T>(selector);

  if (!element) {
    throw new Error(`Missing ${selector}`);
  }

  return element;
}

function renderState(state: AppState): void {
  permission.textContent = state.native.permissions.accessibility ? "Ready" : "Needs access";
  permission.dataset.state = state.native.permissions.accessibility ? "ready" : "blocked";
  permissionNote.textContent = state.native.permissions.note;
  nativeStatus.textContent = state.native.ok ? "Connected" : "Offline";
  nativeStatus.dataset.state = state.native.ok ? "ready" : "blocked";
}

function setSuggestion(result: CorrectionResult | null): void {
  pendingCorrection = result?.changed ? result : null;

  if (!pendingCorrection) {
    suggestion.hidden = true;
    void window.tabFix.hideOverlay();
    return;
  }

  suggestionText.textContent = pendingCorrection.output;
  suggestion.hidden = false;
  positionHint();
}

function positionHint(): void {
  const fieldRect = input.getBoundingClientRect();

  void window.tabFix.showOverlay({
    x: Math.round(window.screenX + fieldRect.right - 220),
    y: Math.round(window.screenY + fieldRect.top - 60),
    text: "Fix sentence"
  });
}

function queueCorrection(): void {
  window.clearTimeout(idleTimer);
  setSuggestion(null);

  const text = input.value;
  const currentRequestId = requestId + 1;
  requestId = currentRequestId;

  if (text.trim().length < 3) {
    return;
  }

  idleTimer = window.setTimeout(() => {
    void (async () => {
      const result = await window.tabFix.correct(text);

      if (currentRequestId !== requestId || input.value !== text) {
        return;
      }

      setSuggestion(result);
    })();
  }, idleDelayMs);
}

function applyCorrection(): void {
  if (!pendingCorrection) {
    return;
  }

  input.value = pendingCorrection.output;
  lastRun.textContent = `${pendingCorrection.durationMs}ms`;
  lastRun.dataset.state = "ready";
  lastRunNote.textContent = pendingCorrection.fixes.length > 0 ? pendingCorrection.fixes.join(", ") : "Text replaced.";
  requestId += 1;
  setSuggestion(null);
}

input.addEventListener("input", queueCorrection);
input.addEventListener("keydown", (event) => {
  if (event.key !== "Tab" || !pendingCorrection) {
    return;
  }

  event.preventDefault();
  applyCorrection();
});
input.addEventListener("blur", () => {
  window.clearTimeout(idleTimer);
  void window.tabFix.hideOverlay();
});

permissionsButton.addEventListener("click", async () => {
  const permissions = await window.tabFix.requestPermissions();
  permission.textContent = permissions.accessibility ? "Ready" : "Needs access";
  permission.dataset.state = permissions.accessibility ? "ready" : "blocked";
  permissionNote.textContent = permissions.note;
});

window.addEventListener("resize", () => {
  if (pendingCorrection) {
    positionHint();
  }
});

void window.tabFix.getState().then(renderState);
