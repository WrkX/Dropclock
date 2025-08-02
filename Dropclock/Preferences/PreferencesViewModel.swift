import EventKit
import ServiceManagement
import SwiftUI

class PreferencesViewModel: ObservableObject {
  @Published var reminderLists: [EKCalendar] = []
  @Published var selectedList: EKCalendar?
  @Published var allowReminders: Bool = false
  @Published var deleteReminders: Bool = true
  @Published var allowCustomNames: Bool = false
  @Published var startAtLogin: Bool = false
  @Published var ignoreShortTimers: Bool = false
  @Published var allowSecondsMode: Bool = false
  @Published var allowFiveMinuteMode: Bool = true
  @Published var shortTimerThresholdMinutes: Double = 1
  @Published var viewAsMinutes: Bool = false
  @Published var showDragIndicator: Bool = true
  @Published var changeRubberbandColor: Bool = false
  @Published var customMenuBarWord: String = ""
  @Published var useCustomMenuBarIcon: Bool = false {
    didSet {
      if useCustomMenuBarIcon {
        if useAlternativeMenuBarIcon {
          useAlternativeMenuBarIcon = false
        }
        if useCustomMenuBarSymbol {
          useCustomMenuBarSymbol = false
        }
      }
    }
  }
  @Published var customMenuBarSymbol: String = ""
  @Published var useCustomMenuBarSymbol: Bool = false {
    didSet {
      if useCustomMenuBarSymbol {
        if useAlternativeMenuBarIcon {
          useAlternativeMenuBarIcon = false
        }
        if useCustomMenuBarIcon {
          useCustomMenuBarIcon = false
        }
      }
    }
  }
  @Published var useAlternativeMenuBarIcon: Bool = false {
    didSet {
      if useAlternativeMenuBarIcon {
        if useCustomMenuBarIcon {
          useCustomMenuBarIcon = false
        }
        if useCustomMenuBarSymbol {
          useCustomMenuBarSymbol = false
        }
      }
    }
  }
  @Published var dragLineColor: Color = Color.white {
    didSet {
      saveDragLineColor()
    }
  }
  @Published var showNextTimerInMenuBar: Bool = false

  @AppStorage("selectedReminderListID") private var selectedReminderListID:
    String = ""

  private struct Keys {
    static let allowReminders = "allowReminders"
    static let deleteReminders = "deleteReminders"
    static let allowCustomNames = "allowCustomNames"
    static let allowSecondsMode = "allowSecondsMode"
    static let allowFiveMinuteMode = "allowFiveMinuteMode"
    static let ignoreShortTimers = "ignoreShortTimers"
    static let shortTimerThresholdMinutes = "shortTimerThresholdMinutes"
    static let selectedReminderListIdentifier = "SelectedReminderListIdentifier"
    static let viewAsMinutes = "viewAsMinutes"
    static let showDragIndicator = "showDragIndicator"
    static let changeRubberbandColor = "changeRubberbandColor"
    static let dragLineColor = "dragLineColor"
    static let useCustomMenuBarSymbol = "useCustomMenuBarSymbol"
    static let customMenuBarSymbol = "customMenuBarSymbol"
    static let useCustomMenuBarIcon = "useCustomMenuBarIcon"
    static let customMenuBarWord = "customMenuBarWord"
    static let useAlternativeMenuBarIcon = "useAlternativeMenuBarIcon"
    static let showNextTimerInMenuBar = "showNextTimerInMenuBar"
  }

  init() {
    loadPreferences()
    startAtLogin = SMAppService.mainApp.status == .enabled
    loadReminderData()
  }

  private func loadReminderData() {
    Task {
      await ensureReminderAccessAndFetchLists()
    }
  }

  private func ensureReminderAccessAndFetchLists() async {
    if allowReminders {
      await ensureReminderAccess()
      await fetchReminderLists()
      loadSelectedList()
    } else {
      await fetchReminderLists()
      loadSelectedList()
    }
  }

  func loadPreferences() {
    allowReminders = UserDefaults.standard.bool(forKey: Keys.allowReminders)
    deleteReminders = UserDefaults.standard.bool(forKey: Keys.deleteReminders)
    allowCustomNames = UserDefaults.standard.bool(forKey: Keys.allowCustomNames)
    allowSecondsMode = UserDefaults.standard.bool(forKey: Keys.allowSecondsMode)
    allowFiveMinuteMode = UserDefaults.standard.bool(
      forKey: Keys.allowFiveMinuteMode)
    viewAsMinutes = UserDefaults.standard.bool(forKey: Keys.viewAsMinutes)
    showDragIndicator = UserDefaults.standard.bool(
      forKey: Keys.showDragIndicator)
    changeRubberbandColor = UserDefaults.standard.bool(
      forKey: Keys.changeRubberbandColor)
    ignoreShortTimers = UserDefaults.standard.bool(
      forKey: Keys.ignoreShortTimers)
    shortTimerThresholdMinutes = UserDefaults.standard.double(
      forKey: Keys.shortTimerThresholdMinutes)
    if let colorData = UserDefaults.standard.data(forKey: "dragLineColor"),
      let color = try? NSKeyedUnarchiver.unarchivedObject(
        ofClass: NSColor.self, from: colorData)
    {
      dragLineColor = Color(nsColor: color)
    }
    useCustomMenuBarIcon = UserDefaults.standard.bool(forKey: Keys.useCustomMenuBarIcon)
    useAlternativeMenuBarIcon = UserDefaults.standard.bool(forKey: Keys.useAlternativeMenuBarIcon)
    customMenuBarWord = UserDefaults.standard.string(forKey: Keys.customMenuBarWord) ?? ""
    customMenuBarSymbol = UserDefaults.standard.string(forKey: Keys.customMenuBarSymbol) ?? ""
    useCustomMenuBarSymbol = UserDefaults.standard.bool(forKey: Keys.useCustomMenuBarSymbol)
    showNextTimerInMenuBar = UserDefaults.standard.bool(forKey: Keys.showNextTimerInMenuBar)
  }

  private func loadSelectedList() {
    if let storedList = RemindersManager.shared.fetchReminderLists().first(
      where: { $0.calendarIdentifier == selectedReminderListID })
    {
      selectedList = storedList
    } else if reminderLists.isEmpty == false {
      selectedList = reminderLists.first
    }
  }

  func savePreferences() {
    if allowReminders {
      Task {
        await ensureReminderAccess()
      }
    }
    if let selected = selectedList {
      UserDefaults.standard.set(
        selected.calendarIdentifier, forKey: Keys.selectedReminderListIdentifier
      )
    }
    UserDefaults.standard.set(allowReminders, forKey: Keys.allowReminders)
    UserDefaults.standard.set(deleteReminders, forKey: Keys.deleteReminders)
    UserDefaults.standard.set(allowCustomNames, forKey: Keys.allowCustomNames)
    UserDefaults.standard.set(ignoreShortTimers, forKey: Keys.ignoreShortTimers)
    UserDefaults.standard.set(allowSecondsMode, forKey: Keys.allowSecondsMode)
    UserDefaults.standard.set(
      allowFiveMinuteMode, forKey: Keys.allowFiveMinuteMode)
    UserDefaults.standard.set(viewAsMinutes, forKey: Keys.viewAsMinutes)
    UserDefaults.standard.set(showDragIndicator, forKey: Keys.showDragIndicator)
    UserDefaults.standard.set(
      changeRubberbandColor, forKey: Keys.changeRubberbandColor)
    UserDefaults.standard.set(
      shortTimerThresholdMinutes, forKey: Keys.shortTimerThresholdMinutes)
    UserDefaults.standard.set(useCustomMenuBarIcon, forKey: Keys.useCustomMenuBarIcon)
    UserDefaults.standard.set(customMenuBarWord, forKey: Keys.customMenuBarWord)
    UserDefaults.standard.set(useAlternativeMenuBarIcon, forKey: Keys.useAlternativeMenuBarIcon)
    UserDefaults.standard.set(useCustomMenuBarSymbol, forKey: Keys.useCustomMenuBarSymbol)
    UserDefaults.standard.set(customMenuBarSymbol, forKey: Keys.customMenuBarSymbol)
    UserDefaults.standard.set(showNextTimerInMenuBar, forKey: Keys.showNextTimerInMenuBar)
    updateLoginItem()
    saveDragLineColor()
  }

  func ensureReminderAccess() async {
    let status = RemindersManager.shared.checkAuthorizationStatus()

    switch status {
    case .notDetermined:
      let granted = await RemindersManager.shared.requestAccess()
      if granted {
      } else {
        print("Access denied. Please enable it in System Settings.")
      }

    case .denied:
      print(
        "Reminders access denied. Ask the user to enable it in System Settings."
      )
    case .fullAccess, .writeOnly:
      break
    default:
      print("Unknown authorization status.")
    }
  }

  private func saveDragLineColor() {
    let nsColor = NSColor(dragLineColor)
    if let colorData = try? NSKeyedArchiver.archivedData(
      withRootObject: nsColor, requiringSecureCoding: false)
    {
      UserDefaults.standard.set(colorData, forKey: "dragLineColor")
    }
  }

  func fetchReminderLists() async {
    await MainActor.run { [weak self] in
      guard let self = self else { return }
      self.reminderLists = RemindersManager.shared.fetchReminderLists()
    }
  }

  func updateLoginItem() {
    do {
      if startAtLogin {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      print(
        "Error \(startAtLogin ? "enabling" : "disabling") login item: \(error)")
      startAtLogin.toggle()
    }
  }
}
