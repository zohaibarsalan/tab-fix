# Tab Fix

Tab Fix is a macOS writing-assist app built around one interaction:

1. Type in any text field.
2. Pause for a moment.
3. A small `Tab` hint appears near the cursor or writing box.
4. Press `Tab`.
5. The sentence is fixed in place.

The app is intentionally split into two parts:

```text
Electron app
  Product shell, menu bar UI, settings, dictionary UI, onboarding, overlay rendering

Swift native core
  macOS Accessibility, focused text fields, caret bounds, Tab event tap, replacement
```

Electron gives us the visual quality and iteration speed we want. Swift gives us the macOS authority needed for the cross-app text interaction.

## Current Prototype

Implemented:

- Electron desktop shell.
- macOS menu bar item.
- Brutalist settings/panel UI.
- Transparent always-on-top overlay window for the `Tab` bubble.
- Secure preload bridge.
- IPC boundary between Electron and the native layer.
- Swift native command service.
- Swift long-running helper service.
- Accessibility permission status/request hook.
- Cross-app focused text inspection MVP.
- Cross-app `Tab` event tap MVP.
- Cross-app AX replacement with paste fallback.
- System spellchecker-backed spelling suggestions.
- Basic grammar, punctuation, and agreement fixes.
- Settings, Dictionary, and Native Helper placeholder sections.

Current cross-app support is an MVP. It starts a long-running Swift helper, watches typing globally, inspects the focused accessibility element after a short pause, asks Electron to show the overlay, intercepts `Tab` while a candidate is active, and attempts replacement.

Expected limitations:

- Some apps expose text through Accessibility cleanly.
- Some browser/editor surfaces expose partial text or no writable AX value.
- Some apps will require per-app fallback behavior.
- The paste fallback briefly uses the clipboard, then restores it.
- Accessibility permission must be granted, and the app should be restarted after granting it.

Example:

```text
i dont think this are right -> I don't think this is right.
```

The spelling layer is intentionally not a hardcoded typo table. It uses macOS spellchecker suggestions for obvious misspellings. Contextual vocabulary fixes like `grast -> great` need a stronger language model/provider because system spellcheck may suggest other valid nearby words without understanding sentence meaning.

## Running Locally

Install dependencies:

```bash
npm install
```

Run the app:

```bash
npm run dev
```

For cross-app testing, click `Request macOS access`. The app opens macOS Accessibility settings. In development, macOS may list `Electron`, `TabFixNative`, or the terminal/dev tool that launched the helper. Enable the relevant entries, then quit and rerun `npm run dev`.

Build everything:

```bash
npm run build
```

Typecheck Electron code:

```bash
npm run typecheck
```

Build only the native core:

```bash
npm run build:native
```

Call the native core directly:

```bash
native/macos/.build/debug/TabFixNative status
native/macos/.build/debug/TabFixNative correct "i dont think this are right"
```

## Project Layout

```text
apps/desktop
  Electron app shell
  menu bar panel
  transparent overlay renderer
  IPC client for the Swift native core

native/macos
  Swift command service
  Accessibility permission checks
  system spellchecker-backed correction
  future focused-field/caret/event-tap implementation
```

## Electron App

Electron owns the product experience:

- Beautiful brutalist panel.
- Menu bar app.
- Onboarding and permission screens.
- Settings.
- Personal dictionary later.
- Account/sync later.
- Overlay rendering for the correction bubble.
- IPC coordination with the native layer.

Electron can render the small `Tab` bubble as a transparent, always-on-top, click-through window. It should not own the macOS text-control logic.

## Swift Native Core

Swift owns the macOS integration layer:

- Accessibility permission check.
- Focused text field detection.
- Caret and text-range bounds.
- Current word/sentence extraction.
- AX observers where reliable.
- Lightweight fallback polling where needed.
- Key event tap for `Tab`.
- In-place replacement.
- Per-app fallback logic.

The Swift service supports both one-shot commands and a long-running `serve` mode. Electron starts `serve` on launch and listens for JSON-line events from the native helper.

## Target Runtime Flow

```text
User types in any app
  -> Swift detects focused editable field and current sentence
  -> Swift sends text + caret bounds to Electron
  -> Electron runs correction provider
  -> Electron shows the Tab overlay near the caret
  -> Swift intercepts Tab only while the overlay is active
  -> Swift replaces the text in place
  -> Electron hides overlay and updates status
```

## Correction Behavior

The default correction should be conservative.

Good:

```text
Input:  wow this seem grast
Output: Wow, this seems great.
```

Bad:

```text
Input:  wow this seem grast
Output: I am highly impressed because this appears to be excellent.
```

Default rules:

- Fix spelling.
- Fix grammar.
- Fix punctuation.
- Preserve the writer's voice.
- Do not add new claims.
- Do not rewrite aggressively.
- Do not change tone unless the user asks for that later.

## Dictionary

The dictionary is a core product feature, but it is not implemented yet.

It should eventually handle:

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

## Privacy Principles

Tab Fix will touch sensitive text, so privacy needs to be part of the product design.

Principles:

- Only read text when needed for a correction.
- Send the smallest useful text range.
- Do not log raw user text by default.
- Make cloud processing explicit if used.
- Keep the dictionary local for the free version.
- Make sync opt-in for paid users.
- Provide excluded apps or domains.

## Next Build Step

The next milestone is hardening the cross-app native helper across real apps.

Build in this order:

1. Add structured diagnostics for focused app, role, AX attributes, and replacement strategy.
2. Improve editable-element detection so buttons/forms/tables are ignored.
3. Improve caret coordinate conversion across multiple displays.
4. Add per-app fallbacks for Safari, Chrome, Arc, Notes, Messages, Slack, Discord, VS Code, Apple Mail, and ChatGPT.
5. Move correction requests from Swift-only to Electron/provider orchestration for future model support.
6. Add settings for excluded apps and trigger behavior.

## Non-Goals For The First Version

- Full document rewriting.
- Complex AI chat UI.
- Team collaboration.
- Browser extension support.
- Billing.
- Account system.
- Cross-platform support.
- Heavy settings and customization.

Those can come later. The first version should prove the core magic: type, pause, press `Tab`, and fix the sentence in place.
