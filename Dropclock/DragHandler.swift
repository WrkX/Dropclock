import AppKit
import SwiftUI

extension AppDelegate {
  internal func setupDrag(for button: NSStatusBarButton) {
    let dragRecognizer = NSPanGestureRecognizer(
      target: self, action: #selector(handleDrag(_:)))
    button.addGestureRecognizer(dragRecognizer)
  }

  @objc internal func handleDrag(_ sender: NSPanGestureRecognizer) {
    let translation = sender.translation(in: sender.view)
    let isCtrlKeyPressed = NSEvent.modifierFlags.contains(.control)
    let isShiftKeyPressed = NSEvent.modifierFlags.contains(.shift)

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
      if isCtrlKeyPressed && UserDefaults.standard.bool(forKey: "allowFiveMinuteMode") {
        if maxDelta >= SecondThreshold {
          let increments = Int((maxDelta - SecondThreshold) / 5) + 1
          calculatedInterval = TimeInterval(increments * 60 * 5)
        } else {
          removeDragTimerPanel()
          calculatedInterval = 0
        }
      } else if isShiftKeyPressed && UserDefaults.standard.bool(forKey: "allowSecondsMode") {
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
        let adjustedOrigin = NSPoint(
          x: mouseLoc.x - (windowWidth / 2) - 10, y: mouseLoc.y)
        updateDragTimerWindow(
          withText: displayText, endTimeText: formatter.string(from: endTime!),
          atPoint: adjustedOrigin)
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
}
