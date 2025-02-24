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

  @AppStorage("selectedReminderListID") private var selectedReminderListID:
    String = ""

  init() {
    loadPreferences()
    startAtLogin = SMAppService.mainApp.status == .enabled
  }

  func loadPreferences() {
    if let storedList = RemindersManager.shared.fetchReminderLists().first(
      where: { $0.calendarIdentifier == selectedReminderListID })
    {
      selectedList = storedList
    }
    allowReminders = UserDefaults.standard.bool(forKey: "allowReminders")
    deleteReminders = UserDefaults.standard.bool(forKey: "deleteReminders")
    allowCustomNames = UserDefaults.standard.bool(forKey: "allowCustomNames")
  }

  func savePreferences() {
    if allowReminders {
      Task {
        await ensureReminderAccess()
      }
    }
    if let selected = selectedList {
      UserDefaults.standard.set(
        selected.calendarIdentifier, forKey: "SelectedReminderList")
    }
    UserDefaults.standard.set(allowReminders, forKey: "allowReminders")
    UserDefaults.standard.set(deleteReminders, forKey: "deleteReminders")
    UserDefaults.standard.set(allowCustomNames, forKey: "allowCustomNames")
    updateLoginItem()

  }

  func ensureReminderAccess() async {
    let status = RemindersManager.shared.checkAuthorizationStatus()

    switch status {
    case .notDetermined:
      let granted = await RemindersManager.shared.requestAccess()

      Task { [weak self] in
        guard let self = self else { return }

        if granted {
          await self.fetchReminderLists()
        } else {
          print("Access denied. Please enable it in System Settings.")
        }
      }

    case .denied:
      print(
        "Reminders access denied. Ask the user to enable it in System Settings."
      )
    case .fullAccess, .writeOnly:
      await fetchReminderLists()
    default:
      print("Unknown authorization status.")
    }
  }

  func fetchReminderLists() async {
    await MainActor.run { [weak self] in
      guard let self = self else { return }
      self.reminderLists = RemindersManager.shared.fetchReminderLists()

      if self.selectedList == nil, let firstList = self.reminderLists.first {
        self.selectedList = firstList
      }
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
