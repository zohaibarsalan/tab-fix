<p align="center">
  <img src="apps/desktop/assets/tab-fix-logo.svg" alt="Tab Fix logo" width="104" height="104">
</p>

<h1 align="center">Tab Fix</h1>

<p align="center">
  A macOS writing assistant that fixes the sentence you are typing when you press <kbd>Tab</kbd>.
</p>

<p align="center">
  <code>v0.1.0</code> - macOS prototype
</p>

## What It Does

Tab Fix watches the text field you are actively typing in. When it finds a conservative correction, it shows a small `Tab` hint near the cursor. Press `Tab` to replace the current sentence in place.

Example:

```text
i dont think this are right -> I don't think this is right.
```

The current correction engine focuses on simple, low-risk fixes:

- Spelling
- Capitalization
- Punctuation
- Repeated spaces
- Common contractions
- Basic agreement errors

## Current Status

Tab Fix is an early macOS prototype. It works best in native text fields such as Notes and TextEdit. Support is improving for browser and editor surfaces such as Chrome, ChatGPT, and code editors.

Implemented:

- Menu bar app
- Desktop settings window
- `Tab` hint overlay
- Swift native helper for macOS Accessibility
- Focused text detection
- Plain-Tab replacement trigger
- Clipboard fallback for fields that reject direct Accessibility replacement
- Local correction engine using macOS spellchecking plus rule-based cleanup

Known limitations:

- Some web apps expose text through Accessibility inconsistently.
- Browser editors and code editors may require per-app fallback behavior.
- The clipboard fallback briefly uses the clipboard, then restores the previous text.
- Accessibility permission is required, and the app should be restarted after permission changes.

## Install And Run

Install dependencies:

```bash
npm install
```

Run in development:

```bash
npm run dev
```

Build and open a local macOS app bundle:

```bash
npm run pack:mac
npm run open:mac
```

Build a DMG:

```bash
npm run dist:mac
```

## Permissions

Tab Fix needs macOS Accessibility access so the native helper can inspect the focused text field, place the hint near the cursor, intercept plain `Tab`, and replace text.

In development, macOS may show `Electron`, `TabFixNative`, or the terminal app that launched the helper. Enable the relevant entries, then quit and reopen Tab Fix.

## Useful Commands

```bash
npm run typecheck
npm run build
npm run build:native
native/macos/.build/debug/TabFixNative status
native/macos/.build/debug/TabFixNative correct "i dont think this are right"
```

## Roadmap

Near term:

- Harden Chrome, ChatGPT, T3 Code, VS Code, Slack, Discord, Messages, Mail, and Safari support.
- Add diagnostics for focused app, role, text range, replacement method, and failure reason.
- Improve caret positioning across multiple displays and browser coordinate systems.
- Add excluded apps and domains.
- Add a user dictionary for names, products, slang, and words that should never be corrected.

Later:

- Better grammar and rewrite quality through an optional model provider.
- Local-first settings and dictionary storage.
- Optional account sync for dictionary and preferences.
- Per-app trigger behavior.
- Stronger privacy controls for sensitive apps and websites.

## Privacy Direction

Tab Fix should only read the smallest useful text range, only when a correction is needed, and should not log raw user text by default. Cloud processing, if added later, should be explicit and opt-in.

## Project Structure

```text
apps/desktop
  Electron app, menu bar UI, settings window, overlay, IPC bridge

native/macos
  Swift helper, Accessibility integration, event tap, text replacement
```
