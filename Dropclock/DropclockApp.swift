import SwiftUI
import UserNotifications
import EventKit

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
  
  private var dragTimeInterval: TimeInterval = 0
  private var dragStartLocation: CGPoint?
  
  private let MinuteThreshold: CGFloat = 130
  private let ThirtySecondThreshold: CGFloat = 80
  private let SecondThreshold: CGFloat = 50
  
  private var timer: Timer?
  private var activeTimers: [(id: UUID, name: String?, startTime: Date, duration: TimeInterval, timer: Timer, reminderId: String?)] = []
  private var dragTimerWindow: NSWindow?
  private var nameInputWindow: NSWindow?
  private var nameInputField: NSTextField?
  private var pendingTimerData: (startTime: Date, duration: TimeInterval)?
  
  private var endTime: Date?
  private var menuUpdateTimer: Timer?
  private var isMenuOpen = false
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem?.button {
      updateStatusIcon()
      setupDrag(for: button)
    }
    checkForPermission()
    loadSavedTimers()
    
    updateMenu()
    
    Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      self?.baseTime = Date() // Update base time every minute
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
  
  struct SavedTimer: Codable {
    let id: String
    let name: String?
    let startTime: Date
    let duration: TimeInterval
    let reminderId: String?
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
    guard let data = UserDefaults.standard.data(forKey: "SavedTimers") else { return }
    
    do {
      let savedTimers = try JSONDecoder().decode([SavedTimer].self, from: data)
      
      for savedTimer in savedTimers {
        let timerId = UUID(uuidString: savedTimer.id) ?? UUID()
        let now = Date()
        
        let endTime = savedTimer.startTime.addingTimeInterval(savedTimer.duration)
        let remainingTime = endTime.timeIntervalSince(now)
        
        if remainingTime > 0 {
          let timerObj = Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { [weak self] _ in
            self?.timerFinished(id: timerId)
          }
          
          activeTimers.append((
            id: timerId,
            name: savedTimer.name,
            startTime: savedTimer.startTime,
            duration: savedTimer.duration,
            timer: timerObj,
            reminderId: savedTimer.reminderId
          ))
        } else {
          let timerObj = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.timerFinished(id: timerId)
          }
          
          activeTimers.append((
            id: timerId,
            name: savedTimer.name,
            startTime: savedTimer.startTime,
            duration: savedTimer.duration,
            timer: timerObj,
            reminderId: savedTimer.reminderId
          ))
          
          print("Timer \(timerId) expired while app was not running. Triggering notification...")
        }
      }
      
      updateStatusIcon()
    } catch {
      print("Failed to load timers: \(error)")
    }
  }
  
  @objc private func menuWillOpen(_ notification: Notification) {
    guard let menu = notification.object as? NSMenu, menu == statusItem?.menu else { return }
    isMenuOpen = true
    startMenuRefreshTimer()
  }
  
  @objc private func menuWillClose(_ notification: Notification) {
    guard let menu = notification.object as? NSMenu, menu == statusItem?.menu else { return }
    isMenuOpen = false
    stopMenuRefreshTimer()
  }
  
  private var menuRefreshTimer: Timer?
  
  private func startMenuRefreshTimer() {
    stopMenuRefreshTimer()
    menuRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      guard let self = self, self.isMenuOpen else { return }
      self.updateMenu()
    }
  }
  
  private func stopMenuRefreshTimer() {
    menuRefreshTimer?.invalidate()
    menuRefreshTimer = nil
  }
  
  private func startMenuUpdateTimer() {
    menuUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      self?.updateMenu()
    }
  }
  
  private func setupDrag(for button: NSStatusBarButton) {
    let dragRecognizer = NSPanGestureRecognizer(target: self, action: #selector(handleDrag(_:)))
    button.addGestureRecognizer(dragRecognizer)
  }
  
  @objc private func handleDrag(_ sender: NSPanGestureRecognizer) {
    let translation = sender.translation(in: sender.view)
    let isCtrlKeyPressed = NSEvent.modifierFlags.contains(.control)
    
    switch sender.state {
    case .began:
      baseTime = Date()
      dragStartLocation = translation
      
    case .changed:
      guard let start = dragStartLocation else { return }
      let deltaX = abs(translation.x - start.x)
      let deltaY = abs(translation.y - start.y)
      let maxDelta = max(deltaX, deltaY)
      
      var calculatedInterval: TimeInterval = 0
      if isCtrlKeyPressed {
        if maxDelta >= SecondThreshold {
          let increments = Int((maxDelta - SecondThreshold) / 5) + 1
          calculatedInterval = TimeInterval(increments * 60 * 5)
        } else {
          removeDragTimerPanel()
          calculatedInterval = 0
        }
      } else {
        if maxDelta < SecondThreshold {
          removeDragTimerPanel()
          calculatedInterval = 0
        } else if maxDelta < ThirtySecondThreshold {
          let increments = Int(maxDelta - SecondThreshold) + 1
          calculatedInterval = TimeInterval(30 + increments)
        } else if maxDelta < MinuteThreshold {
          let increments = Int((maxDelta - ThirtySecondThreshold) / 5)
          calculatedInterval = TimeInterval(60 + increments * 30)
        } else {
          let increments = Int((maxDelta - MinuteThreshold) / 5)
          calculatedInterval = TimeInterval(300 + increments * 60)
        }
      }
      
      dragTimeInterval = calculatedInterval
      endTime = baseTime.addingTimeInterval(dragTimeInterval)
      
      let displayText: String
      if calculatedInterval < 60 {
        displayText = "\(Int(calculatedInterval)) sec"
      } else if calculatedInterval < 300 {
        let minutes = Int(calculatedInterval) / 60
        let seconds = Int(calculatedInterval) - minutes * 60
        displayText = "\(minutes) min \(seconds) sec"
      } else {
        if calculatedInterval >= 3600 {
          let hours = Int(calculatedInterval) / 3600
          let minutes = Int(Int(calculatedInterval) - hours * 3600) / 60
          displayText = "\(hours) hr \(minutes) min"
        } else {
          let minutes = Int(calculatedInterval) / 60
          displayText = "\(minutes) min"
        }
      }
      
      let mouseLoc = NSEvent.mouseLocation
      
      if maxDelta >= SecondThreshold && dragTimerPanel == nil {
        createDragTimerPanel()
      }
      
      if dragTimerPanel != nil {
        let windowWidth = dragTimerPanel!.frame.width
        let adjustedOrigin = NSPoint(x: mouseLoc.x - (windowWidth/2) - 10, y: mouseLoc.y)
        updateDragTimerWindow(withText: displayText, endTimeText: formatter.string(from: endTime!), atPoint: adjustedOrigin)
      }
      
    case .ended, .cancelled:
      removeDragTimerPanel()
      if dragTimeInterval > 0 {
        if UserDefaults.standard.bool(forKey: "allowCustomNames") {
          pendingTimerData = (startTime: Date(), duration: dragTimeInterval)
          showNameInputField()
        } else {
          startOneTimeTimer(name: nil)
        }
      }
      dragTimeInterval = 0
      dragStartLocation = nil
      updateStatusIcon()
      
    default:
      break
    }
  }
  
  private func showNameInputField() {
    cleanupNameInputWindow()  // Clean up any existing window
    
    let mouseLoc = NSEvent.mouseLocation
    
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 160, height: 105),
      styleMask: [.titled, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    
    panel.isFloatingPanel = true
    panel.level = .floating
    panel.titlebarAppearsTransparent = true
    panel.titleVisibility = .hidden
    panel.isMovableByWindowBackground = true
    
    let blurView = NSVisualEffectView(frame: panel.contentView!.bounds)
    blurView.material = .hudWindow
    blurView.state = .active
    blurView.wantsLayer = true
    blurView.layer?.cornerRadius = 8
    
    let stackView = NSStackView(frame: blurView.bounds)
    stackView.orientation = .vertical
    stackView.spacing = 8
    stackView.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    
    let label = NSTextField(labelWithString: "Timer Name")
    label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
    label.textColor = .secondaryLabelColor
    label.alignment = .left
    label.isBordered = false
    label.drawsBackground = false
    
    // Text field setup
    let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 50, height: 22))
    textField.placeholderString = "Timer \(activeTimers.count + 1)"
    textField.isEditable = true
    textField.isSelectable = true
    textField.delegate = self
    
    // Use the native bordered style
    textField.isBordered = true          // Show border
    textField.isBezeled = true             // Enable bezel style
    textField.bezelStyle = .roundedBezel // Rounded corners
    
    // Default appearance settings
    textField.drawsBackground = true
    textField.backgroundColor = .controlBackgroundColor
    textField.textColor = .labelColor
    textField.focusRingType = .default
    
    // Remove custom layer properties
    textField.wantsLayer = false
    
    
    let buttonStack = NSStackView()
    buttonStack.orientation = .horizontal
    buttonStack.spacing = 8
    buttonStack.distribution = .fillEqually
    
    let cancelButton = NSButton(frame: NSRect(x: 0, y: 0, width: 80, height: 22))
    cancelButton.title = "Cancel"
    cancelButton.bezelStyle = .rounded
    cancelButton.target = self
    cancelButton.action = #selector(cancelNameInput)
    cancelButton.wantsLayer = true
    
    let createButton = NSButton(frame: NSRect(x: 0, y: 0, width: 80, height: 22))
    createButton.title = "Create"
    createButton.bezelStyle = .rounded
    createButton.target = self
    createButton.action = #selector(confirmNameInput)
    createButton.keyEquivalent = "\r"  // Enter key
    createButton.wantsLayer = true
    
    if #available(macOS 11.0, *) {
      createButton.controlSize = .regular
    } else {
      createButton.highlight(true)
    }
    
    buttonStack.addArrangedSubview(cancelButton)
    buttonStack.addArrangedSubview(createButton)
    
    stackView.addArrangedSubview(label)
    stackView.addArrangedSubview(textField)
    stackView.addArrangedSubview(buttonStack)
    
    blurView.addSubview(stackView)
    panel.contentView?.addSubview(blurView)
    
    stackView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.leadingAnchor.constraint(equalTo: blurView.leadingAnchor, constant: 8),
      stackView.trailingAnchor.constraint(equalTo: blurView.trailingAnchor, constant: -8),
      stackView.topAnchor.constraint(equalTo: blurView.topAnchor, constant: 8),
      stackView.bottomAnchor.constraint(equalTo: blurView.bottomAnchor, constant: -8)
    ])
    
    label.translatesAutoresizingMaskIntoConstraints = false
    textField.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
      label.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
      textField.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
      textField.trailingAnchor.constraint(equalTo: stackView.trailingAnchor)
    ])
    
    let panelOrigin = NSPoint(x: mouseLoc.x - 125, y: mouseLoc.y - 75)
    panel.setFrameOrigin(panelOrigin)
    
    panel.orderFront(nil)
    panel.makeKeyAndOrderFront(nil)
    panel.level = .floating
    
    DispatchQueue.main.async {
      NSApp.activate(ignoringOtherApps: true)
      panel.makeFirstResponder(textField)
    }
    
    nameInputWindow = panel
    nameInputField = textField
  }
  
  
  @objc private func cancelNameInput() {
    // Just close the window without creating any timer or reminder
    nameInputWindow?.close()
    nameInputWindow = nil
    pendingTimerData = nil  // Clear any pending timer data
  }
  
  // Add this method to handle the Create button action
  @objc private func confirmNameInput() {
    let timerName = nameInputField?.stringValue.isEmpty ?? true ? nil : nameInputField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    startOneTimeTimer(name: timerName)
    nameInputWindow?.close()
    nameInputWindow = nil
  }
  
  private func updateStatusIcon() {
    if activeTimers.count > 0 {
            // Use the SF Symbol as a background and overlay the count
            if let symbolImage = NSImage(systemSymbolName: "arrow.trianglehead.counterclockwise.rotate.90", accessibilityDescription: nil) {
                let symbolSize = NSSize(width: 16, height: 16) // Adjust size as needed
                symbolImage.size = symbolSize

                let text = activeTimers.count > 9 ? "+" : "\(activeTimers.count)"
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9, weight: .medium),
                    .foregroundColor: NSColor.black
                ]
                let attributedString = NSAttributedString(string: text, attributes: attributes)
                let textSize = attributedString.size()

                let textImage = NSImage(size: textSize)
                textImage.lockFocus()
                attributedString.draw(at: NSPoint(x: 0, y: 0))
                textImage.unlockFocus()

                let combinedImage = NSImage(size: symbolSize)
                combinedImage.lockFocus()

                symbolImage.draw(at: NSPoint.zero, from: NSRect(origin: .zero, size: symbolSize), operation: .sourceOver, fraction: 1)

                let textPosition = NSPoint(x: (symbolSize.width - textSize.width) / 2, y: (symbolSize.height - textSize.height) / 2)
                textImage.draw(at: textPosition, from: NSRect(origin: .zero, size: textSize), operation: .sourceOver, fraction: 1)

                combinedImage.unlockFocus()

                statusItem?.button?.image = combinedImage
                statusItem?.button?.title = "" // Clear any title
            } else {
                print("SF Symbol not found.")
                statusItem?.button?.title = "\(activeTimers.count)"
                statusItem?.button?.image = nil
            }
      } else {
          // Show the SF Symbol image
          statusItem?.button?.title = "" // Clear the title
          if let symbolImage = NSImage(systemSymbolName: "clock.arrow.trianglehead.counterclockwise.rotate.90", accessibilityDescription: nil) {
              symbolImage.size = NSSize(width: 18, height: 18) // Adjust size as needed
              statusItem?.button?.image = symbolImage
          } else {
              print("SF Symbol not found.")
          }
      }
  }
  
  private var dragTimerPanel: NSPanel?
  private var timerLabel: NSTextField?
  private var endTimeLabel: NSTextField?
  
  private func createDragTimerPanel() {
    removeDragTimerPanel()
    
    guard let screen = NSScreen.main else { return }
    let windowSize = NSSize(width: 120, height: 50)
    let windowOrigin = NSPoint(x: screen.frame.midX - windowSize.width / 2,
                               y: screen.frame.midY - windowSize.height / 2)
    
    let panel = NSPanel(
      contentRect: NSRect(origin: windowOrigin, size: windowSize),
      styleMask: [.nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    
    panel.isFloatingPanel = true
    panel.level = .popUpMenu
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isMovable = false
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    
    let blurView = NSVisualEffectView(frame: panel.contentView!.bounds)
    blurView.material = .hudWindow
    blurView.blendingMode = .behindWindow
    blurView.state = .active
    blurView.wantsLayer = true
    blurView.layer?.cornerRadius = 12
    blurView.layer?.masksToBounds = true
    blurView.layer?.borderWidth = 1
    blurView.layer?.borderColor = NSColor.secondaryLabelColor.withAlphaComponent(0.2).cgColor
    
    let stackView = NSStackView()
    stackView.orientation = .vertical
    stackView.alignment = .centerX
    stackView.spacing = 3
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    timerLabel = NSTextField(labelWithString: "00:00")
    timerLabel?.font = NSFont.systemFont(ofSize: 16, weight: .medium)
    timerLabel?.textColor = .white
    timerLabel?.alignment = .center
    timerLabel?.isBordered = false
    timerLabel?.drawsBackground = false
    
    endTimeLabel = NSTextField(labelWithString: "at 12:00")
    endTimeLabel?.font = NSFont.systemFont(ofSize: 13)
    endTimeLabel?.textColor = .white
    endTimeLabel?.alignment = .center
    endTimeLabel?.isBordered = false
    endTimeLabel?.drawsBackground = false
    
    stackView.addArrangedSubview(timerLabel!)
    stackView.addArrangedSubview(endTimeLabel!)
    
    blurView.addSubview(stackView)
    panel.contentView?.addSubview(blurView)
    
    NSLayoutConstraint.activate([
      stackView.centerXAnchor.constraint(equalTo: blurView.centerXAnchor),
      stackView.centerYAnchor.constraint(equalTo: blurView.centerYAnchor),
      stackView.widthAnchor.constraint(equalTo: blurView.widthAnchor, multiplier: 0.9),
    ])
    
    panel.orderFront(nil)
    dragTimerPanel = panel
  }
  
  private func updateDragTimerWindow(withText text: String, endTimeText: String, atPoint point: NSPoint) {
    DispatchQueue.main.async {
      self.timerLabel?.stringValue = text
      self.endTimeLabel?.stringValue = "at: \(endTimeText)"
      
      let windowWidth = self.dragTimerPanel?.frame.width ?? 0
      let windowHeight = self.dragTimerPanel?.frame.height ?? 0
      let newOrigin = NSPoint(x: point.x - windowWidth / 2,
                              y: point.y - windowHeight / 2)
      self.dragTimerPanel?.setFrameOrigin(newOrigin)
    }
  }
  
  private func removeDragTimerPanel() {
    dragTimerPanel?.close()
    dragTimerPanel = nil
  }
  
  private func startOneTimeTimer(name: String?) {
    if let timerData = pendingTimerData ?? (dragTimeInterval > 0 ? (Date(), dragTimeInterval) : nil) {
      let timerId = UUID()
      var reminderId: String? = nil
      
      let timerObj = Timer.scheduledTimer(withTimeInterval: timerData.duration, repeats: false) { [weak self] _ in
        self?.timerFinished(id: timerId)
      }
      
      if UserDefaults.standard.bool(forKey: "allowReminders") {
        let reminderTitle = name ?? "Timer \(activeTimers.count + 1)"
        let reminderNotes = "Your timer for \(Int(timerData.duration / 60)) minute(s) has finished."
        let reminderTime = Date().addingTimeInterval(timerData.duration)
        
        do {
          reminderId = try RemindersManager.shared.createReminder(title: reminderTitle, notes: reminderNotes, dueDate: reminderTime)
        } catch {
          print("Failed to create reminder: \(error.localizedDescription)")
        }
      }
      
      activeTimers.append((
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
    nameInputWindow?.close()
    nameInputWindow = nil
  }
  
  private func timerFinished(id: UUID) {
    if let index = activeTimers.firstIndex(where: { $0.id == id }) {
      let timer = activeTimers[index]
      let timerName = timer.name // Get the timer's name
      NotificationManager.shared.dispatchNotification(timerName: timerName) // Pass the name to the notification
      activeTimers.remove(at: index)
    }
    
    updateStatusIcon()
    updateMenu()
    saveTimers()
  }
  
  @objc func cancelTimer(sender: NSMenuItem) {
    guard let timerIndex = sender.representedObject as? Int,
          timerIndex < activeTimers.count else {
      return
    }
    
    let timerToRemove = activeTimers[timerIndex]
    
    if UserDefaults.standard.bool(forKey: "deleteReminders") {
      if let reminderId = timerToRemove.reminderId {
        Task {
          do {
            try await RemindersManager.shared.deleteReminder(withIdentifier: reminderId)
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
  
  func checkForPermission() {
    let notificationCenter = UNUserNotificationCenter.current()
    notificationCenter.getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .authorized:
        NotificationManager.shared.dispatchNotification()
      case .denied:
        return
      case .notDetermined:
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { didAllow, error in
          if didAllow {
            NotificationManager.shared.dispatchNotification()
          }
        }
      default:
        return
      }
    }
  }
  
  
  @objc func quit() {
    NSApplication.shared.terminate(nil)
  }
  
  private func updateMenu() {
    let menu = NSMenu()
    
    if activeTimers.count > 0 {
      menu.addItem(NSMenuItem(title: "Active Timers", action: nil, keyEquivalent: ""))
      
      for (index, timerInfo) in activeTimers.enumerated() {
        let remainingTime = timerInfo.startTime.addingTimeInterval(timerInfo.duration).timeIntervalSince(Date())
        let formattedTime = formatTimeInterval(remainingTime)
        
        let displayName = timerInfo.name ?? "Timer \(index + 1)"
        let menuItem = NSMenuItem()
        menuItem.representedObject = index
        
        let customView = ImprovedHoverView(
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
    
    menu.addItem(NSMenuItem(title: "Preferences", action: #selector(preferences), keyEquivalent: ","))
    menu.addItem(NSMenuItem(title: "Quit Dropclock", action: #selector(quit), keyEquivalent: "q"))
    
    statusItem?.menu = menu
  }
  
  class ImprovedHoverView: NSView {
    private let textField = NSTextField()
    private let normalText: String
    private let hoverText: String
    private weak var target: AnyObject?
    private let action: Selector
    private let index: Int
    
    init(normalText: String, hoverText: String, frame: NSRect, index: Int, target: AnyObject, action: Selector) {
      self.normalText = normalText
      self.hoverText = hoverText
      self.index = index
      self.target = target
      self.action = action
      super.init(frame: frame)
      
      setupView()
      updateTrackingAreas()
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
      textField.isEditable = false
      textField.isBordered = false
      textField.drawsBackground = false
      textField.stringValue = normalText
      textField.font = NSFont.systemFont(ofSize: 13)
      textField.textColor = .labelColor
      textField.translatesAutoresizingMaskIntoConstraints = false
      
      addSubview(textField)
      
      NSLayoutConstraint.activate([
        textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
        textField.centerYAnchor.constraint(equalTo: centerYAnchor),
        textField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12)
      ])
      
      let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(viewClicked))
      addGestureRecognizer(clickGesture)
    }
    
    @objc private func viewClicked() {
      if let target = target {
        let tempMenuItem = NSMenuItem()
        tempMenuItem.representedObject = index
        _ = target.perform(action, with: tempMenuItem)
        
        if let menu = enclosingMenuItem?.menu {
          menu.cancelTracking()
        }
      }
    }
    
    override func updateTrackingAreas() {
      for area in trackingAreas {
        removeTrackingArea(area)
      }
      
      let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect]
      let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
      addTrackingArea(trackingArea)
      
      super.updateTrackingAreas()
    }
    
    override func mouseEntered(with event: NSEvent) {
      NSAnimationContext.runAnimationGroup({ context in
        context.duration = 0.2
        textField.animator().textColor = .systemRed
        textField.animator().stringValue = hoverText
      })
    }
    
    override func mouseExited(with event: NSEvent) {
      NSAnimationContext.runAnimationGroup({ context in
        context.duration = 0.2
        textField.animator().textColor = .labelColor
        textField.animator().stringValue = normalText
      })
    }
    
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      updateTrackingAreas()
    }
    
    override func viewDidMoveToSuperview() {
      super.viewDidMoveToSuperview()
      updateTrackingAreas()
    }
    
    override func mouseMoved(with event: NSEvent) {
      let point = convert(event.locationInWindow, from: nil)
      if bounds.contains(point) && textField.stringValue != hoverText {
        textField.textColor = .systemRed
        textField.stringValue = hoverText
      } else if !bounds.contains(point) && textField.stringValue != normalText {
        textField.textColor = .labelColor
        textField.stringValue = normalText
      }
    }
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
  
  private func cleanupNameInputWindow() {
    nameInputWindow?.close()
    nameInputWindow = nil
    nameInputField = nil
  }
}

extension AppDelegate: NSTextFieldDelegate {
  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    if commandSelector == #selector(NSResponder.insertNewline(_:)) {
      // When Enter is pressed
      let timerName = (control as? NSTextField)?.stringValue.isEmpty ?? true ? nil : (control as? NSTextField)?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
      startOneTimeTimer(name: timerName)
      nameInputWindow?.close()  // Make sure to close the window
      return true
    }
    if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
      cancelNameInput()
      return true
    }
    return false
  }
}
