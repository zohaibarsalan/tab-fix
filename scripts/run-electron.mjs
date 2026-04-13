import { spawn } from "node:child_process";

const env = { ...process.env };
delete env.ELECTRON_RUN_AS_NODE;

const child = spawn("npx", ["electron", "."], {
  stdio: "inherit",
  env
});

child.on("exit", (code) => {
  process.exit(code ?? 0);
});

