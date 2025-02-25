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
    allowFiveMinuteMode = UserDefaults.standard.bool(forKey: Keys.allowFiveMinuteMode)
    viewAsMinutes = UserDefaults.standard.bool(forKey: Keys.viewAsMinutes)
    ignoreShortTimers = UserDefaults.standard.bool(
      forKey: Keys.ignoreShortTimers)
    shortTimerThresholdMinutes = UserDefaults.standard.double(
      forKey: Keys.shortTimerThresholdMinutes)

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
    UserDefaults.standard.set(allowFiveMinuteMode, forKey: Keys.allowFiveMinuteMode)
    UserDefaults.standard.set(viewAsMinutes, forKey: Keys.viewAsMinutes)
    UserDefaults.standard.set(
      shortTimerThresholdMinutes, forKey: Keys.shortTimerThresholdMinutes)
    updateLoginItem()
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
