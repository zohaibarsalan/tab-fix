# Tab Fix

Tab Fix is a fast, lightweight writing-assist app that fixes grammar, spelling, punctuation, and sentence clarity in the text field you are currently editing.

The core interaction is simple:

1. Type anywhere on your computer.
2. Pause for a moment.
3. A small `Tab` hint appears near the cursor or text field.
4. Press `Tab`.
5. The sentence is fixed instantly in place.

The first version is focused on macOS. The long-term direction is a cross-platform desktop app.

## Product Goal

Tab Fix should feel like a native system feature, not a heavy assistant window.

It should work inside browsers, notes apps, chat apps, code editors, email clients, Electron apps, and normal native text fields. The user should not need to copy text into another app, open a popup, or think about prompts.

The product succeeds if pressing `Tab` feels faster than manually correcting the sentence.

## Product Shape

Tab Fix should live in the macOS menu bar.

Clicking the menu bar item opens the Tab Fix panel with:

- Status.
- Settings.
- macOS permission state.
- Custom dictionary later.
- Account/sync later.

The writing interaction itself should not require opening the panel. The panel is for control and configuration; the product experience happens inside the text field the user is already using.

## Why Electron

Electron is acceptable for this project if the app is built with strict performance discipline.

Electron gives Tab Fix:

- Fast product iteration.
- A mature desktop packaging story.
- A path to Windows and Linux later.
- Access to a large JavaScript and native-module ecosystem.
- A UI stack that can still be very fast when kept small.

The app should not behave like a bloated Electron app. The main process should do system integration work, the renderer should be minimal, and background work should be isolated.

## MVP

The first milestone is not sync, billing, accounts, or a complex settings screen.

The MVP is:

- Global `Tab` trigger while editing text.
- Detect the active text field.
- Read selected text or the current sentence around the cursor.
- Send only the needed text to the correction engine.
- Replace the original text in place.
- Preserve the user's intent, tone, and meaning.
- Keep latency low enough that the interaction feels instant.
- Provide a small settings window for enabling/disabling Tab Fix and configuring behavior.

## Core Interaction

Tab Fix should use this priority order:

1. Watch the active editable field after the user types.
2. After a short pause, inspect the current sentence around the cursor.
3. If a useful correction exists, show a small `Tab` hint near the cursor or top edge of the writing box.
4. If the user presses `Tab`, apply the correction in place.
5. If text is selected, fix the selected text instead.
6. If the current app cannot be controlled safely, do nothing and optionally show a subtle failure state.

The app should avoid surprising the user. Pressing `Tab` should only rewrite text when Tab Fix is confident it is inside an editable field.

## macOS Architecture

The macOS app will likely need a hybrid approach:

- Electron for app shell, settings, onboarding, updates, billing UI, and cross-platform structure.
- Native macOS integration for accessibility, keyboard monitoring, active app detection, text extraction, and text replacement.
- A local service layer for correction requests, caching, dictionary rules, and future sync.

Expected macOS permissions:

- Accessibility permission to inspect and manipulate focused text fields.
- Input Monitoring permission if global key interception requires it.

The app should explain these permissions clearly during onboarding because they are sensitive and required for the product to work.

## Suggested Process Model

```text
Electron main process
  - App lifecycle
  - Global shortcut coordination
  - Native bridge orchestration
  - Settings storage
  - Correction request routing

Renderer process
  - Settings UI
  - Onboarding
  - Account/sync UI later

Native macOS helper
  - Active app detection
  - Focused editable element detection
  - Selection/cursor text extraction
  - In-place text replacement
  - Permission checks

Correction engine
  - Fast grammar/spelling rewrite
  - User dictionary
  - Local cache
  - Optional cloud model/API
```

## Performance Requirements

Tab Fix should be designed around latency from day one.

Target behavior:

- Hotkey handling should feel immediate.
- The app should idle with very low CPU usage.
- The renderer should not stay busy in the background.
- Startup should be fast.
- Memory usage should stay boring.
- Correction should stream or return quickly enough that the replacement feels instant.

Engineering rules:

- Keep the renderer small.
- Avoid large frontend frameworks unless the UI actually needs them.
- Lazy-load nonessential UI.
- Do not run polling loops for active text detection.
- Prefer event-driven native hooks where possible.
- Keep correction payloads small by sending selected text or sentence context, not whole documents.
- Cache repeat corrections where safe.
- Measure latency before adding features.

## Correction Behavior

Tab Fix should fix the text without changing the writer's voice.

Good correction:

```text
Input:  i dont think this are right
Output: I don't think this is right.
```

Bad correction:

```text
Input:  i dont think this are right
Output: I strongly believe this is incorrect and should be reconsidered.
```

The default mode should be conservative:

- Fix spelling.
- Fix grammar.
- Fix punctuation.
- Improve awkward sentence issues only when the intent is clear.
- Do not rewrite aggressively.
- Do not add new claims.
- Do not change tone unless the user asks for that later.

## Dictionary

The dictionary is a core product feature.

Examples:

- Names.
- Company terms.
- Slang.
- Product names.
- User-preferred spellings.
- Words that should never be autocorrected.

Free version:

- Dictionary stored locally on one device.
- No account required.
- No sync.

Paid version:

- Dictionary sync across devices.
- Account-based backup and restore.
- Future advanced writing features.

## Free And Paid Direction

The free version should be useful on its own. The paid version should add convenience and power without making the base product feel broken.

Possible free features:

- Local correction.
- Local dictionary.
- Basic settings.
- One-device usage.

Possible paid features:

- Dictionary sync.
- Multi-device settings sync.
- Team or work vocabulary later.
- Advanced rewrite modes.
- Custom tone presets.
- Higher usage limits if using a cloud correction backend.

Billing should not be part of the first milestone.

## Privacy Principles

Tab Fix will touch sensitive text, so privacy needs to be part of the product design.

Principles:

- Only read text when the user presses the trigger.
- Send the smallest useful text range for correction.
- Do not log raw user text by default.
- Make cloud processing explicit if used.
- Keep the user dictionary local for the free version.
- Make sync opt-in for paid users.
- Provide excluded apps or domains.

## Open Technical Questions

The most important early research is macOS text control reliability.

Questions to answer:

- Can Accessibility APIs reliably read and replace selected text across common apps?
- Which apps need pasteboard fallback behavior?
- Can `Tab` be intercepted without breaking normal tab navigation?
- Should the default trigger be `Tab`, `Option+Tab`, or configurable?
- How do we detect when the focused element is editable?
- How do we avoid triggering inside code indentation contexts?
- What is the fastest acceptable correction backend for the MVP?
- Should the first correction engine be local, cloud, or hybrid?

## Early Implementation Plan

1. Build a macOS proof of concept that can detect the focused app and focused editable field.
2. Add a global trigger and confirm it only runs in editable text contexts.
3. Implement selected-text extraction and replacement.
4. Add current-sentence extraction when no text is selected.
5. Wire a basic correction engine.
6. Add a minimal Electron settings window.
7. Add permission onboarding.
8. Test across Safari, Chrome, Arc, Notes, Messages, Slack, Discord, VS Code, Apple Mail, and common Electron apps.

## Tech Direction

Likely stack:

- Electron
- TypeScript
- Vite for renderer builds
- Native macOS helper written in Swift or Objective-C
- Node native bridge where needed
- SQLite or local JSON storage for settings and dictionary
- Auto-update support later

The repo should stay modular so Windows and Linux can get their own native helpers later without rewriting the whole app.

Suggested future layout:

```text
apps/desktop
  Electron app

packages/native-macos
  macOS accessibility and text replacement helper

packages/correction
  Correction engine interface and providers

packages/dictionary
  Local dictionary storage and matching

packages/shared
  Shared types and utilities
```

## Running Locally

Install dependencies:

```bash
npm install
```

Run the desktop app in development:

```bash
npm run dev
```

Create a production build:

```bash
npm run build
```

Run typechecks:

```bash
npm run typecheck
```

## Current Prototype

The repo now contains a working Electron + TypeScript desktop scaffold.

Implemented:

- Electron main process.
- macOS menu bar item.
- Secure preload bridge.
- Lightweight TypeScript renderer.
- Local correction service.
- Rule-based correction engine for the first app loop, including a small common-misspelling layer.
- macOS selected-text read/replace prototype using copy/paste automation.
- Global prototype trigger.
- Permission/status UI.
- Settings and dictionary placeholders.

Current in-app prototype:

```text
Type -> pause -> Tab hint appears -> press Tab -> sentence is fixed
```

Current cross-app trigger:

```text
Alt+Tab
```

The final product should support bare `Tab`, but that should be handled by a native macOS event tap/helper instead of Electron's global shortcut API. The prototype trigger exists so the correction loop can be tested immediately without pretending the hard part is solved.

The cross-app product target is:

1. User types in any editable field.
2. Native helper detects a pause and reads the current sentence around the caret.
3. Correction engine prepares a fix.
4. A tiny overlay appears near the caret or text field with `Tab`.
5. Native helper intercepts `Tab` only while the fix is available.
6. Native helper replaces the sentence in place.

Electron should own the menu bar panel, settings, dictionary UI, account UI, update flow, and cross-platform app shell. Native helpers should own OS-level text control.

Current cross-app selected-text flow:

1. User selects text in another app.
2. User presses the prototype trigger.
3. Tab Fix copies the selected text.
4. Tab Fix runs the local correction engine.
5. Tab Fix pastes the fixed text back.
6. Tab Fix restores the previous clipboard text.

This requires macOS Accessibility permission.

## Development Status

This project has moved from product definition to the first desktop prototype.

Next step: replace the copy/paste prototype with a native macOS helper that can detect editable fields, read the current sentence when no text is selected, and safely support the real `Tab` interaction.

## Non-Goals For The First Version

- Full document rewriting.
- Complex AI chat UI.
- Team collaboration.
- Browser extension support.
- Billing.
- Account system.
- Cross-platform support.
- Heavy settings and customization.

Those can come later. The first version should prove the core magic: press `Tab`, fix the text, stay out of the way.
