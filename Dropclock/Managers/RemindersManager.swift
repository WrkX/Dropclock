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

    // MARK: - Authorization

    /// Checks the current authorization status for reminders.
    func checkAuthorizationStatus() -> EKAuthorizationStatus {
        return EKEventStore.authorizationStatus(for: .reminder)
    }

    /// Requests access to reminders and returns a boolean indicating success.
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
          // Handle write-only access if needed
          print("Write-only access granted.")
          return true
      @unknown default:
          print("Unknown authorization status.")
          return false
      }
  }

    // MARK: - Fetching Reminder Lists

    /// Fetches all reminder lists available in the event store.
    func fetchReminderLists() -> [EKCalendar] {
        return eventStore.calendars(for: .reminder)
    }

    // MARK: - Creating Reminders

    /// Creates a new reminder with the specified title, notes, and due date.
    @discardableResult
    func createReminder(title: String, notes: String?, dueDate: Date) throws -> String {
        guard checkAuthorizationStatus() == .fullAccess || checkAuthorizationStatus() == .writeOnly else {
            throw RemindersError.accessDenied
        }

        guard let listID = UserDefaults.standard.string(forKey: "SelectedReminderList"),
              let calendar = fetchReminderLists().first(where: { $0.calendarIdentifier == listID }) else {
            throw RemindersError.noReminderListSelected
        }

      let reminder = EKReminder(eventStore: eventStore)
      reminder.title = title
      reminder.notes = notes
      reminder.calendar = calendar
      reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)

      let alarm = EKAlarm(absoluteDate: dueDate)
      // These two properties are critical for notifications to work
      alarm.relativeOffset = 0
      reminder.addAlarm(alarm)
        do {
            try eventStore.save(reminder, commit: true)
            print("Reminder added successfully with ID: \(reminder.calendarItemIdentifier)")
            return reminder.calendarItemIdentifier
        } catch {
            throw RemindersError.reminderCreationFailed(error)
        }
    }

    // MARK: - Deleting Reminders

    /// Deletes a reminder with the specified identifier.
  func deleteReminder(withIdentifier identifier: String) async throws {
      guard checkAuthorizationStatus() == .fullAccess || checkAuthorizationStatus() == .writeOnly else {
          throw RemindersError.accessDenied
      }

      let predicate = eventStore.predicateForReminders(in: nil)
      
      // Use continuation to bridge the completion handler to async/await
      return try await withCheckedThrowingContinuation { continuation in
          eventStore.fetchReminders(matching: predicate) { reminders in
              if let reminders = reminders {
                  if let reminderToDelete = reminders.first(where: { $0.calendarItemIdentifier == identifier }) {
                      do {
                          try self.eventStore.remove(reminderToDelete, commit: true)
                          print("Successfully deleted reminder with ID: \(identifier)")
                          continuation.resume()
                      } catch {
                          continuation.resume(throwing: RemindersError.reminderDeletionFailed(error))
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
