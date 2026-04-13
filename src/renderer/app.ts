import "./styles.css";
import type { AppState, CorrectionResult, FixRunResult, PermissionState, TabFixApi } from "../shared/ipc";

declare global {
  interface Window {
    tabFix: TabFixApi;
  }
}

const sampleText = "wow this seem grast";
const idleDelayMs = 420;

const app = document.querySelector<HTMLDivElement>("#app");

if (!app) {
  throw new Error("Missing app root");
}

app.innerHTML = `
  <section class="shell">
    <header class="masthead">
      <div>
        <p class="eyebrow">Tab Fix</p>
        <h1>Type. Pause. Tab.</h1>
      </div>
      <div class="wordmark" aria-label="Tab Fix logo">
        <span>Tab</span>
        <kbd>Fix</kbd>
      </div>
    </header>

    <section class="composer" aria-label="Inline correction demo">
      <div class="field-wrap">
        <label for="preview-input">Write here</label>
        <textarea id="preview-input" spellcheck="false" autocomplete="off">${sampleText}</textarea>
        <div class="tab-hint" data-tab-hint hidden>
          <kbd>Tab</kbd>
          <span>Fix sentence</span>
        </div>
      </div>
      <div class="suggestion" data-suggestion hidden aria-live="polite">
        <span class="label">Suggested fix</span>
        <strong data-suggestion-text></strong>
      </div>
    </section>

    <section class="system-strip" aria-label="Prototype status">
      <div>
        <span class="label">macOS access</span>
        <strong data-permission>Loading</strong>
        <p data-permission-note>Checking macOS access.</p>
      </div>
      <div>
        <span class="label">Cross-app trigger</span>
        <strong data-trigger>Loading</strong>
        <p data-trigger-note>Checking hotkey state.</p>
      </div>
      <div>
        <span class="label">Last fix</span>
        <strong data-last-run>None yet</strong>
        <p data-last-run-note>Pause after typing, then press Tab.</p>
      </div>
    </section>

    <section class="panel-grid" aria-label="Menu bar panel">
      <article>
        <span class="label">Settings</span>
        <h2>Correction trigger</h2>
        <p>Show the Tab hint after a short pause, then apply the suggested fix when Tab is pressed.</p>
        <button type="button" data-permission-action>Request macOS access</button>
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
        <p>The real cross-app Tab experience needs a Swift helper for focused fields, caret bounds, and event taps.</p>
        <button type="button" disabled>Next build step</button>
      </article>
    </section>
  </section>
`;

const trigger = app.querySelector<HTMLElement>("[data-trigger]");
const triggerNote = app.querySelector<HTMLElement>("[data-trigger-note]");
const permission = app.querySelector<HTMLElement>("[data-permission]");
const permissionNote = app.querySelector<HTMLElement>("[data-permission-note]");
const lastRun = app.querySelector<HTMLElement>("[data-last-run]");
const lastRunNote = app.querySelector<HTMLElement>("[data-last-run-note]");
const previewInput = app.querySelector<HTMLTextAreaElement>("#preview-input");
const tabHint = app.querySelector<HTMLElement>("[data-tab-hint]");
const suggestion = app.querySelector<HTMLElement>("[data-suggestion]");
const suggestionText = app.querySelector<HTMLElement>("[data-suggestion-text]");
const permissionButton = app.querySelector<HTMLButtonElement>("[data-permission-action]");

function requireElement<T extends Element>(element: T | null, name: string): T {
  if (!element) {
    throw new Error(`Missing ${name}`);
  }

  return element;
}

const elements = {
  trigger: requireElement(trigger, "trigger"),
  triggerNote: requireElement(triggerNote, "trigger note"),
  permission: requireElement(permission, "permission"),
  permissionNote: requireElement(permissionNote, "permission note"),
  lastRun: requireElement(lastRun, "last run"),
  lastRunNote: requireElement(lastRunNote, "last run note"),
  previewInput: requireElement(previewInput, "preview input"),
  tabHint: requireElement(tabHint, "tab hint"),
  suggestion: requireElement(suggestion, "suggestion"),
  suggestionText: requireElement(suggestionText, "suggestion text"),
  permissionButton: requireElement(permissionButton, "permission button")
};

let pendingCorrection: CorrectionResult | null = null;
let idleTimer: number | undefined;
let correctionRequestId = 0;

function renderPermission(state: PermissionState): void {
  elements.permission.textContent = state.accessibility === "granted" ? "Ready" : "Needs access";
  elements.permission.dataset.state = state.accessibility === "granted" ? "ready" : "blocked";
  elements.permissionNote.textContent = state.note;
}

function renderRun(result?: FixRunResult): void {
  if (!result) {
    elements.lastRun.textContent = "None yet";
    elements.lastRun.dataset.state = "idle";
    elements.lastRunNote.textContent = "Select text in another app, then use the prototype trigger.";
    return;
  }

  elements.lastRun.textContent = result.ok ? `${result.durationMs}ms` : "Blocked";
  elements.lastRun.dataset.state = result.ok ? "ready" : "blocked";
  elements.lastRunNote.textContent = result.reason ?? result.correction?.fixes.join(", ") ?? "Text replaced.";
}

function renderState(state: AppState): void {
  elements.trigger.textContent = state.triggerAccelerator;
  elements.trigger.dataset.state = state.isFixing ? "busy" : "ready";
  elements.triggerNote.textContent =
    state.tabTriggerStatus === "prototype-trigger"
      ? `${state.triggerAccelerator} fixes selected text outside this window. Bare Tab needs the native helper.`
      : "Native Tab trigger is available.";

  renderPermission(state.permissionState);
  renderRun(state.lastRun);
}

function setInlineSuggestion(result: CorrectionResult | null): void {
  pendingCorrection = result?.changed ? result : null;

  if (!pendingCorrection) {
    elements.tabHint.hidden = true;
    elements.suggestion.hidden = true;
    return;
  }

  elements.tabHint.hidden = false;
  elements.suggestion.hidden = false;
  elements.suggestionText.textContent = pendingCorrection.output;
  positionHintNearCaret();
}

function positionHintNearCaret(): void {
  const textarea = elements.previewInput;
  const wrapRect = textarea.parentElement?.getBoundingClientRect();

  if (!wrapRect) {
    return;
  }

  const textareaRect = textarea.getBoundingClientRect();
  const styles = window.getComputedStyle(textarea);
  const mirror = document.createElement("div");
  const marker = document.createElement("span");
  const selectionStart = textarea.selectionStart;

  mirror.style.position = "absolute";
  mirror.style.visibility = "hidden";
  mirror.style.whiteSpace = "pre-wrap";
  mirror.style.overflowWrap = "break-word";
  mirror.style.boxSizing = "border-box";
  mirror.style.width = `${textareaRect.width}px`;
  mirror.style.minHeight = `${textareaRect.height}px`;
  mirror.style.padding = styles.padding;
  mirror.style.border = styles.border;
  mirror.style.font = styles.font;
  mirror.style.lineHeight = styles.lineHeight;
  mirror.style.letterSpacing = styles.letterSpacing;
  mirror.style.left = `${textareaRect.left}px`;
  mirror.style.top = `${textareaRect.top}px`;

  mirror.textContent = textarea.value.slice(0, selectionStart);
  marker.textContent = "\u200b";
  mirror.append(marker);
  document.body.append(mirror);

  const markerRect = marker.getBoundingClientRect();
  const hintRect = elements.tabHint.getBoundingClientRect();
  const left = markerRect.left - wrapRect.left;
  const top = markerRect.top - wrapRect.top - hintRect.height - 10 - textarea.scrollTop;
  const maxLeft = Math.max(12, textareaRect.width - hintRect.width - 18);

  elements.tabHint.style.left = `${Math.min(Math.max(left, 14), maxLeft)}px`;
  elements.tabHint.style.top = `${Math.max(top, 42)}px`;
  mirror.remove();
}

async function queueInlineCorrection(): Promise<void> {
  window.clearTimeout(idleTimer);
  setInlineSuggestion(null);

  const text = elements.previewInput.value;
  const requestId = correctionRequestId + 1;
  correctionRequestId = requestId;

  if (text.trim().length < 3) {
    return;
  }

  idleTimer = window.setTimeout(() => {
    void (async () => {
      const result = await window.tabFix.previewCorrection(text);

      if (requestId !== correctionRequestId || elements.previewInput.value !== text) {
        return;
      }

      setInlineSuggestion(result);
    })();
  }, idleDelayMs);
}

function applyInlineCorrection(): void {
  if (!pendingCorrection) {
    return;
  }

  elements.previewInput.value = pendingCorrection.output;
  elements.lastRun.textContent = `${pendingCorrection.durationMs}ms`;
  elements.lastRun.dataset.state = "ready";
  elements.lastRunNote.textContent =
    pendingCorrection.fixes.length > 0 ? pendingCorrection.fixes.join(", ") : "Text replaced.";
  setInlineSuggestion(null);
  correctionRequestId += 1;
}

async function refreshState(): Promise<void> {
  renderState(await window.tabFix.getState());
}

elements.previewInput.addEventListener("input", () => {
  void queueInlineCorrection();
});

elements.previewInput.addEventListener("keydown", (event) => {
  if (event.key !== "Tab" || !pendingCorrection) {
    return;
  }

  event.preventDefault();
  applyInlineCorrection();
});

elements.previewInput.addEventListener("blur", () => {
  window.clearTimeout(idleTimer);
});

elements.permissionButton.addEventListener("click", async () => {
  renderPermission(await window.tabFix.requestAccessibilityPermission());
});

elements.previewInput.addEventListener("click", () => {
  if (pendingCorrection) {
    positionHintNearCaret();
  }
});

elements.previewInput.addEventListener("keyup", () => {
  if (pendingCorrection) {
    positionHintNearCaret();
  }
});

window.tabFix.onStateChange(renderState);
void refreshState();
void queueInlineCorrection();
