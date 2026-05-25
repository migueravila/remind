import ArgumentParser
import core
import Foundation

public struct AddReminderCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add one or more reminders",
        aliases: ["a"]
    )

    @Argument(parsing: .remaining, help: "Reminder title(s)")
    public var titles: [String] = []

    @Option(name: .shortAndLong, help: "List name")
    public var list: String?

    @Option(
        name: .shortAndLong,
        help: "Due date (DD-MM-YY, 'today', 'tomorrow')"
    )
    public var due: String?

    @Option(name: .shortAndLong, help: "Priority (none, low, medium, high)")
    public var priority: String?

    @Flag(name: .shortAndLong, help: "Mark as flagged")
    public var flag: Bool = false

    @Option(name: .shortAndLong, help: "Add notes")
    public var notes: String?

    public init() {}

    public func run() async throws {
        let manager = Manager()
        try await manager.requestAccess()

        if titles.isEmpty {
            try await runInteractive(manager: manager)
        } else {
            try await runDirect(manager: manager)
        }
    }

    private func runInteractive(manager: Manager) async throws {
        guard let title = InputUtils.input(
            message: "Reminder title",
            required: true
        ), !title.isEmpty else {
            OutputUtils.printError("Title is required")
            return
        }

        guard let targetList = try await resolveList(
            manager: manager,
            explicit: list
        ) else {
            OutputUtils.printError("No list selected")
            return
        }

        let wantsDueDate = InputUtils.confirm(
            message: "Set a due date?",
            defaultValue: false
        )

        let dueDate: Date? = if wantsDueDate {
            InputUtils.datePicker(message: "Select due date:")
        } else {
            nil
        }

        let priorityOptions: [(String, Reminder.Priority)] = [
            ("None", .none),
            ("Low", .low),
            ("Medium", .medium),
            ("High", .high)
        ]
        let selectedPriority = InputUtils.select(
            message: "Select priority:",
            options: priorityOptions
        ) ?? .none

        let flagged = InputUtils.confirm(
            message: "Flag this reminder?",
            defaultValue: false
        )

        let effectivePriority: Reminder.Priority = flagged &&
            selectedPriority == .none ? .high : selectedPriority

        let reminder = Reminder(
            id: nil,
            title: title,
            notes: nil,
            isCompleted: false,
            priority: effectivePriority,
            dueDate: dueDate,
            listName: targetList
        )

        try await manager.createReminder(reminder, in: targetList)
        OutputUtils.printSuccess("Added reminder: \(title)")
    }

    private func runDirect(manager: Manager) async throws {
        guard let targetList = try await resolveList(
            manager: manager,
            explicit: list
        ) else {
            return
        }

        let dueDate: Date? = if let due {
            DateUtils.parseNaturalDate(due)
        } else {
            nil
        }

        let parsedPriority = parsePriority(priority)
        let effectivePriority: Reminder.Priority = if priority != nil {
            parsedPriority
        } else if flag {
            .high
        } else {
            .none
        }

        for title in titles {
            let reminder = Reminder(
                id: nil,
                title: title,
                notes: notes,
                isCompleted: false,
                priority: effectivePriority,
                dueDate: dueDate,
                listName: targetList
            )
            try await manager.createReminder(reminder, in: targetList)
        }

        let message = titles.count == 1
            ? "Added reminder: \(titles[0])"
            : "Added \(titles.count) reminders to \(targetList)"
        OutputUtils.printSuccess(message)
    }
}
