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
  let fullText: String
  let sourceText: String
  let replacementRange: CFRange
  let caretBounds: CGRect
  let correction: CorrectionResult
  let appName: String?
}

final class CrossAppService {
  private let engine = CorrectionEngine()
  private let systemElement = AXUIElementCreateSystemWide()
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var debounceTimer: Timer?
  private var candidate: TextCandidate?

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
    let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
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
    guard type == .keyDown else {
      return Unmanaged.passUnretained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

    if keyCode == 48 {
      if applyCandidate() {
        return nil
      }

      return Unmanaged.passUnretained(event)
    }

    let flags = event.flags
    if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
      clearCandidate(reason: "modifier")
      return Unmanaged.passUnretained(event)
    }

    scheduleInspection()
    return Unmanaged.passUnretained(event)
  }

  private func scheduleInspection() {
    debounceTimer?.invalidate()
    debounceTimer = Timer.scheduledTimer(timeInterval: 0.45, target: self, selector: #selector(inspectFocusedText), userInfo: nil, repeats: false)
  }

  @objc private func inspectFocusedText() {
    guard !isFrontmostAppTabFix(),
          let element = focusedElement(),
          let fullText = stringAttribute(element, kAXValueAttribute as String),
          let selectedRange = selectedTextRange(element),
          let sourceRange = sourceRange(in: fullText, selectedRange: selectedRange) else {
      clearCandidate(reason: "no-editable-text")
      return
    }

    let source = (fullText as NSString).substring(with: NSRange(location: sourceRange.location, length: sourceRange.length))
    guard source.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 else {
      clearCandidate(reason: "empty-source")
      return
    }

    let correction = engine.correct(source)
    guard correction.changed else {
      clearCandidate(reason: "no-change")
      return
    }

    let bounds = boundsForRange(element, range: CFRange(location: max(selectedRange.location, sourceRange.location), length: 0))
      ?? boundsForRange(element, range: sourceRange)
      ?? fallbackBounds(element)
      ?? CGRect(x: 400, y: 400, width: 1, height: 20)

    candidate = TextCandidate(
      element: element,
      fullText: fullText,
      sourceText: source,
      replacementRange: sourceRange,
      caretBounds: bounds,
      correction: correction,
      appName: NSWorkspace.shared.frontmostApplication?.localizedName
    )

    writeJson(CandidateEvent(
      type: "candidate",
      x: Int(bounds.maxX),
      y: Int(max(0, bounds.minY - 70)),
      correction: correction,
      appName: NSWorkspace.shared.frontmostApplication?.localizedName
    ))
  }

  private func applyCandidate() -> Bool {
    guard let candidate else {
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
    var replacementRange = candidate.replacementRange
    guard let rangeValue = AXValueCreate(.cfRange, &replacementRange) else {
      return false
    }

    AXUIElementSetAttributeValue(candidate.element, kAXSelectedTextRangeAttribute as CFString, rangeValue)

    let selectedTextResult = AXUIElementSetAttributeValue(candidate.element, kAXSelectedTextAttribute as CFString, candidate.correction.output as CFString)
    if selectedTextResult == .success {
      return true
    }

    let nsText = candidate.fullText as NSString
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
      return true
    }

    return pasteFallback(candidate)
  }

  private func pasteFallback(_ candidate: TextCandidate) -> Bool {
    var replacementRange = candidate.replacementRange
    guard let rangeValue = AXValueCreate(.cfRange, &replacementRange) else {
      return false
    }

    AXUIElementSetAttributeValue(candidate.element, kAXSelectedTextRangeAttribute as CFString, rangeValue)

    let pasteboard = NSPasteboard.general
    let previous = pasteboard.string(forType: .string)
    pasteboard.clearContents()
    pasteboard.setString(candidate.correction.output, forType: .string)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
      let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true)
      let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false)
      keyDown?.flags = .maskCommand
      keyUp?.flags = .maskCommand
      keyDown?.post(tap: .cghidEventTap)
      keyUp?.post(tap: .cghidEventTap)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      pasteboard.clearContents()
      if let previous {
        pasteboard.setString(previous, forType: .string)
      }
    }

    return true
  }

  private func clearCandidate(reason: String) {
    if candidate != nil {
      candidate = nil
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
