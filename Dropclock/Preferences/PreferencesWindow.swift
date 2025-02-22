import SwiftUI
import EventKit



class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private init() {
        let preferencesView = PreferencesView()
        let hostingController = NSHostingController(rootView: preferencesView)

        let window = NSWindow(
            contentViewController: hostingController
        )
        window.title = "Dropblock Preferences"
        window.setContentSize(NSSize(width: 400, height: 200))
        window.styleMask = [.titled, .closable, .resizable]
        window.isReleasedWhenClosed = false
      window.level = .floating
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
