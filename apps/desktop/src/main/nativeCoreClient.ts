import { spawn, execFile, type ChildProcessWithoutNullStreams } from "node:child_process";
import { EventEmitter } from "node:events";
import path from "node:path";
import { promisify } from "node:util";
import type { CorrectionResult, NativeHelperEvent, NativeStatus, PermissionState } from "../shared/ipc";

const execFileAsync = promisify(execFile);

function repoRoot(): string {
  return process.cwd();
}

export function nativeBinaryPath(): string {
  return path.join(repoRoot(), "native/macos/.build/debug/TabFixNative");
}

export class NativeCoreClient extends EventEmitter {
  private readonly binaryPath = nativeBinaryPath();
  private helperProcess: ChildProcessWithoutNullStreams | null = null;
  private stdoutBuffer = "";

  startHelper(): void {
    if (this.helperProcess) {
      return;
    }

    const child = spawn(this.binaryPath, ["serve"], {
      stdio: ["pipe", "pipe", "pipe"]
    });

    this.helperProcess = child;

    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => {
      this.stdoutBuffer += chunk;

      let newlineIndex = this.stdoutBuffer.indexOf("\n");
      while (newlineIndex >= 0) {
        const line = this.stdoutBuffer.slice(0, newlineIndex).trim();
        this.stdoutBuffer = this.stdoutBuffer.slice(newlineIndex + 1);

        if (line.length > 0) {
          this.emitNativeLine(line);
        }

        newlineIndex = this.stdoutBuffer.indexOf("\n");
      }
    });

    child.stderr.setEncoding("utf8");
    child.stderr.on("data", (chunk: string) => {
      this.emit("event", {
        type: "error",
        message: chunk.trim()
      } satisfies NativeHelperEvent);
    });

    child.on("exit", (code) => {
      this.helperProcess = null;
      this.emit("event", {
        type: "error",
        message: `Native helper exited with code ${code ?? 0}.`
      } satisfies NativeHelperEvent);
    });
  }

  stopHelper(): void {
    this.helperProcess?.kill("SIGTERM");
    this.helperProcess = null;
  }

  async status(): Promise<NativeStatus> {
    return this.runJson<NativeStatus>(["status"]);
  }

  async requestPermissions(): Promise<PermissionState> {
    return this.runJson<PermissionState>(["request-permissions"]);
  }

  async correct(text: string): Promise<CorrectionResult> {
    return this.runJson<CorrectionResult>(["correct", text]);
  }

  private async runJson<T>(args: string[]): Promise<T> {
    const { stdout } = await execFileAsync(this.binaryPath, args, {
      timeout: 5000,
      maxBuffer: 1024 * 1024
    });

    return JSON.parse(stdout) as T;
  }

  private emitNativeLine(line: string): void {
    try {
      this.emit("event", JSON.parse(line) as NativeHelperEvent);
    } catch {
      this.emit("event", {
        type: "error",
        message: `Invalid native helper event: ${line}`
      } satisfies NativeHelperEvent);
    }
  }
}
