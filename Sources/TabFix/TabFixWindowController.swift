import AppKit

final class TabFixWindowController: NSWindowController {
  private let content = TabFixViewController()

  init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1120, height: 860),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    window.title = "Tab Fix"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.backgroundColor = Theme.paper
    window.center()
    window.minSize = NSSize(width: 920, height: 760)
    window.contentViewController = content

    super.init(window: window)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func refreshPermissionState() {
    content.refreshPermissionState()
  }
}
