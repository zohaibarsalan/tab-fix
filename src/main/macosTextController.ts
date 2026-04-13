import { clipboard } from "electron";
import { execFile } from "node:child_process";
import { randomUUID } from "node:crypto";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

type SelectionReadResult =
  | {
      ok: true;
      text: string;
      previousClipboard: string;
    }
  | {
      ok: false;
      reason: string;
      previousClipboard: string;
    };

const copyScript = 'tell application "System Events" to keystroke "c" using command down';
const pasteScript = 'tell application "System Events" to keystroke "v" using command down';

function wait(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function runAppleScript(script: string): Promise<void> {
  await execFileAsync("/usr/bin/osascript", ["-e", script], {
    timeout: 1500
  });
}

export class MacosTextController {
  get isSupported(): boolean {
    return process.platform === "darwin";
  }

  async readSelectedText(): Promise<SelectionReadResult> {
    const previousClipboard = clipboard.readText();

    if (!this.isSupported) {
      return {
        ok: false,
        reason: "Selected-text replacement is currently only implemented for macOS.",
        previousClipboard
      };
    }

    const marker = `__TAB_FIX_EMPTY_SELECTION_${randomUUID()}__`;
    clipboard.writeText(marker);

    try {
      await runAppleScript(copyScript);
      await wait(140);
    } catch {
      clipboard.writeText(previousClipboard);

      return {
        ok: false,
        reason: "macOS blocked keyboard automation. Grant Accessibility permission to Tab Fix.",
        previousClipboard
      };
    }

    const selectedText = clipboard.readText();

    if (selectedText === marker || selectedText.length === 0) {
      clipboard.writeText(previousClipboard);

      return {
        ok: false,
        reason: "No selected text was found. This prototype fixes selected text first.",
        previousClipboard
      };
    }

    return {
      ok: true,
      text: selectedText,
      previousClipboard
    };
  }

  async replaceSelectedText(text: string, previousClipboard: string): Promise<void> {
    clipboard.writeText(text);
    await runAppleScript(pasteScript);
    await wait(120);
    clipboard.writeText(previousClipboard);
  }

  restoreClipboard(text: string): void {
    clipboard.writeText(text);
  }
}
