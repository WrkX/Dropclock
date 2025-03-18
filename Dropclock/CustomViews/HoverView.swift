import AppKit

class HoverView: NSView {
  private let textField = NSTextField()
  private let normalText: String
  private let hoverText: String
  private weak var target: AnyObject?
  private let action: Selector
  private let index: Int

  init(
    normalText: String, hoverText: String, frame: NSRect, index: Int,
    target: AnyObject, action: Selector
  ) {
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
      textField.trailingAnchor.constraint(
        lessThanOrEqualTo: trailingAnchor, constant: -12),
    ])

    let clickGesture = NSClickGestureRecognizer(
      target: self, action: #selector(viewClicked))
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

    let options: NSTrackingArea.Options = [
      .mouseEnteredAndExited, .activeAlways, .inVisibleRect,
    ]
    let trackingArea = NSTrackingArea(
      rect: bounds, options: options, owner: self, userInfo: nil)
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
