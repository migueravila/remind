import ArgumentParser
import core
import Foundation

private func resolveReminderIDs(
    _ inputs: [String],
    examples: [String]
) async throws -> (manager: Manager, ids: [String])? {
    guard !inputs.isEmpty else {
        OutputUtils.printError("Please provide at least one reminder number or ID")
        print("Examples:")
        examples.forEach { print($0) }
        return nil
    }

    let manager = Manager()
    try await manager.requestAccess()
    let allReminders = try await manager.getReminders(from: nil)
    let validIDs = IDResolver.resolveIDs(inputs, from: allReminders)

    guard !validIDs.isEmpty else {
        OutputUtils.printError("No valid reminder numbers or IDs found")
        print("Use 'remind show' to see available reminders with their numbers")
        return nil
    }

    if validIDs.count < inputs.count {
        OutputUtils.printWarning(
            "Only \(validIDs.count) of \(inputs.count) inputs could be resolved"
        )
    }

    return (manager, validIDs)
}

struct AddReminderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a new reminder",
        aliases: ["a"]
    )

    @Argument(parsing: .remaining, help: "Reminder description")
    var description: [String] = []

    @Option(name: .shortAndLong, help: "List name")
    var list: String?

    @Option(
        name: .shortAndLong,
        help: "Due date (YYYY-MM-DD, 'today', 'tomorrow', etc.)"
    )
    var due: String?

    @Option(name: .shortAndLong, help: "Priority (none, low, medium, high)")
    var priority: String?

    @Flag(name: .shortAndLong, help: "Mark as flagged")
    var flag: Bool = false

    @Option(name: .shortAndLong, help: "Add notes")
    var notes: String?

    @Flag(name: .long, help: "Disable interactive mode")
    var noInteractive: Bool = false

    func run() async throws {
        let manager = Manager()
        try await manager.requestAccess()

        let interactive = !noInteractive && description.isEmpty

        if interactive {
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

        let availableLists = try await manager.getAllLists()
        guard !availableLists.isEmpty else {
            OutputUtils.printError("No lists available. Create a list first.")
            return
        }

        let listOptions = availableLists.map { ($0.title, $0.title) }
        guard let selectedList = InputUtils.select(
            message: "Select a list:",
            options: listOptions
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

        let notes = InputUtils.input(message: "Notes (optional)")

        let priorityOptions: [(String, Reminder.Priority)] = [
            ("None", .none),
            ("Low", .low),
            ("Medium", .medium),
            ("High", .high)
        ]

        let priority = InputUtils.select(
            message: "Select priority:",
            options: priorityOptions
        ) ?? .none

        let reminder = Reminder(
            id: nil,
            title: title,
            notes: notes?.isEmpty == false ? notes : nil,
            isCompleted: false,
            priority: priority,
            dueDate: dueDate,
            listName: selectedList
        )

        try await manager.createReminder(reminder, in: selectedList)
        OutputUtils.printSuccess("Added reminder: \(title)")
    }

    private func runDirect(manager: Manager) async throws {
        let title = description.joined(separator: " ")
        let config = Config.load()

        let targetList: String
        if let list {
            targetList = list
        } else if let defaultList = config.defaultList {
            targetList = defaultList
        } else {
            let availableLists = try await manager.getAllLists()
            guard let firstList = availableLists.first else {
                OutputUtils
                    .printError("No lists available. Create a list first.")
                return
            }
            targetList = firstList.title
        }

        let dueDate: Date? = if let due {
            DateUtils.parseNaturalDate(due)
        } else {
            nil
        }

        let parsedPriority = parsePriority(priority)

        let reminder = Reminder(
            id: nil,
            title: title,
            notes: notes,
            isCompleted: false,
            priority: flag ? .high : parsedPriority,
            dueDate: dueDate,
            listName: targetList
        )

        try await manager.createReminder(reminder, in: targetList)
        OutputUtils.printSuccess("Added reminder: \(title)")
    }

    private func parsePriority(_ input: String?) -> Reminder.Priority {
        guard let input = input?.lowercased() else { return .none }
        switch input {
        case "low", "l": return .low
        case "medium", "med", "m": return .medium
        case "high", "h": return .high
        default: return .none
        }
    }
}

struct CompleteReminderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "complete",
        abstract: "Mark one or more reminders as complete",
        aliases: ["c", "done"]
    )

    @Argument(
        parsing: .remaining,
        help: "Reminder number(s) or ID(s) to complete"
    )
    var inputs: [String]

    func run() async throws {
        let examples = [
            "  remind complete 1        # Complete reminder [1]",
            "  remind complete 1 2 3    # Complete multiple reminders",
            "  remind complete 4A83     # Complete by partial ID"
        ]

        guard let result = try await resolveReminderIDs(inputs, examples: examples) else {
            return
        }

        try await result.manager.completeReminders(ids: result.ids)
        let message = result.ids.count == 1
            ? "Completed reminder"
            : "Completed \(result.ids.count) reminders"
        OutputUtils.printSuccess(message)
    }
}

struct EditReminderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "edit",
        abstract: "Edit an existing reminder",
        aliases: ["e"]
    )

    @Argument(help: "Reminder number or ID")
    var input: String

    @Option(name: .shortAndLong, help: "New title")
    var title: String?

    @Option(name: .shortAndLong, help: "Move to different list")
    var list: String?

    @Option(name: .shortAndLong, help: "New due date")
    var due: String?

    @Option(name: .shortAndLong, help: "New priority (none, low, medium, high)")
    var priority: String?

    @Option(name: .shortAndLong, help: "New notes")
    var notes: String?

    func run() async throws {
        let manager = Manager()
        try await manager.requestAccess()

        let allReminders = try await manager.getReminders(from: nil)
        let resolvedIDs = IDResolver.resolveIDs([input], from: allReminders)

        guard let id = resolvedIDs.first else {
            OutputUtils.printError("Reminder not found: \(input)")
            return
        }

        guard let reminder = allReminders.first(where: { $0.id == id }) else {
            OutputUtils.printError("Reminder not found")
            return
        }

        let hasFlags = title != nil || list != nil || due != nil ||
                       priority != nil || notes != nil

        if hasFlags {
            try await runDirect(manager: manager, id: id)
        } else {
            try await runInteractive(manager: manager, id: id, current: reminder)
        }
    }

    private func runDirect(manager: Manager, id: String) async throws {
        let parsedPriority: Reminder.Priority? = if let priority {
            parsePriority(priority)
        } else {
            nil
        }

        let parsedDue: Date?? = if let due {
            .some(DateUtils.parseNaturalDate(due))
        } else {
            nil
        }

        try await manager.updateReminder(
            id: id,
            title: title,
            notes: notes,
            priority: parsedPriority,
            dueDate: parsedDue,
            listName: list
        )

        OutputUtils.printSuccess("Updated reminder")
    }

    private func runInteractive(
        manager: Manager,
        id: String,
        current: Reminder
    ) async throws {
        let newTitle = InputUtils.input(
            message: "Title",
            defaultValue: current.title
        ) ?? current.title

        let availableLists = try await manager.getAllLists()
        let listOptions = availableLists.map { ($0.title, $0.title) }
        let currentListIndex = availableLists.firstIndex {
            $0.title == current.listName
        } ?? 0

        let selectedList = InputUtils.select(
            message: "List:",
            options: listOptions,
            defaultIndex: currentListIndex
        )

        let wantsDueDate = InputUtils.confirm(
            message: "Set a due date?",
            defaultValue: current.dueDate != nil
        )

        let newDueDate: Date?? = if wantsDueDate {
            .some(InputUtils.datePicker(
                message: "Select due date:",
                initialDate: current.dueDate ?? Date()
            ))
        } else {
            .some(nil)
        }

        let newNotes = InputUtils.input(
            message: "Notes",
            defaultValue: current.notes ?? ""
        )

        let priorityOptions: [(String, Reminder.Priority)] = [
            ("None", .none),
            ("Low", .low),
            ("Medium", .medium),
            ("High", .high)
        ]
        let currentPriorityIndex = priorityOptions.firstIndex {
            $0.1 == current.priority
        } ?? 0

        let newPriority = InputUtils.select(
            message: "Priority:",
            options: priorityOptions,
            defaultIndex: currentPriorityIndex
        )

        try await manager.updateReminder(
            id: id,
            title: newTitle,
            notes: newNotes,
            priority: newPriority,
            dueDate: newDueDate,
            listName: selectedList
        )

        OutputUtils.printSuccess("Updated reminder: \(newTitle)")
    }

    private func parsePriority(_ input: String) -> Reminder.Priority {
        switch input.lowercased() {
        case "low", "l": return .low
        case "medium", "med", "m": return .medium
        case "high", "h": return .high
        default: return .none
        }
    }
}

struct DeleteReminderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete one or more reminders",
        aliases: ["d", "rm"]
    )

    @Argument(
        parsing: .remaining,
        help: "Reminder number(s) or ID(s) to delete"
    )
    var inputs: [String]

    @Flag(
        name: [.customShort("y"), .customLong("force")],
        help: "Skip confirmation prompt"
    )
    var force: Bool = false

    func run() async throws {
        let examples = [
            "  remind delete 1          # Delete reminder [1]",
            "  remind delete 1 2 3      # Delete multiple reminders",
            "  remind delete 4A83       # Delete by partial ID"
        ]

        guard let result = try await resolveReminderIDs(inputs, examples: examples) else {
            return
        }

        let config = Config.load()
        let shouldConfirm = !force && config.confirmDelete

        if shouldConfirm {
            let shouldDelete = InputUtils.confirm(
                message: "Are you sure you want to delete \(result.ids.count) reminder(s)?",
                defaultValue: false
            )

            guard shouldDelete else {
                OutputUtils.printInfo("Delete operation cancelled")
                return
            }
        }

        try await result.manager.deleteReminders(ids: result.ids)
        let message = result.ids.count == 1
            ? "Deleted reminder"
            : "Deleted \(result.ids.count) reminders"
        OutputUtils.printSuccess(message)
    }
}
