import AppKit

enum Theme {
  static let paper = NSColor(calibratedRed: 0.969, green: 0.969, blue: 0.949, alpha: 1)
  static let ink = NSColor(calibratedRed: 0.063, green: 0.067, blue: 0.067, alpha: 1)
  static let muted = NSColor(calibratedRed: 0.353, green: 0.365, blue: 0.341, alpha: 1)
  static let line = NSColor(calibratedRed: 0.812, green: 0.827, blue: 0.776, alpha: 1)
  static let signal = NSColor(calibratedRed: 0.847, green: 0.231, blue: 0.176, alpha: 1)
  static let mint = NSColor(calibratedRed: 0.184, green: 0.549, blue: 0.404, alpha: 1)
  static let field = NSColor.white

  static func sans(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
    NSFont.systemFont(ofSize: size, weight: weight)
  }

  static func display(_ size: CGFloat, weight: NSFont.Weight = .bold) -> NSFont {
    NSFont(name: "Didot", size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
  }
}

