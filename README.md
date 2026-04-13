# Tab Fix

Tab Fix is a native macOS writing-assist app that fixes grammar, spelling, punctuation, and sentence issues with one keypress.

The target interaction:

1. Type in any text field.
2. Pause for a moment.
3. A small `Tab` hint appears near the cursor or writing box.
4. Press `Tab`.
5. The sentence is fixed in place.

The app now uses Swift and AppKit instead of Electron. That gives us the right foundation for the real macOS behavior: Accessibility APIs, keyboard event taps, caret bounds, focused text fields, and menu bar integration.

## Current Prototype

The current app is a native Swift/AppKit prototype.

Implemented:

- macOS menu bar app.
- Native settings/panel window.
- Same visual theme as the earlier prototype.
- Writing surface with pause detection.
- Floating `Tab` hint inside the app.
- Press `Tab` to apply the suggested fix.
- Local correction engine.
- System spellchecker-backed spelling suggestions.
- Basic agreement fixes, including `this seem -> this seems`.
- Basic punctuation fixes.
- Accessibility permission request hook.
- Placeholder sections for Settings, Dictionary, and Native Helper.

Example corrections:

```text
i dont think this are right -> I don't think this is right.
```

The spelling layer should not be a hardcoded typo table. The current prototype uses macOS spellchecker suggestions for obvious misspellings. Contextual vocabulary fixes like `grast -> great` need a stronger language model/provider because the system spellchecker may suggest other valid nearby words without understanding sentence meaning.

## Running Locally

Build:

```bash
swift build
```

Run:

```bash
swift run TabFix
```

The app runs as a menu bar app. Look for `Tab Fix` in the macOS menu bar. The panel also opens on launch during development.

## Product Shape

Tab Fix should live in the macOS menu bar.

Clicking the menu bar item opens the panel for:

- Status.
- Settings.
- macOS permission state.
- Custom dictionary later.
- Account/sync later.

The writing interaction itself should not require opening this panel. The panel is for control and configuration; the product experience happens inside the text field the user is already using.

## Core Interaction

The final product should work like this:

1. Watch the active editable field after the user types.
2. After a short pause, inspect the current sentence around the cursor.
3. If a useful correction exists, show a small `Tab` hint near the caret or top edge of the writing box.
4. If the user presses `Tab`, apply the correction in place.
5. If text is selected, fix the selected text instead.
6. If the current app cannot be controlled safely, do nothing.

The app should avoid surprising the user. Pressing `Tab` should only rewrite text when Tab Fix is confident it is inside an editable field and a correction is currently available.

## macOS Architecture

Tab Fix is now Swift-first.

Suggested process model:

```text
Swift/AppKit app
  - Menu bar lifecycle
  - Settings panel
  - Dictionary UI later
  - Account/sync UI later
  - Correction orchestration

Native text controller
  - Focused app detection
  - Focused editable element detection
  - Current sentence extraction
  - Selected text extraction
  - Caret bounds lookup
  - In-place replacement

Keyboard/event layer
  - Detect Tab globally
  - Intercept Tab only while a correction is available
  - Avoid breaking normal Tab behavior

Correction engine
  - Fast spelling/grammar/punctuation pass
  - User dictionary later
  - Local cache later
  - Optional model/API provider later
```

Expected macOS permissions:

- Accessibility permission to inspect and manipulate focused text fields.
- Input Monitoring permission if the global event tap requires it.

## Why Swift

Electron was useful for exploring the UI quickly, but the core Tab Fix interaction is OS-level. Swift/AppKit is the better base because the hard parts are native:

- Global `Tab` handling.
- Focused text field detection.
- Caret position lookup.
- Cross-app text extraction.
- Cross-app replacement.
- Menu bar app behavior.
- Low idle CPU and memory.

The long-term app can still become cross-platform, but the macOS version should first be excellent and native.

## Performance Requirements

Tab Fix should be designed around latency from day one.

Target behavior:

- Idle CPU should be near zero.
- The panel should open immediately.
- Typing should never lag.
- The `Tab` hint should appear shortly after a pause.
- Applying a correction should feel instant.

Engineering rules:

- Do not poll aggressively.
- Prefer event-driven macOS APIs.
- Read the smallest useful text range.
- Do not send whole documents for sentence fixes.
- Cache repeat corrections where safe.
- Measure correction latency before adding heavier features.

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

1. Detect the focused app and focused accessibility element.
2. Confirm whether the focused element is editable.
3. Read selected text from common apps.
4. Read the current sentence around the caret when no text is selected.
5. Get caret bounds and position the `Tab` overlay near the cursor.
6. Add a global event tap for `Tab`.
7. Intercept `Tab` only while a correction is visible.
8. Replace the sentence in place.
9. Test Safari, Chrome, Arc, Notes, Messages, Slack, Discord, VS Code, Apple Mail, and ChatGPT.

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
