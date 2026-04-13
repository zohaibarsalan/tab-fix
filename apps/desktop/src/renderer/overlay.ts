import "./overlay.css";

const root = document.querySelector<HTMLDivElement>("#overlay");

if (!root) {
  throw new Error("Missing overlay root");
}

root.innerHTML = `
  <div class="bubble">
    <kbd>Tab</kbd>
  </div>
`;
