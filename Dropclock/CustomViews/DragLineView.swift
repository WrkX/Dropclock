import AppKit

class DragLineView: NSView {
    var startPoint: NSPoint = .zero
    var endPoint: NSPoint = .zero

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw the line
        let linePath = NSBezierPath()
        linePath.move(to: startPoint)
        linePath.line(to: endPoint)
        NSColor.labelColor.setStroke()
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
