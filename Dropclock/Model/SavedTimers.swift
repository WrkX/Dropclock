import AppKit

struct SavedTimer: Codable {
  let id: String
  let name: String?
  let startTime: Date
  let duration: TimeInterval
  let reminderId: String?
}
