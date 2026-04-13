import AppKit

struct CorrectionResult {
  let input: String
  let output: String
  let changed: Bool
  let fixes: [String]
  let durationMs: Int
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

    let spellingFixed = correctKnownMisspellings(text)
    if spellingFixed != text {
      text = spellingFixed
      fixes.append("Fixed common spelling errors")
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

    return CorrectionResult(
      input: input,
      output: output,
      changed: output != input,
      fixes: fixes,
      durationMs: Int(elapsed / 1_000_000)
    )
  }

  private func applyRule(_ label: String, to text: inout String, fixes: inout [String], transform: (String) -> String) {
    let next = transform(text)
    if next != text {
      text = next
      fixes.append(label)
    }
  }

  private func correctKnownMisspellings(_ text: String) -> String {
    let pattern = #"\b[A-Za-z']+\b"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return text
    }

    let source = text as NSString
    let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length)).reversed()
    let result = NSMutableString(string: text)

    for match in matches {
      let word = source.substring(with: match.range)
      guard shouldSpellCheck(word) else {
        continue
      }

      let misspelledRange = spellChecker.checkSpelling(
        of: word,
        startingAt: 0,
        language: "en",
        wrap: false,
        inSpellDocumentWithTag: 0,
        wordCount: nil
      )

      guard misspelledRange.location != NSNotFound,
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

  private func bestSpellingGuess(for word: String) -> String? {
    let range = NSRange(location: 0, length: (word as NSString).length)
    let guesses = spellChecker.guesses(forWordRange: range, in: word, language: "en", inSpellDocumentWithTag: 0) ?? []
    let normalized = word.lowercased()

    return guesses.first { guess in
      let candidate = guess.lowercased()
      return candidate.first == normalized.first &&
        candidate.count >= max(3, normalized.count - 1) &&
        editDistance(normalized, candidate) <= max(2, normalized.count / 3)
    }
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
