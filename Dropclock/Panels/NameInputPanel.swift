import SwiftUI
import AppKit

class NameInputPanel:NSObject {
    private var window: NSPanel?
    private var textField: NSTextField?
    private weak var delegate: NameInputPanelDelegate?
    
    init(delegate: NameInputPanelDelegate) {
        self.delegate = delegate
    }
    
    func show(at point: NSPoint) {        
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
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 50, height: 22))
        textField.placeholderString = "Timer \(UserDefaults.standard.integer(forKey: "timerCount") + 1)"
        textField.isEditable = true
        textField.isSelectable = true
        textField.delegate = self
        textField.isBordered = true
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.drawsBackground = true
        textField.backgroundColor = .controlBackgroundColor
        textField.textColor = .labelColor
        textField.focusRingType = .default
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
        createButton.keyEquivalent = "\r"
        createButton.wantsLayer = true
        
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
        
        let panelOrigin = NSPoint(x: point.x - 125, y: point.y - 75)
        panel.setFrameOrigin(panelOrigin)
        
        panel.orderFront(nil)
        panel.makeKeyAndOrderFront(nil)
        panel.level = .floating
        
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeFirstResponder(textField)
        }
        
        self.window = panel
        self.textField = textField
    }
    
    @objc private func cancelNameInput() {
        cleanup()
        delegate?.nameInputPanelDidCancel()
    }
    
    @objc private func confirmNameInput() {
        let timerName = textField?.stringValue.isEmpty ?? true ? nil : textField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanup()
        delegate?.nameInputPanelDidConfirm(name: timerName)
    }
    
    func cleanup() {
        window?.close()
        window = nil
        textField = nil
    }
}

extension NameInputPanel: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            confirmNameInput()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelNameInput()
            return true
        }
        return false
    }
}

protocol NameInputPanelDelegate: AnyObject {
    func nameInputPanelDidConfirm(name: String?)
    func nameInputPanelDidCancel()
}
