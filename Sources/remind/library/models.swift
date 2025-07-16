import Foundation

struct Reminder {
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
            case .none: "None"
            case .low: "Low"
            case .medium: "Medium"
            case .high: "High"
            }
        }
    }
}

struct ReminderList {
    let id: String?
    let title: String
    let color: String?
    let reminderCount: Int

    init(
        id: String? = nil, title: String, color: String? = nil,
        reminderCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.color = color
        self.reminderCount = reminderCount
    }
}

enum ProgramError: LocalizedError {
    case accessDenied
    case unknownAuthorizationStatus
    case reminderNotFound
    case listNotFound
    case invalidDate
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Access to Reminders denied. Please grant access in System Preferences > Privacy & Security > Reminders"
        case .unknownAuthorizationStatus: "Unknown authorization status"
        case .reminderNotFound: "Reminder not found"
        case .listNotFound: "List not found"
        case .invalidDate: "Invalid date format"
        case let .operationFailed(message):
            "Operation failed: \(message)"
        }
    }
}

enum ShowOptions {
    case today
    case tomorrow
    case thisWeek
    case overdue
    case flagged
    case upcoming
    case specificDate(Date)
}
