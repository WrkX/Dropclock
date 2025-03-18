import AppKit

class DragLineView: NSView {
  var startPoint: NSPoint = .zero
  var endPoint: NSPoint = .zero

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    let linePath = NSBezierPath()
    linePath.move(to: startPoint)
    linePath.line(to: endPoint)
    if UserDefaults.standard.bool(forKey: "changeRubberbandColor") {
      if let colorData = UserDefaults.standard.data(forKey: "dragLineColor"),
        let color = try? NSKeyedUnarchiver.unarchivedObject(
          ofClass: NSColor.self, from: colorData)
      {
        color.setStroke()
      } else {
        NSColor.labelColor.setStroke()
      }
    } else {
      NSColor.labelColor.setStroke()
    }

    linePath.lineWidth = 3.0
    linePath.lineCapStyle = .round
    linePath.stroke()

  }

  func update(start: NSPoint, end: NSPoint) {
    startPoint = start
    endPoint = end
    needsDisplay = true
    self.layer?.setNeedsDisplay()
  }
}
