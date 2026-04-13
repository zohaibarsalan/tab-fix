import AppKit

final class GridBackgroundView: NSView {
  override var isFlipped: Bool { true }

  override func draw(_ dirtyRect: NSRect) {
    Theme.paper.setFill()
    bounds.fill()
  }
}

class CardView: NSView {
  override var isFlipped: Bool { true }

  override func viewDidMoveToSuperview() {
    wantsLayer = true
    layer?.backgroundColor = NSColor.white.withAlphaComponent(0.9).cgColor
    layer?.cornerRadius = 8
    layer?.borderColor = Theme.line.cgColor
    layer?.borderWidth = 1
    layer?.shadowColor = Theme.ink.cgColor
    layer?.shadowOpacity = 0.08
    layer?.shadowRadius = 20
    layer?.shadowOffset = CGSize(width: 0, height: -8)
  }
}

final class PillView: NSView {
  let keyLabel = Label("")
  let textLabel = Label("")

  init(key: String, text: String) {
    super.init(frame: .zero)
    wantsLayer = true
    layer?.backgroundColor = NSColor(calibratedRed: 1, green: 0.992, blue: 0.976, alpha: 1).cgColor
    layer?.borderColor = Theme.ink.cgColor
    layer?.borderWidth = 1
    layer?.cornerRadius = 8
    layer?.shadowColor = Theme.ink.cgColor
    layer?.shadowOpacity = 0.18
    layer?.shadowRadius = 0
    layer?.shadowOffset = CGSize(width: 6, height: -6)

    keyLabel.stringValue = key
    keyLabel.font = Theme.sans(14, weight: .bold)
    keyLabel.textColor = .white
    keyLabel.alignment = .center
    keyLabel.wantsLayer = true
    keyLabel.layer?.backgroundColor = Theme.signal.cgColor
    keyLabel.layer?.cornerRadius = 6

    textLabel.stringValue = text
    textLabel.font = Theme.sans(14, weight: .bold)
    textLabel.textColor = Theme.ink

    addSubview(keyLabel)
    addSubview(textLabel)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var isFlipped: Bool { true }

  override func layout() {
    super.layout()
    keyLabel.frame = NSRect(x: 10, y: 8, width: 50, height: 28)
    textLabel.frame = NSRect(x: 70, y: 11, width: bounds.width - 80, height: 22)
  }
}

final class LogoMarkView: NSView {
  private let mark = Label("T")
  private let name = Label("Tab Fix")

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor

    mark.font = Theme.sans(16, weight: .black)
    mark.textColor = .white
    mark.alignment = .center
    mark.wantsLayer = true
    mark.layer?.backgroundColor = Theme.signal.cgColor
    mark.layer?.cornerRadius = 8

    name.font = Theme.sans(18, weight: .bold)
    name.textColor = Theme.ink

    addSubview(mark)
    addSubview(name)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var isFlipped: Bool { true }

  override func layout() {
    super.layout()
    mark.frame = NSRect(x: 0, y: 2, width: 34, height: 34)
    name.frame = NSRect(x: 44, y: 6, width: bounds.width - 44, height: 28)
  }
}

final class Label: NSTextField {
  init(_ text: String) {
    super.init(frame: .zero)
    stringValue = text
    isEditable = false
    isSelectable = false
    isBordered = false
    drawsBackground = false
    lineBreakMode = .byWordWrapping
    maximumNumberOfLines = 0
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

final class TabFixTextView: NSTextView {
  var onTab: (() -> Bool)?
  var onTextChanged: (() -> Void)?
  var onSelectionChanged: (() -> Void)?

  override func keyDown(with event: NSEvent) {
    if event.charactersIgnoringModifiers == "\t", onTab?() == true {
      return
    }

    super.keyDown(with: event)
  }

  override func didChangeText() {
    super.didChangeText()
    onTextChanged?()
  }

  override func setSelectedRange(_ charRange: NSRange) {
    super.setSelectedRange(charRange)
    onSelectionChanged?()
  }
}

final class StatusBlockView: CardView {
  private let labelView = Label("")
  let valueView: Label
  let noteView: Label

  init(label: String, value: Label? = nil, valueText: String? = nil, note: Label? = nil, noteText: String = "") {
    valueView = value ?? Label(valueText ?? "")
    noteView = note ?? Label(noteText)
    super.init(frame: .zero)

    labelView.stringValue = label
    labelView.font = Theme.sans(12, weight: .heavy)
    labelView.textColor = Theme.signal
    valueView.font = Theme.sans(24, weight: .bold)
    valueView.textColor = Theme.ink
    noteView.font = Theme.sans(13)
    noteView.textColor = Theme.muted

    addSubview(labelView)
    addSubview(valueView)
    addSubview(noteView)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var isFlipped: Bool { true }

  override func layout() {
    super.layout()
    labelView.frame = NSRect(x: 18, y: 18, width: bounds.width - 36, height: 18)
    valueView.frame = NSRect(x: 18, y: 46, width: bounds.width - 36, height: 34)
    noteView.frame = NSRect(x: 18, y: 88, width: bounds.width - 36, height: 52)
  }
}

final class PanelCardView: CardView {
  private let labelView = Label("")
  private let titleView = Label("")
  private let bodyView = Label("")
  private let buttonView: NSButton

  init(label: String, title: String, body: String, button: String, target: AnyObject?, action: Selector?) {
    buttonView = NSButton(title: button, target: target, action: action)
    super.init(frame: .zero)

    labelView.stringValue = label
    labelView.font = Theme.sans(12, weight: .heavy)
    labelView.textColor = Theme.signal
    titleView.stringValue = title
    titleView.font = Theme.display(28)
    titleView.textColor = Theme.ink
    bodyView.stringValue = body
    bodyView.font = Theme.sans(14)
    bodyView.textColor = Theme.muted
    buttonView.bezelStyle = .rounded
    buttonView.isEnabled = action != nil

    addSubview(labelView)
    addSubview(titleView)
    addSubview(bodyView)
    addSubview(buttonView)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    labelView.frame = NSRect(x: 18, y: 18, width: bounds.width - 36, height: 18)
    titleView.frame = NSRect(x: 18, y: 46, width: bounds.width - 36, height: 42)
    bodyView.frame = NSRect(x: 18, y: 98, width: bounds.width - 36, height: 70)
    buttonView.frame = NSRect(x: 18, y: bounds.height - 50, width: min(190, bounds.width - 36), height: 32)
  }
}
