import "./styles.css";
import type { AppState, CorrectionResult, FixRunResult, PermissionState, TabFixApi } from "../shared/ipc";

declare global {
  interface Window {
    tabFix: TabFixApi;
  }
}

const sampleText = "i dont think this are right";

const app = document.querySelector<HTMLDivElement>("#app");

if (!app) {
  throw new Error("Missing app root");
}

app.innerHTML = `
  <section class="shell">
    <header class="masthead">
      <div>
        <p class="eyebrow">macOS prototype</p>
        <h1>Fix the sentence where it lives.</h1>
      </div>
      <div class="wordmark" aria-label="Tab Fix logo">
        <span>Tab</span>
        <kbd>Fix</kbd>
      </div>
    </header>

    <section class="status-grid" aria-label="Application status">
      <article class="status-panel">
        <span class="label">Trigger</span>
        <strong data-trigger>Loading</strong>
        <p data-trigger-note>Checking hotkey state.</p>
      </article>
      <article class="status-panel">
        <span class="label">Permission</span>
        <strong data-permission>Loading</strong>
        <p data-permission-note>Checking macOS access.</p>
      </article>
      <article class="status-panel">
        <span class="label">Last run</span>
        <strong data-last-run>None yet</strong>
        <p data-last-run-note>Select text in another app, then use the prototype trigger.</p>
      </article>
    </section>

    <section class="workbench">
      <div class="copy">
        <p class="eyebrow">local engine</p>
        <h2>Correction pipeline</h2>
        <p>
          The first build uses a tiny local rule engine so the app loop is real before a model backend is added.
        </p>
      </div>

      <div class="tester" aria-label="Correction preview">
        <label for="preview-input">Preview text</label>
        <textarea id="preview-input" spellcheck="false">${sampleText}</textarea>
        <div class="actions">
          <button type="button" data-preview>Preview fix</button>
          <button type="button" data-run-selected>Fix selected text now</button>
          <button type="button" class="secondary" data-permission-action>Grant macOS access</button>
        </div>
        <output data-preview-output aria-live="polite"></output>
      </div>
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
const previewButton = app.querySelector<HTMLButtonElement>("[data-preview]");
const runSelectedButton = app.querySelector<HTMLButtonElement>("[data-run-selected]");
const permissionButton = app.querySelector<HTMLButtonElement>("[data-permission-action]");
const previewOutput = app.querySelector<HTMLOutputElement>("[data-preview-output]");

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
  previewButton: requireElement(previewButton, "preview button"),
  runSelectedButton: requireElement(runSelectedButton, "run selected button"),
  permissionButton: requireElement(permissionButton, "permission button"),
  previewOutput: requireElement(previewOutput, "preview output")
};

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
      ? "Prototype trigger. Bare Tab needs the native event tap helper."
      : "Native Tab trigger is available.";

  renderPermission(state.permissionState);
  renderRun(state.lastRun);

  elements.runSelectedButton.disabled = state.isFixing;
  elements.runSelectedButton.textContent = state.isFixing ? "Fixing..." : "Fix selected text now";
}

function renderCorrection(result: CorrectionResult): void {
  const fixes = result.fixes.length > 0 ? result.fixes.join(", ") : "No changes needed";

  elements.previewOutput.innerHTML = `
    <span>${fixes}</span>
    <strong>${result.output}</strong>
    <small>${result.durationMs}ms local pass</small>
  `;
}

async function refreshState(): Promise<void> {
  renderState(await window.tabFix.getState());
}

elements.previewButton.addEventListener("click", async () => {
  const result = await window.tabFix.previewCorrection(elements.previewInput.value);
  renderCorrection(result);
});

elements.runSelectedButton.addEventListener("click", async () => {
  const result = await window.tabFix.runSelectedTextFix();
  renderRun(result);
  await refreshState();
});

elements.permissionButton.addEventListener("click", async () => {
  renderPermission(await window.tabFix.requestAccessibilityPermission());
});

window.tabFix.onStateChange(renderState);
void refreshState();
