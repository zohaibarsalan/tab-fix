import AppKit

final class TabFixViewController: NSViewController {
  private let engine = CorrectionEngine()
  private let root = GridBackgroundView()
  private let textView = TabFixTextView()
  private let scrollView = NSScrollView()
  private let hint = PillView(key: "Tab", text: "Fix sentence")
  private let eyebrow = Label("TAB FIX")
  private let headline = Label("Type. Pause. Tab.")
  private let logo = LogoMarkView()
  private let writeLabel = Label("Write here")
  private let suggestionCard = CardView()
  private let suggestionLabel = Label("SUGGESTED FIX")
  private let suggestionText = Label("")
  private let permissionValue = Label("Loading")
  private let permissionNote = Label("Checking macOS access.")
  private let lastFixValue = Label("None yet")
  private let lastFixNote = Label("Pause after typing, then press Tab.")
  private lazy var statusPermission = StatusBlockView(label: "MACOS ACCESS", value: permissionValue, note: permissionNote)
  private lazy var statusMode = StatusBlockView(label: "CROSS-APP TAB", valueText: "Native next", noteText: "The Swift app is ready for the event tap and focused-field helper.")
  private lazy var statusLast = StatusBlockView(label: "LAST FIX", value: lastFixValue, note: lastFixNote)
  private lazy var settings = PanelCardView(label: "SETTINGS", title: "Correction trigger", body: "Show the Tab hint after a short pause, then apply the suggested fix when Tab is pressed.", button: "Request macOS access", target: self, action: #selector(requestAccess))
  private lazy var dictionary = PanelCardView(label: "DICTIONARY", title: "Custom words", body: "Names, products, slang, and words Tab Fix should leave alone will live here.", button: "Coming later", target: self, action: nil)
  private lazy var native = PanelCardView(label: "NATIVE HELPER", title: "Every app", body: "Next step: watch focused text fields, position the overlay near the caret, and intercept Tab only when a fix is ready.", button: "Next build step", target: self, action: nil)
  private var pendingCorrection: CorrectionResult?
  private var idleTimer: Timer?
  private var queuedSource = ""

  override func loadView() {
    view = root
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    buildInterface()
    queueCorrection()
    refreshPermissionState()
  }

  func refreshPermissionState() {
    if AccessibilityAccess.isTrusted {
      permissionValue.stringValue = "Ready"
      permissionValue.textColor = Theme.mint
      permissionNote.stringValue = "Accessibility permission is granted."
    } else {
      permissionValue.stringValue = "Needs access"
      permissionValue.textColor = Theme.signal
      permissionNote.stringValue = "Required for the future cross-app Tab helper."
    }
  }

  private func buildInterface() {
    headline.font = Theme.sans(44, weight: .bold)
    headline.textColor = Theme.ink

    eyebrow.font = Theme.sans(12, weight: .heavy)
    eyebrow.textColor = Theme.signal

    writeLabel.font = Theme.sans(14, weight: .bold)
    writeLabel.textColor = Theme.ink

    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.drawsBackground = false
    scrollView.wantsLayer = true
    scrollView.layer?.backgroundColor = Theme.field.cgColor
    scrollView.layer?.borderColor = Theme.ink.cgColor
    scrollView.layer?.borderWidth = 2
    scrollView.layer?.cornerRadius = 6

    textView.string = ""
    textView.font = Theme.sans(24)
    textView.textColor = Theme.ink
    textView.backgroundColor = Theme.field
    textView.drawsBackground = true
    textView.insertionPointColor = Theme.ink
    textView.textContainerInset = NSSize(width: 28, height: 28)
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]
    textView.isContinuousSpellCheckingEnabled = false
    textView.isGrammarCheckingEnabled = false
    textView.isAutomaticSpellingCorrectionEnabled = false
    textView.isAutomaticTextCompletionEnabled = false
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.typingAttributes = [
      .foregroundColor: Theme.ink,
      .font: Theme.sans(24)
    ]
    textView.isRichText = false
    textView.importsGraphics = false
    textView.allowsUndo = true
    textView.onTab = { [weak self] in
      self?.applyCorrection() ?? false
    }
    textView.onTextChanged = { [weak self] in
      self?.queueCorrection()
    }
    textView.onSelectionChanged = { [weak self] in
      self?.positionHint()
    }
    scrollView.documentView = textView

    hint.isHidden = true

    suggestionLabel.font = Theme.sans(12, weight: .heavy)
    suggestionLabel.textColor = Theme.signal
    suggestionText.font = Theme.sans(24, weight: .semibold)
    suggestionText.textColor = Theme.ink
    suggestionCard.addSubview(suggestionLabel)
    suggestionCard.addSubview(suggestionText)

    for subview in [eyebrow, headline, logo, writeLabel, scrollView, hint, suggestionCard, statusPermission, statusMode, statusLast, settings, dictionary, native] {
      root.addSubview(subview)
    }

    root.postsFrameChangedNotifications = true
    NotificationCenter.default.addObserver(self, selector: #selector(layoutInterface), name: NSView.frameDidChangeNotification, object: root)
    layoutInterface()
  }

  @objc private func layoutInterface() {
    let margin: CGFloat = 44
    let width = root.bounds.width
    let availableWidth = max(720, width - margin * 2)
    let contentWidth = min(1120, availableWidth)
    let contentX = max(margin, (width - contentWidth) / 2)
    let fieldWidth = max(560, contentWidth - 380)
    let suggestionX = contentX + fieldWidth + 24
    let suggestionWidth = max(260, contentWidth - fieldWidth - 24)

    eyebrow.frame = NSRect(x: contentX, y: 34, width: 200, height: 18)
    headline.frame = NSRect(x: contentX, y: 58, width: min(640, contentWidth - 220), height: 58)
    logo.frame = NSRect(x: contentX + contentWidth - 142, y: 42, width: 142, height: 40)
    writeLabel.frame = NSRect(x: contentX, y: 146, width: 220, height: 22)
    scrollView.frame = NSRect(x: contentX, y: 178, width: fieldWidth, height: 300)
    suggestionCard.frame = NSRect(x: suggestionX, y: 178, width: suggestionWidth, height: 300)
    suggestionLabel.frame = NSRect(x: 18, y: 18, width: suggestionWidth - 36, height: 18)
    suggestionText.frame = NSRect(x: 18, y: 58, width: suggestionWidth - 36, height: 190)
    layoutTextEditor()

    let statusY: CGFloat = 512
    let statusWidth = (contentWidth - 36) / 3
    statusPermission.frame = NSRect(x: contentX, y: statusY, width: statusWidth, height: 138)
    statusMode.frame = NSRect(x: contentX + statusWidth + 18, y: statusY, width: statusWidth, height: 138)
    statusLast.frame = NSRect(x: contentX + (statusWidth + 18) * 2, y: statusY, width: statusWidth, height: 138)

    let cardY: CGFloat = 684
    let cardWidth = (contentWidth - 36) / 3
    settings.frame = NSRect(x: contentX, y: cardY, width: cardWidth, height: 148)
    dictionary.frame = NSRect(x: contentX + cardWidth + 18, y: cardY, width: cardWidth, height: 148)
    native.frame = NSRect(x: contentX + (cardWidth + 18) * 2, y: cardY, width: cardWidth, height: 148)

    positionHint()
  }

  private func layoutTextEditor() {
    let contentWidth = max(10, scrollView.contentSize.width)
    let contentHeight = max(300, scrollView.contentSize.height)

    textView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
    textView.minSize = NSSize(width: 0, height: contentHeight)
    textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    textView.textContainer?.containerSize = NSSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude)
    textView.textContainer?.widthTracksTextView = true
  }

  private func queueCorrection() {
    idleTimer?.invalidate()
    setPendingCorrection(nil)

    let source = textView.string
    queuedSource = source
    guard source.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 else {
      return
    }

    idleTimer = Timer.scheduledTimer(timeInterval: 0.42, target: self, selector: #selector(runQueuedCorrection), userInfo: nil, repeats: false)
  }

  @objc private func runQueuedCorrection() {
    guard textView.string == queuedSource else {
      return
    }

    let result = engine.correct(queuedSource)
    setPendingCorrection(result.changed ? result : nil)
  }

  private func setPendingCorrection(_ result: CorrectionResult?) {
    pendingCorrection = result
    hint.isHidden = result == nil
    suggestionText.stringValue = result?.output ?? ""
    positionHint()
  }

  private func applyCorrection() -> Bool {
    guard let correction = pendingCorrection else {
      return false
    }

    textView.string = correction.output
    lastFixValue.stringValue = "\(correction.durationMs)ms"
    lastFixValue.textColor = Theme.mint
    lastFixNote.stringValue = correction.fixes.isEmpty ? "Text replaced." : correction.fixes.joined(separator: ", ")
    setPendingCorrection(nil)
    return true
  }

  private func positionHint() {
    guard !hint.isHidden else {
      return
    }

    hint.frame = NSRect(x: scrollView.frame.maxX - 190, y: scrollView.frame.minY - 18, width: 174, height: 46)
  }

  @objc private func requestAccess() {
    AccessibilityAccess.request()
    refreshPermissionState()
  }
}
