import AppKit
import EventKit
import SwiftUI
import UserNotifications

@main
struct MenuBarApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  var statusItem: NSStatusItem?
  let formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
  }()

  var baseTime = Date()

  internal var dragTimeInterval: TimeInterval = 0
  internal var dragStartLocation: CGPoint?

  internal let MinuteThreshold: CGFloat = 130
  internal let ThirtySecondThreshold: CGFloat = 80
  internal let SecondThreshold: CGFloat = 50

  private var timer: Timer?
  private var activeTimers:
    [(
      id: UUID, name: String?, startTime: Date, duration: TimeInterval,
      timer: Timer, reminderId: String?
    )] = []
  internal var pendingTimerData: (startTime: Date, duration: TimeInterval)?

  private var nameInputPanel: NameInputPanel?
  internal var dragTimerPanel: DragTimerPanel?

  internal var endTime: Date?
  private var menuUpdateTimer: Timer?
  private var isMenuOpen = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(
      withLength: NSStatusItem.variableLength)
    if let button = statusItem?.button {
      updateStatusIcon()
      setupDrag(for: button)
    }
    NotificationManager.shared.checkForPermission()
    loadSavedTimers()

    updateMenu()

    Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      self?.baseTime = Date()
      self?.updateStatusIcon()
    }

    startMenuUpdateTimer()

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

  func applicationWillTerminate(_ notification: Notification) {
    dragTimerPanel?.cleanup()
    nameInputPanel?.cleanup()
  }

  private func saveTimers() {
    let timersToSave = activeTimers.map { timer -> SavedTimer in
      return SavedTimer(
        id: timer.id.uuidString,
        name: timer.name,
        startTime: timer.startTime,
        duration: timer.duration,
        reminderId: timer.reminderId
      )
    }

    do {
      let data = try JSONEncoder().encode(timersToSave)
      UserDefaults.standard.set(data, forKey: "SavedTimers")
    } catch {
      print("Failed to save timers: \(error)")
    }
  }

  private func loadSavedTimers() {
    guard let data = UserDefaults.standard.data(forKey: "SavedTimers") else {
      return
    }

    do {
      let savedTimers = try JSONDecoder().decode([SavedTimer].self, from: data)

      for savedTimer in savedTimers {
        let timerId = UUID(uuidString: savedTimer.id) ?? UUID()
        let now = Date()

        let endTime = savedTimer.startTime.addingTimeInterval(
          savedTimer.duration)
        let remainingTime = endTime.timeIntervalSince(now)

        if remainingTime > 0 {
          let timerObj = Timer.scheduledTimer(
            withTimeInterval: remainingTime, repeats: false
          ) { [weak self] _ in
            self?.timerFinished(id: timerId)
          }

          activeTimers.append(
            (
              id: timerId,
              name: savedTimer.name,
              startTime: savedTimer.startTime,
              duration: savedTimer.duration,
              timer: timerObj,
              reminderId: savedTimer.reminderId
            ))
        } else {
          let timerObj = Timer.scheduledTimer(
            withTimeInterval: 1.0, repeats: false
          ) { [weak self] _ in
            self?.timerFinished(id: timerId)
          }

          activeTimers.append(
            (
              id: timerId,
              name: savedTimer.name,
              startTime: savedTimer.startTime,
              duration: savedTimer.duration,
              timer: timerObj,
              reminderId: savedTimer.reminderId
            ))

          print(
            "Timer \(timerId) expired while app was not running. Triggering notification..."
          )
        }
      }

      updateStatusIcon()
    } catch {
      print("Failed to load timers: \(error)")
    }
  }

  @objc private func menuWillOpen(_ notification: Notification) {
    guard let menu = notification.object as? NSMenu, menu == statusItem?.menu
    else { return }
    isMenuOpen = true
    startMenuRefreshTimer()
  }

  @objc private func menuWillClose(_ notification: Notification) {
    guard let menu = notification.object as? NSMenu, menu == statusItem?.menu
    else { return }
    isMenuOpen = false
    stopMenuRefreshTimer()
  }

  private var menuRefreshTimer: Timer?

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

  internal func showNameInputField() {
    nameInputPanel?.cleanup()
    nameInputPanel = NameInputPanel(delegate: self)
    nameInputPanel?.show(at: NSEvent.mouseLocation)
  }

  internal func updateStatusIcon() {
    if activeTimers.count > 0 {

      let symbolName: String
      if #available(macOS 15.0, *) {
        symbolName = "arrow.trianglehead.counterclockwise.rotate.90"
      } else {
        symbolName = "arrow.circlepath"

      }
      if let symbolImage = NSImage(
        systemSymbolName: symbolName,
        accessibilityDescription: nil)
      {
        let symbolSize = NSSize(width: 16, height: 16)
        symbolImage.size = symbolSize

        let text = activeTimers.count > 9 ? "+" : "\(activeTimers.count)"
        let attributes: [NSAttributedString.Key: Any] = [
          .font: NSFont.systemFont(ofSize: 9, weight: .medium),
          .foregroundColor: NSColor.black,
        ]
        let attributedString = NSAttributedString(
          string: text, attributes: attributes)
        let textSize = attributedString.size()

        let textImage = NSImage(size: textSize)
        textImage.lockFocus()
        attributedString.draw(at: NSPoint(x: 0, y: 0))
        textImage.unlockFocus()

        let combinedImage = NSImage(size: symbolSize)
        combinedImage.lockFocus()

        symbolImage.draw(
          at: NSPoint.zero, from: NSRect(origin: .zero, size: symbolSize),
          operation: .sourceOver, fraction: 1)

        let textPosition = NSPoint(
          x: (symbolSize.width - textSize.width) / 2,
          y: (symbolSize.height - textSize.height) / 2)
        textImage.draw(
          at: textPosition, from: NSRect(origin: .zero, size: textSize),
          operation: .sourceOver, fraction: 1)

        combinedImage.unlockFocus()

        statusItem?.button?.image = combinedImage
        statusItem?.button?.title = ""
      } else {
        print("SF Symbol not found.")
        statusItem?.button?.title = "\(activeTimers.count)"
        statusItem?.button?.image = nil
      }
    } else {
      statusItem?.button?.title = ""
      let symbolName: String
      if #available(macOS 15.0, *) {
        symbolName = "clock.arrow.trianglehead.counterclockwise.rotate.90"
      } else {
        symbolName = "clock.arrow.circlepath"
      }
      if let symbolImage = NSImage(
        systemSymbolName: symbolName,
        accessibilityDescription: nil)
      {
        symbolImage.size = NSSize(width: 18, height: 18)
        statusItem?.button?.image = symbolImage
      } else {
        print("SF Symbol not found.")
      }
    }
  }

  internal func createDragTimerPanel() {
    dragTimerPanel?.cleanup()
    dragTimerPanel = DragTimerPanel()
    dragTimerPanel?.show()
  }

  internal func updateDragTimerWindow(
    withText text: String, endTimeText: String, atPoint point: NSPoint
  ) {
    dragTimerPanel?.update(timerText: text, endTimeText: endTimeText, at: point)
  }

  internal func removeDragTimerPanel() {
    dragTimerPanel?.cleanup()
    dragTimerPanel = nil
  }

  internal func startOneTimeTimer(name: String?) {
    if let timerData = pendingTimerData
      ?? (dragTimeInterval > 0 ? (Date(), dragTimeInterval) : nil)
    {
      let timerId = UUID()
      var reminderId: String? = nil

      let timerObj = Timer.scheduledTimer(
        withTimeInterval: timerData.duration, repeats: false
      ) { [weak self] _ in
        self?.timerFinished(id: timerId)
      }

      if UserDefaults.standard.bool(forKey: "allowReminders") {
        if !UserDefaults.standard.bool(forKey: "ignoreShortTimers")
          || timerData.duration
            > (UserDefaults.standard.double(
              forKey: "shortTimerThresholdMinutes") * 60)
        {
          let reminderTitle = name ?? "Timer \(activeTimers.count + 1)"
          let reminderNotes =
            "Your timer for \(Int(timerData.duration / 60)) minute(s) has finished."
          let reminderTime = Date().addingTimeInterval(timerData.duration)

          do {
            reminderId = try RemindersManager.shared.createReminder(
              title: reminderTitle, notes: reminderNotes, dueDate: reminderTime)
          } catch {
            print("Failed to create reminder: \(error.localizedDescription)")
          }
        }
      }

      activeTimers.append(
        (
          id: timerId,
          name: name,
          startTime: timerData.startTime,
          duration: timerData.duration,
          timer: timerObj,
          reminderId: reminderId
        ))

      updateStatusIcon()
      updateMenu()
      saveTimers()
    }

    pendingTimerData = nil
    nameInputPanel?.cleanup()
    nameInputPanel = nil
  }

  private func timerFinished(id: UUID) {
    if let index = activeTimers.firstIndex(where: { $0.id == id }) {
      let timer = activeTimers[index]
      let timerName = timer.name
      NotificationManager.shared.dispatchNotification(timerName: timerName)
      activeTimers.remove(at: index)
    }

    updateStatusIcon()
    updateMenu()
    saveTimers()
  }

  @objc func cancelTimer(sender: NSMenuItem) {
    guard let timerIndex = sender.representedObject as? Int,
      timerIndex < activeTimers.count
    else {
      return
    }

    let timerToRemove = activeTimers[timerIndex]

    if UserDefaults.standard.bool(forKey: "deleteReminders") {
      if let reminderId = timerToRemove.reminderId {
        Task {
          do {
            try await RemindersManager.shared.deleteReminder(
              withIdentifier: reminderId)
          } catch {
            print("Failed to delete reminder: \(error.localizedDescription)")
          }
        }
      }
    }

    timerToRemove.timer.invalidate()
    activeTimers.remove(at: timerIndex)
    saveTimers()
    updateStatusIcon()

    if sender.menu != nil && !sender.isHidden {
      sender.menu?.cancelTracking()
    }

    updateMenu()
  }

  @objc func preferences() {
    PreferencesWindowController.shared.showWindow()
  }

  @objc func quit() {
    NSApplication.shared.terminate(nil)
  }

  private func updateMenu() {
    let menu = NSMenu()

    if activeTimers.count > 0 {
      menu.addItem(
        NSMenuItem(title: "Active Timers", action: nil, keyEquivalent: ""))

      for (index, timerInfo) in activeTimers.enumerated() {
        let remainingTime = timerInfo.startTime.addingTimeInterval(
          timerInfo.duration
        ).timeIntervalSince(Date())
        let formattedTime = formatTimeInterval(remainingTime)

        let displayName = timerInfo.name ?? "Timer \(index + 1)"
        let menuItem = NSMenuItem()
        menuItem.representedObject = index

        let customView = HoverView(
          normalText: "\(displayName): \(formattedTime)",
          hoverText: "Delete",
          frame: NSRect(x: 0, y: 0, width: 250, height: 22),
          index: index,
          target: self,
          action: #selector(cancelTimer(sender:))
        )
        menuItem.view = customView

        menu.addItem(menuItem)
      }

      menu.addItem(NSMenuItem.separator())
    }

    menu.addItem(
      NSMenuItem(
        title: "Preferences", action: #selector(preferences), keyEquivalent: ","
      ))
    menu.addItem(
      NSMenuItem(
        title: "Quit Dropclock", action: #selector(quit), keyEquivalent: "q"))

    statusItem?.menu = menu
  }

  private func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
    let totalSeconds = Int(max(0, timeInterval))
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
      return String(format: "%02d:%02d", minutes, seconds)
    }
  }

}

extension AppDelegate: NameInputPanelDelegate {
  func nameInputPanelDidConfirm(name: String?) {
    startOneTimeTimer(name: name)
  }

  func nameInputPanelDidCancel() {
    pendingTimerData = nil
  }
}
