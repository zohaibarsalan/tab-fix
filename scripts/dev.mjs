import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { setTimeout as wait } from "node:timers/promises";
import net from "node:net";

const children = new Set();

function run(command, args, options = {}) {
  const child = spawn(command, args, {
    stdio: "inherit",
    shell: false,
    ...options
  });

  children.add(child);
  child.on("exit", () => children.delete(child));
  return child;
}

function isPortOpen(port) {
  return new Promise((resolve) => {
    const socket = net.createConnection({ host: "127.0.0.1", port });
    socket.on("connect", () => {
      socket.end();
      resolve(true);
    });
    socket.on("error", () => resolve(false));
  });
}

async function waitForDevServer(port) {
  for (let index = 0; index < 120; index += 1) {
    if (await isPortOpen(port)) return;
    await wait(250);
  }

  throw new Error(`Timed out waiting for Vite on port ${port}`);
}

async function waitForMainBuild() {
  for (let index = 0; index < 120; index += 1) {
    if (existsSync("dist/desktop/main/main.js") && existsSync("dist/desktop/main/preload.js")) return;
    await wait(250);
  }

  throw new Error("Timed out waiting for Electron main build");
}

function shutdown() {
  for (const child of children) {
    child.kill("SIGTERM");
  }
}

process.on("SIGINT", () => {
  shutdown();
  process.exit(0);
});

process.on("SIGTERM", () => {
  shutdown();
  process.exit(0);
});

run("npm", ["run", "build:main", "--", "--watch", "--preserveWatchOutput"]);
run("npx", ["vite", "--config", "apps/desktop/vite.config.ts", "--host", "127.0.0.1"]);

await Promise.all([waitForMainBuild(), waitForDevServer(5173)]);

const electronEnv = {
  ...process.env,
  TAB_FIX_DEV_SERVER_URL: "http://127.0.0.1:5173"
};

delete electronEnv.ELECTRON_RUN_AS_NODE;

const electronProcess = run("npx", ["electron", "."], {
  env: electronEnv
});

electronProcess.on("exit", (code) => {
  shutdown();
  process.exit(code ?? 0);
});

