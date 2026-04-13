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
- Accessibility permission status/request hook.
- System spellchecker-backed spelling suggestions.
- Basic grammar, punctuation, and agreement fixes.
- Settings, Dictionary, and Native Helper placeholder sections.

Not implemented yet:

- Cross-app `Tab` interception.
- Focused text field detection in other apps.
- Caret-bound overlay positioning in other apps.
- In-place replacement in other apps.

Today, the panel demonstrates the interaction and talks to the Swift native core for permissions and corrections. Running inside Safari, Chrome, ChatGPT, Notes, Slack, etc. requires the next native-helper milestone below.

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

The current Swift service is command-based. It is enough for permission checks and correction calls. The next version should become a long-running native helper so Electron can receive events like focused-field changes, caret movement, and correction availability without spawning a process per request.

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

The next milestone is the real cross-app native helper.

Build in this order:

1. Convert the Swift command service into a long-running helper process.
2. Add focused app and focused accessibility element detection.
3. Confirm whether the focused element is editable.
4. Read selected text from common apps.
5. Read the current sentence around the caret when no text is selected.
6. Get caret bounds and position the Electron overlay near the cursor.
7. Add a global event tap for `Tab`.
8. Intercept `Tab` only while a correction is visible.
9. Replace the sentence in place.
10. Test Safari, Chrome, Arc, Notes, Messages, Slack, Discord, VS Code, Apple Mail, and ChatGPT.

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
