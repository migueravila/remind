import ArgumentParser
import core
import Foundation

private func resolveList(
    manager: Manager,
    explicit: String?
) async throws -> String? {
    if let explicit { return explicit }

    if case let .list(name) = ViewStateStore.load()?.spec {
        return name
    }

    let config = Config.load()
    if let defaultList = config.defaultList { return defaultList }

    let available = try await manager.getAllLists()
    guard !available.isEmpty else {
        OutputUtils.printError("No lists available. Create a list first.")
        return nil
    }
    let options = available.map { ($0.title, $0.title) }
    return InputUtils.select(message: "Select a list:", options: options)
}

private func resolveReminderIDs(
    _ inputs: [String],
    listScope: String?,
    examples: [String]
) async throws -> (manager: Manager, ids: [String])? {
    guard !inputs.isEmpty else {
        OutputUtils
            .printError("Please provide at least one reminder number or ID")
        print("Examples:")
        examples.forEach { print($0) }
        return nil
    }

    let manager = Manager()
    try await manager.requestAccess()
    let reminders = try await manager.getReminders(from: listScope)

    let validIDs: [String]
    if listScope == nil, let state = ViewStateStore.load() {
        validIDs = IDResolver.resolveIDs(
            inputs,
            snapshot: state.ids,
            reminders: reminders
        )
    } else {
        validIDs = IDResolver.resolveIDs(inputs, from: reminders)
    }

    guard !validIDs.isEmpty else {
        OutputUtils.printError("No valid reminder numbers or IDs found")
        print("Use a view command to see reminders with their numbers")
        return nil
    }

    if validIDs.count < inputs.count {
        OutputUtils.printWarning(
            "Only \(validIDs.count) of \(inputs.count) inputs could be resolved"
        )
    }

    return (manager, validIDs)
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

struct AddReminderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add one or more reminders",
        aliases: ["a"]
    )

    @Argument(parsing: .remaining, help: "Reminder title(s)")
    var titles: [String] = []

    @Option(name: .shortAndLong, help: "List name")
    var list: String?

    @Option(
        name: .shortAndLong,
        help: "Due date (DD-MM-YY, 'today', 'tomorrow')"
    )
    var due: String?

    @Option(name: .shortAndLong, help: "Priority (none, low, medium, high)")
    var priority: String?

    @Flag(name: .shortAndLong, help: "Mark as flagged")
    var flag: Bool = false

    @Option(name: .shortAndLong, help: "Add notes")
    var notes: String?

    func run() async throws {
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

struct CompleteReminderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "complete",
        abstract: "Mark one or more reminders as complete",
        aliases: ["c"]
    )

    @Argument(
        parsing: .remaining,
        help: "Reminder number(s) or ID(s) to complete"
    )
    var inputs: [String] = []

    @Option(name: .shortAndLong, help: "Scope ID resolution to this list")
    var list: String?

    func run() async throws {
        let examples = [
            "  remind done 1        # Complete reminder [1]",
            "  remind done 1 2 3    # Complete multiple reminders",
            "  remind done 4A83     # Complete by partial ID"
        ]

        guard let result = try await resolveReminderIDs(
            inputs,
            listScope: list,
            examples: examples
        ) else {
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

    @Option(name: .customLong("list"), help: "Scope ID resolution to this list")
    var listScope: String?

    @Option(name: .shortAndLong, help: "New title")
    var title: String?

    @Option(name: .customLong("move-to"), help: "Move to a different list")
    var moveTo: String?

    @Option(name: .shortAndLong, help: "New due date")
    var due: String?

    @Option(name: .shortAndLong, help: "New priority (none, low, medium, high)")
    var priority: String?

    @Option(name: .shortAndLong, help: "New notes")
    var notes: String?

    @Flag(name: .shortAndLong, help: "Toggle flag (set flagged)")
    var flag: Bool = false

    @Flag(name: .long, help: "Unset the flag")
    var unflag: Bool = false

    func run() async throws {
        let manager = Manager()
        try await manager.requestAccess()

        let reminders = try await manager.getReminders(from: listScope)

        let resolved: [String] = if listScope == nil,
                                    let state = ViewStateStore.load()
        {
            IDResolver.resolveIDs(
                [input],
                snapshot: state.ids,
                reminders: reminders
            )
        } else {
            IDResolver.resolveIDs([input], from: reminders)
        }

        guard let id = resolved.first else {
            OutputUtils.printError("Reminder not found: \(input)")
            return
        }

        guard let reminder = reminders.first(where: { $0.id == id }) else {
            OutputUtils.printError("Reminder not found")
            return
        }

        let hasFlags = title != nil || moveTo != nil || due != nil ||
            priority != nil || notes != nil || flag || unflag

        if hasFlags {
            try await runDirect(manager: manager, id: id)
        } else {
            try await runInteractive(
                manager: manager,
                id: id,
                current: reminder
            )
        }
    }

    private func runDirect(manager: Manager, id: String) async throws {
        var parsedPriority: Reminder.Priority? = if let priority {
            parsePriority(priority)
        } else {
            nil
        }

        if parsedPriority == nil {
            if unflag {
                parsedPriority = Reminder.Priority.none
            } else if flag {
                parsedPriority = .high
            }
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
            listName: moveTo
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
    var inputs: [String] = []

    @Option(name: .shortAndLong, help: "Scope ID resolution to this list")
    var list: String?

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

        guard let result = try await resolveReminderIDs(
            inputs,
            listScope: list,
            examples: examples
        ) else {
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
