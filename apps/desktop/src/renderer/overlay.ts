import "./overlay.css";

const root = document.querySelector<HTMLDivElement>("#overlay");

if (!root) {
  throw new Error("Missing overlay root");
}

root.innerHTML = `
  <div class="bubble">
    <span data-label>Fix sentence</span>
    <kbd>Tab</kbd>
  </div>
`;

const label = root.querySelector<HTMLElement>("[data-label]");
const key = root.querySelector<HTMLElement>("kbd");

window.tabFix.onOverlayPayload((payload) => {
  if (label) {
    label.textContent = payload.label ?? "Fix sentence";
  }

  if (key) {
    key.textContent = payload.text ?? "Tab";
  }
});
