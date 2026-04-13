import "./overlay.css";
import type { OverlayPayload, TabFixApi } from "../shared/ipc";

declare global {
  interface Window {
    tabFix: TabFixApi;
  }
}

const root = document.querySelector<HTMLDivElement>("#overlay");

if (!root) {
  throw new Error("Missing overlay root");
}

root.innerHTML = `
  <div class="bubble">
    <kbd>Tab</kbd>
    <span data-text>Fix sentence</span>
  </div>
`;

const text = root.querySelector<HTMLElement>("[data-text]");

window.tabFix.onOverlayPayload((payload: OverlayPayload) => {
  if (text) {
    text.textContent = payload.text ?? "Fix sentence";
  }
});

