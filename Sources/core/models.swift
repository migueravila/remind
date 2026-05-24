import Foundation

public enum OutputFormat: String, Sendable {
    case standard
    case json
    case plain
    case quiet
}

public struct Reminder: Sendable, Codable {
    public let id: String?
    public let title: String
    public let notes: String?
    public let isCompleted: Bool
    public let priority: Priority
    public let dueDate: Date?
    public let listName: String?

    public var isFlagged: Bool {
        priority != .none
    }

    public init(
        id: String?,
        title: String,
        notes: String?,
        isCompleted: Bool,
        priority: Priority,
        dueDate: Date?,
        listName: String?
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.listName = listName
    }

    public enum Priority: Int, CaseIterable, Sendable, Codable {
        case none = 0
        case low = 1
        case medium = 5
        case high = 9

        public var displayName: String {
            switch self {
            case .none: "None"
            case .low: "Low"
            case .medium: "Medium"
            case .high: "High"
            }
        }
    }
}

public struct ReminderList: Sendable, Codable {
    public let id: String?
    public let title: String
    public let color: String?
    public let reminderCount: Int

    public init(
        id: String? = nil, title: String, color: String? = nil,
        reminderCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.color = color
        self.reminderCount = reminderCount
    }
}

public enum ProgramError: LocalizedError {
    case accessDenied
    case unknownAuthorizationStatus
    case reminderNotFound
    case listNotFound
    case invalidDate
    case operationFailed(String)

    public var errorDescription: String? {
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

public enum ShowOptions: Sendable, Equatable {
    case today
    case tomorrow
    case upcoming
    case completed
    case all
    case specificDate(Date)
}

public enum ViewSpec: Sendable, Codable, Equatable {
    case list(name: String)
    case lists
    case filter(Filter)

    public enum Filter: Sendable, Codable, Equatable {
        case today
        case tomorrow
        case upcoming
        case completed
        case all
        case specificDate(Date)
    }
}

public struct ViewState: Sendable, Codable {
    public let spec: ViewSpec
    public let ids: [String]
    public let updatedAt: Date

    public init(spec: ViewSpec, ids: [String], updatedAt: Date = Date()) {
        self.spec = spec
        self.ids = ids
        self.updatedAt = updatedAt
    }
}
