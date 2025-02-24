import EventKit

enum RemindersError: Error {
  case accessDenied
  case noReminderListSelected
  case reminderCreationFailed(Error)
  case reminderDeletionFailed(Error)
  case reminderNotFound
}

class RemindersManager {
  static let shared = RemindersManager()
  private let eventStore = EKEventStore()

  private init() {}

  func checkAuthorizationStatus() -> EKAuthorizationStatus {
    return EKEventStore.authorizationStatus(for: .reminder)
  }

  func requestAccess() async -> Bool {
    let status = checkAuthorizationStatus()

    switch status {
    case .fullAccess:
      return true
    case .notDetermined:
      do {
        return try await eventStore.requestFullAccessToReminders()
      } catch {
        print("Error requesting access: \(error.localizedDescription)")
        return false
      }
    case .denied, .restricted:
      print("Reminders access denied. Please enable it in System Settings.")
      return false
    case .writeOnly:
      print("Write-only access granted.")
      return true
    @unknown default:
      print("Unknown authorization status.")
      return false
    }
  }

  func fetchReminderLists() -> [EKCalendar] {
    return eventStore.calendars(for: .reminder)
  }

  @discardableResult
  func createReminder(title: String, notes: String?, dueDate: Date) throws
    -> String
  {
    guard
      checkAuthorizationStatus() == .fullAccess
        || checkAuthorizationStatus() == .writeOnly
    else {
      throw RemindersError.accessDenied
    }

    guard
      let listID = UserDefaults.standard.string(forKey: "SelectedReminderList"),
      let calendar = fetchReminderLists().first(where: {
        $0.calendarIdentifier == listID
      })
    else {
      throw RemindersError.noReminderListSelected
    }

    let roundedDueDate = Calendar.current.date(
      bySetting: .second, value: 0,
      of: dueDate.addingTimeInterval(
        59
          - (dueDate.timeIntervalSinceReferenceDate.truncatingRemainder(
            dividingBy: 60))))

    let reminder = EKReminder(eventStore: eventStore)
    reminder.title = title
    reminder.notes = notes
    reminder.calendar = calendar
    reminder.dueDateComponents = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute], from: roundedDueDate!)

    let alarm = EKAlarm(absoluteDate: roundedDueDate!)
    alarm.relativeOffset = 0
    reminder.addAlarm(alarm)

    do {
      try eventStore.save(reminder, commit: true)
      print(
        "Reminder added successfully with ID: \(reminder.calendarItemIdentifier)"
      )
      return reminder.calendarItemIdentifier
    } catch {
      throw RemindersError.reminderCreationFailed(error)
    }
  }

  func deleteReminder(withIdentifier identifier: String) async throws {
    guard
      checkAuthorizationStatus() == .fullAccess
        || checkAuthorizationStatus() == .writeOnly
    else {
      throw RemindersError.accessDenied
    }

    let predicate = eventStore.predicateForReminders(in: nil)

    return try await withCheckedThrowingContinuation { continuation in
      eventStore.fetchReminders(matching: predicate) { reminders in
        if let reminders = reminders {
          if let reminderToDelete = reminders.first(where: {
            $0.calendarItemIdentifier == identifier
          }) {
            do {
              try self.eventStore.remove(reminderToDelete, commit: true)
              print("Successfully deleted reminder with ID: \(identifier)")
              continuation.resume()
            } catch {
              continuation.resume(
                throwing: RemindersError.reminderDeletionFailed(error))
            }
          } else {
            continuation.resume(throwing: RemindersError.reminderNotFound)
          }
        } else {
          continuation.resume(throwing: RemindersError.reminderNotFound)
        }
      }
    }
  }
}
