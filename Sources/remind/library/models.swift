import Foundation

struct ReminderItem {
  let id: String?
  let title: String
  let notes: String?
  let isCompleted: Bool
  let priority: Priority
  let dueDate: Date?
  let listName: String?

  enum Priority: Int, CaseIterable {
    case none = 0
    case low = 1
    case medium = 5
    case high = 9

    var displayName: String {
      switch self {
      case .none: return "None"
      case .low: return "Low"
      case .medium: return "Medium"
      case .high: return "High"
      }
    }
  }
}

struct ReminderList {
  let id: String?
  let title: String
  let color: String?
  let reminderCount: Int

  init(id: String? = nil, title: String, color: String? = nil, reminderCount: Int = 0) {
    self.id = id
    self.title = title
    self.color = color
    self.reminderCount = reminderCount
  }
}

enum RemindError: LocalizedError {
  case accessDenied
  case unknownAuthorizationStatus
  case reminderNotFound
  case listNotFound
  case invalidDate
  case operationFailed(String)

  var errorDescription: String? {
    switch self {
    case .accessDenied:
      return
        "Access to Reminders denied. Please grant access in System Preferences > Privacy & Security > Reminders"
    case .unknownAuthorizationStatus:
      return "Unknown authorization status"
    case .reminderNotFound:
      return "Reminder not found"
    case .listNotFound:
      return "List not found"
    case .invalidDate:
      return "Invalid date format"
    case .operationFailed(let message):
      return "Operation failed: \(message)"
    }
  }
}
