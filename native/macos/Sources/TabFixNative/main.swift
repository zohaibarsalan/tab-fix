import AppKit
import ApplicationServices
import Foundation

struct PermissionState: Codable {
  let accessibility: Bool
  let inputMonitoring: Bool
  let note: String
}

struct NativeStatus: Codable {
  let ok: Bool
  let platform: String
  let permissions: PermissionState
  let capabilities: [String]
}

struct CorrectionResult: Codable {
  let input: String
  let output: String
  let changed: Bool
  let fixes: [String]
  let durationMs: Int
}

struct NativeEvent<T: Encodable>: Encodable {
  let type: String
  let payload: T?
}

struct EmptyPayload: Encodable {}

struct CandidateEvent: Encodable {
  let type: String
  let x: Int
  let y: Int
  let correction: CorrectionResult
  let appName: String?
}

struct StatusEvent: Encodable {
  let type: String
  let status: NativeStatus
}

struct ErrorEvent: Encodable {
  let type: String
  let message: String
}

enum NativeCommand {
  static func permissionState(prompt: Bool) -> PermissionState {
    if prompt {
      let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
      AXIsProcessTrustedWithOptions(options)
    }

    let accessibility = AXIsProcessTrusted()

    return PermissionState(
      accessibility: accessibility,
      inputMonitoring: false,
      note: accessibility
        ? "Accessibility permission is granted."
        : "Accessibility permission is required for cross-app text detection and replacement."
    )
  }

  static func status() -> NativeStatus {
    NativeStatus(
      ok: true,
      platform: "macOS",
      permissions: permissionState(prompt: false),
      capabilities: [
        "accessibility-permission",
        "system-spellchecker",
        "focused-field-detection",
        "current-sentence-extraction",
        "caret-bounds",
        "tab-event-tap",
        "ax-replacement",
        "paste-fallback"
      ]
    )
  }
}

final class CorrectionEngine {
  private let spellChecker = NSSpellChecker.shared

  func correct(_ input: String) -> CorrectionResult {
    let startedAt = DispatchTime.now()
    var fixes: [String] = []
    let leading = input.prefix { $0.isWhitespace }
    let trailing = input.reversed().prefix { $0.isWhitespace }.reversed()
    var text = input.trimmingCharacters(in: .whitespacesAndNewlines)

    applyRule("Collapsed repeated whitespace", to: &text, fixes: &fixes) {
      $0.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
    }

    applyRule("Fixed space before punctuation", to: &text, fixes: &fixes) {
      $0.replacingOccurrences(of: #"\s+([,.;:!?])"#, with: "$1", options: .regularExpression)
    }

    applyRule("Added space after punctuation", to: &text, fixes: &fixes) {
      $0.replacingOccurrences(of: #"([,.;:!?])([A-Za-z])"#, with: "$1 $2", options: .regularExpression)
    }

    applyRule("Capitalized standalone I", to: &text, fixes: &fixes) {
      $0.replacingOccurrences(of: #"\bi\b"#, with: "I", options: .regularExpression)
    }

    applyRule("Fixed common contractions", to: &text, fixes: &fixes) {
      var next = $0
      let replacements = [
        (#"\bdont\b"#, "don't"),
        (#"\bcant\b"#, "can't"),
        (#"\bwont\b"#, "won't"),
        (#"\bim\b"#, "I'm"),
        (#"\bive\b"#, "I've"),
        (#"\bid\b"#, "I'd"),
        (#"\bill\b"#, "I'll"),
        (#"\bthats\b"#, "that's"),
        (#"\btheres\b"#, "there's"),
        (#"\bisnt\b"#, "isn't"),
        (#"\barent\b"#, "aren't")
      ]

      for (pattern, replacement) in replacements {
        next = next.replacingOccurrences(of: pattern, with: replacement, options: [.regularExpression, .caseInsensitive])
      }

      return next
    }

    applyRule("Fixed common agreement errors", to: &text, fixes: &fixes) {
      var next = $0
      let replacements = [
        (#"\bthis are\b"#, "this is"),
        (#"\bthis seem\b"#, "this seems"),
        (#"\bthis look\b"#, "this looks"),
        (#"\bthis feel\b"#, "this feels"),
        (#"\bthat are\b"#, "that is"),
        (#"\bthat seem\b"#, "that seems"),
        (#"\bthat look\b"#, "that looks"),
        (#"\bthat feel\b"#, "that feels"),
        (#"\bthese is\b"#, "these are"),
        (#"\bthose is\b"#, "those are"),
        (#"\byou is\b"#, "you are"),
        (#"\bwe was\b"#, "we were"),
        (#"\bthey was\b"#, "they were"),
        (#"\bI has\b"#, "I have")
      ]

      for (pattern, replacement) in replacements {
        next = next.replacingOccurrences(of: pattern, with: replacement, options: [.regularExpression, .caseInsensitive])
      }

      return next
    }

    applyRule("Fixed article before vowel sound", to: &text, fixes: &fixes) {
      $0.replacingOccurrences(of: #"\ba ([aeiouAEIOU])"#, with: "an $1", options: .regularExpression)
    }

    applyRule("Added comma after opening interjection", to: &text, fixes: &fixes) {
      $0.replacingOccurrences(of: #"^(wow|hey|yeah|yes|no|well|okay|ok)\s+"#, with: "$1, ", options: [.regularExpression, .caseInsensitive])
    }

    let spellingFixed = correctMisspellings(text)
    if spellingFixed != text {
      text = spellingFixed
      fixes.append("Fixed spelling")
    }

    let capitalized = capitalizeSentenceStarts(text)
    if capitalized != text {
      text = capitalized
      fixes.append("Capitalized sentence starts")
    }

    if !text.isEmpty && !text.hasSuffix(".") && !text.hasSuffix("!") && !text.hasSuffix("?") {
      text += "."
      fixes.append("Added terminal punctuation")
    }

    let output = String(leading) + text + String(trailing)
    let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt.uptimeNanoseconds

    return CorrectionResult(input: input, output: output, changed: output != input, fixes: fixes, durationMs: Int(elapsed / 1_000_000))
  }

  private func applyRule(_ label: String, to text: inout String, fixes: inout [String], transform: (String) -> String) {
    let next = transform(text)

    if next != text {
      text = next
      fixes.append(label)
    }
  }

  private func correctMisspellings(_ text: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: #"\b[A-Za-z']+\b"#) else {
      return text
    }

    let source = text as NSString
    let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length)).reversed()
    let result = NSMutableString(string: text)

    for match in matches {
      let word = source.substring(with: match.range)
      guard shouldSpellCheck(word),
            isMisspelled(word),
            let replacement = bestSpellingGuess(for: word) else {
        continue
      }

      result.replaceCharacters(in: match.range, with: preserveCase(source: word, replacement: replacement))
    }

    return result as String
  }

  private func shouldSpellCheck(_ word: String) -> Bool {
    word.count > 2 && word.rangeOfCharacter(from: .decimalDigits) == nil
  }

  private func isMisspelled(_ word: String) -> Bool {
    let range = spellChecker.checkSpelling(
      of: word,
      startingAt: 0,
      language: "en",
      wrap: false,
      inSpellDocumentWithTag: 0,
      wordCount: nil
    )

    return range.location != NSNotFound
  }

  private func bestSpellingGuess(for word: String) -> String? {
    let range = NSRange(location: 0, length: (word as NSString).length)
    let guesses = spellChecker.guesses(forWordRange: range, in: word, language: "en", inSpellDocumentWithTag: 0) ?? []
    let normalized = word.lowercased()
    let correction = spellChecker.correction(forWordRange: range, in: word, language: "en", inSpellDocumentWithTag: 0)
    let candidates = ([correction].compactMap { $0 } + guesses).filter { guess in
      let candidate = guess.lowercased()
      return candidate.first == normalized.first &&
        candidate.range(of: #"^[a-z]+$"#, options: .regularExpression) != nil &&
        candidate.count >= max(3, normalized.count - 1) &&
        editDistance(normalized, candidate) <= max(2, normalized.count / 3)
    }

    guard var best = candidates.first else {
      return nil
    }

    for candidate in candidates.dropFirst() {
      let current = best.lowercased()
      let next = candidate.lowercased()
      let currentPrefix = commonPrefixLength(normalized, current)
      let nextPrefix = commonPrefixLength(normalized, next)
      let currentDistance = editDistance(normalized, current)
      let nextDistance = editDistance(normalized, next)

      if nextPrefix >= currentPrefix + 2 && nextDistance <= currentDistance {
        best = candidate
      }
    }

    return best
  }

  private func commonPrefixLength(_ lhs: String, _ rhs: String) -> Int {
    var count = 0

    for (left, right) in zip(lhs, rhs) {
      if left != right {
        break
      }

      count += 1
    }

    return count
  }

  private func editDistance(_ lhs: String, _ rhs: String) -> Int {
    let left = Array(lhs)
    let right = Array(rhs)
    var previous = Array(0...right.count)

    for (leftIndex, leftCharacter) in left.enumerated() {
      var current = [leftIndex + 1]

      for (rightIndex, rightCharacter) in right.enumerated() {
        if leftCharacter == rightCharacter {
          current.append(previous[rightIndex])
        } else {
          current.append(min(previous[rightIndex], previous[rightIndex + 1], current[rightIndex]) + 1)
        }
      }

      previous = current
    }

    return previous[right.count]
  }

  private func preserveCase(source: String, replacement: String) -> String {
    if source.uppercased() == source {
      return replacement.uppercased()
    }

    if source.first?.isUppercase == true {
      return replacement.prefix(1).uppercased() + replacement.dropFirst()
    }

    return replacement
  }

  private func capitalizeSentenceStarts(_ text: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: #"(^|[.!?]\s+)([a-z])"#) else {
      return text
    }

    let source = text as NSString
    let result = NSMutableString(string: text)
    let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length)).reversed()

    for match in matches {
      let letterRange = match.range(at: 2)
      let letter = source.substring(with: letterRange).uppercased()
      result.replaceCharacters(in: letterRange, with: letter)
    }

    return result as String
  }
}

struct TextCandidate {
  let element: AXUIElement
  let fullValue: String?
  let sourceText: String
  let replacementRange: CFRange
  let originalSelectedRange: CFRange
  let caretBounds: CGRect
  let correction: CorrectionResult
  let appName: String?
  let bundleIdentifier: String?
  let processIdentifier: pid_t?
}

struct TextSnapshot {
  let text: String
  let baseLocation: Int
  let fullValue: String?
}

final class CrossAppService {
  private let engine = CorrectionEngine()
  private let systemElement = AXUIElementCreateSystemWide()
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var debounceTimer: Timer?
  private var candidate: TextCandidate?
  private var lastInspectionKey: String?

  func run() {
    writeJson(StatusEvent(type: "status", status: NativeCommand.status()))

    guard NativeCommand.permissionState(prompt: false).accessibility else {
      writeJson(ErrorEvent(type: "error", message: "Accessibility permission is missing. Request it from the Tab Fix panel, then restart the app."))
      RunLoop.main.run()
      return
    }

    installEventTap()
    RunLoop.main.run()
  }

  private func installEventTap() {
    let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue))
    let ref = Unmanaged.passUnretained(self).toOpaque()

    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: mask,
      callback: { _, type, event, userInfo in
        guard let userInfo else {
          return Unmanaged.passUnretained(event)
        }

        let service = Unmanaged<CrossAppService>.fromOpaque(userInfo).takeUnretainedValue()
        return service.handleEvent(type: type, event: event)
      },
      userInfo: ref
    ) else {
      writeJson(ErrorEvent(type: "error", message: "Could not create keyboard event tap. Input Monitoring or Accessibility permission may be required."))
      return
    }

    eventTap = tap
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

    if let runLoopSource {
      CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }

    CGEvent.tapEnable(tap: tap, enable: true)
  }

  private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let eventTap {
        CGEvent.tapEnable(tap: eventTap, enable: true)
      }

      return Unmanaged.passUnretained(event)
    }

    if type == .flagsChanged {
      debounceTimer?.invalidate()
      clearCandidate(reason: "modifier")
      return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown else {
      return Unmanaged.passUnretained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    if keyCode == 48 {
      if hasApplyBlockingModifiers(flags) {
        debounceTimer?.invalidate()
        clearCandidate(reason: "tab-with-modifier")
        return Unmanaged.passUnretained(event)
      }

      if applyCandidate() {
        return nil
      }

      return Unmanaged.passUnretained(event)
    }

    if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
      debounceTimer?.invalidate()
      clearCandidate(reason: "modifier")
      return Unmanaged.passUnretained(event)
    }

    if candidate != nil {
      clearCandidate(reason: "key")
    }

    if shouldInspectAfterKey(keyCode) {
      scheduleInspection()
    }

    return Unmanaged.passUnretained(event)
  }

  private func hasApplyBlockingModifiers(_ flags: CGEventFlags) -> Bool {
    flags.contains(.maskCommand) ||
      flags.contains(.maskControl) ||
      flags.contains(.maskAlternate) ||
      flags.contains(.maskShift)
  }

  private func shouldInspectAfterKey(_ keyCode: Int64) -> Bool {
    let ignoredKeys: Set<Int64> = [
      48, // Tab
      53, // Escape
      55, 54, // Command
      56, 60, // Shift
      58, 61, // Option
      59, 62, // Control
      63, // Fn
      122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90, // Function keys
      115, 119, 116, 121, 123, 124, 125, 126 // Home, End, Page, arrows
    ]

    return !ignoredKeys.contains(keyCode)
  }

  private func scheduleInspection() {
    debounceTimer?.invalidate()
    debounceTimer = Timer.scheduledTimer(timeInterval: 0.22, target: self, selector: #selector(inspectFocusedText), userInfo: nil, repeats: false)
  }

  @objc private func inspectFocusedText() {
    guard !isFrontmostAppTabFix(),
          let element = focusedElement(),
          let selectedRange = selectedTextRange(element),
          let snapshot = textSnapshot(element, selectedRange: selectedRange) else {
      clearCandidate(reason: "no-editable-text")
      return
    }

    let relativeSelectedRange = CFRange(
      location: selectedRange.location - snapshot.baseLocation,
      length: selectedRange.length
    )
    guard relativeSelectedRange.location >= 0,
          let relativeSourceRange = sourceRange(in: snapshot.text, selectedRange: relativeSelectedRange) else {
      clearCandidate(reason: "no-source-range")
      return
    }

    let sourceRange = CFRange(
      location: snapshot.baseLocation + relativeSourceRange.location,
      length: relativeSourceRange.length
    )
    let source = (snapshot.text as NSString).substring(with: NSRange(location: relativeSourceRange.location, length: relativeSourceRange.length))
    guard source.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 else {
      clearCandidate(reason: "empty-source")
      return
    }

    let inspectionKey = "\(sourceRange.location):\(sourceRange.length):\(source)"
    if inspectionKey == lastInspectionKey, candidate != nil {
      return
    }

    let correction = engine.correct(source)
    guard correction.changed else {
      clearCandidate(reason: "no-change")
      return
    }

    lastInspectionKey = inspectionKey

    let bounds = bestBoundsForOverlay(element: element, selectedRange: selectedRange, sourceRange: sourceRange)
      ?? fallbackBounds(element)
      ?? CGRect(x: 400, y: 400, width: 1, height: 20)
    let app = NSWorkspace.shared.frontmostApplication
    let normalizedBounds = normalizeBoundsForOverlay(bounds, appName: app?.localizedName, bundleIdentifier: app?.bundleIdentifier)
    let overlayPoint = overlayPoint(for: normalizedBounds)

    candidate = TextCandidate(
      element: element,
      fullValue: snapshot.fullValue,
      sourceText: source,
      replacementRange: sourceRange,
      originalSelectedRange: selectedRange,
      caretBounds: normalizedBounds,
      correction: correction,
      appName: app?.localizedName,
      bundleIdentifier: app?.bundleIdentifier,
      processIdentifier: app?.processIdentifier
    )

    writeJson(CandidateEvent(
      type: "candidate",
      x: Int(overlayPoint.x),
      y: Int(overlayPoint.y),
      correction: correction,
      appName: app?.localizedName
    ))
  }

  private func applyCandidate() -> Bool {
    guard let candidate else {
      return false
    }

    guard candidate.processIdentifier == NSWorkspace.shared.frontmostApplication?.processIdentifier else {
      clearCandidate(reason: "frontmost-changed")
      return false
    }

    guard let focusedElement = focusedElement(),
          CFEqual(focusedElement, candidate.element),
          sourceStillMatches(candidate) else {
      clearCandidate(reason: "stale-candidate")
      return false
    }

    let didApply = replace(candidate)
    if didApply {
      writeJson(NativeEvent(type: "applied", payload: candidate.correction))
      self.candidate = nil
      return true
    }

    writeJson(ErrorEvent(type: "error", message: "Could not replace text in the focused app."))
    clearCandidate(reason: "replace-failed")
    return false
  }

  private func replace(_ candidate: TextCandidate) -> Bool {
    if select(candidate.replacementRange, in: candidate.element) {
      let selectedTextResult = AXUIElementSetAttributeValue(candidate.element, kAXSelectedTextAttribute as CFString, candidate.correction.output as CFString)
      if selectedTextResult == .success {
        if replacementMatches(candidate) || !canReadCandidateText(candidate) {
          return true
        }
      }
    }

    if let currentValue = stringAttribute(candidate.element, kAXValueAttribute as String), !currentValue.isEmpty {
      let nsText = currentValue as NSString
      guard candidate.replacementRange.location + candidate.replacementRange.length <= nsText.length else {
        restoreSelection(candidate)
        return false
      }
      let nextValue = nsText.replacingCharacters(
        in: NSRange(location: candidate.replacementRange.location, length: candidate.replacementRange.length),
        with: candidate.correction.output
      )

      let valueResult = AXUIElementSetAttributeValue(candidate.element, kAXValueAttribute as CFString, nextValue as CFString)
      if valueResult == .success {
        var caretRange = CFRange(location: candidate.replacementRange.location + (candidate.correction.output as NSString).length, length: 0)
        if let caretValue = AXValueCreate(.cfRange, &caretRange) {
          AXUIElementSetAttributeValue(candidate.element, kAXSelectedTextRangeAttribute as CFString, caretValue)
        }

        if replacementMatches(candidate) || !canReadCandidateText(candidate) {
          return true
        }
      }
    }

    if pasteFallback(candidate) {
      return true
    }

    restoreSelection(candidate)
    return false
  }

  private func pasteFallback(_ candidate: TextCandidate) -> Bool {
    guard select(candidate.replacementRange, in: candidate.element) else {
      return false
    }

    Thread.sleep(forTimeInterval: 0.08)

    let pasteboard = NSPasteboard.general
    let previous = pasteboard.string(forType: .string)
    pasteboard.clearContents()
    pasteboard.setString(candidate.correction.output, forType: .string)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      CrossAppService.postPasteShortcut()
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      if let previous {
        pasteboard.setString(previous, forType: .string)
      }
    }

    return true
  }

  private func sourceStillMatches(_ candidate: TextCandidate) -> Bool {
    textInRange(candidate.element, range: candidate.replacementRange) == candidate.sourceText
  }

  private func replacementMatches(_ candidate: TextCandidate) -> Bool {
    Thread.sleep(forTimeInterval: 0.06)

    let outputLength = (candidate.correction.output as NSString).length
    let outputRange = CFRange(location: candidate.replacementRange.location, length: outputLength)
    return textInRange(candidate.element, range: outputRange) == candidate.correction.output
  }

  private func canReadCandidateText(_ candidate: TextCandidate) -> Bool {
    textInRange(candidate.element, range: candidate.replacementRange) != nil
  }

  private func textInRange(_ element: AXUIElement, range: CFRange) -> String? {
    if let fullValue = stringAttribute(element, kAXValueAttribute as String) {
      let nsText = fullValue as NSString
      guard range.location >= 0,
            range.length >= 0,
            range.location + range.length <= nsText.length else {
        return nil
      }

      return nsText.substring(with: NSRange(location: range.location, length: range.length))
    }

    return stringForRange(element, range: range)
  }

  private func restoreSelection(_ candidate: TextCandidate) {
    _ = setSelectedRange(candidate.originalSelectedRange, in: candidate.element)
  }

  private func select(_ range: CFRange, in element: AXUIElement) -> Bool {
    guard setSelectedRange(range, in: element) else {
      return false
    }

    Thread.sleep(forTimeInterval: 0.03)

    guard let selectedRange = selectedTextRange(element) else {
      return true
    }

    return selectedRange.location == range.location && selectedRange.length == range.length
  }

  private func setSelectedRange(_ range: CFRange, in element: AXUIElement) -> Bool {
    var mutableRange = range
    guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else {
      return false
    }

    let result = AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, rangeValue)
    guard result == .success else {
      return false
    }

    return true
  }

  private func bestBoundsForOverlay(element: AXUIElement, selectedRange: CFRange, sourceRange: CFRange) -> CGRect? {
    let caretLocation = max(selectedRange.location, sourceRange.location)
    let sourceBounds = boundsForRange(element, range: sourceRange)
    let caretBounds = boundsForRange(element, range: CFRange(location: caretLocation, length: 0))
    let previousCharacterBounds = previousCharacterBounds(element: element, caretLocation: caretLocation, sourceRange: sourceRange)

    if let caretBounds, !isSuspiciousCaretBounds(caretBounds, sourceBounds: sourceBounds) {
      return caretBounds
    }

    if let previousCharacterBounds, !isSuspiciousCaretBounds(previousCharacterBounds, sourceBounds: sourceBounds) {
      return previousCharacterBounds
    }

    return sourceBounds ?? previousCharacterBounds ?? caretBounds
  }

  private func previousCharacterBounds(element: AXUIElement, caretLocation: Int, sourceRange: CFRange) -> CGRect? {
    let previousLocation = caretLocation - 1
    guard previousLocation >= sourceRange.location else {
      return nil
    }

    return boundsForRange(element, range: CFRange(location: previousLocation, length: 1))
  }

  private func isSuspiciousCaretBounds(_ caretBounds: CGRect, sourceBounds: CGRect?) -> Bool {
    if caretBounds.minX <= 1 && caretBounds.minY <= 1 {
      return true
    }

    guard let sourceBounds else {
      return false
    }

    let allowed = sourceBounds.insetBy(dx: -48, dy: -48)
    return !allowed.contains(CGPoint(x: caretBounds.midX, y: caretBounds.midY))
  }

  private func normalizeBoundsForOverlay(_ bounds: CGRect, appName: String?, bundleIdentifier: String?) -> CGRect {
    guard usesBottomLeftRangeCoordinates(appName: appName, bundleIdentifier: bundleIdentifier),
          let screen = screenContaining(bounds) ?? NSScreen.main else {
      return bounds
    }

    let flipped = CGRect(
      x: bounds.minX,
      y: screen.frame.maxY - bounds.maxY + screen.frame.minY,
      width: bounds.width,
      height: bounds.height
    )

    return isBadOverlayBounds(flipped, screen: screen) ? bounds : flipped
  }

  private func overlayPoint(for bounds: CGRect) -> CGPoint {
    CGPoint(x: bounds.maxX + 6, y: max(0, bounds.minY - 34))
  }

  private func screenContaining(_ rect: CGRect) -> NSScreen? {
    NSScreen.screens.first { screen in
      screen.frame.intersects(rect) || screen.frame.contains(CGPoint(x: rect.midX, y: rect.midY))
    }
  }

  private func isBadOverlayBounds(_ bounds: CGRect, screen: NSScreen) -> Bool {
    let paddedFrame = screen.frame.insetBy(dx: -80, dy: -80)
    return !paddedFrame.intersects(bounds) || bounds.minX <= 1 || bounds.minY <= 1
  }

  private func usesBottomLeftRangeCoordinates(appName: String?, bundleIdentifier: String?) -> Bool {
    let browserBundles = [
      "com.google.Chrome",
      "com.google.Chrome.canary",
      "com.brave.Browser",
      "com.microsoft.edgemac",
      "company.thebrowser.Browser",
      "com.operasoftware.Opera"
    ]

    if let bundleIdentifier, browserBundles.contains(bundleIdentifier) {
      return true
    }

    let normalizedBundle = bundleIdentifier?.lowercased() ?? ""
    let normalizedName = appName?.lowercased() ?? ""

    return normalizedBundle.contains("electron") ||
      normalizedBundle.contains("openai") ||
      normalizedBundle.contains("chatgpt") ||
      normalizedBundle.contains("codex") ||
      normalizedBundle.contains("t3") ||
      normalizedName.contains("chatgpt") ||
      normalizedName.contains("codex") ||
      normalizedName.contains("t3 code") ||
      normalizedName.contains("t3")
  }

  private static func postPasteShortcut() {
    let source = CGEventSource(stateID: .hidSystemState)
    let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: true)
    let vDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
    let vUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
    let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: false)

    commandDown?.flags = .maskCommand
    vDown?.flags = .maskCommand
    vUp?.flags = .maskCommand

    commandDown?.post(tap: .cghidEventTap)
    vDown?.post(tap: .cghidEventTap)
    vUp?.post(tap: .cghidEventTap)
    commandUp?.post(tap: .cghidEventTap)
  }

  private func clearCandidate(reason: String) {
    if candidate != nil {
      candidate = nil
      lastInspectionKey = nil
      writeJson(["type": "hide", "reason": reason])
    }
  }

  private func focusedElement() -> AXUIElement? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &value)

    guard result == .success, let value else {
      return nil
    }

    return (value as! AXUIElement)
  }

  private func selectedTextRange(_ element: AXUIElement) -> CFRange? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value)

    guard result == .success, let value else {
      return nil
    }

    var range = CFRange()
    guard AXValueGetValue((value as! AXValue), .cfRange, &range) else {
      return nil
    }

    return range
  }

  private func sourceRange(in text: String, selectedRange: CFRange) -> CFRange? {
    let length = (text as NSString).length
    guard selectedRange.location >= 0, selectedRange.location <= length else {
      return nil
    }

    if selectedRange.length > 0 {
      return selectedRange
    }

    let nsText = text as NSString
    var start = selectedRange.location
    var end = selectedRange.location

    while start > 0 {
      let scalar = nsText.character(at: start - 1)
      if scalar == 10 || scalar == 13 || scalar == 46 || scalar == 33 || scalar == 63 {
        break
      }
      start -= 1
    }

    while end < length {
      let scalar = nsText.character(at: end)
      if scalar == 10 || scalar == 13 || scalar == 46 || scalar == 33 || scalar == 63 {
        end += 1
        break
      }
      end += 1
    }

    while start < end, CharacterSet.whitespacesAndNewlines.contains(UnicodeScalar(nsText.character(at: start))!) {
      start += 1
    }

    while end > start, CharacterSet.whitespacesAndNewlines.contains(UnicodeScalar(nsText.character(at: end - 1))!) {
      end -= 1
    }

    guard end > start else {
      return nil
    }

    return CFRange(location: start, length: end - start)
  }

  private func textSnapshot(_ element: AXUIElement, selectedRange: CFRange) -> TextSnapshot? {
    guard selectedRange.location >= 0 else {
      return nil
    }

    if let fullValue = stringAttribute(element, kAXValueAttribute as String), !fullValue.isEmpty {
      return TextSnapshot(text: fullValue, baseLocation: 0, fullValue: fullValue)
    }

    return rangedTextSnapshot(element, selectedRange: selectedRange)
  }

  private func rangedTextSnapshot(_ element: AXUIElement, selectedRange: CFRange) -> TextSnapshot? {
    guard let characterCount = intAttribute(element, kAXNumberOfCharactersAttribute as String),
          characterCount > 0 else {
      return nil
    }

    let selectedStart = min(max(0, selectedRange.location), characterCount)
    let selectedEnd = min(max(selectedStart, selectedRange.location + selectedRange.length), characterCount)
    let radius = 4000
    let start = max(0, selectedStart - radius)
    let end = min(characterCount, max(selectedEnd + radius, selectedStart + radius))
    let length = end - start

    guard length > 0,
          let text = stringForRange(element, range: CFRange(location: start, length: length)),
          !text.isEmpty else {
      return nil
    }

    return TextSnapshot(text: text, baseLocation: start, fullValue: nil)
  }

  private func boundsForRange(_ element: AXUIElement, range: CFRange) -> CGRect? {
    var mutableRange = range
    guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else {
      return nil
    }

    var value: CFTypeRef?
    let result = AXUIElementCopyParameterizedAttributeValue(
      element,
      kAXBoundsForRangeParameterizedAttribute as CFString,
      rangeValue,
      &value
    )

    guard result == .success, let value else {
      return nil
    }

    var rect = CGRect.zero
    guard AXValueGetValue((value as! AXValue), .cgRect, &rect) else {
      return nil
    }

    return rect
  }

  private func stringForRange(_ element: AXUIElement, range: CFRange) -> String? {
    var mutableRange = range
    guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else {
      return nil
    }

    var value: CFTypeRef?
    let result = AXUIElementCopyParameterizedAttributeValue(
      element,
      kAXStringForRangeParameterizedAttribute as CFString,
      rangeValue,
      &value
    )

    guard result == .success else {
      return nil
    }

    return value as? String
  }

  private func fallbackBounds(_ element: AXUIElement) -> CGRect? {
    guard let position = axPointAttribute(element, kAXPositionAttribute as String),
          let size = axSizeAttribute(element, kAXSizeAttribute as String) else {
      return nil
    }

    return CGRect(origin: position, size: size)
  }

  private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

    guard result == .success else {
      return nil
    }

    return value as? String
  }

  private func intAttribute(_ element: AXUIElement, _ attribute: String) -> Int? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

    guard result == .success, let number = value as? NSNumber else {
      return nil
    }

    return number.intValue
  }

  private func axPointAttribute(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

    guard result == .success, let value else {
      return nil
    }

    var point = CGPoint.zero
    guard AXValueGetValue((value as! AXValue), .cgPoint, &point) else {
      return nil
    }

    return point
  }

  private func axSizeAttribute(_ element: AXUIElement, _ attribute: String) -> CGSize? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

    guard result == .success, let value else {
      return nil
    }

    var size = CGSize.zero
    guard AXValueGetValue((value as! AXValue), .cgSize, &size) else {
      return nil
    }

    return size
  }

  private func isFrontmostAppTabFix() -> Bool {
    guard let app = NSWorkspace.shared.frontmostApplication else {
      return false
    }

    let name = app.localizedName?.lowercased() ?? ""
    let bundle = app.bundleIdentifier?.lowercased() ?? ""

    return name.contains("tab fix") ||
      name == "electron" ||
      bundle.contains("electron") ||
      bundle.contains("tab-fix")
  }
}

func writeJson<T: Encodable>(_ value: T) {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]

  do {
    let data = try encoder.encode(value)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
  } catch {
    fputs("{\"ok\":false,\"error\":\"Failed to encode JSON\"}\n", stderr)
    exit(1)
  }
}

let args = CommandLine.arguments.dropFirst()
let command = args.first ?? "status"

switch command {
case "status":
  writeJson(NativeCommand.status())
case "request-permissions":
  writeJson(NativeCommand.permissionState(prompt: true))
case "correct":
  let text = args.dropFirst().joined(separator: " ")
  writeJson(CorrectionEngine().correct(text))
case "serve":
  CrossAppService().run()
default:
  fputs("Unknown command: \(command)\n", stderr)
  exit(2)
}
