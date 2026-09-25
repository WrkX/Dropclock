import AppKit
import ObjectiveC

extension AppDelegate {

  internal func setupDrag(for button: NSStatusBarButton) {
    button.target = self
    button.action = #selector(handleStatusButtonAction(_:))
    button.sendAction(on: [
      .leftMouseDown, .leftMouseDragged, .leftMouseUp, .rightMouseUp,
    ])
    attachExpandedInterfaceDelegateIfAvailable()
  }

  @objc internal func handleStatusButtonAction(_ sender: NSStatusBarButton) {
    if let event = NSApp.currentEvent {
      switch event.type {
      case .rightMouseDown, .rightMouseUp:
        if isTrackingStatusItem {
          endStatusItemTracking(cancelled: true)
        }
        cancelExpandedInterfaceSession()
        popStatusMenu()
        return
      case .leftMouseDown:
        beginStatusItemTracking()
        return
      case .leftMouseDragged:
        updateStatusItemTracking()
        return
      case .leftMouseUp:
        endStatusItemTracking(cancelled: false)
        return
      default:
        break
      }
    }

    let leftPressed = NSEvent.pressedMouseButtons & (1 << 0) != 0
    if !isTrackingStatusItem && leftPressed {
      beginStatusItemTracking()
    } else if isTrackingStatusItem && leftPressed {
      updateStatusItemTracking()
    } else if isTrackingStatusItem {
      endStatusItemTracking(cancelled: false)
    }
  }

  @objc(statusItem:didBeginExpandedInterfaceSession:)
  func statusItem(
    _ statusItem: NSStatusItem, didBeginExpandedInterfaceSession session: Any
  ) {
    if let event = NSApp.currentEvent,
      event.type == .rightMouseDown || event.type == .rightMouseUp
    {
      cancelExpandedInterfaceSession()
      return
    }
    if NSEvent.pressedMouseButtons & (1 << 1) != 0 {
      cancelExpandedInterfaceSession()
      return
    }
    let leftPressed = NSEvent.pressedMouseButtons & (1 << 0) != 0
    if !leftPressed {
      if isTrackingStatusItem {
        endStatusItemTracking(cancelled: false)
      } else {
        popStatusMenu()
      }
      cancelExpandedInterfaceSession()
      return
    }
    beginStatusItemTracking()
  }

  @objc(statusItemDidEndExpandedInterfaceSession:animated:)
  func statusItemDidEndExpandedInterfaceSession(
    _ statusItem: NSStatusItem, animated: Bool
  ) {
    if isTrackingStatusItem && NSEvent.pressedMouseButtons & (1 << 0) == 0 {
      endStatusItemTracking(cancelled: false)
    }
  }

  internal func beginStatusItemTracking() {
    guard !isTrackingStatusItem else { return }
    isTrackingStatusItem = true
    baseTime = Date()
    dragTimeInterval = 0
    statusItemAnchorPoint = statusItemScreenPoint()
    dragStartLocation = NSEvent.mouseLocation
    statusItem?.button?.highlight(true)
    trackingSawMouseDown = NSEvent.pressedMouseButtons & (1 << 0) != 0
    installStatusItemMouseMonitors()
    startTrackingPollTimer()
  }

  internal func updateStatusItemTracking() {
    guard isTrackingStatusItem, let start = dragStartLocation else { return }

    let mouseLoc = NSEvent.mouseLocation
    let deltaX = abs(mouseLoc.x - start.x)
    let deltaY = abs(mouseLoc.y - start.y)
    let maxDelta = max(deltaX, deltaY)
    let isCtrlKeyPressed = NSEvent.modifierFlags.contains(.control)
    let isShiftKeyPressed = NSEvent.modifierFlags.contains(.shift)

    var calculatedInterval: TimeInterval = 0
    if isCtrlKeyPressed
      && UserDefaults.standard.bool(forKey: "allowFiveMinuteMode")
    {
      if maxDelta >= SecondThreshold {
        let increments = Int((maxDelta - SecondThreshold) / 5) + 1
        calculatedInterval = TimeInterval(increments * 60 * 5)
      } else {
        removeDragTimerPanel()
        calculatedInterval = 0
      }
    } else if isShiftKeyPressed
      && UserDefaults.standard.bool(forKey: "allowSecondsMode")
    {
      if maxDelta >= SecondThreshold {
        let increments = Int(maxDelta - SecondThreshold) + 1
        calculatedInterval = TimeInterval(30 + increments)
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
      if calculatedInterval <= 3600
        || UserDefaults.standard.bool(forKey: "viewAsMinutes")
      {
        let minutes = Int(calculatedInterval) / 60
        displayText = "\(minutes) min"
      } else {
        let hours = Int(calculatedInterval) / 3600
        let minutes = Int(Int(calculatedInterval) - hours * 3600) / 60
        displayText = "\(hours) hr \(minutes) min"
      }
    }

    if maxDelta > 2 && UserDefaults.standard.bool(forKey: "showDragIndicator") {
      if dragLineView == nil {
        createDragLine()
      }
      updateDragLine(endPoint: mouseLoc)
    }

    if maxDelta >= SecondThreshold && dragTimerPanel == nil {
      createDragTimerPanel()
    }

    if dragTimerPanel != nil {
      let windowWidth = dragTimerPanel!.frame.width
      let adjustedOrigin = NSPoint(
        x: mouseLoc.x - (windowWidth / 2) - 10, y: mouseLoc.y)
      updateDragTimerWindow(
        withText: displayText, endTimeText: formatter.string(from: endTime!),
        atPoint: adjustedOrigin)
    }
  }

  internal func endStatusItemTracking(cancelled: Bool) {
    guard isTrackingStatusItem else { return }
    if !cancelled {
      updateStatusItemTracking()
    }
    isTrackingStatusItem = false
    stopTrackingPollTimer()
    removeStatusItemMouseMonitors()
    removeDragTimerPanel()
    removeDragLine()
    statusItem?.button?.highlight(false)

    let interval = dragTimeInterval
    dragTimeInterval = 0
    dragStartLocation = nil

    cancelExpandedInterfaceSession()
    updateStatusIcon()

    guard !cancelled else { return }

    if interval > 0 {
      pendingTimerData = (startTime: Date(), duration: interval)
      if UserDefaults.standard.bool(forKey: "allowCustomNames") {
        // Let the menu bar finish its mouse-up and expanded-interface callbacks
        // before activating the text field window.
        DispatchQueue.main.async { [weak self] in
          guard let self, self.pendingTimerData != nil else { return }
          self.showNameInputField()
        }
      } else {
        startOneTimeTimer(name: nil)
      }
    } else {
      popStatusMenu()
    }
  }

  internal func popStatusMenu() {
    guard !isMenuPresentationPending, !isMenuOpen, pendingTimerData == nil else {
      return
    }
    isMenuPresentationPending = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      defer { self.isMenuPresentationPending = false }
      guard self.pendingTimerData == nil, !self.isMenuOpen,
        let menu = self.statusMenu, let button = self.statusItem?.button
      else { return }
      let buttonFrame = button.window?.convertToScreen(
        button.convert(button.bounds, to: nil))
      let origin = buttonFrame.map { NSPoint(x: $0.minX, y: $0.minY) }
        ?? NSEvent.mouseLocation
      _ = menu.popUp(positioning: nil, at: origin, in: nil)
    }
  }

  internal func removeStatusItemMouseMonitors() {
    stopTrackingPollTimer()
    if let localMonitor = statusItemLocalMonitor {
      NSEvent.removeMonitor(localMonitor)
      statusItemLocalMonitor = nil
    }
    if let globalMonitor = statusItemGlobalMonitor {
      NSEvent.removeMonitor(globalMonitor)
      statusItemGlobalMonitor = nil
    }
  }

  private func startTrackingPollTimer() {
    stopTrackingPollTimer()
    let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
      self?.pollStatusItemTracking()
    }
    RunLoop.main.add(timer, forMode: .common)
    statusItemTrackingTimer = timer
  }

  private func stopTrackingPollTimer() {
    statusItemTrackingTimer?.invalidate()
    statusItemTrackingTimer = nil
  }

  private func pollStatusItemTracking() {
    guard isTrackingStatusItem else { return }
    updateStatusItemTracking()
    let leftPressed = NSEvent.pressedMouseButtons & (1 << 0) != 0
    if leftPressed {
      trackingSawMouseDown = true
    } else if trackingSawMouseDown {
      endStatusItemTracking(cancelled: false)
    }
  }

  private func installStatusItemMouseMonitors() {
    removeStatusItemMouseMonitors()
    let mask: NSEvent.EventTypeMask = [.leftMouseDragged, .leftMouseUp]
    statusItemLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) {
      [weak self] event in
      self?.handleTrackedMouseEvent(event)
      return event
    }
    statusItemGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask)
    { [weak self] event in
      self?.handleTrackedMouseEvent(event)
    }
  }

  private func handleTrackedMouseEvent(_ event: NSEvent) {
    switch event.type {
    case .leftMouseDragged:
      updateStatusItemTracking()
    case .leftMouseUp:
      endStatusItemTracking(cancelled: false)
    default:
      break
    }
  }

  private func statusItemScreenPoint() -> CGPoint {
    let mouse = NSEvent.mouseLocation
    guard let button = statusItem?.button, let window = button.window else {
      return mouse
    }

    let rectInWindow = button.convert(button.bounds, to: nil)
    let screenRect = window.convertToScreen(rectInWindow)
    let candidate = CGPoint(x: screenRect.midX, y: screenRect.midY)
    let dx = candidate.x - mouse.x
    let dy = candidate.y - mouse.y
    if (dx * dx + dy * dy) > 80 * 80 {
      return mouse
    }
    return candidate
  }

  private func createDragLine() {
    let screen =
      NSScreen.screens.first { $0.frame.contains(statusItemAnchorPoint) }
      ?? NSScreen.main
    guard let screen else { return }

    dragLineWindow = NSWindow(
      contentRect: screen.frame, styleMask: .borderless, backing: .buffered,
      defer: false)
    dragLineWindow?.backgroundColor = .clear
    dragLineWindow?.ignoresMouseEvents = true
    dragLineWindow?.level = .statusBar
    dragLineWindow?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    dragLineWindow?.isReleasedWhenClosed = false
    dragLineWindow?.orderFront(nil)

    dragLineView = DragLineView(frame: NSRect(origin: .zero, size: screen.frame.size))
    dragLineView?.wantsLayer = true
    dragLineWindow?.contentView?.addSubview(dragLineView!)
    updateDragLine(endPoint: NSEvent.mouseLocation)
  }

  private func updateDragLine(endPoint: NSPoint) {
    guard let lineView = dragLineView, let window = dragLineWindow else {
      return
    }
    let origin = window.frame.origin
    let start = NSPoint(
      x: statusItemAnchorPoint.x - origin.x,
      y: statusItemAnchorPoint.y - origin.y)
    let end = NSPoint(x: endPoint.x - origin.x, y: endPoint.y - origin.y)
    lineView.update(start: start, end: end)
  }

  private func removeDragLine() {
    dragLineView?.removeFromSuperview()
    dragLineView = nil
    dragLineWindow?.orderOut(nil)
    dragLineWindow = nil
  }

  private func attachExpandedInterfaceDelegateIfAvailable() {
    guard let statusItem else { return }
    if let proto = NSProtocolFromString("NSStatusItemExpandedInterfaceDelegate"),
      !class_conformsToProtocol(AppDelegate.self, proto)
    {
      class_addProtocol(AppDelegate.self, proto)
    }

    let setter = NSSelectorFromString("setExpandedInterfaceDelegate:")
    if statusItem.responds(to: setter) {
      statusItem.perform(setter, with: self)
    }
  }

  private func cancelExpandedInterfaceSession() {
    guard let statusItem else { return }
    let getter = NSSelectorFromString("expandedInterfaceSession")
    guard statusItem.responds(to: getter),
      let unmanaged = statusItem.perform(getter)
    else { return }
    let session = unmanaged.takeUnretainedValue()
    let cancel = NSSelectorFromString("cancel")
    if session.responds(to: cancel) {
      _ = session.perform(cancel)
    }
  }
}
