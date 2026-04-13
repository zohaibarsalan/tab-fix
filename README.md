<p align="center">
  <img src="apps/desktop/assets/tab-fix-logo.svg" alt="Tab Fix logo" width="112" height="112">
</p>

<h1 align="center">Tab Fix</h1>

<p align="center">
  Fix the sentence you are typing with one press of <kbd>Tab</kbd>.
</p>

<p align="center">
  <code>v0.1.0</code> - macOS prototype
</p>

<p align="center">
  <a href="https://github.com/zohaibarsalan/tab-fix/releases">Download</a>
  ·
  <a href="#how-it-works">How It Works</a>
  ·
  <a href="#roadmap">Roadmap</a>
</p>

## Overview

Tab Fix is a macOS writing assistant for quick, in-place cleanup. Type naturally, pause for the hint, then press `Tab` to fix the current sentence without opening a chat box or rewriting your whole paragraph.

```text
i dont think this are right -> I don't think this is right.
```

Tab Fix is designed to stay out of the way. It lives in the menu bar, watches only the focused text field, and applies conservative edits that preserve what you meant to say.

## Download

The current release is:

```text
Tab Fix v0.1.0
macOS Apple Silicon
```

Download the latest `.dmg` from the GitHub Releases page:

https://github.com/zohaibarsalan/tab-fix/releases

Open the DMG, drag `Tab Fix.app` into Applications, then launch it from Applications.

Because this is an early prototype, macOS may ask you to allow the app on first launch. If it does, right-click `Tab Fix.app`, choose `Open`, and confirm.

## How It Works

1. Type in a text field.
2. Pause for a moment.
3. A small `Tab` hint appears near the cursor.
4. Press plain `Tab`.
5. Tab Fix replaces the current sentence in place.

The first version focuses on small, useful corrections:

- Spelling
- Capitalization
- Punctuation
- Repeated spaces
- Common contractions
- Basic agreement errors

## Permissions

Tab Fix needs macOS Accessibility access to read the active text field, place the hint near the cursor, detect plain `Tab`, and replace text.

Tab Fix should only read the smallest useful text range when a correction is needed. Raw user text should not be logged by default.

## Current Status

Tab Fix is an early macOS prototype. It works best in native macOS text fields such as Notes and TextEdit.

Browser and editor support is improving, but some apps expose text through Accessibility in unusual ways. Chrome, ChatGPT, T3 Code, VS Code, Slack, Discord, Safari, Messages, and Mail are the main compatibility targets.

## Roadmap

Near term:

- Stronger Chrome, ChatGPT, and code editor support
- Better diagnostics for failed replacements
- More reliable caret positioning across displays
- Excluded apps and websites
- A local user dictionary for names, products, slang, and words to ignore

Later:

- Optional model-powered corrections
- Local-first settings and dictionary storage
- Optional sync for preferences and dictionary entries
- Per-app trigger behavior
- Stronger privacy controls for sensitive apps and websites

## Project

Tab Fix is built with Electron for the app shell and Swift for the native macOS text integration.

```text
apps/desktop
  Electron app, menu bar UI, settings window, overlay, IPC bridge

native/macos
  Swift helper, Accessibility integration, event tap, text replacement
```
