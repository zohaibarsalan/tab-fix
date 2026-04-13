import ApplicationServices

enum AccessibilityAccess {
  static var isTrusted: Bool {
    AXIsProcessTrusted()
  }

  static func request() {
    let options = [
      "AXTrustedCheckOptionPrompt": true
    ] as CFDictionary

    AXIsProcessTrustedWithOptions(options)
  }
}
