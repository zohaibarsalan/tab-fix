import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem?
  private var statusMenu: NSMenu?
  private var windowController: TabFixWindowController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    _ = notification
    setupMenuBar()
    openPanel()
  }

  private func setupMenuBar() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.button?.title = "Tab Fix"
    item.button?.font = NSFont.systemFont(ofSize: 13, weight: .bold)
    item.button?.target = self
    item.button?.action = #selector(openPanelFromMenuBar)

    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: "Open Tab Fix", action: #selector(openPanelFromMenuBar), keyEquivalent: ""))
    menu.addItem(NSMenuItem(title: "Request Accessibility Access", action: #selector(requestAccessibilityAccess), keyEquivalent: ""))
    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

    item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    statusMenu = menu
    statusItem = item
  }

  @objc private func openPanelFromMenuBar() {
    if NSApp.currentEvent?.type == .rightMouseUp, let menu = statusMenu {
      statusItem?.menu = menu
      statusItem?.button?.performClick(nil)
      statusItem?.menu = nil
      return
    }

    openPanel()
  }

  private func openPanel() {
    if windowController == nil {
      windowController = TabFixWindowController()
    }

    NSApp.activate(ignoringOtherApps: true)
    windowController?.showWindow(nil)
    windowController?.window?.makeKeyAndOrderFront(nil)
  }

  @objc private func requestAccessibilityAccess() {
    AccessibilityAccess.request()
    openPanel()
    windowController?.refreshPermissionState()
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }
}
