import AppKit
import SwiftUI

protocol MenuManagerDelegate: AnyObject {
  var statusItem: NSStatusItem? { get set }
  var activeTimers:
    [(
      id: UUID, name: String?, startTime: Date, duration: TimeInterval,
      timer: Timer, reminderId: String?
    )]
  { get }
  func cancelTimer(sender: NSMenuItem)
  func preferences()
  func quit()
  func formatTimeInterval(_ timeInterval: TimeInterval) -> String
}

class MenuManager: NSObject {
  weak var delegate: MenuManagerDelegate?

  private var isMenuOpen = false
  private var menuRefreshTimer: Timer?
  private var menuUpdateTimer: Timer?

  init(delegate: MenuManagerDelegate) {
    self.delegate = delegate
    super.init()
    startMenuUpdateTimer()
  }

  deinit {
    stopMenuRefreshTimer()
    stopMenuUpdateTimer()
  }

  @objc private func menuWillOpen(_ notification: Notification) {
    guard let menu = notification.object as? NSMenu,
      menu == delegate?.statusItem?.menu
    else { return }
    isMenuOpen = true
    startMenuRefreshTimer()
  }

  @objc private func menuWillClose(_ notification: Notification) {
    guard let menu = notification.object as? NSMenu,
      menu == delegate?.statusItem?.menu
    else { return }
    isMenuOpen = false
    stopMenuRefreshTimer()
  }

  private func startMenuRefreshTimer() {
    stopMenuRefreshTimer()
    menuRefreshTimer = Timer.scheduledTimer(
      withTimeInterval: 1.0, repeats: true
    ) { [weak self] _ in
      guard let self = self, self.isMenuOpen else { return }
      self.updateMenu()
    }
  }

  private func stopMenuRefreshTimer() {
    menuRefreshTimer?.invalidate()
    menuRefreshTimer = nil
  }

  private func startMenuUpdateTimer() {
    menuUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
      [weak self] _ in
      self?.updateMenu()
    }
  }

  private func stopMenuUpdateTimer() {
    menuUpdateTimer?.invalidate()
    menuUpdateTimer = nil
  }

  func updateMenu() {
    let menu = NSMenu()

    if delegate?.activeTimers.count ?? 0 > 0 {
      menu.addItem(
        NSMenuItem(title: "Active Timers", action: nil, keyEquivalent: ""))

      if let activeTimers = delegate?.activeTimers {
        for (index, timerInfo) in activeTimers.enumerated() {
          let remainingTime = timerInfo.startTime.addingTimeInterval(
            timerInfo.duration
          ).timeIntervalSince(Date())
          let formattedTime =
            delegate?.formatTimeInterval(remainingTime) ?? "00:00"

          let displayName = timerInfo.name ?? "Timer \(index + 1)"
          let menuItem = NSMenuItem()
          menuItem.representedObject = index

          let customView = HoverView(
            normalText: "\(displayName): \(formattedTime)",
            hoverText: "Delete",
            frame: NSRect(x: 0, y: 0, width: 250, height: 22),
            index: index,
            target: self,
            action: #selector(callCancelTimer(sender:))
          )
          menuItem.view = customView

          menu.addItem(menuItem)
        }
      }

      menu.addItem(NSMenuItem.separator())
    }

    let preferencesMenuItem = NSMenuItem(
      title: "Preferences", action: #selector(callPreferences),
      keyEquivalent: ",")
    preferencesMenuItem.target = self
    menu.addItem(preferencesMenuItem)

    let quitMenuItem = NSMenuItem(
      title: "Quit Dropclock", action: #selector(callQuit), keyEquivalent: "q")
    quitMenuItem.target = self
    menu.addItem(quitMenuItem)

    delegate?.statusItem?.menu = menu
  }

  @objc private func callCancelTimer(sender: NSMenuItem) {
    delegate?.cancelTimer(sender: sender)
  }

  @objc private func callPreferences() {
    delegate?.preferences()
  }

  @objc private func callQuit() {
    delegate?.quit()
  }

  func setupMenu(statusItem: NSStatusItem) {
    delegate?.statusItem = statusItem

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(menuWillOpen(_:)),
      name: NSMenu.didBeginTrackingNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(menuWillClose(_:)),
      name: NSMenu.didEndTrackingNotification,
      object: nil
    )
  }
}
